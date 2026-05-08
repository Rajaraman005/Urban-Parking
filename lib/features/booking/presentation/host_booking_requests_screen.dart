import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/state_view.dart';
import '../domain/booking.dart';
import 'booking_controller.dart';
import 'booking_live_sync.dart';

class HostBookingRequestsScreen extends ConsumerWidget {
  const HostBookingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bookingLiveSyncProvider(BookingListRole.host));
    final bookings = ref.watch(hostBookingsProvider);
    final actionSaving = ref
        .watch(hostBookingActionControllerProvider)
        .isLoading;

    return AppScreen(
      padded: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Booking Requests',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      child: bookings.when(
        loading: () => const _BookingRequestsSkeleton(),
        error: (error, _) => StateView(
          title: 'Could not load requests',
          body: _errorMessage(error),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(hostBookingsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const StateView(
              title: 'No booking requests',
              body: 'New parking requests will appear here for approval.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(hostBookingsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final booking = items[index];
                return _HostBookingCard(
                  booking: booking,
                  enabled: !actionSaving,
                  onApprove: booking.status == BookingStatus.pending
                      ? () => unawaited(_approve(context, ref, booking))
                      : null,
                  onReject: booking.status == BookingStatus.pending
                      ? () => unawaited(_reject(context, ref, booking))
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    ParkingBooking booking,
  ) async {
    try {
      await ref
          .read(hostBookingActionControllerProvider.notifier)
          .approve(booking);
      if (context.mounted) {
        AppToast.success(context, 'Booking approved');
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, _errorMessage(error));
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    ParkingBooking booking,
  ) async {
    try {
      await ref
          .read(hostBookingActionControllerProvider.notifier)
          .reject(booking);
      if (context.mounted) {
        AppToast.success(context, 'Booking rejected');
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, _errorMessage(error));
      }
    }
  }

  static String _errorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Refresh and try again.';
  }
}

class _HostBookingCard extends StatelessWidget {
  const _HostBookingCard({
    required this.booking,
    required this.enabled,
    this.onApprove,
    this.onReject,
  });

  final ParkingBooking booking;
  final bool enabled;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusIcon(status: booking.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        booking.displayLocation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(status: booking.status),
              ],
            ),
            const SizedBox(height: 14),
            _BookingFactRow(
              icon: Icons.schedule_rounded,
              label: _windowLabel(booking.startAt, booking.endAt),
            ),
            const SizedBox(height: 8),
            _BookingFactRow(
              icon: Icons.directions_car_filled_outlined,
              label:
                  '${booking.vehicleKind.toUpperCase()} | Slot ${booking.slotNumber}',
            ),
            const SizedBox(height: 8),
            _BookingFactRow(
              icon: Icons.payments_outlined,
              label: formatMoney(booking.total, booking.currency),
            ),
            if (booking.renterName != null) ...[
              const SizedBox(height: 8),
              _BookingFactRow(
                icon: Icons.person_outline_rounded,
                label: booking.renterName!,
              ),
            ],
            if (booking.status == BookingStatus.pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: enabled ? onReject : null,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: enabled ? onApprove : null,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _windowLabel(DateTime startAt, DateTime endAt) {
    final sameDay =
        startAt.year == endAt.year &&
        startAt.month == endAt.month &&
        startAt.day == endAt.day;
    final start = DateFormat('EEE, d MMM h:mm a').format(startAt);
    final end = sameDay
        ? DateFormat('h:mm a').format(endAt)
        : DateFormat('EEE, d MMM h:mm a').format(endAt);
    return '$start to $end';
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(context, status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(_statusIcon(status), color: colors.foreground, size: 19),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(context, status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          _statusLabel(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.foreground,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _BookingFactRow extends StatelessWidget {
  const _BookingFactRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colors.onSurfaceVariant, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingRequestsSkeleton extends StatelessWidget {
  const _BookingRequestsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(height: 152),
    );
  }
}

({Color background, Color foreground}) _statusColors(
  BuildContext context,
  BookingStatus status,
) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    BookingStatus.pending => (
      background: colors.tertiaryContainer,
      foreground: colors.onTertiaryContainer,
    ),
    BookingStatus.approved => (
      background: colors.primaryContainer,
      foreground: colors.onPrimaryContainer,
    ),
    BookingStatus.rejected || BookingStatus.expired => (
      background: colors.errorContainer,
      foreground: colors.onErrorContainer,
    ),
  };
}

IconData _statusIcon(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => Icons.pending_actions_outlined,
    BookingStatus.approved => Icons.check_circle_outline_rounded,
    BookingStatus.rejected => Icons.cancel_outlined,
    BookingStatus.expired => Icons.timer_off_outlined,
  };
}

String _statusLabel(BookingStatus status) {
  return switch (status) {
    BookingStatus.pending => 'Pending',
    BookingStatus.approved => 'Approved',
    BookingStatus.rejected => 'Rejected',
    BookingStatus.expired => 'Expired',
  };
}
