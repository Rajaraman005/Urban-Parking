import 'dart:typed_data';

import '../../../core/utils/geo_discovery/geo_types.dart';

class UserSetupState {
  const UserSetupState({
    this.intent,
    this.step = 'intent',
    this.draftId,
    this.draft,
    this.errorMessage,
    this.isBusy = false,
    this.message,
  });

  final HostListingDraft? draft;
  final String? draftId;
  final String? errorMessage;
  final String? intent;
  final bool isBusy;
  final String? message;
  final String step;

  UserSetupState copyWith({
    HostListingDraft? draft,
    String? draftId,
    String? errorMessage,
    String? intent,
    bool? isBusy,
    String? message,
    String? step,
  }) => UserSetupState(
    draft: draft ?? this.draft,
    draftId: draftId ?? this.draftId,
    errorMessage: errorMessage,
    intent: intent ?? this.intent,
    isBusy: isBusy ?? this.isBusy,
    message: message,
    step: step ?? this.step,
  );
}

class HostListingDraft {
  const HostListingDraft({
    required this.id,
    required this.status,
    required this.version,
    this.accessInstructions,
    this.address,
    this.addressConfidence,
    this.addressPlaceId,
    this.addressProvider,
    this.addressRaw,
    this.availableFromDate,
    this.availableToDate,
    this.city,
    this.currentStep,
    this.dailyEndMinute,
    this.dailyStartMinute,
    this.hourlyPrice,
    this.locality,
    this.location,
    this.parkingType,
    this.photos = const [],
    this.postalCode,
    this.skipWeekends = false,
    this.slotsCount = 1,
    this.stateName,
    this.storageKind = 'host_parking',
    this.title,
    this.vehicleFit,
  });

  final String? accessInstructions;
  final String? address;
  final double? addressConfidence;
  final String? addressPlaceId;
  final String? addressProvider;
  final Map<String, Object?>? addressRaw;
  final DateTime? availableFromDate;
  final DateTime? availableToDate;
  final String? city;
  final String? currentStep;
  final int? dailyEndMinute;
  final int? dailyStartMinute;
  final int? hourlyPrice;
  final String id;
  final String? locality;
  final GeoPoint? location;
  final String? parkingType;
  final List<HostListingPhoto> photos;
  final String? postalCode;
  final bool skipWeekends;
  final int slotsCount;
  final String? stateName;
  final String storageKind;
  final String status;
  final String? title;
  final String? vehicleFit;
  final int version;

  bool get hasBasics =>
      _hasText(title) &&
      _hasText(address) &&
      _hasText(locality) &&
      _hasText(city) &&
      _hasText(postalCode) &&
      location != null &&
      _hasText(vehicleFit) &&
      _hasText(parkingType);

  bool get hasPricing =>
      hourlyPrice != null &&
      hourlyPrice! >= 10 &&
      slotsCount >= 1 &&
      availableFromDate != null &&
      availableToDate != null &&
      dailyStartMinute != null &&
      dailyEndMinute != null;

  bool get hasRequiredPhotos => photos.length >= 2;

  bool get isLegacyParkingSpaceDraft => storageKind == 'legacy_parking_space';

