import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/models/completion_record.dart';
import 'package:tracker_app/services/leaderboard_merge.dart';

/// 리더보드 병합 로직(순수 함수) 검증:
/// 원격 목록 + 내 로컬 기록 → 최종 순위. (버그: 내 완주 기록이 순위에 안 뜸)
void main() {
  LeaderboardEntry entry(String id, String nick, int stamps, [int comp = 1]) =>
      LeaderboardEntry(
          id: id, nickname: nick, totalStamps: stamps, completions: comp);

  group('mergeLeaderboard', () {
    test('원격에 내 항목이 없으면 로컬 기록으로 가상 항목을 추가한다', () {
      final rows = mergeLeaderboard(
        remote: [entry('a', '갑돌이', 10), entry('b', '을순이', 4)],
        myNickname: '영도지기',
        myUid: null,
        myTotalStamps: 6,
        myCompletions: 2,
      );
      expect(rows.length, 3);
      final me = rows.firstWhere((r) => r.isMe);
      expect(me.nickname, '영도지기');
      expect(me.totalStamps, 6);
      // 10 > 6 > 4 순.
      expect(rows.map((r) => r.totalStamps).toList(), [10, 6, 4]);
      expect(rows[1].isMe, isTrue);
    });

    test('원격에 uid 문서로 내 항목이 있으면 max(원격,로컬)로 갱신한다', () {
      final rows = mergeLeaderboard(
        remote: [entry('uid-1', '영도지기', 3), entry('b', '을순이', 8)],
        myNickname: '영도지기',
        myUid: 'uid-1',
        myTotalStamps: 12, // 로컬이 더 큼 → 12 로 갱신.
        myCompletions: 5,
      );
      expect(rows.length, 2);
      final me = rows.firstWhere((r) => r.isMe);
      expect(me.totalStamps, 12);
      expect(me.completions, 5);
      expect(rows.first.isMe, isTrue); // 12 > 8 → 1위.
    });

    test('닉네임 문서(게스트)로 내 항목이 있으면 매칭된다', () {
      final rows = mergeLeaderboard(
        remote: [entry('영도지기', '영도지기', 9)],
        myNickname: '영도지기',
        myUid: null,
        myTotalStamps: 5, // 원격이 더 큼 → 9 유지.
        myCompletions: 1,
      );
      expect(rows.length, 1);
      expect(rows.single.isMe, isTrue);
      expect(rows.single.totalStamps, 9);
    });

    test('원격이 비어도(Firestore 실패/게스트) 내 로컬 기록은 순위에 뜬다', () {
      final rows = mergeLeaderboard(
        remote: const [],
        myNickname: '영도지기',
        myUid: null,
        myTotalStamps: 7,
        myCompletions: 3,
      );
      expect(rows.length, 1);
      expect(rows.single.isMe, isTrue);
      expect(rows.single.totalStamps, 7);
    });

    test('내 로컬 기록이 없으면 가상 항목을 만들지 않는다', () {
      final rows = mergeLeaderboard(
        remote: [entry('a', '갑돌이', 10)],
        myNickname: '영도지기',
        myUid: null,
        myTotalStamps: 0,
        myCompletions: 0,
      );
      expect(rows.length, 1);
      expect(rows.any((r) => r.isMe), isFalse);
    });

    test('동점이면 완주 횟수 내림차순으로 정렬한다', () {
      final rows = mergeLeaderboard(
        remote: [entry('a', '갑돌이', 5, 1), entry('b', '을순이', 5, 3)],
        myNickname: '나',
        myUid: null,
        myTotalStamps: 0,
        myCompletions: 0,
      );
      expect(rows.map((r) => r.nickname).toList(), ['을순이', '갑돌이']);
    });
  });
}
