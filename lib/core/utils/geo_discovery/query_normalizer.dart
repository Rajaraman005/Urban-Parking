import 'dart:convert';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../../config/geo_discovery_config.dart';
import 'geo_types.dart';

const _uuid = Uuid();

double _clampDouble(double value, double min, double max) =>
    math.min(max, math.max(min, value));

int _clampInt(int value, int min, int max) =>
    math.min(max, math.max(min, value));

String stableStringify(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(stableStringify).join(',')}]';
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return '{${entries.map((entry) => '${jsonEncode(entry.key.toString())}:${stableStringify(entry.value)}').join(',')}}';
  }
  return jsonEncode(value.toString());
}

String roundedGeocell(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

GeoDiscoveryNormalizedQuery normalizeGeoQuery(GeoDiscoveryQuery query) {
  return normalizeGeoBatchQuery(
    GeoDiscoveryBatchQuery(
      cursors: query.cursor == null ? null : {query.serviceType: query.cursor!},
      filters: query.filters,
      latitude: query.latitude,
      longitude: query.longitude,
      pageSize: query.pageSize,
      radiusKm: query.radiusKm,
      requestId: query.requestId,
      serviceTypes: [query.serviceType],
      sort: query.sort,
    ),
  );
}

GeoDiscoveryNormalizedQuery normalizeGeoBatchQuery(
  GeoDiscoveryBatchQuery query,
) {
  final serviceTypes = <ServiceType>{
    ...query.serviceTypes,
  }.toList(growable: false);
  final radiusKm = _clampDouble(
    query.radiusKm ?? GeoDiscoveryConfig.defaultRadiusKm,
    GeoDiscoveryConfig.minRadiusKm,
    GeoDiscoveryConfig.maxRadiusKm,
  );
  final pageSize = _clampInt(
    query.pageSize ?? GeoDiscoveryConfig.defaultPageSize,
    1,
    GeoDiscoveryConfig.maxPageSize,
  );
  final sort = query.sort ?? GeoSortKey.distance;
  final geocell = roundedGeocell(query.latitude, query.longitude);
  final filtersByService = _normalizeFilters(serviceTypes, query.filters);
  final fingerprint = _buildFingerprint(
    serviceTypes,
    geocell,
    radiusKm,
    sort,
    filtersByService.map((key, value) => MapEntry(key.apiValue, value)),
  );

  return GeoDiscoveryNormalizedQuery(
    cursors: query.cursors ?? const {},
    filtersByService: filtersByService,
    latitude: query.latitude,
    longitude: query.longitude,
    pageSize: pageSize,
    queryFingerprint: fingerprint,
    radiusKm: radiusKm,
    requestId:
        query.requestId ??
        'geo-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 8)}',
    roundedGeocell: geocell,
    schemaVersion: GeoDiscoveryConfig.schemaVersion,
    serviceTypes: serviceTypes,
    sort: sort,
  );
}

Map<ServiceType, GeoDiscoveryFilters> _normalizeFilters(
  List<ServiceType> serviceTypes,
  Map<String, Object?>? filters,
) {
  if (filters == null || filters.isEmpty) return const {};

  final hasServiceKeys = serviceTypes.any((serviceType) {
    final entry = filters[serviceType.apiValue];
    return entry is Map;
  });

  if (!hasServiceKeys) {
    return {
      for (final serviceType in serviceTypes)
        serviceType: Map<String, Object?>.from(filters),
    };
  }

  return {
    for (final serviceType in serviceTypes)
      if (filters[serviceType.apiValue] is Map)
        serviceType: Map<String, Object?>.from(
          filters[serviceType.apiValue] as Map,
        ),
  };
}

String _buildFingerprint(
  List<ServiceType> serviceTypes,
  String geocell,
  double radiusKm,
  GeoSortKey sort,
  Object filters,
) => [
  'v${GeoDiscoveryConfig.schemaVersion}',
  serviceTypes.map((entry) => entry.apiValue).join(','),
  geocell,
  radiusKm.toStringAsFixed(2),
  sort.apiValue,
  stableStringify(filters),
].join('|');
