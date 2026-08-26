/// 코스 경유지 1곳입니다(이름 + 좌표). (#1 다중 위치)
class Waypoint {
  final String name;
  final double lat;
  final double lng;

  const Waypoint({required this.name, required this.lat, required this.lng});

  Map<String, dynamic> toMap() => {'name': name, 'lat': lat, 'lng': lng};

  factory Waypoint.fromMap(Map<String, dynamic> map) => Waypoint(
        name: (map['name'] ?? '').toString(),
        lat: _asDouble(map['lat']),
        lng: _asDouble(map['lng']),
      );

  static double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

/// 사용자가 직접 추가한 코스입니다. (시안 04 · 로컬 저장 전용)
///
/// 위치는 순서 있는 경유지 리스트([waypoints], 최소 4곳)로 지정합니다. (#1)
/// 구버전(단일 lat/lng) 데이터는 [fromMap] 에서 1곳짜리 경유지로 마이그레이션됩니다.
/// 사진은 갤러리에서 고른 경로들([photoPaths], 최대 10장)을 보관합니다. (#2)
class UserCourse {
  final String id;
  final String title;
  final String location;
  final String description;
  final List<String> categories;
  final DateTime createdAt;

  /// 순서 있는 경유지 목록(최소 4곳 권장). 지도/명소에서 골라 추가합니다.
  final List<Waypoint> waypoints;

  /// (구버전 호환) 대표 위치 좌표입니다. 신규 코스는 [waypoints] 를 사용합니다.
  final double? lat;
  final double? lng;

  /// 앱 문서 디렉토리에 복사해 둔 사진 파일 경로들입니다(최대 10장). 없으면 빈 목록.
  final List<String> photoPaths;

  const UserCourse({
    required this.id,
    required this.title,
    required this.location,
    required this.description,
    required this.categories,
    required this.createdAt,
    this.waypoints = const [],
    this.lat,
    this.lng,
    this.photoPaths = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'location': location,
        'description': description,
        'categories': categories,
        'created_at': createdAt.toIso8601String(),
        if (waypoints.isNotEmpty)
          'waypoints': waypoints.map((w) => w.toMap()).toList(),
        'lat': lat,
        'lng': lng,
        'photo_paths': photoPaths,
      };

  factory UserCourse.fromMap(Map<String, dynamic> map) {
    final lat = _asNullableDouble(map['lat']);
    final lng = _asNullableDouble(map['lng']);
    final location = (map['location'] ?? '').toString();

    // 경유지: 신규 'waypoints' 우선, 없으면 구버전 단일 좌표를 1곳으로 마이그레이션.
    var waypoints = (map['waypoints'] as List?)
            ?.whereType<Map>()
            .map((e) => Waypoint.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        const <Waypoint>[];
    if (waypoints.isEmpty && lat != null && lng != null) {
      waypoints = [
        Waypoint(name: location.isNotEmpty ? location : '위치 1', lat: lat, lng: lng),
      ];
    }

    return UserCourse(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      location: location,
      description: (map['description'] ?? '').toString(),
      categories:
          (map['categories'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      waypoints: waypoints,
      lat: lat,
      lng: lng,
      photoPaths:
          (map['photo_paths'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
    );
  }

  static double? _asNullableDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
