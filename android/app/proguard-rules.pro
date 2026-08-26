# Kakao VectorMap(지도) 관련 클래스는 난독화/삭제되지 않도록 보존합니다.
# release 빌드(코드 축소)에서 지도가 하얗게 나오거나 크래시나는 것을 막습니다.
-keep class com.kakao.vectormap.** { *; }
-keep interface com.kakao.vectormap.** { *; }

# Flutter 기본 보존 규칙
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter 가 참조하는 Play Core(앱 분할 설치용) 클래스는
# 이 앱에서 실제로 사용하지 않으므로 R8 누락 경고를 무시합니다.
# (assembleRelease 시 'Missing class com.google.android.play.core...' 오류 방지)
-dontwarn com.google.android.play.core.**
