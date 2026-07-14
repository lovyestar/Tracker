/// 완주 기록 1건입니다. (SPEC §4-8, §7)
///
/// 로컬(shared_preferences)과 Firestore(users/{nickname}/completions) 양쪽에서
/// 같은 형태로 저장/복원하기 위해 toMap/fromMap 을 제공합니다.
class CompletionRecord {
  final String nickname;
  final String courseName;
  final DateTime date;
  final int stampCount;

  /// 완주한 장소 이름(방문 순서). 구버전 기록은 비어 있을 수 있습니다.
  /// 완주 기록 리스트의 대표 사진(#12)·상세 장소 리스트(#16)에 사용합니다.
  final List<String> placeNames;

  /// 내비 중 기록한 GPS 이동 궤적([[lat,lng], ...], 좌표 반올림).
  /// 상세 화면 지도의 이동 경로 폴리라인(#16)에 사용합니다. 없으면 스탬프 지점으로 폴백.
  final List<List<double>> route;

  const CompletionRecord({
    required this.nickname,
    required this.courseName,
    required this.date,
    required this.stampCount,
    this.placeNames = const [],
    this.route = const [],
  });

  Map<String, dynamic> toMap() => {
        'nickname': nickname,
        'courseName': courseName,
        'date': date.toIso8601String(),
        'stampCount': stampCount,
        if (placeNames.isNotEmpty) 'placeNames': placeNames,
        if (route.isNotEmpty)
          'route': route.map((p) => [p[0], p[1]]).toList(),
      };

  factory CompletionRecord.fromMap(Map<String, dynamic> map) {
    return CompletionRecord(
      nickname: (map['nickname'] ?? '').toString(),
      courseName: (map['courseName'] ?? '').toString(),
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      stampCount: _asInt(map['stampCount']),
      placeNames: _asStringList(map['placeNames']),
      route: _asRoute(map['route']),
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static List<String> _asStringList(Object? v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  static List<List<double>> _asRoute(Object? v) {
    if (v is! List) return const [];
    final out = <List<double>>[];
    for (final p in v) {
      if (p is List && p.length >= 2) {
        out.add([_asDouble(p[0]), _asDouble(p[1])]);
      }
    }
    return out;
  }
}

/// 리더보드 한 줄(닉네임별 누적)입니다. (SPEC §4-7)
class LeaderboardEntry {
  /// Firestore 문서 ID(로그인=uid, 게스트=닉네임). '내 항목' 식별에 사용합니다.
  final String id;
  final String nickname;
  final int totalStamps;
  final int completions;

  const LeaderboardEntry({
    this.id = '',
    required this.nickname,
    required this.totalStamps,
    required this.completions,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return LeaderboardEntry(
      id: id,
      nickname: (map['nickname'] ?? '').toString(),
      totalStamps: CompletionRecord._asInt(map['totalStamps']),
      completions: CompletionRecord._asInt(map['completions']),
    );
  }
}
