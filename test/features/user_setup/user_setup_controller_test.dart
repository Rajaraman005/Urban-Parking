import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/parking/domain/owner_parking_repository.dart';
import 'package:urban_parking/features/user_setup/domain/user_setup_repository.dart';
import 'package:urban_parking/features/user_setup/domain/user_setup_state.dart';
import 'package:urban_parking/features/user_setup/presentation/user_setup_controller.dart';

void main() {
  test('host listing draft hydrates legacy parking space payloads', () {
    final draft = HostListingDraft.fromJson({
      'id': 'legacy-draft-1',
      'status': 'draft',
      'storageKind': 'legacy_parking_space',
      'currentStep': 'host_photos',
      'version': 7,
      'title': 'Station parking',
      'address': '12 Main Road',
      'locality': 'Egmore',
      'city': 'Chennai',
      'postal_code': '600008',
      'latitude': 13.0827,
      'longitude': 80.2707,
      'parking_type': 'covered',
      'vehicle_fit': 'car',
      'access_instructions':
          'Covered parking near the entrance with clear lighting and access.',
      'hourly_price': 70,
      'slots_count': 2,
      'available_from_date': '2026-05-07',
      'available_to_date': '2026-06-07',
      'daily_start_minute': 480,
      'daily_end_minute': 1200,
      'skip_weekends': false,
      'parking_space_photos': [
        {
          'id': 'photo-1',
          'public_id': 'parking/photo-1',
          'secure_url': 'https://example.com/photo-1.jpg',
          'sort_order': 0,
        },
      ],
    });

    expect(draft.isLegacyParkingSpaceDraft, isTrue);
    expect(draft.currentStep, 'host_photos');
    expect(draft.title, 'Station parking');
    expect(draft.address, '12 Main Road');
    expect(draft.location?.latitude, closeTo(13.0827, 0.0001));
    expect(draft.hourlyPrice, 70);
    expect(draft.photos, hasLength(1));
  });

  test('host setup can start before loading the setup snapshot', () async {
    final container = _container();
    addTearDown(container.dispose);

    final state = await container
        .read(userSetupControllerProvider.notifier)
        .startHostListing();

    expect(state.intent, 'host');
    expect(state.step, 'host_basics');
    expect(state.draftId, 'draft-1');
  });

  test('host setup advances through persisted feature steps', () async {
    final container = _container();
    addTearDown(container.dispose);

    await container.read(userSetupControllerProvider.future);
    final controller = container.read(userSetupControllerProvider.notifier);

    var state = await controller.saveIntent('host');
    expect(state.step, 'profile');

    state = await controller.startHostListing();
    expect(state.intent, 'host');
    expect(state.step, 'host_basics');

    state = await controller.saveProfile(
      fullName: 'Test Host',
      phone: '9876543210',
      gender: 'prefer_not_to_say',
      dob: '01/01/1990',
    );
    expect(state.step, 'host_basics');

    state = await controller.saveHostBasics(
      const HostBasicsDraftUpdate(
        address: '12 Main Road, Chennai',
        city: 'Chennai',
        locality: 'Anna Nagar',
        location: GeoPoint(latitude: 13.0827, longitude: 80.2707),
        parkingType: 'open',
        postalCode: '600001',
        stateName: 'Tamil Nadu',
        title: 'Car parking',
        vehicleFit: 'car',
      ),
    );
    expect(state.step, 'host_pricing');

    state = await controller.startHostListing();
    expect(state.step, 'host_pricing');

    state = await controller.saveHostPricing(
      HostPricingDraftUpdate(
        availableFromDate: DateTime(2026, 5, 7),
        availableToDate: DateTime(2026, 6, 7),
        dailyEndMinute: 20 * 60,
        dailyStartMinute: 8 * 60,
        hourlyPrice: 60,
        skipWeekends: false,
        slotsCount: 1,
      ),
    );
    expect(state.step, 'host_photos');

    state = await controller.uploadHostPhoto(_photo('photo-1'));
    state = await controller.uploadHostPhoto(_photo('photo-2'));
    expect(state.draft?.photos, hasLength(2));

    state = await controller.completeHostPhotosStep();
    expect(state.step, 'host_review');

    state = await controller.submitHostListing();
    expect(state.step, 'complete');
    expect(state.draft?.status, 'pending_review');
  });
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      userSetupRepositoryProvider.overrideWithValue(_FakeUserSetupRepository()),
    ],
  );
}

HostPhotoUploadCandidate _photo(String name) {
  return HostPhotoUploadCandidate(
    bytes: Uint8List.fromList(List<int>.filled(1024, 1)),
    fileName: '$name.jpg',
    height: 640,
    mimeType: 'image/jpeg',
    width: 640,
  );
}

class _FakeUserSetupRepository implements UserSetupRepository {
  UserSetupState _state = const UserSetupState();
  HostListingDraft? _draft;

  @override
  Future<UserSetupState> loadSnapshot() async => _state;

  @override
  Future<HostListingDraft?> loadHostDraftResumeCandidate() async => _draft;

  @override
  Future<UserSetupState> saveIntent(String intent) async {
    _state = UserSetupState(intent: intent, step: 'profile');
    return _state;
  }

  @override
  Future<UserSetupState> startHostListing({
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  }) async {
    if (createNew) {
      _draft = null;
    }
    _draft ??= const HostListingDraft(
      id: 'draft-1',
      status: 'draft',
      version: 1,
    );
    final step = resumeStep ?? _state.step;
    final nextStep = _validHostStep(step)
        ? step
        : _firstIncompleteStep(_draft!);
    _state = UserSetupState(
      draft: _draft,
      draftId: _draft!.id,
      intent: 'host',
      step: nextStep,
    );
    return _state;
  }

