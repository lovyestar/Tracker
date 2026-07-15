import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../services/active_course_store.dart';
import 'condition_input_screen.dart';
import 'home_screen.dart';
import 'map_tab.dart';
import 'my_records_screen.dart';
import 'profile_screen.dart';

/// 하단 네비게이션 셸입니다. (브랜드 보드: 스티커/두들)
///  - 홈 / 지도 / [중앙 원형 영매기 = AI 추천] / 저장(내 기록·스탬프) / 마이페이지
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 진행 중 코스가 있으면 지도 탭(1)으로 시작합니다.
  int _index = ActiveCourseStore.instance.current != null ? 1 : 0;

  late final List<Widget> _tabs = [
    HomeScreen(onGoToTab: _goToTab),
    const MapTab(),
    const MyRecordsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    ActiveCourseStore.instance.notifier.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    ActiveCourseStore.instance.notifier.removeListener(_onActiveChanged);
    super.dispose();
  }

  /// 코스가 새로 시작되면(진행 상태 발생) 지도 탭으로 자동 전환합니다.
  void _onActiveChanged() {
    if (ActiveCourseStore.instance.current != null && _index != 1) {
      setState(() => _index = 1);
    }
  }

  void _goToTab(int i) {
    if (i < 0 || i >= _tabs.length) return;
    setState(() => _index = i);
  }

  void _openAi() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConditionInputScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 셸이 키보드에 맞춰 리사이즈되면 IndexedStack 안의 지도 탭(카카오맵
      // 네이티브 텍스처)까지 매번 리사이즈되어, 위 화면에서 키보드를 쓰고
      // 돌아왔을 때 지도가 흔들리고 번쩍이는 문제가 생깁니다. 키보드 대응은
      // 각 탭 화면의 Scaffold 가 알아서 하므로 셸에서는 끕니다.
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _centerButton(),
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.cardWhite,
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 66,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _navItem(0, Icons.home_rounded, '홈'),
            _navItem(1, Icons.map_rounded, '지도'),
            const SizedBox(width: 64), // 중앙 버튼 자리
            _navItem(2, Icons.bookmark_rounded, '저장'),
            _navItem(3, Icons.person_rounded, '마이'),
          ],
        ),
      ),
    );
  }

  Widget _centerButton() {
    return GestureDetector(
      onTap: _openAi,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.skyBlue,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppTheme.skyBlue.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: Image.asset(
                'assets/images/yeongmaegi.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final selected = _index == i;
    final color = selected ? AppTheme.skyBlue : AppTheme.bodyText;
    return Expanded(
      child: InkResponse(
        onTap: () => _goToTab(i),
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
