import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// 코스 내비 하단 가로 리스트의 스탬프 카드 한 장입니다.
///
/// 고정 높이(가로 ListView) 안에서 장소명이 길어도 세로 오버플로우가
/// 나지 않도록, 장소명 영역을 [Expanded] 로 감싸 2줄에서 말줄임 처리합니다.
/// (이전 구현은 [Spacer] + 고정 높이라 긴 이름에서 BOTTOM OVERFLOW 발생)
class CourseStopCard extends StatelessWidget {
  final int index;
  final String placeName;
  final String duration;
  final bool visited;
  final VoidCallback? onLongPress;

  const CourseStopCard({
    super.key,
    required this.index,
    required this.placeName,
    required this.duration,
    required this.visited,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 테스트용: GPS 없이 동작 확인 시 스탬프를 길게 눌러 수동 획득할 수 있습니다.
      onLongPress: onLongPress,
      child: Container(
        width: 158,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: visited
              ? AppTheme.mintGreen.withValues(alpha: 0.16)
              : AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: visited ? AppTheme.mintGreen : AppTheme.lineSoft,
            width: visited ? 2 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              visited ? Icons.check_circle : Icons.radio_button_unchecked,
              color: visited ? AppTheme.mintGreen : AppTheme.skyBlue,
            ),
            const SizedBox(height: 6),
            // Expanded 로 남은 공간을 채우고 2줄에서 말줄임 → 세로 오버플로우 방지.
            Expanded(
              child: Text(
                '$index. $placeName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppTheme.navy),
              ),
            ),
            Text(duration,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.bodyText)),
          ],
        ),
      ),
    );
  }
}
