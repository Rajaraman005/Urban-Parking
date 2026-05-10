import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/telemetry.dart';
import '../../../shared/validation/indian_mobile_number.dart';
import '../../../shared/validation/indian_vehicle_registration.dart';
import '../../parking/domain/owner_parking_repository.dart';
import '../../parking/domain/parking_availability.dart';
import '../domain/user_setup_repository.dart';
import '../domain/user_setup_state.dart';

class UserSetupRepositoryImpl implements UserSetupRepository {
  UserSetupRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio();

  static const _legacyDraftSelect =
      '*, parking_space_photos(id, public_id, secure_url, width, height, sort_order, upload_status)';
  static const _hostSteps = {
    'host_basics',
    'host_pricing',
    'host_photos',
    'host_review',
  };
  static const _maxListingPhotoBytes = 10 * 1024 * 1024;
  static const _uuid = Uuid();

  final Dio _dio;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<UserSetupState> loadSnapshot() async {
    if (!AppConfig.isSupabaseConfigured) return const UserSetupState();

    final sb.SupabaseClient client;
    try {
      client = _client;
    } catch (_) {
      return const UserSetupState();
    }

    if (client.auth.currentUser == null) return const UserSetupState();

    try {
      final profile = await _ensureProfile();
      final rawProfileStep = _stringFrom(profile, 'setup_step');
      final profileStep = _validHostStep(rawProfileStep);
      final draftId =
          _stringFrom(profile, 'host_parking_draft_id') ??
          _stringFrom(profile, 'setup_draft_id');
      final loadedDraft = draftId == null
          ? null
          : await _loadListing(draftId, fallbackStep: profileStep);
      final draft = _isResumableHostDraft(loadedDraft) ? loadedDraft : null;
      final step =
          _validHostStep(draft?.currentStep) ??
          profileStep ??
          _validSetupStep(rawProfileStep) ??
          'intent';
      return UserSetupState(
        draft: draft,
        draftId: draft?.id ?? draftId,
        intent: _stringFrom(profile, 'intent'),
        step: step,
      );
    } catch (_) {
      return const UserSetupState();
    }
  }

  @override
  Future<HostListingDraft?> loadHostDraftResumeCandidate() async {
    if (!AppConfig.isSupabaseConfigured) return null;

    final sb.SupabaseClient client;
    try {
      client = _client;
    } catch (_) {
      return null;
    }

    if (client.auth.currentUser == null) return null;

    final profile = await _ensureProfile();
    final profileStep = _validHostStep(_stringFrom(profile, 'setup_step'));
    final profileDraftIds = <String>{
      for (final value in [
        _stringFrom(profile, 'host_parking_draft_id'),
        _stringFrom(profile, 'setup_draft_id'),
      ])
        if (value != null && value.trim().isNotEmpty) value.trim(),
    };

    final candidates = <HostListingDraft>[];
    final seenCandidateKeys = <String>{};
    void addCandidate(HostListingDraft? draft) {
      if (!_isResumableHostDraft(draft)) return;
      final key = '${draft!.storageKind}:${draft.id}';
      if (seenCandidateKeys.add(key)) candidates.add(draft);
    }

    final profileDraftsFuture = Future.wait<HostListingDraft?>(
      profileDraftIds.map(
        (draftId) => _loadListing(draftId, fallbackStep: profileStep),
      ),
    );
    final latestDraftIdFuture = _latestOwnedHostDraftId();
    final legacyDraftFuture = _latestLegacyDraft(fallbackStep: profileStep);

    for (final draft in await profileDraftsFuture) {
      addCandidate(draft);
    }

    final latestDraftId = await latestDraftIdFuture;
    if (latestDraftId != null && !profileDraftIds.contains(latestDraftId)) {
      final latestDraft = await _loadListing(latestDraftId);
      addCandidate(latestDraft);
    }

    addCandidate(await legacyDraftFuture);
    return _bestResumeDraft(candidates);
  }

