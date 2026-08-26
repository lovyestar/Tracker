import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// 지도 오른쪽 아래의 "현재 위치로 이동" 원형 버튼입니다. (#4)
///
/// 흰 배경 + 스카이블루 조준점(내 위치) 아이콘 + 그림자. 지도 탭·코스 지도에서 공용으로 씁니다.
class MyLocationButton extends StatelessWidget {
  final VoidCallback onPressed;

  const MyLocationButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black45,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.my_location, color: AppTheme.skyBlue, size: 24),
        ),
      ),
    );
  }
}
