import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../config/geo_discovery_config.dart';
import '../telemetry.dart';
import 'geo_cache.dart';
import 'geo_types.dart';
import 'query_normalizer.dart';
import 'rate_guard.dart';
import 'retry.dart';

class GeoDiscoveryEngine {
  GeoDiscoveryEngine({
    required GeoDiscoveryRepository repository,
    required GeoDiscoveryCache cache,
  }) : _repository = repository,
       _cache = cache;

  final GeoDiscoveryRepository _repository;
  final GeoDiscoveryCache _cache;
  final _inFlight =
      <String, Future<GeoDiscoveryBatchResult<Map<String, Object?>>>>{};
  final _lastFailedAtByFingerprint = <String, DateTime>{};
  final _lastSuccessfulByKey =
      <String, GeoDiscoveryBatchResult<Map<String, Object?>>>{};
  final _rateGuard = GeoRequestRateGuard();

  Future<GeoDiscoveryPage<Map<String, Object?>>> getNearby(
    GeoDiscoveryQuery query, {
    CancelToken? cancelToken,
  }) async {
    final result = await getNearbyBatch(
      GeoDiscoveryBatchQuery(
        cursors: query.cursor == null
            ? null
            : {query.serviceType: query.cursor!},
        filters: query.filters,
        latitude: query.latitude,
        longitude: query.longitude,
        pageSize: query.pageSize,
        radiusKm: query.radiusKm,
        requestId: query.requestId,
        serviceTypes: [query.serviceType],
        sort: query.sort,
      ),
      cancelToken: cancelToken,
    );
    final page = result.results[query.serviceType];
    if (page == null) {
      throw GeoDiscoveryError(
        'No ${query.serviceType.apiValue} results returned.',
        retryable: true,
      );
    }
    return page;
  }

  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> getNearbyBatch(
    GeoDiscoveryBatchQuery query, {
    CancelToken? cancelToken,
  }) async {
    final normalized = normalizeGeoBatchQuery(query);
    if (normalized.serviceTypes.isEmpty) {
      throw const GeoDiscoveryError(
        'At least one service type is required.',
        retryable: false,
      );
    }

    telemetry.event(
      normalized.serviceTypes.length > 1
          ? TelemetryEvent.geoBatchSearchRequested
          : TelemetryEvent.geoSearchRequested,
      {
        'geocell': normalized.roundedGeocell,
        'pageSize': normalized.pageSize,
        'queryFingerprint': normalized.queryFingerprint,
        'radiusKm': normalized.radiusKm,
        'schemaVersion': normalized.schemaVersion,
        'serviceTypes': normalized.serviceTypes
            .map((entry) => entry.apiValue)
            .join(','),
        'sourceMode': AppConfig.geoRuntimeMode,
      },
    );

    return _execute(normalized, cancelToken: cancelToken);
  }

  Future<void> clearCache() => _cache.clear();

  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> _execute(
    GeoDiscoveryNormalizedQuery normalized, {
    CancelToken? cancelToken,
  }) async {
    final key = _cacheKeyFor(normalized);
    final cached = _cache.get(key);

    if (cached.freshness == CacheFreshness.fresh && cached.value != null) {
      _lastFailedAtByFingerprint.remove(normalized.queryFingerprint);
      _lastSuccessfulByKey[key] = cached.value!;
      telemetry.event(TelemetryEvent.geoCacheHit, {
        'cacheHit': true,
        'geocell': normalized.roundedGeocell,
        'queryFingerprint': normalized.queryFingerprint,
        'serviceTypes': normalized.serviceTypes
            .map((entry) => entry.apiValue)
            .join(','),
      });
      return _markBatch(cached.value!, isStale: false);
    }

    final cooldownFallback = _cooldownFallbackFor(
      key,
      normalized,
      cached.value,
    );
    if (cooldownFallback != null) {
      return cooldownFallback;
    }

    try {
      final result = await _fetchNetwork(
        normalized,
        key,
        cancelToken: cancelToken,
      );
      await _cache.set(key, result);
      _lastFailedAtByFingerprint.remove(normalized.queryFingerprint);
      _lastSuccessfulByKey[key] = result;
      return result;
    } catch (error) {
      final geoError = toGeoDiscoveryError(error);
      if (geoError.code == GeoFailureCode.aborted) {
        final fallback = cached.value ?? _lastSuccessfulByKey[key];
        if (fallback != null) {
          return _markBatch(fallback, isStale: true);
        }
        throw geoError;
      }

      if (geoError.code == GeoFailureCode.invalidCursor) {
        telemetry.warn(TelemetryEvent.geoCursorInvalidated, {
          'code': geoError.code.apiValue,
          'geocell': normalized.roundedGeocell,
          'queryFingerprint': normalized.queryFingerprint,
        });
        final firstPage = GeoDiscoveryNormalizedQuery(
          cursors: const {},
          filtersByService: normalized.filtersByService,
          latitude: normalized.latitude,
          longitude: normalized.longitude,
          pageSize: normalized.pageSize,
          queryFingerprint: normalized.queryFingerprint,
          radiusKm: normalized.radiusKm,
          requestId: normalized.requestId,
          roundedGeocell: normalized.roundedGeocell,
          schemaVersion: normalized.schemaVersion,
          serviceTypes: normalized.serviceTypes,
          sort: normalized.sort,
        );
        final firstPageKey = _cacheKeyFor(firstPage);
        final result = await _fetchNetwork(
          firstPage,
          firstPageKey,
          cancelToken: cancelToken,
        );
        final marked = result.copyWith(
          results: result.results.map(
            (key, page) =>
                MapEntry(key, page.copyWith(cursorInvalidated: true)),
          ),
        );
        await _cache.set(firstPageKey, marked);
        return marked;
      }

      if (cached.freshness == CacheFreshness.stale && cached.value != null) {
        _lastFailedAtByFingerprint[normalized.queryFingerprint] =
            DateTime.now();
        telemetry.warn(TelemetryEvent.geoCacheStaleServed, {
          'code': geoError.code.apiValue,
          'geocell': normalized.roundedGeocell,
          'isStale': true,
          'queryFingerprint': normalized.queryFingerprint,
        });
        return _markBatch(cached.value!, isStale: true);
      }

      _lastFailedAtByFingerprint[normalized.queryFingerprint] = DateTime.now();
      if (geoError.code == GeoFailureCode.deploymentConfigError) {
        telemetry.error(TelemetryEvent.geoDeploymentMisconfiguration, {
          'code': geoError.code.apiValue,
          'geocell': normalized.roundedGeocell,
          'queryFingerprint': normalized.queryFingerprint,
        });
      }
      telemetry.error(TelemetryEvent.geoSearchFailed, {
        'code': geoError.code.apiValue,
        'geocell': normalized.roundedGeocell,
        'queryFingerprint': normalized.queryFingerprint,
        'status': 'failed',
      });
      throw geoError;
    }
  }

