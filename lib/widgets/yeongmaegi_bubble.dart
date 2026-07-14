import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// 영매기 이미지 + 말풍선 위젯입니다. (스티커/두들 리디자인)
///
///  - 이미지는 assets/images/yeongmaegi.jpg (수정 금지).
///  - 말풍선은 스카이블루/옐로/민트 파스텔 배경 + 라운드(시안 UI ELEMENTS).
class YeongmaegiBubble extends StatelessWidget {
  final String message;
  final double avatarSize;

  /// 말풍선 색. 미지정 시 스카이블루 계열.
  final Color? bubbleColor;

  /// 말풍선을 탭했을 때 동작(선택). 지정 시 오른쪽에 탭 힌트가 표시됩니다. (#5)
  final VoidCallback? onTap;

  const YeongmaegiBubble({
    super.key,
    required this.message,
    this.avatarSize = 64,
    this.bubbleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = bubbleColor ?? const Color(0xFFDFF3FD);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppTheme.sunnyYellow, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.navy.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/yeongmaegi.jpg',
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app,
                          size: 14, color: AppTheme.skyBlue),
                      const SizedBox(width: 4),
                      Text('탭하면 지금 딱 맞는 코스 추천!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.skyBlue.withValues(alpha: 0.9),
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: row,
    );
  }
}
