import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_app/models/active_course.dart';
import 'package:tracker_app/models/recommendation.dart';
import 'package:tracker_app/services/active_course_store.dart';

/// 진행 중 코스(내비게이션 모드)의 직렬화 + 저장소 동작을 검증합니다.
///  - ActiveCourse JSON 라운드트립이 이름/추천 목록을 보존하는지
///  - ActiveCourseStore 가 start/clear 후 재로딩(init)에도 상태를 유지/해제하는지
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rec = Recommendation(
    placeName: '흰여울문화마을',
    reason: '바다뷰 산책',
    duration: '40분',
    estimatedCost: '무료',
  );

  group('ActiveCourse 직렬화', () {
    test('toJson/fromJson 라운드트립이 값을 보존한다', () {
      const course = ActiveCourse(
        courseName: '노을 감성 코스',
        recommendations: [rec],
      );

      final restored = ActiveCourse.fromJson(course.toJson());

      expect(restored.courseName, '노을 감성 코스');
      expect(restored.recommendations.length, 1);
      expect(restored.recommendations.first.placeName, '흰여울문화마을');
      expect(restored.recommendations.first.duration, '40분');
    });
  });

  group('ActiveCourseStore', () {
    test('start 후 init 을 다시 해도 진행 코스가 유지된다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ActiveCourseStore.instance;

      await store.start(const ActiveCourse(
        courseName: 'AI 맞춤 코스',
        recommendations: [rec],
      ));
      expect(store.current, isNotNull);
      expect(store.current!.courseName, 'AI 맞춤 코스');

      // 메모리 캐시를 비우고(재시작 흉내) 다시 로드해도 유지되어야 합니다.
      store.notifier.value = null;
      await store.init();
      expect(store.current, isNotNull);
      expect(store.current!.recommendations.first.placeName, '흰여울문화마을');
    });

    test('clear 하면 진행 상태가 해제되고 재로딩해도 비어 있다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ActiveCourseStore.instance;

      await store.start(const ActiveCourse(
        courseName: '태종대 코스',
        recommendations: [rec],
      ));
      await store.clear();
      expect(store.current, isNull);

      store.notifier.value = null;
      await store.init();
      expect(store.current, isNull);
    });
  });
}
