import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_service.dart';

/// Google 로그인 결과입니다.
///  - [cancelled] : 사용자가 로그인 창을 닫음(조용히 종료, 오류 아님).
///  - [user] 가 있으면 성공, [errorMessage] 가 있으면 실패.
class AuthResult {
  final User? user;
  final String? errorMessage;
  final bool cancelled;

  const AuthResult._({this.user, this.errorMessage, this.cancelled = false});

  factory AuthResult.success(User user) => AuthResult._(user: user);
  factory AuthResult.cancelled() => const AuthResult._(cancelled: true);
  factory AuthResult.failure(String message) =>
      AuthResult._(errorMessage: message);

  bool get isSuccess => user != null;
}

/// Google/Firebase 인증 서비스(싱글턴)입니다.
///
/// 로그인은 **선택 사항**입니다. 비로그인(게스트)으로도 앱의 모든 기능이 동작하며,
/// Firebase 가 초기화되지 않았으면([FirebaseService.isAvailable] == false) 로그인은
/// 조용히 실패 처리되어 앱이 절대 죽지 않습니다.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 현재 로그인된 Firebase 사용자(비로그인/미초기화 시 null).
  User? get currentUser {
    if (!FirebaseService().isAvailable) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => currentUser != null;

  /// 로그인 상태 변화 스트림(미초기화 시 항상 null 을 방출).
  Stream<User?> authStateChanges() {
    if (!FirebaseService().isAvailable) {
      return Stream<User?>.value(null);
    }
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return Stream<User?>.value(null);
    }
  }

  /// Google 계정으로 로그인합니다.
  ///
  /// 흐름: GoogleSignIn → GoogleAuthProvider.credential → signInWithCredential.
  /// 취소 시 [AuthResult.cancelled], 실패 시 사용자용 메시지를 담은 [AuthResult.failure]
  /// 를 돌려주며 **예외를 밖으로 던지지 않습니다**(앱 크래시 방지).
  Future<AuthResult> signInWithGoogle() async {
    if (!FirebaseService().isAvailable) {
      return AuthResult.failure('로그인 서버 연결이 안 됐데이. 잠시 후 다시 해보이소.');
    }
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // 사용자가 취소함 → 조용히 종료.
        return AuthResult.cancelled();
      }
      final GoogleSignInAuthentication auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        return AuthResult.failure('로그인에 실패했데이. 다시 시도해보이소.');
      }
      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure('로그인 실패: ${e.message ?? e.code}');
    } catch (_) {
      return AuthResult.failure('로그인 중 문제가 생겼데이. 다시 시도해보이소.');
    }
  }

  /// 로그아웃합니다(Google + Firebase). 실패해도 예외를 던지지 않습니다.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // 무시: 세션이 이미 없을 수 있음.
    }
    try {
      if (FirebaseService().isAvailable) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      // 무시.
    }
  }
}
