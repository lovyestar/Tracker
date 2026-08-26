import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

/// 앱 알림 기록 저장소(shared_preferences JSON 리스트)입니다. (#6 알림 센터)
///
/// 초보자를 위한 설명:
///  - 완주/스탬프/코스 시작/로그인 같은 이벤트를 휴대폰 안에 남깁니다(오프라인 동작).
///  - 최신 [maxItems]개만 유지합니다(오래된 건 자동으로 밀려납니다).
///  - "읽지 않은 개수"는 마지막으로 알림 화면을 연 시각([_kLastRead]) 이후에
///    추가된 알림 수로 계산합니다. 화면 진입 시 읽음 처리하면 배지가 사라집니다.
class NotificationStore {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  static const _kList = 'app_notifications';
  static const _kLastRead = 'app_notifications_last_read';

  /// 유지할 최대 알림 개수.
  static const int maxItems = 100;

  /// 읽지 않은 알림 개수(마이 탭 배지가 이 값을 구독해 실시간 갱신).
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  /// 알림 전체를 최신순(내림차순)으로 읽어옵니다.
  Future<List<AppNotification>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kList) ?? <String>[];
    final items = <AppNotification>[];
    for (final s in raw) {
      try {
        items.add(
            AppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // 깨진 항목은 무시합니다(앱이 죽지 않게).
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// 알림 1건을 추가합니다. 최신순 유지 + [maxItems] 초과분 제거 + 배지 갱신.
  Future<void> _add(AppNotification n) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await load();
    items.insert(0, n);
    if (items.length > maxItems) items.removeRange(maxItems, items.length);
    await prefs.setStringList(
      _kList,
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
    await refreshUnread();
  }

  /// 읽지 않은 알림 개수를 다시 계산해 [unread] 에 반영합니다.
  Future<void> refreshUnread() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRead =
        DateTime.tryParse(prefs.getString(_kLastRead) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    final items = await load();
    unread.value = items.where((n) => n.createdAt.isAfter(lastRead)).length;
  }

  /// 모든 알림을 읽음 처리합니다(마지막 읽은 시각 = 지금).
  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastRead, DateTime.now().toIso8601String());
    unread.value = 0;
  }

  // --- 이벤트 기록 헬퍼 -------------------------------------------------------

  Future<void> recordCompletion(String courseName, int stampCount) => _add(
        AppNotification(
          type: AppNotificationType.completion,
          title: '코스 완주!',
          body: '\'$courseName\' 완주했데이. 스탬프 $stampCount개 모았다!',
          createdAt: DateTime.now(),
        ),
      );

  Future<void> recordStamp(String placeName) => _add(
        AppNotification(
          type: AppNotificationType.stamp,
          title: '스탬프 획득',
          body: '\'$placeName\' 도착! 스탬프 하나 찍었데이.',
          createdAt: DateTime.now(),
        ),
      );

  Future<void> recordCourseStart(String courseName) => _add(
        AppNotification(
          type: AppNotificationType.courseStart,
          title: '코스 시작',
          body: '\'$courseName\' 코스를 시작했데이. 끝까지 가보자!',
          createdAt: DateTime.now(),
        ),
      );

  Future<void> recordLogin(String name) => _add(
        AppNotification(
          type: AppNotificationType.login,
          title: '로그인 완료',
          body: '$name님, 이제 기기가 바뀌어도 기록이 이어진데이.',
          createdAt: DateTime.now(),
        ),
      );
}
