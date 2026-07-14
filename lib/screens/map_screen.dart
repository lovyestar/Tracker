import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// kakao_map_sdk 에도 Badge 라는 이름이 있어 Material 의 Badge 위젯과 충돌합니다.
// 이 화면에서는 kakao 의 Badge 를 쓰지 않으므로 kakao 쪽 Badge 만 숨깁니다.
// (지도 관련 API 사용에는 전혀 영향 없음)
import 'package:kakao_map_sdk/kakao_map_sdk.dart' hide Badge;

import '../constants/app_theme.dart';
import '../models/place.dart';
import '../services/place_repository.dart';
import '../widgets/map_markers.dart';
import '../widgets/my_location_button.dart';
import '../widgets/place_photo.dart';
import '../widgets/top_snack_bar.dart';
import 'add_course_screen.dart';

/// 지도 화면입니다.
///
/// 하는 일:
///  1) Kakao 지도를 영도 중심(35.080, 129.055)으로 보여줍니다.
///  2) DB(68곳)를 읽어 각 장소를 지도 위 마커(Poi)로 표시합니다.
///  3) 상단 카테고리 필터로 특정 카테고리만 볼 수 있습니다.
///  4) 마커를 탭하면 화면 아래에 정보 시트(장소 이름/설명/팁/후기/주소/전화)가 뜹니다.
///
/// 사용한 kakao_map_sdk 1.2.3 API는 모두 패키지 소스로 확인한 실제 시그니처입니다.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // 영도 중심 좌표
  static const LatLng _center = LatLng(35.080, 129.055);

  final PlaceRepository _repository = PlaceRepository();

  /// 지도가 준비되면 받게 되는 컨트롤러입니다. (마커 추가 등에 사용)
  KakaoMapController? _controller;

  /// DB에서 읽어온 전체 장소 목록
  List<Place> _places = [];

  /// 필터 버튼에 쓸 카테고리 목록
  List<String> _categories = [];

  /// 현재 선택된 카테고리. null 이면 "전체"를 의미합니다.
  String? _selectedCategory;

  /// 태그 분류표(그룹명 -> 태그목록). 태그 필터 시트를 만들 때 사용합니다.
  Map<String, List<String>> _tagTaxonomy = {};

  /// 현재 선택된 태그들(AND 조건). 비어 있으면 태그 필터를 적용하지 않습니다.
  Set<String> _selectedTags = {};

  /// 지도에 올린 마커들. 각 마커가 어떤 장소인지 함께 기억해 둡니다.
  final List<_PoiEntry> _poiEntries = [];

  bool _mapReady = false;

  /// 마커 정보 시트 재진입 가드. per-Poi onClick 과 지도 단위 onPoiClick 이
  /// 한 번의 탭에 둘 다 발화해 시트가 두 번 열리던 문제를 막습니다.
  /// 이미 열려 있거나, 같은 장소를 300ms 내 재호출하면 무시합니다.
  bool _sheetOpen = false;
  int? _lastSheetPlaceId;
  DateTime? _lastSheetAt;

  /// 현재 위치 스트림 + 스카이블루 점 마커.
  StreamSubscription<Position>? _positionSub;
  Poi? _myLocationPoi;
  Position? _lastPos;

  /// 위치 권한이 영구 거부됐을 때만 상단에 1회 안내 배너를 보여줍니다.
  bool _showLocPermBanner = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  /// DB(장소/카테고리)를 읽어옵니다. 지도가 이미 준비됐다면 마커도 다시 그립니다.
  Future<void> _loadData() async {
    final places = await _repository.loadPlaces();
    final categories = await _repository.loadCategories();
    final tagTaxonomy = await _repository.loadTagTaxonomy();
    if (!mounted) return;
    setState(() {
      _places = places;
      _categories = categories;
      _tagTaxonomy = tagTaxonomy;
    });
    if (_mapReady) {
      await _rebuildMarkers();
    }
  }

  /// 지도가 준비되었을 때 호출됩니다. (kakao_map_sdk 의 onMapReady 콜백)
  Future<void> _onMapReady(KakaoMapController controller) async {
    _controller = controller;
    _mapReady = true;
    if (_places.isNotEmpty) {
      await _rebuildMarkers();
    }
    // 지도 준비 전에 위치를 이미 받았다면 현재 위치 점을 지금 올립니다.
    final pos = _lastPos;
    if (pos != null) await _updateMyLocation(pos);
  }

  /// 현재 위치 스트림을 시작합니다.
  ///  - 권한이 denied 면 명시적으로 requestPermission 을 호출합니다.
  ///  - 스트림 첫 emit 이 느릴 수 있으니 즉시 1회 위치를 받아 점을 먼저 찍습니다.
  ///  - 권한 영구 거부 시에만 상단 안내 배너를 1회 띄우고, 그 외 실패는 조용히 무시합니다.
  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _showLocPermBanner = true);
        return;
      }
      if (permission == LocationPermission.denied) {
        // 이번엔 거부됨. 배너는 띄우지 않고(영구 거부 아님) 조용히 미표시.
        return;
      }
      // 즉시 1회 위치를 받아 현재 위치 점을 먼저 표시합니다.
      await _primeInitialPosition();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onPosition);
    } catch (_) {
      // 위치 실패는 지도 기능에 영향 없도록 조용히 무시합니다.
    }
  }

  /// 스트림 시작 전에 즉시 위치를 1회 받아 점을 먼저 찍습니다.
  Future<void> _primeInitialPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        debugPrint('[Map] 초기 위치(lastKnown) 수신');
        _onPosition(last);
      }
    } catch (_) {
      // 무시.
    }
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      debugPrint('[Map] 초기 위치(current) 수신');
      _onPosition(current);
    } catch (_) {
      // 무시(스트림이 이어받음).
    }
  }

  void _onPosition(Position pos) {
    _lastPos = pos;
    _updateMyLocation(pos);
  }

  /// 현재 위치 마커를 갱신합니다. 첫 위치 수신 시 스카이블루 점 생성, 이후 move 이동.
  Future<void> _updateMyLocation(Position pos) async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    final latlng = LatLng(pos.latitude, pos.longitude);
    final existing = _myLocationPoi;
    if (existing != null) {
      await existing.move(latlng, 300);
      debugPrint('[Map] 위치 점 이동됨: ${pos.latitude}, ${pos.longitude}');
      return;
    }
    try {
      final bytes = await MapMarkers.locationDot();
      _myLocationPoi = await controller.labelLayer.addPoi(
        latlng,
        style: PoiStyle(
          icon: KImage.fromData(bytes, 26, 26),
          anchor: const KPoint(0.5, 0.5),
        ),
        rank: 100,
      );
      debugPrint('[Map] 위치 점 추가됨: ${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      debugPrint('[Map] 현재 위치 마커 생성 실패(무시): $e');
    }
  }

  /// 현재 필터에 맞는 마커를 지도에 다시 그립니다.
  Future<void> _rebuildMarkers() async {
    final controller = _controller;
    if (controller == null) return;

    // 1) 기존 마커를 모두 지웁니다.
    for (final entry in _poiEntries) {
      await entry.poi.remove();
    }
    _poiEntries.clear();

    // 2) 마커에 사용할 스타일(아이콘 이미지 + 이름 텍스트)을 만듭니다.
    //    marker.png 는 pubspec.yaml 의 assets 에 등록되어 있어야 합니다.
    final style = PoiStyle(
      icon: KImage.fromAsset('assets/marker.png', 40, 40),
      textStyle: const [
        PoiTextStyle(color: Color(0xFF222222), size: 18),
      ],
    );

    // 3) 필터에 맞는 장소만 골라 마커를 추가합니다.
    for (final place in _filteredPlaces()) {
      final poi = await controller.labelLayer.addPoi(
        LatLng(place.lat, place.lng),
        style: style,
        text: place.name,
        // 마커를 탭하면 이 함수가 불립니다. (kakao_map_sdk 의 per-Poi onClick)
        onClick: () => _showPlaceSheet(place),
      );
      _poiEntries.add(_PoiEntry(poi: poi, place: place));
    }
  }

  /// 현재 필터(카테고리 + 태그)에 맞는 장소만 돌려줍니다.
  ///
  /// 조건:
  ///  1) 카테고리: _selectedCategory 가 null 이 아니면 그 카테고리를 가진 장소만 통과.
  ///  2) 태그(AND): _selectedTags 가 비어 있지 않으면,
  ///     선택된 "모든" 태그를 가진 장소만 통과합니다(every → AND 조건).
  List<Place> _filteredPlaces() {
    final selectedCategory = _selectedCategory;
    return _places.where((p) {
      // 1) 카테고리 조건
      if (selectedCategory != null && !p.category.contains(selectedCategory)) {
        return false;
      }
      // 2) 태그 조건(AND): 선택된 모든 태그를 이 장소가 가지고 있어야 통과
      if (_selectedTags.isNotEmpty &&
          !_selectedTags.every((t) => p.tags.contains(t))) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 카테고리 필터를 바꿉니다.
  Future<void> _onSelectCategory(String? category) async {
    setState(() => _selectedCategory = category);
    await _rebuildMarkers();
  }

  /// 태그 필터 시트를 엽니다.
  ///
  /// 시트에서 "적용"을 누르면 선택된 태그 집합(Set<String>)이 돌아옵니다.
  /// "초기화"만 누르고 적용하면 빈 집합이 돌아옵니다.
  /// 시트를 그냥 닫으면(바깥 탭 등) null 이 돌아오며, 이때는 아무것도 바꾸지 않습니다.
  Future<void> _openTagFilterSheet() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TagFilterSheet(
        taxonomy: _tagTaxonomy,
        initialSelected: _selectedTags,
      ),
    );

    // 취소(null)면 변경하지 않습니다.
    if (result == null) return;

    setState(() => _selectedTags = result);
    await _rebuildMarkers();
  }

  /// 마커 탭 시, 화면 아래에서 올라오는 정보 시트를 띄웁니다.
  ///
  /// 카카오맵(플랫폼 뷰) 위에서는 시트가 내용 높이를 즉시 못 재서 처음엔 바닥에
  /// 붙어 있다가 한두 번 쓸어올려야 보이는 문제가 있었습니다. (#1)
  /// [FractionallySizedBox] 로 화면 높이의 고정 비율을 주면 첫 프레임부터 확정 높이로
  /// 올라와서 탭 즉시 완전히 표시됩니다. 내용은 시트 내부에서 스크롤됩니다.
  void _showPlaceSheet(Place place) {
    final now = DateTime.now();
    if (_sheetOpen) return;
    if (_lastSheetPlaceId == place.id &&
        _lastSheetAt != null &&
        now.difference(_lastSheetAt!).inMilliseconds < 300) {
      return;
    }
    _lastSheetPlaceId = place.id;
    _lastSheetAt = now;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _PlaceInfoSheet(place: place),
      ),
    ).whenComplete(() => _sheetOpen = false);
  }

  /// 코스 만들기 화면을 엽니다(등록 후 스낵바 안내).
  /// rootNavigator 로 전체 화면 라우트를 띄워 하단 내비 위로 올라오게 합니다.
  Future<void> _openAddCourse() async {
    final added = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => const AddCourseScreen()),
    );
    if (added == true && mounted) {
      showTopSnackBar(context, message: '코스가 저장 탭 · 코스 목록에 추가됐데이!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('트래커 · 영도 관광 가이드'),
        actions: [
          // 태그 다중 필터 버튼. 선택된 태그 개수를 배지로 함께 표시합니다.
          IconButton(
            tooltip: '태그 필터',
            onPressed: _openTagFilterSheet,
            icon: Badge(
              // 선택된 태그가 없으면 배지를 숨깁니다.
              isLabelVisible: _selectedTags.isNotEmpty,
              label: Text('${_selectedTags.length}'),
              child: const Icon(Icons.tune),
            ),
          ),
        ],
      ),
      // MainShell 이 extendBody + BottomAppBar(높이 66) 를 쓰므로, 탭 내부 Scaffold 의
      // FAB 는 기본 위치에서 하단 내비에 가려집니다. 내비 높이만큼 위로 띄웁니다. 114
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 114),
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.flag_rounded),
          label: const Text('코스 만들기',
              style: TextStyle(fontWeight: FontWeight.w800)),
          onPressed: _openAddCourse,
        ),
      ),
      body: Column(
        children: [
          if (_showLocPermBanner) _locPermBanner(),
          _buildCategoryBar(),
          Expanded(
            child: Stack(
              children: [
                KakaoMap(
                  option: const KakaoMapOption(
                    position: _center,
                    zoomLevel: 15,
                    mapType: MapType.normal,
                  ),
                  onMapReady: _onMapReady,
                  // 위젯 단위 Poi 클릭 콜백. per-Poi onClick 이 우선 처리되지만,
                  // 안전하게 여기서도 해당 장소를 찾아 시트를 띄웁니다.
                  onPoiClick: (LabelController layer, Poi poi) {
                    for (final entry in _poiEntries) {
                      if (entry.poi.id == poi.id) {
                        _showPlaceSheet(entry.place);
                        break;
                      }
                    }
                  },
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: MyLocationButton(onPressed: _goToMyLocation),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 카메라를 현재 위치로 부드럽게 이동합니다. (#4)
  ///
  /// 위치가 아직 없으면 즉시 1회 획득을 시도하고, 실패하면 짧은 스낵바로 안내합니다.
  Future<void> _goToMyLocation() async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    var pos = _lastPos;
    if (pos == null) {
      pos = await _tryGetCurrentPosition();
      if (pos != null) _onPosition(pos);
    }
    if (pos == null) {
      if (!mounted) return;
      showTopSnackBar(context, message: '현재 위치를 못 찾았데이. 위치 권한을 확인해주이소.');
      return;
    }
    await controller.moveCamera(
      CameraUpdate.newCenterPosition(
        LatLng(pos.latitude, pos.longitude),
        zoomLevel: 16,
      ),
      animation: const CameraAnimation(400),
    );
  }

  /// 버튼 탭 시 위치를 1회 조용히 얻습니다(스트림과 별개). 실패 시 null.
  Future<Position?> _tryGetCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  /// 위치 권한 영구 거부 시 상단에 1회 뜨는 작은 안내 배너입니다.
  Widget _locPermBanner() {
    return Container(
      width: double.infinity,
      color: AppTheme.coralRed.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.location_off, size: 18, color: AppTheme.coralRed),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('위치 권한이 꺼져 있어 현재 위치를 못 보여준데이. 설정에서 켜주이소.',
                style: TextStyle(fontSize: 12.5)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _showLocPermBanner = false),
          ),
        ],
      ),
    );
  }

  /// 상단 카테고리 필터 바를 만듭니다. ("전체" + DB의 카테고리들)
  Widget _buildCategoryBar() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          _categoryChip('전체', null),
          for (final category in _categories) _categoryChip(category, category),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String? value) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _onSelectCategory(value),
      ),
    );
  }
}

