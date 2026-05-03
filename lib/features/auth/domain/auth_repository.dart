import 'auth_state.dart';

abstract interface class AuthRepository {
  Future<AuthState> hydrate();
  Future<AuthState> signInWithEmailPassword({
    required String email,
    required String password,
  });
  Future<AuthState> signUpWithEmailPassword({
    required String fullName,
    required String email,
    required String password,
  });
  Future<AuthState> signInWithGoogle();
  Future<void> requestSignupOtp();
  Future<void> verifySignupOtp({required String token});
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<AuthState> refreshSessionOrLogout();
  Future<void> signOut();
}
