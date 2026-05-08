import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/telemetry.dart';
import '../../auth/domain/auth_state.dart';
import '../../parking/presentation/owner_parking_controller.dart';
import '../domain/user_setup_state.dart';
import 'user_setup_controller.dart';

final hostSetupLaunchControllerProvider =
    NotifierProvider<HostSetupLaunchController, HostSetupLaunchState>(
      HostSetupLaunchController.new,
    );

enum HostSetupLaunchPhase {
  idle,
  routeOpening,
  hydrating,
  resumeAvailable,
  draftReady,
  failed,
}

class HostSetupLaunchState {
  const HostSetupLaunchState({
    this.activeStep,
    this.draft,
    this.draftReadyMs,
    this.errorMessage,
    this.firstFrameMs,
    this.launchId = 0,
    this.phase = HostSetupLaunchPhase.idle,
    this.resumeCandidate,
    this.routeVisibleMs,
    this.shouldAutoRoute = false,
    this.startedAt,
  });

  final String? activeStep;
  final HostListingDraft? draft;
  final int? draftReadyMs;
  final String? errorMessage;
  final int? firstFrameMs;
  final int launchId;
  final HostSetupLaunchPhase phase;
  final HostListingDraft? resumeCandidate;
  final int? routeVisibleMs;
  final bool shouldAutoRoute;
  final DateTime? startedAt;

  bool get isHydrating => phase == HostSetupLaunchPhase.hydrating;
  bool get hasResumeCandidate =>
      phase == HostSetupLaunchPhase.resumeAvailable && resumeCandidate != null;
  bool get shouldBlockInitialSave =>
      phase == HostSetupLaunchPhase.routeOpening ||
      phase == HostSetupLaunchPhase.hydrating ||
      phase == HostSetupLaunchPhase.resumeAvailable;

