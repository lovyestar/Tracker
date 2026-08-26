import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_course.dart';

/// 사용자 추가 코스(시안 04)의 로컬 저장소입니다. (shared_preferences)
class UserCourseStore {
  static const _kCourses = 'user_courses';

  Future<List<UserCourse>> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kCourses) ?? <String>[];
    final courses = <UserCourse>[];
    for (final s in list) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        courses.add(UserCourse.fromMap(map));
      } catch (_) {
        // 깨진 항목은 무시합니다.
      }
    }
    courses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return courses;
  }

  Future<void> addCourse(UserCourse course) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kCourses) ?? <String>[];
    list.add(jsonEncode(course.toMap()));
    await prefs.setStringList(_kCourses, list);
  }

  /// id 가 일치하는 코스를 덮어씁니다(수정 저장). 없으면 아무 것도 안 함. (#4)
  Future<void> updateCourse(UserCourse course) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kCourses) ?? <String>[];
    final encoded = jsonEncode(course.toMap());
    for (var i = 0; i < list.length; i++) {
      try {
        final map = jsonDecode(list[i]) as Map<String, dynamic>;
        if ((map['id'] ?? '').toString() == course.id) {
          list[i] = encoded;
          await prefs.setStringList(_kCourses, list);
          return;
        }
      } catch (_) {
        // 깨진 항목은 건너뜁니다.
      }
    }
  }

  /// 여러 코스를 id 기준으로 로컬에 병합 저장합니다(로그인 시 클라우드→로컬 내려받기용). (#5)
  ///
  /// 이미 로컬에 있는 id 는 로컬 버전을 유지합니다(local-first). 없던 코스만 추가됩니다.
  Future<void> upsertCourses(List<UserCourse> courses) async {
    if (courses.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kCourses) ?? <String>[];
    final byId = <String, String>{};
    for (final s in list) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        byId[(map['id'] ?? '').toString()] = s;
      } catch (_) {
        // 깨진 항목은 무시합니다.
      }
    }
    for (final c in courses) {
      if (c.id.isEmpty) continue;
      byId.putIfAbsent(c.id, () => jsonEncode(c.toMap()));
    }
    await prefs.setStringList(_kCourses, byId.values.toList());
  }

  /// id 가 일치하는 코스를 삭제합니다. 깨진 항목은 건너뜁니다.
  Future<void> deleteCourse(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kCourses) ?? <String>[];
    final kept = <String>[];
    for (final s in list) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        if ((map['id'] ?? '').toString() == id) continue;
      } catch (_) {
        // 깨진 항목은 그대로 유지(삭제 대상 아님).
      }
      kept.add(s);
    }
    await prefs.setStringList(_kCourses, kept);
  }
}
