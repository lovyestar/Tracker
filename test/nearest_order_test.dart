import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/models/place.dart';
import 'package:tracker_app/models/recommendation.dart';
import 'package:tracker_app/services/ai_recommend_service.dart';

/// #3 현재 위치 기준 최근접 방문순서 정렬(그리디) 검증.
void main() {
  Recommendation rec(String name) =>
      Recommendation(placeName: name, reason: '', duration: '', estimatedCost: '');

  Place place(String name, double lat, double lng) => Place.fromJson({
        'id': name.hashCode,
        'name': name,
        'lat': lat,
        'lng': lng,
      });

  group('orderByNearest', () {
    test('출발 좌표에서 가까운 순서로 재정렬한다', () {
      // A(먼) - B(중간) - C(가까움) 순으로 들어오지만, 출발점 기준 C→B→A 가 되어야 한다.
      final recs = [rec('A'), rec('B'), rec('C')];
      final byName = {
        'A': place('A', 35.10, 129.10),
        'B': place('B', 35.05, 129.05),
        'C': place('C', 35.01, 129.01),
      };
      final ordered =
          AiRecommendService.orderByNearest(recs, byName, 35.00, 129.00);
      expect(ordered.map((r) => r.placeName).toList(), ['C', 'B', 'A']);
    });

    test('좌표가 없는 추천은 원래 상대 순서로 맨 뒤에 붙는다', () {
      final recs = [rec('A'), rec('X'), rec('B'), rec('Y')];
      final byName = {
        'A': place('A', 35.05, 129.05),
        'B': place('B', 35.01, 129.01),
        // X, Y 는 좌표 없음.
      };
      final ordered =
          AiRecommendService.orderByNearest(recs, byName, 35.00, 129.00);
      // 좌표 있는 B(가까움), A(멈) 먼저, 이어서 X, Y 원래 순서.
      expect(ordered.map((r) => r.placeName).toList(), ['B', 'A', 'X', 'Y']);
    });

    test('빈 목록은 빈 목록을 돌려준다', () {
      final ordered = AiRecommendService.orderByNearest(
          const [], const {}, 35.0, 129.0);
      expect(ordered, isEmpty);
    });
  });
}
