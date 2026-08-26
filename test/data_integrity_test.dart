import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/constants/preset_courses.dart';
import 'package:tracker_app/models/place.dart';

/// 데이터 정합성 테스트입니다. (SPEC §8-2)
void main() {
  // assets 파일을 파일시스템에서 직접 읽습니다(테스트는 프로젝트 루트에서 실행).
  final raw = File('assets/yeongdo_tourism_db.json').readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final places = (data['places'] as List)
      .whereType<Map<String, dynamic>>()
      .map(Place.fromJson)
      .toList();

  group('DB(yeongdo_tourism_db.json) 정합성', () {
    test('장소는 69곳이다', () {
      expect(places.length, 69);
    });

    test('모든 장소에 필수 필드(id/name/lat/lng)가 있다', () {
      for (final p in places) {
        expect(p.id, greaterThan(0), reason: 'id 누락: ${p.name}');
        expect(p.name.trim().isNotEmpty, isTrue, reason: 'name 누락(id=${p.id})');
        expect(p.lat, isNot(0.0), reason: 'lat 누락: ${p.name}');
        expect(p.lng, isNot(0.0), reason: 'lng 누락: ${p.name}');
      }
    });

    test('lat/lng 가 영도 범위 안에 있다 (35.03~35.12, 129.03~129.10)', () {
      for (final p in places) {
        expect(p.lat, inInclusiveRange(35.03, 35.12),
            reason: '위도 범위 벗어남: ${p.name} (${p.lat})');
        expect(p.lng, inInclusiveRange(129.03, 129.10),
            reason: '경도 범위 벗어남: ${p.name} (${p.lng})');
      }
    });

    test('장소 이름은 중복되지 않는다', () {
      final names = places.map((p) => p.name).toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('프리셋 코스 11선 정합성', () {
    test('코스는 11개다', () {
      expect(kPresetCourses.length, 11);
    });

    test('모든 코스의 place_name 이 DB name 에 존재한다', () {
      final dbNames = places.map((p) => p.name).toSet();
      for (final course in kPresetCourses) {
        for (final stop in course.stops) {
          expect(dbNames.contains(stop.placeName), isTrue,
              reason: 'DB에 없는 장소: "${stop.placeName}" (코스 ${course.id})');
        }
      }
    });

    test('모든 코스 stop 의 4필드가 비어있지 않다', () {
      for (final course in kPresetCourses) {
        for (final stop in course.stops) {
          expect(stop.placeName.isNotEmpty, isTrue);
          expect(stop.reason.isNotEmpty, isTrue);
          expect(stop.duration.isNotEmpty, isTrue);
          expect(stop.estimatedCost.isNotEmpty, isTrue);
        }
      }
    });
  });
}
