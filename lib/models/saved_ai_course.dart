import 'recommendation.dart';

/// 마지막으로 받은 AI 추천 결과 1건을 저장/복원하기 위한 모델입니다.
///
/// shared_preferences 에 JSON 문자열로 보관하며,
/// "최근 추천 코스 다시 보기" 카드에서 API 재호출 없이 결과 화면을 다시 엽니다.
class SavedAiCourse {
  final List<Recommendation> recommendations;

  /// 코스 제목(영매기 느낌). 구버전 저장본엔 없을 수 있어 기본값은 빈 문자열입니다. (#2)
  final String title;
  final String summary; // 조건 요약(예: "2명 · 1일 · 3만원 · 자연·카페")
  final DateTime createdAt;

  const SavedAiCourse({
    required this.recommendations,
    this.title = '',
    required this.summary,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'title': title,
        'summary': summary,
        'created_at': createdAt.toIso8601String(),
      };

  factory SavedAiCourse.fromJson(Map<String, dynamic> json) {
    final list = (json['recommendations'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Recommendation.fromJson)
        .toList();
    return SavedAiCourse(
      recommendations: list,
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
