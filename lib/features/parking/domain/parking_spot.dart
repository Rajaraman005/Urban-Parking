import 'package:intl/intl.dart';

import '../../../core/utils/geo_discovery/geo_types.dart';

enum BookingCadence { hourly, daily, monthly }

enum ParkingAmenity { covered, security, evCharging, cctv, valet, twoWheeler }

class ParkingSpot {
  const ParkingSpot({
    required this.id,
    required this.title,
    required this.address,
    required this.locality,
    required this.distanceKm,
    required this.rating,
    required this.reviewCount,
    required this.price,
    required this.currency,
    required this.cadence,
    required this.availableFrom,
    required this.availableUntil,
    required this.slotsAvailable,
    required this.location,
    required this.amenities,
    required this.imageUrl,
    this.addressConfidence,
    this.addressPlaceId,
    this.addressProvider,
    this.availabilitySummary,
    this.availableFromDate,
    this.availableToDate,
    this.city,
    this.dailyEndMinute,
    this.dailyStartMinute,
    this.hostAvatarUrl,
    this.hostName,
    this.hostPhone,
    this.hostRole,
    this.isHostedByCurrentUser = false,
    this.listingRevision = 0,
    this.postalCode,
    this.updatedAt,
    this.version = 1,
    List<String>? imageUrls = const [],
  }) : _imageUrls = imageUrls;

  final String id;
  final String title;
  final String address;
  final String locality;
  final double distanceKm;
  final double rating;
  final int reviewCount;
  final int price;
  final String currency;
  final BookingCadence cadence;
  final DateTime availableFrom;
  final DateTime availableUntil;
  final String? availabilitySummary;
  final DateTime? availableFromDate;
  final DateTime? availableToDate;
  final int? dailyEndMinute;
  final int? dailyStartMinute;
  final int slotsAvailable;
  final GeoPoint location;
  final List<ParkingAmenity> amenities;
  final String imageUrl;
  final double? addressConfidence;
  final String? addressPlaceId;
  final String? addressProvider;
  final String? hostAvatarUrl;
  final String? hostName;
  final String? hostPhone;
  final String? hostRole;
  final String? city;
  final bool isHostedByCurrentUser;
  final int listingRevision;
  final String? postalCode;
  final DateTime? updatedAt;
  final int version;
  final List<String>? _imageUrls;

  List<String> get imageUrls {
    final urls = <String>{};
    for (final rawUrl in _imageUrls ?? const <String>[]) {
      final url = rawUrl.trim();
      if (url.isNotEmpty) {
        urls.add(url);
      }
    }

    final primary = imageUrl.trim();
    if (primary.isNotEmpty) {
      urls.add(primary);
    }

    return urls.toList(growable: false);
  }

