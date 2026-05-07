import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/app_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/address_search_map_picker.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/state_view.dart';
import '../../user_setup/presentation/host_setup_launcher.dart';
import '../domain/owner_parking_repository.dart';
import '../domain/parking_availability.dart';
import '../domain/parking_spot.dart';
import 'owner_parking_controller.dart';
import 'parking_listing_store.dart';
import 'widgets/listing_availability_editor.dart';

class OwnedParkingScreen extends ConsumerStatefulWidget {
  const OwnedParkingScreen({super.key});

  @override
  ConsumerState<OwnedParkingScreen> createState() => _OwnedParkingScreenState();
}

class _OwnedParkingScreenState extends ConsumerState<OwnedParkingScreen> {
  final Set<String> _selectedListingIds = <String>{};
  final Map<String, String> _selectedListingTitles = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final spaces = ref.watch(ownedParkingSpacesProvider);
    final hasSelection = _selectedListingIds.isNotEmpty;

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          'My parking spaces',
          style: TextStyle(
            color: Color(0xFF0B0B0C),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: hasSelection
                ? IconButton(
                    key: const ValueKey('delete-listing'),
                    tooltip: 'Delete selected',
                    onPressed: () => unawaited(_confirmDeleteListings()),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFB91C1C),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('refresh-spaces'),
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(ownedParkingSpacesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
          ),
        ],
      ),
      child: spaces.when(
        loading: () => const StateView(
          title: 'Loading spaces',
          body: 'Checking your active listings.',
          isLoading: true,
        ),
        error: (error, _) => StateView(
          title: 'Could not load spaces',
          body: _errorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownedParkingSpacesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return StateView(
              title: 'No parking spaces yet',
              body: 'Create a parking listing before editing live details.',
              actionLabel: 'Host a space',
              onAction: () => unawaited(startHostSetup(context, ref)),
            );
          }

          ref.watch(
            visibleParkingListingRevisionsProvider(
              parkingListingIdsKey(items.map((spot) => spot.id), maxIds: 12),
            ),
          );

          _clearInvalidSelection(items);

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            itemBuilder: (context, index) {
              final seeded = items[index];
              final live =
                  ref.watch(parkingListingSnapshotProvider(seeded.id))?.spot ??
                  seeded;
              final isDraft = live.status == 'draft';
              final isActive = live.status == 'active';
              final isSelectionMode = _selectedListingIds.isNotEmpty;
              final canTap = isSelectionMode || isDraft || isActive;
              return _OwnedParkingCard(
                isSelected: _selectedListingIds.contains(live.id),
                isSelectionMode: isSelectionMode,
                onLongPress: () => _selectListing(live),
                onTap: canTap ? () => _handleCardTap(live) : null,
                spot: live,
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemCount: items.length,
          );
        },
      ),
    );
  }

  static String _errorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Something went wrong. Please try again.';
  }

  void _handleCardTap(ParkingSpot spot) {
    final isDraft = spot.status == 'draft';
    final isActive = spot.status == 'active';
    if (_selectedListingIds.isNotEmpty) {
      _toggleListingSelection(spot);
      return;
    }
    if (isDraft) {
      unawaited(startHostSetup(context, ref, resumeDraftId: spot.id));
    } else if (isActive) {
      context.push('/profile/my-spaces/${spot.id}/edit');
    }
  }

  void _selectListing(ParkingSpot spot) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedListingIds.add(spot.id);
      _selectedListingTitles[spot.id] = spot.title;
    });
  }

  void _toggleListingSelection(ParkingSpot spot) {
    if (_selectedListingIds.contains(spot.id)) {
      setState(() {
        _selectedListingIds.remove(spot.id);
        _selectedListingTitles.remove(spot.id);
      });
      return;
    }
    _selectListing(spot);
  }

  void _clearInvalidSelection(List<ParkingSpot> items) {
    if (_selectedListingIds.isEmpty) return;
    final validListingIds = {for (final spot in items) spot.id};
    final staleIds = _selectedListingIds.difference(validListingIds);
    if (staleIds.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedListingIds.removeAll(staleIds);
        for (final id in staleIds) {
          _selectedListingTitles.remove(id);
        }
      });
    });
  }

  Future<void> _confirmDeleteListings() async {
    final listingIds = _selectedListingIds.toList(growable: false);
    if (listingIds.isEmpty) return;
    final titles = [
      for (final id in listingIds)
        if ((_selectedListingTitles[id] ?? '').trim().isNotEmpty)
          _selectedListingTitles[id]!.trim(),
    ];
    final isSingle = listingIds.length == 1;
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteListingDialog(
        isSingle: isSingle,
        onDelete: () => _deleteListings(listingIds),
        selectedCount: listingIds.length,
        title: titles.isEmpty ? null : titles.first,
      ),
    );
    if (!mounted) return;
    if (result == true) {
      AppToast.success(
        context,
        isSingle ? 'Listing deleted' : 'Listings deleted',
      );
      return;
    }
    if (result is Object) {
      AppToast.error(context, _errorMessage(result));
    }
  }

  Future<void> _deleteListings(List<String> listingIds) async {
    final controller = ref.read(ownerListingEditorControllerProvider.notifier);
    for (final listingId in listingIds) {
      await controller.deleteListing(listingId);
    }
    if (!mounted) return;
    setState(() {
      _selectedListingIds.clear();
      _selectedListingTitles.clear();
    });
  }
}

