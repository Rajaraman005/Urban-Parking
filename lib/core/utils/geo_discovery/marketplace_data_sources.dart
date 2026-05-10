import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../config/geo_discovery_config.dart';
import '../../../features/parking/data/mock_parking_data.dart';
import '../../../features/parking/domain/parking_spot.dart';
import '../../errors/app_failure.dart';
import '../../network/api_client.dart';
import '../telemetry.dart';
import 'distance.dart';
import 'geo_types.dart';

class RestMarketplaceDataSource implements MarketplaceDataSource {
  const RestMarketplaceDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> searchNearby(
    GeoDiscoveryNormalizedQuery query, {
    CancelToken? cancelToken,
  }) async {
    try {
      _apiClient.refreshRuntimeOptions();
      final response = await _apiClient.dio.post<Map<String, Object?>>(
        GeoDiscoveryConfig.endpoint,
        data: query.toRequestJson(),
        cancelToken: cancelToken,
      );

      return GeoDiscoveryBatchResult.fromJson<Map<String, Object?>>(
        Map<String, Object?>.from(response.data ?? const {}),
        (json) => Map<String, Object?>.from(json as Map),
      );
    } on DioException catch (error) {
      final failure = ApiClient.toFailure(error);
      telemetry.warn(TelemetryEvent.geoSearchFailed, {
        'apiHost': AppConfig.apiBaseHost,
        'code': failure.code ?? 'network_error',
        'dioType': error.type.name,
        'endpoint': GeoDiscoveryConfig.endpoint,
        'httpStatus': error.response?.statusCode,
        'sourceMode': AppConfig.geoRuntimeMode,
        'status': 'rest_transport_error',
      });
      throw _geoDiscoveryErrorFor(failure);
    } catch (error) {
      final failure = ApiClient.toFailure(error);
      telemetry.warn(TelemetryEvent.geoSearchFailed, {
        'apiHost': AppConfig.apiBaseHost,
        'code': failure.code ?? 'network_error',
        'endpoint': GeoDiscoveryConfig.endpoint,
        'sourceMode': AppConfig.geoRuntimeMode,
        'status': 'rest_decode_error',
      });
      throw _geoDiscoveryErrorFor(failure);
    }
  }
}

GeoDiscoveryError _geoDiscoveryErrorFor(AppFailure failure) {
  final parsedCode = GeoFailureCode.fromApi(failure.code);
  final code = parsedCode == GeoFailureCode.unknown
      ? GeoFailureCode.networkError
      : parsedCode;
  return GeoDiscoveryError(
    _geoDiscoveryMessage(failure.message, code),
    code: code,
    retryAfter: failure is NetworkFailure ? failure.retryAfter : null,
    retryable: failure.retryable && _isRetryableGeoFailure(code),
  );
}

String _geoDiscoveryMessage(String message, GeoFailureCode code) {
  switch (code) {
    case GeoFailureCode.serverConfigError:
      return 'Nearby discovery is temporarily unavailable while the server is being configured.';
    case GeoFailureCode.databaseError:
    case GeoFailureCode.contractMismatch:
      return 'Nearby discovery is temporarily unavailable while search data is being updated.';
    case GeoFailureCode.schemaVersionUnsupported:
      return 'Nearby discovery needs an app update before it can search.';
    case GeoFailureCode.deploymentConfigError:
      return 'Nearby discovery is temporarily unavailable because the mobile API is not deployed correctly.';
    default:
      return message;
  }
}

bool _isRetryableGeoFailure(GeoFailureCode code) {
  switch (code) {
    case GeoFailureCode.backendTimeout:
    case GeoFailureCode.networkError:
    case GeoFailureCode.offline:
    case GeoFailureCode.rateLimited:
    case GeoFailureCode.unknown:
      return true;
    case GeoFailureCode.deploymentConfigError:
    default:
      return false;
  }
}

class MockMarketplaceDataSource implements MarketplaceDataSource {
  const MockMarketplaceDataSource();

