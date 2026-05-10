import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/validation/indian_vehicle_registration.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../parking/presentation/owner_parking_controller.dart';
import '../../user_setup/presentation/host_setup_launcher.dart';
import '../../user_setup/presentation/host_setup_launch_controller.dart';
import '../data/profile_vehicle_repository.dart';
import '../domain/profile_vehicle.dart';
import 'profile_display.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authControllerProvider);
    final profileDisplay = ref.watch(currentProfileDisplayProvider);
    final profile = profileDisplay.profile ?? authValue.value?.profile;
    final vehiclesValue = ref.watch(profileVehiclesProvider);
    final vehicles = vehiclesValue.value ?? profileVehiclesFromProfile(profile);
    final primaryVehicle = _primaryVehicle(vehicles);
    final isParkingUser = _isParkingIntent(profile?.intent);

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      safeAreaBackgroundColor: const Color(0xFFB9F45E),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
        children: [
          _HostSetupPrewarmEffect(authState: authValue.value),
          _ProfileHero(
            avatarUrl: profileDisplay.avatarUrl,
            displayEmail: profileDisplay.displayEmail,
            displayName: profileDisplay.displayName,
            isLoading: authValue.isLoading,
            isSignedIn: profileDisplay.isSignedIn,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _ProfileSection(
              title: 'Account',
              children: [
                _ProfileActionTile(
                  icon: Icons.badge_outlined,
                  title: 'Personal details',
                  subtitle: 'Name, email, and profile photo',
                  onTap: () => context.push('/profile/personal-details'),
                ),
                if (!isParkingUser)
                  _ProfileActionTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & Booking',
                    subtitle: 'Phone visibility and booking approvals',
                    onTap: () =>
                        context.push('/profile/privacy-booking-controls'),
                  ),
                _ProfileActionTile(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Parking activity',
                  subtitle: 'Bookings, saved places, and recent searches',
                  onTap: () => context.go('/search'),
                ),
                if (isParkingUser)
                  _ProfileActionTile(
                    icon: _vehicleIcon(
                      primaryVehicle?.type ?? profile?.vehicleType,
                    ),
                    title: 'Vehicle details',
                    subtitle: _vehicleSummary(profile, vehicles),
                    onTap: () => context.push('/profile/vehicle-details'),
                  ),
              ],
            ),
          ),
          if (!isParkingUser)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _ProfileSection(
                title: 'Hosting',
                children: [
                  _ProfileActionTile(
                    icon: Icons.add_home_work_outlined,
                    title: 'Host a parking space',
                    subtitle: 'Create or continue a parking listing',
                    onTapDown: (_) {
                      final authState = ref.read(authControllerProvider).value;
                      if (!_shouldPrewarmHostSetup(authState)) return;
                      unawaited(
                        ref
                            .read(hostSetupLaunchControllerProvider.notifier)
                            .prewarmResumeCandidate(authState),
                      );
                    },
                    onTap: () => unawaited(startHostSetup(context, ref)),
                  ),
                  _ProfileActionTile(
                    icon: Icons.garage_outlined,
                    title: 'My parking spaces',
                    subtitle: 'Edit live price, address, and availability',
                    onTap: () {
                      ref.invalidate(ownedParkingSpacesProvider);
                      context.push('/profile/my-spaces');
                    },
                  ),
                  _ProfileActionTile(
                    icon: Icons.fact_check_outlined,
                    title: 'Booking requests',
                    subtitle: 'Approve, reject, or review host requests',
                    onTap: () => context.push('/profile/booking-requests'),
                  ),
                  _ProfileActionTile(
                    icon: Icons.payments_outlined,
                    title: 'Payouts',
                    subtitle: 'Bank details and earning preferences',
                    onTap: () => context.push('/setup/host-pricing'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _ProfileSection(
              title: 'Communication',
              children: [
                _ProfileActionTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  subtitle: 'Host chats and property conversations',
                  onTap: () => context.push('/messages'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _ProfileSection(
              title: 'Support',
              children: [
                _ProfileActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  subtitle: 'How your account data is handled',
                  onTap: () => context.push('/privacy'),
                ),
                _ProfileActionTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of use',
                  subtitle: 'Lotzi service terms',
                  onTap: () => context.push('/terms'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _ProfileSessionButton(
              isSignedIn: profileDisplay.isSignedIn,
              onPressed: () {
                if (profileDisplay.isSignedIn) {
                  _signOut(context, ref);
                } else {
                  context.go('/auth');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    unawaited(ref.read(authControllerProvider.notifier).signOut());
    context.go('/auth');
  }
}

class _HostSetupPrewarmEffect extends ConsumerStatefulWidget {
  const _HostSetupPrewarmEffect({required this.authState});

  final AuthState? authState;

  @override
  ConsumerState<_HostSetupPrewarmEffect> createState() =>
      _HostSetupPrewarmEffectState();
}

class _HostSetupPrewarmEffectState
    extends ConsumerState<_HostSetupPrewarmEffect> {
  String? _lastPrewarmKey;

  @override
  void initState() {
    super.initState();
    _schedulePrewarmIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _HostSetupPrewarmEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePrewarmIfNeeded();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  void _schedulePrewarmIfNeeded() {
    final authState = widget.authState;
    if (!_shouldPrewarmHostSetup(authState)) return;

    final profile = authState!.profile;
    final key = [
      authState.user?.id ?? '',
      profile?.hostParkingDraftId ?? '',
      profile?.setupDraftId ?? '',
      profile?.setupStep ?? '',
    ].join('|');
    if (_lastPrewarmKey == key) return;
    _lastPrewarmKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(hostSetupLaunchControllerProvider.notifier)
            .prewarmResumeCandidate(widget.authState),
      );
    });
  }
}

bool _shouldPrewarmHostSetup(AuthState? authState) {
  if (authState?.isAuthenticated != true) return false;
  final profile = authState?.profile;
  if (_isParkingIntent(profile?.intent)) return false;
  final hostDraftId = profile?.hostParkingDraftId?.trim();
  final legacyDraftId = profile?.setupDraftId?.trim();
  return (hostDraftId != null && hostDraftId.isNotEmpty) ||
      (legacyDraftId != null && legacyDraftId.isNotEmpty);
}

bool _isParkingIntent(String? intent) => intent?.trim().toLowerCase() == 'park';

IconData _vehicleIcon(String? type) {
  return switch (type?.trim().toLowerCase()) {
    'bike' => Icons.two_wheeler_rounded,
    'car' => Icons.directions_car_filled_rounded,
    _ => Icons.directions_car_outlined,
  };
}

String _vehicleSummary(UserProfile? profile, List<ProfileVehicle> vehicles) {
  if (vehicles.length > 1) {
    final primary = _primaryVehicle(vehicles);
    final primaryLabel = primary == null
        ? ''
        : ' - ${_vehicleTypeLabel(primary.type)} ${primary.displayRegistration}';
    return '${vehicles.length} vehicles$primaryLabel';
  }
  if (vehicles.length == 1) {
    final vehicle = vehicles.first;
    final makeModel = _makeModelLabel(vehicle.make, vehicle.model);
    final parts = [
      if (vehicle.displayRegistration.isNotEmpty) vehicle.displayRegistration,
      if (makeModel.isNotEmpty) makeModel,
    ];
    if (parts.isEmpty) {
      return '${_vehicleTypeLabel(vehicle.type)} details missing';
    }
    return '${_vehicleTypeLabel(vehicle.type)} - ${parts.join(' - ')}';
  }
  if (profile == null) return 'Add your vehicle for faster bookings';

  final type = _vehicleTypeLabel(profile.vehicleType);
  final registration = IndianVehicleRegistration.formatForDisplay(
    profile.vehicleRegistration ?? '',
  );
  final makeModel = _makeModelLabel(profile.vehicleMake, profile.vehicleModel);
  final parts = [
    if (registration.isNotEmpty) registration,
    if (makeModel.isNotEmpty) makeModel,
  ];

  if (parts.isEmpty) return '$type details missing';
  return '$type - ${parts.join(' - ')}';
}

ProfileVehicle? _primaryVehicle(List<ProfileVehicle> vehicles) {
  for (final vehicle in vehicles) {
    if (vehicle.isPrimary) return vehicle;
  }
  return vehicles.isEmpty ? null : vehicles.first;
}

String _vehicleTypeLabel(String? type) {
  return switch (type?.trim().toLowerCase()) {
    'bike' => 'Bike',
    'car' => 'Car',
    String value when value.isNotEmpty => type!.trim(),
    _ => 'Vehicle',
  };
}

String _makeModelLabel(String? make, String? model) {
  final parts = [
    if (make != null && make.trim().isNotEmpty) make.trim(),
    if (model != null && model.trim().isNotEmpty) model.trim(),
  ];
  return parts.join(' ');
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.avatarUrl,
    required this.displayEmail,
    required this.displayName,
    required this.isLoading,
    required this.isSignedIn,
  });

  final String? avatarUrl;
  final String displayEmail;
  final String displayName;
  final bool isLoading;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    const headerHeight = 158.0;
    const avatarSize = 76.0;

    return SizedBox(
      height: 274,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: headerHeight,
            child: const ColoredBox(
              color: Color(0xFFB9F45E),
              child: _ProfileBrandHeader(),
            ),
          ),
          Positioned(
            left: 24,
            top: headerHeight - (avatarSize / 2),
            child: _ProfileAvatar(
              avatarUrl: avatarUrl,
              displayName: displayName,
              size: avatarSize,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: headerHeight + (avatarSize / 2) + 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              isLoading ? 'Loading profile' : displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0B0B0C),
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF2563EB),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ProfileBadge(
                      icon: isSignedIn
                          ? Icons.verified_user_outlined
                          : Icons.login_rounded,
                      label: isSignedIn ? 'Active' : 'Guest',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  displayEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBrandHeader extends StatelessWidget {
  const _ProfileBrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Lotzi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF0B0B0C),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.displayName,
    required this.size,
  });

  final String? avatarUrl;
  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: ColoredBox(
            color: const Color(0xFF0B0B0C),
            child: url == null || url.isEmpty
                ? _ProfileInitials(displayName: displayName)
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    memCacheHeight:
                        (size * MediaQuery.devicePixelRatioOf(context)).round(),
                    memCacheWidth:
                        (size * MediaQuery.devicePixelRatioOf(context)).round(),
                    placeholder: (_, _) =>
                        _ProfileInitials(displayName: displayName),
                    errorWidget: (_, _, _) =>
                        _ProfileInitials(displayName: displayName),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProfileInitials extends StatelessWidget {
  const _ProfileInitials({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        profileInitials(displayName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFB9F45E), size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.children, required this.title});

  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0B0B0C),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                    indent: 62,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.onTap,
    required this.subtitle,
    required this.title,
    this.onTapDown,
  });

  final IconData icon;
  final GestureTapDownCallback? onTapDown;
  final VoidCallback onTap;
  final String subtitle;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: onTapDown,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(icon, color: const Color(0xFF0B0B0C), size: 19),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B0B0C),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF71717A),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSessionButton extends StatelessWidget {
  const _ProfileSessionButton({
    required this.isSignedIn,
    required this.onPressed,
  });

  final bool isSignedIn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(isSignedIn ? Icons.logout_rounded : Icons.login_rounded),
      label: Text(isSignedIn ? 'Sign out' : 'Sign in'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: isSignedIn
            ? const Color(0xFFB91C1C)
            : const Color(0xFF0B0B0C),
        side: BorderSide(
          color: isSignedIn ? const Color(0xFFB91C1C) : const Color(0xFF0B0B0C),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
