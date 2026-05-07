import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../data/host_parking_local_store.dart';
import '../data/supabase_host_parking_repository.dart';
import '../domain/host_parking_draft.dart';
import '../domain/host_parking_repository.dart';

final hostParkingRepositoryProvider = Provider<HostParkingRepository>((ref) {
  return SupabaseHostParkingRepository();
});

final hostParkingLocalStoreProvider = Provider<HostParkingLocalStore>((ref) {
  return HostParkingLocalStore();
});

final hostParkingDraftControllerProvider =
    AsyncNotifierProvider<HostParkingDraftController, HostParkingDraftState>(
      HostParkingDraftController.new,
    );

class HostParkingDraftState {
  const HostParkingDraftState({
    this.conflict,
    this.draft,
    this.errorMessage,
    this.pendingMutationCount = 0,
    this.saveStatus = HostParkingSaveStatus.idle,
  });

  final HostParkingDraftConflict? conflict;
  final HostParkingDraft? draft;
  final String? errorMessage;
  final int pendingMutationCount;
  final HostParkingSaveStatus saveStatus;

  HostParkingDraftState copyWith({
    HostParkingDraftConflict? conflict,
    bool clearConflict = false,
    HostParkingDraft? draft,
    String? errorMessage,
    bool clearError = false,
    int? pendingMutationCount,
    HostParkingSaveStatus? saveStatus,
  }) {
    return HostParkingDraftState(
      conflict: clearConflict ? null : conflict ?? this.conflict,
      draft: draft ?? this.draft,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      pendingMutationCount: pendingMutationCount ?? this.pendingMutationCount,
      saveStatus: saveStatus ?? this.saveStatus,
    );
  }
}

class HostParkingDraftController extends AsyncNotifier<HostParkingDraftState> {
  static const autosaveIdleDelay = Duration(milliseconds: 1200);
  static const autosaveMaxWait = Duration(seconds: 10);
  static const retryCap = Duration(seconds: 60);

  Timer? _idleTimer;
  Timer? _maxWaitTimer;
  Future<void> _flushChain = Future.value();
  int _retryAttempt = 0;
  final _uuid = const Uuid();

  HostParkingRepository get _repository =>
      ref.read(hostParkingRepositoryProvider);

  HostParkingLocalStore get _localStore =>
      ref.read(hostParkingLocalStoreProvider);

  @override
  Future<HostParkingDraftState> build() async {
    ref.onDispose(() {
      _idleTimer?.cancel();
      _maxWaitTimer?.cancel();
    });

    final localDraft = await _localStore.readLatestDraft();
    if (localDraft != null) {
      return HostParkingDraftState(
        draft: localDraft,
        saveStatus: HostParkingSaveStatus.savedOnDevice,
      );
    }
    return const HostParkingDraftState();
  }

  Future<HostParkingDraft> ensureDraft({
    bool createNew = false,
    String? requestedDraftId,
  }) async {
    final local = !createNew && requestedDraftId != null
        ? await _localStore.readDraft(requestedDraftId)
        : !createNew
        ? await _localStore.readLatestDraft()
        : null;
    if (local != null) {
      _setData(
        (current) => current.copyWith(
          draft: local,
          saveStatus: HostParkingSaveStatus.savedOnDevice,
        ),
      );
    }

    final draft = await _repository.ensureDraft(
      createNew: createNew,
      requestedDraftId: requestedDraftId,
    );
    await _localStore.saveDraft(draft);
    _setData(
      (current) => current.copyWith(
        clearConflict: true,
        clearError: true,
        draft: draft,
        saveStatus: HostParkingSaveStatus.saved,
      ),
    );
    return draft;
  }

  Future<void> updateBasics(HostParkingBasicsData basics) async {
    await _applyLocalPatch(
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
      nextStep: 'host_basics',
      patch: {'basics': basics.toJson()},
      update: (draft) => draft.copyWith(
        data: draft.data.copyWith(basics: basics),
        completionPercent: calculateHostParkingCompletion(
          draft.copyWith(data: draft.data.copyWith(basics: basics)),
        ),
      ),
    );
  }

  Future<void> updatePricing(HostParkingPricingData pricing) async {
    await _applyLocalPatch(
      fieldMask: const [
        'pricing.hourlyPrice',
        'pricing.slotsCount',
        'pricing.availableFromDate',
        'pricing.availableToDate',
        'pricing.dailyStartMinute',
        'pricing.dailyEndMinute',
        'pricing.skipWeekends',
      ],
      nextStep: 'host_pricing',
      patch: {'pricing': pricing.toJson()},
      update: (draft) => draft.copyWith(
        data: draft.data.copyWith(pricing: pricing),
        completionPercent: calculateHostParkingCompletion(
          draft.copyWith(data: draft.data.copyWith(pricing: pricing)),
        ),
      ),
    );
  }

