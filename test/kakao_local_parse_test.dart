import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:tracker_app/services/kakao_local_service.dart';

/// #7 카카오 로컬 키워드 검색 응답 파싱(방어적) 검증.
void main() {
  group('KakaoLocalService.parseResponse', () {
    test('정상 문서를 KakaoPlace 로 파싱한다(도로명 우선)', () {
      const body = '{"documents":['
          '{"place_name":"흰여울문화마을","road_address_name":"부산 영도구 흰여울길",'
          '"address_name":"부산 영도구 영선동","x":"129.045","y":"35.078"},'
          '{"place_name":"태종대","road_address_name":"",'
          '"address_name":"부산 영도구 동삼동","x":"129.086","y":"35.052"}'
          ']}';
      final places = KakaoLocalService.parseResponse(body);
      expect(places.length, 2);
      expect(places.first.name, '흰여울문화마을');
      // 도로명이 있으면 도로명 주소 사용.
      expect(places.first.address, '부산 영도구 흰여울길');
      expect(places.first.lat, closeTo(35.078, 1e-6));
      expect(places.first.lng, closeTo(129.045, 1e-6));
      // 도로명이 비면 지번 주소로 폴백.
      expect(places[1].address, '부산 영도구 동삼동');
    });

    test('좌표/이름 결측 문서는 건너뛴다', () {
      const body = '{"documents":['
          '{"place_name":"","x":"129.0","y":"35.0"},'
          '{"place_name":"좌표없음","x":"","y":""},'
          '{"place_name":"정상","x":"129.05","y":"35.08"}'
          ']}';
      final places = KakaoLocalService.parseResponse(body);
      expect(places.length, 1);
      expect(places.first.name, '정상');
    });

    test('documents 없음/깨진 JSON 은 빈 목록', () {
      expect(KakaoLocalService.parseResponse('{}'), isEmpty);
      expect(KakaoLocalService.parseResponse('not json'), isEmpty);
      expect(KakaoLocalService.parseResponse('{"documents":"bad"}'), isEmpty);
    });
  });

  group('KakaoLocalService.searchKeyword', () {
    test('빈 키워드는 네트워크 호출 없이 빈 목록', () async {
      final service = KakaoLocalService(client: MockClient((_) async {
        fail('빈 키워드는 요청하면 안 된다');
      }));
      final result =
          await service.searchKeyword('  ', lat: 35.08, lng: 129.05);
      expect(result, isEmpty);
    });

    test('200 응답이면 파싱 결과를 돌려준다', () async {
      final service = KakaoLocalService(client: MockClient((request) async {
        expect(request.headers['Authorization']!.startsWith('KakaoAK '), isTrue);
        final body = jsonEncode({
          'documents': [
            {
              'place_name': '흰여울문화마을',
              'road_address_name': '부산 영도구 흰여울길',
              'x': '129.045',
              'y': '35.078',
            }
          ]
        });
        return http.Response(body, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final result =
          await service.searchKeyword('흰여울', lat: 35.08, lng: 129.05);
      expect(result.single.name, '흰여울문화마을');
    });

    test('비200 응답은 빈 목록(스낵바 폴백)', () async {
      final service = KakaoLocalService(client: MockClient((_) async {
        return http.Response('error', 401);
      }));
      final result =
          await service.searchKeyword('흰여울', lat: 35.08, lng: 129.05);
      expect(result, isEmpty);
    });
  });
}
