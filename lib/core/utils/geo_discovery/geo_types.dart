import 'package:dio/dio.dart';

enum ServiceType {
  parking('parking'),
  rental('rental'),
  service('service');

  const ServiceType(this.apiValue);
  final String apiValue;

  static ServiceType fromApi(String value) => ServiceType.values.firstWhere(
    (entry) => entry.apiValue == value,
    orElse: () => ServiceType.parking,
  );
}

enum AvailabilityStatus {
  available('available'),
  limited('limited'),
  unavailable('unavailable'),
  unknown('unknown');

  const AvailabilityStatus(this.apiValue);
  final String apiValue;

  static AvailabilityStatus fromApi(String value) =>
      AvailabilityStatus.values.firstWhere(
        (entry) => entry.apiValue == value,
        orElse: () => AvailabilityStatus.unknown,
      );
}

enum GeoSortKey {
  distance('distance'),
  price('price'),
  rating('rating');

  const GeoSortKey(this.apiValue);
  final String apiValue;

  static GeoSortKey fromApi(String value) => GeoSortKey.values.firstWhere(
    (entry) => entry.apiValue == value,
    orElse: () => GeoSortKey.distance,
  );
}

enum GeoResultSource {
  network('network'),
  cache('cache'),
  mock('mock');

  const GeoResultSource(this.apiValue);
  final String apiValue;

  static GeoResultSource fromApi(String value) =>
      GeoResultSource.values.firstWhere(
        (entry) => entry.apiValue == value,
        orElse: () => GeoResultSource.network,
      );
}

enum GeoFailureCode {
  aborted,
  backendTimeout,
  contractMismatch,
  databaseError,
  deploymentConfigError,
  gpsDenied,
  gpsTimeout,
  invalidCursor,
  networkError,
  offline,
  rateLimited,
  schemaVersionUnsupported,
  serverConfigError,
  unknown;

  String get apiValue {
    switch (this) {
      case GeoFailureCode.backendTimeout:
        return 'backend_timeout';
      case GeoFailureCode.contractMismatch:
        return 'contract_mismatch';
      case GeoFailureCode.databaseError:
        return 'database_error';
      case GeoFailureCode.deploymentConfigError:
        return 'deployment_misconfiguration';
      case GeoFailureCode.gpsDenied:
        return 'gps_denied';
      case GeoFailureCode.gpsTimeout:
        return 'gps_timeout';
      case GeoFailureCode.invalidCursor:
        return 'invalid_cursor';
      case GeoFailureCode.networkError:
        return 'network_error';
      case GeoFailureCode.rateLimited:
        return 'rate_limited';
      case GeoFailureCode.schemaVersionUnsupported:
        return 'schema_version_unsupported';
      case GeoFailureCode.serverConfigError:
        return 'server_config_error';
      case GeoFailureCode.aborted:
      case GeoFailureCode.offline:
      case GeoFailureCode.unknown:
        return name;
    }
  }

  static GeoFailureCode fromApi(String? value) {
    return GeoFailureCode.values.firstWhere(
      (entry) => entry.apiValue == value,
      orElse: () => GeoFailureCode.unknown,
    );
  }
}

class GeoDiscoveryError implements Exception {
  const GeoDiscoveryError(
    this.message, {
    this.code = GeoFailureCode.unknown,
    this.retryAfter,
    this.retryable = true,
  });

  final String message;
  final GeoFailureCode code;
  final Duration? retryAfter;
  final bool retryable;

  @override
  String toString() => message;
}

