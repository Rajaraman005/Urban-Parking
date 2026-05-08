import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/config/app_providers.dart';
import 'package:urban_parking/core/errors/app_failure.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/booking/domain/booking_quote.dart';
import 'package:urban_parking/features/parking/domain/owner_parking_repository.dart';
import 'package:urban_parking/features/parking/domain/parking_repository.dart';
import 'package:urban_parking/features/parking/domain/parking_spot.dart';
import 'package:urban_parking/features/parking/presentation/owner_parking_controller.dart';
import 'package:urban_parking/features/parking/presentation/parking_listing_store.dart';

void main() {
  test(
    'pricing update refreshes and retries once on stale listing version',
    () async {
      final ownerRepository = _RetryingOwnerRepository();
      final parkingRepository = _NetworkParkingRepository();
      final container = ProviderContainer(
        overrides: [
          ownerParkingRepositoryProvider.overrideWithValue(ownerRepository),
          parkingRepositoryProvider.overrideWithValue(parkingRepository),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(parkingListingStoreProvider.notifier)
          .seed(_spot(version: 1));

      final saved = await container
          .read(ownerListingEditorControllerProvider.notifier)
          .updatePricing(
            spotId: _spotId,
            update: OwnedListingPricingUpdate(
              availableFromDate: DateTime(2026, 5, 7),
              availableToDate: DateTime(2026, 5, 31),
              dailyEndMinute: 20 * 60,
              dailyStartMinute: 8 * 60,
              expectedVersion: 1,
              hourlyPrice: 90,
              skipWeekends: false,
              slotsCount: 2,
            ),
          );

      expect(saved.price, 90);
      expect(ownerRepository.receivedVersions, [1, 2]);
      expect(
        parkingRepository.lastFetchPolicy,
        ParkingSpotFetchPolicy.networkOnly,
      );
    },
  );

  test('listing delete removes the optimistic listing snapshot', () async {
    final ownerRepository = _RetryingOwnerRepository();
    final parkingRepository = _NetworkParkingRepository();
    final container = ProviderContainer(
      overrides: [
        ownerParkingRepositoryProvider.overrideWithValue(ownerRepository),
        parkingRepositoryProvider.overrideWithValue(parkingRepository),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(parkingListingStoreProvider.notifier)
        .seed(_spot(version: 1).copyWith(status: 'draft'));

    await container
        .read(ownerListingEditorControllerProvider.notifier)
        .deleteListing(_spotId);

    expect(ownerRepository.deletedSpotIds, [_spotId]);
    expect(
      container.read(parkingListingSnapshotProvider(_spotId))?.isDeleted,
      isTrue,
    );
  });
}

const _spotId = '550e8400-e29b-41d4-a716-446655440000';

class _RetryingOwnerRepository implements OwnerParkingRepository {
  final receivedVersions = <int>[];
  final deletedSpotIds = <String>[];

  @override
  Future<List<ParkingSpot>> listOwnedSpaces() async => [_spot(version: 1)];

  @override
  Future<void> deleteListing(String spotId) async {
    deletedSpotIds.add(spotId);
  }

  @override
  Future<List<ParkingAddressCandidate>> searchAddress(String query) async =>
      const [];

  @override
  Future<ParkingSpot> updateListingAddress({
    required String spotId,
    required OwnedListingAddressUpdate update,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ParkingSpot> updateListingPricing({
    required String spotId,
    required OwnedListingPricingUpdate update,
  }) async {
    receivedVersions.add(update.expectedVersion);
    if (receivedVersions.length == 1) {
      throw const ValidationFailure(
        'This listing changed elsewhere. Refresh and try again.',
        code: 'listing_version_conflict',
      );
    }
    return _spot(
      price: update.hourlyPrice,
      slots: update.slotsCount,
      version: update.expectedVersion + 1,
    );
  }
}

class _NetworkParkingRepository implements ParkingRepository {
  ParkingSpotFetchPolicy? lastFetchPolicy;

  @override
  Future<ParkingSpot> getById(
    String id, {
    ParkingSpotFetchPolicy fetchPolicy = ParkingSpotFetchPolicy.cacheFirst,
  }) async {
    lastFetchPolicy = fetchPolicy;
    return _spot(version: 2);
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
    return [_spot(version: 2)];
  }
}

ParkingSpot _spot({int price = 50, int slots = 1, required int version}) {
  return ParkingSpot(
    id: _spotId,
    title: 'Live listing',
    address: '12 Live Street',
    locality: 'Live Locality',
    distanceKm: 0,
    rating: 0,
    reviewCount: 0,
    price: price,
    currency: 'INR',
    cadence: BookingCadence.hourly,
    availableFrom: DateTime(2026, 5, 7, 8),
    availableFromDate: DateTime(2026, 5, 7),
    availableToDate: DateTime(2026, 5, 31),
    availableUntil: DateTime(2026, 5, 31, 20),
    dailyEndMinute: 20 * 60,
    dailyStartMinute: 8 * 60,
    slotsAvailable: slots,
    location: const GeoPoint(latitude: 13.08, longitude: 80.27),
    amenities: const [ParkingAmenity.covered],
    imageUrl: 'https://example.com/parking.jpg',
    listingRevision: version,
    version: version,
  );
}