  static HostListingDraft fromJson(Map<String, Object?> json) {
    final draftData = json['draft_data'] is Map
        ? Map<String, Object?>.from(json['draft_data'] as Map)
        : json['draftData'] is Map
        ? Map<String, Object?>.from(json['draftData'] as Map)
        : const <String, Object?>{};
    final basics = draftData['basics'] is Map
        ? Map<String, Object?>.from(draftData['basics'] as Map)
        : const <String, Object?>{};
    final pricing = draftData['pricing'] is Map
        ? Map<String, Object?>.from(draftData['pricing'] as Map)
        : const <String, Object?>{};
    final rawAddress = basics['addressRaw'] ?? basics['address_raw_osm_json'];
    final addressRawMap = rawAddress is Map
        ? Map<String, Object?>.from(rawAddress)
        : json['address_raw_osm_json'] is Map
        ? Map<String, Object?>.from(json['address_raw_osm_json'] as Map)
        : null;
    final photos =
        ((json['parking_space_photos'] ?? json['parking_listing_draft_photos'])
                    as List<dynamic>? ??
                const [])
            .whereType<Map>()
            .map(
              (entry) =>
                  HostListingPhoto.fromJson(Map<String, Object?>.from(entry)),
            )
            .toList(growable: false)
          ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

    return HostListingDraft(
      id: json['id'].toString(),
      status: json['status']?.toString() ?? 'draft',
      storageKind:
          _firstStringFrom(json, const ['storageKind', 'storage_kind']) ??
          'host_parking',
      version: _intFrom(json, const ['version'], fallback: 1),
      currentStep: _firstStringFrom(json, const [
        'currentStep',
        'current_step',
      ]),
      accessInstructions:
          _firstStringFrom(basics, const [
            'description',
            'accessInstructions',
            'access_instructions',
          ]) ??
          _firstStringFrom(json, const [
            'description',
            'accessInstructions',
            'access_instructions',
          ]),
      address:
          _firstStringFrom(basics, const ['address']) ??
          _firstStringFrom(json, const ['address']),
      addressConfidence:
          _doubleFrom(basics, const [
            'addressConfidence',
            'address_confidence',
          ]) ??
          _doubleFrom(json, const ['addressConfidence', 'address_confidence']),
      addressPlaceId:
          _firstStringFrom(basics, const [
            'addressPlaceId',
            'address_place_id',
          ]) ??
          _firstStringFrom(json, const ['addressPlaceId', 'address_place_id']),
      addressProvider:
          _firstStringFrom(basics, const [
            'addressProvider',
            'address_provider',
          ]) ??
          _firstStringFrom(json, const ['addressProvider', 'address_provider']),
      addressRaw: addressRawMap,
      availableFromDate:
          _dateOnlyFrom(pricing, const [
            'availableFromDate',
            'available_from_date',
          ]) ??
          _dateOnlyFrom(json, const [
            'availableFromDate',
            'available_from_date',
          ]),
      availableToDate:
          _dateOnlyFrom(pricing, const [
            'availableToDate',
            'available_to_date',
          ]) ??
          _dateOnlyFrom(json, const ['availableToDate', 'available_to_date']),
      city:
          _firstStringFrom(basics, const ['city']) ??
          _firstStringFrom(json, const ['city']),
      dailyEndMinute:
          _nullableIntFrom(pricing, const [
            'dailyEndMinute',
            'daily_end_minute',
          ]) ??
          _nullableIntFrom(json, const ['dailyEndMinute', 'daily_end_minute']),
      dailyStartMinute:
          _nullableIntFrom(pricing, const [
            'dailyStartMinute',
            'daily_start_minute',
          ]) ??
          _nullableIntFrom(json, const [
            'dailyStartMinute',
            'daily_start_minute',
          ]),
      hourlyPrice:
          _nullableIntFrom(pricing, const ['hourlyPrice', 'hourly_price']) ??
          _nullableIntFrom(json, const ['hourlyPrice', 'hourly_price']),
      locality:
          _firstStringFrom(basics, const ['locality']) ??
          _firstStringFrom(json, const ['locality']),
      location: _locationFrom(basics) ?? _locationFrom(json),
      parkingType:
          _firstStringFrom(basics, const ['parkingType', 'parking_type']) ??
          _firstStringFrom(json, const ['parkingType', 'parking_type']),
      photos: photos,
      postalCode:
          _firstStringFrom(basics, const ['postalCode', 'postal_code']) ??
          _firstStringFrom(json, const ['postalCode', 'postal_code']),
      skipWeekends:
          _boolFrom(pricing, const ['skipWeekends', 'skip_weekends']) ||
          _boolFrom(json, const ['skipWeekends', 'skip_weekends']),
      slotsCount: _intFrom(
        pricing,
        const ['slotsCount', 'slots_count'],
        fallback: _intFrom(json, const [
          'slotsCount',
          'slots_count',
        ], fallback: 1),
      ),
      stateName:
          _firstStringFrom(basics, const [
            'state',
            'stateName',
            'state_name',
          ]) ??
          _firstStringFrom(json, const ['state', 'stateName', 'state_name']) ??
          _stateFromRaw(addressRawMap),
      title:
          _firstStringFrom(basics, const ['title']) ??
          _firstStringFrom(json, const ['title']),
      vehicleFit:
          _firstStringFrom(basics, const ['vehicleFit', 'vehicle_fit']) ??
          _firstStringFrom(json, const ['vehicleFit', 'vehicle_fit']),
    );
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class HostListingPhoto {
  const HostListingPhoto({
    required this.id,
    required this.publicId,
    required this.secureUrl,
    required this.sortOrder,
    this.height,
    this.width,
  });

  final int? height;
  final String id;
  final String publicId;
  final String secureUrl;
  final int sortOrder;
  final int? width;

  static HostListingPhoto fromJson(Map<String, Object?> json) {
    return HostListingPhoto(
      id: json['id'].toString(),
      publicId: _firstStringFrom(json, const ['publicId', 'public_id']) ?? '',
      secureUrl:
          _firstStringFrom(json, const ['secureUrl', 'secure_url']) ?? '',
      sortOrder: _intFrom(json, const ['sortOrder', 'sort_order']),
      height: _nullableIntFrom(json, const ['height']),
      width: _nullableIntFrom(json, const ['width']),
    );
  }
}

class HostBasicsDraftUpdate {
  const HostBasicsDraftUpdate({
    required this.address,
    required this.city,
    required this.locality,
    required this.location,
    required this.parkingType,
    required this.postalCode,
    required this.stateName,
    required this.title,
    required this.vehicleFit,
    this.accessInstructions,
    this.addressConfidence = 1,
    this.addressPlaceId,
    this.addressProvider = 'manual',
    this.addressRaw,
  });

  final String? accessInstructions;
  final String address;
  final double addressConfidence;
  final String? addressPlaceId;
  final String addressProvider;
  final Map<String, Object?>? addressRaw;
  final String city;
  final String locality;
  final GeoPoint location;
  final String parkingType;
  final String postalCode;
  final String stateName;
  final String title;
  final String vehicleFit;
}

class HostPricingDraftUpdate {
  const HostPricingDraftUpdate({
    required this.availableFromDate,
    required this.availableToDate,
    required this.dailyEndMinute,
    required this.dailyStartMinute,
    required this.hourlyPrice,
    required this.skipWeekends,
    required this.slotsCount,
  });

  final DateTime availableFromDate;
  final DateTime availableToDate;
  final int dailyEndMinute;
  final int dailyStartMinute;
  final int hourlyPrice;
  final bool skipWeekends;
  final int slotsCount;
}

class HostPhotoUploadCandidate {
  const HostPhotoUploadCandidate({
    required this.bytes,
    required this.fileName,
    required this.height,
    required this.mimeType,
    required this.width,
  });

  final Uint8List bytes;
  final String fileName;
  final int height;
  final String mimeType;
  final int width;
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

String? _stateFromRaw(Map<String, Object?>? raw) {
  return _firstNestedString(raw, const [
    ['address', 'state'],
    ['address', 'region'],
    ['address', 'state_district'],
    ['state'],
    ['region'],
  ]);
}

String? _firstNestedString(
  Map<String, Object?>? raw,
  List<List<String>> paths,
) {
  if (raw == null) return null;
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
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  return null;
}

GeoPoint? _locationFrom(Map<String, Object?> map) {
  final location = map['location'];
  if (location is Map) {
    return GeoPoint.fromJson(Map<String, Object?>.from(location));
  }

  final latitude = _doubleFrom(map, const ['latitude']);
  final longitude = _doubleFrom(map, const ['longitude']);
  if (latitude == null || longitude == null) return null;
  return GeoPoint(latitude: latitude, longitude: longitude);
}
