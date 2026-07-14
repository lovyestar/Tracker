import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/completion_record.dart';
import '../models/saved_ai_course.dart';
import 'firebase_service.dart';

/// 로컬 저장소(shared_preferences) 래퍼입니다. (SPEC §1 로컬 저장, §4-8)
///
/// 초보자를 위한 설명:
///  - 닉네임과 완주 기록을 휴대폰 안에 저장합니다(오프라인에서도 동작).
///  - Firebase 가 없어도 "내 기록"이 남도록 하는 폴백 역할을 합니다.
class LocalStore {
  static const _kNickname = 'nickname';
  static const _kRecords = 'completion_records';
  static const _kProfilePhoto = 'profile_photo_path';
  static const _kLastAiCourse = 'last_ai_course';
  static const _kMergedUid = 'leaderboard_merged_uid';

  Future<String?> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kNickname);
  }

  Future<void> setNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNickname, nickname);
  }

  /// 프로필 사진의 앱 문서 디렉토리 경로(미설정 시 null).
  Future<String?> getProfilePhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kProfilePhoto);
  }

  Future<void> setProfilePhotoPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfilePhoto, path);
  }

  /// 완주 기록 전체를 읽어옵니다(최신순).
  Future<List<CompletionRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecords) ?? <String>[];
    final records = <CompletionRecord>[];
    for (final s in list) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        records.add(CompletionRecord.fromMap(map));
      } catch (_) {
        // 깨진 항목은 무시합니다(앱이 죽지 않게).
      }
    }
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  /// 완주 기록 1건을 추가 저장합니다.
  Future<void> addRecord(CompletionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecords) ?? <String>[];
    list.add(jsonEncode(record.toMap()));
    await prefs.setStringList(_kRecords, list);
  }

  /// 여러 완주 기록을 병합 저장합니다(로그인 시 클라우드→로컬 내려받기용). (#5)
  ///
  /// 내용 기반 키([FirebaseService.recordDocId])로 중복을 제거하며,
  /// 이미 로컬에 있는 기록은 로컬 버전을 유지합니다(local-first).
  Future<void> upsertRecords(List<CompletionRecord> records) async {
    if (records.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecords) ?? <String>[];
    final byKey = <String, String>{};
    for (final s in list) {
      try {
        final rec = CompletionRecord.fromMap(jsonDecode(s) as Map<String, dynamic>);
        byKey[FirebaseService.recordDocId(rec)] = s;
      } catch (_) {
        // 깨진 항목은 무시합니다.
      }
    }
    for (final r in records) {
      byKey.putIfAbsent(
          FirebaseService.recordDocId(r), () => jsonEncode(r.toMap()));
    }
    await prefs.setStringList(_kRecords, byKey.values.toList());
  }

  /// 마지막 AI 추천 결과 1건을 저장합니다(기존 저장본은 덮어씀).
  Future<void> saveLastAiCourse(SavedAiCourse course) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastAiCourse, jsonEncode(course.toJson()));
  }

  /// 마지막 AI 추천 결과를 읽어옵니다(없거나 깨졌으면 null).
  Future<SavedAiCourse?> loadLastAiCourse() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kLastAiCourse);
    if (s == null || s.isEmpty) return null;
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      final course = SavedAiCourse.fromJson(map);
      if (course.recommendations.isEmpty) return null;
      return course;
    } catch (_) {
      return null;
    }
  }

  /// 이 uid 로 로컬 기록을 리더보드에 병합한 적이 있는지 여부입니다.
  Future<bool> isMergedForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMergedUid) == uid;
  }

  /// 병합 완료를 기록합니다(uid 당 1회 가드용).
  Future<void> markMergedForUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMergedUid, uid);
  }
}
