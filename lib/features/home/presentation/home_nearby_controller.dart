import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../../config/geo_discovery_config.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../core/utils/telemetry.dart';

final homeNearbyControllerProvider =
    AsyncNotifierProvider<HomeNearbyController, HomeNearbyViewState>(
      HomeNearbyController.new,
    );

class HomeNearbyViewState {
  const HomeNearbyViewState({
    required this.center,
    required this.items,
    required this.partialFailures,
    required this.permissionDenied,
    required this.isFallbackLocation,
    required this.isStale,
    this.message,
  });

  final GeoPoint? center;
  final bool isFallbackLocation;
  final bool isStale;
  final List<GeoDiscoveryEntity<Map<String, Object?>>> items;
  final String? message;
  final List<GeoDiscoveryPartialFailure> partialFailures;
  final bool permissionDenied;

  bool get hasPartialFailures => partialFailures.isNotEmpty;
}

class HomeNearbyController extends AsyncNotifier<HomeNearbyViewState> {
  CancelToken? _cancelToken;

  @override
  Future<HomeNearbyViewState> build() async {
    ref.onDispose(() => _cancelToken?.cancel());
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<HomeNearbyViewState> _load() async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final locationState = await ref
        .read(locationServiceProvider)
        .currentLocation();
    if (locationState.location == null) {
      return HomeNearbyViewState(
        center: null,
        items: const [],
        partialFailures: const [],
        permissionDenied: locationState.permissionDenied,
        isFallbackLocation: false,
        isStale: false,
        message: locationState.error,
      );
    }

    final result = await ref
        .read(geoDiscoveryEngineProvider)
        .getNearbyBatch(
          GeoDiscoveryBatchQuery(
            latitude: locationState.location!.latitude,
            longitude: locationState.location!.longitude,
            radiusKm: GeoDiscoveryConfig.defaultRadiusKm,
            pageSize: 8,
            serviceTypes: const [ServiceType.parking],
            sort: GeoSortKey.distance,
          ),
          cancelToken: _cancelToken,
        );

    final pages = result.results.values;
    final items = pages.expand((page) => page.items).toList()
      ..sort((left, right) {
        final distanceCompare = left.distanceKm.compareTo(right.distanceKm);
        if (distanceCompare != 0) return distanceCompare;
        return (right.rating ?? 0).compareTo(left.rating ?? 0);
      });
    final visibleItems = items.take(6).toList(growable: false);
    ref.read(parkingSpotCacheProvider).upsertDiscoveryItems(visibleItems);

    telemetry.event(TelemetryEvent.geoResultsRendered, {
      'emptyResult': visibleItems.isEmpty,
      'queryFingerprint': result.queryFingerprint,
      'renderCount': visibleItems.length,
      'source': result.source.apiValue,
      'surface': 'home',
    });

    return HomeNearbyViewState(
      center: locationState.location,
      items: visibleItems,
      partialFailures: result.partialFailures,
      permissionDenied: locationState.permissionDenied,
      isFallbackLocation: locationState.isFallback,
      isStale: pages.any((page) => page.isStale),
      message: locationState.error,
    );
  }
}
