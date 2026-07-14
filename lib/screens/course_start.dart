import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../models/active_course.dart';
import '../models/recommendation.dart';
import '../services/active_course_store.dart';
import '../services/notification_store.dart';

/// 코스를 "진행 중(내비게이션 모드)"으로 시작하는 공통 진입점입니다.
///
/// 규칙:
///  - 이미 다른 코스가 진행 중이면 영매기 말투 안내 + "기존 경로 취소하고 시작" 다이얼로그.
///  - 시작하면 진행 상태를 전역 저장하고, 루트까지 pop 합니다.
///    (MainShell 이 진행 상태를 구독해 지도 탭으로 전환 → 지도 탭이 코스 내비를 보여줌)
Future<void> startActiveCourse(
  BuildContext context, {
  required String courseName,
  required List<Recommendation> stops,
}) async {
  final store = ActiveCourseStore.instance;
  final active = store.current;

  if (active != null && active.courseName != courseName) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('진행 중인 코스가 있데이'),
        content: const Text(MessagesKo.navLockGuide),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 진행'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.coralRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('기존 경로 취소하고 시작'),
          ),
        ],
      ),
    );
    if (replace != true) return;
  }

  await store.start(
    ActiveCourse(courseName: courseName, recommendations: stops),
  );
  await NotificationStore.instance.recordCourseStart(courseName);
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}
