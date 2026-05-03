import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  late final AuthRepository _repository;

  @override
  Future<AuthState> build() async {
    _repository = ref.watch(authRepositoryProvider);
    return _repository.hydrate();
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () =>
          _repository.signInWithEmailPassword(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.signUpWithEmailPassword(
        fullName: fullName,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.signInWithGoogle);
  }

  Future<void> signOut() async {
    await _repository.signOut();
    await ref.read(geoDiscoveryCacheProvider).clear();
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }

  Future<AuthState> refreshSessionOrLogout() async {
    final next = await _repository.refreshSessionOrLogout();
    state = AsyncData(next);
    return next;
  }
}
