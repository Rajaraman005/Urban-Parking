import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../user_setup/presentation/user_setup_controller.dart';
import '../data/profile_vehicle_repository.dart';
import '../domain/profile_vehicle.dart';
import 'vehicle_details_form.dart';

class VehicleDetailsScreen extends ConsumerWidget {
  const VehicleDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authValue = ref.watch(authControllerProvider);
    final profile = authValue.value?.profile;
    final vehiclesValue = ref.watch(profileVehiclesProvider);
    final fallbackVehicles = profileVehiclesFromProfile(profile);
    final vehicles = _sortedVehicles(vehiclesValue.value ?? fallbackVehicles);

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      safeAreaBackgroundColor: const Color(0xFFB9F45E),
      resizeToAvoidBottomInset: false,
      child: Column(
        children: [
          _VehicleDetailsHeader(
            title: 'Vehicle details',
            onAddVehicle: () => context.push('/profile/vehicle-details/add'),
            onBack: () => _returnToProfile(context),
          ),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF0B0B0C),
              onRefresh: () async {
                ref.invalidate(profileVehiclesProvider);
                await ref.read(profileVehiclesProvider.future);
              },
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  if (vehiclesValue.isLoading) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 16),
                  ],
                  if (vehicles.isEmpty)
                    _VehicleEmptyState(
                      onAddVehicle: () =>
                          context.push('/profile/vehicle-details/add'),
                    )
                  else
                    for (var index = 0; index < vehicles.length; index++) ...[
                      _VehicleOverviewCard(
                        key: ValueKey('vehicle-card-${vehicles[index].id}'),
                        vehicle: vehicles[index],
                        onTap: () => context.push(
                          '/profile/vehicle-details/${Uri.encodeComponent(vehicles[index].id)}',
                        ),
                        onLongPress: () =>
                            _showVehicleActions(context, ref, vehicles[index]),
                      ),
                      if (index != vehicles.length - 1)
                        const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _VehicleCardAction { delete, setPrimary }

Future<void> _showVehicleActions(
  BuildContext context,
  WidgetRef ref,
  ProfileVehicle vehicle,
) async {
  final action = await showDialog<_VehicleCardAction>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => _VehicleActionSheet(vehicle: vehicle),
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case _VehicleCardAction.setPrimary:
      await _setPrimaryVehicle(context, ref, vehicle);
    case _VehicleCardAction.delete:
      await _deleteVehicle(context, ref, vehicle);
  }
}

Future<void> _setPrimaryVehicle(
  BuildContext context,
  WidgetRef ref,
  ProfileVehicle vehicle,
) async {
  if (vehicle.isPrimary) {
    AppToast.info(context, 'Already primary');
    return;
  }

  try {
    final primary = await ref
        .read(profileVehicleRepositoryProvider)
        .setPrimaryVehicle(vehicle);
    _syncPrimaryVehicle(ref, primary);
    ref.invalidate(profileVehiclesProvider);
    if (context.mounted) {
      AppToast.success(context, 'Primary vehicle updated');
    }
  } catch (error) {
    if (context.mounted) {
      AppToast.error(context, _vehicleActionError(error));
    }
  }
}

Future<void> _deleteVehicle(
  BuildContext context,
  WidgetRef ref,
  ProfileVehicle vehicle,
) async {
  try {
    final nextPrimary = await ref
        .read(profileVehicleRepositoryProvider)
        .deleteVehicle(vehicle);
    if (vehicle.isPrimary) {
      _syncPrimaryVehicle(ref, nextPrimary);
    }
    ref.invalidate(profileVehiclesProvider);
    if (context.mounted) {
      AppToast.success(context, 'Vehicle deleted');
    }
  } catch (error) {
    if (context.mounted) {
      AppToast.error(context, _vehicleActionError(error));
    }
  }
}

void _syncPrimaryVehicle(WidgetRef ref, ProfileVehicle? vehicle) {
  final current = ref.read(authControllerProvider).value;
  final profile = current?.profile;
  if (profile == null) return;

  ref
      .read(authControllerProvider.notifier)
      .replaceProfile(
        profile.copyWith(
          vehicleMake: vehicle?.make,
          clearVehicleMake: vehicle == null || vehicle.make == null,
          vehicleModel: vehicle?.model,
          clearVehicleModel: vehicle == null || vehicle.model == null,
          vehicleRegistration: vehicle?.registration,
          clearVehicleRegistration: vehicle == null,
          vehicleType: vehicle?.type,
          clearVehicleType: vehicle == null,
          version: profile.version + 1,
        ),
      );
}

String _vehicleActionError(Object error) {
  if (error is AppFailure) return error.message;
  return 'Could not update vehicle. Please try again.';
}

