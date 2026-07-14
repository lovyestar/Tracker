import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../constants/preset_courses.dart';
import '../models/preset_course.dart';
import '../widgets/leaderboard_list.dart';
import '../widgets/place_photo.dart';
import '../widgets/retro.dart';
import '../widgets/top_snack_bar.dart';
import '../widgets/yeongmaegi_bubble.dart';
import '../services/voice_service.dart';
import 'condition_input_screen.dart';
import 'leaderboard_screen.dart';
import 'preset_courses_screen.dart';

/// 홈 화면입니다. (브랜드 보드 시안 01)
///  - Tracker 로고 + 영매기 인사 말풍선
///  - 빠른 이동(코스 추천/명소/맛집/이벤트) + AI 맞춤 코스 CTA
///  - 오늘의 추천 코스(스티커 카드) / 완주 순위
class HomeScreen extends StatefulWidget {
  /// 하단 탭 전환 콜백(셸에서 주입). 지도 탭 등으로 이동할 때 사용.
  final ValueChanged<int>? onGoToTab;

  const HomeScreen({super.key, this.onGoToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 홈 첫 진입 음성은 앱 세션당 한 번만 재생합니다.
  static bool _greetingVoicePlayed = false;

  String _greeting = MessagesKo.greetingFirst;

  @override
  void initState() {
    super.initState();
    // 첫인사(기본 대사)는 축약형으로 표시합니다. 음성/시간대 인사는 그대로. (#7)
    final g = MessagesKo.greetingForHour(DateTime.now().hour);
    _greeting =
        g == MessagesKo.greetingFirst ? MessagesKo.greetingFirstShort : g;
    if (!_greetingVoicePlayed) {
      _greetingVoicePlayed = true;
      VoiceService.instance.play(VoiceLine.greetingFirst);
    }
  }

  /// 인사 말풍선 탭: 현재 시간대에 맞는 프리셋 코스를 즉시 추천합니다. (#5)
  ///
  /// 별도 API 없이 로컬 시간대 → 테마 매칭으로 코스를 고르고,
  /// 영매기 말투 사유를 안내한 뒤 코스 상세로 이동합니다.
  void _openSituational() {
    final hour = DateTime.now().hour;
    final course = _situationalCourse(hour);
    if (course == null) return;
    final reason = MessagesKo.situationReasonForHour(hour);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YeongmaegiBubble(message: reason, avatarSize: 60),
              const SizedBox(height: 16),
              Text(course.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy)),
              const SizedBox(height: 4),
              Text('${course.theme} · ${course.target} · ${course.totalTime}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTheme.bodyText)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.explore),
                label: const Text('이 코스 보러가기'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CourseDetailScreen(course: course)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 시간대에 맞는 테마의 프리셋 코스를 고릅니다. 미성년 노출 방지로 성인전용은 제외. (#5)
  PresetCourse? _situationalCourse(int hour) {
    final theme = _situationalTheme(hour);
    final candidates =
        kPresetCourses.where((c) => !c.adultOnly).toList();
    for (final c in candidates) {
      if (c.theme.contains(theme)) return c;
    }
    return candidates.isNotEmpty ? candidates.first : null;
  }

  String _situationalTheme(int hour) {
    if (hour >= 20 || hour <= 5) return '야경';
    if (hour >= 17 && hour <= 19) return '야경';
    if (hour >= 11 && hour <= 13) return '카페';
    if (hour >= 6 && hour <= 10) return '자연';
    return '즉흥';
  }

  void _openCourses() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PresetCoursesScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final todayCourses = kPresetCourses.take(3).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            _topBar(),
            const SizedBox(height: 16),
            YeongmaegiBubble(
                message: _greeting, avatarSize: 76, onTap: _openSituational),
            const SizedBox(height: 18),
            _quickActions(),
            const SizedBox(height: 18),
            _aiCta(),
            const SizedBox(height: 24),
            SectionHeader(
              icon: Icons.explore,
              title: '오늘의 추천 코스',
              actionText: '전체보기',
              onAction: _openCourses,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: todayCourses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) =>
                    _todayCourseCard(todayCourses[i], i),
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              icon: Icons.emoji_events,
              title: '완주 순위',
              actionText: '전체보기',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              ),
            ),
            const SizedBox(height: 12),
            const LeaderboardList(limit: 4),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tracker', style: AppTheme.logo(size: 34)),
              const Text(
                '영도를 가장 재밌게 추적하는 방법!',
                style: TextStyle(
                  color: AppTheme.skyBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.lineSoft),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_none, color: AppTheme.navy),
            onPressed: () => showTopSnackBar(context, message: '새 알림이 없데이!'),
          ),
        ),
      ],
    );
  }

  Widget _quickActions() {
    final items = <(IconData, String, Color, VoidCallback)>[
      (Icons.auto_awesome, '코스 추천', AppTheme.skyBlue, _openCourses),
      (Icons.place, '명소', AppTheme.mintGreen, () => widget.onGoToTab?.call(1)),
      (Icons.restaurant, '맛집', AppTheme.coralRed, _openCourses),
      (
        Icons.celebration,
        '이벤트',
        AppTheme.sunnyYellow,
        () => showTopSnackBar(context, message: '진행 중인 이벤트가 곧 열린데이!')
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (icon, label, color, onTap) in items)
          _quickButton(icon, label, color, onTap),
      ],
    );
  }

  Widget _quickButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy)),
        ],
      ),
    );
  }

  Widget _aiCta() {
    return FilledButton.icon(
      icon: const Icon(Icons.auto_awesome),
      label: const Text('AI 맞춤 코스 추천받기'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConditionInputScreen()),
      ),
    );
  }

  Widget _todayCourseCard(PresetCourse course, int index) {
    final accents = [
      AppTheme.coralRed,
      AppTheme.sunnyYellow,
      AppTheme.mintGreen
    ];
    final accent = accents[index % accents.length];
    final photoName =
        course.placeNames.isNotEmpty ? course.placeNames.first : null;
    return SizedBox(
      width: 250,
      child: RetroCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PlacePhoto(
                  placeName: photoName,
                  width: double.infinity,
                  height: 120,
                  radius: 22,
                ),
                if (index == 0)
                  const Positioned(top: 10, left: 10, child: BestBadge()),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      course.theme,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.target,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppTheme.bodyText),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InfoTag(
                            icon: Icons.schedule,
                            text: course.totalTime,
                            color: AppTheme.skyBlue,
                            flexible: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InfoTag(
                            icon: Icons.stairs,
                            text: '계단 ${course.stairs}',
                            color: AppTheme.skyBlue,
                            flexible: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
