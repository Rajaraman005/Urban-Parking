import 'package:flutter/material.dart';

import '../../domain/host_parking_draft.dart';

class HostParkingProgressHeader extends StatelessWidget {
  const HostParkingProgressHeader({
    required this.completionPercent,
    required this.currentStep,
    required this.saveStatus,
    super.key,
  });

  final int completionPercent;
  final String currentStep;
  final HostParkingSaveStatus saveStatus;

  @override
  Widget build(BuildContext context) {
    final status = _statusText(saveStatus);
    return Semantics(
      label: 'Host parking setup, $completionPercent percent complete, $status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _stepLabel(currentStep),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0B0B0C),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completionPercent%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF52525B),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: completionPercent.clamp(0, 100) / 100,
              backgroundColor: const Color(0xFFE4E4E7),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF0B0B0C)),
            ),
          ),
          const SizedBox(height: 10),
          HostParkingSaveStatusBanner(status: saveStatus),
        ],
      ),
    );
  }
}

class HostParkingSaveStatusBanner extends StatelessWidget {
  const HostParkingSaveStatusBanner({required this.status, super.key});

  final HostParkingSaveStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(_statusIcon(status), color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _statusText(status),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _stepLabel(String step) {
  return switch (step) {
    'host_pricing' => 'Pricing and availability',
    'host_photos' => 'Photos',
    'host_review' => 'Review',
    'complete' => 'Submitted',
    _ => 'Basics',
  };
}

String _statusText(HostParkingSaveStatus status) {
  return switch (status) {
    HostParkingSaveStatus.savedOnDevice => 'Saved on this device',
    HostParkingSaveStatus.syncing => 'Syncing changes',
    HostParkingSaveStatus.saved => 'Saved',
    HostParkingSaveStatus.needsReview => 'Review changes before continuing',
    HostParkingSaveStatus.syncFailed => 'Sync failed',
    HostParkingSaveStatus.idle => 'Ready',
  };
}

IconData _statusIcon(HostParkingSaveStatus status) {
  return switch (status) {
    HostParkingSaveStatus.syncing => Icons.sync_rounded,
    HostParkingSaveStatus.needsReview => Icons.report_problem_outlined,
    HostParkingSaveStatus.syncFailed => Icons.cloud_off_outlined,
    HostParkingSaveStatus.savedOnDevice => Icons.phone_iphone_rounded,
    HostParkingSaveStatus.saved => Icons.cloud_done_outlined,
    HostParkingSaveStatus.idle => Icons.radio_button_unchecked_rounded,
  };
}

Color _statusColor(HostParkingSaveStatus status) {
  return switch (status) {
    HostParkingSaveStatus.needsReview ||
    HostParkingSaveStatus.syncFailed => const Color(0xFFB91C1C),
    HostParkingSaveStatus.savedOnDevice => const Color(0xFF92400E),
    HostParkingSaveStatus.syncing => const Color(0xFF1D4ED8),
    HostParkingSaveStatus.saved => const Color(0xFF047857),
    HostParkingSaveStatus.idle => const Color(0xFF52525B),
  };
}