class VehicleDetailsFormScreen extends ConsumerStatefulWidget {
  const VehicleDetailsFormScreen({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  ConsumerState<VehicleDetailsFormScreen> createState() =>
      _VehicleDetailsFormScreenState();
}

class _VehicleDetailsFormScreenState
    extends ConsumerState<VehicleDetailsFormScreen> {
  final _formKey = GlobalKey<VehicleDetailsFormState>();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final authValue = ref.watch(authControllerProvider);
    final profile = authValue.value?.profile;
    final vehiclesValue = ref.watch(profileVehiclesProvider);
    final fallbackVehicles = profileVehiclesFromProfile(profile);
    final vehicles = _sortedVehicles(vehiclesValue.value ?? fallbackVehicles);
    final vehicleId = widget.vehicleId;
    final isNewVehicle = vehicleId == null;
    final selectedVehicle = isNewVehicle
        ? null
        : _vehicleById(vehicles, vehicleId);
    final syncPrimaryProfile =
        selectedVehicle?.isPrimary ?? (isNewVehicle && vehicles.isEmpty);
    final waitingForVehicle =
        !isNewVehicle && selectedVehicle == null && vehiclesValue.isLoading;
    final missingVehicle =
        !isNewVehicle && selectedVehicle == null && !vehiclesValue.isLoading;

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      safeAreaBackgroundColor: const Color(0xFFB9F45E),
      resizeToAvoidBottomInset: false,
      child: Stack(
        children: [
          Column(
            children: [
              _VehicleDetailsHeader(
                title: isNewVehicle ? 'Add vehicle' : 'Vehicle details',
                onBack: () => _returnToVehicleList(context),
              ),
              Expanded(
                child: waitingForVehicle
                    ? const _VehicleLoadingState()
                    : missingVehicle
                    ? _VehicleMissingState(
                        onBack: () => _returnToVehicleList(context),
                      )
                    : SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
                        child: VehicleDetailsForm(
                          key: _formKey,
                          initialMake: selectedVehicle?.make,
                          initialModel: selectedVehicle?.model,
                          initialRegistration: selectedVehicle?.registration,
                          initialType: selectedVehicle?.type,
                          onSavingChanged: (saving) {
                            if (mounted) {
                              setState(() => _saving = saving);
                            }
                          },
                          savedVehicles: vehicles,
                          savedVehiclesLoading: vehiclesValue.isLoading,
                          showSavedVehicles: false,
                          showSaveButton: false,
                          onSave:
                              ({
                                String? vehicleMake,
                                String? vehicleModel,
                                required String vehicleRegistration,
                                required String vehicleType,
                              }) async {
                                await ref
                                    .read(userSetupControllerProvider.notifier)
                                    .saveVehicleDetails(
                                      createNew: isNewVehicle,
                                      previousVehicleRegistration:
                                          selectedVehicle?.registration,
                                      syncPrimaryProfile: syncPrimaryProfile,
                                      vehicleId: selectedVehicle?.id,
                                      vehicleMake: vehicleMake,
                                      vehicleModel: vehicleModel,
                                      vehicleRegistration: vehicleRegistration,
                                      vehicleType: vehicleType,
                                    );
                                ref.invalidate(profileVehiclesProvider);
                                if (context.mounted) {
                                  AppToast.show(
                                    context,
                                    message: 'Vehicle details saved',
                                    variant: AppToastVariant.success,
                                  );
                                  _returnToVehicleList(context);
                                }
                              },
                        ),
                      ),
              ),
            ],
          ),
          if (!waitingForVehicle && !missingVehicle)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _VehicleSaveBar(
                saving: _saving,
                onSave: () => _formKey.currentState?.save(),
              ),
            ),
        ],
      ),
    );
  }
}

List<ProfileVehicle> _sortedVehicles(List<ProfileVehicle> vehicles) {
  final sorted = [...vehicles];
  sorted.sort((a, b) {
    if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
    return a.displayRegistration.compareTo(b.displayRegistration);
  });
  return sorted;
}

ProfileVehicle? _vehicleById(List<ProfileVehicle> vehicles, String id) {
  final decodedId = _decodePathValue(id);
  for (final vehicle in vehicles) {
    if (vehicle.id == id || vehicle.id == decodedId) return vehicle;
  }
  return null;
}

String _decodePathValue(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

void _returnToProfile(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/profile');
  }
}

void _returnToVehicleList(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/profile/vehicle-details');
  }
}

class _VehicleDetailsHeader extends StatelessWidget {
  const _VehicleDetailsHeader({
    required this.onBack,
    required this.title,
    this.onAddVehicle,
  });

