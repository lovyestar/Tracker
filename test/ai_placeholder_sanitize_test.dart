import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:tracker_app/models/place.dart';
import 'package:tracker_app/models/tour_conditions.dart';
import 'package:tracker_app/services/ai_recommend_service.dart';

/// #13 회귀 방지: AI 응답의 duration/estimated_cost 자리에 스키마 자리표시자
/// "string" 이 새어 나오면 "정보 없음" 으로 방어 대체되어야 합니다.
void main() {
  final place = Place.fromJson(const {
    'id': 1,
    'name': '흰여울문화마을',
    'lat': 35.078,
    'lng': 129.045,
    'review_summary': '바다뷰 절벽 마을',
  });

  http.Client mockReturning(String content) {
    return MockClient((request) async {
      final body = jsonEncode({
        'choices': [
          {
            'message': {'content': content}
          }
        ]
      });
      return http.Response(body, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
  }

  test('duration/estimated_cost 가 "string" 이면 "정보 없음" 으로 대체된다', () async {
    const content =
        '[{"place_name":"흰여울문화마을","reason":"노을이 억수로 이쁘데이","duration":"string","estimated_cost":"string"}]';
    final service = AiRecommendService(client: mockReturning(content));

    final result = await service.recommend(
      conditions: TourConditions(),
      places: [place],
    );

    expect(result.isSuccess, isTrue);
    final rec = result.recommendations.single;
    expect(rec.duration, '정보 없음');
    expect(rec.estimatedCost, '정보 없음');
    // 정상 값(reason)은 그대로 보존.
    expect(rec.reason, '노을이 억수로 이쁘데이');
  });

  test('빈 reason 은 장소 요약으로 대체된다', () async {
    const content =
        '[{"place_name":"흰여울문화마을","reason":"","duration":"60분","estimated_cost":"무료"}]';
    final service = AiRecommendService(client: mockReturning(content));

    final result = await service.recommend(
      conditions: TourConditions(),
      places: [place],
    );

    final rec = result.recommendations.single;
    expect(rec.reason, '바다뷰 절벽 마을');
    // 정상 값은 그대로.
    expect(rec.duration, '60분');
    expect(rec.estimatedCost, '무료');
  });
}
