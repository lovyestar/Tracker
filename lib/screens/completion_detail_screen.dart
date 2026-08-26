import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' hide Badge;

import '../constants/app_theme.dart';
import '../models/completion_record.dart';
import '../models/place.dart';
import '../services/place_repository.dart';
import '../widgets/place_photo.dart';
import '../widgets/retro.dart';

/// 완주 기록 상세 화면입니다. (#16)
///  - 완주한 장소를 방문 순서대로 리스트로 보여줍니다.
///  - 지도에 이동 경로를 폴리라인으로 표시합니다.
///    · 궤적(GPS)이 있으면 그 궤적을, 없으면 스탬프(장소) 지점을 순서대로 잇습니다.
class CompletionDetailScreen extends StatefulWidget {
  final CompletionRecord record;

  const CompletionDetailScreen({super.key, required this.record});

  @override
  State<CompletionDetailScreen> createState() => _CompletionDetailScreenState();
}

class _CompletionDetailScreenState extends State<CompletionDetailScreen> {
  final PlaceRepository _placeRepo = PlaceRepository();

  KakaoMapController? _controller;
  bool _mapReady = false;

  /// 이름 → 장소(좌표 조회용).
  Map<String, Place> _byName = {};

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    final places = await _placeRepo.loadPlaces();
    if (!mounted) return;
    setState(() => _byName = {for (final p in places) p.name: p});
    await _drawRoute();
  }

  /// 폴리라인 지점 목록을 결정합니다.
  ///  (a) 기록된 GPS 궤적이 2점 이상이면 그대로 사용.
  ///  (b) 없으면 완주 장소를 순서대로 DB 좌표로 변환해 폴백.
  List<LatLng> _routePoints() {
    final route = widget.record.route;
    if (route.length >= 2) {
      return [for (final p in route) LatLng(p[0], p[1])];
    }
    final out = <LatLng>[];
    for (final name in widget.record.placeNames) {
      final place = _byName[name];
      if (place != null) out.add(LatLng(place.lat, place.lng));
    }
    return out;
  }

  LatLng get _center {
    final pts = _routePoints();
    if (pts.isNotEmpty) return pts.first;
    return const LatLng(35.080, 129.055);
  }

  Future<void> _onMapReady(KakaoMapController controller) async {
    _controller = controller;
    _mapReady = true;
    await _drawRoute();
  }

  Future<void> _drawRoute() async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    final pts = _routePoints();
    if (pts.isEmpty) return;

    // 장소(스탬프) 지점 마커.
    for (var i = 0; i < widget.record.placeNames.length; i++) {
      final place = _byName[widget.record.placeNames[i]];
      if (place == null) continue;
      try {
        await controller.labelLayer.addPoi(
          LatLng(place.lat, place.lng),
          style: PoiStyle(
            icon: KImage.fromAsset('assets/marker.png', 34, 34),
            textStyle: const [PoiTextStyle(color: AppTheme.navy, size: 13)],
          ),
          text: '${i + 1}. ${place.name}',
        );
      } catch (_) {
        // 마커 실패는 경로 표시에 영향 없으니 무시합니다.
      }
    }

    // 이동 경로 폴리라인(스카이블루).
    if (pts.length >= 2) {
      try {
        await controller.routeLayer.addRoute(
          pts,
          RouteStyle(AppTheme.skyBlue, 7,
              strokeColor: Colors.white, strokeWidth: 2),
          curveType: CurveType.none,
        );
      } catch (_) {
        // 폴리라인 실패 시 마커만 표시됩니다.
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final hasTrace = r.route.length >= 2;
    return Scaffold(
      appBar: AppBar(title: const Text('완주 기록')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(r.courseName, style: AppTheme.heading(size: 20)),
            const SizedBox(height: 4),
            Text('${_formatDate(r.date)} · 스탬프 ${r.stampCount}개',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.bodyBrown)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 240,
                child: KakaoMap(
                  option: KakaoMapOption(
                    position: _center,
                    zoomLevel: 14,
                    mapType: MapType.normal,
                  ),
                  onMapReady: _onMapReady,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasTrace ? '내가 걸은 이동 경로입니다.' : '스탬프 지점을 순서대로 이은 경로입니다.',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.bodyBrown),
            ),
            const SizedBox(height: 20),
            const SectionHeader(icon: Icons.route, title: '완주한 장소'),
            const SizedBox(height: 12),
            if (r.placeNames.isEmpty)
              _noPlaces()
            else
              for (var i = 0; i < r.placeNames.length; i++) ...[
                _placeTile(i + 1, r.placeNames[i]),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _placeTile(int order, String name) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: PlacePhoto(placeName: name, width: 56, height: 56),
          ),
          const SizedBox(width: 12),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppTheme.skyBlue, shape: BoxShape.circle),
            child: Text('$order',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppTheme.warmBrown)),
          ),
        ],
      ),
    );
  }

  Widget _noPlaces() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: const Text('이 기록에는 장소 정보가 없데이. (예전 기록)',
          style: TextStyle(color: AppTheme.bodyBrown)),
    );
  }
}
