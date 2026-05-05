import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/booking/presentation/booking_controller.dart';
import 'package:urban_parking/features/parking/domain/parking_spot.dart';

void main() {
  test(
    'initial selection uses available date and rounds start to slot step',
    () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final spot = ParkingSpot(
        id: 'spot-1',
        title: 'Test parking',
        address: 'Test address',
        locality: 'Test',
        distanceKm: 1,
        rating: 4.8,
        reviewCount: 10,
        price: 80,
        currency: 'INR',
        cadence: BookingCadence.hourly,
        availableFrom: DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          9,
          10,
          15,
        ),
        availableUntil: DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          12,
        ),
        slotsAvailable: 2,
        location: const GeoPoint(latitude: 13.08, longitude: 80.27),
        amenities: const [ParkingAmenity.covered],
        imageUrl: 'https://example.com/parking.jpg',
      );

      final selection = BookingTimeSelection.initialFor(spot);

      expect(selection, isNotNull);
      expect(selection!.startAt.hour, 9);
      expect(selection.startAt.minute, 30);
      expect(selection.endAt.hour, 10);
      expect(selection.endAt.minute, 30);
    },
  );

  test('end options stay inside the advertised availability window', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final spot = ParkingSpot(
      id: 'spot-1',
      title: 'Test parking',
      address: 'Test address',
      locality: 'Test',
      distanceKm: 1,
      rating: 4.8,
      reviewCount: 10,
      price: 80,
      currency: 'INR',
      cadence: BookingCadence.hourly,
      availableFrom: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8),
      availableUntil: DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        10,
        30,
      ),
      slotsAvailable: 2,
      location: const GeoPoint(latitude: 13.08, longitude: 80.27),
      amenities: const [ParkingAmenity.covered],
      imageUrl: 'https://example.com/parking.jpg',
    );
    final startAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);

    final endOptions = BookingTimeSelection.endOptionsFor(spot, startAt);

    expect(endOptions.map((entry) => entry.hour), [10, 10]);
    expect(endOptions.map((entry) => entry.minute), [0, 30]);
  });

  test('available dates include the full advertised booking range', () {
    final startDate = DateTime.now().add(const Duration(days: 1));
    final endDate = startDate.add(const Duration(days: 5));
    final spot = ParkingSpot(
      id: 'spot-1',
      title: 'Test parking',
      address: 'Test address',
      locality: 'Test',
      distanceKm: 1,
      rating: 4.8,
      reviewCount: 10,
      price: 80,
      currency: 'INR',
      cadence: BookingCadence.hourly,
      availableFrom: DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        8,
      ),
      availableUntil: DateTime(endDate.year, endDate.month, endDate.day, 22),
      slotsAvailable: 2,
      location: const GeoPoint(latitude: 13.08, longitude: 80.27),
      amenities: const [ParkingAmenity.covered],
      imageUrl: 'https://example.com/parking.jpg',
    );

    final availableDates = BookingTimeSelection.availableDatesFor(spot);

    expect(availableDates, hasLength(6));
    expect(availableDates.first.day, startDate.day);
    expect(availableDates.last.day, endDate.day);
  });

  test('all-day owner windows stay inside the advertised end month', () {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final monthLabel = DateFormat('MMM').format(monthStart);
    final spot = ParkingSpot.fromJson({
      'id': 'spot-1',
      'title': 'Owner scheduled spot',
      'price': 80,
      'availability_summary':
          '1 $monthLabel - ${monthEnd.day} $monthLabel, All day',
      'availableFrom': DateTime(
        monthStart.year,
        monthStart.month,
        monthStart.day,
        8,
      ).toIso8601String(),
      'availableUntil': DateTime(
        monthEnd.year,
        monthEnd.month,
        monthEnd.day,
        20,
      ).toIso8601String(),
    });

    final availableDates = BookingTimeSelection.availableDatesFor(spot);
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59);
    final expectedFirstDate =
        todayEnd.difference(now) >= BookingTimeSelection.minimumDuration
        ? todayStart
        : todayStart.add(const Duration(days: 1));

    expect(availableDates.first, expectedFirstDate);
    expect(
      availableDates.last,
      DateTime(monthEnd.year, monthEnd.month, monthEnd.day),
    );
    expect(
      availableDates.any(
        (date) => date.year != now.year || date.month != now.month,
      ),
      isFalse,
    );
  });
}
