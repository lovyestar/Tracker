import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/place.dart';

/// 앱 안에 포함된(assets) JSON 파일에서 장소 목록을 읽어오는 저장소입니다.
///
/// 초보자를 위한 설명:
///  - assets/yeongdo_tourism_db.json 파일을 문자열로 읽고, JSON으로 해석한 뒤,
///    "places" 배열을 [Place] 객체 목록으로 바꿔서 돌려줍니다.
///  - 한 번 읽은 결과는 [_cache]에 저장해 두었다가 다음부터는 다시 읽지 않습니다(빠름).
class PlaceRepository {
  /// assets 안의 DB 파일 경로. pubspec.yaml 의 assets 항목과 반드시 일치해야 합니다.
  static const String _assetPath = 'assets/yeongdo_tourism_db.json';

  List<Place>? _cache;

  /// JSON 전체(Map)를 저장해 두는 캐시입니다.
  /// 장소 목록뿐 아니라 tag_taxonomy 같은 최상위 데이터도 재사용하기 위함입니다.
  Map<String, dynamic>? _rawCache;

  /// assets 파일을 읽어 JSON(Map) 전체를 돌려줍니다. (내부용)
  ///
  /// 한 번 읽으면 [_rawCache]에 저장해 두었다가 다음부터는 다시 읽지 않습니다(빠름).
  Future<Map<String, dynamic>> _loadRaw() async {
    final cached = _rawCache;
    if (cached != null) return cached;

    // assets 파일을 문자열로 읽고 JSON(Map)으로 해석합니다.
    final jsonString = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> data =
        jsonDecode(jsonString) as Map<String, dynamic>;

    _rawCache = data;
    return data;
  }

  /// 모든 장소(68곳)를 읽어옵니다.
  Future<List<Place>> loadPlaces() async {
    // 이미 한 번 읽었다면 저장해 둔 값을 그대로 돌려줍니다.
    final cached = _cache;
    if (cached != null) return cached;

    // JSON 전체를 읽어 "places" 배열을 꺼내 Place 목록으로 변환합니다.
    final data = await _loadRaw();
    final List<dynamic> rawList = (data['places'] as List<dynamic>?) ?? [];
    final places = rawList
        .whereType<Map<String, dynamic>>()
        .map(Place.fromJson)
        .toList();

    _cache = places;
    return places;
  }

  /// 장소 이름 → 장소 id 매핑을 돌려줍니다.
  ///
  /// 실사진(assets/place_photos/{id}.jpg)을 코스/추천 화면에서 이름으로 찾을 때 씁니다.
  Future<Map<String, int>> loadNameToId() async {
    final places = await loadPlaces();
    return {for (final p in places) p.name: p.id};
  }

  /// DB에 들어 있는 카테고리 목록을 (중복 없이) 돌려줍니다.
  ///
  /// 필터 버튼을 만들 때 사용합니다. 순서는 등장 순서를 유지합니다.
  Future<List<String>> loadCategories() async {
    final places = await loadPlaces();
    final result = <String>[];
    for (final place in places) {
      for (final c in place.category) {
        if (!result.contains(c)) result.add(c);
      }
    }
    return result;
  }

  /// 태그 분류표(tag_taxonomy)를 읽어옵니다.
  ///
  /// 반환 형태: 그룹명 -> 그 그룹에 속한 태그 목록.
  ///  예) {"편의·접근성": ["주차 가능","주차 어려움",...], "분위기·테마": [...], ...}
  /// DB에 tag_taxonomy 가 없으면 빈 맵({})을 돌려줍니다(안전).
  Future<Map<String, List<String>>> loadTagTaxonomy() async {
    final data = await _loadRaw();

    // 최상위 "tag_taxonomy" 를 꺼냅니다. 없으면 빈 맵.
    final raw = data['tag_taxonomy'];
    if (raw is! Map) return <String, List<String>>{};

    final result = <String, List<String>>{};
    raw.forEach((groupName, tagList) {
      // 각 그룹의 값이 배열일 때만 문자열 목록으로 변환합니다.
      if (tagList is List) {
        result[groupName.toString()] =
            tagList.map((e) => e.toString()).toList();
      }
    });
    return result;
  }
}
