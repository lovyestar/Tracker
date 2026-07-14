import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/recommendation.dart';
import 'place_photo.dart';
import 'retro.dart';

/// AI 추천 결과 카드 1장입니다.
///
/// 긴 장소명/사유/시간/비용에서도 오버플로우가 나지 않도록:
///  - 장소명 [maxLines]+ellipsis
///  - 시간/비용 태그는 [Wrap] 으로 줄바꿈(Row 가로 오버플로우 방지)
///  - 사진은 폭 전체(double.infinity)로 고정, 높이만 지정
class RecommendationCard extends StatelessWidget {
  final int index;
  final Recommendation rec;

  const RecommendationCard({
    super.key,
    required this.index,
    required this.rec,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RetroCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PlacePhoto(
                  placeName: rec.placeName,
                  width: double.infinity,
                  height: 128,
                  radius: 22,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.skyBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Text('$index',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
                const Positioned(
                  top: 10,
                  right: 10,
                  child: BestBadge(text: '추천', color: AppTheme.sunnyYellow),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.placeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy)),
                  const SizedBox(height: 8),
                  Text(rec.reason,
                      style: const TextStyle(
                          color: AppTheme.bodyText, height: 1.45)),
                  const Divider(height: 22),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: InfoTag(
                            icon: Icons.schedule,
                            text: '소요 ${rec.duration}',
                            color: AppTheme.skyBlue,
                            flexible: true
                          ),
                      ),
                      Expanded(
                        flex: 3,
                        child: InfoTag(
                            icon: Icons.payments_outlined,
                            text: rec.estimatedCost,
                            mainAxisAlignment: MainAxisAlignment.end,
                            color: AppTheme.skyBlue,
                            flexible: true
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
