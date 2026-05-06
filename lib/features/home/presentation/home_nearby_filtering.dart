import '../../../core/utils/geo_discovery/geo_types.dart';

enum HomeNearbyVehicleFilter { bike, car }

enum HomeNearbySortOption { nearby, lowPrice, highRated }

enum HomeNearbyQuickFilter { availableNow, covered, evCharging, security }

class HomeNearbyFilterSelection {
  const HomeNearbyFilterSelection({
    this.sort = HomeNearbySortOption.nearby,
    this.quickFilters = const {},
  });

  static const defaults = HomeNearbyFilterSelection();

  final Set<HomeNearbyQuickFilter> quickFilters;
  final HomeNearbySortOption sort;

  bool get isDefault =>
      sort == HomeNearbySortOption.nearby && quickFilters.isEmpty;

  HomeNearbyFilterSelection copyWith({
    Set<HomeNearbyQuickFilter>? quickFilters,
    HomeNearbySortOption? sort,
  }) {
    return HomeNearbyFilterSelection(
      quickFilters: quickFilters ?? this.quickFilters,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is HomeNearbyFilterSelection &&
        other.sort == sort &&
        other.quickFilters.length == quickFilters.length &&
        other.quickFilters.containsAll(quickFilters);
  }

  @override
  int get hashCode {
    var filtersHash = 0;
    for (final filter in quickFilters) {
      filtersHash ^= filter.hashCode;
    }
    return Object.hash(sort, filtersHash);
  }
}

extension HomeNearbyVehicleFilterCopy on HomeNearbyVehicleFilter {
  String get label => switch (this) {
    HomeNearbyVehicleFilter.bike => 'Bike',
    HomeNearbyVehicleFilter.car => 'Cars',
  };

  String get nearbySubtitle => switch (this) {
    HomeNearbyVehicleFilter.bike => 'Bike spaces from your location',
    HomeNearbyVehicleFilter.car => 'Car spaces from your location',
  };

  String get emptyTitle => switch (this) {
    HomeNearbyVehicleFilter.bike => 'No bike spaces nearby',
    HomeNearbyVehicleFilter.car => 'No car spaces nearby',
  };

