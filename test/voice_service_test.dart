import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_app/services/voice_service.dart';

/// 영매기 음성 서비스 테스트입니다.
///  - 대사 enum ↔ mp3 자산 매핑 무결성
///  - 토글(shared_preferences) 저장/로드 및 기본 on
///  - 음성 실패가 앱 흐름에 영향 없도록 play() 가 절대 예외를 던지지 않음
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceService', () {
    test('모든 VoiceLine 이 assets/voice 의 mp3 파일명과 일치한다', () {
      const expected = {
        VoiceLine.greetingFirst: 'greeting_first.mp3',
        VoiceLine.recommendStart: 'recommend_start.mp3',
        VoiceLine.stampFirst: 'stamp_first.mp3',
        VoiceLine.stampGet: 'stamp_get.mp3',
        VoiceLine.stampLastOne: 'stamp_last_one.mp3',
        VoiceLine.complete: 'complete.mp3',
      };
      expect(VoiceLine.values.length, expected.length);
      for (final line in VoiceLine.values) {
        expect(line.asset, expected[line]);
        expect(line.asset.endsWith('.mp3'), isTrue);
      }
    });

    test('저장값이 없으면 기본 on 이다', () async {
      SharedPreferences.setMockInitialValues({});
      await VoiceService.instance.init();
      expect(VoiceService.instance.enabled, isTrue);
    });

    test('setEnabled 가 상태와 shared_preferences 에 반영된다', () async {
      SharedPreferences.setMockInitialValues({});
      await VoiceService.instance.setEnabled(false);
      expect(VoiceService.instance.enabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(VoiceService.prefsKey), isFalse);

      // 새 init() 이 저장된 off 값을 그대로 읽어온다.
      await VoiceService.instance.init();
      expect(VoiceService.instance.enabled, isFalse);
    });

    test('off 이면 play() 가 즉시 return 하며 예외를 던지지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      await VoiceService.instance.setEnabled(false);
      // off 이므로 오디오 플랫폼을 건드리지 않고 조용히 반환해야 한다.
      await VoiceService.instance.play(VoiceLine.greetingFirst);
    });
  });
}
