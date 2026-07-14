import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/models/user_course.dart';

/// UserCourse 직렬화 테스트입니다.
/// 신규 필드(lat/lng/photoPaths)가 toMap/fromMap 을 왕복해도 보존되는지,
/// 그리고 구버전(좌표/사진 없이 저장된) 데이터도 안전하게 읽히는지 검증합니다.
void main() {
  group('UserCourse 직렬화', () {
    test('toMap/fromMap 라운드트립이 좌표·사진을 보존한다', () {
      final now = DateTime.now();
      final course = UserCourse(
        id: 'abc',
        title: '내 코스',
        location: '흰여울문화마을',
        description: '바다뷰 산책',
        categories: const ['자연', '포토'],
        createdAt: now,
        lat: 35.07812,
        lng: 129.04567,
        photoPaths: const ['/a/1.jpg', '/a/2.jpg'],
      );

      final restored = UserCourse.fromMap(course.toMap());

      expect(restored.id, 'abc');
      expect(restored.title, '내 코스');
      expect(restored.location, '흰여울문화마을');
      expect(restored.categories, ['자연', '포토']);
      expect(restored.lat, closeTo(35.07812, 1e-9));
      expect(restored.lng, closeTo(129.04567, 1e-9));
      expect(restored.photoPaths, ['/a/1.jpg', '/a/2.jpg']);
    });

    test('구버전 데이터(좌표·사진 없음)도 안전하게 읽힌다', () {
      final legacy = <String, dynamic>{
        'id': 'old',
        'title': '옛 코스',
        'location': '태종대',
        'description': '',
        'categories': ['관광지'],
        'created_at': DateTime.now().toIso8601String(),
      };

      final restored = UserCourse.fromMap(legacy);

      expect(restored.lat, isNull);
      expect(restored.lng, isNull);
      expect(restored.photoPaths, isEmpty);
      expect(restored.categories, ['관광지']);
      expect(restored.waypoints, isEmpty);
    });

    test('경유지 리스트가 순서대로 라운드트립된다 (#1)', () {
      final course = UserCourse(
        id: 'wp',
        title: '경유지 코스',
        location: '영도 한 바퀴',
        description: '',
        categories: const ['관광지'],
        createdAt: DateTime.now(),
        waypoints: const [
          Waypoint(name: '흰여울문화마을', lat: 35.078, lng: 129.045),
          Waypoint(name: '절영해안산책로', lat: 35.076, lng: 129.047),
          Waypoint(name: '태종대', lat: 35.053, lng: 129.087),
          Waypoint(name: '국립해양박물관', lat: 35.075, lng: 129.078),
        ],
      );

      final restored = UserCourse.fromMap(course.toMap());

      expect(restored.waypoints.length, 4);
      expect(restored.waypoints.map((w) => w.name).toList(),
          ['흰여울문화마을', '절영해안산책로', '태종대', '국립해양박물관']);
      expect(restored.waypoints.first.lat, closeTo(35.078, 1e-9));
      expect(restored.waypoints.last.lng, closeTo(129.078, 1e-9));
    });

    test('구버전 단일 좌표는 1곳짜리 경유지로 마이그레이션된다 (#1)', () {
      final legacy = <String, dynamic>{
        'id': 'mig',
        'title': '옛 단일 좌표 코스',
        'location': '흰여울문화마을',
        'description': '',
        'categories': ['자연'],
        'created_at': DateTime.now().toIso8601String(),
        'lat': 35.078,
        'lng': 129.045,
      };

      final restored = UserCourse.fromMap(legacy);

      expect(restored.waypoints.length, 1);
      expect(restored.waypoints.single.name, '흰여울문화마을');
      expect(restored.waypoints.single.lat, closeTo(35.078, 1e-9));
    });
  });
}
