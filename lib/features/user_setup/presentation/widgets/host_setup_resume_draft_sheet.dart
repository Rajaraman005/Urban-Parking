import 'package:flutter/material.dart';

import '../../domain/user_setup_state.dart';
import '../host_setup_launch_controller.dart';

enum HostSetupResumeDraftAction { resume, createNew }

Future<HostSetupResumeDraftAction?> showHostSetupResumeDraftSheet(
  BuildContext context,
  HostListingDraft draft,
) {
  return showModalBottomSheet<HostSetupResumeDraftAction>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _HostSetupResumeDraftSheet(draft: draft),
  );
}

class _HostSetupResumeDraftSheet extends StatelessWidget {
  const _HostSetupResumeDraftSheet({required this.draft});

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
                onPressed: () => Navigator.of(
                  context,
                ).pop(HostSetupResumeDraftAction.resume),
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
                onPressed: () => Navigator.of(
                  context,
                ).pop(HostSetupResumeDraftAction.createNew),
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

  static String _stepLabelForDraft(HostListingDraft draft) {
    return switch (resumeStepForHostDraft(draft)) {
      'host_pricing' => 'Step 2 of 4',
      'host_photos' => 'Step 3 of 4',
      'host_review' => 'Step 4 of 4',
      _ => 'Step 1 of 4',
    };
  }

  static String _draftSummary(HostListingDraft draft) {
    final title = draft.title?.trim();
    final address = draft.address?.trim();
    if (title != null && title.isNotEmpty) return title;
    if (address != null && address.isNotEmpty) return address;
    return 'Unsaved parking listing';
  }
}
