import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/config/app_providers.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/booking/domain/booking_quote.dart';
import 'package:urban_parking/features/parking/domain/parking_repository.dart';
import 'package:urban_parking/features/parking/domain/parking_spot.dart';
import 'package:urban_parking/features/parking/presentation/parking_listing_store.dart';

void main() {
  test('realtime revision record maps safe public metadata', () {
    final revision = parkingListingRevisionFromRealtimeRecord({
      'space_id': '550e8400-e29b-41d4-a716-446655440000',
      'listing_revision': 7,
      'updated_at': '2026-05-06T10:30:00.000Z',
    });

    expect(revision, isNotNull);
    expect(revision!.spaceId, '550e8400-e29b-41d4-a716-446655440000');
    expect(revision.listingRevision, 7);
    expect(revision.updatedAt, DateTime.parse('2026-05-06T10:30:00.000Z'));
  });

  test('realtime revision record without id or revision is ignored', () {
    expect(
      parkingListingRevisionFromRealtimeRecord({'listing_revision': 1}),
      isNull,
    );
    expect(
      parkingListingRevisionFromRealtimeRecord({
        'space_id': '550e8400-e29b-41d4-a716-446655440000',
      }),
      isNull,
    );
  });

  test('listing store keeps newer canonical data over stale records', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(parkingListingStoreProvider.notifier);

    store.seed(_spot(title: 'Fresh listing', revision: 3, version: 3));
    store.seed(_spot(title: 'Stale listing', revision: 2, version: 2));

    expect(
      container
          .read(
            parkingListingStoreProvider,
          )['550e8400-e29b-41d4-a716-446655440000']!
          .spot!
          .title,
      'Fresh listing',
    );

    store.seed(_spot(title: 'Newer listing', revision: 4, version: 4));

    expect(
      container
          .read(
            parkingListingStoreProvider,
          )['550e8400-e29b-41d4-a716-446655440000']!
          .spot!
          .title,
      'Newer listing',
    );
  });

  test('refresh uses network-only fetch policy', () async {
    final repository = _FakeParkingRepository();
    final container = ProviderContainer(
      overrides: [parkingRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final store = container.read(parkingListingStoreProvider.notifier);
    final spot = await store.refresh('550e8400-e29b-41d4-a716-446655440000');

    expect(spot.title, 'Network listing');
    expect(repository.lastFetchPolicy, ParkingSpotFetchPolicy.networkOnly);
  });
}

class _FakeParkingRepository implements ParkingRepository {
  ParkingSpotFetchPolicy? lastFetchPolicy;

  @override
  Future<ParkingSpot> getById(
    String id, {
    ParkingSpotFetchPolicy fetchPolicy = ParkingSpotFetchPolicy.cacheFirst,
  }) async {
    lastFetchPolicy = fetchPolicy;
    return _spot(title: 'Network listing', revision: 9, version: 9);
  }

  @override
  Future<ParkingSpot> refreshById(String id) {
    return getById(id, fetchPolicy: ParkingSpotFetchPolicy.networkOnly);
  }

  @override
  Future<BookingQuote> quoteBooking({
    required String spotId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    return BookingQuote(
      spotId: spotId,
      startAt: startAt,
      endAt: endAt,
      subtotal: 50,
      platformFee: 8,
      taxes: 1,
      total: 59,
      currency: 'INR',
    );
  }

  @override
  Future<List<ParkingSpot>> searchNearby({
    required GeoPoint center,
    required double radiusKm,
  }) async {
    return [_spot(title: 'Network listing', revision: 9, version: 9)];
  }
}

ParkingSpot _spot({
  required int revision,
  required String title,
  required int version,
}) {
  return ParkingSpot(
    id: '550e8400-e29b-41d4-a716-446655440000',
    title: title,
    address: '12 Live Street',
    locality: 'Live Locality',
    distanceKm: 0,
    rating: 0,
    reviewCount: 0,
    price: 50,
    currency: 'INR',
    cadence: BookingCadence.hourly,
    availableFrom: DateTime(2026, 5, 7, 9),
    availableUntil: DateTime(2026, 5, 7, 18),
    slotsAvailable: 1,
    location: const GeoPoint(latitude: 13.08, longitude: 80.27),
    amenities: const [ParkingAmenity.covered],
    imageUrl: 'https://example.com/parking.jpg',
    listingRevision: revision,
    version: version,
  );
}
