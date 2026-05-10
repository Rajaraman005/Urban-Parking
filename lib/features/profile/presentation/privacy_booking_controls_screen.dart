import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import 'profile_controls_controller.dart';

class PrivacyBookingControlsScreen extends ConsumerWidget {
  const PrivacyBookingControlsScreen({super.key});

  static const _brandColor = Color(0xFFB9F45E);
  static const _backgroundColor = Color(0xFFF5F6F8);
  static const _inkColor = Color(0xFF0B0B0C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authControllerProvider);
    final saving = ref.watch(profileControlsControllerProvider).isLoading;
    final profile = authValue.value?.profile;

    return AppScreen(
      padded: false,
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _brandColor,
        foregroundColor: _inkColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _brandColor,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
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
          'Privacy & Booking',
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
                _ControlsSection(
                  title: 'Privacy',
                  children: [
                    _SettingsSwitchRow(
                      enabled: !saving,
                      title: 'Show phone number',
                      subtitle: profile.showPhoneNumber
                          ? 'Visible on public marketplace views'
                          : 'Hidden from public marketplace views',
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
                    _SettingsSwitchRow(
                      enabled: !saving,
                      title: 'Auto approve bookings',
                      subtitle:
                          profile.bookingApprovalMode ==
                              BookingApprovalMode.auto
                          ? 'Requests are approved automatically'
                          : 'Requests need your manual approval',
                      value:
                          profile.bookingApprovalMode ==
                          BookingApprovalMode.auto,
                      onChanged: (value) => unawaited(
                        _update(
                          context,
                          ref,
                          bookingApprovalMode: value
                              ? BookingApprovalMode.auto
                              : BookingApprovalMode.manual,
                          showPhoneNumber: profile.showPhoneNumber,
                        ),
                      ),
                    ),
                  ],
                ),
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
        Column(children: children),
      ],
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.enabled,
    required this.onChanged,
    required this.subtitle,
    required this.title,
    required this.value,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String subtitle;
  final String title;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: title,
      toggled: value,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    subtitle,
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
            const SizedBox(width: 12),
            _SettingsToggle(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({required this.onChanged, required this.value});

  final ValueChanged<bool>? onChanged;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final trackColor = value ? const Color(0xFF0B0B0C) : Colors.white;
    final borderColor = value
        ? const Color(0xFF0B0B0C)
        : const Color(0xFF9CA3AF);
    final thumbColor = value ? Colors.white : const Color(0xFF0B0B0C);

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 54,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: thumbColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const SizedBox.square(dimension: 24),
              ),
            ),
          ),
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
        _SkeletonBlock(height: 78),
        SizedBox(height: 16),
        _SkeletonBlock(height: 78),
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
