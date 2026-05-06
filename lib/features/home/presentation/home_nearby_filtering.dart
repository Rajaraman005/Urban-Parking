import '../../../core/utils/geo_discovery/geo_types.dart';

enum HomeNearbyVehicleFilter { bike, car }

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

    final distanceCompare = left.item.distanceKm.compareTo(right.item.distanceKm);
    if (distanceCompare != 0) {
      return distanceCompare;
    }

    return (right.item.rating ?? 0).compareTo(left.item.rating ?? 0);
  });

  return matches.map((entry) => entry.item).toList(growable: false);
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

int _matchScoreFor(
  HomeNearbyVehicleFilter filter,
  _VehicleSupport support,
) {
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

_VehicleSupport? _vehicleSupportFromExplicitFields(Map<String, Object?> entity) {
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
  return value == 'car' ||
      value == 'cars' ||
      value == 'fourwheeler';
}