  final VoidCallback? onAddVehicle;
  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFB9F45E),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0B0B0C),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0B0B0C),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (onAddVehicle == null)
              const SizedBox(width: 50)
            else ...[
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Add vehicle',
                onPressed: onAddVehicle,
                icon: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF0B0B0C),
                  size: 28,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _VehicleOverviewCard extends StatelessWidget {
  const _VehicleOverviewCard({
    required this.onTap,
    required this.onLongPress,
    required this.vehicle,
    super.key,
  });

  final VoidCallback onLongPress;
  final VoidCallback onTap;
  final ProfileVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final makeModel = _makeModelLabel(vehicle.make, vehicle.model);

    return Material(
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFB9F45E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Icon(
                    _vehicleIcon(vehicle.type),
                    color: const Color(0xFF0B0B0C),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _vehicleTypeLabel(vehicle.type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0B0B0C),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (vehicle.isPrimary) ...[
                          const SizedBox(width: 8),
                          const _PrimaryVehicleBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      vehicle.displayRegistration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B0B0C),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    if (makeModel.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        makeModel,
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF71717A),
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleActionSheet extends StatelessWidget {
  const _VehicleActionSheet({required this.vehicle});

  final ProfileVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final makeModel = _makeModelLabel(vehicle.make, vehicle.model);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFB9F45E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          _vehicleIcon(vehicle.type),
                          color: const Color(0xFF0B0B0C),
                          size: 23,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicleTypeLabel(vehicle.type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0B0B0C),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            vehicle.displayRegistration,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0B0B0C),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                          if (makeModel.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              makeModel,
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _VehicleSheetAction(
                  enabled: !vehicle.isPrimary,
                  icon: Icons.star_border_rounded,
                  title: 'Set as primary',
                  subtitle: vehicle.isPrimary
                      ? 'This vehicle is already primary'
                      : 'Use this vehicle by default',
                  onTap: () =>
                      Navigator.of(context).pop(_VehicleCardAction.setPrimary),
                ),
                const SizedBox(height: 8),
                _VehicleSheetAction(
                  destructive: true,
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete vehicle',
                  subtitle: vehicle.isPrimary
                      ? 'The next vehicle becomes primary'
                      : 'Remove this saved vehicle',
                  onTap: () =>
                      Navigator.of(context).pop(_VehicleCardAction.delete),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleSheetAction extends StatelessWidget {
  const _VehicleSheetAction({
    required this.icon,
    required this.onTap,
    required this.subtitle,
    required this.title,
    this.destructive = false,
    this.enabled = true,
  });

  final bool destructive;
  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;
  final String subtitle;
  final String title;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFB42318)
        : const Color(0xFF0B0B0C);
    final effectiveColor = enabled ? color : const Color(0xFF9CA3AF);

    return Material(
      color: destructive ? const Color(0xFFFFF1F0) : const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Icon(icon, color: effectiveColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: effectiveColor,
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
                      style: TextStyle(
                        color: enabled
                            ? const Color(0xFF71717A)
                            : const Color(0xFFA1A1AA),
                        fontSize: 12,
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
        ),
      ),
    );
  }
}

class _VehicleEmptyState extends StatelessWidget {
  const _VehicleEmptyState({required this.onAddVehicle});

  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFB9F45E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const SizedBox(
                width: 54,
                height: 54,
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: Color(0xFF0B0B0C),
                  size: 25,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No vehicles added',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF0B0B0C),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddVehicle,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add vehicle'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B0B0C),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleLoadingState extends StatelessWidget {
  const _VehicleLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF0B0B0C)),
    );
  }
}

class _VehicleMissingState extends StatelessWidget {
  const _VehicleMissingState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Material(
          color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE4E4E7)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFB42318),
                  size: 28,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vehicle not found',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF0B0B0C),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0B0B0C),
                    side: const BorderSide(color: Color(0xFF0B0B0C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Back to vehicles'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryVehicleBadge extends StatelessWidget {
  const _PrimaryVehicleBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          'Primary',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
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

class _VehicleSaveBar extends StatelessWidget {
  const _VehicleSaveBar({required this.onSave, required this.saving});

  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F6F8),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFF0B0B0C),
              disabledBackgroundColor: const Color(0xFF0B0B0C),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.3,
                    ),
                  )
                : const Text(
                    'Save vehicle',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

IconData _vehicleIcon(String? type) {
  return switch (type?.trim().toLowerCase()) {
    'bike' => Icons.two_wheeler_rounded,
    'car' => Icons.directions_car_filled_rounded,
    _ => Icons.directions_car_outlined,
  };
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