  GeoDiscoveryBatchResult<Map<String, Object?>>? _cooldownFallbackFor(
    String key,
    GeoDiscoveryNormalizedQuery normalized,
    GeoDiscoveryBatchResult<Map<String, Object?>>? cachedValue,
  ) {
    final failedAt = _lastFailedAtByFingerprint[normalized.queryFingerprint];
    if (failedAt == null) return null;

    final elapsed = DateTime.now().difference(failedAt);
    if (elapsed >= GeoDiscoveryConfig.failureCooldown) {
      _lastFailedAtByFingerprint.remove(normalized.queryFingerprint);
      return null;
    }

    final fallback = cachedValue ?? _lastSuccessfulByKey[key];
    telemetry.warn(TelemetryEvent.geoRetryCooldownTriggered, {
      'durationMs':
          (GeoDiscoveryConfig.failureCooldown - elapsed).inMilliseconds,
      'geocell': normalized.roundedGeocell,
      'queryFingerprint': normalized.queryFingerprint,
      'status': fallback == null ? 'blocked_without_cache' : 'served_cache',
    });

    if (fallback != null) {
      return _markBatch(fallback, isStale: true);
    }

    throw const GeoDiscoveryError(
      'Nearby discovery is cooling down after a failed request.',
      code: GeoFailureCode.networkError,
      retryable: false,
    );
  }

  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> _fetchNetwork(
    GeoDiscoveryNormalizedQuery normalized,
    String key, {
    CancelToken? cancelToken,
  }) {
    final active = _inFlight[key];
    if (active != null) return active;

    final startedAt = DateTime.now();
    final promise = () async {
      await _rateGuard.waitForSlot(normalized.queryFingerprint);
      final result = await withGeoRetry(
        () => _repository.searchNearby(normalized, cancelToken: cancelToken),
        queryFingerprint: normalized.queryFingerprint,
        serviceTypes: normalized.serviceTypes
            .map((entry) => entry.apiValue)
            .join(','),
      );

      if (result.schemaVersion != GeoDiscoveryConfig.schemaVersion) {
        throw const GeoDiscoveryError(
          'Geo discovery schema version is unsupported.',
          code: GeoFailureCode.schemaVersionUnsupported,
          retryable: false,
        );
      }

      telemetry.event(TelemetryEvent.geoSearchSucceeded, {
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'emptyResult': result.results.values.every(
          (page) => page.items.isEmpty,
        ),
        'geocell': normalized.roundedGeocell,
        'queryFingerprint': normalized.queryFingerprint,
        'schemaVersion': result.schemaVersion,
        'source': result.source.apiValue,
      });
      return result;
    }();

    _inFlight[key] = promise;
    return promise.whenComplete(() => _inFlight.remove(key));
  }

  String _cacheKeyFor(GeoDiscoveryNormalizedQuery query) {
    final cursors = query.cursors.entries.toList()
      ..sort((left, right) => left.key.apiValue.compareTo(right.key.apiValue));
    final cursorKey = cursors
        .map((entry) => '${entry.key.apiValue}:${entry.value}')
        .join(',');
    final cacheNamespace =
        'geo_v${GeoDiscoveryConfig.schemaVersion}|${AppConfig.geoRuntimeMode}|${AppConfig.apiBaseHost}';
    return '$cacheNamespace|${query.queryFingerprint}|cursor:${cursorKey.isEmpty ? 'first' : cursorKey}';
  }

  GeoDiscoveryBatchResult<Map<String, Object?>> _markBatch(
    GeoDiscoveryBatchResult<Map<String, Object?>> result, {
    required bool isStale,
  }) => result.copyWith(
    source: GeoResultSource.cache,
    results: result.results.map(
      (key, page) => MapEntry(
        key,
        page.copyWith(isStale: isStale, source: GeoResultSource.cache),
      ),
    ),
  );
}