  String get emptyMessage => switch (this) {
    HomeNearbyVehicleFilter.bike =>
      'We could not find a nearby bike-friendly spot in this area yet.',
    HomeNearbyVehicleFilter.car =>
      'We could not find a nearby car-friendly spot in this area yet.',
  };
}

List<GeoDiscoveryEntity<Map<String, Object?>>> applyHomeNearbyFilters(
  List<GeoDiscoveryEntity<Map<String, Object?>>> items, {
  required HomeNearbyFilterSelection filters,
  required HomeNearbyVehicleFilter? vehicleFilter,
}) {
  final filteredItems = filterHomeNearbyItems(
    items,
    vehicleFilter,
  ).where((item) => _matchesQuickFilters(item, filters.quickFilters)).toList();

  filteredItems.sort(
    (left, right) => _compareNearbyItems(left, right, filters.sort),
  );
  return filteredItems;
}

List<GeoDiscoveryEntity<Map<String, Object?>>> filterHomeNearbyItems(
  List<GeoDiscoveryEntity<Map<String, Object?>>> items,
  HomeNearbyVehicleFilter? filter,
) {
  if (filter == null) {
    return items;
  }

  final matches = <_ScoredNearbyItem>[];
  for (final item in items) {
    final support = _vehicleSupportFor(item);
    final score = _matchScoreFor(filter, support);
    if (score > 0) {
      matches.add(_ScoredNearbyItem(item: item, score: score));
    }
  }

  matches.sort((left, right) {
    final scoreCompare = right.score.compareTo(left.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }

    final distanceCompare = left.item.distanceKm.compareTo(
      right.item.distanceKm,
    );
    if (distanceCompare != 0) {
      return distanceCompare;
    }

    return (right.item.rating ?? 0).compareTo(left.item.rating ?? 0);
  });

  return matches.map((entry) => entry.item).toList(growable: false);
}

bool _matchesQuickFilters(
  GeoDiscoveryEntity<Map<String, Object?>> item,
  Set<HomeNearbyQuickFilter> filters,
) {
  for (final filter in filters) {
    final matches = switch (filter) {
      HomeNearbyQuickFilter.availableNow => _isAvailableNow(item),
      HomeNearbyQuickFilter.covered => _containsAnyNearbyKeyword(item, const [
        'covered',
        'garage',
        'basement',
        'indoor',
        'sheltered',
        'roofed',
      ]),
      HomeNearbyQuickFilter.evCharging =>
        _containsAnyNearbyKeyword(item, const [
          'ev',
          'evcharging',
          'electricvehicle',
          'electricvehiclecharging',
          'charging',
          'charger',
        ]),
      HomeNearbyQuickFilter.security => _containsAnyNearbyKeyword(item, const [
        'security',
        'secure',
        'secured',
        'cctv',
        'guard',
        'surveillance',
      ]),
    };

    if (!matches) {
      return false;
    }
  }

  return true;
}

bool _isAvailableNow(GeoDiscoveryEntity<Map<String, Object?>> item) {
  if (item.availabilityStatus != AvailabilityStatus.available &&
      item.availabilityStatus != AvailabilityStatus.limited) {
    return false;
  }

  final slotsAvailable = _intValue(
    item.entity['slotsAvailable'] ??
        item.entity['slots_available'] ??
        item.entity['availableSlots'] ??
        item.entity['available_slots'],
  );

  return slotsAvailable == null || slotsAvailable > 0;
}

int _compareNearbyItems(
  GeoDiscoveryEntity<Map<String, Object?>> left,
  GeoDiscoveryEntity<Map<String, Object?>> right,
  HomeNearbySortOption sort,
) {
  return switch (sort) {
    HomeNearbySortOption.nearby => _compareByDistanceThenRating(left, right),
    HomeNearbySortOption.lowPrice => _compareByPriceThenDistance(left, right),
    HomeNearbySortOption.highRated => _compareByRatingThenDistance(left, right),
  };
}

int _compareByDistanceThenRating(
  GeoDiscoveryEntity<Map<String, Object?>> left,
  GeoDiscoveryEntity<Map<String, Object?>> right,
) {
  final distanceCompare = left.distanceKm.compareTo(right.distanceKm);
  if (distanceCompare != 0) {
    return distanceCompare;
  }

  return (right.rating ?? 0).compareTo(left.rating ?? 0);
}

int _compareByPriceThenDistance(
  GeoDiscoveryEntity<Map<String, Object?>> left,
  GeoDiscoveryEntity<Map<String, Object?>> right,
) {
  final priceCompare = _compareNullableNumAsc(left.price, right.price);
  if (priceCompare != 0) {
    return priceCompare;
  }

  return _compareByDistanceThenRating(left, right);
}

int _compareByRatingThenDistance(
  GeoDiscoveryEntity<Map<String, Object?>> left,
  GeoDiscoveryEntity<Map<String, Object?>> right,
) {
  final ratingCompare = (right.rating ?? 0).compareTo(left.rating ?? 0);
  if (ratingCompare != 0) {
    return ratingCompare;
  }

  return left.distanceKm.compareTo(right.distanceKm);
}

int _compareNullableNumAsc(num? left, num? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

class _ScoredNearbyItem {
  const _ScoredNearbyItem({required this.item, required this.score});

  final GeoDiscoveryEntity<Map<String, Object?>> item;
  final int score;
}

class _VehicleSupport {
  const _VehicleSupport({
    required this.confidence,
    required this.supportsBike,
    required this.supportsCar,
  });

  const _VehicleSupport.none()
    : confidence = 0,
      supportsBike = false,
      supportsCar = false;

  final int confidence;
  final bool supportsBike;
  final bool supportsCar;
}

int _matchScoreFor(HomeNearbyVehicleFilter filter, _VehicleSupport support) {
  if (filter == HomeNearbyVehicleFilter.bike) {
    if (!support.supportsBike) {
      return 0;
    }
    return (support.supportsCar ? 90 : 100) + support.confidence;
  }

  if (!support.supportsCar) {
    return 0;
  }
  return (support.supportsBike ? 90 : 100) + support.confidence;
}

_VehicleSupport _vehicleSupportFor(
  GeoDiscoveryEntity<Map<String, Object?>> item,
) {
  if (item.serviceType != ServiceType.parking) {
    return const _VehicleSupport.none();
  }

  final entity = item.entity;
  final explicit = _vehicleSupportFromExplicitFields(entity);
  if (explicit != null) {
    return explicit;
  }

  final amenityValues = _normalizedValues(entity['amenities']);
  final hasBikeAmenity = amenityValues.any(_isBikeToken);

  final textValues = [
    item.title,
    entity['title']?.toString(),
    entity['address']?.toString(),
    entity['locality']?.toString(),
    entity['parkingType']?.toString(),
    entity['parking_type']?.toString(),
  ].whereType<String>().map(_normalizeToken).where((value) => value.isNotEmpty);

  final hasBikeKeyword = textValues.any(_containsBikeKeyword);
  final hasCarKeyword = textValues.any(_containsCarKeyword);
  final hasParkingKeyword = textValues.any(_containsParkingKeyword);

  if (hasBikeAmenity && hasCarKeyword) {
    return const _VehicleSupport(
      supportsBike: true,
      supportsCar: true,
      confidence: 1,
    );
  }

  if (hasBikeAmenity || hasBikeKeyword) {
    return const _VehicleSupport(
      supportsBike: true,
      supportsCar: false,
      confidence: 1,
    );
  }

  if (hasCarKeyword) {
    return const _VehicleSupport(
      supportsBike: false,
      supportsCar: true,
      confidence: 1,
    );
  }

  if (hasParkingKeyword) {
    return const _VehicleSupport(
      supportsBike: false,
      supportsCar: true,
      confidence: 1,
    );
  }

  return const _VehicleSupport.none();
}

bool _containsAnyNearbyKeyword(
  GeoDiscoveryEntity<Map<String, Object?>> item,
  List<String> keywords,
) {
  final normalizedKeywords = keywords.map(_normalizeToken).toList();
  return _searchableNearbyValues(item).any(
    (value) => normalizedKeywords.any((keyword) => value.contains(keyword)),
  );
}

List<String> _searchableNearbyValues(
  GeoDiscoveryEntity<Map<String, Object?>> item,
) {
  final entity = item.entity;
  final values = <String>[
    item.title,
    entity['title']?.toString() ?? '',
    entity['address']?.toString() ?? '',
    entity['locality']?.toString() ?? '',
    entity['description']?.toString() ?? '',
    entity['parkingType']?.toString() ?? '',
    entity['parking_type']?.toString() ?? '',
  ].map(_normalizeToken).where((value) => value.isNotEmpty).toList();

  for (final key in const [
    'amenities',
    'features',
    'tags',
    'highlights',
    'facilityFeatures',
    'facility_features',
  ]) {
    values.addAll(_normalizedValues(entity[key]));
  }

  return values;
}

_VehicleSupport? _vehicleSupportFromExplicitFields(
  Map<String, Object?> entity,
) {
  for (final key in const [
    'vehicleFit',
    'vehicle_fit',
    'vehicleType',
    'vehicle_type',
  ]) {
    final support = _vehicleSupportFromString(entity[key]?.toString());
    if (support != null) {
      return support;
    }
  }

  for (final key in const [
    'supportedVehicleTypes',
    'supported_vehicle_types',
    'vehicleFits',
    'vehicle_fits',
  ]) {
    final support = _vehicleSupportFromCollection(entity[key]);
    if (support != null) {
      return support;
    }
  }

  return null;
}

_VehicleSupport? _vehicleSupportFromString(String? rawValue) {
  final value = _normalizeToken(rawValue);
  if (value.isEmpty) {
    return null;
  }

  if (value == 'both' ||
      value == 'bikecar' ||
      value == 'carbike' ||
      value == 'bikeandcar' ||
      value == 'carandbike') {
    return const _VehicleSupport(
      supportsBike: true,
      supportsCar: true,
      confidence: 3,
    );
  }

  if (_isBikeToken(value)) {
    return const _VehicleSupport(
      supportsBike: true,
      supportsCar: false,
      confidence: 3,
    );
  }

  if (_isCarToken(value)) {
    return const _VehicleSupport(
      supportsBike: false,
      supportsCar: true,
      confidence: 3,
    );
  }

  return null;
}

_VehicleSupport? _vehicleSupportFromCollection(Object? rawValue) {
  final values = _normalizedValues(rawValue);
  if (values.isEmpty) {
    return null;
  }

  final supportsBike = values.any(_isBikeToken);
  final supportsCar = values.any(_isCarToken);
  if (!supportsBike && !supportsCar) {
    return null;
  }

  return _VehicleSupport(
    supportsBike: supportsBike,
    supportsCar: supportsCar,
    confidence: 2,
  );
}

List<String> _normalizedValues(Object? rawValue) {
  final values = <String>[];

  void collect(Object? value) {
    if (value == null) {
      return;
    }

    if (value is Iterable) {
      for (final entry in value) {
        collect(entry);
      }
      return;
    }

    if (value is String) {
      for (final part in value.split(',')) {
        final normalized = _normalizeToken(part);
        if (normalized.isNotEmpty) {
          values.add(normalized);
        }
      }
      return;
    }

    final normalized = _normalizeToken(value.toString());
    if (normalized.isNotEmpty) {
      values.add(normalized);
    }
  }

  collect(rawValue);
  return values;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

String _normalizeToken(String? value) {
  return (value ?? '')
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

bool _containsBikeKeyword(String value) {
  return value.contains('bike') ||
      value.contains('twowheeler') ||
      value.contains('motorcycle') ||
      value.contains('scooter');
}

bool _containsCarKeyword(String value) {
  return value.contains('car') ||
      value.contains('sedan') ||
      value.contains('suv') ||
      value.contains('hatchback');
}

bool _containsParkingKeyword(String value) {
  return value.contains('parking') ||
      value.contains('garage') ||
      value.contains('basement') ||
      value.contains('driveway') ||
      value.contains('covered') ||
      value.contains('open');
}

bool _isBikeToken(String value) {
  return value == 'bike' ||
      value == 'bikes' ||
      value == 'twowheeler' ||
      value == 'motorcycle' ||
      value == 'scooter';
}

bool _isCarToken(String value) {
  return value == 'car' || value == 'cars' || value == 'fourwheeler';
}
