import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/host_parking_draft.dart';
import '../domain/host_parking_repository.dart';

class SupabaseHostParkingRepository implements HostParkingRepository {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<HostParkingDraft> ensureDraft({
    bool createNew = false,
    String? requestedDraftId,
  }) async {
    _assertReady();
    try {
      final response = await _client.rpc(
        'ensure_host_parking_draft',
        params: {
          'p_create_new': createNew,
          'p_requested_draft_id': requestedDraftId,
        },
      );
      return HostParkingDraft.fromJson(response);
    } on sb.PostgrestException catch (error) {
      throw _toFailure(error, fallbackMessage: 'Could not prepare draft.');
    }
  }

  @override
  Future<HostParkingDraft> getDraft(String draftId) async {
    _assertReady();
    try {
      final response = await _client.rpc(
        'get_host_parking_draft',
        params: {'p_draft_id': draftId},
      );
      return HostParkingDraft.fromJson(response);
    } on sb.PostgrestException catch (error) {
      throw _toFailure(error, fallbackMessage: 'Could not load draft.');
    }
  }

  @override
  Future<HostParkingPatchResult> patchDraft({
    required String draftId,
    required HostParkingMutation mutation,
  }) async {
    _assertReady();
    try {
      final response = await _client.rpc(
        'patch_host_parking_draft',
        params: {
          'p_base_version': mutation.baseVersion,
          'p_client_mutation_id': mutation.clientMutationId,
          'p_current_step': mutation.nextStep,
          'p_device_id': mutation.deviceId,
          'p_draft_id': draftId,
          'p_field_mask': mutation.fieldMask,
          'p_idempotency_key_hash': mutation.idempotencyKeyHash,
          'p_patch': mutation.patch,
          'p_request_hash': mutation.requestHash,
        },
      );
      final payload = Map<String, Object?>.from(response as Map);
      if (payload['conflict'] == true || payload['ok'] == false) {
        throw HostParkingDraftConflict.fromJson(payload);
      }
      return HostParkingPatchResult.fromJson(payload);
    } on HostParkingDraftConflict {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw _toFailure(error, fallbackMessage: 'Could not save draft.');
    }
  }

  @override
  Future<HostParkingDraft> deletePhoto({
    required String draftId,
    required String photoId,
  }) async {
    _assertReady();
    try {
      final response = await _client.rpc(
        'delete_host_parking_draft_photo',
        params: {'p_draft_id': draftId, 'p_photo_id': photoId},
      );
      return HostParkingDraft.fromJson(response);
    } on sb.PostgrestException catch (error) {
      throw _toFailure(error, fallbackMessage: 'Could not remove photo.');
    }
  }

  @override
  Future<HostParkingDraft> reorderPhotos({
    required String draftId,
    required List<String> photoIds,
  }) async {
    _assertReady();
    try {
      final response = await _client.rpc(
        'reorder_host_parking_draft_photos',
        params: {'p_draft_id': draftId, 'p_photo_ids': photoIds},
      );
      return HostParkingDraft.fromJson(response);
    } on sb.PostgrestException catch (error) {
      throw _toFailure(error, fallbackMessage: 'Could not reorder photos.');
    }
  }

  @override
  Future<HostParkingDraft> publish({
    required String draftId,
    required int expectedVersion,
    required String clientMutationId,
    required String idempotencyKeyHash,
    required String requestHash,
  }) async {
    _assertReady();
    try {
      final response = await _client.rpc(
        'publish_host_parking_draft',
        params: {
          'p_client_mutation_id': clientMutationId,
          'p_draft_id': draftId,
          'p_expected_version': expectedVersion,
          'p_idempotency_key_hash': idempotencyKeyHash,
          'p_request_hash': requestHash,
        },
      );
      final payload = Map<String, Object?>.from(response as Map);
      return HostParkingDraft.fromJson(payload['draft'] ?? payload);
    } on sb.PostgrestException catch (error) {
      throw _toFailure(error, fallbackMessage: 'Could not publish draft.');
    }
  }

  AppFailure _toFailure(
    sb.PostgrestException error, {
    required String fallbackMessage,
  }) {
    final code = error.code ?? 'host_parking_failed';
    if (code == '40001') {
      return const ValidationFailure(
        'This draft changed elsewhere. Review the latest version.',
        code: 'host_parking_version_conflict',
      );
    }
    if (code == '23514') {
      return ValidationFailure(
        error.message.isEmpty ? 'Check the draft details.' : error.message,
        code: 'host_parking_validation_failed',
      );
    }
    if (code == 'P0002') {
      return const AuthFailure(
        'Draft listing was not found.',
        code: 'host_parking_draft_not_found',
      );
    }
    if (code == '42501') {
      return const AuthFailure(
        'You do not have access to this draft.',
        code: 'host_parking_forbidden',
      );
    }
    return NetworkFailure(fallbackMessage, code: code);
  }

  void _assertReady() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const ConfigurationFailure(
        'Supabase is not configured for this build.',
        code: 'supabase_not_configured',
      );
    }
    if (_client.auth.currentUser == null) {
      throw const AuthFailure('Session expired.', code: 'session_expired');
    }
  }
}