  HostSetupLaunchState copyWith({
    String? activeStep,
    bool clearDraft = false,
    bool clearError = false,
    bool clearResumeCandidate = false,
    HostListingDraft? draft,
    int? draftReadyMs,
    String? errorMessage,
    int? firstFrameMs,
    int? launchId,
    HostSetupLaunchPhase? phase,
    HostListingDraft? resumeCandidate,
    int? routeVisibleMs,
    bool? shouldAutoRoute,
    DateTime? startedAt,
  }) {
    return HostSetupLaunchState(
      activeStep: activeStep ?? this.activeStep,
      draft: clearDraft ? null : draft ?? this.draft,
      draftReadyMs: draftReadyMs ?? this.draftReadyMs,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      firstFrameMs: firstFrameMs ?? this.firstFrameMs,
      launchId: launchId ?? this.launchId,
      phase: phase ?? this.phase,
      resumeCandidate: clearResumeCandidate
          ? null
          : resumeCandidate ?? this.resumeCandidate,
      routeVisibleMs: routeVisibleMs ?? this.routeVisibleMs,
      shouldAutoRoute: shouldAutoRoute ?? this.shouldAutoRoute,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

class HostSetupLaunchController extends Notifier<HostSetupLaunchState> {
  Future<HostListingDraft?>? _prewarmFuture;
  HostListingDraft? _prewarmedCandidate;
  String? _prewarmUserId;
  int _prewarmGeneration = 0;
  int _nextLaunchId = 0;

  @override
  HostSetupLaunchState build() => const HostSetupLaunchState();

  Future<void> prewarmResumeCandidate(AuthState? authState) async {
    if (authState?.isAuthenticated != true) return;

    final userId = authState?.user?.id;
    if (userId == null || userId.isEmpty) return;

    final existing = _prewarmFuture;
    if (existing != null && _prewarmUserId == userId) {
      await existing;
      return;
    }

    _prewarmUserId = userId;
    final generation = ++_prewarmGeneration;
    _prewarmFuture = _loadResumeCandidate()
        .then((candidate) {
          if (_prewarmGeneration == generation) {
            _prewarmedCandidate = candidate;
          }
          return candidate;
        })
        .catchError((Object error) {
          appLogger.warn('host_setup_prewarm_failed', {
            'error': error.toString(),
          });
          return null;
        });

    await _prewarmFuture;
  }

  bool hasCachedResumeCandidateForUser(AuthState? authState) {
    return _isPrewarmForUser(authState) && _prewarmedCandidate != null;
  }

  HostListingDraft? takeCachedResumeCandidateForUser(AuthState? authState) {
    return _takeCachedResumeCandidateForUser(authState);
  }

  void clearCachedResumeCandidate({String? draftId}) {
    final cached = _prewarmedCandidate;
    if (draftId != null && cached != null && cached.id != draftId) return;

    _prewarmedCandidate = null;
    _prewarmFuture = null;
    _prewarmUserId = null;
    _prewarmGeneration += 1;

    final current = state;
    final shouldClearStateDraft =
        draftId == null ||
        current.resumeCandidate?.id == draftId ||
        current.draft?.id == draftId;
    if (!shouldClearStateDraft) return;

    state = HostSetupLaunchState(
      launchId: current.launchId,
      phase: HostSetupLaunchPhase.idle,
      startedAt: current.startedAt,
    );
  }

  int beginInstantLaunch({
    required AuthState authState,
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  }) {
    final launchId = ++_nextLaunchId;
    final startedAt = DateTime.now();
    state = HostSetupLaunchState(
      activeStep: resumeStep,
      launchId: launchId,
      phase: HostSetupLaunchPhase.routeOpening,
      startedAt: startedAt,
    );
    telemetry.event(TelemetryEvent.hostLaunchTapped, {
      'createNew': createNew,
      'hasExplicitResume': resumeDraftId != null || resumeStep != null,
      'hasProfileDraft':
          authState.profile?.hostParkingDraftId != null ||
          authState.profile?.setupDraftId != null,
      'setupStep': authState.profile?.setupStep,
    });
    return launchId;
  }

  void markRouteVisible(int launchId) {
    if (state.launchId != launchId) return;
    final elapsed = _elapsedMs;
    state = state.copyWith(
      phase: HostSetupLaunchPhase.hydrating,
      routeVisibleMs: elapsed,
    );
    telemetry.event(TelemetryEvent.hostLaunchRouteVisible, {
      'launchId': launchId,
      'tapToRouteMs': elapsed,
    });
  }

  void markFirstFrame() {
    final current = state;
    if (current.firstFrameMs != null || current.startedAt == null) return;
    final elapsed = _elapsedMs;
    state = current.copyWith(firstFrameMs: elapsed);
    telemetry.event(TelemetryEvent.hostLaunchFirstFrame, {
      'launchId': current.launchId,
      'tapToFirstFrameMs': elapsed,
    });
  }

  Future<void> hydrate({
    required int launchId,
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  }) async {
    if (state.launchId != launchId) return;

    final task = developer.TimelineTask()..start('host_setup_launch_hydrate');
    telemetry.event(TelemetryEvent.hostLaunchHydrationStarted, {
      'launchId': launchId,
      'createNew': createNew,
      'hasExplicitResume': resumeDraftId != null || resumeStep != null,
    });

    try {
      if (createNew) {
        await _createFreshDraft(launchId);
        return;
      }

      if (resumeDraftId != null || resumeStep != null) {
        await _resumeExplicitDraft(
          launchId: launchId,
          resumeDraftId: resumeDraftId,
          resumeStep: resumeStep,
        );
        return;
      }

      final hasPrewarm = _prewarmedCandidate != null || _prewarmFuture != null;
      final resumeCandidate = hasPrewarm
          ? await _consumePrewarmedCandidate()
          : await _loadResumeCandidate();
      if (state.launchId != launchId) return;

      if (_isResumableDraft(resumeCandidate)) {
        state = state.copyWith(
          phase: HostSetupLaunchPhase.resumeAvailable,
          resumeCandidate: resumeCandidate,
        );
        telemetry.event(TelemetryEvent.hostLaunchResumeAvailable, {
          'launchId': launchId,
          'draftId': resumeCandidate!.id,
          'savedStep': resumeStepForHostDraft(resumeCandidate),
          'tapToResumeMs': _elapsedMs,
        });
        return;
      }

      await _createFreshDraft(launchId);
    } catch (error) {
      if (state.launchId != launchId) return;
      appLogger.error('host_setup_launch_hydration_failed', null, error);
      state = state.copyWith(
        clearDraft: true,
        clearResumeCandidate: true,
        errorMessage: 'Could not prepare host setup. Try again.',
        phase: HostSetupLaunchPhase.failed,
      );
      telemetry.error(TelemetryEvent.hostLaunchFailed, {
        'launchId': launchId,
        'errorType': error.runtimeType.toString(),
      });
    } finally {
      task.finish();
    }
  }

  Future<UserSetupState> continueResumeCandidate() async {
    final candidate = state.resumeCandidate;
    if (candidate == null) {
      throw StateError('No resumable host draft is available.');
    }

    final step = resumeStepForHostDraft(candidate);
    final next = await ref
        .read(userSetupControllerProvider.notifier)
        .startHostListing(resumeDraftId: candidate.id, resumeStep: step);
    _markDraftReady(next, shouldAutoRoute: true);
    return next;
  }

  Future<UserSetupState> startFreshDraft() async {
    final launchId = state.launchId;
    state = state.copyWith(
      clearDraft: true,
      clearError: true,
      clearResumeCandidate: true,
      phase: HostSetupLaunchPhase.hydrating,
      shouldAutoRoute: false,
    );
    return _createFreshDraft(launchId);
  }

  void clearAutoRoute() {
    if (!state.shouldAutoRoute) return;
    state = state.copyWith(shouldAutoRoute: false);
  }

  Future<UserSetupState> _createFreshDraft(int launchId) async {
    if (state.launchId != launchId) {
      throw StateError('Host setup launch was superseded.');
    }
    ref.read(userSetupControllerProvider.notifier).prepareNewHostListing();
    final next = await ref
        .read(userSetupControllerProvider.notifier)
        .startHostListing(createNew: true);
    if (state.launchId == launchId) _markDraftReady(next);
    return next;
  }

  Future<void> _resumeExplicitDraft({
    required int launchId,
    String? resumeDraftId,
    String? resumeStep,
  }) async {
    final next = await ref
        .read(userSetupControllerProvider.notifier)
        .startHostListing(resumeDraftId: resumeDraftId, resumeStep: resumeStep);
    if (state.launchId == launchId) {
      _markDraftReady(next, shouldAutoRoute: next.step != 'host_basics');
    }
  }

  void _markDraftReady(UserSetupState next, {bool shouldAutoRoute = false}) {
    final elapsed = _elapsedMs;
    state = state.copyWith(
      activeStep: next.step,
      clearError: true,
      clearResumeCandidate: true,
      draft: next.draft,
      draftReadyMs: elapsed,
      phase: HostSetupLaunchPhase.draftReady,
      shouldAutoRoute: shouldAutoRoute,
    );
    telemetry.event(TelemetryEvent.hostLaunchDraftReady, {
      'launchId': state.launchId,
      'draftReadyMs': elapsed,
      'setupStep': next.step,
      'hasDraft': next.draft != null,
      'shouldAutoRoute': shouldAutoRoute,
    });
    ref.invalidate(ownedParkingSpacesProvider);
  }

  Future<HostListingDraft?> _consumePrewarmedCandidate() async {
    final candidate = _prewarmedCandidate;
    if (candidate != null) {
      _prewarmedCandidate = null;
      _prewarmFuture = null;
      return candidate;
    }

    final future = _prewarmFuture;
    if (future == null) return null;
    _prewarmFuture = null;
    return future;
  }

  Future<HostListingDraft?> _loadResumeCandidate() {
    return ref
        .read(userSetupControllerProvider.notifier)
        .loadHostDraftResumeCandidate();
  }

  int? get _elapsedMs {
    final startedAt = state.startedAt;
    if (startedAt == null) return null;
    return DateTime.now().difference(startedAt).inMilliseconds;
  }

  HostListingDraft? _takeCachedResumeCandidateForUser(AuthState? authState) {
    if (!_isPrewarmForUser(authState)) return null;

    final candidate = _prewarmedCandidate;
    if (candidate == null) return null;

    _prewarmedCandidate = null;
    _prewarmFuture = null;

    return _isResumableDraft(candidate) ? candidate : null;
  }

  bool _isPrewarmForUser(AuthState? authState) {
    if (authState?.isAuthenticated != true) return false;
    final userId = authState?.user?.id;
    return userId != null && userId.isNotEmpty && _prewarmUserId == userId;
  }
}

bool isResumableHostDraft(HostListingDraft? draft) => _isResumableDraft(draft);

bool _isResumableDraft(HostListingDraft? draft) {
  return draft != null && draft.status == 'draft';
}

String firstIncompleteHostDraftStep(HostListingDraft draft) {
  if (!draft.hasBasics) return 'host_basics';
  if (!draft.hasPricing) return 'host_pricing';
  if (!draft.hasRequiredPhotos) return 'host_photos';
  return 'host_review';
}

String resumeStepForHostDraft(HostListingDraft draft) {
  final savedStep = draft.currentStep;
  if (const {
    'host_basics',
    'host_pricing',
    'host_photos',
    'host_review',
  }.contains(savedStep)) {
    return savedStep!;
  }
  return firstIncompleteHostDraftStep(draft);
}
