import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../../config/geo_discovery_config.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/telemetry.dart';

final homeNearbyControllerProvider =
    AsyncNotifierProvider<HomeNearbyController, HomeNearbyViewState>(
      HomeNearbyController.new,
    );

enum HomeNearbyLoadPhase { idle, loadingEmpty, loadingWithData, loaded, error }

class HomeNearbyViewState {
  const HomeNearbyViewState({
    required this.center,
    required this.items,
    required this.partialFailures,
    required this.permissionDenied,
    required this.isFallbackLocation,
    required this.isStale,
    this.locationFailureReason = LocationFailureReason.none,
    this.phase = HomeNearbyLoadPhase.loaded,
    this.message,
  });

  final GeoPoint? center;
  final bool isFallbackLocation;
  final bool isStale;
  final LocationFailureReason locationFailureReason;
  final List<GeoDiscoveryEntity<Map<String, Object?>>> items;
  final String? message;
  final List<GeoDiscoveryPartialFailure> partialFailures;
  final HomeNearbyLoadPhase phase;
  final bool permissionDenied;

  bool get hasPartialFailures => partialFailures.isNotEmpty;
  bool get isRefreshingWithData => phase == HomeNearbyLoadPhase.loadingWithData;

  HomeNearbyViewState copyWith({
    GeoPoint? center,
    bool? isFallbackLocation,
    bool? isStale,
    LocationFailureReason? locationFailureReason,
    List<GeoDiscoveryEntity<Map<String, Object?>>>? items,
    String? message,
    List<GeoDiscoveryPartialFailure>? partialFailures,
    HomeNearbyLoadPhase? phase,
    bool? permissionDenied,
  }) => HomeNearbyViewState(
    center: center ?? this.center,
    items: items ?? this.items,
    partialFailures: partialFailures ?? this.partialFailures,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    isFallbackLocation: isFallbackLocation ?? this.isFallbackLocation,
    isStale: isStale ?? this.isStale,
    locationFailureReason: locationFailureReason ?? this.locationFailureReason,
    message: message ?? this.message,
    phase: phase ?? this.phase,
  );
}

class HomeNearbyController extends AsyncNotifier<HomeNearbyViewState> {
  CancelToken? _cancelToken;

  @override
  Future<HomeNearbyViewState> build() async {
    ref.onDispose(() => _cancelToken?.cancel());
    return _load();
  }

  Future<void> refresh() async {
    final previous = state.value;
    if (previous != null && previous.items.isNotEmpty) {
      state = AsyncData(
        previous.copyWith(phase: HomeNearbyLoadPhase.loadingWithData),
      );
    } else {
      state = const AsyncLoading();
    }

    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      if (previous != null && previous.items.isNotEmpty) {
        state = AsyncData(
          previous.copyWith(
            message: error.toString(),
            phase: HomeNearbyLoadPhase.error,
          ),
        );
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<HomeNearbyViewState> _load() async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final locationState = await ref
        .read(locationServiceProvider)
        .currentLocation();
    if (locationState.location == null || locationState.isFallback) {
      telemetry.warn(TelemetryEvent.geoSearchBlockedNoLocation, {
        'isFallback': locationState.isFallback,
        'permissionDenied': locationState.permissionDenied,
        'reason': locationState.failureReason.name,
        'surface': 'home',
      });
      return HomeNearbyViewState(
        center: null,
        items: const [],
        partialFailures: const [],
        permissionDenied: locationState.permissionDenied,
        isFallbackLocation: false,
        isStale: false,
        locationFailureReason: locationState.failureReason,
        message: locationState.error,
        phase: HomeNearbyLoadPhase.loaded,
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
      locationFailureReason: locationState.failureReason,
      message: locationState.error,
      phase: HomeNearbyLoadPhase.loaded,
    );
  }
}
