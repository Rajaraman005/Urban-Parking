import '../../../core/utils/geo_discovery/geo_types.dart';

enum HostParkingSaveStatus {
  idle,
  savedOnDevice,
  syncing,
  saved,
  needsReview,
  syncFailed,
}

enum HostParkingMergeStatus { applied, autoMerged, idempotentReplay }

class HostParkingDraft {
  const HostParkingDraft({
    required this.id,
    required this.status,
    required this.currentStep,
    required this.version,
    required this.completionPercent,
    required this.data,
    this.expiresAt,
    this.lastAutosavedAt,
    this.photos = const [],
    this.publishedSpaceId,
    this.updatedAt,
    this.validationState = const {},
  });

  final int completionPercent;
  final String currentStep;
  final HostParkingDraftData data;
  final DateTime? expiresAt;
  final String id;
  final DateTime? lastAutosavedAt;
  final List<HostParkingDraftPhoto> photos;
  final String? publishedSpaceId;
  final String status;
  final DateTime? updatedAt;
  final Map<String, Object?> validationState;
  final int version;

  bool get hasConflicts =>
      validationState['conflict'] == true ||
      validationState['status'] == 'conflict';

  HostParkingDraft copyWith({
    int? completionPercent,
    String? currentStep,
    HostParkingDraftData? data,
    DateTime? expiresAt,
    DateTime? lastAutosavedAt,
    List<HostParkingDraftPhoto>? photos,
    String? publishedSpaceId,
    String? status,
    DateTime? updatedAt,
    Map<String, Object?>? validationState,
    int? version,
  }) {
    return HostParkingDraft(
      id: id,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      version: version ?? this.version,
      completionPercent: completionPercent ?? this.completionPercent,
      data: data ?? this.data,
      expiresAt: expiresAt ?? this.expiresAt,
      lastAutosavedAt: lastAutosavedAt ?? this.lastAutosavedAt,
      photos: photos ?? this.photos,
      publishedSpaceId: publishedSpaceId ?? this.publishedSpaceId,
      updatedAt: updatedAt ?? this.updatedAt,
      validationState: validationState ?? this.validationState,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'status': status,
    'currentStep': currentStep,
    'version': version,
    'completionPercent': completionPercent,
    'draftData': data.toJson(),
    'expiresAt': expiresAt?.toIso8601String(),
    'lastAutosavedAt': lastAutosavedAt?.toIso8601String(),
    'photos': photos.map((photo) => photo.toJson()).toList(),
    'publishedSpaceId': publishedSpaceId,
    'updatedAt': updatedAt?.toIso8601String(),
    'validationState': validationState,
  };

  static HostParkingDraft fromJson(Object? value) {
    final json = Map<String, Object?>.from(value as Map);
    final draftData = _mapFromAny(
      json['draftData'] ?? json['draft_data'] ?? json['draft_data_json'],
    );
    final photoRows =
        json['parking_listing_draft_photos'] ??
        json['parking_space_photos'] ??
        json['photos'];
    return HostParkingDraft(
      id: json['id'].toString(),
      status: _stringFrom(json, const ['status']) ?? 'draft',
      currentStep:
          _stringFrom(json, const ['currentStep', 'current_step', 'step']) ??
          'host_basics',
      version: _intFrom(json, const ['version'], fallback: 1),
      completionPercent: _intFrom(json, const [
        'completionPercent',
        'completion_percent',
      ]),
      data: HostParkingDraftData.fromJson(draftData),
      expiresAt: _dateTimeFrom(json, const ['expiresAt', 'expires_at']),
      lastAutosavedAt: _dateTimeFrom(json, const [
        'lastAutosavedAt',
        'last_autosaved_at',
      ]),
      photos: _photosFrom(photoRows),
      publishedSpaceId: _stringFrom(json, const [
        'publishedSpaceId',
        'published_space_id',
      ]),
      updatedAt: _dateTimeFrom(json, const ['updatedAt', 'updated_at']),
      validationState: _mapFromAny(
        json['validationState'] ?? json['validation_state'],
      ),
    );
  }
}

class HostParkingDraftData {
  const HostParkingDraftData({
    this.basics = const HostParkingBasicsData(),
    this.pricing = const HostParkingPricingData(),
  });

  final HostParkingBasicsData basics;
  final HostParkingPricingData pricing;

  HostParkingDraftData copyWith({
    HostParkingBasicsData? basics,
    HostParkingPricingData? pricing,
  }) {
    return HostParkingDraftData(
      basics: basics ?? this.basics,
      pricing: pricing ?? this.pricing,
    );
  }

