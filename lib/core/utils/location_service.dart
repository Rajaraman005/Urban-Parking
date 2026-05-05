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
  Future<LocationResult> currentLocation() async {
    telemetry.event(TelemetryEvent.geoPermissionRequested);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
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
        return LocationResult(
          location: GeoPoint(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
          ),
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
}
