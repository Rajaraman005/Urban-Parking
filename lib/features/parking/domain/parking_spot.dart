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
  });

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
  final int slotsAvailable;
  final GeoPoint location;
  final List<ParkingAmenity> amenities;
  final String imageUrl;

  ParkingSpot copyWith({double? distanceKm}) => ParkingSpot(
    id: id,
    title: title,
    address: address,
    locality: locality,
    distanceKm: distanceKm ?? this.distanceKm,
    rating: rating,
    reviewCount: reviewCount,
    price: price,
    currency: currency,
    cadence: cadence,
    availableFrom: availableFrom,
    availableUntil: availableUntil,
    slotsAvailable: slotsAvailable,
    location: location,
    amenities: amenities,
    imageUrl: imageUrl,
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
    'availableUntil': availableUntil.toIso8601String(),
    'slotsAvailable': slotsAvailable,
    'location': location.toJson(),
    'amenities': amenities.map((entry) => entry.name).toList(),
    'imageUrl': imageUrl,
  };

  static ParkingSpot fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
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
      availableFrom:
          DateTime.tryParse(map['availableFrom']?.toString() ?? '') ??
          DateTime.now(),
      availableUntil:
          DateTime.tryParse(map['availableUntil']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 3)),
      slotsAvailable: ((map['slotsAvailable'] ?? 0) as num).toInt(),
      location: map['location'] is Map
          ? GeoPoint.fromJson(Map<String, Object?>.from(map['location'] as Map))
          : const GeoPoint(latitude: 13.0827, longitude: 80.2707),
      amenities: (map['amenities'] as List<dynamic>? ?? const [])
          .map(
            (entry) => ParkingAmenity.values.firstWhere(
              (amenity) => amenity.name == entry,
              orElse: () => ParkingAmenity.covered,
            ),
          )
          .toList(),
      imageUrl:
          map['imageUrl']?.toString() ??
          'https://images.unsplash.com/photo-1506521781263-d8422e82f27a',
    );
  }
}
