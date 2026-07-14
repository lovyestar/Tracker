import 'package:flutter/material.dart';

/// 앱 색상·테마입니다. — "영매기 브랜드 보드"(스티커/두들) 기준 재구성.
///
/// 무드: 흰~아이보리 배경 + 밝은 파스텔 카드 + 말풍선 + 스티커 코스 카드.
/// 두껍게 라운드, 두들 아이콘, 네이비 헤드라인 텍스트.
///
/// 폰트는 번들 Pretendard(assets/fonts, OFL)만 사용합니다.
/// 런타임 네트워크 폰트 의존은 없습니다.
class AppTheme {
  AppTheme._();

  // ── 브랜드 팔레트 (시안 명시값) ─────────────────────────────
  static const Color skyBlue = Color(0xFF69C6F0); // 스카이 블루(주 CTA)
  static const Color sunnyYellow = Color(0xFFFFD64D); // 써니 옐로(포인트/뱃지)
  static const Color coralRed = Color(0xFFFF6B6B); // 코랄 레드(저장/하트)
  static const Color mintGreen = Color(0xFF7EDDB7); // 민트 그린(보조)
  static const Color navy = Color(0xFF1E3A8A); // 네이비(헤드라인 텍스트)

  static const Color ivory = Color(0xFFFFFDF7); // 배경(화이트~아이보리)
  static const Color cardWhite = Color(0xFFFFFFFF); // 카드 표면(화이트)
  static const Color bodyText = Color(0xFF5C6B8A); // 본문/보조 텍스트(슬레이트)
  static const Color lineSoft = Color(0xFFE5EAF2); // 얇은 카드 테두리

  // ── 기존 코드 호환용 별칭(구 토큰명 → 새 팔레트로 remap) ────────
  //  화면 코드 대부분이 아래 이름을 참조하므로 심볼을 유지합니다.
  static const Color paperBg = ivory;
  static const Color cardCream = cardWhite;
  static const Color warmBrown = navy; // 헤드라인/짙은 텍스트 → 네이비
  static const Color bodyBrown = bodyText; // 본문/보조 텍스트 → 슬레이트
  static const Color burntOrange = skyBlue; // 주 CTA → 스카이 블루
  static const Color gold = sunnyYellow; // 포인트/순위 → 옐로
  static const Color brownBorder = lineSoft; // 얇은 테두리
  static const Color sunsetPink = coralRed;

  /// 헤드라인 서체. Pretendard(번들).
  static const String serifFamily = 'Pretendard';

  static TextStyle logo({double size = 30, Color color = navy}) => TextStyle(
        fontFamily: serifFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
      );

  static TextStyle heading({double size = 22, Color color = navy}) => TextStyle(
        fontFamily: serifFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.2,
      );

  /// 배경 대체용 미묘한 그라데이션(화이트 → 아이보리).
  static const LinearGradient paperGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFEAF6FE)],
  );

  /// 밝은 하늘 그라데이션(히어로/완주 배경 등에 사용).
  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9BDBF6), Color(0xFF69C6F0), Color(0xFF4FB4E8)],
  );

  /// 카드 공통 데코레이션(화이트 + 얇은 테두리 + 부드러운 그림자 + 큰 라운드).
  static BoxDecoration cardDecoration({double radius = 22}) => BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: lineSoft, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: skyBlue,
      brightness: Brightness.light,
      primary: skyBlue,
      onPrimary: Colors.white,
      secondary: sunnyYellow,
      onSecondary: navy,
      tertiary: coralRed,
      surface: cardWhite,
      onSurface: navy,
    );

    final baseText = ThemeData.light().textTheme.apply(
          fontFamily: serifFamily,
          bodyColor: navy,
          displayColor: navy,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: serifFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: ivory,
      textTheme: baseText,
      appBarTheme: const AppBarTheme(
        backgroundColor: ivory,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: serifFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: lineSoft, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEFF5FB),
        selectedColor: skyBlue,
        secondarySelectedColor: skyBlue,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(
            color: navy, fontWeight: FontWeight.w700, fontFamily: serifFamily),
        secondaryLabelStyle: const TextStyle(
            color: Colors.white, fontFamily: serifFamily),
        side: const BorderSide(color: lineSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: skyBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, fontFamily: serifFamily),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: skyBlue,
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontFamily: serifFamily),
          side: const BorderSide(color: skyBlue, width: 1.6),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: skyBlue),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: skyBlue,
        thumbColor: skyBlue,
        inactiveTrackColor: lineSoft,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F9FD),
        hintStyle: const TextStyle(color: bodyText),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lineSoft, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: skyBlue, width: 1.8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: lineSoft, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardWhite,
        surfaceTintColor: Colors.transparent,
        indicatorColor: skyBlue.withValues(alpha: 0.16),
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: serifFamily,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? skyBlue : bodyText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? skyBlue : bodyText);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: const TextStyle(
            color: Colors.white, fontFamily: serifFamily),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lineSoft, thickness: 1),
    );
  }
}