class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  static GeoPoint fromJson(Map<String, Object?> json) => GeoPoint(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

typedef GeoDiscoveryFilters = Map<String, Object?>;

class GeoDiscoveryQuery {
  const GeoDiscoveryQuery({
    required this.latitude,
    required this.longitude,
    required this.serviceType,
    this.cursor,
    this.filters,
    this.pageSize,
    this.radiusKm,
    this.requestId,
    this.sort,
  });

  final double latitude;
  final double longitude;
  final ServiceType serviceType;
  final String? cursor;
  final GeoDiscoveryFilters? filters;
  final int? pageSize;
  final double? radiusKm;
  final String? requestId;
  final GeoSortKey? sort;
}

class GeoDiscoveryBatchQuery {
  const GeoDiscoveryBatchQuery({
    required this.latitude,
    required this.longitude,
    required this.serviceTypes,
    this.cursors,
    this.filters,
    this.pageSize,
    this.radiusKm,
    this.requestId,
    this.sort,
  });

  final double latitude;
  final double longitude;
  final List<ServiceType> serviceTypes;
  final Map<ServiceType, String>? cursors;
  final Map<String, Object?>? filters;
  final int? pageSize;
  final double? radiusKm;
  final String? requestId;
  final GeoSortKey? sort;
}

class GeoDiscoveryNormalizedQuery {
  const GeoDiscoveryNormalizedQuery({
    required this.latitude,
    required this.longitude,
    required this.serviceTypes,
    required this.cursors,
    required this.filtersByService,
    required this.pageSize,
    required this.queryFingerprint,
    required this.radiusKm,
    required this.requestId,
    required this.roundedGeocell,
    required this.schemaVersion,
    required this.sort,
  });

  final double latitude;
  final double longitude;
  final List<ServiceType> serviceTypes;
  final Map<ServiceType, String> cursors;
  final Map<ServiceType, GeoDiscoveryFilters> filtersByService;
  final int pageSize;
  final String queryFingerprint;
  final double radiusKm;
  final String requestId;
  final String roundedGeocell;
  final int schemaVersion;
  final GeoSortKey sort;

  Map<String, Object?> toRequestJson() => {
    'cursors': cursors.map((key, value) => MapEntry(key.apiValue, value)),
    'filters': filtersByService.map(
      (key, value) => MapEntry(key.apiValue, value),
    ),
    'latitude': latitude,
    'longitude': longitude,
    'pageSize': pageSize,
    'queryFingerprint': queryFingerprint,
    'radiusKm': radiusKm,
    'requestId': requestId,
    'schemaVersion': schemaVersion,
    'serviceTypes': serviceTypes.map((entry) => entry.apiValue).toList(),
    'sort': sort.apiValue,
  };
}

class GeoDiscoveryEntity<T> {
  const GeoDiscoveryEntity({
    required this.availabilityStatus,
    required this.distanceKm,
    required this.entity,
    required this.id,
    required this.location,
    required this.serviceType,
    required this.title,
    this.currency,
    this.imageUrl,
    this.price,
    this.rating,
  });

  final AvailabilityStatus availabilityStatus;
  final String? currency;
  final double distanceKm;
  final T entity;
  final String id;
  final String? imageUrl;
  final GeoPoint location;
  final num? price;
  final num? rating;
  final ServiceType serviceType;
  final String title;

  Map<String, Object?> toJson(Object? Function(T value) entityToJson) => {
    'availabilityStatus': availabilityStatus.apiValue,
    'currency': currency,
    'distanceKm': distanceKm,
    'entity': entityToJson(entity),
    'id': id,
    'imageUrl': imageUrl,
    'location': location.toJson(),
    'price': price,
    'rating': rating,
    'serviceType': serviceType.apiValue,
    'title': title,
  };

  static GeoDiscoveryEntity<T> fromJson<T>(
    Map<String, Object?> json,
    T Function(Object? json) entityFromJson,
  ) => GeoDiscoveryEntity<T>(
    availabilityStatus: AvailabilityStatus.fromApi(
      json['availabilityStatus'].toString(),
    ),
    currency: json['currency']?.toString(),
    distanceKm: (json['distanceKm'] as num).toDouble(),
    entity: entityFromJson(json['entity']),
    id: json['id'].toString(),
    imageUrl: json['imageUrl']?.toString(),
    location: GeoPoint.fromJson(
      Map<String, Object?>.from(json['location'] as Map),
    ),
    price: json['price'] as num?,
    rating: json['rating'] as num?,
    serviceType: ServiceType.fromApi(json['serviceType'].toString()),
    title: json['title'].toString(),
  );
}

class GeoDiscoveryPage<T> {
  const GeoDiscoveryPage({
    required this.fetchedAt,
    required this.isStale,
    required this.items,
    required this.queryFingerprint,
    required this.schemaVersion,
    required this.source,
    this.cursorInvalidated = false,
    this.nextCursor,
  });

  final bool cursorInvalidated;
  final DateTime fetchedAt;
  final bool isStale;
  final List<GeoDiscoveryEntity<T>> items;
  final String? nextCursor;
  final String queryFingerprint;
  final int schemaVersion;
  final GeoResultSource source;

  GeoDiscoveryPage<T> copyWith({
    bool? cursorInvalidated,
    bool? isStale,
    GeoResultSource? source,
  }) => GeoDiscoveryPage<T>(
    cursorInvalidated: cursorInvalidated ?? this.cursorInvalidated,
    fetchedAt: fetchedAt,
    isStale: isStale ?? this.isStale,
    items: items,
    nextCursor: nextCursor,
    queryFingerprint: queryFingerprint,
    schemaVersion: schemaVersion,
    source: source ?? this.source,
  );

  Map<String, Object?> toJson(Object? Function(T value) entityToJson) => {
    'cursorInvalidated': cursorInvalidated,
    'fetchedAt': fetchedAt.toIso8601String(),
    'isStale': isStale,
    'items': items.map((entry) => entry.toJson(entityToJson)).toList(),
    'nextCursor': nextCursor,
    'queryFingerprint': queryFingerprint,
    'schemaVersion': schemaVersion,
    'source': source.apiValue,
  };

  static GeoDiscoveryPage<T> fromJson<T>(
    Map<String, Object?> json,
    T Function(Object? json) entityFromJson,
  ) => GeoDiscoveryPage<T>(
    cursorInvalidated: json['cursorInvalidated'] == true,
    fetchedAt: DateTime.parse(json['fetchedAt'].toString()),
    isStale: json['isStale'] == true,
    items: (json['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) => GeoDiscoveryEntity.fromJson<T>(
            Map<String, Object?>.from(entry as Map),
            entityFromJson,
          ),
        )
        .toList(),
    nextCursor: json['nextCursor']?.toString(),
    queryFingerprint: json['queryFingerprint'].toString(),
    schemaVersion: (json['schemaVersion'] as num).toInt(),
    source: GeoResultSource.fromApi(json['source'].toString()),
  );
}

class GeoDiscoveryPartialFailure {
  const GeoDiscoveryPartialFailure({
    required this.code,
    required this.message,
    required this.retryable,
    required this.serviceType,
  });

  final GeoFailureCode code;
  final String message;
  final bool retryable;
  final ServiceType serviceType;

  Map<String, Object?> toJson() => {
    'code': code.apiValue,
    'message': message,
    'retryable': retryable,
    'serviceType': serviceType.apiValue,
  };

  static GeoDiscoveryPartialFailure fromJson(Map<String, Object?> json) =>
      GeoDiscoveryPartialFailure(
        code: GeoFailureCode.fromApi(json['code']?.toString()),
        message: json['message'].toString(),
        retryable: json['retryable'] == true,
        serviceType: ServiceType.fromApi(json['serviceType'].toString()),
      );
}

class GeoDiscoveryBatchResult<T> {
  const GeoDiscoveryBatchResult({
    required this.fetchedAt,
    required this.partialFailures,
    required this.queryFingerprint,
    required this.results,
    required this.schemaVersion,
    required this.source,
  });

  final DateTime fetchedAt;
  final List<GeoDiscoveryPartialFailure> partialFailures;
  final String queryFingerprint;
  final Map<ServiceType, GeoDiscoveryPage<T>> results;
  final int schemaVersion;
  final GeoResultSource source;

  GeoDiscoveryBatchResult<T> copyWith({
    Map<ServiceType, GeoDiscoveryPage<T>>? results,
    GeoResultSource? source,
  }) => GeoDiscoveryBatchResult<T>(
    fetchedAt: fetchedAt,
    partialFailures: partialFailures,
    queryFingerprint: queryFingerprint,
    results: results ?? this.results,
    schemaVersion: schemaVersion,
    source: source ?? this.source,
  );

  Map<String, Object?> toJson(Object? Function(T value) entityToJson) => {
    'fetchedAt': fetchedAt.toIso8601String(),
    'partialFailures': partialFailures.map((entry) => entry.toJson()).toList(),
    'queryFingerprint': queryFingerprint,
    'results': results.map(
      (key, value) => MapEntry(key.apiValue, value.toJson(entityToJson)),
    ),
    'schemaVersion': schemaVersion,
    'source': source.apiValue,
  };

  static GeoDiscoveryBatchResult<T> fromJson<T>(
    Map<String, Object?> json,
    T Function(Object? json) entityFromJson,
  ) {
    final rawResults = Map<String, Object?>.from(json['results'] as Map);
    return GeoDiscoveryBatchResult<T>(
      fetchedAt: DateTime.parse(json['fetchedAt'].toString()),
      partialFailures: (json['partialFailures'] as List<dynamic>? ?? const [])
          .map(
            (entry) => GeoDiscoveryPartialFailure.fromJson(
              Map<String, Object?>.from(entry as Map),
            ),
          )
          .toList(),
      queryFingerprint: json['queryFingerprint'].toString(),
      results: rawResults.map(
        (key, value) => MapEntry(
          ServiceType.fromApi(key),
          GeoDiscoveryPage.fromJson<T>(
            Map<String, Object?>.from(value as Map),
            entityFromJson,
          ),
        ),
      ),
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      source: GeoResultSource.fromApi(json['source'].toString()),
    );
  }
}

abstract interface class GeoDiscoveryRepository {
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> searchNearby(
    GeoDiscoveryNormalizedQuery query, {
    CancelToken? cancelToken,
  });
}

abstract interface class MarketplaceDataSource {
  Future<GeoDiscoveryBatchResult<Map<String, Object?>>> searchNearby(
    GeoDiscoveryNormalizedQuery query, {
    CancelToken? cancelToken,
  });
}
