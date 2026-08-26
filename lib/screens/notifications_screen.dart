import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../models/app_notification.dart';
import '../services/notification_store.dart';

/// 알림 기록 화면입니다. (#6 알림 센터)
///  - 시간 역순(최신 먼저), 아이콘 + 제목 + 본문 + 상대시간("3시간 전")
///  - 진입 즉시 읽음 처리 → 마이 탭 배지가 사라집니다.
///  - 비어 있으면 영매기 말투 빈 상태 문구.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationStore _store = NotificationStore.instance;
  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _store.load();
    // 진입 시 읽음 처리(배지 제거). 목록은 이미 읽어둔 뒤라 그대로 보여줍니다.
    await _store.markAllRead();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// "방금 전 / N분 전 / N시간 전 / N일 전 / yyyy.MM.dd" 상대시간.
  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  }

  IconData _iconFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.completion:
        return Icons.emoji_events;
      case AppNotificationType.stamp:
        return Icons.local_activity;
      case AppNotificationType.courseStart:
        return Icons.flag;
      case AppNotificationType.login:
        return Icons.login;
    }
  }

  Color _colorFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.completion:
        return AppTheme.gold;
      case AppNotificationType.stamp:
        return AppTheme.skyBlue;
      case AppNotificationType.courseStart:
        return AppTheme.mintGreen;
      case AppNotificationType.login:
        return AppTheme.coralRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _tile(_items[i]),
                  ),
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 48, color: AppTheme.bodyBrown),
            SizedBox(height: 12),
            Text(MessagesKo.notificationsEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.bodyBrown, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final color = _colorFor(n.type);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(n.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy)),
                    ),
                    const SizedBox(width: 8),
                    Text(_relative(n.createdAt),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.bodyBrown)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(n.body,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.bodyBrown, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
