/// 영도 관광 장소 1곳을 나타내는 데이터 모델입니다.
///
/// assets/yeongdo_tourism_db.json 의 "places" 배열 각 원소를 그대로 담습니다.
/// 초보자를 위한 설명:
///  - 이 클래스는 순수 Dart 파일입니다(지도 패키지와 무관).
///  - JSON(맵 형태)을 받아서 Place 객체로 바꾸는 [fromJson] 생성자를 제공합니다.
///  - 모든 필드는 null-safe 하게 처리했습니다(값이 없어도 앱이 죽지 않도록).
class Place {
  final int id;
  final String name;

  /// 카테고리 목록입니다. 예: ["맛집"], ["자연"], ["골목"]. (Todo 표준 7종)
  /// DB에서는 문자열 배열(list[str])로 들어옵니다.
  final List<String> category;

  final double lat;
  final double lng;

  final String address;
  final String phone;

  /// 장소 설명
  final String desc;

  /// 방문 팁 (비어 있을 수 있음)
  final String tip;

  /// 후기 요약
  final String reviewSummary;

  final String kakaoCategory;
  final String placeUrl;

  /// 태그 목록입니다. 예: ["주차 가능","바다뷰"].
  /// DB의 "tags" 필드(문자열 배열)에서 옵니다. 태그가 없으면 빈 목록입니다.
  /// 태그 다중 필터(AND 조건)에서 사용합니다.
  final List<String> tags;

  /// 경사 정도입니다. "steep"|"moderate"|"flat"|"unknown".
  /// DB의 accessibility.gradient 에서 옵니다. 값이 없으면 "unknown".
  final String gradient;

  /// 계단 정도입니다. "many"|"some"|"none"|"unknown".
  /// DB의 accessibility.stairs 에서 옵니다. 값이 없으면 "unknown".
  final String stairs;

  /// 엘리베이터 유무입니다. "yes"|"no"|"unknown".
  /// DB의 accessibility.elevator 에서 옵니다. 값이 없으면 "unknown".
  final String elevator;

  /// 주차 가능 여부입니다. true(가능)|false(어려움)|null(불명).
  /// DB의 accessibility.parking 에서 옵니다. 값이 없으면 null.
  final bool? parking;

  /// 위험 등급입니다. "none"|"caution"|"high".
  /// DB의 danger.level 에서 옵니다. 값이 없으면 "none".
  final String dangerLevel;

  /// 위험 사유(한국어). 위험이 없으면 빈 문자열입니다.
  /// DB의 danger.reason 에서 옵니다.
  final String dangerReason;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.address,
    required this.phone,
    required this.desc,
    required this.tip,
    required this.reviewSummary,
    required this.kakaoCategory,
    required this.placeUrl,
    this.tags = const [],
    this.gradient = 'unknown',
    this.stairs = 'unknown',
    this.elevator = 'unknown',
    this.parking,
    this.dangerLevel = 'none',
    this.dangerReason = '',
  });

  /// JSON(Map) 한 개를 Place 객체로 변환합니다.
  ///
  /// 값이 없거나 타입이 조금 달라도 앱이 죽지 않도록 안전하게 변환합니다.
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      category: _asStringList(json['category']),
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      address: _asString(json['address']),
      phone: _asString(json['phone']),
      desc: _asString(json['desc']),
      tip: _asString(json['tip']),
      reviewSummary: _asString(json['review_summary']),
      kakaoCategory: _asString(json['kakao_category']),
      placeUrl: _asString(json['place_url']),
      // 태그 파싱: 값이 없거나 배열이 아니면 빈 목록으로 안전하게 처리합니다.
      tags: _asStringList(json['tags']),
      // 접근성 파싱: accessibility 객체가 없어도 안전하게 기본값 처리합니다.
      gradient: _asString(_nested(json['accessibility'], 'gradient', 'unknown')),
      stairs: _asString(_nested(json['accessibility'], 'stairs', 'unknown')),
      elevator: _asString(_nested(json['accessibility'], 'elevator', 'unknown')),
      parking: _asNullableBool(_nested(json['accessibility'], 'parking', null)),
      // 위험 파싱: danger 객체가 없어도 안전하게 기본값 처리합니다.
      dangerLevel: _asString(_nested(json['danger'], 'level', 'none')),
      dangerReason: _asString(_nested(json['danger'], 'reason', '')),
    );
  }

  /// 중첩 객체에서 안전하게 값을 꺼냅니다. 없으면 기본값을 돌려줍니다.
  static Object? _nested(Object? obj, String key, Object? fallback) {
    if (obj is Map && obj[key] != null) return obj[key];
    return fallback;
  }

  /// 경사를 한국어 라벨로 돌려줍니다. unknown 이면 빈 문자열.
  String get gradientLabel => const {
        'steep': '경사 가파름',
        'moderate': '경사 약간',
        'flat': '평지',
      }[gradient] ??
      '';

  /// 계단을 한국어 라벨로 돌려줍니다. unknown 이면 빈 문자열.
  String get stairsLabel => const {
        'many': '계단 많음',
        'some': '계단 조금',
        'none': '계단 없음',
      }[stairs] ??
      '';

  /// 엘리베이터를 한국어 라벨로 돌려줍니다. unknown 이면 빈 문자열.
  String get elevatorLabel => const {
        'yes': '엘리베이터 있음',
        'no': '엘리베이터 없음',
      }[elevator] ??
      '';

  /// 주차를 한국어 라벨로 돌려줍니다. 불명(null)이면 빈 문자열.
  String get parkingLabel {
    if (parking == true) return '주차 가능';
    if (parking == false) return '주차 어려움';
    return '';
  }

  /// 위험 등급 한국어 라벨. none 이면 빈 문자열.
  String get dangerLabel => const {
        'caution': '주의',
        'high': '위험',
      }[dangerLevel] ??
      '';

  /// 접근성/위험 정보가 하나라도 있는지 여부(바텀시트 표시 판단용).
  bool get hasAccessInfo =>
      gradientLabel.isNotEmpty ||
      stairsLabel.isNotEmpty ||
      elevatorLabel.isNotEmpty ||
      parkingLabel.isNotEmpty ||
      dangerLevel != 'none';

  /// 대표 카테고리(목록의 첫 번째)를 돌려줍니다. 없으면 "기타".
  String get primaryCategory => category.isNotEmpty ? category.first : '기타';

  // ---- 아래는 안전 변환용 헬퍼들 (초보자는 그대로 두면 됩니다) ----

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static String _asString(Object? v) {
    if (v == null) return '';
    return v.toString();
  }

  static List<String> _asStringList(Object? v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    if (v is String && v.isNotEmpty) return [v];
    return <String>[];
  }

  /// true/false/null 을 안전하게 bool? 로 변환합니다.
  /// 문자열 "true"/"false" 도 처리하며, 그 외/누락은 null 입니다.
  static bool? _asNullableBool(Object? v) {
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }
}
