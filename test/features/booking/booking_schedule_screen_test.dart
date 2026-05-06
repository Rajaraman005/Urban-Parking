import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:urban_parking/config/app_providers.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/booking/domain/booking_quote.dart';
import 'package:urban_parking/features/booking/presentation/booking_schedule_screen.dart';
import 'package:urban_parking/features/parking/domain/parking_repository.dart';
import 'package:urban_parking/features/parking/domain/parking_spot.dart';

void main() {
  testWidgets('booking schedule screen shows calendar and reserve CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parkingRepositoryProvider.overrideWithValue(_FakeParkingRepository()),
        ],
        child: const MaterialApp(home: BookingScheduleScreen(spotId: 'spot-1')),
      ),
    );

    await tester.pumpAndSettle();

    final pageScrollView = find.byType(Scrollable).first;

    expect(find.text('Schedule Booking'), findsOneWidget);
    expect(find.text('Select date'), findsOneWidget);
    expect(find.text('Reserve Slot'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Vehicle type'),
      180,
      scrollable: pageScrollView,
    );
    await tester.pumpAndSettle();
    expect(find.text('Vehicle type'), findsOneWidget);
    await tester.drag(pageScrollView, const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(find.text('Booking summary'), findsOneWidget);
    expect(find.text('\u20B959'), findsWidgets);
  });

  testWidgets('reserve CTA stays disabled until time details are confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parkingRepositoryProvider.overrideWithValue(_FakeParkingRepository()),
        ],
        child: const MaterialApp(home: BookingScheduleScreen(spotId: 'spot-1')),
      ),
    );

    await tester.pumpAndSettle();

    InkWell reserveButton() =>
        tester.widget<InkWell>(find.byKey(const ValueKey('reserve-slot-cta')));

    expect(find.text('Select time'), findsOneWidget);
    expect(reserveButton().onTap, isNull);

    await tester.scrollUntilVisible(
      find.text('From'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('From'));
    await tester.pumpAndSettle();

    expect(find.text('Choose time'), findsOneWidget);
    expect(find.byKey(const ValueKey('time-range-apply')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('time-range-apply')));
    await tester.tap(find.byKey(const ValueKey('time-range-apply')));
    await tester.pumpAndSettle();

    expect(find.text('\u20B959'), findsWidgets);
    expect(reserveButton().onTap, isNotNull);
  });

  testWidgets('time range sheet closes when tapping outside', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parkingRepositoryProvider.overrideWithValue(_FakeParkingRepository()),
        ],
        child: const MaterialApp(home: BookingScheduleScreen(spotId: 'spot-1')),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('From'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('From'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('time-range-apply')), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('time-range-apply')), findsNothing);
  });

  testWidgets('vertical drag on the calendar still scrolls the booking page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parkingRepositoryProvider.overrideWithValue(_FakeParkingRepository()),
        ],
        child: const MaterialApp(home: BookingScheduleScreen(spotId: 'spot-1')),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Booking summary'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('booking-calendar')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking summary'), findsOneWidget);
  });

  testWidgets('displayed booking pricing uses vehicle-specific platform fee', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parkingRepositoryProvider.overrideWithValue(_FakeParkingRepository()),
        ],
        child: const MaterialApp(home: BookingScheduleScreen(spotId: 'spot-1')),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Platform fee'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('\u20B98'), findsOneWidget);
    expect(find.text('\u20B91'), findsOneWidget);
    expect(find.text('\u20B959'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('vehicle-toggle-bike')));
    await tester.pumpAndSettle();

    expect(find.text('\u20B95'), findsOneWidget);
    expect(find.text('\u20B956'), findsWidgets);
  });

  testWidgets('same-day booking summary keeps the date only once', (
    tester,
  ) async {
    final startAt = DateTime(2026, 5, 7, 9);
    final endAt = DateTime(2026, 5, 7, 18);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parkingRepositoryProvider.overrideWithValue(
            _FakeParkingRepository(
              availableFrom: startAt,
              availableUntil: endAt,
            ),
          ),
        ],
        child: const MaterialApp(home: BookingScheduleScreen(spotId: 'spot-1')),
      ),
    );

    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();

    final expectedLabel =
        '${DateFormat('EEE, d MMM h:mm a').format(startAt)} to ${DateFormat('h:mm a').format(startAt.add(const Duration(hours: 1)))}';

    expect(find.text(expectedLabel), findsOneWidget);
  });
}

class _FakeParkingRepository implements ParkingRepository {
  _FakeParkingRepository({DateTime? availableFrom, DateTime? availableUntil})
    : _availableFrom = availableFrom,
      _availableUntil = availableUntil;

  final DateTime? _availableFrom;
  final DateTime? _availableUntil;

  @override
  Future<ParkingSpot> getById(String id) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final availableFrom =
        _availableFrom ??
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 10);
    final availableUntil =
        _availableUntil ??
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 13);
    return ParkingSpot(
      id: id,
      title: 'Car parking',
      address: 'Ambasamudram, Tirunelveli, Tamil Nadu',
      locality: 'Ambasamudram',
      distanceKm: 1.2,
      rating: 4.8,
      reviewCount: 24,
      price: 50,
      currency: 'INR',
      cadence: BookingCadence.hourly,
      availableFrom: availableFrom,
      availableUntil: availableUntil,
      slotsAvailable: 1,
      location: const GeoPoint(latitude: 13.08, longitude: 80.27),
      amenities: const [ParkingAmenity.covered],
      imageUrl: 'https://example.com/parking.jpg',
    );
  }

  @override
  Future<BookingQuote> quoteBooking({
    required String spotId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final durationHours = (endAt.difference(startAt).inMinutes / 60)
        .ceil()
        .clamp(1, 24);
    final subtotal = 50 * durationHours;
    return BookingQuote(
      spotId: spotId,
      startAt: startAt,
      endAt: endAt,
      subtotal: subtotal,
      platformFee: 4,
      taxes: 10,
      total: subtotal + 14,
      currency: 'INR',
    );
  }

  @override
  Future<List<ParkingSpot>> searchNearby({
    required GeoPoint center,
    required double radiusKm,
  }) async {
    return [await getById('spot-1')];
  }
}
