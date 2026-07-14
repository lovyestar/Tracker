import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

import 'config/api_keys.dart';
import 'constants/app_theme.dart';
import 'services/active_course_store.dart';
import 'services/firebase_service.dart';
import 'services/place_repository.dart';
import 'services/voice_service.dart';
import 'screens/main_shell.dart';
import 'widgets/place_photo.dart';

Future<void> main() async {
  // Flutter 엔진과 위젯 바인딩을 먼저 초기화합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // Kakao 지도 SDK를 네이티브 앱 키로 초기화합니다. (SPEC §2)
  await KakaoMapSdk.instance.initialize(ApiKeys.kakaoNativeAppKey);

  // 장소 이름→id 인덱스를 심어 실사진(assets/place_photos)을 카드에서 찾게 합니다.
  try {
    PhotoIndex.seed(await PlaceRepository().loadNameToId());
  } catch (_) {
    // DB 로드 실패 시 사진은 컬러 플레이스홀더로 대체됩니다.
  }

  // 영매기 목소리 토글 값을 미리 읽어옵니다(기본 on).
  await VoiceService.instance.init();

  // 진행 중 코스(내비게이션 모드)를 미리 읽어옵니다(앱 재시작 유지).
  await ActiveCourseStore.instance.init();

  // Firebase 초기화. google-services.json 이 없으면 실패하는데,
  // try/catch 로 감싸서 앱이 죽지 않고 "로컬 모드"로 동작하게 합니다. (SPEC §7)
  try {
    await Firebase.initializeApp();
    FirebaseService.markInitialized();
  } catch (_) {
    // Firebase 미설정 → 리더보드/서버 저장 비활성, 로컬 기록만 사용.
  }

  runApp(const TrackerApp());
}

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '영도 AI 스탬프 투어',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const MainShell(),
    );
  }
}
