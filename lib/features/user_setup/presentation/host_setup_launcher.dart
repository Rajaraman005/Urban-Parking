import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_logger.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import 'host_setup_launch_controller.dart';
import 'widgets/host_setup_resume_draft_sheet.dart';

const _hostSetupRoutes = <String, String>{
  'host_basics': '/setup/host-basics',
  'host_pricing': '/setup/host-pricing',
  'host_photos': '/setup/host-photos',
  'host_review': '/setup/host-review',
};
String routeForHostSetupStep(String? step) {
  return _hostSetupRoutes[step] ?? '/setup/host-basics';
}

Future<void> startHostSetup(
  BuildContext context,
  WidgetRef ref, {
  bool createNew = false,
  String? resumeDraftId,
  String? resumeStep,
}) async {
  AuthState? authState = ref.read(authControllerProvider).value;
  authState ??= await ref.read(authControllerProvider.future);

  if (!context.mounted) return;

  if (authState?.isAuthenticated != true) {
    appLogger.info('host_setup_start_redirected_to_auth', {
      'hasAuthValue': authState != null,
    });
    context.go('/auth?mode=login');
    return;
  }

  final authenticatedAuthState = authState!;
  final controller = ref.read(hostSetupLaunchControllerProvider.notifier);
  var nextCreateNew = createNew;
  var nextResumeDraftId = resumeDraftId;
  var nextResumeStep = resumeStep;

  final hasExplicitResume = resumeDraftId != null || resumeStep != null;
  if (!createNew && !hasExplicitResume) {
    final hasProfileDraftHint = _hasProfileDraftHint(
      authenticatedAuthState.profile,
    );
    final hasWarmCandidate = controller.hasCachedResumeCandidateForUser(
      authenticatedAuthState,
    );
    if (!hasProfileDraftHint && !hasWarmCandidate) {
      nextCreateNew = true;
      _openInstantHostSetup(
        context,
        ref,
        authState: authenticatedAuthState,
        createNew: nextCreateNew,
        resumeDraftId: nextResumeDraftId,
        resumeStep: nextResumeStep,
      );
      return;
    }

    if (hasProfileDraftHint && !hasWarmCandidate) {
      unawaited(controller.prewarmResumeCandidate(authenticatedAuthState));
    }

    final resumeCandidate = controller.takeCachedResumeCandidateForUser(
      authenticatedAuthState,
    );
    if (resumeCandidate != null) {
      final action = await showHostSetupResumeDraftSheet(
        context,
        resumeCandidate,
      );
      if (!context.mounted || action == null) return;

      appLogger.info('host_setup_resume_prompt_selected', {
        'choice': action.name,
        'draftId': resumeCandidate.id,
        'savedStep': resumeStepForHostDraft(resumeCandidate),
      });

      if (action == HostSetupResumeDraftAction.resume) {
        nextResumeDraftId = resumeCandidate.id;
        nextResumeStep = resumeStepForHostDraft(resumeCandidate);
      } else {
        nextCreateNew = true;
        controller.clearCachedResumeCandidate();
      }
    } else {
      nextCreateNew = true;
      controller.clearCachedResumeCandidate();
      appLogger.info('host_setup_resume_prompt_skipped', {
        'reason': 'candidate_not_ready',
        'hasProfileDraftHint': hasProfileDraftHint,
      });
    }
  }

  _openInstantHostSetup(
    context,
    ref,
    authState: authenticatedAuthState,
    createNew: nextCreateNew,
    resumeDraftId: nextResumeDraftId,
    resumeStep: nextResumeStep,
  );
}

bool _hasProfileDraftHint(UserProfile? profile) {
  if (profile == null) return false;
  final hostDraftId = profile.hostParkingDraftId?.trim();
  final legacyDraftId = profile.setupDraftId?.trim();
  if (hostDraftId != null && hostDraftId.isNotEmpty) return true;
  if (legacyDraftId != null && legacyDraftId.isNotEmpty) return true;
  return false;
}

void _openInstantHostSetup(
  BuildContext context,
  WidgetRef ref, {
  required AuthState authState,
  required bool createNew,
  String? resumeDraftId,
  String? resumeStep,
}) {
  final launchId = ref
      .read(hostSetupLaunchControllerProvider.notifier)
      .beginInstantLaunch(
        authState: authState,
        createNew: createNew,
        resumeDraftId: resumeDraftId,
        resumeStep: resumeStep,
      );
  final route = Uri(
    path: '/setup/host-basics',
    queryParameters: {'launch': 'instant', if (createNew) 'new': '1'},
  ).toString();

  appLogger.info('host_setup_start_route_opened', {
    'route': route,
    'createNew': createNew,
    'hasExplicitResume': resumeDraftId != null || resumeStep != null,
    'profileStep': authState.profile?.setupStep,
    'hasCompletedOnboarding': authState.profile?.hasCompletedOnboarding,
    'hostParkingDraftId': authState.profile?.hostParkingDraftId,
    'profileDraftId': authState.profile?.setupDraftId,
    'resumeDraftId': resumeDraftId,
  });

  context.go(route);
  ref
      .read(hostSetupLaunchControllerProvider.notifier)
      .markRouteVisible(launchId);
  unawaited(
    ref
        .read(hostSetupLaunchControllerProvider.notifier)
        .hydrate(
          launchId: launchId,
          createNew: createNew,
          resumeDraftId: resumeDraftId,
          resumeStep: resumeStep,
        ),
  );
}
