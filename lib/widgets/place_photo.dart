import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// 장소 실사진(assets/place_photos/{id}.jpg) 조회용 인덱스입니다.
///
/// 코스/추천 카드에는 장소 "이름"만 있으므로, 앱 시작 시 이름→id 를 한 번 심어두고
/// 위젯에서 동기적으로 사진 경로를 찾습니다.
class PhotoIndex {
  PhotoIndex._();

  static Map<String, int> _nameToId = const {};

  static void seed(Map<String, int> nameToId) {
    _nameToId = nameToId;
  }

  static String assetForId(int id) => 'assets/place_photos/$id.jpg';

  /// 장소 이름으로 사진 경로를 찾습니다. 매칭 실패 시 null.
  static String? assetForName(String name) {
    final id = _nameToId[name];
    return id == null ? null : assetForId(id);
  }
}

/// 장소 실사진 위젯. 사진이 없거나 로드 실패 시 컬러 플레이스홀더로 대체합니다.
///
/// [placeId] 또는 [placeName] 중 하나로 사진을 찾습니다.
class PlacePhoto extends StatelessWidget {
  final int? placeId;
  final String? placeName;
  final double? width;
  final double height;
  final double radius;
  final BoxFit fit;

  const PlacePhoto({
    super.key,
    this.placeId,
    this.placeName,
    this.width,
    this.height = 96,
    this.radius = 16,
    this.fit = BoxFit.cover,
  });

  String? get _asset {
    if (placeId != null) return PhotoIndex.assetForId(placeId!);
    if (placeName != null) return PhotoIndex.assetForName(placeName!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    final placeholder = _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: asset == null
          ? placeholder
          : Image.asset(
              asset,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }

  Widget _placeholder() {
    final seed = (placeName?.hashCode ?? placeId ?? 0).abs();
    const palette = [
      AppTheme.skyBlue,
      AppTheme.sunnyYellow,
      AppTheme.coralRed,
      AppTheme.mintGreen,
    ];
    final base = palette[seed % palette.length];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base.withValues(alpha: 0.85), base],
        ),
      ),
      child: const Center(
        child: Icon(Icons.photo_camera_back_outlined,
            color: Colors.white, size: 30),
      ),
    );
  }
}