class _DeleteListingDialog extends StatefulWidget {
  const _DeleteListingDialog({
    required this.isSingle,
    required this.onDelete,
    required this.selectedCount,
    this.title,
  });

  final bool isSingle;
  final Future<void> Function() onDelete;
  final int selectedCount;
  final String? title;

  @override
  State<_DeleteListingDialog> createState() => _DeleteListingDialogState();
}

class _DeleteListingDialogState extends State<_DeleteListingDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final titleText = widget.isSingle ? 'Delete listing?' : 'Delete listings?';
    final bodyText = widget.isSingle
        ? widget.title == null || widget.title!.trim().isEmpty
              ? 'This removes the selected parking space. This cannot be undone.'
              : 'This removes "${widget.title}" from your parking spaces. This cannot be undone.'
        : 'This removes ${widget.selectedCount} selected parking spaces. This cannot be undone.';
    final deleteLabel = widget.isSingle ? 'Delete' : 'Delete all';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _isDeleting
                  ? const SizedBox(
                      key: ValueKey('delete-spinner'),
                      height: 168,
                      child: Center(
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      key: const ValueKey('delete-content'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          titleText,
                          style: const TextStyle(
                            color: Color(0xFF0B0B0C),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          bodyText,
                          style: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  foregroundColor: const Color(0xFF18181B),
                                  side: const BorderSide(
                                    color: Color(0xFFE4E4E7),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: _delete,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  backgroundColor: const Color(0xFFB91C1C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                                child: Text(deleteLabel),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) Navigator.of(context).pop(error);
    }
  }
}

class _OwnedParkingCard extends StatelessWidget {
  const _OwnedParkingCard({
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.spot,
    this.onLongPress,
  });

  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final ParkingSpot spot;

  @override
  Widget build(BuildContext context) {
    final address = spot.address.isEmpty ? spot.locality : spot.address;
    final isDraft = spot.status == 'draft';
    final isActive = spot.status == 'active';
    return Semantics(
      button: true,
      selected: isSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? const Color(0xFFB91C1C) : Colors.black)
                  .withValues(alpha: isSelected ? 0.14 : 0.06),
              blurRadius: isSelected ? 24 : 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFFB91C1C)
                  : Colors.black.withValues(alpha: 0.08),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onLongPress: onLongPress,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 74),
              padding: const EdgeInsets.fromLTRB(15, 14, 10, 14),
              child: Row(
                children: [
                  if (isSelectionMode) ...[
                    _SelectedListingIndicator(isSelected: isSelected),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0B0B0C),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          address.isEmpty
                              ? _statusDescription(spot.status)
                              : address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ListingStatusBadge(status: spot.status),
                  if (!isSelectionMode && (isDraft || isActive)) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF0B0B0C),
                      size: 26,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusDescription(String status) {
    return switch (status) {
      'draft' => 'Continue setup',
      'pending_review' => 'Submitted for review',
      'rejected' => 'Needs updates',
      'suspended' => 'Temporarily hidden',
      _ => 'Active listing',
    };
  }
}

class _SelectedListingIndicator extends StatelessWidget {
  const _SelectedListingIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFB91C1C) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB91C1C), width: 1.6),
      ),
      child: SizedBox(
        width: 24,
        height: 24,
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
            : null,
      ),
    );
  }
}