/// 마커(Poi)와 그 마커가 가리키는 장소를 함께 묶어 두는 도우미 클래스입니다.
class _PoiEntry {
  final Poi poi;
  final Place place;
  const _PoiEntry({required this.poi, required this.place});
}

/// 마커를 탭했을 때 아래에서 올라오는 장소 정보 시트입니다.
class _PlaceInfoSheet extends StatelessWidget {
  final Place place;
  const _PlaceInfoSheet({required this.place});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 장소 실사진(상단 라운드 크롭). 없으면 컬러 플레이스홀더.
              PlacePhoto(
                placeId: place.id,
                placeName: place.name,
                width: double.infinity,
                height: 172,
                radius: 18,
              ),
              const SizedBox(height: 12),
              // 이름(네이비 볼드)
              Text(place.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy)),
              const SizedBox(height: 4),
              // 카테고리 태그들
              Wrap(
                spacing: 6,
                children: [
                  for (final c in place.category)
                    Chip(
                      label: Text(c),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              // 태그들 (있을 때만) - 작은 Chip 으로 표시
              if (place.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in place.tags)
                      Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                      ),
                  ],
                ),
              ],
              // 접근성/위험 정보 (하나라도 있을 때만)
              if (place.hasAccessInfo) ...[
                const SizedBox(height: 12),
                _buildAccessInfo(context),
              ],
              const SizedBox(height: 12),
              // 설명
              _section(context, '설명', place.desc),
              // 방문 팁 (있을 때만)
              if (place.tip.isNotEmpty) _section(context, '방문 팁', place.tip),
              // 후기 요약 (있을 때만)
              if (place.reviewSummary.isNotEmpty)
                _section(context, '후기 요약', place.reviewSummary),
              const SizedBox(height: 8),
              // 주소
              if (place.address.isNotEmpty)
                _iconRow(Icons.place_outlined, place.address),
              // 전화
              if (place.phone.isNotEmpty)
                _iconRow(Icons.phone_outlined, place.phone),
            ],
          ),
        ),
      ),
    );
  }

  /// 접근성(경사/계단/엘리베이터)·위험 구간을 보여줍니다.
  ///  - 위험(caution/high)이 있으면 색상 배너를 먼저 표시합니다.
  ///  - 경사/계단/엘리베이터는 라벨이 있는 것만 작은 칩으로 표시합니다.
  Widget _buildAccessInfo(BuildContext context) {
    final theme = Theme.of(context);
    // 접근성 칩에 넣을 라벨들(빈 것은 제외)
    final chips = <String>[
      place.parkingLabel,
      place.gradientLabel,
      place.stairsLabel,
      place.elevatorLabel,
    ].where((s) => s.isNotEmpty).toList();

    // 위험 배너 색상(high=빨강, caution=주황)
    final bool isHigh = place.dangerLevel == 'high';
    final Color dangerColor = isHigh ? Colors.red.shade700 : Colors.orange.shade800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('접근성·안전', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        // 위험 배너 (none 이 아닐 때만)
        if (place.dangerLevel != 'none') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: dangerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dangerColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isHigh ? Icons.dangerous_outlined : Icons.warning_amber_rounded,
                  size: 18,
                  color: dangerColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.dangerLabel,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: dangerColor, fontWeight: FontWeight.bold),
                      ),
                      if (place.dangerReason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(place.dangerReason,
                            style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        // 접근성 칩들 (값이 있는 것만)
        if (chips.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final label in chips)
                Chip(
                  avatar: Icon(
                    label.contains('주차')
                        ? Icons.local_parking_outlined
                        : (label.contains('엘리베이터')
                            ? Icons.elevator_outlined
                            : (label.contains('계단')
                                ? Icons.stairs_outlined
                                : Icons.terrain_outlined)),
                    size: 16,
                  ),
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
      ],
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _iconRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// 태그 다중 선택 필터 시트입니다.
///
/// - taxonomy: 그룹명 -> 태그목록 (그룹별로 나눠서 보여줍니다).
/// - initialSelected: 시트를 열 때 이미 선택돼 있던 태그들.
/// - "적용"을 누르면 현재 선택된 태그 집합을 Navigator.pop 으로 돌려줍니다.
/// - "초기화"는 시트 안의 선택만 모두 해제합니다(적용을 눌러야 실제 반영).
///
/// 시트가 자기만의 임시 선택 상태를 가져야 하므로 StatefulWidget 으로 만듭니다.
class _TagFilterSheet extends StatefulWidget {
  final Map<String, List<String>> taxonomy;
  final Set<String> initialSelected;

  const _TagFilterSheet({
    required this.taxonomy,
    required this.initialSelected,
  });

  @override
  State<_TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<_TagFilterSheet> {
  /// 시트 안에서만 쓰는 임시 선택 상태입니다.
  /// 부모의 집합을 그대로 바꾸지 않도록 복사해서 시작합니다.
  late Set<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = {...widget.initialSelected};
  }

  /// 태그 하나를 켜고/끄기.
  void _toggle(String tag, bool selected) {
    setState(() {
      if (selected) {
        _tempSelected.add(tag);
      } else {
        _tempSelected.remove(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = widget.taxonomy.entries.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 + 현재 선택 개수
            Row(
              children: [
                Text('태그 필터', style: theme.textTheme.titleLarge),
                const SizedBox(width: 8),
                if (_tempSelected.isNotEmpty)
                  Text(
                    '${_tempSelected.length}개 선택',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '선택한 모든 태그를 가진 장소만 표시됩니다.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),

            // 그룹별 태그 목록 (길어질 수 있으니 스크롤 가능하게)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('표시할 태그가 없습니다.'),
                      ),
                    for (final group in groups) ...[
                      const SizedBox(height: 8),
                      // 그룹 이름 (예: 편의·접근성)
                      Text(group.key, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      // 그룹에 속한 태그들을 FilterChip 으로 (다중 선택)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final tag in group.value)
                            FilterChip(
                              label: Text(tag),
                              selected: _tempSelected.contains(tag),
                              onSelected: (selected) => _toggle(tag, selected),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // 하단 버튼: 초기화 / 적용
            Row(
              children: [
                // 초기화: 시트 안 선택만 모두 해제
                TextButton(
                  onPressed: () => setState(() => _tempSelected.clear()),
                  child: const Text('초기화'),
                ),
                const Spacer(),
                // 적용: 현재 선택된 태그 집합을 돌려주며 시트를 닫음
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_tempSelected),
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
