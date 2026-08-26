import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/place.dart';
import 'place_photo.dart';

/// 지도 마커 탭 시 아래에서 올라오는 장소 사진·정보 바텀시트입니다.
///
/// 구성: 상단 라운드 크롭 실사진(PlacePhoto 재사용, 없으면 컬러 플레이스홀더)
///  + 장소명(네이비 볼드) + 카테고리 칩 + 설명 요약 + tip 옐로 칩.
class PlaceDetailSheet extends StatelessWidget {
  final Place place;
  const PlaceDetailSheet({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 라운드 크롭 실사진
            PlacePhoto(
              placeId: place.id,
              placeName: place.name,
              width: double.infinity,
              height: 180,
              radius: 18,
            ),
            const SizedBox(height: 14),
            // 장소명(네이비 볼드)
            Text(
              place.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.navy,
              ),
            ),
            // 카테고리 칩
            if (place.category.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in place.category)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.skyBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            // 설명 요약(2~3줄)
            if (place.desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                place.desc,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppTheme.bodyText,
                ),
              ),
            ],
            // tip 옐로 칩
            if (place.tip.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.sunnyYellow.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 18, color: AppTheme.navy),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place.tip,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
