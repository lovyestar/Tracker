import 'recommendation.dart';

/// 프리셋 코스 1개입니다. (SPEC §3, §4-4, courses_11.md)
///
/// stops 의 각 place_name 은 assets/yeongdo_tourism_db.json 의 name 과 완전 일치합니다.
class PresetCourse {
  final int id;
  final String theme; // 테마 (예: 야경)
  final String target; // 타깃 (예: 20~30대 커플)
  final String totalTime; // 총 소요(예: 3h)
  final String budget; // 1인 예산(예: 25,000원)
  final String stairs; // 계단 강도(예: 중)
  final bool adultOnly; // 성인 전용(코스 3)
  final List<Recommendation> stops; // 장소 순서 + 4필드

  const PresetCourse({
    required this.id,
    required this.theme,
    required this.target,
    required this.totalTime,
    required this.budget,
    required this.stairs,
    this.adultOnly = false,
    required this.stops,
  });

  /// 코스 표시용 이름입니다. (완주 카드/기록에 사용)
  String get title => '$theme 코스';

  /// 코스에 포함된 장소 이름 목록입니다.
  List<String> get placeNames => stops.map((s) => s.placeName).toList();
}
