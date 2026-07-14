import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
// kakao_map_sdk 의 Badge 가 Material 의 Badge 와 충돌하므로 kakao 쪽만 숨깁니다.
import 'package:kakao_map_sdk/kakao_map_sdk.dart' hide Badge;

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../models/place.dart';
import '../services/kakao_local_service.dart';
import '../services/place_repository.dart';
import '../widgets/place_photo.dart';
import '../widgets/top_snack_bar.dart';
import '../widgets/yeongmaegi_bubble.dart';

/// 위치 선택 결과입니다. 지도 피커/명소 선택 공통으로 사용합니다.
///  - 지도에서 찍은 경우: [name] 이 null (좌표만).
///  - 명소에서 고른 경우: [name] 에 장소 이름이 담깁니다.
class LocationPickResult {
  final double lat;
  final double lng;
  final String? name;
  const LocationPickResult({required this.lat, required this.lng, this.name});
}

/// 방법 A: 전체 화면 카카오맵 피커입니다.
///
/// 지도를 탭하면 코랄 핀이 찍히고, 하단 확인 바에 좌표가 표시됩니다.
/// "이 위치로 등록"을 누르면 [LocationPickResult] 를 pop 으로 돌려줍니다.
/// 기본 중심은 현재 위치, 실패 시 영도 중심(35.080, 129.055)입니다.
class LocationPickerScreen extends StatefulWidget {
  /// 이전에 이미 좌표를 골라뒀다면 그 자리를 초기 중심/핀으로 씁니다.
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  /// 영도 중심(현재 위치 실패 시 폴백).
  static const LatLng _yeongdo = LatLng(35.080, 129.055);

  KakaoMapController? _controller;
  bool _mapReady = false;

  /// 지도 초기 중심을 정하는 동안(현재 위치 조회) 스피너를 보여줍니다.
  bool _resolvingCenter = true;
  LatLng _center = _yeongdo;

  /// 사용자가 찍은 좌표(없으면 null → 등록 버튼 비활성).
  LatLng? _picked;
  Poi? _pinPoi;

  /// 키워드 검색으로 고른 장소 이름(지도 직접 탭이면 null). _confirm 시 함께 넘깁니다.
  String? _pickedName;

  /// 코랄 핀 이미지 바이트(1회 캐싱). 서브디렉토리 에셋을 네이티브가 못 읽는
  /// 문제를 피하려고 rootBundle 로 직접 읽어 KImage.fromData 로 넘깁니다.
  Uint8List? _pinBytes;

  /// 카카오 로컬 키워드 검색(#7).
  final KakaoLocalService _kakao = KakaoLocalService();
  final TextEditingController _searchController = TextEditingController();
  List<KakaoPlace> _results = [];
  bool _searching = false;

