import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../models/user_course.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/user_course_store.dart';
import 'location_picker_screen.dart';

/// 코스 추가/수정 화면입니다. (시안 04 · 로컬 저장)
///
/// 위치는 순서 있는 경유지 리스트(최소 4곳)로 지정하고, 사진은 갤러리에서
/// 최대 10장까지 골라 앱 문서 디렉토리에 복사해 경로를 저장합니다.
/// [initial] 이 주어지면 기존 값을 프리필한 수정 모드로 동작합니다. (#4)
class AddCourseScreen extends StatefulWidget {
  final UserCourse? initial;

  const AddCourseScreen({super.key, this.initial});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final UserCourseStore _store = UserCourseStore();
  final FirebaseService _firebase = FirebaseService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final Set<String> _selected = {};
  bool _saving = false;

  /// 순서 있는 경유지 목록(최소 4곳). 지도/명소에서 골라 추가합니다. (#1)
  final List<Waypoint> _waypoints = [];

  /// 갤러리에서 고른 사진 경로들(최대 10장). (#2)
  final List<String> _photoPaths = [];

  static const int _maxPhotos = 10;
  static const int _minWaypoints = 4;

  bool get _isEditing => widget.initial != null;

  static const List<(String, IconData)> _categories = [
    ('맛집', Icons.restaurant),
    ('카페', Icons.local_cafe),
    ('관광지', Icons.account_balance),
    ('체험', Icons.brush),
    ('쇼핑', Icons.shopping_bag),
    ('숙소', Icons.hotel),
    ('자연', Icons.park),
    ('문화', Icons.museum),
    ('야경', Icons.nightlight),
    ('기타', Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _location.addListener(() => setState(() {}));
    _desc.addListener(() => setState(() {}));
    _prefill();
  }

  /// 수정 모드일 때 기존 코스 값을 채워 넣습니다. (#4)
  void _prefill() {
    final initial = widget.initial;
    if (initial == null) return;
    _title.text = initial.title;
    _location.text = initial.location;
    _desc.text = initial.description;
    _selected.addAll(initial.categories);
    _waypoints.addAll(initial.waypoints);
    _photoPaths.addAll(initial.photoPaths);
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _selected.isNotEmpty &&
      _waypoints.length >= _minWaypoints;

  Future<void> _submit() async {
    if (_saving) return;
    if (_waypoints.length < _minWaypoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(MessagesKo.addCourseWaypointTooFew)),
      );
      return;
    }
    if (!_valid) return;
    setState(() => _saving = true);

    // 위치 라벨: 입력값 우선, 없으면 첫 경유지 이름으로 대표 표기.
    final location = _location.text.trim().isNotEmpty
        ? _location.text.trim()
        : _waypoints.first.name;
    // 하위호환 대표 좌표: 첫 경유지.
    final first = _waypoints.first;

    final course = UserCourse(
      id: widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      location: location,
      description: _desc.text.trim(),
      categories: _selected.toList(),
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      waypoints: List<Waypoint>.from(_waypoints),
      lat: first.lat,
      lng: first.lng,
      photoPaths: List<String>.from(_photoPaths),
    );

    if (_isEditing) {
      await _store.updateCourse(course);
    } else {
      await _store.addCourse(course);
    }
    // 로그인 상태면 클라우드에도 저장(사진 제외; 실패해도 로컬 우선).
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) await _firebase.uploadCourse(uid, course);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? '코스가 수정됐데이!' : '코스가 등록됐데이! 고맙습니더')),
    );
    Navigator.pop(context, true);
  }

  /// 방법 A: 지도 피커에서 좌표를 골라 경유지로 추가합니다. (#1)
  Future<void> _addFromMap() async {
    final result = await Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
      ),
    );
    if (result == null || !mounted) return;
    final name = (result.name != null && result.name!.isNotEmpty)
        ? result.name!
        : '경유지 ${_waypoints.length + 1}';
    setState(() {
      _waypoints
          .add(Waypoint(name: name, lat: result.lat, lng: result.lng));
    });
  }

  /// 방법 B: 내장 DB 명소를 골라 경유지로 추가합니다. (#1)
  Future<void> _addFromPlaces() async {
    final result = await Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );
    if (result == null || !mounted) return;
    final name = (result.name != null && result.name!.isNotEmpty)
        ? result.name!
        : '경유지 ${_waypoints.length + 1}';
    setState(() {
      _waypoints
          .add(Waypoint(name: name, lat: result.lat, lng: result.lng));
    });
  }

  void _removeWaypoint(int index) {
    setState(() => _waypoints.removeAt(index));
  }

  void _reorderWaypoint(int oldIndex, int newIndex) {
    setState(() {
      final item = _waypoints.removeAt(oldIndex);
      _waypoints.insert(newIndex, item);
    });
  }

  /// 갤러리에서 사진을 골라(최대 10장) 앱 문서 디렉토리에 복사 후 경로를 저장합니다. (#2)
  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photoPaths.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(MessagesKo.addCoursePhotoMax)),
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;
      final dir = await getApplicationDocumentsDirectory();
      for (final x in picked.take(remaining)) {
        final ext = x.path.split('.').last;
        final dest = '${dir.path}/course_'
            '${DateTime.now().microsecondsSinceEpoch}_${_photoPaths.length}.$ext';
        await File(x.path).copy(dest);
        _photoPaths.add(dest);
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('[AddCourse] 사진 선택 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했데이. 다시 해보이소.')),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() => _photoPaths.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(_isEditing ? '코스 수정' : '코스 추가')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _label('제목', trailing: '${_title.text.characters.length}/50'),
            TextField(
              controller: _title,
              maxLength: 50,
              buildCounter: _noCounter,
              decoration: const InputDecoration(hintText: '코스 제목을 입력하세요'),
            ),
            const SizedBox(height: 18),
            _label('경유지', trailing: '${_waypoints.length}곳 · 최소 $_minWaypoints곳'),
            const Text(MessagesKo.addCourseWaypointHint,
                style: TextStyle(fontSize: 12.5, color: AppTheme.bodyBrown)),
            const SizedBox(height: 10),
            _waypointSection(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('지도에서 추가'),
                    onPressed: _addFromMap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.place_outlined, size: 18),
                    label: const Text('명소에서 추가'),
                    onPressed: _addFromPlaces,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _label('위치 이름', trailing: '선택'),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                  hintText: '대표 위치 이름(비우면 첫 경유지로 표시)'),
            ),
            const SizedBox(height: 18),
            _label('사진', trailing: '${_photoPaths.length}/$_maxPhotos'),
            _photoSection(),
            const SizedBox(height: 6),
            const Text(MessagesKo.addCoursePhotoHint,
                style: TextStyle(fontSize: 12.5, color: AppTheme.bodyBrown)),
            const SizedBox(height: 18),
            _label('설명', trailing: '${_desc.text.characters.length}/500'),
            TextField(
              controller: _desc,
              maxLength: 500,
              maxLines: 4,
              buildCounter: _noCounter,
              decoration:
                  const InputDecoration(hintText: '코스에 대한 설명을 입력해주세요'),
            ),
            const SizedBox(height: 18),
            _label('카테고리', trailing: '여러 개 선택 가능'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (name, icon) in _categories)
                  FilterChip(
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: _selected.contains(name)
                          ? Colors.white
                          : AppTheme.bodyBrown,
                    ),
                    label: Text(name),
                    selected: _selected.contains(name),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _selected.add(name);
                      } else {
                        _selected.remove(name);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_isEditing ? '수정 저장하기' : '코스 등록하기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: _valid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _noCounter(BuildContext context,
          {required int currentLength,
          required bool isFocused,
          required int? maxLength}) =>
      null;

  Widget _label(String text, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.warmBrown)),
          const Spacer(),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.bodyBrown)),
        ],
      ),
    );
  }

  /// 경유지 영역: 순서 있는 목록(드래그 재정렬 + 삭제). 비어 있으면 안내 프레임. (#1)
  Widget _waypointSection() {
    if (_waypoints.isEmpty) {
      return Container(
        height: 92,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.cardCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.brownBorder, width: 1.5),
        ),
        child: const Text('아직 경유지가 없데이. 아래 버튼으로 자리를 골라봐라!',
            style: TextStyle(color: AppTheme.bodyBrown)),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _waypoints.length,
      onReorderItem: _reorderWaypoint,
      itemBuilder: (context, i) => _waypointTile(i),
    );
  }

  Widget _waypointTile(int index) {
    final w = _waypoints[index];
    return Container(
      key: ValueKey('wp_${w.name}_${w.lat}_${w.lng}_$index'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.skyBlue,
              shape: BoxShape.circle,
            ),
            child: Text('${index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy)),
                const SizedBox(height: 2),
                Text(
                    '위도 ${w.lat.toStringAsFixed(4)}, 경도 ${w.lng.toStringAsFixed(4)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.bodyBrown)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: AppTheme.coralRed),
            onPressed: () => _removeWaypoint(index),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.drag_handle, color: AppTheme.bodyBrown),
            ),
          ),
        ],
      ),
    );
  }

  /// 사진 영역: 고른 사진 썸네일(삭제 가능) + (최대 미만이면) 추가 버튼. (#2)
  Widget _photoSection() {
    if (_photoPaths.isEmpty) return _addPhotoFrame();
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:
            _photoPaths.length + (_photoPaths.length < _maxPhotos ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i >= _photoPaths.length) return _addPhotoTile();
          return _photoThumb(i);
        },
      ),
    );
  }

  Widget _photoThumb(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_photoPaths[index]),
            width: 108,
            height: 108,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 108,
              height: 108,
              color: AppTheme.cardCream,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppTheme.bodyBrown),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppTheme.coralRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addPhotoTile() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: Container(
        width: 108,
        height: 108,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.cardCream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.brownBorder, width: 1.5),
        ),
        child: const Icon(Icons.add_a_photo_outlined,
            size: 28, color: AppTheme.bodyBrown),
      ),
    );
  }

  Widget _addPhotoFrame() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.cardCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.brownBorder, width: 1.5),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 40, color: AppTheme.bodyBrown),
            SizedBox(height: 8),
            Text('사진을 추가해주세요 (최대 10장)',
                style: TextStyle(color: AppTheme.bodyBrown)),
          ],
        ),
      ),
    );
  }
}
