import '../models/completion_record.dart';

/// 리더보드 한 줄(원격+로컬 병합 결과)입니다. [isMe] 가 true 면 '내 항목'.
class LeaderboardRow {
  final String nickname;
  final int totalStamps;
  final int completions;
  final bool isMe;

  const LeaderboardRow({
    required this.nickname,
    required this.totalStamps,
    required this.completions,
    this.isMe = false,
  });
}

/// 원격 리더보드 목록에 '내 로컬 완주 기록'을 항상 병합합니다.
///
/// 규칙(사용자 지시):
///  - 원격에 내 항목(문서 ID=uid 또는 닉네임, 혹은 닉네임 일치)이 있으면
///    max(원격, 로컬) 으로 갱신하고 '나'로 표시합니다.
///  - 없으면 내 로컬 기록으로 가상 항목을 추가해 순위에 포함합니다.
///  - Firestore 실패/게스트로 원격이 비어도 최소한 내 기록은 순위에 뜹니다.
///
/// 정렬은 누적 스탬프 내림차순, 동점 시 완주 횟수 내림차순입니다.
List<LeaderboardRow> mergeLeaderboard({
  required List<LeaderboardEntry> remote,
  required String myNickname,
  String? myUid,
  required int myTotalStamps,
  required int myCompletions,
}) {
  final nickname = myNickname.trim();
  final uid = (myUid ?? '').trim();
  final haveLocal = myTotalStamps > 0 || myCompletions > 0;

  bool isMine(LeaderboardEntry e) {
    if (uid.isNotEmpty && e.id == uid) return true;
    if (nickname.isNotEmpty && e.id == nickname) return true;
    if (nickname.isNotEmpty && e.nickname == nickname) return true;
    return false;
  }

  final rows = <LeaderboardRow>[];
  var matched = false;
  for (final e in remote) {
    if (!matched && isMine(e)) {
      matched = true;
      rows.add(LeaderboardRow(
        nickname: nickname.isNotEmpty ? nickname : e.nickname,
        totalStamps:
            e.totalStamps > myTotalStamps ? e.totalStamps : myTotalStamps,
        completions:
            e.completions > myCompletions ? e.completions : myCompletions,
        isMe: true,
      ));
    } else {
      rows.add(LeaderboardRow(
        nickname: e.nickname,
        totalStamps: e.totalStamps,
        completions: e.completions,
      ));
    }
  }

  // 원격에 내 항목이 없고 로컬 기록이 있으면 가상 항목 추가.
  if (!matched && haveLocal && nickname.isNotEmpty) {
    rows.add(LeaderboardRow(
      nickname: nickname,
      totalStamps: myTotalStamps,
      completions: myCompletions,
      isMe: true,
    ));
  }

  rows.sort((a, b) {
    final byStamps = b.totalStamps.compareTo(a.totalStamps);
    if (byStamps != 0) return byStamps;
    return b.completions.compareTo(a.completions);
  });
  return rows;
}