  ParkingSpot copyWith({
    String? address,
    double? addressConfidence,
    String? addressPlaceId,
    String? addressProvider,
    List<ParkingAmenity>? amenities,
    DateTime? availableFrom,
    DateTime? availableFromDate,
    DateTime? availableToDate,
    DateTime? availableUntil,
    String? availabilitySummary,
    BookingCadence? cadence,
    String? city,
    String? currency,
    int? dailyEndMinute,
    int? dailyStartMinute,
    double? distanceKm,
    String? hostAvatarUrl,
    String? hostName,
    String? hostPhone,
    String? hostRole,
    String? imageUrl,
    List<String>? imageUrls,
    bool? isHostedByCurrentUser,
    int? listingRevision,
    String? locality,
    GeoPoint? location,
    String? postalCode,
    int? price,
    double? rating,
    int? reviewCount,
    int? slotsAvailable,
    String? title,
    DateTime? updatedAt,
    int? version,
  }) => ParkingSpot(
    id: id,
    title: title ?? this.title,
    address: address ?? this.address,
    locality: locality ?? this.locality,
    distanceKm: distanceKm ?? this.distanceKm,
    rating: rating ?? this.rating,
    reviewCount: reviewCount ?? this.reviewCount,
    price: price ?? this.price,
    currency: currency ?? this.currency,
    cadence: cadence ?? this.cadence,
    availableFrom: availableFrom ?? this.availableFrom,
    availableFromDate: availableFromDate ?? this.availableFromDate,
    availableToDate: availableToDate ?? this.availableToDate,
    availableUntil: availableUntil ?? this.availableUntil,
    availabilitySummary: availabilitySummary ?? this.availabilitySummary,
    slotsAvailable: slotsAvailable ?? this.slotsAvailable,
    location: location ?? this.location,
    amenities: amenities ?? this.amenities,
    imageUrl: imageUrl ?? this.imageUrl,
    addressConfidence: addressConfidence ?? this.addressConfidence,
    addressPlaceId: addressPlaceId ?? this.addressPlaceId,
    addressProvider: addressProvider ?? this.addressProvider,
    city: city ?? this.city,
    dailyEndMinute: dailyEndMinute ?? this.dailyEndMinute,
    dailyStartMinute: dailyStartMinute ?? this.dailyStartMinute,
    hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
    hostName: hostName ?? this.hostName,
    hostPhone: hostPhone ?? this.hostPhone,
    hostRole: hostRole ?? this.hostRole,
    isHostedByCurrentUser: isHostedByCurrentUser ?? this.isHostedByCurrentUser,
    listingRevision: listingRevision ?? this.listingRevision,
    postalCode: postalCode ?? this.postalCode,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    imageUrls: imageUrls ?? _imageUrls,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'address': address,
    'locality': locality,
    'distanceKm': distanceKm,
    'rating': rating,
    'reviewCount': reviewCount,
    'price': price,
    'currency': currency,
    'cadence': cadence.name,
    'availableFrom': availableFrom.toIso8601String(),
    'availableFromDate': availableFromDate?.toIso8601String(),
    'availableToDate': availableToDate?.toIso8601String(),
    'availableUntil': availableUntil.toIso8601String(),
    'availabilitySummary': availabilitySummary,
    'dailyEndMinute': dailyEndMinute,
    'dailyStartMinute': dailyStartMinute,
    'slotsAvailable': slotsAvailable,
    'location': location.toJson(),
    'amenities': amenities.map((entry) => entry.name).toList(),
    'imageUrl': imageUrl,
    'imageUrls': imageUrls,
    'addressConfidence': addressConfidence,
    'addressPlaceId': addressPlaceId,
    'addressProvider': addressProvider,
    'city': city,
    'hostAvatarUrl': hostAvatarUrl,
    'hostName': hostName,
    'hostPhone': hostPhone,
    'hostRole': hostRole,
    'isHostedByCurrentUser': isHostedByCurrentUser,
    'listingRevision': listingRevision,
    'postalCode': postalCode,
    'updatedAt': updatedAt?.toIso8601String(),
    'version': version,
  };

  static ParkingSpot fromDiscoveryEntity(
    GeoDiscoveryEntity<Map<String, Object?>> item,
  ) {
    final entity = Map<String, Object?>.from(item.entity);

    void setFallback(String key, Object? value) {
      if (value == null) return;
      final current = entity[key];
      if (current == null || (current is String && current.trim().isEmpty)) {
        entity[key] = value;
      }
    }

    setFallback('id', item.id);
    setFallback('title', item.title);
    setFallback('distanceKm', item.distanceKm);
    setFallback('currency', item.currency);
    setFallback('price', item.price);
    setFallback('rating', item.rating);
    setFallback('imageUrl', item.imageUrl);
    if (item.imageUrl != null && entity['imageUrls'] == null) {
      entity['imageUrls'] = [item.imageUrl];
    }
    setFallback('location', item.location.toJson());

    return ParkingSpot.fromJson(entity);
  }

