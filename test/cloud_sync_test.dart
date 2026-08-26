import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_app/models/completion_record.dart';
import 'package:tracker_app/models/user_course.dart';
import 'package:tracker_app/services/firebase_service.dart';
import 'package:tracker_app/services/local_store.dart';
import 'package:tracker_app/services/user_course_store.dart';

/// #5 클라우드 동기화 보조 로직(순수 Dart) 검증.
///  - recordDocId 결정성/안전성
///  - 로컬 병합(upsert)이 local-first 로 중복 없이 합쳐지는지
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseService.recordDocId', () {
    test('같은 날짜+코스명은 같은 문서 ID 를 만든다(결정적)', () {
      final date = DateTime.parse('2026-07-11T10:30:00.000');
      final a = CompletionRecord(
          nickname: '갑', courseName: 'AI 맞춤 코스', date: date, stampCount: 3);
      final b = CompletionRecord(
          nickname: '을', courseName: 'AI 맞춤 코스', date: date, stampCount: 5);
      expect(FirebaseService.recordDocId(a), FirebaseService.recordDocId(b));
    });

    test('코스명이 다르면 문서 ID 도 다르다', () {
      final date = DateTime.parse('2026-07-11T10:30:00.000');
      final a = CompletionRecord(
          nickname: '갑', courseName: '코스 A', date: date, stampCount: 3);
      final b = CompletionRecord(
          nickname: '갑', courseName: '코스 B', date: date, stampCount: 3);
      expect(FirebaseService.recordDocId(a),
          isNot(FirebaseService.recordDocId(b)));
    });

    test('슬래시(/)는 문서 ID 에서 제거된다', () {
      final r = CompletionRecord(
        nickname: '갑',
        courseName: 'a/b/c',
        date: DateTime.parse('2026-07-11T10:30:00.000'),
        stampCount: 1,
      );
      expect(FirebaseService.recordDocId(r).contains('/'), isFalse);
    });
  });

  group('LocalStore.upsertRecords', () {
    test('기존 기록은 유지하고 새 기록만 추가한다(중복 제거)', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore();
      final existing = CompletionRecord(
        nickname: '갑',
        courseName: '코스 A',
        date: DateTime.parse('2026-07-01T09:00:00.000'),
        stampCount: 4,
      );
      await store.addRecord(existing);

      // 하나는 기존과 동일(중복), 하나는 신규.
      final duplicate = CompletionRecord(
        nickname: '갑',
        courseName: '코스 A',
        date: DateTime.parse('2026-07-01T09:00:00.000'),
        stampCount: 4,
      );
      final fresh = CompletionRecord(
        nickname: '갑',
        courseName: '코스 B',
        date: DateTime.parse('2026-07-05T09:00:00.000'),
        stampCount: 6,
      );
      await store.upsertRecords([duplicate, fresh]);

      final all = await store.loadRecords();
      expect(all.length, 2);
      expect(all.map((r) => r.courseName).toSet(), {'코스 A', '코스 B'});
    });
  });

  group('UserCourseStore.upsertCourses', () {
    test('같은 id 는 로컬 버전 유지, 없던 id 만 추가한다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = UserCourseStore();
      final local = UserCourse(
        id: 'c1',
        title: '로컬 코스',
        location: '흰여울',
        description: '',
        categories: const ['자연'],
        createdAt: DateTime.parse('2026-07-01T00:00:00.000'),
      );
      await store.addCourse(local);

      final remoteSameId = UserCourse(
        id: 'c1',
        title: '원격이 덮으면 안 됨',
        location: '엉뚱',
        description: '',
        categories: const [],
        createdAt: DateTime.parse('2026-07-02T00:00:00.000'),
      );
      final remoteNew = UserCourse(
        id: 'c2',
        title: '원격 신규 코스',
        location: '태종대',
        description: '',
        categories: const ['관광지'],
        createdAt: DateTime.parse('2026-07-03T00:00:00.000'),
      );
      await store.upsertCourses([remoteSameId, remoteNew]);

      final all = await store.loadCourses();
      expect(all.length, 2);
      final c1 = all.firstWhere((c) => c.id == 'c1');
      // local-first: 기존 로컬 제목 유지.
      expect(c1.title, '로컬 코스');
      final c2 = all.firstWhere((c) => c.id == 'c2');
      expect(c2.title, '원격 신규 코스');
    });
  });
}
