import 'host_parking_draft.dart';

class HostParkingMutation {
  const HostParkingMutation({
    required this.baseVersion,
    required this.clientMutationId,
    required this.deviceId,
    required this.fieldMask,
    required this.idempotencyKeyHash,
    required this.patch,
    required this.requestHash,
    this.nextStep,
  });

  final int baseVersion;
  final String clientMutationId;
  final String deviceId;
  final List<String> fieldMask;
  final String idempotencyKeyHash;
  final String? nextStep;
  final Map<String, Object?> patch;
  final String requestHash;
}

abstract interface class HostParkingRepository {
  Future<HostParkingDraft> ensureDraft({
    bool createNew = false,
    String? requestedDraftId,
  });

  Future<HostParkingDraft> getDraft(String draftId);

  Future<HostParkingPatchResult> patchDraft({
    required String draftId,
    required HostParkingMutation mutation,
  });

  Future<HostParkingDraft> deletePhoto({
    required String draftId,
    required String photoId,
  });

  Future<HostParkingDraft> reorderPhotos({
    required String draftId,
    required List<String> photoIds,
  });

  Future<HostParkingDraft> publish({
    required String draftId,
    required int expectedVersion,
    required String clientMutationId,
    required String idempotencyKeyHash,
    required String requestHash,
  });
}