  static ParkingSpot fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    final imageUrl =
        map['imageUrl']?.toString() ??
        'https://images.unsplash.com/photo-1506521781263-d8422e82f27a';
    final availabilitySummary = _firstStringFrom(map, const [
      'availabilitySummary',
      'availability_summary',
    ]);
    final availableFromDate = _dateOnlyFrom(map, const [
      'availableFromDate',
      'available_from_date',
    ]);
    final availableToDate = _dateOnlyFrom(map, const [
      'availableToDate',
      'available_to_date',
    ]);
    final dailyStartMinute = _nullableIntFrom(map, const [
      'dailyStartMinute',
      'daily_start_minute',
    ]);
    final dailyEndMinute = _nullableIntFrom(map, const [
      'dailyEndMinute',
      'daily_end_minute',
    ]);
    final availabilityWindow = _availabilityWindowFrom(
      availableFromRaw: map['availableFrom'],
      availableUntilRaw: map['availableUntil'],
      availabilitySummary: availabilitySummary,
      structuredEndDate: availableToDate,
      structuredEndMinute: dailyEndMinute,
      structuredStartDate: availableFromDate,
      structuredStartMinute: dailyStartMinute,
    );
    return ParkingSpot(
      id: map['id'].toString(),
      title: map['title']?.toString() ?? 'Parking space',
      address: map['address']?.toString() ?? '',
      locality: map['locality']?.toString() ?? '',
      distanceKm: ((map['distanceKm'] ?? 0) as num).toDouble(),
      rating: ((map['rating'] ?? 0) as num).toDouble(),
      reviewCount: ((map['reviewCount'] ?? 0) as num).toInt(),
      price: ((map['price'] ?? map['hourlyPrice'] ?? 0) as num).toInt(),
      currency: map['currency']?.toString() ?? 'INR',
      cadence: BookingCadence.values.firstWhere(
        (entry) => entry.name == map['cadence'],
        orElse: () => BookingCadence.hourly,
      ),
      availableFrom: availabilityWindow.start,
      availableUntil: availabilityWindow.end,
      availabilitySummary: availabilitySummary,
      availableFromDate: availableFromDate,
      availableToDate: availableToDate,
      dailyEndMinute: dailyEndMinute,
      dailyStartMinute: dailyStartMinute,
      slotsAvailable: ((map['slotsAvailable'] ?? 0) as num).toInt(),
      location: _locationFrom(map),
      amenities: (map['amenities'] as List<dynamic>? ?? const [])
          .map(_amenityFrom)
          .toList(),
      imageUrl: imageUrl,
      addressConfidence: _doubleFrom(map, const [
        'addressConfidence',
        'address_confidence',
      ]),
      addressPlaceId: _firstStringFrom(map, const [
        'addressPlaceId',
        'address_place_id',
      ]),
      addressProvider: _firstStringFrom(map, const [
        'addressProvider',
        'address_provider',
      ]),
      city: _firstStringFrom(map, const ['city']),
      hostAvatarUrl: _firstStringFrom(map, const [
        'hostAvatarUrl',
        'host_avatar_url',
        'avatarUrl',
        'avatar_url',
      ]),
      hostName: _firstStringFrom(map, const [
        'hostName',
        'host_name',
        'ownerName',
        'owner_name',
      ]),
      hostPhone: _firstStringFrom(map, const [
        'hostPhone',
        'host_phone',
        'ownerPhone',
        'owner_phone',
        'phone',
      ]),
      hostRole: _firstStringFrom(map, const [
        'hostRole',
        'host_role',
        'ownerRole',
        'owner_role',
      ]),
      isHostedByCurrentUser: _boolFrom(map, const [
        'isHostedByCurrentUser',
        'is_hosted_by_current_user',
      ]),
      listingRevision: _intFrom(map, const [
        'listingRevision',
        'listing_revision',
        'revision',
      ]),
      postalCode: _firstStringFrom(map, const ['postalCode', 'postal_code']),
      updatedAt: _dateTimeFrom(map, const ['updatedAt', 'updated_at']),
      version: _intFrom(map, const ['version'], fallback: 1),
      imageUrls: _imageUrlsFrom(map, imageUrl),
    );
  }
}

class _AvailabilityWindow {
  const _AvailabilityWindow({required this.end, required this.start});

  final DateTime end;
  final DateTime start;
}

class _ParsedAvailabilitySummary {
  const _ParsedAvailabilitySummary({
    required this.endDate,
    required this.startDate,
    this.endMinute,
    this.startMinute,
  });

  final DateTime endDate;
  final int? endMinute;
  final DateTime startDate;
  final int? startMinute;
}

String? _firstStringFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
  }
  return null;
}

bool _boolFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    if (value is num) {
      return value != 0;
    }
  }
  return false;
}

double? _doubleFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

