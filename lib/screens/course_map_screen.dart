import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' hide Badge;

import '../constants/app_theme.dart';
import '../constants/messages_ko.dart';
import '../models/place.dart';
import '../models/recommendation.dart';
import '../services/active_course_store.dart';
import '../services/notification_store.dart';
import '../services/voice_service.dart';
import '../widgets/course_stop_card.dart';
import '../widgets/map_markers.dart';
import '../widgets/my_location_button.dart';
import '../widgets/place_detail_sheet.dart';
import '../widgets/yeongmaegi_bubble.dart';
import 'completion_card_screen.dart';

/// 코스 하나에 포함된 장소 + 좌표(스탬프 대상)입니다.
class _Stop {
  final Recommendation rec;
  final Place place;
  bool visited = false;
  _Stop({required this.rec, required this.place});
}

/// 지도 + GPS 스탬프 화면입니다. (SPEC §4-5)
///  - 코스 장소를 카카오맵 마커로 표시
///  - Geolocator 스트림으로 50m 이내 진입 시 스탬프 자동 획득
///  - 전체 획득 시 완주 카드로 이동
class CourseMapScreen extends StatefulWidget {
  final String courseName;
  final List<Recommendation> stops;
  final List<Place> allPlaces;

  const CourseMapScreen({
    super.key,
    required this.courseName,
    required this.stops,
    required this.allPlaces,
  });

  @override
  State<CourseMapScreen> createState() => _CourseMapScreenState();
}

class _CourseMapScreenState extends State<CourseMapScreen> {
  /// 스탬프 획득 기준 거리(m). SPEC §1.
  static const double _stampRadiusMeters = 50;

  KakaoMapController? _controller;
  final List<_Stop> _stops = [];
  final List<Poi> _pois = [];
  StreamSubscription<Position>? _positionSub;

  /// 현재 위치를 나타내는 스카이블루 점 마커. 첫 위치 수신 시 생성, 이후 move 로 이동.
  Poi? _myLocationPoi;

  /// 커스텀 마커 원본 바이트(앱에서 rootBundle 로 직접 읽어 캐싱).
  /// KImage.fromAsset 은 경로 문자열만 네이티브로 넘겨 서브디렉토리 에셋 해석 실패 시
  /// 조용히 카카오 기본 핀으로 떨어진다. 바이트를 직접 넘기면(ImageType.data) 확실히 반영된다.
  Uint8List? _todoIconBytes;
  Uint8List? _doneIconBytes;

  bool _mapReady = false;
  bool _completed = false;

  /// 마커 정보 시트 재진입 가드. 카카오맵 poi 클릭이 한 번의 탭에 콜백을
  /// 중복 발화해 시트가 두 번 열리던 문제를 막습니다. 이미 열려 있거나,
  /// 같은 장소를 300ms 내 재호출하면 무시합니다. (지도 탭과 동일)
  bool _sheetOpen = false;
  int? _lastSheetPlaceId;
  DateTime? _lastSheetAt;
  String? _locationError;
  Position? _lastPos;

  /// 완주 경로 기록용 GPS 궤적(좌표 반올림). 25m 이상 이동 시에만 점을 추가해
  /// 용량을 아낍니다. 완주 시 CompletionRecord 에 저장돼 상세 지도 폴리라인이 됩니다. (#16)
  final List<List<double>> _trace = [];
  static const double _traceMinMoveMeters = 25;

  void _recordTrace(Position pos) {
    final lat = double.parse(pos.latitude.toStringAsFixed(5));
    final lng = double.parse(pos.longitude.toStringAsFixed(5));
    if (_trace.isNotEmpty) {
      final last = _trace.last;
      final moved = Geolocator.distanceBetween(last[0], last[1], lat, lng);
      if (moved < _traceMinMoveMeters) return;
    }
    _trace.add([lat, lng]);
  }

  @override
  void initState() {
    super.initState();
    _resolveStops();
    _startLocation();
  }

  /// 추천 장소 이름을 DB 좌표와 매칭합니다(할루시네이션 차단은 서비스에서 이미 수행).
  void _resolveStops() {
    final byName = {for (final p in widget.allPlaces) p.name: p};
    for (final rec in widget.stops) {
      final place = byName[rec.placeName];
      if (place != null) {
        _stops.add(_Stop(rec: rec, place: place));
      }
    }
  }

  int get _visitedCount => _stops.where((s) => s.visited).length;

  /// 다음 방문할(미방문) 스탬프 대상.
  _Stop? get _nextStop {
    for (final s in _stops) {
      if (!s.visited) return s;
    }
    return null;
  }