class _ListingStatusBadge extends StatelessWidget {
  const _ListingStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'draft' => 'Draft',
      'pending_review' => 'Review',
      'rejected' => 'Rejected',
      'suspended' => 'Suspended',
      _ => 'Active',
    };
    final color = switch (status) {
      'draft' => const Color(0xFF92400E),
      'pending_review' => const Color(0xFF1D4ED8),
      'rejected' => const Color(0xFFB91C1C),
      'suspended' => const Color(0xFFB45309),
      _ => const Color(0xFF047857),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
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

const _fieldTextStyle = TextStyle(
  color: Color(0xFF0B0B0C),
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.2,
  letterSpacing: 0,
);

const _addressAutocompleteDelay = Duration(milliseconds: 350);
const _addressAutocompleteMinLength = 4;

class OwnedParkingEditScreen extends ConsumerWidget {
  const OwnedParkingEditScreen({required this.spotId, super.key});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(parkingListingRevisionSyncProvider(spotId));
    final spot = ref.watch(liveParkingSpotProvider(spotId));

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          'Update listing',
          style: TextStyle(
            color: Color(0xFF0B0B0C),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      child: spot.when(
        loading: () => const StateView(
          title: 'Loading listing',
          body: 'Preparing live listing details.',
          isLoading: true,
        ),
        error: (error, _) => StateView(
          title: 'Could not load listing',
          body: _errorMessage(error),
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
        data: (spot) => _OwnedParkingEditContent(spot: spot),
      ),
    );
  }
}

class _OwnedParkingEditContent extends StatelessWidget {
  const _OwnedParkingEditContent({required this.spot});

  final ParkingSpot spot;

  @override
  Widget build(BuildContext context) {
    final address = _listingAddress(spot);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          spot.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0B0B0C),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF71717A),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        _OwnerEditActionTile(
          icon: Icons.location_on_outlined,
          title: 'Address',
          onTap: () => context.push('/profile/my-spaces/${spot.id}/address'),
        ),
        const SizedBox(height: 12),
        _OwnerEditActionTile(
          icon: Icons.payments_outlined,
          title: 'Pricing and availability',
          onTap: () => context.push('/profile/my-spaces/${spot.id}/pricing'),
        ),
      ],
    );
  }
}