  /// 검색을 1회라도 실행했는지(빈 결과 안내 표시 판단용).
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _resolveCenter();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // 지도 컨트롤러 참조를 정리해 화면 전환 후 뒤틀림/누수를 막습니다. (#3)
    _controller = null;
    _mapReady = false;
    super.dispose();
  }

  /// 키워드로 카카오 로컬을 검색합니다. 지도 중심 기준 반경 우선.
  /// 네트워크/파싱 실패 시 빈 목록 + 스낵바 안내(지도 탭 방식은 그대로 사용 가능).
  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final results = await _kakao.searchKeyword(
      query,
      lat: _center.latitude,
      lng: _center.longitude,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      _searched = true;
    });
    if (results.isEmpty) {
      showTopSnackBar(context, message: '검색 결과가 없데이. 지도를 직접 탭해서 찍어도 된데이.');
    }
  }

  /// 검색 결과를 선택하면 그 좌표로 카메라를 옮기고 핀을 찍고 이름을 채웁니다.
  Future<void> _selectResult(KakaoPlace place) async {
    FocusScope.of(context).unfocus();
    final pos = LatLng(place.lat, place.lng);
    setState(() {
      _results = [];
      _searched = false;
    });
    await _drop(pos, name: place.name);
    final controller = _controller;
    if (controller != null && _mapReady) {
      await controller.moveCamera(
        CameraUpdate.newCenterPosition(pos, zoomLevel: 16),
        animation: const CameraAnimation(400),
      );
    }
  }

  /// 초기 중심을 정합니다. 이전 선택값 > 현재 위치 > 영도 순.
  Future<void> _resolveCenter() async {
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
      _picked = _center;
      if (mounted) setState(() => _resolvingCenter = false);
      return;
    }
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition();
          _center = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      // 위치 실패 시 영도 중심 유지.
    }
    if (mounted) setState(() => _resolvingCenter = false);
  }

  Future<Uint8List> _pinImageBytes() async {
    final cached = _pinBytes;
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/images/marker_todo.png');
    return _pinBytes = data.buffer.asUint8List();
  }

  Future<void> _onMapReady(KakaoMapController controller) async {
    _controller = controller;
    _mapReady = true;
    // 초기 선택값이 있으면 핀을 미리 찍어둡니다.
    if (_picked != null) await _drop(_picked!);
  }

  /// 좌표를 저장하고 코랄 핀을 찍거나 이동합니다.
  /// [name] 은 검색 선택 시 장소 이름(지도 직접 탭이면 null → 이름 없음).
  Future<void> _drop(LatLng pos, {String? name}) async {
    _picked = pos;
    _pickedName = name;
    final controller = _controller;
    if (controller == null || !_mapReady) {
      if (mounted) setState(() {});
      return;
    }
    final existing = _pinPoi;
    if (existing != null) {
      await existing.move(pos, 200);
      if (mounted) setState(() {});
      return;
    }
    try {
      final bytes = await _pinImageBytes();
      _pinPoi = await controller.labelLayer.addPoi(
        pos,
        style: PoiStyle(
          icon: KImage.fromData(bytes, 48, 48),
          // 핀 이미지의 뾰족한 아래 끝이 좌표를 가리키도록 하단 중앙 앵커.
          anchor: const KPoint(0.5, 1.0),
        ),
        rank: 200,
      );
    } catch (e) {
      debugPrint('[LocationPicker] 핀 생성 실패(무시): $e');
    }
    if (mounted) setState(() {});
  }

  void _confirm() {
    final picked = _picked;
    if (picked == null) return;
    Navigator.pop(
      context,
      LocationPickResult(
          lat: picked.latitude, lng: picked.longitude, name: _pickedName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지도에서 위치 선택')),
      body: _resolvingCenter
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                // 지도는 화면 전체를 채우도록 명시적으로 고정해 리사이즈 뒤틀림을 막습니다. (#3)
                Positioned.fill(
                  child: KakaoMap(
                    option: KakaoMapOption(
                      position: _center,
                      zoomLevel: 15,
                      mapType: MapType.normal,
                    ),
                    onMapReady: _onMapReady,
                    onMapClick: (KPoint point, LatLng position) =>
                        _drop(position),
                  ),
                ),
                // 상단: 이름 검색 바 + 결과 목록 + 영매기 안내 말풍선.
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _searchBar(),
                      if (_searched || _results.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _searchResults(),
                      ],
                      const SizedBox(height: 8),
                      YeongmaegiBubble(
                        message: _picked == null
                            ? MessagesKo.addCoursePickOnMap
                            : MessagesKo.addCoursePickConfirm,
                      ),
                    ],
                  ),
                ),
                // 하단 확인 바(좌표 + 등록 버튼).
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _confirmBar(),
                ),
              ],
            ),
    );
  }

  /// 이름 검색 바(#7). 제출하면 카카오 로컬 키워드 검색을 실행합니다.
  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lineSoft, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: AppTheme.bodyBrown, size: 20),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '장소 이름으로 검색 (예: 흰여울문화마을)',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              ),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.skyBlue),
              ),
            )
          else
            TextButton(
              onPressed: _runSearch,
              child: const Text('검색',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  /// 검색 결과 목록(#7). 탭하면 그 좌표로 카메라 이동 + 핀 + 이름 자동 입력.
  Widget _searchResults() {
    if (_results.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.lineSoft, width: 1.4),
        ),
        child: const Text('검색 결과가 없데이. 지도를 직접 탭해서 찍어도 된데이.',
            style: TextStyle(fontSize: 13, color: AppTheme.bodyBrown)),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lineSoft, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _results.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppTheme.lineSoft),
        itemBuilder: (context, i) {
          final r = _results[i];
          return ListTile(
            dense: true,
            leading:
                const Icon(Icons.place_outlined, color: AppTheme.coralRed),
            title: Text(r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy)),
            subtitle: r.address.isEmpty
                ? null
                : Text(r.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.bodyBrown)),
            onTap: () => _selectResult(r),
          );
        },
      ),
    );
  }

  Widget _confirmBar() {
    final picked = _picked;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.lineSoft, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place, color: AppTheme.coralRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  picked == null
                      ? '지도를 탭해서 위치를 찍어보이소'
                      : '위도 ${picked.latitude.toStringAsFixed(5)}, '
                          '경도 ${picked.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('이 위치로 등록'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: picked == null ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

/// 방법 B: 내장 DB 명소 검색 화면입니다.
///
/// 이름/카테고리로 검색해 고르면 [LocationPickResult] (이름+좌표)를 돌려줍니다.
class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final PlaceRepository _repository = PlaceRepository();
  final TextEditingController _search = TextEditingController();
  List<Place> _places = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim()));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final places = await _repository.loadPlaces();
    if (!mounted) return;
    setState(() {
      _places = places;
      _loading = false;
    });
  }

  List<Place> get _filtered {
    if (_query.isEmpty) return _places;
    final q = _query.toLowerCase();
    return _places.where((p) {
      final haystack = '${p.name} ${p.category.join(' ')}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  void _pick(Place place) {
    Navigator.pop(
      context,
      LocationPickResult(lat: place.lat, lng: place.lng, name: place.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('명소에서 선택')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: AppTheme.bodyBrown),
                  hintText: '명소 이름·카테고리로 검색',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(MessagesKo.addCoursePlaceSearchHint,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.bodyBrown)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? const Center(
                          child: Text('검색 결과가 없데이. 다른 키워드로 찾아보이소!',
                              style: TextStyle(color: AppTheme.bodyBrown)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _placeTile(results[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeTile(Place place) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _pick(place),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: AppTheme.cardDecoration(radius: 16),
        child: Row(
          children: [
            PlacePhoto(
              placeId: place.id,
              placeName: place.name,
              width: 56,
              height: 56,
              radius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy)),
                  const SizedBox(height: 4),
                  Text(place.category.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.bodyBrown)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.bodyBrown),
          ],
        ),
      ),
    );
  }
}
