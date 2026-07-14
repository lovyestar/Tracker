import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/preset_courses.dart';
import '../models/place.dart';
import '../models/preset_course.dart';
import '../models/user_course.dart';
import '../services/place_repository.dart';
import '../services/user_course_store.dart';
import '../widgets/place_photo.dart';
import '../widgets/retro.dart';
import '../widgets/yeongmaegi_bubble.dart';
import 'add_course_screen.dart';
import 'course_start.dart';

/// 사용자 추천 코스 목록 화면입니다. (레트로 선셋 시안 03)
///  - 검색 + 카테고리 칩 필터
///  - 프리셋 코스 11선(출발 가능) + 사용자 추가 코스(로컬)
class PresetCoursesScreen extends StatefulWidget {
  const PresetCoursesScreen({super.key});

  @override
  State<PresetCoursesScreen> createState() => _PresetCoursesScreenState();
}

class _PresetCoursesScreenState extends State<PresetCoursesScreen> {
  final UserCourseStore _userStore = UserCourseStore();
  final TextEditingController _search = TextEditingController();

  static const List<String> _categories = ['전체', '감성', '자연', '맛집', '포토', '골목'];
  String _category = '전체';
  String _query = '';
  List<UserCourse> _userCourses = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
    _loadUserCourses();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadUserCourses() async {
    final courses = await _userStore.loadCourses();
    if (!mounted) return;
    setState(() => _userCourses = courses);
  }