  Map<String, Object?> toJson() => {
    'basics': basics.toJson(),
    'pricing': pricing.toJson(),
  };

  Map<String, Object?> patchForBasics() => {'basics': basics.toJson()};
  Map<String, Object?> patchForPricing() => {'pricing': pricing.toJson()};

  static HostParkingDraftData fromJson(Map<String, Object?> json) {
    return HostParkingDraftData(
      basics: HostParkingBasicsData.fromJson(_mapFromAny(json['basics'])),
      pricing: HostParkingPricingData.fromJson(_mapFromAny(json['pricing'])),
    );
  }
}

class HostParkingBasicsData {
  const HostParkingBasicsData({
    this.accessInstructions,
    this.address,
    this.addressConfidence,
    this.addressPlaceId,
    this.addressProvider,
    this.addressRaw,
    this.city,
    this.locality,
    this.location,
    this.parkingType,
    this.postalCode,
    this.stateName,
    this.title,
    this.vehicleFit,
  });

  final String? accessInstructions;
  final String? address;
  final double? addressConfidence;
  final String? addressPlaceId;
  final String? addressProvider;
  final Map<String, Object?>? addressRaw;
  final String? city;
  final String? locality;
  final GeoPoint? location;
  final String? parkingType;
  final String? postalCode;
  final String? stateName;
  final String? title;
  final String? vehicleFit;

  bool get isComplete =>
      _hasText(title) &&
      _hasText(address) &&
      _hasText(city) &&
      _hasText(locality) &&
      _hasText(postalCode) &&
      location != null &&
      _hasText(parkingType) &&
      _hasText(vehicleFit) &&
      _hasText(accessInstructions);

  HostParkingBasicsData copyWith({
    String? accessInstructions,
    String? address,
    double? addressConfidence,
    String? addressPlaceId,
    String? addressProvider,
    Map<String, Object?>? addressRaw,
    String? city,
    String? locality,
    GeoPoint? location,
    String? parkingType,
    String? postalCode,
    String? stateName,
    String? title,
    String? vehicleFit,
  }) {
    return HostParkingBasicsData(
      accessInstructions: accessInstructions ?? this.accessInstructions,
      address: address ?? this.address,
      addressConfidence: addressConfidence ?? this.addressConfidence,
      addressPlaceId: addressPlaceId ?? this.addressPlaceId,
      addressProvider: addressProvider ?? this.addressProvider,
      addressRaw: addressRaw ?? this.addressRaw,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      location: location ?? this.location,
      parkingType: parkingType ?? this.parkingType,
      postalCode: postalCode ?? this.postalCode,
      stateName: stateName ?? this.stateName,
      title: title ?? this.title,
      vehicleFit: vehicleFit ?? this.vehicleFit,
    );
  }

  Map<String, Object?> toJson() => {
    if (_hasText(accessInstructions))
      'accessInstructions': accessInstructions!.trim(),
    if (_hasText(address)) 'address': address!.trim(),
    if (addressConfidence != null) 'addressConfidence': addressConfidence,
    if (_hasText(addressPlaceId)) 'addressPlaceId': addressPlaceId!.trim(),
    if (_hasText(addressProvider)) 'addressProvider': addressProvider!.trim(),
    if (addressRaw != null) 'addressRaw': addressRaw,
    if (_hasText(city)) 'city': city!.trim(),
    if (_hasText(locality)) 'locality': locality!.trim(),
    if (location != null) 'location': location!.toJson(),
    if (_hasText(parkingType)) 'parkingType': parkingType!.trim(),
    if (_hasText(postalCode)) 'postalCode': postalCode!.trim(),
    if (_hasText(stateName)) 'state': stateName!.trim(),
    if (_hasText(title)) 'title': title!.trim(),
    if (_hasText(vehicleFit)) 'vehicleFit': vehicleFit!.trim(),
  };

  static HostParkingBasicsData fromJson(Map<String, Object?> json) {
    final addressRaw = _mapFromAny(
      json['addressRaw'] ?? json['address_raw_osm_json'],
    );
    return HostParkingBasicsData(
      accessInstructions: _stringFrom(json, const [
        'accessInstructions',
        'access_instructions',
        'description',
      ]),
      address: _stringFrom(json, const ['address']),
      addressConfidence: _doubleFrom(json, const [
        'addressConfidence',
        'address_confidence',
      ]),
      addressPlaceId: _stringFrom(json, const [
        'addressPlaceId',
        'address_place_id',
      ]),
      addressProvider: _stringFrom(json, const [
        'addressProvider',
        'address_provider',
      ]),
      addressRaw: addressRaw,
      city: _stringFrom(json, const ['city']),
      locality: _stringFrom(json, const ['locality']),
      location: _locationFrom(json['location']) ?? _flatLocationFrom(json),
      parkingType: _stringFrom(json, const ['parkingType', 'parking_type']),
      postalCode: _stringFrom(json, const ['postalCode', 'postal_code']),
      stateName:
          _stringFrom(json, const ['state', 'stateName', 'state_name']) ??
          _stateFromRaw(addressRaw),
      title: _stringFrom(json, const ['title']),
      vehicleFit: _stringFrom(json, const ['vehicleFit', 'vehicle_fit']),
    );
  }
}

class HostParkingPricingData {
  const HostParkingPricingData({
    this.availableFromDate,
    this.availableToDate,
    this.dailyEndMinute,
    this.dailyStartMinute,
    this.hourlyPrice,
    this.skipWeekends = false,
    this.slotsCount,
  });

