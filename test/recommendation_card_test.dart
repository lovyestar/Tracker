import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/models/recommendation.dart';
import 'package:tracker_app/models/saved_ai_course.dart';
import 'package:tracker_app/widgets/recommendation_card.dart';

/// AI 추천 카드 오버플로우 방지 + 저장 모델 직렬화 테스트입니다.
void main() {
  testWidgets('아주 긴 장소명/비용에도 RecommendationCard 오버플로우 예외가 없다',
      (tester) async {
    const longName = '부산광역시 영도구 아주아주 긴 이름을 가진 전망 좋은 명소 카페 테스트 장소';
    const longCost = '1인 25,000원 ~ 35,000원 (음료 및 디저트 포함, 주말 할증 별도)';
    const rec = Recommendation(
      placeName: longName,
      reason: '전망이 끝내주고 사진 찍기 좋은 곳이라예. 커피도 맛있고 조용해서 오래 머물기 좋습니다.',
      duration: '1시간 30분',
      estimatedCost: longCost,
    );

    // 좁은 폭으로 제약해 Row 내부 텍스트가 오버플로우하기 쉬운 조건을 만든다.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: RecommendationCard(index: 1, rec: rec),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('부산광역시 영도구'), findsOneWidget);
  });

  test('SavedAiCourse toJson/fromJson 라운드트립이 값을 보존한다', () {
    final course = SavedAiCourse(
      recommendations: const [
        Recommendation(
          placeName: '흰여울문화마을',
          reason: '바다뷰 골목',
          duration: '40분',
          estimatedCost: '무료',
        ),
        Recommendation(
          placeName: '태종대',
          reason: '절벽 전망',
          duration: '1시간',
          estimatedCost: '3,000원',
        ),
      ],
      summary: '2명 · 1일 · 3만원 · 자연·카페',
      createdAt: DateTime(2026, 7, 10, 14, 30),
    );

    final restored = SavedAiCourse.fromJson(course.toJson());

    expect(restored.recommendations.length, 2);
    expect(restored.recommendations.first.placeName, '흰여울문화마을');
    expect(restored.recommendations[1].estimatedCost, '3,000원');
    expect(restored.summary, '2명 · 1일 · 3만원 · 자연·카페');
    expect(restored.createdAt, DateTime(2026, 7, 10, 14, 30));
  });
}
