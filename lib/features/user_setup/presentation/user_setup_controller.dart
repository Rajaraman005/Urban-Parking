import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_setup_repository_impl.dart';
import '../domain/user_setup_repository.dart';
import '../domain/user_setup_state.dart';

final userSetupRepositoryProvider = Provider<UserSetupRepository>((ref) {
  return UserSetupRepositoryImpl();
});

final userSetupControllerProvider =
    AsyncNotifierProvider<UserSetupController, UserSetupState>(
      UserSetupController.new,
    );

class UserSetupController extends AsyncNotifier<UserSetupState> {
  late final UserSetupRepository _repository;

  @override
  Future<UserSetupState> build() {
    _repository = ref.watch(userSetupRepositoryProvider);
    return _repository.loadSnapshot();
  }

  Future<UserSetupState> saveIntent(String intent) async {
    final next = await _repository.saveIntent(intent);
    state = AsyncData(next);
    return next;
  }

  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  }) async {
    final next = await _repository.saveProfile(
      fullName: fullName,
      phone: phone,
      gender: gender,
      dob: dob,
    );
    state = AsyncData(next);
    return next;
  }

  Future<UserSetupState> advanceHostStep(String step) async {
    final next = switch (step) {
      'host_basics' => await _repository.saveHostBasics(),
      'host_pricing' => await _repository.saveHostPricing(),
      'host_photos' => await _repository.markPhotosStepComplete(),
      'host_review' => await _repository.submitForReview(),
      _ => await _repository.loadSnapshot(),
    };
    state = AsyncData(next);
    return next;
  }
}