  Future<void> flushNow() {
    _idleTimer?.cancel();
    _maxWaitTimer?.cancel();
    return _queueFlush();
  }

  Future<HostParkingDraft> publish() async {
    await flushNow();
    final current = state.value?.draft;
    if (current == null) {
      throw const ValidationFailure(
        'Start a draft before publishing.',
        code: 'host_parking_draft_missing',
      );
    }
    if (state.value?.conflict != null) {
      throw const ValidationFailure(
        'Resolve draft conflicts before publishing.',
        code: 'host_parking_conflict_unresolved',
      );
    }

    final request = _mutationEnvelope(
      baseVersion: current.version,
      fieldMask: const ['publish'],
      patch: const {'publish': true},
    );
    final draft = await _repository.publish(
      draftId: current.id,
      expectedVersion: current.version,
      clientMutationId: request.clientMutationId,
      idempotencyKeyHash: request.idempotencyKeyHash,
      requestHash: request.requestHash,
    );
    await _localStore.saveDraft(draft);
    _setData(
      (currentState) => currentState.copyWith(
        clearConflict: true,
        clearError: true,
        draft: draft,
        pendingMutationCount: 0,
        saveStatus: HostParkingSaveStatus.saved,
      ),
    );
    return draft;
  }

  Future<void> _applyLocalPatch({
    required List<String> fieldMask,
    required String nextStep,
    required Map<String, Object?> patch,
    required HostParkingDraft Function(HostParkingDraft draft) update,
  }) async {
    final current = state.value?.draft;
    if (current == null) {
      throw const ValidationFailure(
        'Start a draft before editing.',
        code: 'host_parking_draft_missing',
      );
    }

    final next = update(current);
    await _localStore.saveDraft(next);
    final mutation = _mutationEnvelope(
      baseVersion: current.version,
      fieldMask: fieldMask,
      nextStep: nextStep,
      patch: patch,
    );
    final existingQueue = await _localStore.readQueuedMutations(current.id);
    if (existingQueue.isEmpty) {
      await _localStore.enqueueMutation(current.id, _mutationToJson(mutation));
    } else {
      await _localStore.replaceQueuedMutations(current.id, [
        _coalesceMutationQueue([...existingQueue, _mutationToJson(mutation)]),
      ]);
    }
    final queued = await _localStore.readQueuedMutations(current.id);
    _setData(
      (state) => state.copyWith(
        clearError: true,
        draft: next,
        pendingMutationCount: queued.length,
        saveStatus: HostParkingSaveStatus.savedOnDevice,
      ),
    );
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _idleTimer?.cancel();
    _idleTimer = Timer(autosaveIdleDelay, () {
      unawaited(_queueFlush());
    });
    _maxWaitTimer ??= Timer(autosaveMaxWait, () {
      _maxWaitTimer = null;
      unawaited(_queueFlush());
    });
  }

  Future<void> _queueFlush() {
    _flushChain = _flushChain.then((_) => _flushQueuedMutations());
    return _flushChain;
  }

  Future<void> _flushQueuedMutations() async {
    final draft = state.value?.draft;
    if (draft == null) return;
    var queued = await _localStore.readQueuedMutations(draft.id);
    if (queued.isEmpty) {
      _setData(
        (state) => state.copyWith(saveStatus: HostParkingSaveStatus.saved),
      );
      return;
    }

    _setData(
      (state) => state.copyWith(saveStatus: HostParkingSaveStatus.syncing),
    );

    var latestDraft = draft;
    final remaining = <Map<String, Object?>>[];
    for (final entry in queued) {
      try {
        final result = await _repository.patchDraft(
          draftId: draft.id,
          mutation: _mutationFromJson(entry),
        );
        _retryAttempt = 0;
        latestDraft = result.draft;
        await _localStore.saveDraft(latestDraft);
      } on HostParkingDraftConflict catch (conflict) {
        remaining.add(entry);
        _setData(
          (state) => state.copyWith(
            conflict: conflict,
            draft: conflict.serverDraft,
            pendingMutationCount: remaining.length,
            saveStatus: HostParkingSaveStatus.needsReview,
          ),
        );
        await _localStore.replaceQueuedMutations(draft.id, remaining);
        return;
      } on AppFailure catch (error) {
        remaining.add(entry);
        appLogger.warn('host_parking_autosave_failed', {
          'code': error.code,
          'retryable': error.retryable,
        });
        _setData(
          (state) => state.copyWith(
            errorMessage: error.message,
            pendingMutationCount: remaining.length,
            saveStatus: error.retryable
                ? HostParkingSaveStatus.savedOnDevice
                : HostParkingSaveStatus.syncFailed,
          ),
        );
        await _localStore.replaceQueuedMutations(draft.id, [
          ...remaining,
          ...queued.skip(queued.indexOf(entry) + 1),
        ]);
        if (error.retryable) _scheduleRetry();
        return;
      }
    }

    queued = const [];
    await _localStore.replaceQueuedMutations(draft.id, queued);
    _setData(
      (state) => state.copyWith(
        clearConflict: true,
        clearError: true,
        draft: latestDraft,
        pendingMutationCount: 0,
        saveStatus: HostParkingSaveStatus.saved,
      ),
    );
  }