  @override
  Future<UserSetupState> saveIntent(String intent) async {
    final client = _readyClient();
    final normalized = intent.trim();
    if (!const {'park', 'host'}.contains(normalized)) {
      throw const ValidationFailure(
        'Choose how you want to use Lotzi.',
        code: 'setup_intent_invalid',
      );
    }

    await _ensureProfile();
    await client
        .from('profiles')
        .update({'intent': normalized, 'setup_step': 'profile'})
        .eq('id', client.auth.currentUser!.id);
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'intent'});
    return UserSetupState(
      intent: normalized,
      step: 'profile',
      message: 'Intent saved',
    );
  }

  @override
  Future<UserSetupState> startHostListing({
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  }) async {
    final profile = await _ensureProfile();
    final savedProfileStep = _validHostStep(_stringFrom(profile, 'setup_step'));
    final profileDraftId =
        _stringFrom(profile, 'host_parking_draft_id') ??
        _stringFrom(profile, 'setup_draft_id');
    final draft = await _ensureDraft(
      createNew ? null : resumeDraftId ?? profileDraftId,
      createNew: createNew,
      fallbackStep: savedProfileStep,
    );
    final launchStep = createNew
        ? 'host_basics'
        : resumeStep ?? draft.currentStep ?? savedProfileStep;
    final step = _resolveHostStep(launchStep, draft);

    await _updateProfileSetup(
      intent: 'host',
      step: step,
      draftId: draft.id,
      legacyDraft: draft.isLegacyParkingSpaceDraft,
    );
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': step});
    return _stateForDraft(draft, step: step, message: 'Hosting setup started');
  }

  @override
  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  }) async {
    final client = _readyClient();
    final profile = await _ensureProfile();
    final intent = _stringFrom(profile, 'intent');
    if (!const {'park', 'host'}.contains(intent)) {
      throw const ValidationFailure(
        'Choose how you want to use Lotzi.',
        code: 'setup_intent_invalid',
      );
    }
    final nextStep = intent == 'host' ? 'host_basics' : 'vehicle_details';
    final normalizedFullName = _normalizeProfileName(fullName);
    final normalizedPhone = _normalizeProfilePhone(phone);
    final normalizedGender = _normalizeProfileGender(gender);
    final normalizedDob = _normalizeProfileDob(dob);

    final payload = <String, Object?>{
      'full_name': normalizedFullName,
      'phone': normalizedPhone,
      'gender': normalizedGender,
      'dob': normalizedDob,
      'setup_step': nextStep,
    };
    try {
      await client
          .from('profiles')
          .update(payload)
          .eq('id', client.auth.currentUser!.id);
    } on sb.PostgrestException catch (error) {
      throw _profileWriteFailure(
        error,
        fallbackMessage: 'Could not save your details. Please try again.',
      );
    }
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'profile'});

    return UserSetupState(
      intent: intent,
      step: nextStep,
      message: 'Profile saved',
    );
  }

  @override
  Future<UserSetupState> saveVehicleDetails({
    bool createNew = false,
    String? previousVehicleRegistration,
    String? vehicleId,
    String? vehicleMake,
    String? vehicleModel,
    required String vehicleRegistration,
    required String vehicleType,
  }) async {
    final client = _readyClient();
    final profile = await _ensureProfile();
    final intent = _stringFrom(profile, 'intent');
    if (intent != 'park') {
      throw const ValidationFailure(
        'Vehicle details are required for finding parking.',
        code: 'vehicle_details_intent_invalid',
      );
    }

    final normalizedType = _normalizeVehicleType(vehicleType);
    final normalizedRegistration = _normalizeVehicleRegistration(
      vehicleRegistration,
    );
    final normalizedPreviousRegistration = _normalizePreviousRegistration(
      previousVehicleRegistration,
    );
    final normalizedMake = _normalizeOptionalVehicleText(
      vehicleMake,
      fieldCode: 'vehicle_make',
      fieldLabel: 'Vehicle make',
    );
    final normalizedModel = _normalizeOptionalVehicleText(
      vehicleModel,
      fieldCode: 'vehicle_model',
      fieldLabel: 'Vehicle model',
    );

    final collectionSave = await _upsertProfileVehicle(
      createNew: createNew,
      previousVehicleRegistration: normalizedPreviousRegistration,
      profile: profile,
      vehicleId: vehicleId,
      vehicleMake: normalizedMake,
      vehicleModel: normalizedModel,
      vehicleRegistration: normalizedRegistration,
      vehicleType: normalizedType,
    );
    if (createNew && collectionSave == null) {
      throw const ConfigurationFailure(
        'Vehicle list storage is not deployed yet. Apply the latest profile migration before adding another vehicle.',
        code: 'profile_vehicles_schema_missing',
      );
    }
    final shouldUpdatePrimaryVehicle = collectionSave?.updatesPrimary ?? true;

    final payload = <String, Object?>{
      'setup_step': 'complete',
      'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
      'version': _intFrom(profile, 'version', fallback: 1) + 1,
    };
    if (shouldUpdatePrimaryVehicle) {
      payload.addAll({
        'vehicle_type': normalizedType,
        'vehicle_registration': normalizedRegistration,
        'vehicle_make': normalizedMake,
        'vehicle_model': normalizedModel,
      });
    }

    try {
      await client
          .from('profiles')
          .update(payload)
          .eq('id', client.auth.currentUser!.id);
    } on sb.PostgrestException catch (error) {
      if (_isVehicleProfileSchemaUnavailable(error)) {
        throw const ConfigurationFailure(
          'Vehicle setup is not deployed yet. Apply the latest profile migration.',
          code: 'vehicle_profile_schema_missing',
        );
      }
      throw _profileWriteFailure(
        error,
        fallbackMessage: 'Could not save your vehicle. Please try again.',
      );
    }

    telemetry.event(TelemetryEvent.setupStepSaved, {
      'step': 'vehicle_details',
      'vehicleType': normalizedType,
    });

    return const UserSetupState(
      intent: 'park',
      step: 'complete',
      message: 'Vehicle details saved',
    );
  }

  Future<_ProfileVehicleSaveResult?> _upsertProfileVehicle({
    required bool createNew,
    required String? previousVehicleRegistration,
    required Map<String, Object?> profile,
    required String? vehicleId,
    required String? vehicleMake,
    required String? vehicleModel,
    required String vehicleRegistration,
    required String vehicleType,
  }) async {
    final client = _readyClient();
    final userId = client.auth.currentUser!.id;

    try {
      var existingVehicles = await _loadProfileVehicleRows(userId);
      if (existingVehicles.isEmpty) {
        await _seedLegacyProfileVehicle(profile);
        existingVehicles = await _loadProfileVehicleRows(userId);
      }

      if (createNew) {
        if (_hasVehicleRegistration(existingVehicles, vehicleRegistration)) {
          throw const ValidationFailure(
            'This vehicle is already saved.',
            code: 'vehicle_already_saved',
          );
        }

        final saved = await client
            .from('profile_vehicles')
            .insert({
              'user_id': userId,
              'vehicle_type': vehicleType,
              'vehicle_registration': vehicleRegistration,
              'vehicle_make': vehicleMake,
              'vehicle_model': vehicleModel,
              'is_primary': existingVehicles.isEmpty,
            })
            .select('is_primary')
            .single();

        return _ProfileVehicleSaveResult(
          updatesPrimary: _boolFrom(saved['is_primary']),
        );
      }

      final editableVehicleId = _editableProfileVehicleId(vehicleId);
      if (editableVehicleId != null) {
        final target = _vehicleRowById(existingVehicles, editableVehicleId);
        if (target != null) {
          return _updateProfileVehicleRow(
            client: client,
            row: target,
            userId: userId,
            vehicleMake: vehicleMake,
            vehicleModel: vehicleModel,
            vehicleRegistration: vehicleRegistration,
            vehicleType: vehicleType,
          );
        }
      }

      if (previousVehicleRegistration != null) {
        final target = _vehicleRowByRegistration(
          existingVehicles,
          previousVehicleRegistration,
        );
        if (target != null) {
          return _updateProfileVehicleRow(
            client: client,
            row: target,
            userId: userId,
            vehicleMake: vehicleMake,
            vehicleModel: vehicleModel,
            vehicleRegistration: vehicleRegistration,
            vehicleType: vehicleType,
          );
        }
      }

      Map<String, Object?>? existing;
      for (final row in existingVehicles) {
        if (_stringFrom(row, 'vehicle_registration') == vehicleRegistration) {
          existing = row;
          break;
        }
      }
      final updatesPrimary =
          existingVehicles.isEmpty || _boolFrom(existing?['is_primary']);

      final saved = await client
          .from('profile_vehicles')
          .upsert({
            'user_id': userId,
            'vehicle_type': vehicleType,
            'vehicle_registration': vehicleRegistration,
            'vehicle_make': vehicleMake,
            'vehicle_model': vehicleModel,
            'is_primary': updatesPrimary,
          }, onConflict: 'user_id,vehicle_registration')
          .select('is_primary')
          .single();

      return _ProfileVehicleSaveResult(
        updatesPrimary: _boolFrom(saved['is_primary']),
      );
    } on sb.PostgrestException catch (error) {
      if (_isProfileVehiclesSchemaUnavailable(error)) {
        return null;
      }
      if (_isUniqueViolation(error)) {
        throw const ValidationFailure(
          'This vehicle is already saved.',
          code: 'vehicle_already_saved',
        );
      }
      throw _profileWriteFailure(
        error,
        fallbackMessage: 'Could not save your vehicle. Please try again.',
      );
    }
  }

  Future<List<Map<String, Object?>>> _loadProfileVehicleRows(
    String userId,
  ) async {
    final response = await _client
        .from('profile_vehicles')
        .select('id,vehicle_registration,is_primary')
        .eq('user_id', userId);
    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
  }

  bool _hasVehicleRegistration(
    List<Map<String, Object?>> rows,
    String registration,
  ) {
    for (final row in rows) {
      if (_stringFrom(row, 'vehicle_registration') == registration) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?>? _vehicleRowById(
    List<Map<String, Object?>> rows,
    String id,
  ) {
    for (final row in rows) {
      if (_stringFrom(row, 'id') == id) return row;
    }
    return null;
  }

  Map<String, Object?>? _vehicleRowByRegistration(
    List<Map<String, Object?>> rows,
    String registration,
  ) {
    for (final row in rows) {
      if (_stringFrom(row, 'vehicle_registration') == registration) {
        return row;
      }
    }
    return null;
  }

  Future<_ProfileVehicleSaveResult> _updateProfileVehicleRow({
    required sb.SupabaseClient client,
    required Map<String, Object?> row,
    required String userId,
    required String? vehicleMake,
    required String? vehicleModel,
    required String vehicleRegistration,
    required String vehicleType,
  }) async {
    final updatesPrimary = _boolFrom(row['is_primary']);
    final rowId = _stringFrom(row, 'id');
    final previousRegistration = _stringFrom(row, 'vehicle_registration');

    final update = client
        .from('profile_vehicles')
        .update({
          'vehicle_type': vehicleType,
          'vehicle_registration': vehicleRegistration,
          'vehicle_make': vehicleMake,
          'vehicle_model': vehicleModel,
        })
        .eq('user_id', userId);
    final filtered = rowId == null
        ? update.eq('vehicle_registration', previousRegistration ?? '')
        : update.eq('id', rowId);
    final saved = await filtered.select('is_primary').single();

    return _ProfileVehicleSaveResult(
      updatesPrimary: _boolFrom(saved['is_primary']) || updatesPrimary,
    );
  }

  String? _editableProfileVehicleId(String? vehicleId) {
    final id = vehicleId?.trim();
    if (id == null || id.isEmpty || id.startsWith('legacy-')) return null;
    return id;
  }

  Future<void> _seedLegacyProfileVehicle(Map<String, Object?> profile) async {
    final userId = _client.auth.currentUser!.id;
    final registration = _stringFrom(profile, 'vehicle_registration');
    final type = _stringFrom(profile, 'vehicle_type');
    if (registration == null ||
        type == null ||
        !const {'bike', 'car'}.contains(type)) {
      return;
    }

    await _client.from('profile_vehicles').upsert({
      'user_id': userId,
      'vehicle_type': type,
      'vehicle_registration': registration,
      'vehicle_make': _stringFrom(profile, 'vehicle_make'),
      'vehicle_model': _stringFrom(profile, 'vehicle_model'),
      'is_primary': true,
    }, onConflict: 'user_id,vehicle_registration');
  }

  @override
  Future<List<ParkingAddressCandidate>> searchAddress(String query) async {
    _readyClient();
    final normalized = query.trim();
    if (normalized.length < 4) {
      throw const ValidationFailure(
        'Enter a more specific address.',
        code: 'address_query_too_short',
      );
    }

    final data = await _invokeFunctionData('search-address', {
      'query': normalized,
    });
    final results = data['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map(
          (entry) => ParkingAddressCandidate.fromJson(
            Map<String, Object?>.from(entry),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<UserSetupState> saveHostBasics(HostBasicsDraftUpdate update) async {
    _readyClient();
    _validateBasics(update);
    final draft = await _draftForWrite();

    if (draft.isLegacyParkingSpaceDraft) {
      final next = await _saveLegacyHostBasics(draft, update);
      await _updateProfileSetup(
        intent: 'host',
        step: 'host_pricing',
        draftId: next.id,
        legacyDraft: true,
      );
      telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_basics'});
      return _stateForDraft(
        next,
        step: 'host_pricing',
        message: 'Basics saved',
      );
    }

    final next = await _patchDraft(
      draft: draft,
      fieldMask: const [
        'basics.title',
        'basics.address',
        'basics.locality',
        'basics.city',
        'basics.state',
        'basics.postalCode',
        'basics.location',
        'basics.vehicleFit',
        'basics.parkingType',
        'basics.accessInstructions',
      ],
      nextStep: 'host_pricing',
      patch: {
        'basics': {
          'accessInstructions': _nullIfBlank(update.accessInstructions),
          'address': update.address.trim(),
          'addressConfidence': update.addressConfidence,
          'addressPlaceId': _nullIfBlank(update.addressPlaceId),
          'addressProvider': update.addressProvider.trim(),
          'addressRaw': update.addressRaw,
          'city': update.city.trim(),
          'locality': update.locality.trim(),
          'location': update.location.toJson(),
          'parkingType': update.parkingType.trim(),
          'postalCode': update.postalCode.trim(),
          'state': update.stateName.trim(),
          'title': update.title.trim(),
          'vehicleFit': update.vehicleFit.trim(),
        },
      },
    );
    await _updateProfileSetup(
      intent: 'host',
      step: 'host_pricing',
      draftId: next.id,
    );
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_basics'});
    return _stateForDraft(next, step: 'host_pricing', message: 'Basics saved');
  }

  @override
  Future<UserSetupState> saveHostPricing(HostPricingDraftUpdate update) async {
    _readyClient();
    _validatePricing(update);
    final draft = await _draftForWrite();

    if (draft.isLegacyParkingSpaceDraft) {
      final next = await _saveLegacyHostPricing(draft, update);
      await _updateProfileSetup(
        intent: 'host',
        step: 'host_photos',
        draftId: next.id,
        legacyDraft: true,
      );
      telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_pricing'});
      return _stateForDraft(
        next,
        step: 'host_photos',
        message: 'Pricing saved',
      );
    }

    final next = await _patchDraft(
      draft: draft,
      fieldMask: const [
        'pricing.hourlyPrice',
        'pricing.slotsCount',
        'pricing.availableFromDate',
        'pricing.availableToDate',
        'pricing.dailyStartMinute',
        'pricing.dailyEndMinute',
        'pricing.skipWeekends',
      ],
      nextStep: 'host_photos',
      patch: {
        'pricing': {
          'availableFromDate': _dateOnly(update.availableFromDate),
          'availableToDate': _dateOnly(update.availableToDate),
          'availabilitySummary': _availabilitySummary(update),
          'dailyEndMinute': update.dailyEndMinute,
          'dailyStartMinute': update.dailyStartMinute,
          'hourlyPrice': update.hourlyPrice,
          'skipWeekends': update.skipWeekends,
          'slotsCount': update.slotsCount,
        },
      },
    );
    await _updateProfileSetup(
      intent: 'host',
      step: 'host_photos',
      draftId: next.id,
    );
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_pricing'});
    return _stateForDraft(next, step: 'host_photos', message: 'Pricing saved');
  }

  @override
  Future<UserSetupState> uploadHostPhoto(HostPhotoUploadCandidate image) async {
    _readyClient();
    _validatePhoto(image);
    final draft = await _draftForWrite();

    if (draft.isLegacyParkingSpaceDraft) {
      return _uploadLegacyHostPhoto(draft, image);
    }

    telemetry.event(TelemetryEvent.cloudinaryUploadStarted, {
      'draftId': draft.id,
      'fileSize': image.bytes.length,
      'mimeType': image.mimeType,
    });

    var uploadPhase = 'sign';
    try {
      final signature = await _invokeFunctionData(
        'create-host-parking-photo-upload-signature',
        {
          'fileName': image.fileName,
          'fileSize': image.bytes.length,
          'height': image.height,
          'mimeType': image.mimeType,
          'draftId': draft.id,
          'width': image.width,
        },
      );
      final cloudName = _requiredString(signature, 'cloudName');
      uploadPhase = 'cloudinary_upload';
      final uploadResponse = await _dio.post<Map<String, Object?>>(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: FormData.fromMap({
          'api_key': _requiredString(signature, 'apiKey'),
          'file': MultipartFile.fromBytes(
            image.bytes,
            contentType: _mediaTypeFromMime(image.mimeType),
            filename: image.fileName,
          ),
          'public_id': _requiredString(signature, 'publicId'),
          'signature': _requiredString(signature, 'signature'),
          'timestamp': signature['timestamp'],
        }),
      );

      final upload = uploadResponse.data;
      if (upload == null) {
        throw const NetworkFailure(
          'Cloudinary did not return upload details.',
          code: 'cloudinary_empty_response',
        );
      }

      uploadPhase = 'complete';
      final signedPublicId = _requiredString(signature, 'publicId');
      final complete =
          await _invokeFunctionData('complete-host-parking-photo-upload', {
            'bytes': upload['bytes'],
            'clientUploadId': signature['clientUploadId'],
            'clientBytes': image.bytes.length,
            'clientHeight': image.height,
            'clientMimeType': image.mimeType,
            'clientWidth': image.width,
            'cloudinaryPublicId': upload['public_id'],
            'draftId': draft.id,
            'format': upload['format'],
            'height': upload['height'],
            'publicId': signedPublicId,
            'secureUrl': upload['secure_url'],
            'width': upload['width'],
          });
      final next = _draftFromFunctionPayload(complete, draft.id);
      telemetry.event(TelemetryEvent.cloudinaryUploadCompleted, {
        'draftId': draft.id,
        'photoCount': next.photos.length,
      });
      return _stateForDraft(next, step: 'host_photos', message: 'Photo added');
    } on AppFailure catch (error) {
      if (_shouldFallbackToLegacyPhotoUpload(error)) {
        telemetry.error(TelemetryEvent.cloudinaryUploadFailed, {
          'draftId': draft.id,
          'failureCode': error.code,
          'fallback': 'legacy_parking_space',
          'phase': uploadPhase,
          'retryable': false,
        });
        final legacyDraft = await _fallbackHostDraftToLegacy(
          draft,
          step: 'host_photos',
        );
        return _uploadLegacyHostPhoto(legacyDraft, image);
      }
      telemetry.error(TelemetryEvent.cloudinaryUploadFailed, {
        'draftId': draft.id,
        'failureCode': error.code,
        'failureMessage': error.message,
        'phase': uploadPhase,
        'retryable': error.retryable,
      });
      rethrow;
    } on DioException catch (error) {
      final failureCategory = _cloudinaryFailureCategory(error);
      telemetry.error(TelemetryEvent.cloudinaryUploadFailed, {
        'cloudinaryFailure': failureCategory,
        'draftId': draft.id,
        'phase': uploadPhase,
        'statusCode': error.response?.statusCode,
      });
      throw NetworkFailure(
        _cloudinaryFailureMessage(failureCategory),
        code: failureCategory,
      );
    }
  }

  Future<UserSetupState> _uploadLegacyHostPhoto(
    HostListingDraft draft,
    HostPhotoUploadCandidate image,
  ) async {
    telemetry.event(TelemetryEvent.cloudinaryUploadStarted, {
      'draftId': draft.id,
      'fileSize': image.bytes.length,
      'mimeType': image.mimeType,
      'storageKind': 'legacy_parking_space',
    });

    var uploadPhase = 'sign';
    try {
      final signature =
          await _invokeFunctionData('create-cloudinary-upload-signature', {
            'fileName': image.fileName,
            'fileSize': image.bytes.length,
            'height': image.height,
            'mimeType': image.mimeType,
            'parkingSpaceId': draft.id,
            'width': image.width,
          });
      final cloudName = _requiredString(signature, 'cloudName');
      uploadPhase = 'cloudinary_upload';
      final uploadResponse = await _dio.post<Map<String, Object?>>(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: FormData.fromMap({
          'api_key': _requiredString(signature, 'apiKey'),
          'file': MultipartFile.fromBytes(
            image.bytes,
            contentType: _mediaTypeFromMime(image.mimeType),
            filename: image.fileName,
          ),
          'folder': _requiredString(signature, 'folder'),
          'public_id': _requiredString(signature, 'publicId'),
          'signature': _requiredString(signature, 'signature'),
          'timestamp': signature['timestamp'],
        }),
      );

      final upload = uploadResponse.data;
      if (upload == null) {
        throw const NetworkFailure(
          'Cloudinary did not return upload details.',
          code: 'cloudinary_empty_response',
        );
      }

      uploadPhase = 'complete';
      await _invokeFunctionData('complete-parking-photo-upload', {
        'bytes': upload['bytes'],
        'clientBytes': image.bytes.length,
        'clientHeight': image.height,
        'clientMimeType': image.mimeType,
        'clientWidth': image.width,
        'cloudinaryPublicId': upload['public_id'],
        'format': upload['format'],
        'height': upload['height'],
        'parkingSpaceId': draft.id,
        'publicId': upload['public_id'],
        'secureUrl': upload['secure_url'],
        'width': upload['width'],
      });
      final next =
          await _loadLegacyListing(draft.id, fallbackStep: 'host_photos') ??
          draft;
      telemetry.event(TelemetryEvent.cloudinaryUploadCompleted, {
        'draftId': draft.id,
        'photoCount': next.photos.length,
        'storageKind': 'legacy_parking_space',
      });
      return _stateForDraft(next, step: 'host_photos', message: 'Photo added');
    } on AppFailure catch (error) {
      telemetry.error(TelemetryEvent.cloudinaryUploadFailed, {
        'draftId': draft.id,
        'failureCode': error.code,
        'failureMessage': error.message,
        'phase': uploadPhase,
        'retryable': error.retryable,
        'storageKind': 'legacy_parking_space',
      });
      rethrow;
    } on DioException catch (error) {
      final failureCategory = _cloudinaryFailureCategory(error);
      telemetry.error(TelemetryEvent.cloudinaryUploadFailed, {
        'cloudinaryFailure': failureCategory,
        'draftId': draft.id,
        'phase': uploadPhase,
        'statusCode': error.response?.statusCode,
        'storageKind': 'legacy_parking_space',
      });
      throw NetworkFailure(
        _cloudinaryFailureMessage(failureCategory),
        code: failureCategory,
      );
    }
  }

  @override
  Future<UserSetupState> deleteHostPhoto(String photoId) async {
    final client = _readyClient();
    final draft = await _draftForWrite();

    if (draft.isLegacyParkingSpaceDraft) {
      await client
          .from('parking_space_photos')
          .delete()
          .eq('id', photoId)
          .eq('parking_space_id', draft.id);
      final next =
          await _loadLegacyListing(draft.id, fallbackStep: 'host_photos') ??
          draft;
      return _stateForDraft(
        next,
        step: 'host_photos',
        message: 'Photo removed',
      );
    }

    try {
      final response = await client.rpc(
        'delete_host_parking_draft_photo',
        params: {'p_draft_id': draft.id, 'p_photo_id': photoId},
      );
      final next = HostListingDraft.fromJson(
        Map<String, Object?>.from(response as Map),
      );
      return _stateForDraft(
        next,
        step: 'host_photos',
        message: 'Photo removed',
      );
    } on sb.PostgrestException catch (error) {
      throw _draftFailure(
        error,
        fallbackMessage: 'Could not remove the photo.',
      );
    }
  }

  @override
  Future<UserSetupState> reorderHostPhotos(List<String> photoIds) async {
    final client = _readyClient();
    final draft = await _draftForWrite();
    final knownIds = draft.photos.map((photo) => photo.id).toSet();
    if (photoIds.length != knownIds.length || !knownIds.containsAll(photoIds)) {
      throw const ValidationFailure(
        'Photo order is invalid.',
        code: 'host_photo_order_invalid',
      );
    }

    if (draft.isLegacyParkingSpaceDraft) {
      for (var index = 0; index < photoIds.length; index++) {
        await client
            .from('parking_space_photos')
            .update({'sort_order': index})
            .eq('id', photoIds[index])
            .eq('parking_space_id', draft.id);
      }
      final next =
          await _loadLegacyListing(draft.id, fallbackStep: 'host_photos') ??
          draft;
      return _stateForDraft(
        next,
        step: 'host_photos',
        message: 'Photos reordered',
      );
    }

    try {
      final response = await client.rpc(
        'reorder_host_parking_draft_photos',
        params: {'p_draft_id': draft.id, 'p_photo_ids': photoIds},
      );
      final next = HostListingDraft.fromJson(
        Map<String, Object?>.from(response as Map),
      );
      return _stateForDraft(
        next,
        step: 'host_photos',
        message: 'Photos reordered',
      );
    } on sb.PostgrestException catch (error) {
      throw _draftFailure(error, fallbackMessage: 'Could not reorder photos.');
    }
  }

  @override
  Future<UserSetupState> markPhotosStepComplete() async {
    final draft = await _draftForWrite();
    if (draft.photos.length < 2) {
      throw const ValidationFailure(
        'Add at least two photos of your parking space.',
        code: 'host_photos_minimum',
      );
    }

    if (draft.isLegacyParkingSpaceDraft) {
      await _updateProfileSetup(
        intent: 'host',
        step: 'host_review',
        draftId: draft.id,
        legacyDraft: true,
      );
      telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_photos'});
      return _stateForDraft(
        _legacyDraftWithStep(draft, 'host_review'),
        step: 'host_review',
        message: 'Photos saved',
      );
    }

    final next = await _patchDraft(
      draft: draft,
      fieldMask: const ['currentStep'],
      nextStep: 'host_review',
      patch: const {},
    );
    await _updateProfileSetup(
      intent: 'host',
      step: 'host_review',
      draftId: next.id,
    );
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_photos'});
    return _stateForDraft(next, step: 'host_review', message: 'Photos saved');
  }

  @override
  Future<UserSetupState> submitForReview() async {
    final client = _readyClient();
    final draft = await _draftForWrite();
    _validateReadyForSubmission(draft);

    if (draft.isLegacyParkingSpaceDraft) {
      try {
        final response = await client.rpc(
          'submit_parking_space_for_review',
          params: {'p_expected_version': draft.version, 'p_space_id': draft.id},
        );
        final submittedId = response is Map
            ? response['id']?.toString()
            : draft.id;
        final next =
            await _loadLegacyListing(
              submittedId ?? draft.id,
              fallbackStep: 'complete',
            ) ??
            draft;
        telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_review'});
        return _stateForDraft(
          _legacyDraftWithStep(next, 'complete'),
          step: 'complete',
          message: 'Listing submitted for review',
        );
      } on sb.PostgrestException catch (error) {
        throw _draftFailure(
          error,
          fallbackMessage: 'Could not submit the listing.',
        );
      }
    }

    try {
      final mutationId = _uuid.v4();
      final requestHash = _stableHash(
        jsonEncode({
          'draftId': draft.id,
          'expectedVersion': draft.version,
          'mutationId': mutationId,
          'operation': 'publish',
        }),
      );
      final response = await client.rpc(
        'publish_host_parking_draft',
        params: {
          'p_client_mutation_id': mutationId,
          'p_draft_id': draft.id,
          'p_expected_version': draft.version,
          'p_idempotency_key_hash': requestHash,
          'p_request_hash': requestHash,
        },
      );
      final payload = Map<String, Object?>.from(response as Map);
      final next = HostListingDraft.fromJson(
        Map<String, Object?>.from(payload['draft'] as Map),
      );
      telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_review'});
      return _stateForDraft(
        next,
        step: 'complete',
        message: 'Listing submitted for review',
      );
    } on sb.PostgrestException catch (error) {
      throw _draftFailure(
        error,
        fallbackMessage: 'Could not submit the listing.',
      );
    }
  }

  Future<Map<String, Object?>> _ensureProfile() async {
    final client = _readyClient();
    final data = await client.rpc('ensure_user_profile');
    if (data is Map) return Map<String, Object?>.from(data);
    throw const AuthFailure(
      'Could not load your profile.',
      code: 'profile_load_failed',
    );
  }

  Future<HostListingDraft> _ensureDraft(
    String? requestedDraftId, {
    bool createNew = false,
    String? fallbackStep,
  }) async {
    final requested = requestedDraftId?.trim();
    if (!createNew && requested != null && requested.isNotEmpty) {
      final draft = await _loadListing(requested, fallbackStep: fallbackStep);
      if (draft != null && draft.status == 'draft') return draft;
    }

    if (!createNew) {
      final existing = await _latestDraft(fallbackStep: fallbackStep);
      if (existing != null) return existing;
    }

    final client = _readyClient();
    try {
      final row = await client.rpc(
        'ensure_host_parking_draft',
        params: {'p_create_new': createNew, 'p_requested_draft_id': requested},
      );
      return HostListingDraft.fromJson(Map<String, Object?>.from(row as Map));
    } on sb.PostgrestException catch (error) {
      if (_isDraftLookupUnavailable(error)) {
        return _createLegacyDraft(fallbackStep: fallbackStep);
      }
      rethrow;
    }
  }

  Future<HostListingDraft?> _latestDraft({String? fallbackStep}) async {
    final client = _readyClient();
    try {
      final row = await client.rpc(
        'ensure_host_parking_draft',
        params: {'p_create_new': false, 'p_requested_draft_id': null},
      );
      return HostListingDraft.fromJson(Map<String, Object?>.from(row as Map));
    } on sb.PostgrestException catch (error) {
      if (_isDraftLookupUnavailable(error)) {
        return _latestLegacyDraft(fallbackStep: fallbackStep);
      }
      rethrow;
    }
  }

  Future<String?> _latestOwnedHostDraftId() async {
    final client = _readyClient();
    try {
      final response = await client.rpc('get_owned_host_parking_drafts');
      if (response is! List) return null;

      for (final entry in response.whereType<Map>()) {
        final row = Map<String, Object?>.from(entry);
        final id = _stringFrom(row, 'id');
        final status = _stringFrom(row, 'status') ?? 'draft';
        if (id != null && status == 'draft') return id;
      }
      return null;
    } on sb.PostgrestException catch (error) {
      if (_isDraftLookupUnavailable(error)) return null;
      rethrow;
    }
  }

  Future<HostListingDraft?> _loadListing(
    String listingId, {
    String? fallbackStep,
  }) async {
    final client = _readyClient();
    try {
      final row = await client.rpc(
        'get_host_parking_draft',
        params: {'p_draft_id': listingId},
      );
      return HostListingDraft.fromJson(Map<String, Object?>.from(row as Map));
    } on sb.PostgrestException catch (error) {
      if (error.code == 'P0002' || _isDraftLookupUnavailable(error)) {
        return _loadLegacyListing(listingId, fallbackStep: fallbackStep);
      }
      rethrow;
    }
  }

  Future<HostListingDraft?> _loadLegacyListing(
    String listingId, {
    String? fallbackStep,
  }) async {
    final client = _readyClient();
    try {
      final row = await client
          .from('parking_spaces')
          .select(_legacyDraftSelect)
          .eq('id', listingId)
          .eq('host_id', client.auth.currentUser!.id)
          .maybeSingle();
      if (row == null) return null;
      return _legacyDraftFromRow(row, fallbackStep: fallbackStep);
    } on sb.PostgrestException catch (error) {
      if (_isLegacyDraftLookupUnavailable(error)) return null;
      rethrow;
    }
  }

  Future<HostListingDraft?> _latestLegacyDraft({String? fallbackStep}) async {
    final client = _readyClient();
    try {
      final row = await client
          .from('parking_spaces')
          .select(_legacyDraftSelect)
          .eq('host_id', client.auth.currentUser!.id)
          .eq('status', 'draft')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return _legacyDraftFromRow(row, fallbackStep: fallbackStep);
    } on sb.PostgrestException catch (error) {
      if (_isLegacyDraftLookupUnavailable(error)) return null;
      rethrow;
    }
  }

  Future<HostListingDraft> _createLegacyDraft({String? fallbackStep}) async {
    final client = _readyClient();
    final row = await client
        .from('parking_spaces')
        .insert({'host_id': client.auth.currentUser!.id, 'status': 'draft'})
        .select(_legacyDraftSelect)
        .single();
    return _legacyDraftFromRow(row, fallbackStep: fallbackStep);
  }

  HostListingDraft _legacyDraftFromRow(
    Map<String, dynamic> row, {
    String? fallbackStep,
  }) {
    final payload = Map<String, Object?>.from(row);
    payload['storageKind'] = 'legacy_parking_space';
    payload['currentStep'] = _validHostStep(fallbackStep);
    return HostListingDraft.fromJson(payload);
  }

  HostListingDraft _legacyDraftWithStep(HostListingDraft draft, String step) {
    return HostListingDraft(
      id: draft.id,
      status: draft.status,
      version: draft.version,
      accessInstructions: draft.accessInstructions,
      address: draft.address,
      addressConfidence: draft.addressConfidence,
      addressPlaceId: draft.addressPlaceId,
      addressProvider: draft.addressProvider,
      addressRaw: draft.addressRaw,
      availableFromDate: draft.availableFromDate,
      availableToDate: draft.availableToDate,
      city: draft.city,
      currentStep: step,
      dailyEndMinute: draft.dailyEndMinute,
      dailyStartMinute: draft.dailyStartMinute,
      hourlyPrice: draft.hourlyPrice,
      locality: draft.locality,
      location: draft.location,
      parkingType: draft.parkingType,
      photos: draft.photos,
      postalCode: draft.postalCode,
      skipWeekends: draft.skipWeekends,
      slotsCount: draft.slotsCount,
      stateName: draft.stateName,
      storageKind: 'legacy_parking_space',
      title: draft.title,
      vehicleFit: draft.vehicleFit,
    );
  }

  bool _isResumableHostDraft(HostListingDraft? draft) {
    return draft != null && draft.status == 'draft';
  }

  HostListingDraft? _bestResumeDraft(List<HostListingDraft> candidates) {
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) {
      final scoreCompare = _resumeScore(right).compareTo(_resumeScore(left));
      if (scoreCompare != 0) return scoreCompare;
      return right.version.compareTo(left.version);
    });
    return candidates.first;
  }

  int _resumeScore(HostListingDraft draft) {
    var score = 0;
    if (draft.hasBasics) score += 1000;
    if (draft.hasPricing) score += 800;
    if (draft.hasRequiredPhotos) score += 600;
    score += draft.photos.length * 50;
    score += _stepRank(draft.currentStep) * 25;
    if (_hasText(draft.title)) score += 20;
    if (_hasText(draft.address)) score += 20;
    if (_hasText(draft.city)) score += 10;
    if (_hasText(draft.postalCode)) score += 10;
    if (draft.location != null) score += 20;
    if (draft.isLegacyParkingSpaceDraft) score += 5;
    return score;
  }

  int _stepRank(String? step) {
    return switch (step) {
      'host_basics' => 1,
      'host_pricing' => 2,
      'host_photos' => 3,
      'host_review' => 4,
      _ => 0,
    };
  }

  bool _isDraftLookupUnavailable(sb.PostgrestException error) {
    final text = [error.message, error.details, error.hint]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();
    return error.code == 'PGRST202' ||
        error.code == 'PGRST203' ||
        text.contains('could not find the function') ||
        text.contains('schema cache') ||
        text.contains('ensure_host_parking_draft') ||
        text.contains('get_host_parking_draft') ||
        text.contains('get_owned_host_parking_drafts');
  }

  bool _isLegacyDraftLookupUnavailable(sb.PostgrestException error) {
    final text = [error.message, error.details, error.hint]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();
    return error.code == '42P01' ||
        text.contains('parking_spaces') && text.contains('does not exist');
  }

  bool _isProfileHostDraftColumnUnavailable(sb.PostgrestException error) {
    final text = [error.message, error.details, error.hint]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();
    return error.code == 'PGRST204' ||
        text.contains('host_parking_draft_id') &&
            (text.contains('schema cache') ||
                text.contains('could not find') ||
                text.contains('does not exist'));
  }

  bool _isVehicleProfileSchemaUnavailable(sb.PostgrestException error) {
    final text = [error.message, error.details, error.hint]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();
    return error.code == 'PGRST204' ||
        (text.contains('vehicle_') &&
            (text.contains('schema cache') ||
                text.contains('could not find') ||
                text.contains('does not exist')));
  }

  bool _isProfileVehiclesSchemaUnavailable(sb.PostgrestException error) {
    final text = [error.code, error.message, error.details, error.hint]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();
    return text.contains('profile_vehicles') &&
        (text.contains('42p01') ||
            text.contains('pgrst205') ||
            text.contains('schema cache') ||
            text.contains('could not find') ||
            text.contains('does not exist'));
  }

  bool _isUniqueViolation(sb.PostgrestException error) {
    final text = [error.code, error.message, error.details, error.hint]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();
    return text.contains('23505') || text.contains('duplicate key');
  }

  AppFailure _profileWriteFailure(
    sb.PostgrestException error, {
    required String fallbackMessage,
  }) {
    final code = error.code ?? 'profile_write_failed';
    final text = [error.message, error.details, error.hint]
        .whereType<Object>()
        .map((value) => value.toString())
        .join(' ')
        .toLowerCase();

    if (code == '23514' && text.contains('profiles_setup_step_check')) {
      return const ConfigurationFailure(
        'Profile setup database is missing the vehicle-details step. Apply the latest Supabase migrations and try again.',
        code: 'profile_setup_step_migration_missing',
      );
    }
    if (code == '42703' ||
        text.contains('schema cache') ||
        text.contains('could not find') ||
        text.contains('does not exist')) {
      return const ConfigurationFailure(
        'Profile setup database is missing the latest profile columns. Apply the latest Supabase migrations and try again.',
        code: 'profile_schema_migration_missing',
      );
    }
    if (code == '42501' || text.contains('permission denied')) {
      return const ConfigurationFailure(
        'Profile setup permissions are not deployed. Apply the latest Supabase profile grants and try again.',
        code: 'profile_update_grant_missing',
      );
    }
    if (code == '23514') {
      return ValidationFailure(
        error.message.isEmpty ? 'Check your profile details.' : error.message,
        code: 'profile_constraint_failed',
      );
    }
    return NetworkFailure(fallbackMessage, code: code);
  }

  bool _shouldFallbackToLegacyPhotoUpload(AppFailure error) {
    return error.code == 'host_photo_upload_service_missing' ||
        error.code == 'create-host-parking-photo-upload-signature_404' ||
        error.code == 'complete-host-parking-photo-upload_404';
  }

  Future<HostListingDraft> _draftForWrite() async {
    final profile = await _ensureProfile();
    final profileStep = _validHostStep(_stringFrom(profile, 'setup_step'));
    final hostDraftId = _stringFrom(profile, 'host_parking_draft_id');
    final legacyDraftId = _stringFrom(profile, 'setup_draft_id');
    final candidates = <HostListingDraft>[];
    final seenCandidateKeys = <String>{};

    void addCandidate(HostListingDraft? candidate) {
      if (candidate == null || candidate.status != 'draft') return;
      final key = '${candidate.storageKind}:${candidate.id}';
      if (seenCandidateKeys.add(key)) candidates.add(candidate);
    }

    if (hostDraftId != null) {
      addCandidate(await _loadListing(hostDraftId, fallbackStep: profileStep));
    }
    if (legacyDraftId != null && legacyDraftId != hostDraftId) {
      addCandidate(
        await _loadLegacyListing(legacyDraftId, fallbackStep: profileStep),
      );
    }

    final draft =
        _bestResumeDraft(candidates) ??
        await _ensureDraft(
          hostDraftId ?? legacyDraftId,
          fallbackStep: profileStep,
        );
    if (draft.status != 'draft') {
      throw const ValidationFailure(
        'This listing has already been submitted.',
        code: 'host_draft_closed',
      );
    }
    return draft;
  }

  Future<HostListingDraft> _saveLegacyHostBasics(
    HostListingDraft draft,
    HostBasicsDraftUpdate update,
  ) async {
    final client = _readyClient();
    final row = await client
        .from('parking_spaces')
        .update({
          'access_instructions': _nullIfBlank(update.accessInstructions),
          'address': update.address.trim(),
          'address_confidence': update.addressConfidence,
          'address_place_id': _nullIfBlank(update.addressPlaceId),
          'address_provider': update.addressProvider.trim(),
          'address_raw_osm_json': update.addressRaw,
          'city': update.city.trim(),
          'latitude': update.location.latitude,
          'locality': update.locality.trim(),
          'location_confirmed_at': DateTime.now().toUtc().toIso8601String(),
          'longitude': update.location.longitude,
          'parking_type': update.parkingType.trim(),
          'postal_code': update.postalCode.trim(),
          'title': update.title.trim(),
          'vehicle_fit': update.vehicleFit.trim(),
          'version': draft.version + 1,
        })
        .eq('id', draft.id)
        .eq('status', 'draft')
        .eq('version', draft.version)
        .select(_legacyDraftSelect)
        .maybeSingle();

    if (row == null) {
      throw const ValidationFailure(
        'This draft changed elsewhere. Refresh and try again.',
        code: 'host_draft_version_conflict',
      );
    }
    return _legacyDraftFromRow(row, fallbackStep: 'host_pricing');
  }

  Future<HostListingDraft> _saveLegacyHostPricing(
    HostListingDraft draft,
    HostPricingDraftUpdate update,
  ) async {
    final client = _readyClient();
    final row = await client
        .from('parking_spaces')
        .update({
          'available_from_date': _dateOnly(update.availableFromDate),
          'available_to_date': _dateOnly(update.availableToDate),
          'availability_summary': _availabilitySummary(update),
          'daily_end_minute': update.dailyEndMinute,
          'daily_start_minute': update.dailyStartMinute,
          'hourly_price': update.hourlyPrice,
          'skip_weekends': update.skipWeekends,
          'slots_count': update.slotsCount,
          'version': draft.version + 1,
        })
        .eq('id', draft.id)
        .eq('status', 'draft')
        .eq('version', draft.version)
        .select(_legacyDraftSelect)
        .maybeSingle();

    if (row == null) {
      throw const ValidationFailure(
        'This draft changed elsewhere. Refresh and try again.',
        code: 'host_draft_version_conflict',
      );
    }
    return _legacyDraftFromRow(row, fallbackStep: 'host_photos');
  }

  Future<HostListingDraft> _fallbackHostDraftToLegacy(
    HostListingDraft source, {
    required String step,
  }) async {
    if (source.isLegacyParkingSpaceDraft) {
      return _legacyDraftWithStep(source, step);
    }

    final client = _readyClient();
    final profile = await _ensureProfile();
    final existingLegacyId = _stringFrom(profile, 'setup_draft_id');
    final existingLegacy = existingLegacyId == null
        ? null
        : await _loadLegacyListing(existingLegacyId, fallbackStep: step);
    final patch = _legacyParkingSpacePayloadFromDraft(source);
    late HostListingDraft legacyDraft;

    if (existingLegacy == null) {
      final row = await client
          .from('parking_spaces')
          .insert({
            'host_id': client.auth.currentUser!.id,
            'status': 'draft',
            ...patch,
          })
          .select(_legacyDraftSelect)
          .single();
      legacyDraft = _legacyDraftFromRow(row, fallbackStep: step);
    } else if (patch.isEmpty) {
      legacyDraft = _legacyDraftWithStep(existingLegacy, step);
    } else {
      final row = await client
          .from('parking_spaces')
          .update({...patch, 'version': existingLegacy.version + 1})
          .eq('id', existingLegacy.id)
          .eq('status', 'draft')
          .select(_legacyDraftSelect)
          .maybeSingle();
      legacyDraft = row == null
          ? _legacyDraftWithStep(existingLegacy, step)
          : _legacyDraftFromRow(row, fallbackStep: step);
    }

    await _migrateHostDraftPhotosToLegacy(source, legacyDraft);
    final reloaded =
        await _loadLegacyListing(legacyDraft.id, fallbackStep: step) ??
        legacyDraft;
    await _updateProfileSetup(
      intent: 'host',
      step: step,
      draftId: reloaded.id,
      legacyDraft: true,
    );
    return _legacyDraftWithStep(reloaded, step);
  }

  Future<void> _migrateHostDraftPhotosToLegacy(
    HostListingDraft source,
    HostListingDraft legacyDraft,
  ) async {
    if (source.photos.isEmpty) return;

    final existingPublicIds = legacyDraft.photos
        .map((photo) => photo.publicId)
        .where((publicId) => publicId.trim().isNotEmpty)
        .toSet();
    final rows = <Map<String, Object?>>[];

    for (final photo in source.photos) {
      if (photo.publicId.trim().isEmpty ||
          photo.secureUrl.trim().isEmpty ||
          existingPublicIds.contains(photo.publicId)) {
        continue;
      }
      rows.add({
        'height': photo.height,
        'host_id': _readyClient().auth.currentUser!.id,
        'parking_space_id': legacyDraft.id,
        'public_id': photo.publicId,
        'secure_url': photo.secureUrl,
        'sort_order': photo.sortOrder,
        'upload_status': 'linked',
        'width': photo.width,
      });
    }

    if (rows.isEmpty) return;
    await _readyClient()
        .from('parking_space_photos')
        .upsert(rows, onConflict: 'parking_space_id,public_id');
  }

  Map<String, Object?> _legacyParkingSpacePayloadFromDraft(
    HostListingDraft source,
  ) {
    final patch = <String, Object?>{};

    void putText(String column, String? value) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        patch[column] = normalized;
      }
    }

    putText('access_instructions', source.accessInstructions);
    putText('address', source.address);
    putText('address_place_id', source.addressPlaceId);
    putText('address_provider', source.addressProvider);
    putText('city', source.city);
    putText('locality', source.locality);
    putText('parking_type', source.parkingType);
    putText('postal_code', source.postalCode);
    putText('title', source.title);
    putText('vehicle_fit', source.vehicleFit);

    if (source.addressConfidence != null) {
      patch['address_confidence'] = source.addressConfidence;
    }
    if (source.addressRaw != null) {
      patch['address_raw_osm_json'] = source.addressRaw;
    }
    if (source.location != null) {
      patch['latitude'] = source.location!.latitude;
      patch['longitude'] = source.location!.longitude;
      patch['location_confirmed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (source.availableFromDate != null) {
      patch['available_from_date'] = _dateOnly(source.availableFromDate!);
    }
    if (source.availableToDate != null) {
      patch['available_to_date'] = _dateOnly(source.availableToDate!);
    }
    if (source.dailyEndMinute != null) {
      patch['daily_end_minute'] = source.dailyEndMinute;
    }
    if (source.dailyStartMinute != null) {
      patch['daily_start_minute'] = source.dailyStartMinute;
    }
    if (source.hourlyPrice != null) {
      patch['hourly_price'] = source.hourlyPrice;
    }
    final availabilitySummary = _availabilitySummaryFromDraft(source);
    if (availabilitySummary != null) {
      patch['availability_summary'] = availabilitySummary;
    }
    patch['skip_weekends'] = source.skipWeekends;
    patch['slots_count'] = source.slotsCount;

    return patch;
  }

  String? _availabilitySummaryFromDraft(HostListingDraft source) {
    final from = source.availableFromDate;
    final to = source.availableToDate;
    final start = source.dailyStartMinute;
    final end = source.dailyEndMinute;
    if (from == null || to == null || start == null || end == null) {
      return null;
    }
    return [
      '${_dateOnly(from)} to ${_dateOnly(to)}',
      '${_minuteLabel(start)} - ${_minuteLabel(end)}',
      if (source.skipWeekends) 'weekdays only',
    ].join(', ');
  }

  Future<void> _updateProfileSetup({
    required String draftId,
    required String intent,
    bool legacyDraft = false,
    required String step,
  }) async {
    final client = _readyClient();
    final patch = <String, Object?>{
      'intent': intent,
      'setup_step': step,
      'setup_draft_id': legacyDraft ? draftId : null,
      'host_parking_draft_id': legacyDraft ? null : draftId,
    };
    try {
      await client
          .from('profiles')
          .update(patch)
          .eq('id', client.auth.currentUser!.id);
    } on sb.PostgrestException catch (error) {
      if (!_isProfileHostDraftColumnUnavailable(error)) rethrow;
      patch.remove('host_parking_draft_id');
      await client
          .from('profiles')
          .update(patch)
          .eq('id', client.auth.currentUser!.id);
    }
  }

  Future<HostListingDraft> _patchDraft({
    required HostListingDraft draft,
    required List<String> fieldMask,
    required String nextStep,
    required Map<String, Object?> patch,
  }) async {
    final client = _readyClient();
    final mutationId = _uuid.v4();
    final requestHash = _stableHash(
      jsonEncode({
        'baseVersion': draft.version,
        'draftId': draft.id,
        'fieldMask': fieldMask,
        'mutationId': mutationId,
        'patch': patch,
      }),
    );

    try {
      final response = await client.rpc(
        'patch_host_parking_draft',
        params: {
          'p_base_version': draft.version,
          'p_client_mutation_id': mutationId,
          'p_current_step': nextStep,
          'p_device_id': 'flutter-user-setup',
          'p_draft_id': draft.id,
          'p_field_mask': fieldMask,
          'p_idempotency_key_hash': requestHash,
          'p_patch': patch,
          'p_request_hash': requestHash,
        },
      );
      final payload = Map<String, Object?>.from(response as Map);
      if (payload['conflict'] == true || payload['ok'] == false) {
        throw const ValidationFailure(
          'This draft changed elsewhere. Review the latest version.',
          code: 'host_draft_version_conflict',
        );
      }
      final draftPayload = payload['draft'];
      if (draftPayload is! Map) {
        throw const NetworkFailure(
          'Draft service returned an invalid response.',
          code: 'host_draft_invalid_response',
        );
      }
      return HostListingDraft.fromJson(Map<String, Object?>.from(draftPayload));
    } on sb.PostgrestException catch (error) {
      throw _draftFailure(error, fallbackMessage: 'Could not save the draft.');
    }
  }

  UserSetupState _stateForDraft(
    HostListingDraft draft, {
    required String step,
    String? message,
  }) {
    return UserSetupState(
      draft: draft,
      draftId: draft.id,
      intent: 'host',
      message: message,
      step: step,
    );
  }

  String _resolveHostStep(String? requestedStep, HostListingDraft draft) {
    return _validHostStep(requestedStep) ?? _firstIncompleteStep(draft);
  }

  String _firstIncompleteStep(HostListingDraft draft) {
    if (!draft.hasBasics) return 'host_basics';
    if (!draft.hasPricing) return 'host_pricing';
    if (!draft.hasRequiredPhotos) return 'host_photos';
    return 'host_review';
  }

  String? _validHostStep(String? step) {
    if (step == null) return null;
    return _hostSteps.contains(step) ? step : null;
  }

  String? _validSetupStep(String? step) {
    if (step == null) return null;
    return const {
          'intent',
          'profile',
          'vehicle_details',
          'complete',
        }.contains(step)
        ? step
        : null;
  }

  HostListingDraft _draftFromFunctionPayload(
    Map<String, Object?> payload,
    String draftId,
  ) {
    final draft = payload['draft'];
    if (draft is Map) {
      return HostListingDraft.fromJson(Map<String, Object?>.from(draft));
    }
    final photos = payload['photos'];
    if (photos is List) {
      return HostListingDraft(
        id: draftId,
        status: 'draft',
        version: 1,
        photos: photos
            .whereType<Map>()
            .map(
              (entry) =>
                  HostListingPhoto.fromJson(Map<String, Object?>.from(entry)),
            )
            .toList(growable: false),
      );
    }
    throw const NetworkFailure(
      'Photo service returned an invalid response.',
      code: 'host_photo_invalid_response',
    );
  }

  Future<Map<String, Object?>> _invokeFunctionData(
    String name,
    Map<String, Object?> body,
  ) async {
    final client = _readyClient();
    try {
      final response = await client.functions.invoke(name, body: body);
      final data = response.data;
      if (response.status >= 400 || data is! Map || data['ok'] != true) {
        throw _functionFailure(name, data);
      }
      final payload = data['data'];
      if (payload is! Map) {
        throw AuthFailure(
          'Host setup service returned an invalid response.',
          code: '${name}_invalid_response',
        );
      }
      return Map<String, Object?>.from(payload);
    } on sb.FunctionException catch (error) {
      if (error.status == 404 &&
          name == 'create-host-parking-photo-upload-signature') {
        throw const ConfigurationFailure(
          'Photo upload service is not deployed yet.',
          code: 'host_photo_upload_service_missing',
        );
      }
      final failure = _functionFailure(name, error.details);
      if (failure.code != name) throw failure;
      throw NetworkFailure(
        'Host setup service is temporarily unavailable.',
        code: '${name}_${error.status}',
      );
    }
  }

  AppFailure _functionFailure(String name, Object? data) {
    final message = data is Map
        ? data['message']?.toString() ?? 'Host setup service failed.'
        : 'Host setup service failed.';
    final code = data is Map ? data['code']?.toString() ?? name : name;

    switch (code) {
      case 'validation':
      case 'invalid_cloudinary_url':
      case 'invalid_dimensions':
      case 'invalid_draft_id':
      case 'invalid_parking_space_id':
      case 'invalid_photo_format':
      case 'invalid_photo_metadata':
      case 'invalid_uploaded_photo':
      case 'invalid_upload_session':
        return ValidationFailure(message, code: code);
      case 'server':
        return NetworkFailure(message, code: '${name}_server');
      case 'unauthorized':
      case 'forbidden':
        return AuthFailure(message, code: code);
      default:
        return NetworkFailure(message, code: code);
    }
  }

  DioMediaType? _mediaTypeFromMime(String mimeType) {
    try {
      return DioMediaType.parse(mimeType);
    } catch (_) {
      return null;
    }
  }

  String _cloudinaryFailureCategory(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = _cloudinaryErrorMessage(error).toLowerCase();

    if (statusCode == 401 || message.contains('invalid signature')) {
      return 'cloudinary_signature_invalid';
    }
    if (statusCode == 400 &&
        (message.contains('invalid image') ||
            message.contains('unsupported') ||
            message.contains('not an image'))) {
      return 'cloudinary_invalid_image';
    }
    if (statusCode == 413 ||
        message.contains('file size') ||
        message.contains('too large')) {
      return 'cloudinary_file_too_large';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'cloudinary_network';
    }
    return statusCode == null
        ? 'cloudinary_upload_failed'
        : 'cloudinary_$statusCode';
  }

  String _cloudinaryFailureMessage(String category) {
    switch (category) {
      case 'cloudinary_invalid_image':
        return 'Upload a valid JPG, PNG, WebP, HEIC, or HEIF photo.';
      case 'cloudinary_file_too_large':
        return 'This photo could not be prepared for upload. Try a different photo.';
      case 'cloudinary_network':
        return 'Check your connection and try uploading again.';
      case 'cloudinary_signature_invalid':
        return 'Photo upload is not configured correctly. Please try again later.';
      default:
        return 'Photo upload failed. Please try again.';
    }
  }

  String _cloudinaryErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final nestedError = data['error'];
      if (nestedError is Map && nestedError['message'] != null) {
        return nestedError['message'].toString();
      }
      if (data['message'] != null) return data['message'].toString();
    }
    return error.message ?? '';
  }

  String _requiredString(Map<String, Object?> data, String key) {
    final value = data[key]?.toString();
    if (value == null || value.isEmpty) {
      throw AuthFailure(
        'Host setup service returned an invalid response.',
        code: 'missing_$key',
      );
    }
    return value;
  }

  void _validateBasics(HostBasicsDraftUpdate update) {
    if (update.title.trim().length < 3) {
      throw const ValidationFailure(
        'Enter a clear listing title.',
        code: 'host_title_required',
      );
    }
    if (update.address.trim().length < 8 ||
        update.locality.trim().length < 2 ||
        update.city.trim().length < 2) {
      throw const ValidationFailure(
        'Choose a complete parking address.',
        code: 'host_address_incomplete',
      );
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(update.postalCode.trim())) {
      throw const ValidationFailure(
        'Enter a valid 6 digit PIN code.',
        code: 'host_postal_code_invalid',
      );
    }
    final descriptionLength = update.accessInstructions?.trim().length ?? 0;
    if (descriptionLength < _descriptionMinLength ||
        descriptionLength > _descriptionMaxLength) {
      throw const ValidationFailure(
        'Description must be between 50 and 200 characters.',
        code: 'host_description_length_invalid',
      );
    }
    if (update.location.latitude < 6 ||
        update.location.latitude > 38 ||
        update.location.longitude < 68 ||
        update.location.longitude > 98) {
      throw const ValidationFailure(
        'Choose a location inside India.',
        code: 'host_location_out_of_bounds',
      );
    }
    if (!const {'nominatim', 'manual'}.contains(update.addressProvider)) {
      throw const ValidationFailure(
        'Choose a supported address provider.',
        code: 'host_address_provider_invalid',
      );
    }
    if (update.addressConfidence < 0 || update.addressConfidence > 1) {
      throw const ValidationFailure(
        'Choose a verified map result.',
        code: 'host_address_confidence_invalid',
      );
    }
    if (!const {'bike', 'car', 'both'}.contains(update.vehicleFit)) {
      throw const ValidationFailure(
        'Choose the vehicle fit.',
        code: 'host_vehicle_fit_invalid',
      );
    }
    if (!const {
      'basement',
      'covered',
      'driveway',
      'garage',
      'open',
    }.contains(update.parkingType)) {
      throw const ValidationFailure(
        'Choose the parking type.',
        code: 'host_parking_type_invalid',
      );
    }
  }

  void _validatePricing(HostPricingDraftUpdate update) {
    if (update.hourlyPrice < 10 || update.hourlyPrice > 10000) {
      throw const ValidationFailure(
        'Hourly price must be between INR 10 and INR 10,000.',
        code: 'host_price_invalid',
      );
    }
    if (update.slotsCount < 1 || update.slotsCount > 50) {
      throw const ValidationFailure(
        'Slots must be between 1 and 50.',
        code: 'host_slots_invalid',
      );
    }
    if (update.availableToDate.isBefore(update.availableFromDate)) {
      throw const ValidationFailure(
        'End date cannot be before start date.',
        code: 'host_date_range_invalid',
      );
    }
    if (!parkingRangeContainsBookableDay(
      update.availableFromDate,
      update.availableToDate,
      skipWeekends: update.skipWeekends,
    )) {
      throw const ValidationFailure(
        'Date range must include at least one weekday.',
        code: 'host_date_range_has_no_bookable_days',
      );
    }
    if (update.dailyStartMinute < 0 ||
        update.dailyStartMinute > 1410 ||
        update.dailyEndMinute < 30 ||
        update.dailyEndMinute > 1440 ||
        update.dailyStartMinute % 30 != 0 ||
        update.dailyEndMinute % 30 != 0 ||
        update.dailyEndMinute <= update.dailyStartMinute) {
      throw const ValidationFailure(
        'Daily availability must use a valid 30 minute window.',
        code: 'host_daily_window_invalid',
      );
    }
  }

  void _validatePhoto(HostPhotoUploadCandidate image) {
    if (image.bytes.isEmpty || image.bytes.length > _maxListingPhotoBytes) {
      throw const ValidationFailure(
        'This photo could not be prepared for upload. Try a different photo.',
        code: 'host_photo_size',
      );
    }
    if (!const {
      'image/heic',
      'image/heif',
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
    }.contains(image.mimeType.toLowerCase())) {
      throw const ValidationFailure(
        'Upload a JPG, PNG, WebP, HEIC, or HEIF photo.',
        code: 'host_photo_type',
      );
    }
  }

  void _validateReadyForSubmission(HostListingDraft draft) {
    if (!draft.hasBasics) {
      throw const ValidationFailure(
        'Complete the parking space basics first.',
        code: 'host_basics_incomplete',
      );
    }
    if (!draft.hasPricing) {
      throw const ValidationFailure(
        'Complete pricing and availability first.',
        code: 'host_pricing_incomplete',
      );
    }
    if (!draft.hasRequiredPhotos) {
      throw const ValidationFailure(
        'Add at least two photos before submitting.',
        code: 'host_photos_minimum',
      );
    }
  }

  AppFailure _draftFailure(
    sb.PostgrestException error, {
    required String fallbackMessage,
  }) {
    final code = error.code ?? 'host_listing_failed';
    if (code == '40001') {
      return const ValidationFailure(
        'This draft changed elsewhere. Refresh and try again.',
        code: 'host_draft_version_conflict',
      );
    }
    if (code == '23514') {
      return ValidationFailure(
        error.message.isEmpty ? 'Check the listing details.' : error.message,
        code: 'host_listing_validation_failed',
      );
    }
    if (code == 'P0002') {
      return const AuthFailure(
        'Draft listing was not found.',
        code: 'host_draft_not_found',
      );
    }
    return AuthFailure(fallbackMessage, code: code);
  }

  sb.SupabaseClient _readyClient() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const ConfigurationFailure(
        'Supabase is not configured for this build.',
        code: 'supabase_not_configured',
      );
    }

    final sb.SupabaseClient client;
    try {
      client = _client;
    } catch (_) {
      throw const ConfigurationFailure(
        'Supabase is not initialized for this build.',
        code: 'supabase_not_initialized',
      );
    }

    if (client.auth.currentUser == null) {
      throw const AuthFailure('Session expired.', code: 'session_expired');
    }
    return client;
  }

  String? _stringFrom(Map<String, Object?> map, String key) {
    final value = map[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  int _intFrom(Map<String, Object?> map, String key, {required int fallback}) {
    final value = map[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  bool _boolFrom(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String? _nullIfBlank(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _availabilitySummary(HostPricingDraftUpdate update) {
    final start = _dateOnly(update.availableFromDate);
    final end = _dateOnly(update.availableToDate);
    final weekend = update.skipWeekends ? ', weekdays only' : '';
    return '$start to $end, ${update.dailyStartMinute}-${update.dailyEndMinute}$weekend';
  }

  String _minuteLabel(int minuteOfDay) {
    final clamped = minuteOfDay.clamp(0, 1440).toInt();
    final hour = (clamped ~/ 60).toString().padLeft(2, '0');
    final minute = (clamped % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? _normalizeDob(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final slashMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
    if (slashMatch != null) {
      return '${slashMatch.group(3)}-${slashMatch.group(2)}-${slashMatch.group(1)}';
    }
    return text;
  }

  String _normalizeProfileName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      throw const ValidationFailure(
        'Enter your full name.',
        code: 'profile_full_name_required',
      );
    }
    if (normalized.length > 80) {
      throw const ValidationFailure(
        'Name is too long.',
        code: 'profile_full_name_too_long',
      );
    }
    return normalized;
  }

  String _normalizeProfilePhone(String value) {
    final issue = IndianMobileNumber.issue(value);
    if (issue != null) {
      throw ValidationFailure(
        IndianMobileNumber.message(issue),
        code: 'profile_phone_invalid',
      );
    }
    return IndianMobileNumber.normalize(value)!;
  }

  String _normalizeProfileGender(String value) {
    final normalized = value.trim();
    if (!const {
      'male',
      'female',
      'other',
      'prefer_not_to_say',
    }.contains(normalized)) {
      throw const ValidationFailure(
        'Choose a valid gender option.',
        code: 'profile_gender_invalid',
      );
    }
    return normalized;
  }

  String _normalizeProfileDob(String value) {
    final normalized = _normalizeDob(value);
    if (normalized == null) {
      throw const ValidationFailure(
        'Choose your date of birth.',
        code: 'profile_dob_required',
      );
    }
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) {
      throw const ValidationFailure(
        'Choose a valid date of birth.',
        code: 'profile_dob_invalid',
      );
    }
    final today = DateTime.now();
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    if (date.isAfter(DateTime(today.year, today.month, today.day))) {
      throw const ValidationFailure(
        'Date of birth cannot be in the future.',
        code: 'profile_dob_future',
      );
    }
    return _dateOnly(date);
  }

  String _normalizeVehicleType(String value) {
    final normalized = value.trim().toLowerCase();
    if (!const {'bike', 'car'}.contains(normalized)) {
      throw const ValidationFailure(
        'Choose your vehicle type.',
        code: 'vehicle_type_invalid',
      );
    }
    return normalized;
  }

  String _normalizeVehicleRegistration(String value) {
    final issue = IndianVehicleRegistration.issue(value);
    if (issue != null) {
      throw ValidationFailure(
        IndianVehicleRegistration.message(issue),
        code: 'vehicle_registration_invalid',
      );
    }
    return IndianVehicleRegistration.normalize(value)!;
  }

  String? _normalizePreviousRegistration(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return IndianVehicleRegistration.normalize(text) ??
        IndianVehicleRegistration.compact(text);
  }

  String? _normalizeOptionalVehicleText(
    String? value, {
    required String fieldCode,
    required String fieldLabel,
  }) {
    final normalized = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.length > 40) {
      throw ValidationFailure(
        '$fieldLabel is too long.',
        code: '${fieldCode}_too_long',
      );
    }
    return normalized;
  }
}

const _descriptionMaxLength = 200;
const _descriptionMinLength = 50;

class _ProfileVehicleSaveResult {
  const _ProfileVehicleSaveResult({required this.updatesPrimary});

  final bool updatesPrimary;
}

String _stableHash(String value) {
  const fnvPrime = 16777619;
  var hash = 2166136261;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
