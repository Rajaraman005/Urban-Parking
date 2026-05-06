import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/parking/data/parking_spot_cache.dart';
import 'package:urban_parking/features/parking/domain/parking_spot.dart';

void main() {
  test('discovery entity hydrates a booking-ready parking spot', () {
    final item = _discoveryEntity();

    final spot = ParkingSpot.fromDiscoveryEntity(item);

    expect(spot.id, 'spot-1');
    expect(spot.title, 'Nungambakkam covered bay');
    expect(spot.price, 120);
    expect(spot.distanceKm, 1.4);
    expect(spot.location.latitude, 13.0604);
    expect(spot.imageUrl, 'https://example.com/parking.jpg');
    expect(spot.imageUrls, [
      'https://example.com/parking-2.jpg',
      'https://example.com/parking.jpg',
    ]);
  });

  test('cache stores hydrated parking spots by discovery id', () {
    final cache = ParkingSpotCache();

    cache.upsertDiscoveryItems([_discoveryEntity()]);

    expect(cache.getById('spot-1')?.title, 'Nungambakkam covered bay');
  });

  test('constructor falls back to primary image when image list is null', () {
    final spot = ParkingSpot(
      id: 'spot-1',
      title: 'Test spot',
      address: 'Test address',
      locality: 'Test',
      distanceKm: 1,
      rating: 4,
      reviewCount: 2,
      price: 80,
      currency: 'INR',
      cadence: BookingCadence.hourly,
      availableFrom: DateTime.now(),
      availableUntil: DateTime.now().add(const Duration(hours: 2)),
      slotsAvailable: 1,
      location: const GeoPoint(latitude: 13.08, longitude: 80.27),
      amenities: const [ParkingAmenity.covered],
      imageUrl: 'https://example.com/primary.jpg',
      imageUrls: null,
    );

    expect(spot.imageUrls, ['https://example.com/primary.jpg']);
  });

  test('parser keeps every uploaded parking photo from Supabase rows', () {
    final spot = ParkingSpot.fromJson({
      'id': 'spot-1',
      'title': 'Multi photo spot',
      'price': 80,
      'imageUrl': 'https://example.com/cover.jpg',
      'parking_space_photos': [
        {'secure_url': 'https://example.com/cover.jpg'},
        {'secure_url': 'https://example.com/side.jpg'},
        {'secureUrl': 'https://example.com/entry.jpg'},
      ],
    });

    expect(spot.imageUrls, [
      'https://example.com/cover.jpg',
      'https://example.com/side.jpg',
      'https://example.com/entry.jpg',
    ]);
  });

  test('parser keeps host profile metadata when available', () {
    final spot = ParkingSpot.fromJson({
      'id': 'spot-1',
      'title': 'Hosted spot',
      'price': 80,
      'hostName': 'Rajesh Kumar',
      'hostAvatarUrl': 'https://example.com/host.jpg',
      'hostPhone': '+91 98765 43210',
      'hostRole': 'host',
      'isHostedByCurrentUser': true,
    });

    expect(spot.hostName, 'Rajesh Kumar');
    expect(spot.hostAvatarUrl, 'https://example.com/host.jpg');
    expect(spot.hostPhone, '+91 98765 43210');
    expect(spot.hostRole, 'host');
    expect(spot.isHostedByCurrentUser, isTrue);
  });

  test('parser honors owner availability summary for booking dates', () {
    final spot = ParkingSpot.fromJson({
      'id': 'spot-1',
      'title': 'Owner scheduled spot',
      'price': 80,
      'availability_summary': '2 May - 31 May, All day',
      'availableFrom': '2026-05-05T08:00:00.000+05:30',
      'availableUntil': '2026-06-03T20:00:00.000+05:30',
    });

    expect(spot.availabilitySummary, '2 May - 31 May, All day');
    expect(spot.availableFrom.month, 5);
    expect(spot.availableFrom.day, 2);
    expect(spot.availableFrom.hour, 0);
    expect(spot.availableUntil.month, 5);
    expect(spot.availableUntil.day, 31);
    expect(spot.availableUntil.hour, 23);
    expect(spot.availableUntil.minute, 59);
  });

  test('structured owner availability overrides stale summary text', () {
    final spot = ParkingSpot.fromJson({
      'id': 'spot-1',
      'title': 'Owner scheduled spot',
      'price': 80,
      'availability_summary': '2 May - 31 May, All day',
      'availableFromDate': '2026-06-01',
      'availableToDate': '2026-06-10',
      'dailyStartMinute': 9 * 60,
      'dailyEndMinute': 18 * 60,
      'availableFrom': '2026-05-02T00:00:00.000+05:30',
      'availableUntil': '2026-05-31T23:59:00.000+05:30',
    });

    expect(spot.availableFromDate, DateTime(2026, 6, 1));
    expect(spot.availableToDate, DateTime(2026, 6, 10));
    expect(spot.dailyStartMinute, 9 * 60);
    expect(spot.dailyEndMinute, 18 * 60);
    expect(spot.availableFrom, DateTime(2026, 6, 1, 9));
    expect(spot.availableUntil, DateTime(2026, 6, 10, 18));
  });
}

GeoDiscoveryEntity<Map<String, Object?>> _discoveryEntity() {
  return GeoDiscoveryEntity<Map<String, Object?>>(
    availabilityStatus: AvailabilityStatus.available,
    currency: 'INR',
    distanceKm: 1.4,
    entity: {
      'address': '12 College Road',
      'hourlyPrice': 120,
      'id': 'spot-1',
      'imageUrls': ['https://example.com/parking-2.jpg'],
      'locality': 'Nungambakkam',
      'slotsAvailable': 3,
      'title': 'Nungambakkam covered bay',
    },
    id: 'spot-1',
    imageUrl: 'https://example.com/parking.jpg',
    location: const GeoPoint(latitude: 13.0604, longitude: 80.2496),
    price: 120,
    rating: 4.6,
    serviceType: ServiceType.parking,
    title: 'Nungambakkam covered bay',
  );
}
