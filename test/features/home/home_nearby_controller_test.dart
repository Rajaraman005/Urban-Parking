import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/config/app_providers.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_cache.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_discovery_engine.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/core/utils/location_service.dart';
import 'package:urban_parking/features/home/presentation/home_nearby_controller.dart';

void main() {
  test('refresh preserves previous nearby results while loading', () async {
    final engine = _BlockingGeoDiscoveryEngine();
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
        geoDiscoveryEngineProvider.overrideWithValue(engine),
        geoDiscoveryCacheProvider.overrideWithValue(GeoDiscoveryCache()),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(homeNearbyControllerProvider.future);
    expect(initial.items.map((item) => item.id), ['initial']);

    final refreshCompleter =
        Completer<GeoDiscoveryBatchResult<Map<String, Object?>>>();
    engine.nextResult = refreshCompleter.future;

    final refresh = container
        .read(homeNearbyControllerProvider.notifier)
        .refresh();

    final refreshing = container.read(homeNearbyControllerProvider).value;
    expect(refreshing?.phase, HomeNearbyLoadPhase.loadingWithData);
    expect(refreshing?.items.map((item) => item.id), ['initial']);

    refreshCompleter.complete(_result('refreshed'));
    await refresh;

    final refreshed = container.read(homeNearbyControllerProvider).value;
    expect(refreshed?.phase, HomeNearbyLoadPhase.loaded);
    expect(refreshed?.items.map((item) => item.id), ['refreshed']);
  });
}

class _BlockingGeoDiscoveryEngine implements GeoDiscoveryEngine {
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>>? nextResult;

  @override
  Future<void> clearCache() async {}

  @override
  Future<GeoDiscoveryPage<Map<String, Object?>>> getNearby(
    GeoDiscoveryQuery query, {
    CancelToken? cancelToken,
  }) async {
    final batch = await getNearbyBatch(
      GeoDiscoveryBatchQuery(
        latitude: query.latitude,
        longitude: query.longitude,
        serviceTypes: [query.serviceType],
      ),
      cancelToken: cancelToken,
    );
    return batch.results[query.serviceType]!;
  }

  @override
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> getNearbyBatch(
    GeoDiscoveryBatchQuery query, {
    CancelToken? cancelToken,
  }) async {
    final pending = nextResult;
    if (pending != null) {
      nextResult = null;
      return pending;
    }
    return _result('initial');
  }
}

class _FakeLocationService extends LocationService {
  @override
  Future<LocationResult> currentLocation() async {
    return const LocationResult(
      location: GeoPoint(latitude: 13.0827, longitude: 80.2707),
      permissionDenied: false,
      isFallback: false,
    );
  }
}

GeoDiscoveryBatchResult<Map<String, Object?>> _result(String id) {
  final fetchedAt = DateTime.now();
  return GeoDiscoveryBatchResult(
    fetchedAt: fetchedAt,
    partialFailures: const [],
    queryFingerprint: 'v1|parking|13.083,80.271|5.00|distance|{}',
    results: {
      ServiceType.parking: GeoDiscoveryPage(
        fetchedAt: fetchedAt,
        isStale: false,
        items: [
          GeoDiscoveryEntity(
            availabilityStatus: AvailabilityStatus.available,
            distanceKm: 1,
            entity: {'id': id, 'title': id},
            id: id,
            location: const GeoPoint(latitude: 13.08, longitude: 80.27),
            serviceType: ServiceType.parking,
            title: id,
          ),
        ],
        queryFingerprint: 'v1|parking|13.083,80.271|5.00|distance|{}',
        schemaVersion: 1,
        source: GeoResultSource.network,
      ),
    },
    schemaVersion: 1,
    source: GeoResultSource.network,
  );
}
