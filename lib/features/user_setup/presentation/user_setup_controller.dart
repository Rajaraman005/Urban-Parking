import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/validation/indian_vehicle_registration.dart';
import '../../auth/presentation/auth_controller.dart';
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
  Future<HostListingDraft?>? _resumeLookupInFlight;
  Future<UserSetupState>? _startHostListingInFlight;
  String? _startHostListingInFlightKey;

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
    final inFlight = _resumeLookupInFlight;
    if (inFlight != null) return inFlight;

    final future = _repo.loadHostDraftResumeCandidate();
    _resumeLookupInFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_resumeLookupInFlight, future)) {
          _resumeLookupInFlight = null;
        }
      }),
    );
    return future;
  }

  Future<UserSetupState> startHostListing({
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  }) async {
    final key = '$createNew|${resumeDraftId ?? ''}|${resumeStep ?? ''}';
    final inFlight = _startHostListingInFlight;
    if (inFlight != null && _startHostListingInFlightKey == key) {
      return inFlight;
    }

    final future = _run(
      () => _repo.startHostListing(
        createNew: createNew,
        resumeDraftId: resumeDraftId,
        resumeStep: resumeStep,
      ),
    );
    _startHostListingInFlight = future;
    _startHostListingInFlightKey = key;
    try {
      final next = await future;
      _syncAuthProfile(next);
      return next;
    } finally {
      if (identical(_startHostListingInFlight, future)) {
        _startHostListingInFlight = null;
        _startHostListingInFlightKey = null;
      }
    }
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
    final next = await _setData(
      () => _repo.saveProfile(
        fullName: fullName,
        phone: phone,
        gender: gender,
        dob: dob,
      ),
    );
    _syncSavedProfile(
      dob: dob,
      fullName: fullName,
      gender: gender,
      nextStep: next.step,
      phone: phone,
    );
    return next;
  }

  Future<UserSetupState> saveVehicleDetails({
    bool createNew = false,
    String? previousVehicleRegistration,
    bool syncPrimaryProfile = true,
    String? vehicleId,
    String? vehicleMake,
    String? vehicleModel,
    required String vehicleRegistration,
    required String vehicleType,
  }) async {
    final next = await _setData(
      () => _repo.saveVehicleDetails(
        createNew: createNew,
        previousVehicleRegistration: previousVehicleRegistration,
        vehicleId: vehicleId,
        vehicleMake: vehicleMake,
        vehicleModel: vehicleModel,
        vehicleRegistration: vehicleRegistration,
        vehicleType: vehicleType,
      ),
    );
    _syncSavedVehicleDetails(
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      previousVehicleRegistration: previousVehicleRegistration,
      vehicleRegistration: vehicleRegistration,
      vehicleType: vehicleType,
      createNew: createNew,
      syncPrimaryProfile: syncPrimaryProfile,
    );
    return next;
  }

  Future<UserSetupState> advanceHostStep(String step) async {
    final next = switch (step) {
      'host_photos' => await _repo.markPhotosStepComplete(),
      'host_review' => await _repo.submitForReview(),
      _ => await _repo.loadSnapshot(),
    };
    state = AsyncData(next);
    _syncAuthProfile(next);
    return next;
  }

  Future<UserSetupState> _run(Future<UserSetupState> Function() action) async {
    state = const AsyncLoading();
    try {
      final next = await action();
      state = AsyncData(next);
      _syncAuthProfile(next);
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

  void _syncAuthProfile(UserSetupState setupState) {
    final draft = setupState.draft;
    final auth = ref.read(authControllerProvider.notifier);
    if (draft == null ||
        setupState.step == 'complete' ||
        draft.status != 'draft') {
      auth.clearHostDraftReference(draftId: setupState.draftId);
      return;
    }

    auth.setHostDraftReference(
      draftId: draft.id,
      legacyDraft: draft.isLegacyParkingSpaceDraft,
      step: setupState.step,
    );
  }

  void _syncSavedProfile({
    required String dob,
    required String fullName,
    required String gender,
    required String nextStep,
    required String phone,
  }) {
    final current = ref.read(authControllerProvider).value;
    final profile = current?.profile;
    if (current == null || profile == null) return;

    final parsedDob = _parseDate(dob);
    ref
        .read(authControllerProvider.notifier)
        .replaceProfile(
          profile.copyWith(
            dob: parsedDob,
            fullName: fullName.trim(),
            gender: gender.trim(),
            onboardingCompletedAt: nextStep == 'complete'
                ? DateTime.now().toUtc()
                : null,
            phone: phone.trim(),
            setupStep: nextStep,
            version: profile.version + 1,
          ),
        );
  }

  void _syncSavedVehicleDetails({
    bool createNew = false,
    String? previousVehicleRegistration,
    bool syncPrimaryProfile = true,
    String? vehicleMake,
    String? vehicleModel,
    required String vehicleRegistration,
    required String vehicleType,
  }) {
    final current = ref.read(authControllerProvider).value;
    final profile = current?.profile;
    if (current == null || profile == null) return;

    final currentRegistration =
        _blankToNull(profile.vehicleRegistration) == null
        ? null
        : _normalizeVehicleRegistrationForState(profile.vehicleRegistration!);
    final nextRegistration = _normalizeVehicleRegistrationForState(
      vehicleRegistration,
    );
    final previousRegistration = previousVehicleRegistration == null
        ? null
        : _normalizeVehicleRegistrationForState(previousVehicleRegistration);
    final updatesPrimary =
        syncPrimaryProfile &&
        (currentRegistration == null ||
            (!createNew &&
                (currentRegistration == nextRegistration ||
                    currentRegistration == previousRegistration)));

    ref
        .read(authControllerProvider.notifier)
        .replaceProfile(
          profile.copyWith(
            intent: 'park',
            onboardingCompletedAt: DateTime.now().toUtc(),
            setupStep: 'complete',
            vehicleMake: updatesPrimary ? _blankToNull(vehicleMake) : null,
            clearVehicleMake:
                updatesPrimary && _blankToNull(vehicleMake) == null,
            vehicleModel: updatesPrimary ? _blankToNull(vehicleModel) : null,
            clearVehicleModel:
                updatesPrimary && _blankToNull(vehicleModel) == null,
            vehicleRegistration: updatesPrimary ? nextRegistration : null,
            vehicleType: updatesPrimary
                ? vehicleType.trim().toLowerCase()
                : null,
            version: profile.version + 1,
          ),
        );
  }
}

DateTime? _parseDate(String value) {
  final text = value.trim();
  final slashMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (slashMatch != null) {
    final day = int.tryParse(slashMatch.group(1)!);
    final month = int.tryParse(slashMatch.group(2)!);
    final year = int.tryParse(slashMatch.group(3)!);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String? _blankToNull(String? value) {
  final text = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
  return text == null || text.isEmpty ? null : text;
}

String _normalizeVehicleRegistrationForState(String value) {
  return IndianVehicleRegistration.normalize(value) ??
      IndianVehicleRegistration.compact(value);
}