  void _scheduleRetry() {
    _idleTimer?.cancel();
    _retryAttempt = (_retryAttempt + 1).clamp(1, 6);
    final seconds = (1 << (_retryAttempt - 1)).clamp(1, retryCap.inSeconds);
    _idleTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_queueFlush());
    });
  }

  HostParkingMutation _mutationEnvelope({
    required int baseVersion,
    required List<String> fieldMask,
    required Map<String, Object?> patch,
    String? nextStep,
  }) {
    final clientMutationId = _uuid.v4();
    final encoded = jsonEncode({
      'baseVersion': baseVersion,
      'clientMutationId': clientMutationId,
      'fieldMask': fieldMask,
      'nextStep': nextStep,
      'patch': patch,
    });
    final hash = _stableHash(encoded);
    return HostParkingMutation(
      baseVersion: baseVersion,
      clientMutationId: clientMutationId,
      deviceId: 'flutter-client',
      fieldMask: fieldMask,
      idempotencyKeyHash: hash,
      nextStep: nextStep,
      patch: patch,
      requestHash: hash,
    );
  }

  Map<String, Object?> _mutationToJson(HostParkingMutation mutation) => {
    'baseVersion': mutation.baseVersion,
    'clientMutationId': mutation.clientMutationId,
    'deviceId': mutation.deviceId,
    'fieldMask': mutation.fieldMask,
    'idempotencyKeyHash': mutation.idempotencyKeyHash,
    'nextStep': mutation.nextStep,
    'patch': mutation.patch,
    'requestHash': mutation.requestHash,
  };

  HostParkingMutation _mutationFromJson(Map<String, Object?> json) {
    return HostParkingMutation(
      baseVersion: (json['baseVersion'] as num).toInt(),
      clientMutationId: json['clientMutationId'].toString(),
      deviceId: json['deviceId']?.toString() ?? 'flutter-client',
      fieldMask: (json['fieldMask'] as List<dynamic>)
          .map((entry) => entry.toString())
          .toList(growable: false),
      idempotencyKeyHash: json['idempotencyKeyHash'].toString(),
      nextStep: json['nextStep']?.toString(),
      patch: Map<String, Object?>.from(json['patch'] as Map),
      requestHash: json['requestHash'].toString(),
    );
  }

  Map<String, Object?> _coalesceMutationQueue(
    List<Map<String, Object?>> mutations,
  ) {
    final first = mutations.first;
    final last = mutations.last;
    final fieldMask = <String>{};
    var patch = <String, Object?>{};

    for (final mutation in mutations) {
      fieldMask.addAll(
        (mutation['fieldMask'] as List<dynamic>).map(
          (entry) => entry.toString(),
        ),
      );
      patch = _deepMerge(
        patch,
        Map<String, Object?>.from(mutation['patch'] as Map),
      );
    }

    final encoded = jsonEncode({
      'baseVersion': first['baseVersion'],
      'fieldMask': fieldMask.toList(growable: false)..sort(),
      'nextStep': last['nextStep'],
      'patch': patch,
    });
    final hash = _stableHash(encoded);

    return {
      'baseVersion': first['baseVersion'],
      'clientMutationId': last['clientMutationId'],
      'deviceId': last['deviceId'],
      'fieldMask': fieldMask.toList(growable: false)..sort(),
      'idempotencyKeyHash': hash,
      'nextStep': last['nextStep'],
      'patch': patch,
      'requestHash': hash,
    };
  }

  void _setData(HostParkingDraftState Function(HostParkingDraftState) update) {
    final current = state.value ?? const HostParkingDraftState();
    state = AsyncData(update(current));
  }
}

Map<String, Object?> _deepMerge(
  Map<String, Object?> target,
  Map<String, Object?> patch,
) {
  final result = Map<String, Object?>.from(target);
  for (final entry in patch.entries) {
    final current = result[entry.key];
    final incoming = entry.value;
    if (current is Map && incoming is Map) {
      result[entry.key] = _deepMerge(
        Map<String, Object?>.from(current),
        Map<String, Object?>.from(incoming),
      );
    } else {
      result[entry.key] = incoming;
    }
  }
  return result;
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
