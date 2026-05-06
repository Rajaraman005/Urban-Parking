import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository_impl.dart';
import '../domain/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl();
});

final profileDetailsControllerProvider =
    AsyncNotifierProvider<ProfileDetailsController, void>(
      ProfileDetailsController.new,
    );

class ProfileDetailsController extends AsyncNotifier<void> {
  late final ProfileRepository _repository;

  @override
  void build() {
    _repository = ref.watch(profileRepositoryProvider);
  }

  Future<UserProfile> updatePersonalDetails(ProfileDetailsUpdate update) async {
    state = const AsyncLoading();
    try {
      final profile = await _repository.updatePersonalDetails(update);
      ref.read(authControllerProvider.notifier).replaceProfile(profile);
      state = const AsyncData(null);
      return profile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<UserProfile> updateAvatar(ProfileAvatarUploadCandidate image) async {
    state = const AsyncLoading();
    try {
      final profile = await _repository.updateAvatar(image);
      ref.read(authControllerProvider.notifier).replaceProfile(profile);
      state = const AsyncData(null);
      return profile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
