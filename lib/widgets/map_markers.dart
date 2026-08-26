import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// 지도 마커용 이미지 바이트를 코드로 그려 캐싱하는 도우미입니다.
///
/// 카카오맵(kakao_map_sdk)은 [KImage.fromData] 로 바이트를 직접 넘기는 것이
/// 에셋 경로 해석에 의존하지 않아 가장 확실합니다. 현재 위치 점은 별도 PNG 없이
/// dart:ui Canvas 로 한 번 그려서 바이트로 캐싱합니다.
class MapMarkers {
  MapMarkers._();

  static Uint8List? _locationDot;

  /// 현재 위치를 나타내는 스카이블루 원형 점(흰 테두리 + 옅은 그림자) PNG 바이트.
  /// 앱 세션당 한 번만 그려 캐싱합니다.
  static Future<Uint8List> locationDot() async {
    final cached = _locationDot;
    if (cached != null) return cached;

    const double size = 72; // 비트맵 한 변(px)
    const Offset center = Offset(size / 2, size / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1) 옅은 그림자
    canvas.drawCircle(
      center,
      22,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // 2) 흰 테두리(바깥 원)
    canvas.drawCircle(center, 20, Paint()..color = Colors.white);
    // 3) 스카이블루 채움(안쪽 원)
    canvas.drawCircle(center, 13, Paint()..color = AppTheme.skyBlue);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    _locationDot = bytes;
    return bytes;
  }
}
