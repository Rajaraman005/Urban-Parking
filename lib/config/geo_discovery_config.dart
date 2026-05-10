import '../core/utils/geo_discovery/geo_types.dart';

class GeoDiscoveryConfig {
  const GeoDiscoveryConfig._();

  static const schemaVersion = 1;
  static const endpoint = '/geo-discovery/search';
  static const defaultRadiusKm = 5.0;
  static const minRadiusKm = 1.0;
  static const maxRadiusKm = 10.0;
  static const defaultPageSize = 20;
  static const maxPageSize = 50;
  static const freshTtl = Duration(seconds: 60);
  static const staleTtl = Duration(minutes: 5);
  static const memoryMaxEntries = 100;
  static const memoryMaxBytes = 10 * 1024 * 1024;
  static const persistentMaxEntries = 250;
  static const persistentMaxBytes = 25 * 1024 * 1024;
  static const minRequestInterval = Duration(milliseconds: 600);
  static const failureCooldown = Duration(seconds: 30);
  static const retryDelays = [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];
  static const retryMaxAttempts = 3;
  static const retryMaxDelay = Duration(seconds: 16);
  static const gpsQuickTimeout = Duration(seconds: 4);
  static const gpsTimeout = Duration(seconds: 12);
  static const gpsProviderFallbackTimeout = Duration(seconds: 12);
  static const gpsWarmupTimeout = Duration(seconds: 90);
  static const locationDebounce = Duration(milliseconds: 750);
  static const ignoreMovementMeters = 75.0;
  static const invalidateCacheMovementMeters = 250.0;
  static const haversineBatchBudget = Duration(milliseconds: 50);
  static const haversineBatchSize = 10000;
  static const maxInitialMarkers = 100;
  static const rawMarkerHardLimit = 200;
  static const coldNetworkTtfrBudget = Duration(seconds: 3);
  static const warmCacheTtfrBudget = Duration(milliseconds: 250);
  static const supportedServiceTypes = [
    ServiceType.parking,
    ServiceType.rental,
    ServiceType.service,
  ];
}
