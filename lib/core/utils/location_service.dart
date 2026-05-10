import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/geo_discovery_config.dart';
import 'geo_discovery/geo_types.dart';
import 'telemetry.dart';

enum LocationFailureReason {
  none,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

class LocationResult {
  const LocationResult({
    required this.location,
    required this.permissionDenied,
    required this.isFallback,
    this.failureReason = LocationFailureReason.none,
    this.error,
  });

  final String? error;
  final LocationFailureReason failureReason;
  final bool isFallback;
  final GeoPoint? location;
  final bool permissionDenied;

  bool get hasUsableLocation => location != null && !isFallback;
}

class _NativeLocationSnapshot {
  const _NativeLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.isMocked = false,
    this.provider,
  });

  final double? accuracy;
  final bool isMocked;
  final double latitude;
  final double longitude;
  final String? provider;
  final DateTime timestamp;
}

class LocationService {
  static const _freshLocationTtl = Duration(seconds: 30);
  static const _lastKnownLocationTtl = Duration(hours: 12);
  static const _locationDiagnosticsChannel = MethodChannel(
    'com.urbanparking.india/location_diagnostics',
  );
  static const _settingsReturnDelay = Duration(milliseconds: 450);

  GeoPoint? _lastResolvedLocation;
  DateTime? _lastResolvedAt;
  final _resolvedLocationsController = StreamController<GeoPoint>.broadcast();
  StreamSubscription<Position>? _warmupSubscription;
  Completer<Position?>? _warmupCompleter;
  Timer? _warmupTimer;
  bool _warmupStarting = false;

  Stream<GeoPoint> get resolvedLocations => _resolvedLocationsController.stream;

