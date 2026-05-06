import 'parking_spot.dart';

class ParkingAddressCandidate {
  const ParkingAddressCandidate({
    required this.address,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.provider,
    this.city,
    this.locality,
    this.placeId,
    this.postalCode,
    this.raw,
    this.state,
  });

  final String address;
  final String? city;
  final double confidence;
  final double latitude;
  final String? locality;
  final double longitude;
  final String? placeId;
  final String? postalCode;
  final String provider;
  final Map<String, Object?>? raw;
  final String? state;

  static ParkingAddressCandidate fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    final raw = map['raw'] is Map
        ? Map<String, Object?>.from(map['raw'] as Map)
        : null;
    return ParkingAddressCandidate(
      address: map['formattedAddress']?.toString() ?? '',
      city: map['city']?.toString(),
      confidence: ((map['confidence'] ?? 0.5) as num).toDouble(),
      latitude: ((map['latitude'] ?? 0) as num).toDouble(),
      locality: map['locality']?.toString(),
      longitude: ((map['longitude'] ?? 0) as num).toDouble(),
      placeId: map['placeId']?.toString(),
      postalCode: map['postalCode']?.toString(),
      provider: map['provider']?.toString() ?? 'nominatim',
      raw: raw,
      state: map['state']?.toString(),
    );
  }
}

class OwnedListingAddressUpdate {
  const OwnedListingAddressUpdate({
    required this.address,
    required this.city,
    required this.confidence,
    required this.expectedVersion,
    required this.latitude,
    required this.locality,
    required this.longitude,
    required this.postalCode,
    required this.provider,
    this.placeId,
    this.raw,
  });

  final String address;
  final String city;
  final double confidence;
  final int expectedVersion;
  final double latitude;
  final String locality;
  final double longitude;
  final String? placeId;
  final String postalCode;
  final String provider;
  final Map<String, Object?>? raw;
}

class OwnedListingPricingUpdate {
  const OwnedListingPricingUpdate({
    required this.availableFromDate,
    required this.availableToDate,
    required this.dailyEndMinute,
    required this.dailyStartMinute,
    required this.expectedVersion,
    required this.hourlyPrice,
    required this.slotsCount,
  });

  final DateTime availableFromDate;
  final DateTime availableToDate;
  final int dailyEndMinute;
  final int dailyStartMinute;
  final int expectedVersion;
  final int hourlyPrice;
  final int slotsCount;
}

abstract interface class OwnerParkingRepository {
  Future<List<ParkingSpot>> listOwnedSpaces();

  Future<List<ParkingAddressCandidate>> searchAddress(String query);

  Future<ParkingSpot> updateListingAddress({
    required String spotId,
    required OwnedListingAddressUpdate update,
  });

  Future<ParkingSpot> updateListingPricing({
    required String spotId,
    required OwnedListingPricingUpdate update,
  });
}