  final DateTime? availableFromDate;
  final DateTime? availableToDate;
  final int? dailyEndMinute;
  final int? dailyStartMinute;
  final int? hourlyPrice;
  final bool skipWeekends;
  final int? slotsCount;

  bool get isComplete =>
      hourlyPrice != null &&
      slotsCount != null &&
      availableFromDate != null &&
      availableToDate != null &&
      dailyStartMinute != null &&
      dailyEndMinute != null;

  HostParkingPricingData copyWith({
    DateTime? availableFromDate,
    DateTime? availableToDate,
    int? dailyEndMinute,
    int? dailyStartMinute,
    int? hourlyPrice,
    bool? skipWeekends,
    int? slotsCount,
  }) {
    return HostParkingPricingData(
      availableFromDate: availableFromDate ?? this.availableFromDate,
      availableToDate: availableToDate ?? this.availableToDate,
      dailyEndMinute: dailyEndMinute ?? this.dailyEndMinute,
      dailyStartMinute: dailyStartMinute ?? this.dailyStartMinute,
      hourlyPrice: hourlyPrice ?? this.hourlyPrice,
      skipWeekends: skipWeekends ?? this.skipWeekends,
      slotsCount: slotsCount ?? this.slotsCount,
    );
  }

  Map<String, Object?> toJson() => {
    if (availableFromDate != null)
      'availableFromDate': _dateOnly(availableFromDate!),
    if (availableToDate != null) 'availableToDate': _dateOnly(availableToDate!),
    if (dailyEndMinute != null) 'dailyEndMinute': dailyEndMinute,
    if (dailyStartMinute != null) 'dailyStartMinute': dailyStartMinute,
    if (hourlyPrice != null) 'hourlyPrice': hourlyPrice,
    'skipWeekends': skipWeekends,
    if (slotsCount != null) 'slotsCount': slotsCount,
  };

  static HostParkingPricingData fromJson(Map<String, Object?> json) {
    return HostParkingPricingData(
      availableFromDate: _dateOnlyFrom(json, const [
        'availableFromDate',
        'available_from_date',
      ]),
      availableToDate: _dateOnlyFrom(json, const [
        'availableToDate',
        'available_to_date',
      ]),
      dailyEndMinute: _nullableIntFrom(json, const [
        'dailyEndMinute',
        'daily_end_minute',
      ]),
      dailyStartMinute: _nullableIntFrom(json, const [
        'dailyStartMinute',
        'daily_start_minute',
      ]),
      hourlyPrice: _nullableIntFrom(json, const [
        'hourlyPrice',
        'hourly_price',
      ]),
      skipWeekends: _boolFrom(json, const ['skipWeekends', 'skip_weekends']),
      slotsCount: _nullableIntFrom(json, const ['slotsCount', 'slots_count']),
    );
  }
}

class HostParkingDraftPhoto {
  const HostParkingDraftPhoto({
    required this.id,
    required this.publicId,
    required this.secureUrl,
    required this.sortOrder,
    this.clientUploadId,
    this.height,
    this.width,
  });

  final String? clientUploadId;
  final int? height;
  final String id;
  final String publicId;
  final String secureUrl;
  final int sortOrder;
  final int? width;

  Map<String, Object?> toJson() => {
    'clientUploadId': clientUploadId,
    'height': height,
    'id': id,
    'publicId': publicId,
    'secureUrl': secureUrl,
    'sortOrder': sortOrder,
    'width': width,
  };

