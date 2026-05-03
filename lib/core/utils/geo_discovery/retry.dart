import 'dart:math' as math;

import '../../../config/geo_discovery_config.dart';
import '../telemetry.dart';
import 'geo_types.dart';
import 'rate_guard.dart';

const _retryableCodes = {
  GeoFailureCode.backendTimeout,
  GeoFailureCode.networkError,
  GeoFailureCode.offline,
  GeoFailureCode.rateLimited,
  GeoFailureCode.unknown,
};

Future<T> withGeoRetry<T>(
  Future<T> Function() operation, {
  required String queryFingerprint,
  required String serviceTypes,
}) async {
  var attempt = 0;
  GeoDiscoveryError? lastError;

  while (attempt <= GeoDiscoveryConfig.retryMaxAttempts) {
    try {
      return await operation();
    } catch (error) {
      final geoError = toGeoDiscoveryError(error);
      lastError = geoError;
      final canRetry =
          geoError.retryable &&
          _retryableCodes.contains(geoError.code) &&
          attempt < GeoDiscoveryConfig.retryMaxAttempts;

      if (!canRetry) {
        throw geoError;
      }

      final configuredDelay =
          geoError.retryAfter ??
          GeoDiscoveryConfig.retryDelays[math.min(
            attempt,
            GeoDiscoveryConfig.retryDelays.length - 1,
          )];
      final capped = configuredDelay > GeoDiscoveryConfig.retryMaxDelay
          ? GeoDiscoveryConfig.retryMaxDelay
          : configuredDelay;
      final jitterMs = math.Random().nextInt(
        math.max(capped.inMilliseconds, 1),
      );
      final delay = Duration(milliseconds: jitterMs);

      telemetry.warn(TelemetryEvent.geoSearchFailed, {
        'code': geoError.code.apiValue,
        'durationMs': delay.inMilliseconds,
        'queryFingerprint': queryFingerprint,
        'retryCount': attempt + 1,
        'serviceTypes': serviceTypes,
        'status': 'retrying',
      });
      await Future<void>.delayed(delay);
      attempt += 1;
    }
  }

  throw lastError ??
      const GeoDiscoveryError(
        'Geo discovery retry failed.',
        code: GeoFailureCode.unknown,
      );
}
