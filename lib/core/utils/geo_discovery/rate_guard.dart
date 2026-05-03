import '../../../config/geo_discovery_config.dart';
import '../telemetry.dart';
import 'geo_types.dart';

class GeoRequestRateGuard {
  final _lastAttempt = <String, DateTime>{};

  Future<void> waitForSlot(String queryFingerprint) async {
    final now = DateTime.now();
    final last = _lastAttempt[queryFingerprint];
    if (last != null) {
      final elapsed = now.difference(last);
      final wait = GeoDiscoveryConfig.minRequestInterval - elapsed;
      if (!wait.isNegative && wait > Duration.zero) {
        telemetry.warn(TelemetryEvent.geoRateLimited, {
          'durationMs': wait.inMilliseconds,
          'queryFingerprint': queryFingerprint,
          'status': 'client_wait',
        });
        await Future<void>.delayed(wait);
      }
    }
    _lastAttempt[queryFingerprint] = DateTime.now();
  }
}

GeoDiscoveryError toGeoDiscoveryError(Object error) {
  if (error is GeoDiscoveryError) return error;
  final message = error.toString();
  if (message.contains('cancel') || message.contains('aborted')) {
    return const GeoDiscoveryError(
      'Geo discovery request was cancelled.',
      code: GeoFailureCode.aborted,
      retryable: false,
    );
  }
  return GeoDiscoveryError(message, code: GeoFailureCode.networkError);
}
