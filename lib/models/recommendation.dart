/// AI(또는 프리셋)가 추천한 장소 1곳을 나타내는 모델입니다. (SPEC §3~§5)
///
/// 출력 JSON은 정확히 4필드입니다: place_name / reason / duration / estimated_cost.
class Recommendation {
  final String placeName;
  final String reason;
  final String duration;
  final String estimatedCost;

  const Recommendation({
    required this.placeName,
    required this.reason,
    required this.duration,
    required this.estimatedCost,
  });

  /// JSON(Map) 한 개를 Recommendation 으로 변환합니다.
  /// 4필드 중 일부가 없어도 앱이 죽지 않도록 빈 문자열로 처리합니다.
  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      placeName: (json['place_name'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      estimatedCost: (json['estimated_cost'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'place_name': placeName,
        'reason': reason,
        'duration': duration,
        'estimated_cost': estimatedCost,
      };
}
