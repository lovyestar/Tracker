import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/models/recommendation.dart';
import 'package:tracker_app/services/ai_recommend_service.dart';

/// safe_json_extract 파서 단위 테스트입니다. (SPEC §8-2)
void main() {
  group('AiRecommendService.safeJsonExtract', () {
    test('정상 JSON 배열을 파싱한다', () {
      const raw =
          '[{"place_name":"흰여울문화마을","reason":"r","duration":"60분","estimated_cost":"무료"}]';
      final list = AiRecommendService.safeJsonExtract(raw);
      expect(list.length, 1);
      final rec = Recommendation.fromJson(Map<String, dynamic>.from(list.first));
      expect(rec.placeName, '흰여울문화마을');
      expect(rec.duration, '60분');
    });

    test('코드펜스(```json)로 감싼 JSON 을 파싱한다', () {
      const raw = '```json\n'
          '[{"place_name":"태종대유원지","reason":"r","duration":"60분","estimated_cost":"무료"}]\n'
          '```';
      final list = AiRecommendService.safeJsonExtract(raw);
      expect(list.length, 1);
      expect((list.first as Map)['place_name'], '태종대유원지');
    });

    test('앞뒤 설명 텍스트가 섞여 있어도 배열만 추출한다', () {
      const raw = '알겠다! 아래 코스 추천한데이:\n'
          '[{"place_name":"봉래산","reason":"r","duration":"60분","estimated_cost":"무료"}]\n'
          '이 코스로 가보래이.';
      final list = AiRecommendService.safeJsonExtract(raw);
      expect(list.length, 1);
      expect((list.first as Map)['place_name'], '봉래산');
    });

    test('빈 배열을 파싱하면 빈 목록을 돌려준다', () {
      final list = AiRecommendService.safeJsonExtract('[]');
      expect(list, isEmpty);
    });

    test('완전히 깨진 문자열이면 빈 목록을 돌려준다', () {
      expect(AiRecommendService.safeJsonExtract('그냥 아무 말'), isEmpty);
      expect(AiRecommendService.safeJsonExtract(''), isEmpty);
    });

    test('여러 항목이 든 배열을 모두 파싱한다', () {
      const raw = '['
          '{"place_name":"A","reason":"r","duration":"d","estimated_cost":"c"},'
          '{"place_name":"B","reason":"r","duration":"d","estimated_cost":"c"}'
          ']';
      final list = AiRecommendService.safeJsonExtract(raw);
      expect(list.length, 2);
    });
  });
}
