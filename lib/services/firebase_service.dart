import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/completion_record.dart';
import '../models/user_course.dart';

/// Firestore 연동 서비스입니다. (SPEC §7)
///
/// 초보자를 위한 설명:
///  - google-services.json 이 없으면 Firebase 초기화가 실패합니다.
///    이때는 [isAvailable] 이 false 가 되어 리더보드/서버 저장 기능이 꺼지고,
///    앱은 로컬 기록만으로 정상 동작합니다(죽지 않음).
///  - main() 에서 초기화를 시도하고 성공하면 [markInitialized] 를 호출합니다.
class FirebaseService {
  static bool _initialized = false;

  /// main() 에서 Firebase.initializeApp() 이 성공하면 호출합니다.
  static void markInitialized() {
    _initialized = true;
  }

  /// Firestore 사용이 가능한지 여부입니다.
  bool get isAvailable => _initialized && Firebase.apps.isNotEmpty;

  /// 완주 기록을 저장하고 리더보드 집계를 갱신합니다.
  /// Firebase 미설정 시 아무 것도 하지 않습니다(로컬 저장은 별도).
  ///
  /// [docId] 를 주면(로그인 시 Firebase uid) 그것을 문서 ID 로 써서
  /// 기기가 바뀌어도 같은 계정의 기록이 이어집니다. 없으면(게스트) 닉네임을 씁니다.
  /// 표시용 닉네임은 항상 문서 필드로 저장됩니다.
  Future<void> saveCompletion(CompletionRecord record, {String? docId}) async {
    if (!isAvailable) {
      debugPrint('[Firebase] saveCompletion 스킵: Firebase 미설정(게스트 로컬 기록만 유지)');
      return;
    }
    final db = FirebaseFirestore.instance;
    final id = (docId != null && docId.isNotEmpty) ? docId : record.nickname;
    final mode = (docId != null && docId.isNotEmpty) ? '로그인(uid)' : '게스트(닉네임)';
    debugPrint('[Firebase] saveCompletion → leaderboard/$id ($mode, '
        'nickname=${record.nickname}, +stamps=${record.stampCount})');

    try {
      // 1) 개인 완주 이력: users/{id}/completions
      await db
          .collection('users')
          .doc(id)
          .collection('completions')
          .add(record.toMap());

      // 2) 리더보드 집계: leaderboard/{id} (누적 스탬프 + 완주 횟수)
      await db.collection('leaderboard').doc(id).set({
        'nickname': record.nickname,
        'totalStamps': FieldValue.increment(record.stampCount),
        'completions': FieldValue.increment(1),
      }, SetOptions(merge: true));
      debugPrint('[Firebase] saveCompletion 성공: leaderboard/$id');
    } catch (e) {
      // 권한/규칙 실패 등: 로컬 기록은 이미 저장되어 있으므로 삼키고 로그만 남김.
      debugPrint('[Firebase] saveCompletion 실패(로컬 우선, 무시): $e');
    }
  }

  /// 로그인 시점의 1회 마이그레이션: 로컬 완주 기록을 uid 문서로 병합합니다.
  /// (호출 측에서 uid 당 1회만 실행되도록 가드합니다.)
  Future<void> mergeLocalRecords({
    required String uid,
    required String nickname,
    required int totalStamps,
    required int completions,
  }) async {
    if (!isAvailable) return;
    if (totalStamps <= 0 && completions <= 0) return;
    await FirebaseFirestore.instance.collection('leaderboard').doc(uid).set({
      'nickname': nickname,
      'totalStamps': FieldValue.increment(totalStamps),
      'completions': FieldValue.increment(completions),
    }, SetOptions(merge: true));
  }

  // ── #5 코스·완주 기록 클라우드 동기화 ────────────────────────────────
  // 스키마: users/{uid}/courses/{courseId}, users/{uid}/records/{recordId}
  //
  // 사진 파일은 업로드하지 않습니다. photoPaths 는 이 기기의 로컬 파일 경로일 뿐이라
  // 다른 기기에서는 열 수 없고, 파일 자체 업로드는 Firebase Storage 범위(이번 작업 밖)
  // 입니다. 따라서 코스 문서에서 photo_paths 는 제외하고 올립니다.
  //
  // 모든 write 는 로컬 우선(local-first): 실패해도 예외를 삼키고 debugPrint 만 남겨
  // 로컬 저장이 항상 살아 있도록 합니다. 게스트(uid 없음)는 클라우드에 쓰지 않습니다.

