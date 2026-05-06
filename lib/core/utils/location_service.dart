import 'package:geolocator/geolocator.dart';

import '../../config/app_config.dart';
import '../../config/geo_discovery_config.dart';
import '../constants/app_constants.dart';
import 'geo_discovery/geo_types.dart';
import 'telemetry.dart';

class LocationResult {
  const LocationResult({
    required this.location,
    required this.permissionDenied,
    required this.isFallback,
    this.error,
  });

  final String? error;
  final bool isFallback;
  final GeoPoint? location;
  final bool permissionDenied;
}

class LocationService {
  static const _freshLocationTtl = Duration(seconds: 30);

  GeoPoint? _lastResolvedLocation;
  DateTime? _lastResolvedAt;

  Future<LocationResult> currentLocation() async {
    final cached = _freshCachedLocation();
    if (cached != null) {
      return cached;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      telemetry.event(TelemetryEvent.geoPermissionRequested);
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      telemetry.warn(TelemetryEvent.geoPermissionDenied, {
        'status': permission.name,
      });
      return LocationResult(
        location: AppConfig.isProduction ? null : AppConstants.chennaiCenter,
        permissionDenied: true,
        isFallback: !AppConfig.isProduction,
        error: 'Location permission is required to show nearby results.',
      );
    }

    final startedAt = DateTime.now();
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } catch (_) {
      lastKnown = null;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: GeoDiscoveryConfig.gpsTimeout,
        ),
      ).timeout(GeoDiscoveryConfig.gpsTimeout);
      final location = GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _rememberLocation(location);
      telemetry.event(TelemetryEvent.geoLocationResolved, {
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'geocell':
            '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}',
        'status': 'granted',
      });
      return LocationResult(
        location: location,
        permissionDenied: false,
        isFallback: false,
      );
    } catch (_) {
      if (lastKnown != null) {
        final location = GeoPoint(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
        );
        _rememberLocation(location);
        telemetry.event(TelemetryEvent.geoLocationResolved, {
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'geocell':
              '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}',
          'status': 'last_known',
        });
        return LocationResult(
          location: location,
          permissionDenied: false,
          isFallback: false,
          error: 'Using your last known location.',
        );
      }
      return LocationResult(
        location: AppConstants.chennaiCenter,
        permissionDenied: false,
        isFallback: true,
        error:
            'GPS location timed out. Showing central Chennai while location warms up.',
      );
    }
  }

  LocationResult? _freshCachedLocation() {
    final location = _lastResolvedLocation;
    final resolvedAt = _lastResolvedAt;
    if (location == null || resolvedAt == null) {
      return null;
    }

    if (DateTime.now().difference(resolvedAt) > _freshLocationTtl) {
      return null;
    }

    telemetry.event(TelemetryEvent.geoLocationResolved, {
      'durationMs': 0,
      'geocell':
          '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}',
      'status': 'cached',
    });
    return LocationResult(
      location: location,
      permissionDenied: false,
      isFallback: false,
    );
  }

  void _rememberLocation(GeoPoint location) {
    _lastResolvedLocation = location;
    _lastResolvedAt = DateTime.now();
  }
}