  static HostParkingDraftPhoto fromJson(Object? value) {
    final json = Map<String, Object?>.from(value as Map);
    return HostParkingDraftPhoto(
      id: json['id'].toString(),
      publicId: _stringFrom(json, const ['publicId', 'public_id']) ?? '',
      secureUrl: _stringFrom(json, const ['secureUrl', 'secure_url']) ?? '',
      sortOrder: _intFrom(json, const ['sortOrder', 'sort_order']),
      clientUploadId: _stringFrom(json, const [
        'clientUploadId',
        'client_upload_id',
      ]),
      height: _nullableIntFrom(json, const ['height']),
      width: _nullableIntFrom(json, const ['width']),
    );
  }
}

class HostParkingPatchResult {
  const HostParkingPatchResult({
    required this.draft,
    required this.mergeStatus,
  });

  final HostParkingDraft draft;
  final HostParkingMergeStatus mergeStatus;

  static HostParkingPatchResult fromJson(Object? value) {
    final json = Map<String, Object?>.from(value as Map);
    final draft = json['draft'] ?? json;
    return HostParkingPatchResult(
      draft: HostParkingDraft.fromJson(draft),
      mergeStatus: _mergeStatusFrom(json['mergeStatus']),
    );
  }
}

class HostParkingDraftConflict implements Exception {
  const HostParkingDraftConflict({
    required this.conflictingPaths,
    required this.resolutionToken,
    required this.serverDraft,
    required this.serverVersion,
  });

  final List<String> conflictingPaths;
  final String resolutionToken;
  final HostParkingDraft serverDraft;
  final int serverVersion;

  static HostParkingDraftConflict fromJson(Object? value) {
    final json = Map<String, Object?>.from(value as Map);
    return HostParkingDraftConflict(
      conflictingPaths: (json['conflictingPaths'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .toList(growable: false),
      resolutionToken: json['resolutionToken']?.toString() ?? '',
      serverDraft: HostParkingDraft.fromJson(json['serverDraft']),
      serverVersion: _intFrom(json, const ['serverVersion']),
    );
  }

  @override
  String toString() => 'HostParkingDraftConflict($conflictingPaths)';
}

int calculateHostParkingCompletion(HostParkingDraft draft) {
  var score = 0;
  if (draft.data.basics.isComplete) score += 35;
  if (draft.data.pricing.isComplete) score += 35;
  if (draft.photos.length >= 2) {
    score += 20;
  } else if (draft.photos.length == 1) {
    score += 10;
  }
  return score >= 90 ? 100 : score;
}

List<String> conflictingFieldPaths(
  Iterable<String> localFieldMask,
  Iterable<String> remoteFieldMask,
) {
  final remote = remoteFieldMask.toSet();
  return localFieldMask.where(remote.contains).toSet().toList(growable: false)
    ..sort();
}

List<HostParkingDraftPhoto> _photosFrom(Object? value) {
  if (value is! List) return const [];
  final photos = value
      .whereType<Map>()
      .map((entry) => HostParkingDraftPhoto.fromJson(entry))
      .toList(growable: false);
  photos.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  return photos;
}

HostParkingMergeStatus _mergeStatusFrom(Object? value) {
  return switch (value?.toString()) {
    'auto_merged' || 'autoMerged' => HostParkingMergeStatus.autoMerged,
    'idempotent_replay' ||
    'idempotentReplay' => HostParkingMergeStatus.idempotentReplay,
    _ => HostParkingMergeStatus.applied,
  };
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

Map<String, Object?> _mapFromAny(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return const {};
}

String? _stringFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String? _stateFromRaw(Map<String, Object?> raw) {
  return _firstNestedString(raw, const [
    ['address', 'state'],
    ['address', 'region'],
    ['address', 'state_district'],
    ['state'],
    ['region'],
  ]);
}

String? _firstNestedString(Map<String, Object?> raw, List<List<String>> paths) {
  for (final path in paths) {
    Object? cursor = raw;
    for (final segment in path) {
      if (cursor is! Map) {
        cursor = null;
        break;
      }
      cursor = cursor[segment];
    }
    if (cursor is String) {
      final trimmed = cursor.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
  }
  return null;
}

bool _boolFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
  }
  return false;
}

double? _doubleFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

int _intFrom(Map<String, Object?> map, List<String> keys, {int fallback = 0}) {
  return _nullableIntFrom(map, keys) ?? fallback;
}

int? _nullableIntFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

DateTime? _dateOnlyFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString();
    if (value == null || value.trim().isEmpty) continue;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
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

GeoPoint? _locationFrom(Object? value) {
  if (value is! Map) return null;
  return GeoPoint.fromJson(Map<String, Object?>.from(value));
}

GeoPoint? _flatLocationFrom(Map<String, Object?> json) {
  final latitude = _doubleFrom(json, const ['latitude']);
  final longitude = _doubleFrom(json, const ['longitude']);
  if (latitude == null || longitude == null) return null;
  return GeoPoint(latitude: latitude, longitude: longitude);
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
