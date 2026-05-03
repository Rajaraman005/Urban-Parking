import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../../config/geo_discovery_config.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
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

class GeoDiscoveryViewState {
  const GeoDiscoveryViewState({
    required this.center,
    required this.result,
    required this.permissionDenied,
    required this.isFallbackLocation,
    this.message,
  });

  final GeoPoint? center;
  final GeoDiscoveryBatchResult<Map<String, Object?>>? result;
  final bool permissionDenied;
  final bool isFallbackLocation;
  final String? message;

  List<GeoDiscoveryPartialFailure> failuresFor(ServiceType serviceType) =>
      result?.partialFailures
          .where((failure) => failure.serviceType == serviceType)
          .toList() ??
      const [];
}

class GeoDiscoveryController extends AsyncNotifier<GeoDiscoveryViewState> {
  CancelToken? _cancelToken;

  @override
  Future<GeoDiscoveryViewState> build() async {
    ref.onDispose(() => _cancelToken?.cancel());
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<GeoDiscoveryViewState> _load() async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    final locationState = await ref
        .read(locationServiceProvider)
        .currentLocation();
    if (locationState.location == null) {
      return GeoDiscoveryViewState(
        center: null,
        result: null,
        permissionDenied: locationState.permissionDenied,
        isFallbackLocation: false,
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
            serviceTypes: GeoDiscoveryConfig.supportedServiceTypes,
          ),
          cancelToken: _cancelToken,
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
      message: locationState.error,
    );
  }
}
