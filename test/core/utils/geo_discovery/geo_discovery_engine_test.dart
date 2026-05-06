import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/config/geo_discovery_config.dart';
import 'package:urban_parking/core/utils/geo_discovery/distance.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_cache.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_discovery_engine.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/core/utils/geo_discovery/query_normalizer.dart';

void main() {
  test('haversine distance is stable for Chennai coordinates', () {
    final distance = haversineDistanceKm(
      const GeoPoint(latitude: 13.0827, longitude: 80.2707),
      const GeoPoint(latitude: 13.0604, longitude: 80.2496),
    );

    expect(distance, closeTo(3.34, 0.2));
  });

  test(
    'normalizer clamps radius and page size and builds stable fingerprint',
    () {
      final query = normalizeGeoBatchQuery(
        const GeoDiscoveryBatchQuery(
          latitude: 13.0827,
          longitude: 80.2707,
          radiusKm: 40,
          pageSize: 500,
          serviceTypes: [ServiceType.parking, ServiceType.parking],
          filters: {'maxPrice': 100},
        ),
      );

      expect(query.radiusKm, GeoDiscoveryConfig.maxRadiusKm);
      expect(query.pageSize, GeoDiscoveryConfig.maxPageSize);
      expect(query.serviceTypes, [ServiceType.parking]);
      expect(query.queryFingerprint, contains('13.083,80.271'));
    },
  );

  test('engine deduplicates fresh cache after first request', () async {
    final repository = _FakeGeoRepository();
    final engine = GeoDiscoveryEngine(
      repository: repository,
      cache: GeoDiscoveryCache(),
    );

    final query = const GeoDiscoveryBatchQuery(
      latitude: 13.0827,
      longitude: 80.2707,
      serviceTypes: [ServiceType.parking],
    );

    final first = await engine.getNearbyBatch(query);
    final second = await engine.getNearbyBatch(query);

    expect(first.results[ServiceType.parking]!.items, hasLength(1));
    expect(second.source, GeoResultSource.cache);
    expect(repository.calls, 1);
  });

  test('engine does not retry non-recoverable backend errors', () async {
    final repository = _FailingGeoRepository(
      const GeoDiscoveryError(
        'Database schema is not ready.',
        code: GeoFailureCode.databaseError,
      ),
    );
    final engine = GeoDiscoveryEngine(
      repository: repository,
      cache: GeoDiscoveryCache(),
    );

    await expectLater(
      engine.getNearbyBatch(
        const GeoDiscoveryBatchQuery(
          latitude: 13.0827,
          longitude: 80.2707,
          serviceTypes: [ServiceType.parking],
        ),
      ),
      throwsA(
        isA<GeoDiscoveryError>().having(
          (error) => error.code,
          'code',
          GeoFailureCode.databaseError,
        ),
      ),
    );

    expect(repository.calls, 1);
  });
}

class _FakeGeoRepository implements GeoDiscoveryRepository {
  var calls = 0;

  @override
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> searchNearby(
    GeoDiscoveryNormalizedQuery query, {
    CancelToken? cancelToken,
  }) async {
    calls += 1;
    final fetchedAt = DateTime.now();
    return GeoDiscoveryBatchResult(
      fetchedAt: fetchedAt,
      partialFailures: const [],
      queryFingerprint: query.queryFingerprint,
      results: {
        ServiceType.parking: GeoDiscoveryPage(
          fetchedAt: fetchedAt,
          isStale: false,
          items: [
            GeoDiscoveryEntity(
              availabilityStatus: AvailabilityStatus.available,
              distanceKm: 1,
              entity: const {'id': 'test'},
              id: 'test',
              location: const GeoPoint(latitude: 13.08, longitude: 80.27),
              serviceType: ServiceType.parking,
              title: 'Test spot',
            ),
          ],
          queryFingerprint: query.queryFingerprint,
          schemaVersion: query.schemaVersion,
          source: GeoResultSource.network,
        ),
      },
      schemaVersion: query.schemaVersion,
      source: GeoResultSource.network,
    );
  }
}

class _FailingGeoRepository implements GeoDiscoveryRepository {
  _FailingGeoRepository(this.error);

  final GeoDiscoveryError error;
  var calls = 0;

  @override
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> searchNearby(
    GeoDiscoveryNormalizedQuery query, {
    CancelToken? cancelToken,
  }) async {
    calls += 1;
    throw error;
  }
}
