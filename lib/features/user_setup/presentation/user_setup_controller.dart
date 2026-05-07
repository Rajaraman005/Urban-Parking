import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../parking/domain/owner_parking_repository.dart';
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
  UserSetupRepository? _repository;

  UserSetupRepository get _repo {
    final repository = _repository;
    if (repository != null) return repository;

    final next = ref.read(userSetupRepositoryProvider);
    _repository = next;
    return next;
  }

  @override
  Future<UserSetupState> build() {
    final repository = ref.watch(userSetupRepositoryProvider);
    _repository = repository;
    return repository.loadSnapshot();
  }

  Future<UserSetupState> saveIntent(String intent) async {
    return _setData(() => _repo.saveIntent(intent));
  }

  Future<HostListingDraft?> loadHostDraftResumeCandidate() {
    return _repo.loadHostDraftResumeCandidate();
  }

  Future<UserSetupState> startHostListing({
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  }) async {
    return _run(
      () => _repo.startHostListing(
        createNew: createNew,
        resumeDraftId: resumeDraftId,
        resumeStep: resumeStep,
      ),
    );
  }

  void prepareNewHostListing() {
    state = const AsyncData(
      UserSetupState(
        intent: 'host',
        step: 'host_basics',
        message: 'Hosting setup started',
      ),
    );
  }

  Future<List<ParkingAddressCandidate>> searchAddress(String query) {
    return _repo.searchAddress(query);
  }

  Future<UserSetupState> saveHostBasics(HostBasicsDraftUpdate update) {
    return _run(() => _repo.saveHostBasics(update));
  }

  Future<UserSetupState> saveHostPricing(HostPricingDraftUpdate update) {
    return _run(() => _repo.saveHostPricing(update));
  }

  Future<UserSetupState> uploadHostPhoto(HostPhotoUploadCandidate image) {
    return _run(() => _repo.uploadHostPhoto(image));
  }

  Future<UserSetupState> deleteHostPhoto(String photoId) {
    return _run(() => _repo.deleteHostPhoto(photoId));
  }

  Future<UserSetupState> reorderHostPhotos(List<String> photoIds) {
    return _run(() => _repo.reorderHostPhotos(photoIds));
  }

  Future<UserSetupState> completeHostPhotosStep() {
    return _run(_repo.markPhotosStepComplete);
  }

  Future<UserSetupState> submitHostListing() {
    return _run(_repo.submitForReview);
  }

  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  }) async {
    return _setData(
      () => _repo.saveProfile(
        fullName: fullName,
        phone: phone,
        gender: gender,
        dob: dob,
      ),
    );
  }

  Future<UserSetupState> advanceHostStep(String step) async {
    final next = switch (step) {
      'host_photos' => await _repo.markPhotosStepComplete(),
      'host_review' => await _repo.submitForReview(),
      _ => await _repo.loadSnapshot(),
    };
    state = AsyncData(next);
    return next;
  }

  Future<UserSetupState> _run(Future<UserSetupState> Function() action) async {
    state = const AsyncLoading();
    try {
      final next = await action();
      state = AsyncData(next);
      return next;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<UserSetupState> _setData(
    Future<UserSetupState> Function() action,
  ) async {
    final next = await action();
    state = AsyncData(next);
    return next;
  }
}
