import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';

/// 카카오 로컬 키워드 검색 결과 1건입니다. (#7)
class KakaoPlace {
  final String name;
  final String address;
  final double lat;
  final double lng;

  const KakaoPlace({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

/// 카카오 로컬 REST 키워드 검색 서비스입니다. (#7 지도에서 이름 검색으로 위치 추가)
///
/// GET https://dapi.kakao.com/v2/local/search/keyword.json
///  - 헤더: Authorization: KakaoAK {REST 키}
///  - 파라미터: query(키워드), x(경도), y(위도), radius(m), sort=distance
///  - 지도 중심(영도) 기준 반경 우선으로 검색합니다.
class KakaoLocalService {
  static const _endpoint =
      'https://dapi.kakao.com/v2/local/search/keyword.json';
  static const _timeout = Duration(seconds: 10);

  final http.Client _client;
  KakaoLocalService({http.Client? client}) : _client = client ?? http.Client();

  /// 키워드로 장소를 검색합니다. 실패/파싱 오류 시 예외를 던지지 않고 빈 목록.
  ///
  /// [lat]/[lng] 는 검색 중심(현재 지도 중심). 중심 반경([radius]m) 안을
  /// 거리순으로 우선 정렬해 영도권 결과가 위로 오도록 합니다.
  Future<List<KakaoPlace>> searchKeyword(
    String query, {
    required double lat,
    required double lng,
    int radius = 20000,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'query': trimmed,
        'x': lng.toString(),
        'y': lat.toString(),
        'radius': radius.toString(),
        'sort': 'distance',
      });
      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK ${ApiKeys.kakaoRestApiKey}',
        },
      ).timeout(_timeout);
      if (resp.statusCode != 200) return const [];
      return parseResponse(resp.body);
    } catch (_) {
      return const [];
    }
  }

  /// 카카오 응답 본문(JSON 문자열)을 [KakaoPlace] 목록으로 파싱합니다.
  ///
  /// 방어적으로 파싱합니다: documents 없음/타입 이상/좌표 결측은 건너뜁니다.
  /// (테스트에서 이 메서드를 직접 검증합니다.)
  static List<KakaoPlace> parseResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const [];
      final docs = decoded['documents'];
      if (docs is! List) return const [];
      final result = <KakaoPlace>[];
      for (final d in docs) {
        if (d is! Map) continue;
        final name = (d['place_name'] ?? '').toString();
        final lng = double.tryParse((d['x'] ?? '').toString());
        final lat = double.tryParse((d['y'] ?? '').toString());
        if (name.isEmpty || lat == null || lng == null) continue;
        final road = (d['road_address_name'] ?? '').toString();
        final addr = (d['address_name'] ?? '').toString();
        result.add(KakaoPlace(
          name: name,
          address: road.isNotEmpty ? road : addr,
          lat: lat,
          lng: lng,
        ));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}