int _intFrom(Map<String, Object?> map, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

int? _nullableIntFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

DateTime? _dateTimeFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString();
    if (value == null || value.trim().isEmpty) continue;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _dateOnlyFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString();
    if (value == null || value.trim().isEmpty) continue;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  return null;
}

_AvailabilityWindow _availabilityWindowFrom({
  required Object? availableFromRaw,
  required Object? availableUntilRaw,
  required String? availabilitySummary,
  DateTime? structuredEndDate,
  int? structuredEndMinute,
  DateTime? structuredStartDate,
  int? structuredStartMinute,
}) {
  final structuredStart = DateTime.tryParse(availableFromRaw?.toString() ?? '');
  final structuredEnd = DateTime.tryParse(availableUntilRaw?.toString() ?? '');
  final parsedSummary = _parseAvailabilitySummary(availabilitySummary);
  final columnStart =
      structuredStartDate == null || structuredStartMinute == null
      ? null
      : _dateAtMinute(structuredStartDate, structuredStartMinute);
  final columnEnd = structuredEndDate == null || structuredEndMinute == null
      ? null
      : _dateAtMinute(
          structuredEndDate,
          _displayEndMinute(structuredEndMinute),
        );

  if (columnStart != null || columnEnd != null) {
    final start = columnStart ?? structuredStart ?? DateTime.now();
    var end =
        columnEnd ??
        structuredEnd ??
        DateTime.now().add(const Duration(hours: 3));
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    return _AvailabilityWindow(start: start, end: end);
  }

  if (parsedSummary == null) {
    return _AvailabilityWindow(
      start: structuredStart ?? DateTime.now(),
      end: structuredEnd ?? DateTime.now().add(const Duration(hours: 3)),
    );
  }

  final baseStartMinute = structuredStart == null
      ? structuredStartMinute ?? 8 * 60
      : structuredStart.hour * 60 + structuredStart.minute;
  final baseEndMinute = structuredEnd == null
      ? structuredEndMinute ?? 20 * 60
      : structuredEnd.hour * 60 + structuredEnd.minute;
  final start = _dateAtMinute(
    structuredStartDate ?? parsedSummary.startDate,
    parsedSummary.startMinute ?? baseStartMinute,
  );
  var end = _dateAtMinute(
    structuredEndDate ?? parsedSummary.endDate,
    _displayEndMinute(parsedSummary.endMinute ?? baseEndMinute),
  );

  if (!end.isAfter(start)) {
    end = start.add(const Duration(hours: 1));
  }

  return _AvailabilityWindow(start: start, end: end);
}

int _displayEndMinute(int minuteOfDay) {
  if (minuteOfDay >= 24 * 60) return (24 * 60) - 1;
  return minuteOfDay;
}

