import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_course.dart';

/// 진행 중 코스(내비게이션 모드)의 전역 상태 저장소입니다.
///
/// - 싱글턴 + shared_preferences 로 앱 재시작에도 진행 상태를 유지합니다.
/// - [notifier] 를 구독하면 진행 코스가 바뀔 때(시작/취소/완주) UI 가 반응합니다.
///   예) 지도 탭은 진행 코스가 있으면 자동으로 코스 내비 화면을 보여줍니다.
class ActiveCourseStore {
  ActiveCourseStore._();
  static final ActiveCourseStore instance = ActiveCourseStore._();

  static const _kActiveCourse = 'active_course';

  /// 현재 진행 코스(없으면 null). 메모리 캐시 겸 구독 대상.
  final ValueNotifier<ActiveCourse?> notifier = ValueNotifier<ActiveCourse?>(null);

  ActiveCourse? get current => notifier.value;

  /// 앱 시작 시(main) 저장된 진행 코스를 메모리로 미리 읽어옵니다.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kActiveCourse);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final course = ActiveCourse.fromJson(map);
      if (course.recommendations.isNotEmpty) {
        notifier.value = course;
      }
    } catch (_) {
      // 깨진 값은 무시(비진행 상태로 시작).
    }
  }

  /// 코스를 진행 상태로 설정합니다(기존 진행 코스가 있으면 덮어씀).
  Future<void> start(ActiveCourse course) async {
    notifier.value = course; // 먼저 메모리/구독 반영(즉시 UI 전환)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveCourse, jsonEncode(course.toJson()));
    } catch (_) {
      // 저장 실패해도 이번 세션 진행 상태는 유지됩니다.
    }
  }

  /// 진행 상태를 해제합니다(취소/완주). 스탬프·완주 기록은 건드리지 않습니다.
  Future<void> clear() async {
    notifier.value = null; // 먼저 메모리/구독 반영
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kActiveCourse);
    } catch (_) {
      // 무시.
    }
  }
}
