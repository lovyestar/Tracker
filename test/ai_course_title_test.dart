import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:tracker_app/models/place.dart';
import 'package:tracker_app/models/tour_conditions.dart';
import 'package:tracker_app/services/ai_recommend_service.dart';

/// #2 코스 제목(course_title): 객체 엔벨로프 파싱 + 자리표시자 폴백 검증.
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

  test('객체 엔벨로프({course_title, places})에서 제목을 파싱한다', () async {
    const content = '{"course_title":"노을빛 바다 한 바퀴","places":['
        '{"place_name":"흰여울문화마을","reason":"노을이 이쁘데이","duration":"60분","estimated_cost":"무료"}'
        ']}';
    final service = AiRecommendService(client: mockReturning(content));

    final result = await service.recommend(
      conditions: TourConditions(),
      places: [place],
    );

    expect(result.isSuccess, isTrue);
    expect(result.courseTitle, '노을빛 바다 한 바퀴');
    expect(result.recommendations.single.placeName, '흰여울문화마을');
  });

  test('구버전(바로 배열) 응답도 파싱하고 제목은 폴백으로 채운다', () async {
    const content =
        '[{"place_name":"흰여울문화마을","reason":"r","duration":"60분","estimated_cost":"무료"}]';
    final service = AiRecommendService(client: mockReturning(content));

    final result = await service.recommend(
      conditions: TourConditions(),
      places: [place],
    );

    expect(result.isSuccess, isTrue);
    // 제목 없음 → 조건 기반 폴백이 비어있지 않게 채워진다.
    expect(result.courseTitle.isNotEmpty, isTrue);
  });

  test('제목이 자리표시자("string")면 폴백 제목으로 대체된다', () async {
    const content = '{"course_title":"string","places":['
        '{"place_name":"흰여울문화마을","reason":"r","duration":"60분","estimated_cost":"무료"}'
        ']}';
    final service = AiRecommendService(client: mockReturning(content));

    final result = await service.recommend(
      conditions: TourConditions(),
      places: [place],
    );

    expect(result.courseTitle, isNot('string'));
    expect(result.courseTitle.isNotEmpty, isTrue);
  });

  group('fallbackTitle', () {
    test('테마가 있으면 테마 단어를 포함한다', () {
      final c = TourConditions()..themes.add('자연');
      final title = AiRecommendService.fallbackTitle(c);
      expect(title.contains('자연'), isTrue);
      expect(title.length <= 15, isTrue);
    });

    test('테마가 없으면 "영도"로 폴백한다', () {
      final title = AiRecommendService.fallbackTitle(TourConditions());
      expect(title.contains('영도'), isTrue);
    });
  });
}