  Future<LocationResult> currentLocation() async {
    final startedAt = DateTime.now();
    final blocked = await _ensureLocationAccess();
    if (blocked != null) return blocked;
    unawaited(startWarmup(accessAlreadyVerified: true));

    final cached = _freshCachedLocation();
    if (cached != null) {
      return cached;
    }

    final nativeLastKnown = await _nativeLastKnownLocation(
      stage: 'native_last_known_before_fix',
    );
    if (nativeLastKnown != null &&
        _isFreshEnoughTimestamp(nativeLastKnown.timestamp)) {
      return _resolvedNativeLocation(
        snapshot: nativeLastKnown,
        startedAt: startedAt,
        status: 'native_last_known_before_fix',
        error: 'Using your last known location while GPS warms up.',
      );
    }

    final lastKnown = await _lastKnownPosition(stage: 'last_known_before_fix');
    final quickPosition = await _currentPosition(
      accuracy: LocationAccuracy.low,
      forceAndroidLocationManager: false,
      stage: 'quick_network',
      timeout: GeoDiscoveryConfig.gpsQuickTimeout,
    );
    if (quickPosition != null) {
      return _resolvedLocation(
        position: quickPosition,
        startedAt: startedAt,
        status: 'quick_network',
      );
    }

    if (lastKnown != null && _isFreshEnoughLastKnown(lastKnown)) {
      return _resolvedLocation(
        position: lastKnown,
        startedAt: startedAt,
        status: 'last_known',
        error: 'Using your last known location while GPS warms up.',
      );
    }

    final balancedPosition = await _currentPosition(
      accuracy: LocationAccuracy.medium,
      forceAndroidLocationManager: false,
      stage: 'balanced_gps',
      timeout: GeoDiscoveryConfig.gpsTimeout,
    );
    if (balancedPosition != null) {
      return _resolvedLocation(
        position: balancedPosition,
        startedAt: startedAt,
        status: 'balanced_gps',
      );
    }

    final providerFallbackPosition =
        await _warmupPositionWithin(const Duration(seconds: 1)) ??
        await _foregroundProviderFallback();
    if (providerFallbackPosition != null) {
      return _resolvedLocation(
        position: providerFallbackPosition,
        startedAt: startedAt,
        status: 'android_location_manager_stream',
      );
    }

    final lastKnownAfterAttempts = await _lastKnownPosition(
      stage: 'last_known_after_attempts',
    );
    final nativeLastKnownAfterAttempts = await _nativeLastKnownLocation(
      stage: 'native_last_known_after_attempts',
    );
    if (lastKnownAfterAttempts != null &&
        _isFreshEnoughLastKnown(lastKnownAfterAttempts)) {
      return _resolvedLocation(
        position: lastKnownAfterAttempts,
        startedAt: startedAt,
        status: 'last_known_after_attempts',
        error: 'Using your last known location while GPS warms up.',
      );
    }
    if (nativeLastKnownAfterAttempts != null &&
        _isFreshEnoughTimestamp(nativeLastKnownAfterAttempts.timestamp)) {
      return _resolvedNativeLocation(
        snapshot: nativeLastKnownAfterAttempts,
        startedAt: startedAt,
        status: 'native_last_known_after_attempts',
        error: 'Using your last known location while GPS warms up.',
      );
    }

    telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      'reason': 'timeout',
      'hadLastKnown':
          lastKnown != null ||
          lastKnownAfterAttempts != null ||
          nativeLastKnown != null ||
          nativeLastKnownAfterAttempts != null,
      ...?await _locationDiagnosticsSnapshot(),
    });
    return const LocationResult(
      location: null,
      permissionDenied: false,
      isFallback: false,
      failureReason: LocationFailureReason.timeout,
      error:
          'Location is taking too long. Turn on high accuracy location, then refresh.',
    );
  }

  Future<bool> openAppSettings() async {
    final opened = await Geolocator.openAppSettings();
    await Future<void>.delayed(_settingsReturnDelay);
    return opened;
  }

  Future<bool> openLocationSettings() async {
    final opened = await Geolocator.openLocationSettings();
    await Future<void>.delayed(_settingsReturnDelay);
    return opened;
  }

  Future<void> startWarmup({bool accessAlreadyVerified = false}) async {
    if (_resolvedLocationsController.isClosed ||
        _warmupStarting ||
        _warmupSubscription != null ||
        _freshCachedLocation() != null) {
      return;
    }

    _warmupStarting = true;
    if (!accessAlreadyVerified) {
      final blocked = await _ensureLocationAccess(requestPermission: false);
      if (blocked != null) {
        _warmupStarting = false;
        telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
          'reason': blocked.failureReason.name,
          'stage': 'warmup_access',
        });
        return;
      }
    }

    final nativeLastKnown = await _nativeLastKnownLocation(
      stage: 'warmup_native_last_known',
    );
    if (nativeLastKnown != null &&
        _isFreshEnoughTimestamp(nativeLastKnown.timestamp)) {
      final location = GeoPoint(
        latitude: nativeLastKnown.latitude,
        longitude: nativeLastKnown.longitude,
      );
      _rememberLocation(location);
      telemetry.event(TelemetryEvent.geoLocationResolved, {
        'accuracyMeters': nativeLastKnown.accuracy?.round(),
        'durationMs': 0,
        'geocell':
            '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}',
        'isMocked': nativeLastKnown.isMocked,
        'provider': nativeLastKnown.provider,
        'status': 'warmup_native_last_known',
      });
      return;
    }

    final completer = Completer<Position?>();
    _warmupCompleter = completer;
    final startedAt = DateTime.now();
    telemetry.event(TelemetryEvent.geoLocationAttemptStarted, {
      'accuracy': LocationAccuracy.low.name,
      'forceAndroidLocationManager': true,
      'provider': _providerName(true),
      'stage': 'warmup_android_location_manager_stream',
      'timeoutMs': GeoDiscoveryConfig.gpsWarmupTimeout.inMilliseconds,
    });

    void complete(Position? position) {
      if (!completer.isCompleted) {
        completer.complete(position);
      }
    }

    _warmupTimer = Timer(GeoDiscoveryConfig.gpsWarmupTimeout, () {
      telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
        'forceAndroidLocationManager': true,
        'provider': _providerName(true),
        'stage': 'warmup_android_location_manager_stream',
        'timeoutMs': GeoDiscoveryConfig.gpsWarmupTimeout.inMilliseconds,
        'errorType': 'TimeoutException',
      });
      complete(null);
      unawaited(_stopWarmup());
    });

    try {
      _warmupSubscription =
          Geolocator.getPositionStream(
            locationSettings: _locationSettings(
              accuracy: LocationAccuracy.low,
              forceAndroidLocationManager: true,
              timeout: null,
            ),
          ).listen(
            (position) {
              if (!_isUsablePosition(position)) {
                telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
                  'stage': 'warmup_android_location_manager_stream',
                  'reason': 'invalid_position',
                });
                return;
              }
              final location = _rememberPosition(position);
              telemetry.event(TelemetryEvent.geoLocationResolved, {
                'accuracyMeters': position.accuracy.round(),
                'durationMs': DateTime.now()
                    .difference(startedAt)
                    .inMilliseconds,
                'geocell':
                    '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}',
                'isMocked': position.isMocked,
                'status': 'warmup_android_location_manager_stream',
              });
              complete(position);
              unawaited(_stopWarmup());
            },
            onError: (Object error) {
              telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
                'forceAndroidLocationManager': true,
                'provider': _providerName(true),
                'stage': 'warmup_android_location_manager_stream',
                'errorType': error.runtimeType.toString(),
              });
              complete(null);
              unawaited(_stopWarmup());
            },
            cancelOnError: true,
          );
    } catch (error) {
      telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
        'forceAndroidLocationManager': true,
        'provider': _providerName(true),
        'stage': 'warmup_android_location_manager_stream',
        'errorType': error.runtimeType.toString(),
      });
      complete(null);
      unawaited(_stopWarmup());
    } finally {
      _warmupStarting = false;
    }
  }

  Future<void> dispose() async {
    await _stopWarmup();
    await _resolvedLocationsController.close();
  }

  Future<LocationResult?> _ensureLocationAccess({
    bool requestPermission = true,
  }) async {
    final diagnostics = await _locationDiagnosticsSnapshot();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    telemetry.event(TelemetryEvent.geoLocationAccessChecked, {
      'serviceEnabled': serviceEnabled,
      ...?diagnostics,
    });
    if (!serviceEnabled) {
      return const LocationResult(
        location: null,
        permissionDenied: false,
        isFallback: false,
        failureReason: LocationFailureReason.servicesDisabled,
        error: 'Turn on device location to show nearby spaces.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      telemetry.event(TelemetryEvent.geoPermissionRequested);
      permission = await Geolocator.requestPermission();
    }
    telemetry.event(TelemetryEvent.geoLocationAccessChecked, {
      'permission': permission.name,
      'serviceEnabled': true,
      ...?diagnostics,
    });
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      telemetry.warn(TelemetryEvent.geoPermissionDenied, {
        'status': permission.name,
      });
      return LocationResult(
        location: null,
        permissionDenied: true,
        isFallback: false,
        failureReason: permission == LocationPermission.deniedForever
            ? LocationFailureReason.permissionDeniedForever
            : LocationFailureReason.permissionDenied,
        error: 'Location permission is required to show nearby results.',
      );
    }

    return null;
  }

  Future<Position?> _lastKnownPosition({required String stage}) async {
    try {
      telemetry.event(TelemetryEvent.geoLocationAttemptStarted, {
        'stage': stage,
      });
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && !_isUsablePosition(position)) {
        telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
          'stage': stage,
          'reason': 'invalid_position',
        });
        return null;
      }
      return position;
    } catch (error) {
      telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
        'stage': stage,
        'errorType': error.runtimeType.toString(),
      });
      return null;
    }
  }

  Future<_NativeLocationSnapshot?> _nativeLastKnownLocation({
    required String stage,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      telemetry.event(TelemetryEvent.geoLocationAttemptStarted, {
        'stage': stage,
      });
      final snapshot = await _locationDiagnosticsChannel
          .invokeMapMethod<String, Object?>('lastKnownBest');
      if (snapshot == null) {
        telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
          'stage': stage,
          'reason': 'empty_native_last_known',
        });
        return null;
      }

      final latitude = (snapshot['latitude'] as num?)?.toDouble();
      final longitude = (snapshot['longitude'] as num?)?.toDouble();
      final timestampMs = (snapshot['timestampMs'] as num?)?.toInt();
      if (latitude == null || longitude == null || timestampMs == null) {
        telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
          'stage': stage,
          'reason': 'invalid_native_last_known',
        });
        return null;
      }

      final native = _NativeLocationSnapshot(
        accuracy: (snapshot['accuracy'] as num?)?.toDouble(),
        isMocked: snapshot['isMocked'] == true,
        latitude: latitude,
        longitude: longitude,
        provider: snapshot['provider']?.toString(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          timestampMs,
          isUtc: true,
        ),
      );
      if (!_isUsableCoordinates(native.latitude, native.longitude)) {
        telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
          'stage': stage,
          'reason': 'invalid_native_coordinates',
        });
        return null;
      }
      return native;
    } catch (error) {
      telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
        'stage': stage,
        'errorType': error.runtimeType.toString(),
      });
      return null;
    }
  }

  Future<Position?> _currentPosition({
    required LocationAccuracy accuracy,
    required bool forceAndroidLocationManager,
    required String stage,
    required Duration timeout,
  }) async {
    try {
      telemetry.event(TelemetryEvent.geoLocationAttemptStarted, {
        'accuracy': accuracy.name,
        'forceAndroidLocationManager': forceAndroidLocationManager,
        'provider': _providerName(forceAndroidLocationManager),
        'stage': stage,
        'timeoutMs': timeout.inMilliseconds,
      });
      return await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(
          accuracy: accuracy,
          forceAndroidLocationManager: forceAndroidLocationManager,
          timeout: timeout,
        ),
      ).timeout(timeout + const Duration(seconds: 1)).then((position) {
        if (!_isUsablePosition(position)) {
          telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
            'stage': stage,
            'reason': 'invalid_position',
          });
          return null;
        }
        return position;
      });
    } catch (error) {
      telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
        'forceAndroidLocationManager': forceAndroidLocationManager,
        'provider': _providerName(forceAndroidLocationManager),
        'stage': stage,
        'timeoutMs': timeout.inMilliseconds,
        'errorType': error.runtimeType.toString(),
      });
      return null;
    }
  }

  Future<Position?> _streamPosition({
    required LocationAccuracy accuracy,
    required bool forceAndroidLocationManager,
    required String stage,
    required Duration timeout,
  }) async {
    StreamSubscription<Position>? subscription;
    Timer? timer;
    try {
      telemetry.event(TelemetryEvent.geoLocationAttemptStarted, {
        'accuracy': accuracy.name,
        'forceAndroidLocationManager': forceAndroidLocationManager,
        'provider': _providerName(forceAndroidLocationManager),
        'stage': stage,
        'timeoutMs': timeout.inMilliseconds,
      });
      final completer = Completer<Position?>();
      void complete(Position? position) {
        if (!completer.isCompleted) {
          completer.complete(position);
        }
      }

      subscription =
          Geolocator.getPositionStream(
            locationSettings: _locationSettings(
              accuracy: accuracy,
              forceAndroidLocationManager: forceAndroidLocationManager,
              timeout: timeout,
            ),
          ).listen(
            (position) {
              if (!_isUsablePosition(position)) {
                telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
                  'stage': stage,
                  'reason': 'invalid_position',
                });
                return;
              }
              complete(position);
            },
            onError: (Object error) {
              telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
                'forceAndroidLocationManager': forceAndroidLocationManager,
                'provider': _providerName(forceAndroidLocationManager),
                'stage': stage,
                'timeoutMs': timeout.inMilliseconds,
                'errorType': error.runtimeType.toString(),
              });
              complete(null);
            },
            cancelOnError: true,
          );
      timer = Timer(timeout + const Duration(seconds: 1), () {
        telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
          'forceAndroidLocationManager': forceAndroidLocationManager,
          'provider': _providerName(forceAndroidLocationManager),
          'stage': stage,
          'timeoutMs': timeout.inMilliseconds,
          'errorType': 'TimeoutException',
        });
        complete(null);
      });

      return await completer.future;
    } catch (error) {
      telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
        'forceAndroidLocationManager': forceAndroidLocationManager,
        'provider': _providerName(forceAndroidLocationManager),
        'stage': stage,
        'timeoutMs': timeout.inMilliseconds,
        'errorType': error.runtimeType.toString(),
      });
      return null;
    } finally {
      timer?.cancel();
      await subscription?.cancel();
    }
  }

  LocationSettings _locationSettings({
    required LocationAccuracy accuracy,
    required bool forceAndroidLocationManager,
    required Duration? timeout,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        forceLocationManager: forceAndroidLocationManager,
        intervalDuration: const Duration(seconds: 1),
        timeLimit: timeout,
      );
    }

    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: 0,
      timeLimit: timeout,
    );
  }

  LocationResult _resolvedLocation({
    required Position position,
    required DateTime startedAt,
    required String status,
    String? error,
  }) {
    final location = _rememberPosition(position);
    telemetry.event(TelemetryEvent.geoLocationResolved, {
      'accuracyMeters': position.accuracy.round(),
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      'geocell':
          '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}',
      'isMocked': position.isMocked,
      'status': status,
    });
    return LocationResult(
      location: location,
      permissionDenied: false,
      isFallback: false,
      error: error,
    );
  }

  LocationResult _resolvedNativeLocation({
    required _NativeLocationSnapshot snapshot,
    required DateTime startedAt,
    required String status,
    String? error,
  }) {
    final location = GeoPoint(
      latitude: snapshot.latitude,
      longitude: snapshot.longitude,
    );
    _rememberLocation(location);
    telemetry.event(TelemetryEvent.geoLocationResolved, {
      'accuracyMeters': snapshot.accuracy?.round(),
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      'geocell':
          '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}',
      'isMocked': snapshot.isMocked,
      'provider': snapshot.provider,
      'status': status,
    });
    return LocationResult(
      location: location,
      permissionDenied: false,
      isFallback: false,
      error: error,
    );
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
    if (!_resolvedLocationsController.isClosed) {
      _resolvedLocationsController.add(location);
    }
  }

  GeoPoint _rememberPosition(Position position) {
    final location = GeoPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    _rememberLocation(location);
    return location;
  }

  bool _isFreshEnoughLastKnown(Position position) {
    return _isFreshEnoughTimestamp(position.timestamp);
  }

  bool _isFreshEnoughTimestamp(DateTime timestamp) {
    return DateTime.now().toUtc().difference(timestamp.toUtc()) <=
        _lastKnownLocationTtl;
  }

  Future<Map<String, Object?>?> _locationDiagnosticsSnapshot() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      final snapshot = await _locationDiagnosticsChannel
          .invokeMapMethod<String, Object?>('snapshot');
      if (snapshot == null) return null;
      return Map<String, Object?>.from(snapshot);
    } catch (error) {
      telemetry.warn(TelemetryEvent.geoLocationUnavailable, {
        'stage': 'native_diagnostics',
        'errorType': error.runtimeType.toString(),
      });
      return null;
    }
  }

  bool _isUsablePosition(Position position) {
    return _isUsableCoordinates(position.latitude, position.longitude);
  }

  bool _isUsableCoordinates(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  String _providerName(bool forceAndroidLocationManager) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return 'platform_default';
    }
    return forceAndroidLocationManager
        ? 'android_location_manager'
        : 'android_fused';
  }

  Future<Position?> _foregroundProviderFallback() async {
    if (_warmupSubscription != null) {
      return null;
    }
    return _streamPosition(
      accuracy: LocationAccuracy.low,
      forceAndroidLocationManager: true,
      stage: 'android_location_manager_stream',
      timeout: GeoDiscoveryConfig.gpsProviderFallbackTimeout,
    );
  }

  Future<Position?> _warmupPositionWithin(Duration timeout) async {
    final completer = _warmupCompleter;
    if (completer == null || completer.isCompleted) {
      return null;
    }

    final result = await Future.any<Position?>([
      completer.future,
      Future<Position?>.delayed(timeout),
    ]);
    if (result == null || !_isUsablePosition(result)) {
      return null;
    }
    return result;
  }

  Future<void> _stopWarmup() async {
    _warmupTimer?.cancel();
    _warmupTimer = null;
    final subscription = _warmupSubscription;
    _warmupSubscription = null;
    await subscription?.cancel();
  }
}
