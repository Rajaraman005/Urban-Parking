import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../../config/geo_discovery_config.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/utils/telemetry.dart';

final selectedServiceTypeProvider =
    NotifierProvider<SelectedServiceTypeController, ServiceType>(
      SelectedServiceTypeController.new,
    );

class SelectedServiceTypeController extends Notifier<ServiceType> {
  @override
  ServiceType build() => ServiceType.parking;

  void select(ServiceType serviceType) {
    state = serviceType;
  }
}

final geoDiscoveryControllerProvider =
    AsyncNotifierProvider<GeoDiscoveryController, GeoDiscoveryViewState>(
      GeoDiscoveryController.new,
    );

enum GeoDiscoveryLoadPhase {
  idle,
  loadingEmpty,
  loadingWithData,
  loaded,
  error,
}

class GeoDiscoveryViewState {
  const GeoDiscoveryViewState({
    required this.center,
    required this.result,
    required this.permissionDenied,
    required this.isFallbackLocation,
    this.locationFailureReason = LocationFailureReason.none,
    this.phase = GeoDiscoveryLoadPhase.loaded,
    this.message,
  });

  final GeoPoint? center;
  final GeoDiscoveryBatchResult<Map<String, Object?>>? result;
  final bool permissionDenied;
  final bool isFallbackLocation;
  final LocationFailureReason locationFailureReason;
  final GeoDiscoveryLoadPhase phase;
  final String? message;

  List<GeoDiscoveryPartialFailure> failuresFor(ServiceType serviceType) =>
      result?.partialFailures
          .where((failure) => failure.serviceType == serviceType)
          .toList() ??
      const [];

  bool get isRefreshingWithData =>
      phase == GeoDiscoveryLoadPhase.loadingWithData;

  GeoDiscoveryViewState copyWith({
    GeoPoint? center,
    GeoDiscoveryBatchResult<Map<String, Object?>>? result,
    bool? permissionDenied,
    bool? isFallbackLocation,
    LocationFailureReason? locationFailureReason,
    GeoDiscoveryLoadPhase? phase,
    String? message,
  }) => GeoDiscoveryViewState(
    center: center ?? this.center,
    result: result ?? this.result,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    isFallbackLocation: isFallbackLocation ?? this.isFallbackLocation,
    locationFailureReason: locationFailureReason ?? this.locationFailureReason,
    phase: phase ?? this.phase,
    message: message ?? this.message,
  );
}

class GeoDiscoveryController extends AsyncNotifier<GeoDiscoveryViewState> {
  CancelToken? _cancelToken;

  @override
  Future<GeoDiscoveryViewState> build() async {
    ref.onDispose(() => _cancelToken?.cancel());
    return _load();
  }

  Future<void> refresh() async {
    final previous = state.value;
    if (previous?.result != null) {
      state = AsyncData(
        previous!.copyWith(phase: GeoDiscoveryLoadPhase.loadingWithData),
      );
    } else {
      state = const AsyncLoading();
    }

    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      if (previous?.result != null) {
        state = AsyncData(
          previous!.copyWith(
            message: error.toString(),
            phase: GeoDiscoveryLoadPhase.error,
          ),
        );
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<GeoDiscoveryViewState> _load() async {
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
        'surface': 'search',
      });
      return GeoDiscoveryViewState(
        center: null,
        result: null,
        permissionDenied: locationState.permissionDenied,
        isFallbackLocation: false,
        locationFailureReason: locationState.failureReason,
        message: locationState.error,
        phase: GeoDiscoveryLoadPhase.loaded,
      );
    }

    final result = await ref
        .read(geoDiscoveryEngineProvider)
        .getNearbyBatch(
          GeoDiscoveryBatchQuery(
            latitude: locationState.location!.latitude,
            longitude: locationState.location!.longitude,
            radiusKm: GeoDiscoveryConfig.defaultRadiusKm,
            serviceTypes: GeoDiscoveryConfig.supportedServiceTypes,
          ),
          cancelToken: _cancelToken,
        );
    ref
        .read(parkingSpotCacheProvider)
        .upsertDiscoveryItems(
          result.results.values.expand((page) => page.items),
        );
    telemetry.event(TelemetryEvent.geoResultsRendered, {
      'emptyResult': result.results.values.every((page) => page.items.isEmpty),
      'queryFingerprint': result.queryFingerprint,
      'source': result.source.apiValue,
    });
    return GeoDiscoveryViewState(
      center: locationState.location,
      result: result,
      permissionDenied: locationState.permissionDenied,
      isFallbackLocation: locationState.isFallback,
      locationFailureReason: locationState.failureReason,
      message: locationState.error,
      phase: GeoDiscoveryLoadPhase.loaded,
    );
  }
}
