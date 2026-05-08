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

  void replaceProfile(UserProfile profile) {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (current.user?.id != profile.id) {
      return;
    }
    state = AsyncData(current.copyWith(profile: profile));
  }

  void setHostDraftReference({
    required String draftId,
    required bool legacyDraft,
    required String step,
  }) {
    final current = state.value;
    final profile = current?.profile;
    if (current == null || profile == null) return;

    final nextProfile = profile.copyWith(
      intent: 'host',
      hostParkingDraftId: legacyDraft ? null : draftId,
      clearHostParkingDraftId: legacyDraft,
      setupDraftId: legacyDraft ? draftId : null,
      clearSetupDraftId: !legacyDraft,
      setupStep: step,
      version: profile.version + 1,
    );
    state = AsyncData(current.copyWith(profile: nextProfile));
  }

  void clearHostDraftReference({String? draftId}) {
    final current = state.value;
    final profile = current?.profile;
    if (current == null || profile == null) return;

    final clearsHostDraft =
        draftId == null || profile.hostParkingDraftId == draftId;
    final clearsLegacyDraft =
        draftId == null || profile.setupDraftId == draftId;
    if (!clearsHostDraft && !clearsLegacyDraft) return;

    final nextProfile = profile.copyWith(
      clearHostParkingDraftId: clearsHostDraft,
      clearSetupDraftId: clearsLegacyDraft,
      setupStep: _isHostSetupStep(profile.setupStep)
          ? 'profile'
          : profile.setupStep,
      version: profile.version + 1,
    );
    state = AsyncData(current.copyWith(profile: nextProfile));
  }
}

bool _isHostSetupStep(String step) {
  return const {
    'host_basics',
    'host_pricing',
    'host_photos',
    'host_review',
  }.contains(step);
}