  CollectionReference<Map<String, dynamic>> _coursesCol(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('courses');

  CollectionReference<Map<String, dynamic>> _recordsCol(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('records');

  /// 완주 기록의 안정적인 문서 ID(날짜+코스명 기반). 재업로드해도 중복되지 않게 합니다.
  /// CompletionRecord 에 별도 id 필드가 없어 내용 기반 결정적 키를 씁니다.
  static String recordDocId(CompletionRecord r) {
    final raw = '${r.date.toIso8601String()}_${r.courseName}';
    final safe = raw.replaceAll('/', '_'); // Firestore 문서 ID 는 '/' 금지.
    return safe.length > 1400 ? safe.substring(0, 1400) : safe;
  }

  /// 코스 1건을 users/{uid}/courses/{course.id} 에 merge 저장합니다(사진 제외).
  Future<void> uploadCourse(String uid, UserCourse course) async {
    if (!isAvailable || uid.isEmpty || course.id.isEmpty) return;
    try {
      final map = Map<String, dynamic>.from(course.toMap());
      map.remove('photo_paths'); // 사진 파일은 클라우드에 올리지 않음(로컬 전용).
      await _coursesCol(uid).doc(course.id).set(map, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firebase] uploadCourse 실패(로컬 우선, 무시): $e');
    }
  }

  /// 코스 문서를 삭제합니다(로그인 상태에서 로컬 삭제와 함께 호출).
  Future<void> deleteCourseDoc(String uid, String courseId) async {
    if (!isAvailable || uid.isEmpty || courseId.isEmpty) return;
    try {
      await _coursesCol(uid).doc(courseId).delete();
    } catch (e) {
      debugPrint('[Firebase] deleteCourseDoc 실패(무시): $e');
    }
  }

  /// users/{uid}/courses 전체를 내려받습니다. 실패 시 빈 목록.
  Future<List<UserCourse>> downloadCourses(String uid) async {
    if (!isAvailable || uid.isEmpty) return const [];
    try {
      final snap = await _coursesCol(uid).get();
      return snap.docs
          .map((d) => UserCourse.fromMap({...d.data(), 'id': d.id}))
          .toList();
    } catch (e) {
      debugPrint('[Firebase] downloadCourses 실패(무시): $e');
      return const [];
    }
  }

  /// 완주 기록 1건을 users/{uid}/records/{recordDocId} 에 merge 저장합니다.
  Future<void> uploadRecord(String uid, CompletionRecord record) async {
    if (!isAvailable || uid.isEmpty) return;
    try {
      await _recordsCol(uid)
          .doc(recordDocId(record))
          .set(record.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firebase] uploadRecord 실패(로컬 우선, 무시): $e');
    }
  }

  /// users/{uid}/records 전체를 내려받습니다. 실패 시 빈 목록.
  Future<List<CompletionRecord>> downloadRecords(String uid) async {
    if (!isAvailable || uid.isEmpty) return const [];
    try {
      final snap = await _recordsCol(uid).get();
      return snap.docs.map((d) => CompletionRecord.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('[Firebase] downloadRecords 실패(무시): $e');
      return const [];
    }
  }

  /// 리더보드 실시간 스트림(onSnapshot)입니다. 누적 스탬프 내림차순.
  /// Firebase 미설정 시 빈 목록 스트림을 돌려줍니다.
  Stream<List<LeaderboardEntry>> leaderboardStream() {
    if (!isAvailable) {
      return Stream<List<LeaderboardEntry>>.value(const []);
    }
    return FirebaseFirestore.instance
        .collection('leaderboard')
        .orderBy('totalStamps', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaderboardEntry.fromMap(doc.data(), id: doc.id))
            .toList());
  }
}
