import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/completion_record.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/leaderboard_merge.dart';
import '../services/local_store.dart';

/// 완주 순위 리스트(레트로 카드). 홈/마이/리더보드 화면에서 공용.
///  - Firestore 실시간 순위에 **내 로컬 완주 기록을 항상 병합**해 보여줍니다.
///    (게스트/미로그인, Firestore 실패·빈 결과에서도 내 기록은 순위에 뜹니다.)
///  - 내 항목은 스카이블루 하이라이트 + "나" 뱃지로 표시합니다.
class LeaderboardList extends StatefulWidget {
  /// 표시할 최대 항목 수. null 이면 전체.
  final int? limit;
  final bool shrinkWrap;

  const LeaderboardList({super.key, this.limit, this.shrinkWrap = true});

  @override
  State<LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<LeaderboardList> {
  final FirebaseService _firebase = FirebaseService();
  final LocalStore _store = LocalStore();

  late final Future<_MyStats> _myStats = _loadMyStats();

  Future<_MyStats> _loadMyStats() async {
    final nickname = (await _store.getNickname()) ?? '';
    final records = await _store.loadRecords();
    final totalStamps =
        records.fold<int>(0, (sum, r) => sum + r.stampCount);
    return _MyStats(
      nickname: nickname,
      uid: AuthService.instance.currentUser?.uid,
      totalStamps: totalStamps,
      completions: records.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MyStats>(
      future: _myStats,
      builder: (context, meSnap) {
        if (meSnap.connectionState == ConnectionState.waiting) {
          return _spinner();
        }
        final me = meSnap.data ?? const _MyStats.empty();

        // Firebase 미설정: 원격 없이 내 로컬 기록만으로 순위를 구성.
        if (!_firebase.isAvailable) {
          final rows = _merge(const <LeaderboardEntry>[], me);
          if (rows.isEmpty) return _unavailable();
          return _rows(rows, offlineNote: true);
        }

        return StreamBuilder<List<LeaderboardEntry>>(
          stream: _firebase.leaderboardStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _spinner();
            }
            final remote = snapshot.data ?? const <LeaderboardEntry>[];
            final rows = _merge(remote, me);
            if (rows.isEmpty) return _emptyCard();
            return _rows(rows);
          },
        );
      },
    );
  }

  List<LeaderboardRow> _merge(List<LeaderboardEntry> remote, _MyStats me) {
    final rows = mergeLeaderboard(
      remote: remote,
      myNickname: me.nickname,
      myUid: me.uid,
      myTotalStamps: me.totalStamps,
      myCompletions: me.completions,
    );
    if (widget.limit != null && rows.length > widget.limit!) {
      // 상위 limit 을 자르되, 내 항목이 잘려나가면 마지막 칸에 끼워 넣어
      // "전체보기 전에도 내 순위는 보이도록" 합니다.
      final top = rows.sublist(0, widget.limit!);
      final meInTop = top.any((r) => r.isMe);
      if (!meInTop) {
        final mine = rows.firstWhere((r) => r.isMe,
            orElse: () => const LeaderboardRow(
                nickname: '', totalStamps: -1, completions: 0));
        if (mine.totalStamps >= 0) {
          top[top.length - 1] = mine;
        }
      }
      return top;
    }
    return rows;
  }

  Widget _rows(List<LeaderboardRow> rows, {bool offlineNote = false}) {
    return Column(
      children: [
        if (offlineNote)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _offlineNote(),
          ),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _rankTile(i + 1, rows[i]),
          ),
      ],
    );
  }

  Widget _spinner() => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _rankTile(int rank, LeaderboardRow e) {
    final decoration = e.isMe
        ? BoxDecoration(
            color: AppTheme.skyBlue.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.skyBlue, width: 1.6),
          )
        : AppTheme.cardDecoration(radius: 16);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: decoration,
      child: Row(
        children: [
          _rankBadge(rank),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              e.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.warmBrown,
              ),
            ),
          ),
          if (e.isMe) ...[
            const SizedBox(width: 6),
            _meBadge(),
          ],
          const Spacer(),
          const Icon(Icons.local_activity, size: 15, color: AppTheme.gold),
          const SizedBox(width: 4),
          Text(
            '${e.totalStamps}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.warmBrown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.skyBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '나',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _rankBadge(int rank) {
    final medal = rank <= 3;
    final color = switch (rank) {
      1 => AppTheme.gold,
      2 => const Color(0xFFB9A48C),
      3 => const Color(0xFFC08552),
      _ => AppTheme.brownBorder,
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: medal ? color : AppTheme.cardCream,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: medal ? Colors.white : AppTheme.bodyBrown,
        ),
      ),
    );
  }

  Widget _offlineNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppTheme.gold),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '지금은 내 기록만 보여줘예. 인터넷·로그인하면 전체 순위가 뜬데이.',
              style: TextStyle(color: AppTheme.bodyBrown, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: const Center(
        child: Text(
          '아직 완주 기록이 없데이. 니가 1등 해봐라!',
          style: TextStyle(color: AppTheme.bodyBrown),
        ),
      ),
    );
  }

  Widget _unavailable() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: AppTheme.gold),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Firebase를 연결하면 완주 순위가 실시간으로 뜬데이.\n지금은 "스탬프" 탭에서 내 기록을 볼 수 있어예.',
              style: TextStyle(color: AppTheme.bodyBrown, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 내 로컬 통계(닉네임/uid/누적 스탬프/완주 수) 스냅샷.
class _MyStats {
  final String nickname;
  final String? uid;
  final int totalStamps;
  final int completions;

  const _MyStats({
    required this.nickname,
    required this.uid,
    required this.totalStamps,
    required this.completions,
  });

  const _MyStats.empty()
      : nickname = '',
        uid = null,
        totalStamps = 0,
        completions = 0;
}
