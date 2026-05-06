import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/app_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/state_view.dart';
import '../domain/owner_parking_repository.dart';
import '../domain/parking_spot.dart';
import 'owner_parking_controller.dart';
import 'parking_listing_store.dart';

class OwnedParkingScreen extends ConsumerWidget {
  const OwnedParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(ownedParkingSpacesProvider);

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('My parking spaces'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(ownedParkingSpacesProvider),
            icon: const Icon(Icons.refresh_rounded),
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
              title: 'No active spaces yet',
              body:
                  'Create or activate a parking listing before editing live details.',
              actionLabel: 'Host a space',
              onAction: () => context.push('/setup/host-basics'),
            );
          }

          ref.watch(
            visibleParkingListingRevisionsProvider(
              parkingListingIdsKey(items.map((spot) => spot.id), maxIds: 12),
            ),
          );

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            itemBuilder: (context, index) {
              final seeded = items[index];
              final live =
                  ref.watch(parkingListingSnapshotProvider(seeded.id))?.spot ??
                  seeded;
              return _OwnedParkingCard(spot: live);
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
}

class _OwnedParkingCard extends StatelessWidget {
  const _OwnedParkingCard({required this.spot});

  final ParkingSpot spot;

  @override
  Widget build(BuildContext context) {
    final address = spot.address.isEmpty ? spot.locality : spot.address;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/profile/my-spaces/${spot.id}/edit'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
            child: Row(
              children: [
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
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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

const _fieldTextStyle = TextStyle(
  color: Color(0xFF0B0B0C),
  fontSize: 16,
  fontWeight: FontWeight.w800,
  height: 1.2,
  letterSpacing: 0,
);

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
      appBar: AppBar(title: const Text('Update listing')),
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
    final price = formatHourlyMoney(spot.price, spot.currency);
    final slotLabel = spot.slotsAvailable == 1 ? 'slot' : 'slots';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          spot.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0B0B0C),
            fontSize: 26,
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        _OwnerEditActionTile(
          icon: Icons.location_on_outlined,
          title: 'Address',
          value: address,
          onTap: () => context.push('/profile/my-spaces/${spot.id}/address'),
        ),
        const SizedBox(height: 12),
        _OwnerEditActionTile(
          icon: Icons.payments_outlined,
          title: 'Pricing and availability',
          value:
              '$price - ${spot.slotsAvailable} $slotLabel\n${_availabilityLabel(spot)}',
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
    required this.value,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String title;
  final String value;

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(icon, color: const Color(0xFF0B0B0C), size: 21),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
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

class _AddressSearchBar extends StatelessWidget {
  const _AddressSearchBar({
    required this.controller,
    required this.enabled,
    required this.isSearching,
    required this.onClear,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSearching;
  final VoidCallback onClear;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final canSubmit = enabled && !isSearching;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          return SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF71717A),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    textInputAction: TextInputAction.search,
                    onSubmitted: canSubmit && value.text.trim().isNotEmpty
                        ? (_) => onSearch()
                        : null,
                    style: _fieldTextStyle.copyWith(fontSize: 15),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      hintText: 'Search address',
                      hintStyle: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: hasText
                      ? Semantics(
                          key: const ValueKey('clear-search'),
                          button: true,
                          label: 'Clear search',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: enabled ? onClear : null,
                            child: const SizedBox(
                              width: 42,
                              height: 52,
                              child: Icon(
                                Icons.close_rounded,
                                color: Color(0xFF71717A),
                                size: 20,
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('empty-search-action'),
                          width: 10,
                          height: 52,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddressMapPreview extends StatefulWidget {
  const _AddressMapPreview({
    required this.fallback,
    required this.isLocating,
    required this.latitudeController,
    required this.longitudeController,
    required this.onLocationChanged,
    required this.onUseCurrentLocation,
  });

  final GeoPoint fallback;
  final bool isLocating;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final ValueChanged<GeoPoint> onLocationChanged;
  final VoidCallback onUseCurrentLocation;

  @override
  State<_AddressMapPreview> createState() => _AddressMapPreviewState();
}

class _AddressMapPreviewState extends State<_AddressMapPreview> {
  final _mapController = MapController();
  late GeoPoint _cameraTarget;
  double _zoom = 16;
  bool _mapReady = false;
  bool _updatingFromMap = false;

  @override
  void initState() {
    super.initState();
    _cameraTarget = _controllerLocation();
    widget.latitudeController.addListener(_syncCameraFromText);
    widget.longitudeController.addListener(_syncCameraFromText);
  }

  @override
  void didUpdateWidget(covariant _AddressMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitudeController != widget.latitudeController) {
      oldWidget.latitudeController.removeListener(_syncCameraFromText);
      widget.latitudeController.addListener(_syncCameraFromText);
    }
    if (oldWidget.longitudeController != widget.longitudeController) {
      oldWidget.longitudeController.removeListener(_syncCameraFromText);
      widget.longitudeController.addListener(_syncCameraFromText);
    }
    _syncCameraFromText();
  }

  @override
  void dispose() {
    widget.latitudeController.removeListener(_syncCameraFromText);
    widget.longitudeController.removeListener(_syncCameraFromText);
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 230,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _latLng(_cameraTarget),
                  initialZoom: 16,
                  maxZoom: 19,
                  minZoom: 4,
                  onMapReady: () {
                    _mapReady = true;
                  },
                  onMapEvent: (event) {
                    if (event is MapEventMoveEnd) {
                      _cameraTarget = _geoPoint(event.camera.center);
                      _commitCameraTarget();
                    }
                  },
                  onPositionChanged: (camera, _) {
                    _cameraTarget = _geoPoint(camera.center);
                    _zoom = camera.zoom;
                  },
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchMove |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.flingAnimation,
                  ),
                  keepAlive: true,
                  backgroundColor: const Color(0xFFEDEFF3),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.urbanparking.india',
                    maxZoom: 19,
                  ),
                ],
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x08000000),
                        Colors.transparent,
                        Color(0x12000000),
                      ],
                    ),
                  ),
                ),
              ),
              const Center(child: _FloatingMapPin()),
              const Positioned(
                left: 10,
                bottom: 10,
                child: _OsmAttributionPill(),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _MapGpsControl(
                  isLoading: widget.isLocating,
                  onTap: widget.onUseCurrentLocation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  GeoPoint _controllerLocation() => _mapLocationFrom(
    fallback: widget.fallback,
    latitudeText: widget.latitudeController.text,
    longitudeText: widget.longitudeController.text,
  );

  void _syncCameraFromText() {
    if (_updatingFromMap) return;
    final next = _controllerLocation();
    if (!_hasMeaningfullyMoved(next, _cameraTarget)) return;
    _cameraTarget = next;
    if (mounted) setState(() {});
    if (_mapReady) {
      _mapController.move(_latLng(next), _zoom);
    }
  }

  void _commitCameraTarget() {
    _updatingFromMap = true;
    widget.onLocationChanged(_cameraTarget);
    _updatingFromMap = false;
  }

  bool _hasMeaningfullyMoved(GeoPoint next, GeoPoint current) {
    return (next.latitude - current.latitude).abs() > 0.000001 ||
        (next.longitude - current.longitude).abs() > 0.000001;
  }

  GeoPoint _geoPoint(LatLng point) {
    return GeoPoint(latitude: point.latitude, longitude: point.longitude);
  }

  LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);
}

class _OsmAttributionPill extends StatelessWidget {
  const _OsmAttributionPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'OpenStreetMap',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _FloatingMapPin extends StatelessWidget {
  const _FloatingMapPin();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -15),
      child: Icon(
        Icons.location_on_rounded,
        color: Colors.black,
        size: 40,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
    );
  }
}