  Future<void> _openAddCourse() async {
    // rootNavigator 로 전체 화면 라우트를 띄워 하단 내비 위로 올라오게 합니다.
    final added = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => const AddCourseScreen()),
    );
    if (added == true) {
      await _loadUserCourses();
    }
  }

  bool _matchesQuery(String haystack) =>
      _query.isEmpty || haystack.toLowerCase().contains(_query.toLowerCase());

  bool _matchesCategory(String haystack) =>
      _category == '전체' || haystack.contains(_category);

  List<PresetCourse> get _filteredPresets {
    return kPresetCourses.where((c) {
      final text =
          '${c.theme} ${c.target} ${c.placeNames.join(' ')}';
      return _matchesQuery(text) && _matchesCategory(text);
    }).toList();
  }

  List<UserCourse> get _filteredUserCourses {
    return _userCourses.where((c) {
      final text = '${c.title} ${c.location} ${c.description} '
          '${c.categories.join(' ')}';
      return _matchesQuery(text) && _matchesCategory(text);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final presets = _filteredPresets;
    final userCourses = _filteredUserCourses;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.flag_rounded),
        label: const Text('코스 만들기',
            style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: _openAddCourse,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
          children: [
            Row(
              children: [
                Text('Tracker', style: AppTheme.logo(size: 26)),
                const Spacer(),
                const PostageFrame(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('YEONGDO',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: AppTheme.bodyBrown,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('사용자 추천 코스', style: AppTheme.heading(size: 22)),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: AppTheme.bodyBrown),
                hintText: '코스, 장소, 키워드 검색',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  return ChoiceChip(
                    label: Text(cat),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (presets.isEmpty && userCourses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: YeongmaegiBubble(
                    message: '검색 결과가 없데이. 다른 키워드로 찾아보이소!'),
              ),
            for (final c in userCourses) ...[
              const SizedBox(height: 12),
              _userCourseCard(c),
            ],
            for (final c in presets) ...[
              const SizedBox(height: 12),
              _presetCard(c),
            ],
          ],
        ),
      ),
    );
  }

  Widget _presetCard(PresetCourse course) {
    final photoName =
        course.placeNames.isNotEmpty ? course.placeNames.first : null;
    final tags = <String>[
      course.theme,
      ...course.target.split(RegExp(r'[ ,/]+')).where((s) => s.isNotEmpty),
    ].take(3).toList();
    return RetroCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PlacePhoto(placeName: photoName, height: 128, radius: 22),
              const Positioned(top: 10, left: 10, child: BestBadge()),
              if (course.adultOnly)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: BestBadge(text: '19+', color: AppTheme.coralRed),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy)),
                const SizedBox(height: 6),
                HashtagRow(tags: tags),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InfoTag(
                          icon: Icons.schedule,
                          text: course.totalTime,
                          color: AppTheme.skyBlue,
                          flexible: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InfoTag(
                          icon: Icons.payments_outlined,
                          text: course.budget,
                          color: AppTheme.skyBlue,
                          flexible: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InfoTag(
                          icon: Icons.stairs,
                          text: '계단 ${course.stairs}',
                          color: AppTheme.skyBlue,
                          flexible: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCourseCard(UserCourse course) {
    return RetroCard(
      onTap: () => _showUserCourse(course),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(course.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warmBrown)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('MY',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.gold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(course.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.bodyBrown)),
                if (course.categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final c in course.categories.take(3))
                        InfoTag(icon: Icons.tag, text: c),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _courseThumb(course, 92),
        ],
      ),
    );
  }

  /// 코스 썸네일: 첫 사진이 있으면 Image.file, 없거나 유실이면 플레이스홀더.
  Widget _courseThumb(UserCourse course, double size) {
    final path = course.photoPaths.isNotEmpty ? course.photoPaths.first : null;
    if (path == null || !File(path).existsSync()) {
      return CourseThumb(width: size, height: size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CourseThumb(width: size, height: size),
      ),
    );
  }

  void _showUserCourse(UserCourse course) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warmBrown)),
              const SizedBox(height: 6),
              if (course.photoPaths.isNotEmpty) ...[
                _photoStrip(course.photoPaths),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 16, color: AppTheme.bodyBrown),
                  const SizedBox(width: 4),
                  Expanded(child: Text(course.location)),
                ],
              ),
              if (course.categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in course.categories)
                      Chip(label: Text(c)),
                  ],
                ),
              ],
              if (course.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(course.description,
                    style: const TextStyle(
                        color: AppTheme.bodyBrown, height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 코스 상세의 사진 가로 스트립. 유실 파일은 건너뜁니다.
  Widget _photoStrip(List<String> paths) {
    final valid = paths.where((p) => File(p).existsSync()).toList();
    if (valid.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: valid.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(valid[i]),
            width: 160,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// 프리셋 코스 상세 화면입니다. 장소 순서를 보여주고 출발합니다.
class CourseDetailScreen extends StatefulWidget {
  final PresetCourse course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final PlaceRepository _repo = PlaceRepository();
  List<Place> _places = [];

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
    final course = widget.course;
    return Scaffold(
      appBar: AppBar(title: Text('${course.theme} 코스')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            YeongmaegiBubble(
              message: '${course.target}한테 딱인 코스다. 순서대로 돌면 된다카이!',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text('총 ${course.totalTime}')),
                Chip(
                    avatar: const Icon(Icons.payments_outlined, size: 16),
                    label: Text('예산 ${course.budget}')),
                Chip(
                    avatar: const Icon(Icons.stairs, size: 16),
                    label: Text('계단 ${course.stairs}')),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < course.stops.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RetroCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppTheme.burntOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      PlacePhoto(
                          placeName: course.stops[i].placeName,
                          width: 60,
                          height: 60,
                          radius: 14),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(course.stops[i].placeName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppTheme.navy)),
                            const SizedBox(height: 4),
                            Text(course.stops[i].reason,
                                style: const TextStyle(
                                    color: AppTheme.bodyText, height: 1.4)),
                            const SizedBox(height: 6),
                            InfoTag(
                                icon: Icons.schedule,
                                text: course.stops[i].duration,
                                color: AppTheme.skyBlue),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('이 코스로 출발'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: _places.isEmpty ? null : _start,
            ),
          ],
        ),
      ),
    );
  }

  void _start() {
    // 진행 중 코스로 등록 → 지도 탭이 자동으로 코스 내비를 보여줍니다.
    startActiveCourse(
      context,
      courseName: widget.course.title,
      stops: widget.course.stops,
    );
  }
}