  @override
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> searchNearby(
    GeoDiscoveryNormalizedQuery query, {
    CancelToken? cancelToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (cancelToken?.isCancelled == true) {
      throw const GeoDiscoveryError(
        'Geo discovery request was cancelled.',
        code: GeoFailureCode.aborted,
        retryable: false,
      );
    }

    final fetchedAt = DateTime.now();
    final center = GeoPoint(
      latitude: query.latitude,
      longitude: query.longitude,
    );
    final results = <ServiceType, GeoDiscoveryPage<Map<String, Object?>>>{};
    final partialFailures = <GeoDiscoveryPartialFailure>[];

    for (final serviceType in query.serviceTypes) {
      final items =
          _itemsFor(
              serviceType,
              center,
            ).where((item) => item.distanceKm <= query.radiusKm).toList()
            ..sort((left, right) => _compare(left, right, query.sort));
      final offset = _parseCursor(
        query.cursors[serviceType],
        query.queryFingerprint,
        serviceType,
      );
      final pageItems = items.skip(offset).take(query.pageSize).toList();
      final nextOffset = offset + query.pageSize;
      results[serviceType] = GeoDiscoveryPage<Map<String, Object?>>(
        fetchedAt: fetchedAt,
        isStale: false,
        items: pageItems,
        nextCursor: nextOffset < items.length
            ? _cursorFor(query.queryFingerprint, serviceType, nextOffset)
            : null,
        queryFingerprint: query.queryFingerprint,
        schemaVersion: query.schemaVersion,
        source: GeoResultSource.mock,
      );
    }

    return GeoDiscoveryBatchResult<Map<String, Object?>>(
      fetchedAt: fetchedAt,
      partialFailures: partialFailures,
      queryFingerprint: query.queryFingerprint,
      results: results,
      schemaVersion: GeoDiscoveryConfig.schemaVersion,
      source: GeoResultSource.mock,
    );
  }

  List<GeoDiscoveryEntity<Map<String, Object?>>> _itemsFor(
    ServiceType serviceType,
    GeoPoint center,
  ) {
    if (serviceType == ServiceType.parking) {
      return mockParkingSpots.map((spot) {
        final distanceKm = roundDistanceKm(
          haversineDistanceKm(center, spot.location),
        );
        final updated = spot.copyWith(distanceKm: distanceKm);
        final vehicleFit = _vehicleFitFor(updated);
        return GeoDiscoveryEntity<Map<String, Object?>>(
          availabilityStatus: spot.slotsAvailable <= 0
              ? AvailabilityStatus.unavailable
              : spot.slotsAvailable <= 2
              ? AvailabilityStatus.limited
              : AvailabilityStatus.available,
          currency: spot.currency,
          distanceKm: distanceKm,
          entity: {
            ...updated.toJson(),
            'supportedVehicleTypes': _supportedVehicleTypesFor(vehicleFit),
            'vehicleFit': vehicleFit,
            'vehicle_fit': vehicleFit,
          },
          id: spot.id,
          imageUrl: spot.imageUrl,
          location: spot.location,
          price: spot.price,
          rating: spot.rating,
          serviceType: ServiceType.parking,
          title: spot.title,
        );
      }).toList();
    }

    final titlePrefix = serviceType == ServiceType.rental
        ? 'Rental'
        : 'Service';
    final location = serviceType == ServiceType.rental
        ? const GeoPoint(latitude: 13.0732, longitude: 80.2609)
        : const GeoPoint(latitude: 13.0780, longitude: 80.2633);
    final distanceKm = roundDistanceKm(haversineDistanceKm(center, location));

    return [
      GeoDiscoveryEntity<Map<String, Object?>>(
        availabilityStatus: AvailabilityStatus.available,
        currency: 'INR',
        distanceKm: distanceKm,
        entity: {
          'id': '${serviceType.apiValue}-egmore-01',
          'title': '$titlePrefix near Egmore',
        },
        id: '${serviceType.apiValue}-egmore-01',
        imageUrl: serviceType == ServiceType.rental
            ? 'https://images.unsplash.com/photo-1558981806-ec527fa84c39'
            : 'https://images.unsplash.com/photo-1607860108855-64acf2078ed9',
        location: location,
        price: serviceType == ServiceType.rental ? 550 : 399,
        rating: 4.8,
        serviceType: serviceType,
        title: '$titlePrefix near Egmore',
      ),
    ];
  }

  int _compare(
    GeoDiscoveryEntity<Map<String, Object?>> left,
    GeoDiscoveryEntity<Map<String, Object?>> right,
    GeoSortKey sort,
  ) {
    switch (sort) {
      case GeoSortKey.price:
        return (left.price ?? 1 << 31).compareTo(right.price ?? 1 << 31);
      case GeoSortKey.rating:
        return (right.rating ?? 0).compareTo(left.rating ?? 0);
      case GeoSortKey.distance:
        return left.distanceKm.compareTo(right.distanceKm);
    }
  }

  String _vehicleFitFor(ParkingSpot spot) {
    final title = spot.title.toLowerCase();
    if (title.contains('bike') || title.contains('two wheeler')) {
      return 'bike';
    }

    if (spot.amenities.contains(ParkingAmenity.twoWheeler)) {
      return 'both';
    }

    return 'car';
  }

  List<String> _supportedVehicleTypesFor(String vehicleFit) {
    switch (vehicleFit) {
      case 'bike':
        return const ['bike'];
      case 'both':
        return const ['bike', 'car'];
      case 'car':
      default:
        return const ['car'];
    }
  }

  String _cursorFor(
    String queryFingerprint,
    ServiceType serviceType,
    int offset,
  ) => '$queryFingerprint::${serviceType.apiValue}::$offset';

  int _parseCursor(
    String? cursor,
    String queryFingerprint,
    ServiceType serviceType,
  ) {
    if (cursor == null) return 0;
    final parts = cursor.split('::');
    if (parts.length != 3 ||
        parts[0] != queryFingerprint ||
        parts[1] != serviceType.apiValue) {
      throw const GeoDiscoveryError(
        'Geo discovery cursor does not match the current query.',
        code: GeoFailureCode.invalidCursor,
      );
    }
    final offset = int.tryParse(parts[2]);
    if (offset == null || offset < 0) {
      throw const GeoDiscoveryError(
        'Geo discovery cursor offset is invalid.',
        code: GeoFailureCode.invalidCursor,
      );
    }
    return offset;
  }
}

MarketplaceDataSource createMarketplaceDataSource(ApiClient apiClient) =>
    AppConfig.useMockGeoData
    ? const MockMarketplaceDataSource()
    : RestMarketplaceDataSource(apiClient);
