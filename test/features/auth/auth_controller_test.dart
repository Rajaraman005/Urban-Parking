import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/auth/domain/auth_repository.dart';
import 'package:urban_parking/features/auth/domain/auth_state.dart';
import 'package:urban_parking/features/auth/presentation/auth_controller.dart';

void main() {
  test(
    'signOut marks user logged out before provider cleanup completes',
    () async {
      final cleanup = Completer<void>();
      final repository = _BlockingSignOutRepository(cleanup);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .signOut()
          .timeout(const Duration(milliseconds: 100));

      expect(repository.signOutStarted, isTrue);
      expect(cleanup.isCompleted, isFalse);
      expect(
        container.read(authControllerProvider).value?.status,
        AuthStatus.unauthenticated,
      );

      cleanup.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );
}

class _BlockingSignOutRepository implements AuthRepository {
  _BlockingSignOutRepository(this._signOutCleanup);

  final Completer<void> _signOutCleanup;
  bool signOutStarted = false;

  @override
  Future<AuthState> hydrate() async {
    return const AuthState(
      status: AuthStatus.authenticated,
      user: AppUser(id: 'user-1', email: 'user@example.com'),
      profile: UserProfile(id: 'user-1', email: 'user@example.com'),
    );
  }

  @override
  Future<AuthState> refreshSessionOrLogout() => hydrate();

  @override
  Future<void> requestSignupOtp() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<AuthState> signInWithEmailPassword({
    required String email,
    required String password,
  }) => hydrate();

  @override
  Future<AuthState> signInWithGoogle() => hydrate();

  @override
  Future<void> signOut() {
    signOutStarted = true;
    return _signOutCleanup.future;
  }

  @override
  Future<AuthState> signUpWithEmailPassword({
    required String fullName,
    required String email,
    required String password,
  }) => hydrate();

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> verifySignupOtp({required String token}) async {}
}
