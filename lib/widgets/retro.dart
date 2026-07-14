import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import 'place_photo.dart';

/// 브랜드(스티커/두들) 공용 위젯 모음입니다.

/// "BEST" 등 코스 카드 코너 뱃지(옐로 배경 + 네이비 텍스트).
class BestBadge extends StatelessWidget {
  final String text;
  final Color color;
  const BestBadge({super.key, this.text = 'BEST', this.color = AppTheme.sunnyYellow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.navy,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// #해시태그 나열(코스/명소 카드용).
class HashtagRow extends StatelessWidget {
  final List<String> tags;
  final Color color;
  const HashtagRow({super.key, required this.tags, this.color = AppTheme.skyBlue});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final t in tags)
          Text(
            '#$t',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
      ],
    );
  }
}

/// 섹션 제목(아이콘 + 제목 + 선택적 우측 액션). 예: "🧭 오늘의 추천 코스 · 전체보기".
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.burntOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.warmBrown,
            ),
          ),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.bodyBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// 크림 종이 + 얇은 브라운 테두리 라운드 카드 래퍼.
class RetroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  const RetroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = AppTheme.cardDecoration(radius: radius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: color == null
              ? decoration
              : decoration.copyWith(color: color),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 작은 태그 칩(아이콘 + 텍스트). 코스 카드의 시간/거리/예산 등에 사용.
///
/// [flexible] 을 켜면 텍스트를 1줄 ellipsis 로 줄여 가로 오버플로우를 막습니다.
/// 이때는 부모(예: Row)가 폭을 제약해 줘야 하므로 보통 `Expanded` 안에 넣습니다.
class InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final bool flexible;
  final MainAxisAlignment mainAxisAlignment;

  const InfoTag({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.flexible = false,
    this.mainAxisAlignment = MainAxisAlignment.start
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.bodyBrown;
    final label = Text(
      text,
      maxLines: 1,
      overflow: flexible ? TextOverflow.ellipsis : TextOverflow.clip,
      style: TextStyle(fontSize: 12.5, color: c, fontWeight: FontWeight.w600),
    );
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        flexible ? Flexible(child: label) : label,
      ],
    );
  }
}

/// 코스/명소 썸네일. [placeName] 또는 [placeId]가 주어지면 실사진을 표시하고,
/// 없거나 로드 실패 시 컬러 플레이스홀더로 대체합니다.([PlacePhoto] 위임)
class CourseThumb extends StatelessWidget {
  final String? placeName;
  final int? placeId;
  final double width;
  final double height;
  final double radius;

  const CourseThumb({
    super.key,
    this.placeName,
    this.placeId,
    this.width = double.infinity,
    this.height = 96,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return PlacePhoto(
      placeName: placeName,
      placeId: placeId,
      width: width,
      height: height,
      radius: radius,
    );
  }
}

/// 우표(스탬프) 모티프 프레임 — 톱니 테두리 느낌의 라운드 + 점선 테두리 대체.
class PostageFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PostageFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.cardCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.brownBorder,
          width: 2,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.warmBrown.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