  /// 현재 위치에서 다음 목적지까지 남은 거리(m). 위치 없으면 null.
  double? get _remainingMeters {
    final pos = _lastPos;
    final next = _nextStop;
    if (pos == null || next == null) return null;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      next.place.lat,
      next.place.lng,
    );
  }

  /// 위치 fix 를 아직 못 받았는지 여부. (내비 정보 바에서 "위치 확인 중…" 표시)
  bool get _hasFix => _lastPos != null;

  /// 도보 4km/h 기준 다음 목적지까지 예상 소요(분).
  int? get _walkMinutes {
    final meters = _remainingMeters;
    if (meters == null) return null;
    return (meters / 1000 / 4 * 60).round();
  }

  /// 도보 4km/h 기준 도착 예정 시각 문자열. 계산 불가 시 '—'.
  String get _etaText {
    final minutes = _walkMinutes;
    if (minutes == null) return '—';
    final eta = DateTime.now().add(Duration(minutes: minutes));
    final isPm = eta.hour >= 12;
    final h12 = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final mm = eta.minute.toString().padLeft(2, '0');
    return '${isPm ? '오후' : '오전'} $h12:$mm';
  }

  /// 예상 소요 문자열(도보). 계산 불가 시 '—'.
  String get _durationText {
    final minutes = _walkMinutes;
    if (minutes == null) return '—';
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '$h시간' : '$h시간 $m분';
    }
    return '$minutes분';
  }

  String get _remainingText {
    final meters = _remainingMeters;
    if (meters == null) return '—';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters.round()}m';
  }

  LatLng get _center {
    if (_stops.isNotEmpty) {
      return LatLng(_stops.first.place.lat, _stops.first.place.lng);
    }
    return const LatLng(35.080, 129.055);
  }

  Future<void> _startLocation() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        setState(() => _locationError = MessagesKo.errorGpsIndoor);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() =>
            _locationError = '위치를 켜줘야 스탬프 찍을 수 있데이. 설정에서 켜주이소');
        return;
      }
      // 스트림 첫 emit 이 느릴 수 있으니, 마지막/현재 위치를 즉시 1회 받아 점을 먼저 찍습니다.
      await _primeInitialPosition();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onPosition);
    } catch (_) {
      setState(() => _locationError = MessagesKo.errorGpsIndoor);
    }
  }

  /// 스트림 시작 전에 즉시 위치를 1회 받아 현재 위치 점을 먼저 표시합니다.
  /// getLastKnownPosition(빠름) → getCurrentPosition(정확) 순으로 시도합니다.
  Future<void> _primeInitialPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        debugPrint('[CourseMap] 초기 위치(lastKnown) 수신');
        _onPosition(last);
      }
    } catch (_) {
      // 무시하고 현재 위치 시도로 넘어갑니다.
    }
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      debugPrint('[CourseMap] 초기 위치(current) 수신');
      _onPosition(current);
    } catch (_) {
      // 즉시 위치 실패는 스트림이 이어받으므로 조용히 무시합니다.
    }
  }

  void _onPosition(Position pos) {
    if (mounted) setState(() => _lastPos = pos);
    _recordTrace(pos);
    _updateMyLocation(pos);
    for (var i = 0; i < _stops.length; i++) {
      final stop = _stops[i];
      if (stop.visited) continue;
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        stop.place.lat,
        stop.place.lng,
      );
      if (distance <= _stampRadiusMeters) {
        _acquireStamp(i);
      }
    }
  }

  /// 현재 위치 마커를 갱신합니다. 첫 위치 수신 시 스카이블루 점을 생성하고,
  /// 이후에는 move 로 부드럽게 이동합니다. 지도 준비 전이면 조용히 넘어갑니다.
  Future<void> _updateMyLocation(Position pos) async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    final latlng = LatLng(pos.latitude, pos.longitude);
    final existing = _myLocationPoi;
    if (existing != null) {
      await existing.move(latlng, 300);
      debugPrint('[CourseMap] 위치 점 이동됨: ${pos.latitude}, ${pos.longitude}');
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
      debugPrint('[CourseMap] 위치 점 추가됨: ${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      debugPrint('[CourseMap] 현재 위치 마커 생성 실패(무시): $e');
    }
  }

  /// 카메라를 현재 위치로 부드럽게 이동합니다. (#4)
  ///
  /// 위치가 아직 없으면 즉시 1회 획득을 시도하고, 실패하면 짧은 스낵바로 안내합니다.
  Future<void> _goToMyLocation() async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;
    var pos = _lastPos;
    if (pos == null) {
      pos = await _fetchCurrentPositionOnce();
      if (pos != null) _onPosition(pos);
    }
    if (pos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 못 찾았데이. 위치 권한을 확인해주이소.')),
      );
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

  /// 버튼 탭 시 위치를 1회 조용히 얻습니다. 권한/서비스 없으면 null.
  Future<Position?> _fetchCurrentPositionOnce() async {
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

  /// 스탬프를 획득합니다(자동 GPS 또는 테스트용 수동).
  Future<void> _acquireStamp(int index) async {
    if (_stops[index].visited) return;
    setState(() => _stops[index].visited = true);
    await NotificationStore.instance
        .recordStamp(_stops[index].place.name);
    await HapticFeedback.mediumImpact();
    await _rebuildMarkers();

    final count = _visitedCount;
    final remaining = _stops.length - count;
    String message;
    if (count == 1) {
      message = MessagesKo.stampFirst;
      VoiceService.instance.play(VoiceLine.stampFirst);
    } else if (remaining == 1) {
      message = MessagesKo.stampLastOne;
      VoiceService.instance.play(VoiceLine.stampLastOne);
    } else {
      message = MessagesKo.stampGetWith(count);
      VoiceService.instance.play(VoiceLine.stampGet);
    }

    if (!mounted) return;
    _showBubbleSnack(message);

    if (remaining == 0) {
      _onCompleted();
    }
  }

  /// 영매기 말풍선 스타일의 토스트(스카이블루 라운드 + 옐로 링 아바타).
  void _showBubbleSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: EdgeInsets.zero,
          content: YeongmaegiBubble(message: message, avatarSize: 44),
        ),
      );
  }

  void _onCompleted() {
    if (_completed) return;
    _completed = true;
    _positionSub?.cancel();
    // 완주 카드는 루트 네비게이터로 띄웁니다(이 화면은 지도 탭에 임베드돼 있으므로).
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CompletionCardScreen(
          courseName: widget.courseName,
          stampCount: _stops.length,
          placeNames: _stops.map((s) => s.place.name).toList(),
          route: List<List<double>>.from(_trace),
        ),
      ),
    );
    // 진행 상태 해제 → 지도 탭이 일반 지도로 되돌아갑니다. (완주 자동 해제)
    ActiveCourseStore.instance.clear();
  }

  /// 코스 경로 취소(확인 다이얼로그). 취소해도 스탬프 기록은 그대로 남습니다.
  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('경로 취소할까?'),
        content: const Text(MessagesKo.navCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 진행'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.coralRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('경로 취소'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // 진행 상태만 해제(스탬프 기록 유지). 지도 탭은 일반 지도로 되돌아갑니다.
      await ActiveCourseStore.instance.clear();
    }
  }

  Future<void> _onMapReady(KakaoMapController controller) async {
    _controller = controller;
    _mapReady = true;
    await _rebuildMarkers();
    // 지도 준비 전에 위치를 이미 받았다면 현재 위치 점을 지금 올립니다.
    final pos = _lastPos;
    if (pos != null) await _updateMyLocation(pos);
  }

  /// 커스텀 마커 PNG 를 rootBundle 로 한 번만 읽어 바이트로 캐싱합니다.
  Future<void> _ensureMarkerIcons() async {
    if (_todoIconBytes != null && _doneIconBytes != null) return;
    try {
      _todoIconBytes =
          (await rootBundle.load('assets/images/marker_todo.png'))
              .buffer
              .asUint8List();
      _doneIconBytes =
          (await rootBundle.load('assets/images/marker_done.png'))
              .buffer
              .asUint8List();
    } catch (e) {
      debugPrint('[CourseMap] 커스텀 마커 로드 실패 → 기본 마커 폴백: $e');
    }
  }

  Future<void> _rebuildMarkers() async {
    final controller = _controller;
    if (controller == null || !_mapReady) return;

    await _ensureMarkerIcons();

    // 기존 마커 제거 후 다시 그립니다(방문/미방문 상태 반영).
    for (final poi in _pois) {
      await poi.remove();
    }
    _pois.clear();

    final todoStyle = _markerStyle(visited: false);
    final doneStyle = _markerStyle(visited: true);
    for (final stop in _stops) {
      final place = stop.place;
      final poi = await controller.labelLayer.addPoi(
        LatLng(place.lat, place.lng),
        style: stop.visited ? doneStyle : todoStyle,
        text: place.name,
        onClick: () => _showPlaceSheet(place),
      );
      _pois.add(poi);
    }
  }

  /// 마커 탭 시 장소 사진·정보 바텀시트를 띄웁니다.
  ///
  /// 카카오맵(플랫폼 뷰) 위에서 시트가 내용 높이를 즉시 못 재 처음엔 바닥에 붙어
  /// 있다가 쓸어올려야 보이던 문제를 [FractionallySizedBox] 고정 비율로 해결합니다. (#1)
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
      backgroundColor: AppTheme.cardWhite,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.6,
        child: PlaceDetailSheet(place: place),
      ),
    ).whenComplete(() => _sheetOpen = false);
  }

  /// 커스텀 핀 마커 스타일(미방문=코랄 깃발, 방문=민트 체크), 52dp.
  /// 캐싱된 바이트로 KImage.fromData 를 써서 네이티브 에셋 경로 해석에 의존하지 않습니다.
  /// 바이트 로드 실패 시에만 기본 마커(assets/marker.png)로 폴백합니다.
  PoiStyle _markerStyle({required bool visited}) {
    final bytes = visited ? _doneIconBytes : _todoIconBytes;
    if (bytes != null) {
      debugPrint(
          '[CourseMap] 마커 렌더: ${visited ? 'marker_done' : 'marker_todo'} '
          '(fromData ${bytes.length}B, 52dp)');
      return PoiStyle(
        icon: KImage.fromData(bytes, 52, 52),
        textStyle: const [PoiTextStyle(color: AppTheme.navy, size: 15)],
      );
    }
    debugPrint('[CourseMap] 마커 렌더: 기본 마커 폴백(assets/marker.png)');
    return PoiStyle(
      icon: KImage.fromAsset('assets/marker.png', 40, 40),
      textStyle: const [PoiTextStyle(color: Color(0xFF222222), size: 16)],
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_locationError != null) _errorBanner(_locationError!),
            _progressHeader(),
            Expanded(
              child: Stack(
                children: [
                  KakaoMap(
                    option: KakaoMapOption(
                      position: _center,
                      zoomLevel: 15,
                      mapType: MapType.normal,
                    ),
                    onMapReady: _onMapReady,
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: MyLocationButton(onPressed: _goToMyLocation),
                  ),
                ],
              ),
            ),
            _bottomPanel(),
            _stopList(),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      color: AppTheme.coralRed.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.gps_off, color: AppTheme.coralRed),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          TextButton(onPressed: _startLocation, child: const Text('다시 시도')),
        ],
      ),
    );
  }

  /// 상단 흰 라운드 카드 헤더: 코스명 + 진행률 뱃지(써니옐로 "2/5" 칩) (시안 영도 지도).
  Widget _progressHeader() {
    final total = _stops.isEmpty ? 1 : _stops.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppTheme.skyBlue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy)),
              ),
              const SizedBox(width: 8),
              _progressBadge(),
              const SizedBox(width: 4),
              _cancelButton(),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _visitedCount / total,
              minHeight: 7,
              backgroundColor: AppTheme.lineSoft,
              valueColor: const AlwaysStoppedAnimation(AppTheme.skyBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// 코랄 "경로 취소" 버튼(확인 다이얼로그). 상단 헤더 우측.
  Widget _cancelButton() {
    return TextButton.icon(
      onPressed: _confirmCancel,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.coralRed,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.close_rounded, size: 18),
      label: const Text('경로 취소',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
    );
  }

  /// 써니옐로 진행률 칩 "2/5".
  Widget _progressBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.sunnyYellow,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text('$_visitedCount/${_stops.length}',
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.navy)),
    );
  }

  /// 하단: 영매기 말풍선(스카이블루) + 흰 라운드 정보 바(도착 예정 · 남은 거리).
  Widget _bottomPanel() {
    final next = _nextStop;
    final bubbleMsg = next == null
        ? '스탬프 다 왔나? 마지막까지 가보자!'
        : '${next.place.name} 쪽으로 가보자. 다 왔데이!';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        children: [
          YeongmaegiBubble(message: bubbleMsg, avatarSize: 46),
          const SizedBox(height: 8),
          _infoBar(),
        ],
      ),
    );
  }

  /// 흰 라운드 정보 바 (남은 거리 · 예상 소요 · 도착 예정).
  /// 위치 fix 가 없으면 "위치 확인 중…" 을 표시합니다. (#14)
  Widget _infoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.cardDecoration(radius: 18),
      child: _hasFix
          ? Row(
              children: [
                _infoCell(Icons.place_outlined, '남은 거리', _remainingText),
                _infoDivider(),
                _infoCell(Icons.directions_walk, '예상 소요', _durationText),
                _infoDivider(),
                _infoCell(Icons.schedule, '도착 예정', _etaText),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.skyBlue),
                ),
                SizedBox(width: 10),
                Text('위치 확인 중…',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.bodyText)),
              ],
            ),
    );
  }

  Widget _infoDivider() => Container(
        width: 1,
        height: 34,
        color: AppTheme.lineSoft,
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );

  Widget _infoCell(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.skyBlue),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.bodyText)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopList() {
    return SizedBox(
      height: 128,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        itemCount: _stops.length,
        itemBuilder: (context, i) {
          final stop = _stops[i];
          return CourseStopCard(
            index: i + 1,
            placeName: stop.place.name,
            duration: stop.rec.duration,
            visited: stop.visited,
            onLongPress: () => _acquireStamp(i),
          );
        },
      ),
    );
  }
}
