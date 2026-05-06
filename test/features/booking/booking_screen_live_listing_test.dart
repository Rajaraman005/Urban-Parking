import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/config/app_providers.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/booking/domain/booking_quote.dart';
import 'package:urban_parking/features/booking/presentation/booking_screen.dart';
import 'package:urban_parking/features/parking/domain/parking_repository.dart';
import 'package:urban_parking/features/parking/domain/parking_spot.dart';
import 'package:urban_parking/features/parking/presentation/parking_listing_store.dart';

void main() {
  testWidgets('property details repaint when listing store changes', (
    tester,
  ) async {
    late ParkingListingStore store;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parkingRepositoryProvider.overrideWithValue(
            _FakeParkingRepository(_spot()),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            store = ref.read(parkingListingStoreProvider.notifier);
            return const MaterialApp(
              home: BookingScreen(
                spotId: '550e8400-e29b-41d4-a716-446655440000',
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Live parking'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(_textOrRichTextContaining('\u20B950/hr'), findsWidgets);
    expect(find.text('12 Old Street'), findsOneWidget);

    store.applyOptimistic(
      _spot(address: '98 New Avenue', price: 90, revision: 2, version: 2),
    );
    await tester.pumpAndSettle();

    expect(_textOrRichTextContaining('\u20B990/hr'), findsWidgets);
    expect(find.text('98 New Avenue'), findsOneWidget);
    expect(find.text('12 Old Street'), findsNothing);
  });
}

Finder _textOrRichTextContaining(String value) {
  return find.byWidgetPredicate(
    (widget) =>
        (widget is Text && (widget.data?.contains(value) ?? false)) ||
        (widget is RichText && widget.text.toPlainText().contains(value)),
  );
}

class _FakeParkingRepository implements ParkingRepository {
  const _FakeParkingRepository(this._spot);

  final ParkingSpot _spot;

  @override
  Future<ParkingSpot> getById(
    String id, {
    ParkingSpotFetchPolicy fetchPolicy = ParkingSpotFetchPolicy.cacheFirst,
  }) async {
    return _spot;
  }

  @override
  Future<ParkingSpot> refreshById(String id) async => _spot;

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
    return [_spot];
  }
}

ParkingSpot _spot({
  String address = '12 Old Street',
  int price = 50,
  int revision = 1,
  int version = 1,
}) {
  return ParkingSpot(
    id: '550e8400-e29b-41d4-a716-446655440000',
    title: 'Live parking',
    address: address,
    locality: 'Nungambakkam',
    distanceKm: 0,
    rating: 4.8,
    reviewCount: 12,
    price: price,
    currency: 'INR',
    cadence: BookingCadence.hourly,
    availableFrom: DateTime(2026, 5, 7, 9),
    availableUntil: DateTime(2026, 5, 7, 18),
    slotsAvailable: 1,
    location: const GeoPoint(latitude: 13.08, longitude: 80.27),
    amenities: const [ParkingAmenity.covered],
    imageUrl: 'https://example.com/parking.jpg',
    isHostedByCurrentUser: true,
    listingRevision: revision,
    version: version,
  );
}
