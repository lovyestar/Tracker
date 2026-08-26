import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 영매기 음성 대사 종류입니다. 각 값은 assets/voice/ 의 mp3 파일에 대응합니다.
enum VoiceLine {
  greetingFirst('greeting_first.mp3'),
  recommendStart('recommend_start.mp3'),
  stampFirst('stamp_first.mp3'),
  stampGet('stamp_get.mp3'),
  stampLastOne('stamp_last_one.mp3'),
  complete('complete.mp3');

  const VoiceLine(this.asset);

  /// AssetSource 경로(자동으로 assets/ 접두사가 붙습니다).
  final String asset;
}

/// 영매기 TTS 음성 재생 서비스입니다.
///
/// 설계 원칙:
///  - 싱글턴 + AudioPlayer 1개 재사용.
///  - 이미 재생 중이면 중지 후 새 대사를 재생.
///  - "영매기 목소리" 토글(off)이면 즉시 return.
///  - 모든 예외를 삼켜서 음성 실패가 앱 동작에 절대 영향을 주지 않게 합니다.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const String prefsKey = 'voice_enabled';

  /// AudioPlayer 는 실제로 재생할 때 처음 한 번만 생성합니다(1개 재사용).
  AudioPlayer? _player;
  AudioPlayer get _audio => _player ??= AudioPlayer();

  /// 토글 상태(기본 on). init() 전에도 기본 on 으로 동작합니다.
  bool _enabled = true;
  bool get enabled => _enabled;

  /// 앱 시작 시 저장된 토글 값을 읽어옵니다.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(prefsKey) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  /// 토글 값을 저장하고 메모리 캐시를 갱신합니다. off 로 바꾸면 재생 중인 음성을 멈춥니다.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (_) {
      // 저장 실패는 무시합니다(메모리 값은 이미 반영됨).
    }
    if (!value && _player != null) {
      try {
        await _player!.stop();
      } catch (_) {}
    }
  }

  /// 대사 하나를 재생합니다. off 이면 아무 것도 하지 않으며, 예외는 전부 삼킵니다.
  Future<void> play(VoiceLine line) async {
    if (!_enabled) return;
    try {
      await _audio.stop();
      await _audio.play(AssetSource('voice/${line.asset}'));
    } catch (_) {
      // 음성 재생 실패가 앱 흐름에 영향을 주지 않도록 무시합니다.
    }
  }
}