  @override
  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  }) async {
    _state = _state.copyWith(step: 'host_basics');
    return _state;
  }

  @override
  Future<List<ParkingAddressCandidate>> searchAddress(String query) async {
    return const [
      ParkingAddressCandidate(
        address: '12 Main Road, Chennai',
        city: 'Chennai',
        confidence: 0.92,
        latitude: 13.0827,
        locality: 'Anna Nagar',
        longitude: 80.2707,
        postalCode: '600001',
        provider: 'nominatim',
      ),
    ];
  }

  @override
  Future<UserSetupState> saveHostBasics(HostBasicsDraftUpdate update) async {
    _draft = HostListingDraft(
      id: _draft?.id ?? 'draft-1',
      status: 'draft',
      version: (_draft?.version ?? 0) + 1,
      address: update.address,
      city: update.city,
      locality: update.locality,
      location: update.location,
      parkingType: update.parkingType,
      postalCode: update.postalCode,
      stateName: update.stateName,
      title: update.title,
      vehicleFit: update.vehicleFit,
    );
    _state = UserSetupState(
      draft: _draft,
      draftId: _draft!.id,
      intent: 'host',
      step: 'host_pricing',
    );
    return _state;
  }

  @override
  Future<UserSetupState> saveHostPricing(HostPricingDraftUpdate update) async {
    final draft = _draft!;
    _draft = HostListingDraft(
      id: draft.id,
      status: draft.status,
      version: draft.version + 1,
      address: draft.address,
      availableFromDate: update.availableFromDate,
      availableToDate: update.availableToDate,
      city: draft.city,
      dailyEndMinute: update.dailyEndMinute,
      dailyStartMinute: update.dailyStartMinute,
      hourlyPrice: update.hourlyPrice,
      locality: draft.locality,
      location: draft.location,
      parkingType: draft.parkingType,
      postalCode: draft.postalCode,
      skipWeekends: update.skipWeekends,
      slotsCount: update.slotsCount,
      stateName: draft.stateName,
      title: draft.title,
      vehicleFit: draft.vehicleFit,
    );
    _state = UserSetupState(
      draft: _draft,
      draftId: _draft!.id,
      intent: 'host',
      step: 'host_photos',
    );
    return _state;
  }

  @override
  Future<UserSetupState> uploadHostPhoto(HostPhotoUploadCandidate image) async {
    final draft = _draft!;
    final photos = [
      ...draft.photos,
      HostListingPhoto(
        id: 'photo-${draft.photos.length + 1}',
        publicId: image.fileName,
        secureUrl: 'https://example.com/${image.fileName}',
        sortOrder: draft.photos.length,
      ),
    ];
    _draft = _copyDraft(draft, photos: photos);
    _state = _state.copyWith(draft: _draft, step: 'host_photos');
    return _state;
  }

  @override
  Future<UserSetupState> deleteHostPhoto(String photoId) async {
    final draft = _draft!;
    _draft = _copyDraft(
      draft,
      photos: draft.photos.where((photo) => photo.id != photoId).toList(),
    );
    _state = _state.copyWith(draft: _draft);
    return _state;
  }

  @override
  Future<UserSetupState> reorderHostPhotos(List<String> photoIds) async {
    final draft = _draft!;
    final byId = {for (final photo in draft.photos) photo.id: photo};
    _draft = _copyDraft(
      draft,
      photos: [
        for (var index = 0; index < photoIds.length; index++)
          HostListingPhoto(
            id: byId[photoIds[index]]!.id,
            publicId: byId[photoIds[index]]!.publicId,
            secureUrl: byId[photoIds[index]]!.secureUrl,
            sortOrder: index,
          ),
      ],
    );
    _state = _state.copyWith(draft: _draft);
    return _state;
  }

  @override
  Future<UserSetupState> markPhotosStepComplete() async {
    _state = _state.copyWith(step: 'host_review');
    return _state;
  }

  @override
  Future<UserSetupState> submitForReview() async {
    _draft = _copyDraft(_draft!, status: 'pending_review');
    _state = _state.copyWith(draft: _draft, step: 'complete');
    return _state;
  }

  bool _validHostStep(String? step) {
    return const {
      'host_basics',
      'host_pricing',
      'host_photos',
      'host_review',
    }.contains(step);
  }

  String _firstIncompleteStep(HostListingDraft draft) {
    if (!draft.hasBasics) return 'host_basics';
    if (!draft.hasPricing) return 'host_pricing';
    if (!draft.hasRequiredPhotos) return 'host_photos';
    return 'host_review';
  }

  HostListingDraft _copyDraft(
    HostListingDraft draft, {
    List<HostListingPhoto>? photos,
    String? status,
  }) {
    return HostListingDraft(
      id: draft.id,
      status: status ?? draft.status,
      version: draft.version + 1,
      address: draft.address,
      availableFromDate: draft.availableFromDate,
      availableToDate: draft.availableToDate,
      city: draft.city,
      dailyEndMinute: draft.dailyEndMinute,
      dailyStartMinute: draft.dailyStartMinute,
      hourlyPrice: draft.hourlyPrice,
      locality: draft.locality,
      location: draft.location,
      parkingType: draft.parkingType,
      photos: photos ?? draft.photos,
      postalCode: draft.postalCode,
      skipWeekends: draft.skipWeekends,
      slotsCount: draft.slotsCount,
      stateName: draft.stateName,
      title: draft.title,
      vehicleFit: draft.vehicleFit,
    );
  }
}
