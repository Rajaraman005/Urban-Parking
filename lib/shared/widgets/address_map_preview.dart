import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/geo_discovery/geo_types.dart';

class AddressMapPreview extends StatefulWidget {
  const AddressMapPreview({
    required this.fallback,
    required this.isLocating,
    required this.onLocationChanged,
    required this.onUseCurrentLocation,
    super.key,
    this.height = 230,
    this.location,
  });

  final GeoPoint fallback;
  final double height;
  final bool isLocating;
  final GeoPoint? location;
  final ValueChanged<GeoPoint> onLocationChanged;
  final VoidCallback onUseCurrentLocation;

  @override
  State<AddressMapPreview> createState() => _AddressMapPreviewState();
}

class _AddressMapPreviewState extends State<AddressMapPreview> {
  final _mapController = MapController();
  late GeoPoint _cameraTarget;
  double _zoom = 16;
  bool _mapReady = false;
  bool _updatingFromMap = false;

  @override
  void initState() {
    super.initState();
    _cameraTarget = _effectiveLocation;
  }

  @override
  void didUpdateWidget(covariant AddressMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_updatingFromMap) return;
    final next = _effectiveLocation;
    if (!_hasMeaningfullyMoved(next, _cameraTarget)) return;
    _cameraTarget = next;
    if (_mapReady) {
      _mapController.move(_latLng(next), _zoom);
    }
  }

  @override
  void dispose() {
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
          height: widget.height,
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

  GeoPoint get _effectiveLocation => widget.location ?? widget.fallback;

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