class _OwnerEditActionTile extends StatelessWidget {
  const _OwnerEditActionTile({
    required this.icon,
    required this.onTap,
    required this.title,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(icon, color: const Color(0xFF0B0B0C), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF0B0B0C),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressFormPanel extends StatelessWidget {
  const _AddressFormPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class EditListingAddressScreen extends ConsumerStatefulWidget {
  const EditListingAddressScreen({required this.spotId, super.key});

  final String spotId;

  @override
  ConsumerState<EditListingAddressScreen> createState() =>
      _EditListingAddressScreenState();
}

class _EditListingAddressScreenState
    extends ConsumerState<EditListingAddressScreen> {
  final _searchController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _coordinatesController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  List<ParkingAddressCandidate> _candidates = const [];
  Map<String, Object?>? _rawAddress;
  String? _placeId;
  String _provider = 'manual';
  double _confidence = 1;
  int? _seededVersion;
  Timer? _addressSearchDebounce;
  int _addressSearchToken = 0;
  bool _locating = false;
  bool _searching = false;
  bool _syncingCoordinates = false;

  @override
  void dispose() {
    _addressSearchDebounce?.cancel();
    _searchController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _coordinatesController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(parkingListingRevisionSyncProvider(widget.spotId));
    final spot = ref.watch(liveParkingSpotProvider(widget.spotId));
    final saving = ref.watch(ownerListingEditorControllerProvider).isLoading;

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Edit address'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      child: spot.when(
        loading: () => const StateView(
          title: 'Loading listing',
          body: 'Preparing address fields.',
          isLoading: true,
        ),
        error: (error, _) => StateView(
          title: 'Could not load listing',
          body: _errorMessage(error),
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
        data: (spot) {
          _seed(spot);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
            children: [
              AddressSearchMapPicker<ParkingAddressCandidate>(
                enabled: !saving,
                fallbackLocation: spot.location,
                isLocating: _locating,
                isSearching: _searching,
                location: _coordinatesFromHiddenControllers(),
                onClearSearch: _clearSearch,
                onLocationChanged: _applyMapLocation,
                onSearch: _searchAddress,
                onSearchChanged: _handleSearchQueryChanged,
                onSuggestionSelected: saving ? null : _applyCandidate,
                onUseCurrentLocation: _useCurrentLocation,
                searchController: _searchController,
                searchLabel: 'Search address',
                showSuggestionsAboveMap: true,
                suggestionSubtitleBuilder: (candidate) => candidate.address,
                suggestionTitleBuilder: _candidateTitle,
                suggestions: _candidates,
              ),
              const SizedBox(height: 16),
              _AddressFormPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Full address'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      enabled: !saving,
                      style: _fieldTextStyle,
                      decoration: _inputDecoration(
                        'Street, building, landmark',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TwoColumnFields(
                      left: _FieldSpec(
                        controller: _cityController,
                        label: 'City',
                        hint: 'City',
                      ),
                      right: _FieldSpec(
                        controller: _stateController,
                        label: 'State',
                        hint: 'Tamil Nadu',
                      ),
                      enabled: !saving,
                    ),
                    const SizedBox(height: 14),
                    _Label('PIN code'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _postalController,
                      enabled: !saving,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      keyboardType: TextInputType.number,
                      style: _fieldTextStyle,
                      decoration: _inputDecoration('600001'),
                    ),
                    const SizedBox(height: 14),
                    _Label('Coordinates'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _coordinatesController,
                      keyboardType: TextInputType.text,
                      enabled: !saving,
                      onChanged: _handleCoordinatesChanged,
                      style: _fieldTextStyle,
                      decoration: _inputDecoration('8.712758, 77.421806'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: saving ? null : () => _save(spot),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(saving ? 'Saving' : 'Save address'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B0B0C),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF3F3F46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _seed(ParkingSpot spot) {
    if (_seededVersion == spot.version) return;
    _seededVersion = spot.version;
    _addressController.text = spot.address;
    _stateController.text = _stateFrom(spot);
    _cityController.text = spot.city ?? spot.locality;
    _postalController.text = spot.postalCode ?? '';
    _setCoordinateControllers(spot.location);
    _provider = spot.addressProvider ?? 'manual';
    _confidence = spot.addressConfidence ?? 1;
    _placeId = spot.addressPlaceId;
  }

  void _handleSearchQueryChanged(String value) {
    _addressSearchDebounce?.cancel();
    _addressSearchToken += 1;
    if (_candidates.isNotEmpty || _searching) {
      setState(() {
        _candidates = const [];
        _searching = false;
      });
    }

    final query = value.trim();
    if (query.length < _addressAutocompleteMinLength) {
      return;
    }

    final token = _addressSearchToken;
    _addressSearchDebounce = Timer(_addressAutocompleteDelay, () {
      unawaited(
        _searchAddress(query: query, isAutocomplete: true, token: token),
      );
    });
  }

  Future<void> _searchAddress({
    String? query,
    bool isAutocomplete = false,
    int? token,
  }) async {
    if (!isAutocomplete) _addressSearchDebounce?.cancel();
    final effectiveQuery = (query ?? _searchController.text).trim();
    if (effectiveQuery.length < _addressAutocompleteMinLength) return;
    final searchToken = token ?? ++_addressSearchToken;

    if (!isAutocomplete) FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(ownerListingEditorControllerProvider.notifier)
          .searchAddress(effectiveQuery);
      if (!mounted || searchToken != _addressSearchToken) return;
      setState(() => _candidates = results);
    } catch (error) {
      if (!mounted || searchToken != _addressSearchToken) return;
      if (isAutocomplete) {
        setState(() => _candidates = const []);
      } else {
        _showToast(_errorMessage(error), AppToastVariant.error);
      }
    } finally {
      if (mounted && searchToken == _addressSearchToken) {
        setState(() => _searching = false);
      }
    }
  }

  void _clearSearch() {
    _cancelAddressAutocomplete();
    setState(() {
      _searchController.clear();
      _candidates = const [];
      _searching = false;
    });
  }

  void _clearAddressFields() {
    _cancelAddressAutocomplete();
    _addressController.clear();
    _stateController.clear();
    _cityController.clear();
    _postalController.clear();
    _candidates = const [];
  }

  void _setCoordinateControllers(GeoPoint location) {
    _syncingCoordinates = true;
    _setHiddenCoordinateControllers(location);
    _coordinatesController.text = _coordinateText(location);
    _syncingCoordinates = false;
  }

  void _setHiddenCoordinateControllers(GeoPoint location) {
    _latitudeController.text = location.latitude.toStringAsFixed(6);
    _longitudeController.text = location.longitude.toStringAsFixed(6);
  }

  GeoPoint? _coordinatesFromHiddenControllers() {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null || longitude == null) return null;
    return GeoPoint(latitude: latitude, longitude: longitude);
  }

  void _handleCoordinatesChanged(String value) {
    if (_syncingCoordinates) return;
    final location = _coordinatesFromText(value);
    setState(() {
      _clearAddressFields();
      _provider = 'manual';
      _confidence = location == null ? 0.5 : 0.85;
      _placeId = null;
      _rawAddress = null;
      if (location != null) {
        _setHiddenCoordinateControllers(location);
      }
    });
  }

  void _applyMapLocation(GeoPoint location) {
    final latitude = location.latitude.toStringAsFixed(6);
    final longitude = location.longitude.toStringAsFixed(6);
    if (_latitudeController.text == latitude &&
        _longitudeController.text == longitude) {
      return;
    }
    _cancelAddressAutocomplete();
    setState(() {
      _setCoordinateControllers(location);
      _clearAddressFields();
      _provider = 'manual';
      _confidence = 0.85;
      _placeId = null;
      _rawAddress = null;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    _cancelAddressAutocomplete();
    setState(() => _locating = true);
    try {
      final result = await ref.read(locationServiceProvider).currentLocation();
      final location = result.location;
      if (location == null) {
        if (mounted) {
          _showToast(
            result.error ?? 'Location unavailable',
            AppToastVariant.error,
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _setCoordinateControllers(location);
        _clearAddressFields();
        _provider = 'manual';
        _confidence = result.isFallback ? 0.5 : 0.9;
        _placeId = null;
        _rawAddress = null;
        _candidates = const [];
      });
      _showToast(result.error ?? 'Location updated');
    } catch (error) {
      if (mounted) _showToast(_errorMessage(error), AppToastVariant.error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _applyCandidate(ParkingAddressCandidate candidate) {
    _cancelAddressAutocomplete();
    setState(() {
      _addressController.text = candidate.address;
      _stateController.text = candidate.state?.trim().isNotEmpty == true
          ? candidate.state!.trim()
          : _stateFromRaw(candidate.raw);
      _cityController.text = candidate.city ?? candidate.locality ?? '';
      _postalController.text = candidate.postalCode ?? '';
      _setCoordinateControllers(
        GeoPoint(latitude: candidate.latitude, longitude: candidate.longitude),
      );
      _provider = candidate.provider;
      _confidence = candidate.confidence;
      _placeId = candidate.placeId;
      _rawAddress = candidate.raw;
      _candidates = const [];
    });
  }

  void _cancelAddressAutocomplete() {
    _addressSearchDebounce?.cancel();
    _addressSearchToken += 1;
  }

  Future<void> _save(ParkingSpot spot) async {
    final coordinates =
        _coordinatesFromText(_coordinatesController.text) ??
        _coordinatesFromHiddenControllers();
    if (coordinates == null) {
      _showToast('Check coordinates', AppToastVariant.error);
      return;
    }

    try {
      await ref
          .read(ownerListingEditorControllerProvider.notifier)
          .updateAddress(
            spotId: spot.id,
            update: OwnedListingAddressUpdate(
              address: _addressController.text,
              city: _cityController.text,
              confidence: _confidence,
              expectedVersion: spot.version,
              latitude: coordinates.latitude,
              locality: _stateController.text,
              longitude: coordinates.longitude,
              placeId: _placeId,
              postalCode: _postalController.text,
              provider: _provider,
              raw: _rawAddress,
            ),
          );
      if (mounted) _showToast('Address saved', AppToastVariant.success);
    } catch (error) {
      if (mounted) _showToast(_errorMessage(error), AppToastVariant.error);
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF8F8FA),
    hintText: hint,
    hintStyle: const TextStyle(
      color: Color(0xFFA1A1AA),
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF0B0B0C), width: 1.4),
    ),
  );

  void _showToast(
    String message, [
    AppToastVariant variant = AppToastVariant.info,
  ]) {
    AppToast.show(context, message: message, variant: variant);
  }
}

class EditListingPricingScreen extends ConsumerStatefulWidget {
  const EditListingPricingScreen({required this.spotId, super.key});

  final String spotId;

  @override
  ConsumerState<EditListingPricingScreen> createState() =>
      _EditListingPricingScreenState();
}

class _EditListingPricingScreenState
    extends ConsumerState<EditListingPricingScreen> {
  final _priceController = TextEditingController();
  final _slotsController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  int _startMinute = 8 * 60;
  int _endMinute = 20 * 60;
  bool _skipWeekends = false;
  int? _seededVersion;

  @override
  void dispose() {
    _priceController.dispose();
    _slotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(parkingListingRevisionSyncProvider(widget.spotId));
    final spot = ref.watch(liveParkingSpotProvider(widget.spotId));
    final saving = ref.watch(ownerListingEditorControllerProvider).isLoading;

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          'Edit pricing',
          style: TextStyle(
            color: Color(0xFF0B0B0C),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      child: spot.when(
        loading: () => const StateView(
          title: 'Loading listing',
          body: 'Preparing pricing fields.',
          isLoading: true,
        ),
        error: (error, _) => StateView(
          title: 'Could not load listing',
          body: _errorMessage(error),
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
        data: (spot) {
          _seed(spot);
          final bottomPadding = MediaQuery.paddingOf(context).bottom;
          return ListView(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28 + bottomPadding),
            children: [
              _PricingSummaryCard(
                price: formatHourlyMoney(spot.price, spot.currency),
                slots: spot.slotsAvailable,
                window: _availabilityLabel(spot),
              ),
              const SizedBox(height: 14),
              _EditorSection(
                title: 'Pricing',
                child: _TwoColumnFields(
                  left: _FieldSpec(
                    controller: _priceController,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    keyboardType: TextInputType.number,
                    label: 'Hourly price',
                    hint: '80',
                  ),
                  right: _FieldSpec(
                    controller: _slotsController,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    keyboardType: TextInputType.number,
                    label: 'Slots',
                    hint: '1',
                  ),
                  enabled: !saving,
                ),
              ),
              const SizedBox(height: 14),
              _EditorSection(
                title: 'Availability',
                child: ListingAvailabilityEditor(
                  enabled: !saving,
                  value: ListingAvailabilityValue(
                    dailyEndMinute: _endMinute,
                    dailyStartMinute: _startMinute,
                    fromDate: _fromDate,
                    skipWeekends: _skipWeekends,
                    toDate: _toDate,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _endMinute = value.dailyEndMinute;
                      _fromDate = value.fromDate;
                      _skipWeekends = value.skipWeekends;
                      _startMinute = value.dailyStartMinute;
                      _toDate = value.toDate;
                    });
                  },
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: saving ? null : () => _save(spot),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B0B0C),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF3F3F46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Text(
                          'Save pricing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _seed(ParkingSpot spot) {
    if (_seededVersion == spot.version) return;
    _seededVersion = spot.version;
    _priceController.text = spot.price.toString();
    _slotsController.text = spot.slotsAvailable.toString();
    _fromDate =
        spot.availableFromDate ??
        DateTime(
          spot.availableFrom.year,
          spot.availableFrom.month,
          spot.availableFrom.day,
        );
    _toDate =
        spot.availableToDate ??
        DateTime(
          spot.availableUntil.year,
          spot.availableUntil.month,
          spot.availableUntil.day,
        );
    _skipWeekends = spot.skipWeekends;
    _startMinute = normalizeParkingStartMinute(
      spot.dailyStartMinute ?? parkingMinuteOfDay(spot.availableFrom),
    );
    _endMinute = normalizeParkingEndMinute(
      spot.dailyEndMinute ?? parkingMinuteOfDay(spot.availableUntil),
      startMinute: _startMinute,
    );
  }

  Future<void> _save(ParkingSpot spot) async {
    final price = int.tryParse(_priceController.text.trim());
    final slots = int.tryParse(_slotsController.text.trim());
    final fromDate = _fromDate;
    final toDate = _toDate;
    final savePayload = _pricingSaveLogPayload(
      spot: spot,
      price: price,
      priceText: _priceController.text,
      slots: slots,
      slotsText: _slotsController.text,
      fromDate: fromDate,
      toDate: toDate,
      dailyStartMinute: _startMinute,
      dailyEndMinute: _endMinute,
      skipWeekends: _skipWeekends,
    );
    appLogger.info('owner_pricing_save_tapped', savePayload);

    if (price == null || slots == null || fromDate == null || toDate == null) {
      appLogger.warn('owner_pricing_save_validation_failed', {
        ...savePayload,
        'reason': 'missing_or_invalid_fields',
      });
      _showToast('Complete pricing fields', AppToastVariant.error);
      return;
    }
    if (price < 10 || price > 10000) {
      appLogger.warn('owner_pricing_save_validation_failed', {
        ...savePayload,
        'reason': 'price_out_of_range',
      });
      _showToast('Check hourly price', AppToastVariant.error);
      return;
    }
    if (slots < 1 || slots > 50) {
      appLogger.warn('owner_pricing_save_validation_failed', {
        ...savePayload,
        'reason': 'slots_out_of_range',
      });
      _showToast('Check slot count', AppToastVariant.error);
      return;
    }
    if (toDate.isBefore(fromDate)) {
      appLogger.warn('owner_pricing_save_validation_failed', {
        ...savePayload,
        'reason': 'date_range_invalid',
      });
      _showToast('Check date range', AppToastVariant.error);
      return;
    }
    if (!parkingRangeContainsBookableDay(
      fromDate,
      toDate,
      skipWeekends: _skipWeekends,
    )) {
      appLogger.warn('owner_pricing_save_validation_failed', {
        ...savePayload,
        'reason': 'no_bookable_weekday',
      });
      _showToast('Choose at least one weekday', AppToastVariant.error);
      return;
    }
    if (_endMinute <= _startMinute) {
      appLogger.warn('owner_pricing_save_validation_failed', {
        ...savePayload,
        'reason': 'daily_hours_invalid',
      });
      _showToast('Check daily hours', AppToastVariant.error);
      return;
    }

    try {
      appLogger.info('owner_pricing_save_submitting', savePayload);
      await ref
          .read(ownerListingEditorControllerProvider.notifier)
          .updatePricing(
            spotId: spot.id,
            update: OwnedListingPricingUpdate(
              availableFromDate: fromDate,
              availableToDate: toDate,
              dailyEndMinute: _endMinute,
              dailyStartMinute: _startMinute,
              expectedVersion: spot.version,
              hourlyPrice: price,
              skipWeekends: _skipWeekends,
              slotsCount: slots,
            ),
          );
      appLogger.info('owner_pricing_save_succeeded', savePayload);
      if (mounted) _showToast('Pricing saved', AppToastVariant.success);
    } catch (error) {
      appLogger.error('owner_pricing_save_failed', {
        ...savePayload,
        ..._pricingFailureLogPayload(error),
      }, error);
      if (mounted) _showToast(_errorMessage(error), AppToastVariant.error);
    }
  }

  void _showToast(
    String message, [
    AppToastVariant variant = AppToastVariant.info,
  ]) {
    AppToast.show(context, message: message, variant: variant);
  }
}

class _PricingSummaryCard extends StatelessWidget {
  const _PricingSummaryCard({
    required this.price,
    required this.slots,
    required this.window,
  });

  final String price;
  final int slots;
  final String window;

  @override
  Widget build(BuildContext context) {
    final slotLabel = slots == 1 ? 'slot' : 'slots';
    final scheduleText = window.replaceFirst(', ', '\n');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0C),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live pricing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(label: 'Hourly', value: price),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Capacity',
                    value: '$slots $slotLabel',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: Colors.white.withValues(alpha: 0.74),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scheduleText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE4E4E7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.32,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.child, required this.title});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0B0B0C),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({
    required this.enabled,
    required this.left,
    required this.right,
  });

  final bool enabled;
  final _FieldSpec left;
  final _FieldSpec right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TextInput(spec: left, enabled: enabled),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TextInput(spec: right, enabled: enabled),
        ),
      ],
    );
  }
}

class _FieldSpec {
  const _FieldSpec({
    required this.controller,
    required this.hint,
    required this.label,
    this.inputFormatters,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final String label;
}

class _TextInput extends StatelessWidget {
  const _TextInput({required this.enabled, required this.spec});

  final bool enabled;
  final _FieldSpec spec;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(spec.label),
        const SizedBox(height: 8),
        TextField(
          controller: spec.controller,
          enabled: enabled,
          inputFormatters: spec.inputFormatters,
          keyboardType: spec.keyboardType,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: _fieldTextStyle,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F8FA),
            hintText: spec.hint,
            hintStyle: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF0B0B0C),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    );
  }
}

String _errorMessage(Object error) {
  if (error is AppFailure) return error.message;
  return 'Something went wrong. Please try again.';
}

Map<String, Object?> _pricingSaveLogPayload({
  required ParkingSpot spot,
  required int? price,
  required String priceText,
  required int? slots,
  required String slotsText,
  required DateTime? fromDate,
  required DateTime? toDate,
  required int dailyStartMinute,
  required int dailyEndMinute,
  required bool skipWeekends,
}) {
  return {
    'spotId': spot.id,
    'spotVersion': spot.version,
    'spotRevision': spot.listingRevision,
    'parsedHourlyPrice': price,
    'rawHourlyPrice': priceText.trim(),
    'parsedSlotsCount': slots,
    'rawSlotsCount': slotsText.trim(),
    'availableFromDate': fromDate == null ? null : _dateOnlyForLog(fromDate),
    'availableToDate': toDate == null ? null : _dateOnlyForLog(toDate),
    'dailyStartMinute': dailyStartMinute,
    'dailyEndMinute': dailyEndMinute,
    'skipWeekends': skipWeekends,
  };
}

Map<String, Object?> _pricingFailureLogPayload(Object error) {
  if (error is AppFailure) {
    return {
      'failureCode': error.code,
      'failureMessage': error.message,
      'failureType': error.runtimeType.toString(),
    };
  }
  return {
    'failureCode': null,
    'failureMessage': error.toString(),
    'failureType': error.runtimeType.toString(),
  };
}

String _dateOnlyForLog(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _listingAddress(ParkingSpot spot) {
  final address = spot.address.trim();
  if (address.isNotEmpty) return address;
  final locality = spot.locality.trim();
  if (locality.isNotEmpty) return locality;
  return 'Address not set';
}

String _availabilityLabel(ParkingSpot spot) {
  final dateFormat = DateFormat('d MMM yyyy');
  final startDate = dateFormat.format(
    spot.availableFromDate ?? parkingDateOnly(spot.availableFrom),
  );
  final endDate = dateFormat.format(
    spot.availableToDate ?? parkingDateOnly(spot.availableUntil),
  );
  final startMinute = normalizeParkingStartMinute(
    spot.dailyStartMinute ?? parkingMinuteOfDay(spot.availableFrom),
  );
  final endMinute = normalizeParkingEndMinute(
    spot.dailyEndMinute ?? parkingMinuteOfDay(spot.availableUntil),
    startMinute: startMinute,
  );
  final startTime = parkingMinuteLabel(startMinute);
  final endTime = parkingMinuteLabel(endMinute);
  final weekendLabel = spot.skipWeekends ? ', Except Sat/Sun' : '';
  return '$startDate to $endDate, $startTime - $endTime$weekendLabel';
}

String _candidateTitle(ParkingAddressCandidate candidate) {
  final parts = <String>[
    candidate.city?.trim() ?? '',
    candidate.state?.trim().isNotEmpty == true
        ? candidate.state!.trim()
        : _stateFromRaw(candidate.raw),
    candidate.postalCode?.trim() ?? '',
    'India',
  ].where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.isNotEmpty) return parts.join(', ');
  return candidate.address;
}

String _stateFrom(ParkingSpot spot) {
  final parts = spot.address
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  for (final part in parts.reversed) {
    final normalized = part.toLowerCase();
    if (normalized == 'india') continue;
    if (RegExp(r'^[1-9][0-9]{5}$').hasMatch(part)) continue;
    if (spot.city != null && normalized == spot.city!.toLowerCase()) continue;
    if (normalized == spot.locality.toLowerCase()) continue;
    return part;
  }
  return spot.locality;
}

String _stateFromRaw(Map<String, Object?>? raw) {
  final value = _firstNestedString(raw, const [
    ['address', 'state'],
    ['address', 'region'],
    ['address', 'state_district'],
    ['state'],
    ['region'],
  ]);
  return value ?? '';
}

String? _firstNestedString(
  Map<String, Object?>? raw,
  List<List<String>> paths,
) {
  if (raw == null) return null;
  for (final path in paths) {
    Object? cursor = raw;
    for (final segment in path) {
      if (cursor is! Map) {
        cursor = null;
        break;
      }
      cursor = cursor[segment];
    }
    final value = cursor?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

GeoPoint? _coordinatesFromText(String value) {
  final parts = value
      .split(RegExp(r'[,\s]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length < 2) return null;
  final latitude = double.tryParse(parts[0]);
  final longitude = double.tryParse(parts[1]);
  if (latitude == null || longitude == null) return null;
  if (latitude < -85 || latitude > 85 || longitude < -180 || longitude > 180) {
    return null;
  }
  return GeoPoint(latitude: latitude, longitude: longitude);
}

String _coordinateText(GeoPoint location) {
  return '${location.latitude.toStringAsFixed(6)}, '
      '${location.longitude.toStringAsFixed(6)}';
}
