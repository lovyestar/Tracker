import 'recommendation.dart';

/// 현재 진행 중(내비게이션 모드)인 코스 1건을 나타내는 모델입니다.
///
/// shared_preferences 에 JSON 으로 보관해 앱을 재시작해도 진행 상태가 유지되도록 합니다.
/// 지도 탭은 이 값이 있으면 자동으로 코스 내비 화면(course_map)을 보여줍니다.
class ActiveCourse {
  final String courseName;
  final List<Recommendation> recommendations;

  const ActiveCourse({
    required this.courseName,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
        'course_name': courseName,
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
      };

  factory ActiveCourse.fromJson(Map<String, dynamic> json) {
    final list = (json['recommendations'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Recommendation.fromJson)
        .toList();
    return ActiveCourse(
      courseName: (json['course_name'] ?? '').toString(),
      recommendations: list,
    );
  }
}
