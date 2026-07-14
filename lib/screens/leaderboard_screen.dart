import 'package:flutter/material.dart';

import '../widgets/leaderboard_list.dart';
import '../widgets/yeongmaegi_bubble.dart';

/// 리더보드 화면입니다. (레트로 선셋 리디자인)
///  - Firestore leaderboard 실시간 순위(공용 LeaderboardList 위젯 사용).
///  - Firebase 미설정 시 안내 카드 표시.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('완주 순위')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            YeongmaegiBubble(
              message: '누가 제일 많이 스탬프를 모았노? 순위 한 번 보래이!',
            ),
            SizedBox(height: 16),
            LeaderboardList(),
          ],
        ),
      ),
    );
  }
}
