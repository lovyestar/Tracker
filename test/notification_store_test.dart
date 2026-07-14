import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_app/models/app_notification.dart';
import 'package:tracker_app/services/notification_store.dart';

/// #6 알림 저장소(순수 로직) 검증: 기록/최신순/최대 100개/읽음 처리.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = NotificationStore.instance;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('이벤트 기록이 최신순(내림차순)으로 쌓인다', () async {
    await store.recordCourseStart('코스 A');
    await store.recordStamp('흰여울문화마을');
    await store.recordCompletion('코스 A', 4);

    final items = await store.load();
    expect(items.length, 3);
    // 마지막에 기록한 완주가 맨 앞.
    expect(items.first.type, AppNotificationType.completion);
    // 시간 역순 정렬 보장.
    for (var i = 0; i < items.length - 1; i++) {
      expect(
          items[i].createdAt.isBefore(items[i + 1].createdAt), isFalse);
    }
  });

  test('최대 100개만 유지한다(오래된 것부터 밀려남)', () async {
    for (var i = 0; i < 105; i++) {
      await store.recordStamp('장소 $i');
    }
    final items = await store.load();
    expect(items.length, NotificationStore.maxItems);
  });

  test('읽음 처리 전에는 unread 가 쌓이고, 읽으면 0 이 된다', () async {
    await store.recordStamp('장소 1');
    await store.recordStamp('장소 2');
    await store.refreshUnread();
    expect(store.unread.value, 2);

    await store.markAllRead();
    expect(store.unread.value, 0);

    // 읽음 이후 새 알림은 다시 unread 1.
    await store.recordCompletion('코스', 3);
    expect(store.unread.value, 1);
  });

  test('로그인 알림 본문에 이름이 들어간다', () async {
    await store.recordLogin('영도지기');
    final items = await store.load();
    expect(items.first.type, AppNotificationType.login);
    expect(items.first.body.contains('영도지기'), isTrue);
  });
}
