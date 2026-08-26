import 'package:flutter/material.dart';

import '../models/active_course.dart';
import '../models/place.dart';
import '../services/active_course_store.dart';
import '../services/place_repository.dart';
import 'course_map_screen.dart';
import 'map_screen.dart';

/// 지도 탭입니다. 진행 중 코스가 있으면 자동으로 코스 내비 화면(course_map)을,
/// 없으면 일반 지도 화면(MapScreen)을 보여줍니다.
class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveCourse?>(
      valueListenable: ActiveCourseStore.instance.notifier,
      builder: (_, active, __) {
        if (active == null) return const MapScreen();
        return _ActiveCourseHost(active: active);
      },
    );
  }
}

/// 진행 코스의 장소 좌표를 DB 에서 로드한 뒤 코스 내비 화면을 띄우는 호스트입니다.
class _ActiveCourseHost extends StatefulWidget {
  final ActiveCourse active;
  const _ActiveCourseHost({required this.active});

  @override
  State<_ActiveCourseHost> createState() => _ActiveCourseHostState();
}

class _ActiveCourseHostState extends State<_ActiveCourseHost> {
  final PlaceRepository _repo = PlaceRepository();
  List<Place>? _places;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final places = await _repo.loadPlaces();
    if (!mounted) return;
    setState(() => _places = places);
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;
    if (places == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return CourseMapScreen(
      // 코스가 바뀌면(경로 취소 후 다른 코스 시작) 새로 그리도록 키를 둡니다.
      key: ValueKey(widget.active.courseName),
      courseName: widget.active.courseName,
      stops: widget.active.recommendations,
      allPlaces: places,
    );
  }
}
