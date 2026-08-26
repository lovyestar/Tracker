import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/services/auth_service.dart';

/// AuthService 테스트입니다.
///
/// Firebase 를 초기화하지 않은 상태(FirebaseService.isAvailable == false)에서
/// 로그인/조회 API 가 **예외 없이 안전한 기본값**을 돌려주는지만 검증합니다.
/// (실제 Google/Firebase 흐름은 플랫폼 채널이 필요해 단위 테스트 범위를 넘어섭니다.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService (Firebase 미초기화)', () {
    test('currentUser 는 null 이고 isSignedIn 은 false 다', () {
      expect(AuthService.instance.currentUser, isNull);
      expect(AuthService.instance.isSignedIn, isFalse);
    });

    test('authStateChanges 는 null 을 방출한다', () async {
      final first = await AuthService.instance.authStateChanges().first;
      expect(first, isNull);
    });

    test('signInWithGoogle 은 예외 없이 실패 결과를 돌려준다', () async {
      final result = await AuthService.instance.signInWithGoogle();
      expect(result.isSuccess, isFalse);
      expect(result.cancelled, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('signOut 은 예외를 던지지 않는다', () async {
      await expectLater(AuthService.instance.signOut(), completes);
    });
  });

  group('AuthResult', () {
    test('cancelled 팩토리는 성공/오류가 아니다', () {
      final r = AuthResult.cancelled();
      expect(r.isSuccess, isFalse);
      expect(r.cancelled, isTrue);
      expect(r.errorMessage, isNull);
    });

    test('failure 팩토리는 메시지를 담고 성공이 아니다', () {
      final r = AuthResult.failure('실패');
      expect(r.isSuccess, isFalse);
      expect(r.errorMessage, '실패');
    });
  });
}