_ParsedAvailabilitySummary? _parseAvailabilitySummary(String? value) {
  if (value == null) return null;

  final normalized = value
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return null;

  final parts = normalized.split(',');
  final datePart = parts.first.trim();
  final timePart = parts.length > 1 ? parts.sublist(1).join(',').trim() : null;
  final dateMatch = RegExp(r'^(.+?)\s*-\s*(.+)$').firstMatch(datePart);
  if (dateMatch == null) return null;

  final startDate = _parseAvailabilityDate(dateMatch.group(1)!);
  final endDate = _parseAvailabilityDate(
    dateMatch.group(2)!,
    fallbackYear: startDate?.year,
  );
  if (startDate == null || endDate == null) return null;

  var resolvedEndDate = endDate;
  if (resolvedEndDate.isBefore(startDate)) {
    resolvedEndDate = DateTime(
      resolvedEndDate.year + 1,
      resolvedEndDate.month,
      resolvedEndDate.day,
    );
  }

  if (timePart == null || timePart.isEmpty) {
    return _ParsedAvailabilitySummary(
      startDate: startDate,
      endDate: resolvedEndDate,
    );
  }

  final normalizedTime = timePart.toLowerCase();
  if (normalizedTime == 'all day') {
    return _ParsedAvailabilitySummary(
      startDate: startDate,
      startMinute: 0,
      endDate: resolvedEndDate,
      endMinute: (24 * 60) - 1,
    );
  }

  final timeMatch = RegExp(
    r'^(.+?)\s*(?:-|to)\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(timePart);
  if (timeMatch == null) {
    return _ParsedAvailabilitySummary(
      startDate: startDate,
      endDate: resolvedEndDate,
    );
  }

  return _ParsedAvailabilitySummary(
    startDate: startDate,
    startMinute: _parseMinuteOfDay(timeMatch.group(1)!),
    endDate: resolvedEndDate,
    endMinute: _parseMinuteOfDay(timeMatch.group(2)!),
  );
}

DateTime? _parseAvailabilityDate(String rawValue, {int? fallbackYear}) {
  final trimmed = rawValue.trim().replaceAll(
    RegExp(r'(\d)(st|nd|rd|th)\b', caseSensitive: false),
    r'$1',
  );
  if (trimmed.isEmpty) return null;

  for (final pattern in const [
    'd MMM yyyy',
    'd MMMM yyyy',
    'dd MMM yyyy',
    'dd MMMM yyyy',
  ]) {
    try {
      return DateFormat(pattern, 'en_US').parseStrict(trimmed);
    } catch (_) {
      // Try the next accepted owner date pattern.
    }
  }

  final year = fallbackYear ?? DateTime.now().year;
  for (final pattern in const ['d MMM', 'd MMMM', 'dd MMM', 'dd MMMM']) {
    try {
      return DateFormat('$pattern yyyy', 'en_US').parseStrict('$trimmed $year');
    } catch (_) {
      // Try the next accepted owner date pattern.
    }
  }

  return null;
}

int? _parseMinuteOfDay(String rawValue) {
  final normalized = rawValue.trim().toUpperCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  if (normalized.isEmpty) return null;

  for (final pattern in const ['h:mm a', 'h a', 'hh:mm a', 'hh a', 'HH:mm']) {
    try {
      final parsed = DateFormat(pattern, 'en_US').parseStrict(normalized);
      return parsed.hour * 60 + parsed.minute;
    } catch (_) {
      // Try the next accepted owner time pattern.
    }
  }

  return null;
}

DateTime _dateAtMinute(DateTime date, int minuteOfDay) {
  final safeMinute = minuteOfDay.clamp(0, 24 * 60);
  return DateTime(
    date.year,
    date.month,
    date.day,
    safeMinute ~/ 60,
    safeMinute % 60,
  );
}

List<String> _imageUrlsFrom(Map<String, Object?> map, String primaryImageUrl) {
  final urls = <String>{};

  void addUrl(Object? value) {
    if (value == null) return;

    if (value is String) {
      final url = value.trim();
      if (url.isNotEmpty) urls.add(url);
      return;
    }

    if (value is Iterable) {
      for (final entry in value) {
        addUrl(entry);
      }
      return;
    }

    if (value is Map) {
      final entry = Map<Object?, Object?>.from(value);
      for (final key in const [
        'secure_url',
        'secureUrl',
        'imageUrl',
        'image_url',
        'url',
        'src',
      ]) {
        addUrl(entry[key]);
      }
    }
  }

  for (final key in const [
    'imageUrls',
    'image_urls',
    'images',
    'photos',
    'parkingPhotos',
    'parking_space_photos',
  ]) {
    addUrl(map[key]);
  }

  addUrl(primaryImageUrl);

  return urls.toList(growable: false);
}

GeoPoint _locationFrom(Map<String, Object?> map) {
  final location = map['location'];
  if (location is Map) {
    return GeoPoint.fromJson(Map<String, Object?>.from(location));
  }

  final latitude = map['latitude'];
  final longitude = map['longitude'];
  if (latitude is num && longitude is num) {
    return GeoPoint(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }

  return const GeoPoint(latitude: 13.0827, longitude: 80.2707);
}

ParkingAmenity _amenityFrom(Object? value) {
  final normalized = value?.toString().trim();
  switch (normalized) {
    case 'evCharging':
    case 'ev_charging':
      return ParkingAmenity.evCharging;
    case 'twoWheeler':
    case 'two_wheeler':
    case 'bike':
      return ParkingAmenity.twoWheeler;
    case 'security':
      return ParkingAmenity.security;
    case 'cctv':
      return ParkingAmenity.cctv;
    case 'valet':
      return ParkingAmenity.valet;
    case 'covered':
    default:
      return ParkingAmenity.covered;
  }
}
