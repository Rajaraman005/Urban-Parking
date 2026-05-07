import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_logger.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/user_setup_state.dart';
import 'user_setup_controller.dart';

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

  final hasExplicitResume = resumeDraftId != null || resumeStep != null;
  if (createNew) {
    _openNewHostSetup(context, ref, source: 'explicit_new');
    return;
  }

  final nextResumeDraftId = createNew
      ? null
      : resumeDraftId ??
            authState?.profile?.hostParkingDraftId ??
            authState?.profile?.setupDraftId;
  final nextResumeStep = createNew
      ? 'host_basics'
      : resumeStep ??
            (resumeDraftId == null ? authState?.profile?.setupStep : null);
  appLogger.info('host_setup_start_navigating', {
    'createNew': createNew,
    'profileStep': nextResumeStep,
    'hasCompletedOnboarding': authState?.profile?.hasCompletedOnboarding,
    'hostParkingDraftId': authState?.profile?.hostParkingDraftId,
    'profileDraftId': authState?.profile?.setupDraftId,
    'resumeDraftId': nextResumeDraftId,
  });

  if (!hasExplicitResume) {
    final HostListingDraft? resumeCandidate;
    try {
      resumeCandidate = await _loadResumeCandidate(ref);
    } catch (error) {
      appLogger.error('host_setup_resume_lookup_failed', null, error);
      if (context.mounted) {
        AppToast.error(context, 'Could not check saved drafts. Try again.');
      }
      return;
    }
    if (!context.mounted) return;

    if (resumeCandidate == null) {
      _openNewHostSetup(context, ref, source: 'no_resume_draft');
      return;
    }

    final choice = await _showResumeDraftPrompt(context, resumeCandidate);
    if (!context.mounted || choice == null) return;

    appLogger.info('host_setup_resume_prompt_selected', {
      'choice': choice.name,
      'draftId': resumeCandidate.id,
      'savedStep': _resumeStepForDraft(resumeCandidate),
    });

    if (choice == _HostSetupLaunchChoice.createNew) {
      _openNewHostSetup(context, ref, source: 'resume_prompt_new');
      return;
    }

    await _resumeHostSetup(
      context,
      ref,
      createNew: false,
      resumeDraftId: resumeCandidate.id,
      resumeStep: _resumeStepForDraft(resumeCandidate),
    );
    return;
  }

  await _resumeHostSetup(
    context,
    ref,
    createNew: false,
    resumeDraftId: nextResumeDraftId,
    resumeStep: nextResumeStep,
  );
}

void _openNewHostSetup(
  BuildContext context,
  WidgetRef ref, {
  required String source,
}) {
  ref.read(userSetupControllerProvider.notifier).prepareNewHostListing();
  appLogger.info('host_setup_start_route_opened', {
    'route': '/setup/host-basics',
    'createNew': true,
    'source': source,
  });
  context.go('/setup/host-basics?new=1');
}

Future<void> _resumeHostSetup(
  BuildContext context,
  WidgetRef ref, {
  required bool createNew,
  String? resumeDraftId,
  String? resumeStep,
}) async {
  try {
    final setupState = await ref
        .read(userSetupControllerProvider.notifier)
        .startHostListing(
          createNew: createNew,
          resumeDraftId: resumeDraftId,
          resumeStep: resumeStep,
        );
    final route = routeForHostSetupStep(setupState.step);
    appLogger.info('host_setup_start_state_saved', {
      'setupStep': setupState.step,
      'draftId': setupState.draftId,
      'route': route,
    });
    if (context.mounted) context.go(route);
  } catch (error) {
    appLogger.error('host_setup_start_state_failed', null, error);
    if (context.mounted) {
      AppToast.error(context, 'Could not start hosting setup. Try again.');
    }
  }
}

Future<HostListingDraft?> _loadResumeCandidate(WidgetRef ref) async {
  final candidate = await ref
      .read(userSetupControllerProvider.notifier)
      .loadHostDraftResumeCandidate();
  if (_isResumableDraft(candidate)) return candidate;

  ref.invalidate(userSetupControllerProvider);
  return null;
}

Future<_HostSetupLaunchChoice?> _showResumeDraftPrompt(
  BuildContext context,
  HostListingDraft draft,
) {
  return showModalBottomSheet<_HostSetupLaunchChoice>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ResumeDraftSheet(draft: draft),
  );
}

bool _isResumableDraft(HostListingDraft? draft) {
  return draft != null && draft.status == 'draft';
}

String _firstIncompleteStep(HostListingDraft draft) {
  if (!draft.hasBasics) return 'host_basics';
  if (!draft.hasPricing) return 'host_pricing';
  if (!draft.hasRequiredPhotos) return 'host_photos';
  return 'host_review';
}

String _resumeStepForDraft(HostListingDraft draft) {
  final savedStep = draft.currentStep;
  if (_hostSetupRoutes.containsKey(savedStep)) return savedStep!;
  return _firstIncompleteStep(draft);
}

String _stepLabelForDraft(HostListingDraft draft) {
  return switch (_resumeStepForDraft(draft)) {
    'host_pricing' => 'Step 2 of 4',
    'host_photos' => 'Step 3 of 4',
    'host_review' => 'Step 4 of 4',
    _ => 'Step 1 of 4',
  };
}

String _draftSummary(HostListingDraft draft) {
  final title = draft.title?.trim();
  final address = draft.address?.trim();
  if (title != null && title.isNotEmpty) return title;
  if (address != null && address.isNotEmpty) return address;
  return 'Unsaved parking listing';
}

enum _HostSetupLaunchChoice { resume, createNew }

class _ResumeDraftSheet extends StatelessWidget {
  const _ResumeDraftSheet({required this.draft});

  final HostListingDraft draft;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Continue your draft?',
                    style: TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF52525B),
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _stepLabelForDraft(draft),
                            style: const TextStyle(
                              color: Color(0xFF71717A),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _draftSummary(draft),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0B0B0C),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HostSetupLaunchChoice.resume),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B0B0C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Continue draft',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(_HostSetupLaunchChoice.createNew),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0B0B0C),
                  side: const BorderSide(color: Color(0xFF0B0B0C)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Start new listing',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
