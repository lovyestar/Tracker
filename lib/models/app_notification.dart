/// 앱 알림 1건입니다. (#6 알림 센터)
///
/// 완주·스탬프 획득·코스 시작·구글 로그인 같은 이벤트가 발생하면
/// [NotificationStore] 가 이 모델로 기록합니다.
enum AppNotificationType { completion, stamp, courseStart, login }

class AppNotification {
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;

  const AppNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  /// JSON(Map) 한 개를 AppNotification 으로 변환합니다.
  /// 알 수 없는 타입/깨진 날짜는 안전값으로 처리해 앱이 죽지 않게 합니다.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      type: AppNotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AppNotificationType.completion,
      ),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
