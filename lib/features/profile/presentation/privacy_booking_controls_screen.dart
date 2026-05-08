import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import 'profile_controls_controller.dart';

class PrivacyBookingControlsScreen extends ConsumerWidget {
  const PrivacyBookingControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authControllerProvider);
    final saving = ref.watch(profileControlsControllerProvider).isLoading;
    final profile = authValue.value?.profile;

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
          'Privacy & Booking Controls',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      child: authValue.isLoading && profile == null
          ? const _ControlsSkeleton()
          : profile == null
          ? const _SignedOutState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                _StatusHeader(
                  bookingApprovalMode: profile.bookingApprovalMode,
                  showPhoneNumber: profile.showPhoneNumber,
                  saving: saving,
                ),
                const SizedBox(height: 18),
                _ControlsSection(
                  title: 'Privacy',
                  children: [
                    _PhoneVisibilityTile(
                      enabled: !saving,
                      value: profile.showPhoneNumber,
                      onChanged: (value) => unawaited(
                        _update(
                          context,
                          ref,
                          bookingApprovalMode: profile.bookingApprovalMode,
                          showPhoneNumber: value,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ControlsSection(
                  title: 'Booking approvals',
                  children: [
                    _ApprovalModeControl(
                      enabled: !saving,
                      value: profile.bookingApprovalMode,
                      onChanged: (value) => unawaited(
                        _update(
                          context,
                          ref,
                          bookingApprovalMode: value,
                          showPhoneNumber: profile.showPhoneNumber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _OperationalNotice(),
              ],
            ),
    );
  }

  Future<void> _update(
    BuildContext context,
    WidgetRef ref, {
    required BookingApprovalMode bookingApprovalMode,
    required bool showPhoneNumber,
  }) async {
    try {
      await ref
          .read(profileControlsControllerProvider.notifier)
          .updateControls(
            bookingApprovalMode: bookingApprovalMode,
            showPhoneNumber: showPhoneNumber,
          );
      if (context.mounted) {
        AppToast.success(context, 'Controls saved');
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, _errorMessage(error));
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Could not save controls. Please try again.';
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.bookingApprovalMode,
    required this.saving,
    required this.showPhoneNumber,
  });

  final BookingApprovalMode bookingApprovalMode;
  final bool saving;
  final bool showPhoneNumber;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: colors.onPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    saving ? 'Saving controls' : 'Controls active',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (saving)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: colors.onPrimary,
                      strokeWidth: 2.2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${showPhoneNumber ? 'Phone visible' : 'Phone hidden'} | ${_modeLabel(bookingApprovalMode)}',
              style: TextStyle(
                color: colors.onPrimary.withValues(alpha: 0.72),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modeLabel(BookingApprovalMode mode) {
    return switch (mode) {
      BookingApprovalMode.auto => 'Auto approval',
      BookingApprovalMode.manual => 'Manual approval',
    };
  }
}

class _ControlsSection extends StatelessWidget {
  const _ControlsSection({required this.children, required this.title});

  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _PhoneVisibilityTile extends StatelessWidget {
  const _PhoneVisibilityTile({
    required this.enabled,
    required this.onChanged,
    required this.value,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Show phone number publicly',
      toggled: value,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            _LeadingIcon(
              icon: value
                  ? Icons.phone_enabled_outlined
                  : Icons.phone_disabled_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Show phone number',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    value
                        ? 'Other users can call or message you from listings.'
                        : 'Your phone is hidden from public marketplace views.',
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
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalModeControl extends StatelessWidget {
  const _ApprovalModeControl({
    required this.enabled,
    required this.onChanged,
    required this.value,
  });

  final bool enabled;
  final ValueChanged<BookingApprovalMode> onChanged;
  final BookingApprovalMode value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LeadingIcon(icon: Icons.event_available_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Approval mode',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ModeSegmentedButton(
            enabled: enabled,
            onChanged: onChanged,
            value: value,
          ),
          const SizedBox(height: 12),
          Text(
            value == BookingApprovalMode.auto
                ? 'Bookings are approved immediately when capacity is available.'
                : 'Requests stay pending for up to 24 hours until you approve or reject.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.28,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentedButton extends StatelessWidget {
  const _ModeSegmentedButton({
    required this.enabled,
    required this.onChanged,
    required this.value,
  });

  final bool enabled;
  final ValueChanged<BookingApprovalMode> onChanged;
  final BookingApprovalMode value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: _ModeOption(
                enabled: enabled,
                icon: Icons.bolt_outlined,
                label: 'Auto',
                selected: value == BookingApprovalMode.auto,
                onTap: () => onChanged(BookingApprovalMode.auto),
              ),
            ),
            Expanded(
              child: _ModeOption(
                enabled: enabled,
                icon: Icons.fact_check_outlined,
                label: 'Manual',
                selected: value == BookingApprovalMode.manual,
                onTap: () => onChanged(BookingApprovalMode.manual),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled && !selected ? onTap : null,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: selected ? colors.onPrimary : colors.onSurface,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? colors.onPrimary : colors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, color: colors.onSurface, size: 19),
      ),
    );
  }
}

class _OperationalNotice extends StatelessWidget {
  const _OperationalNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_clock_outlined, color: colors.onSurface, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pending booking requests expire after 24 hours. Payment holds are not part of this release.',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.28,
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

class _ControlsSkeleton extends StatelessWidget {
  const _ControlsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: const [
        _SkeletonBlock(height: 86),
        SizedBox(height: 18),
        _SkeletonBlock(height: 96),
        SizedBox(height: 16),
        _SkeletonBlock(height: 156),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(height: height),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign in required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Privacy and booking controls belong to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