class _MapGpsControl extends StatelessWidget {
  const _MapGpsControl({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Use current location',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Color(0xFF0B0B0C),
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFF0B0B0C),
                        size: 21,
                      ),
              ),
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
  bool _locating = false;
  bool _searching = false;
  bool _syncingCoordinates = false;

  @override
  void dispose() {
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
              _AddressSearchBar(
                controller: _searchController,
                enabled: !saving && !_searching,
                isSearching: _searching,
                onClear: _clearSearch,
                onSearch: _searchAddress,
              ),
              if (_candidates.isNotEmpty) ...[
                const SizedBox(height: 8),
                _AddressSearchResultsPanel(
                  candidates: _candidates,
                  onSelect: saving ? null : _applyCandidate,
                ),
              ],
              const SizedBox(height: 12),
              _AddressMapPreview(
                fallback: spot.location,
                isLocating: _locating,
                latitudeController: _latitudeController,
                longitudeController: _longitudeController,
                onLocationChanged: _applyMapLocation,
                onUseCurrentLocation: _useCurrentLocation,
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

  Future<void> _searchAddress() async {
    if (_searchController.text.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(ownerListingEditorControllerProvider.notifier)
          .searchAddress(_searchController.text);
      if (mounted) {
        setState(() => _candidates = results);
      }
    } catch (error) {
      if (mounted) _showToast(_errorMessage(error), AppToastVariant.error);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _candidates = const [];
    });
  }

  void _clearAddressFields() {
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
    });
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
      appBar: AppBar(title: const Text('Edit pricing')),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DateTile(
                            label: 'From date',
                            value: _fromDate,
                            onTap: saving
                                ? null
                                : () => _pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateTile(
                            label: 'To date',
                            value: _toDate,
                            onTap: saving
                                ? null
                                : () => _pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeTile(
                            label: 'Daily start',
                            value: _startMinute,
                            onTap: saving
                                ? null
                                : () => _pickMinute(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeTile(
                            label: 'Daily end',
                            value: _endMinute,
                            onTap: saving
                                ? null
                                : () => _pickMinute(isStart: false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _AvailabilityPreview(
                text:
                    '${_dateRangeLabel(_fromDate, _toDate)} - '
                    '${_minuteLabel(_startMinute)} to ${_minuteLabel(_endMinute)}',
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 56,
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
                  label: Text(
                    saving ? 'Saving' : 'Save pricing',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
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
    _startMinute = _normalizeStartMinute(
      spot.dailyStartMinute ?? _minuteOfDay(spot.availableFrom),
    );
    _endMinute = _normalizeEndMinute(
      spot.dailyEndMinute ?? _minuteOfDay(spot.availableUntil),
      startMinute: _startMinute,
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = isStart ? _fromDate : _toDate;
    final firstAllowed = isStart
        ? today
        : _fromDate == null || _fromDate!.isBefore(today)
        ? today
        : _fromDate!;
    final initialDate = initial == null || initial.isBefore(firstAllowed)
        ? firstAllowed
        : initial;
    final picked = await showDatePicker(
      context: context,
      firstDate: firstAllowed,
      initialDate: initialDate,
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _fromDate = picked;
        if (_toDate == null || _toDate!.isBefore(picked)) {
          _toDate = picked;
        }
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _pickMinute({required bool isStart}) async {
    final minMinute = isStart ? 0 : _startMinute + 30;
    final maxMinute = isStart ? 1410 : 1440;
    final current = isStart
        ? _startMinute
        : _normalizeEndMinute(_endMinute, startMinute: _startMinute);
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MinutePickerSheet(
        currentValue: current,
        label: isStart ? 'Daily start' : 'Daily end',
        maxMinute: maxMinute,
        minMinute: minMinute,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startMinute = _normalizeStartMinute(picked);
        if (_endMinute <= _startMinute) {
          _endMinute = (_startMinute + 30).clamp(30, 1440).toInt();
        }
      } else {
        _endMinute = _normalizeEndMinute(picked, startMinute: _startMinute);
      }
    });
  }

  Future<void> _save(ParkingSpot spot) async {
    final price = int.tryParse(_priceController.text.trim());
    final slots = int.tryParse(_slotsController.text.trim());
    final fromDate = _fromDate;
    final toDate = _toDate;
    if (price == null || slots == null || fromDate == null || toDate == null) {
      _showToast('Complete pricing fields', AppToastVariant.error);
      return;
    }
    if (price < 10 || price > 10000) {
      _showToast('Check hourly price', AppToastVariant.error);
      return;
    }
    if (slots < 1 || slots > 50) {
      _showToast('Check slot count', AppToastVariant.error);
      return;
    }
    if (toDate.isBefore(fromDate)) {
      _showToast('Check date range', AppToastVariant.error);
      return;
    }
    if (_endMinute <= _startMinute) {
      _showToast('Check daily hours', AppToastVariant.error);
      return;
    }

    try {
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
              slotsCount: slots,
            ),
          );
      if (mounted) _showToast('Pricing saved', AppToastVariant.success);
    } catch (error) {
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live pricing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFFE4E4E7),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    window,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE4E4E7),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w900,
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

class _AvailabilityPreview extends StatelessWidget {
  const _AvailabilityPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFFDF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB7EAD4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            const Icon(
              Icons.published_with_changes_rounded,
              color: Color(0xFF047857),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF065F46),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressSearchResultsPanel extends StatelessWidget {
  const _AddressSearchResultsPanel({
    required this.candidates,
    required this.onSelect,
  });

  final List<ParkingAddressCandidate> candidates;
  final ValueChanged<ParkingAddressCandidate>? onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var index = 0; index < candidates.length; index++) ...[
              _AddressCandidateRow(
                candidate: candidates[index],
                onTap: onSelect == null
                    ? null
                    : () => onSelect!(candidates[index]),
              ),
              if (index != candidates.length - 1)
                Divider(
                  height: 1,
                  indent: 48,
                  endIndent: 14,
                  color: Colors.black.withValues(alpha: 0.06),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddressCandidateRow extends StatelessWidget {
  const _AddressCandidateRow({required this.candidate, required this.onTap});

  final ParkingAddressCandidate candidate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF0B0B0C),
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _candidateTitle(candidate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0B0B0C),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.north_west_rounded,
                color: Color(0xFFA1A1AA),
                size: 16,
              ),
            ],
          ),
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
          style: _fieldTextStyle,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F8FA),
            hintText: spec.hint,
            hintStyle: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
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
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.onTap,
    required this.value,
  });

  final String label;
  final VoidCallback? onTap;
  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(label),
              const SizedBox(height: 8),
              Text(
                value == null
                    ? 'Choose date'
                    : DateFormat('d MMM yyyy').format(value!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0B0B0C),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.onTap,
    required this.value,
  });

  final String label;
  final VoidCallback? onTap;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(label),
                    const SizedBox(height: 8),
                    Text(
                      _minuteLabel(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B0B0C),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF71717A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinutePickerSheet extends StatelessWidget {
  const _MinutePickerSheet({
    required this.currentValue,
    required this.label,
    required this.maxMinute,
    required this.minMinute,
  });

  final int currentValue;
  final String label;
  final int maxMinute;
  final int minMinute;

  @override
  Widget build(BuildContext context) {
    final options = [
      for (var minute = minMinute; minute <= maxMinute; minute += 30) minute,
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E4E7),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFF0B0B0C),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
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
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final value = options[index];
                      final selected = value == currentValue;
                      return Material(
                        color: selected
                            ? const Color(0xFF0B0B0C)
                            : const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).pop(value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _minuteLabel(value),
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF0B0B0C),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _errorMessage(Object error) {
  if (error is AppFailure) return error.message;
  return 'Something went wrong. Please try again.';
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
    spot.availableFromDate ?? _dateOnly(spot.availableFrom),
  );
  final endDate = dateFormat.format(
    spot.availableToDate ?? _dateOnly(spot.availableUntil),
  );
  final startMinute = _normalizeStartMinute(
    spot.dailyStartMinute ?? _minuteOfDay(spot.availableFrom),
  );
  final endMinute = _normalizeEndMinute(
    spot.dailyEndMinute ?? _minuteOfDay(spot.availableUntil),
    startMinute: startMinute,
  );
  final startTime = _minuteLabel(startMinute);
  final endTime = _minuteLabel(endMinute);
  return '$startDate to $endDate, $startTime-$endTime';
}

String _dateRangeLabel(DateTime? fromDate, DateTime? toDate) {
  if (fromDate == null || toDate == null) return 'Choose dates';
  final dateFormat = DateFormat('d MMM yyyy');
  return '${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _minuteOfDay(DateTime value) => value.hour * 60 + value.minute;

int _normalizeStartMinute(int minute) {
  final rounded = (minute ~/ 30) * 30;
  return rounded.clamp(0, 1410).toInt();
}

int _normalizeEndMinute(int minute, {required int startMinute}) {
  final rounded = ((minute + 29) ~/ 30) * 30;
  final clamped = rounded.clamp(30, 1440).toInt();
  if (clamped > startMinute) return clamped;
  return (startMinute + 30).clamp(30, 1440).toInt();
}

String _minuteLabel(int minute) {
  if (minute >= 24 * 60) return '12:00 AM';
  final safeMinute = minute.clamp(0, 1410).toInt();
  final date = DateTime(2026, 1, 1, safeMinute ~/ 60, safeMinute % 60);
  return DateFormat('h:mm a').format(date);
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

GeoPoint _mapLocationFrom({
  required GeoPoint fallback,
  required String latitudeText,
  required String longitudeText,
}) {
  final latitude = double.tryParse(latitudeText.trim());
  final longitude = double.tryParse(longitudeText.trim());
  if (latitude == null || longitude == null) return fallback;
  if (latitude < -85 || latitude > 85 || longitude < -180 || longitude > 180) {
    return fallback;
  }
  return GeoPoint(latitude: latitude, longitude: longitude);
}
