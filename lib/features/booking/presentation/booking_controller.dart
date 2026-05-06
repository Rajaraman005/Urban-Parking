import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../booking/domain/booking_quote.dart';
import '../../parking/domain/parking_spot.dart';
import '../../parking/presentation/parking_listing_store.dart';

final bookingSpotProvider = FutureProvider.family<ParkingSpot, String>((
  ref,
  spotId,
) {
  ref.watch(parkingListingRevisionSyncProvider(spotId));
  return ref.watch(liveParkingSpotProvider(spotId).future);
});

final bookingQuoteProvider =
    FutureProvider.family<BookingQuote, BookingQuoteRequest>((ref, request) {
      return ref
          .watch(parkingRepositoryProvider)
          .quoteBooking(
            spotId: request.spotId,
            startAt: request.startAt,
            endAt: request.endAt,
          );
    });

final bookingControllerProvider = FutureProvider.family<BookingState, String>((
  ref,
  spotId,
) async {
  final spot = await ref.watch(bookingSpotProvider(spotId).future);
  final selection = BookingTimeSelection.initialFor(spot);
  if (selection == null) {
    throw Exception('This parking space is not available for booking.');
  }
  final quote = await ref.watch(
    bookingQuoteProvider(
      BookingQuoteRequest(
        spotId: spotId,
        startAt: selection.startAt,
        endAt: selection.endAt,
      ),
    ).future,
  );
  return BookingState(spot: spot, quote: quote);
});

class BookingState {
  const BookingState({required this.spot, required this.quote});

  final ParkingSpot spot;
  final BookingQuote quote;
}

class BookingQuoteRequest {
  const BookingQuoteRequest({
    required this.spotId,
    required this.startAt,
    required this.endAt,
  });

  final String spotId;
  final DateTime startAt;
  final DateTime endAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingQuoteRequest &&
          spotId == other.spotId &&
          startAt == other.startAt &&
          endAt == other.endAt;

  @override
  int get hashCode => Object.hash(spotId, startAt, endAt);
}

class BookingTimeSelection {
  const BookingTimeSelection({required this.startAt, required this.endAt});

  static const maxVisibleBookingDays = 366;
  static const slotStep = Duration(minutes: 30);
  static const minimumDuration = Duration(hours: 1);

  final DateTime startAt;
  final DateTime endAt;

  BookingTimeSelection copyWith({DateTime? startAt, DateTime? endAt}) {
    return BookingTimeSelection(
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }

  static BookingTimeSelection? initialFor(ParkingSpot spot) {
    final dates = availableDatesFor(spot);
    if (dates.isEmpty) return null;

    for (final date in dates) {
      final startOptions = startOptionsFor(spot, date);
      if (startOptions.isEmpty) continue;
      final startAt = startOptions.first;
      final endOptions = endOptionsFor(spot, startAt);
      if (endOptions.isEmpty) continue;
      return BookingTimeSelection(startAt: startAt, endAt: endOptions.first);
    }

    return null;
  }

  static List<DateTime> availableDatesFor(ParkingSpot spot) {
    final now = DateTime.now();
    final firstDate = _dateOnly(
      spot.availableFrom.isAfter(now) ? spot.availableFrom : now,
    );
    final lastDate = _dateOnly(spot.availableUntil);
    if (lastDate.isBefore(firstDate)) return const [];

    final dayCount = lastDate.difference(firstDate).inDays + 1;
    return List.generate(
      dayCount.clamp(0, maxVisibleBookingDays).toInt(),
      (index) => firstDate.add(Duration(days: index)),
      growable: false,
    ).where((date) => _windowFor(spot, date) != null).toList(growable: false);
  }

  static List<DateTime> startOptionsFor(ParkingSpot spot, DateTime date) {
    final window = _windowFor(spot, date);
    if (window == null) return const [];

    final options = <DateTime>[];
    var cursor = _roundUpToStep(window.start);
    final latestStart = window.end.subtract(minimumDuration);
    while (!cursor.isAfter(latestStart)) {
      options.add(cursor);
      cursor = cursor.add(slotStep);
    }
    return options;
  }

  static List<DateTime> endOptionsFor(ParkingSpot spot, DateTime startAt) {
    final window = _windowFor(spot, _dateOnly(startAt));
    if (window == null) return const [];

    final options = <DateTime>[];
    var cursor = startAt.add(minimumDuration);
    while (!cursor.isAfter(window.end)) {
      options.add(cursor);
      cursor = cursor.add(slotStep);
    }
    return options;
  }

  static ({DateTime start, DateTime end})? _windowFor(
    ParkingSpot spot,
    DateTime date,
  ) {
    final dateOnly = _dateOnly(date);
    var start = DateTime(
      dateOnly.year,
      dateOnly.month,
      dateOnly.day,
      spot.availableFrom.hour,
      spot.availableFrom.minute,
    );
    var end = DateTime(
      dateOnly.year,
      dateOnly.month,
      dateOnly.day,
      spot.availableUntil.hour,
      spot.availableUntil.minute,
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    if (_isSameDate(dateOnly, spot.availableFrom) &&
        spot.availableFrom.isAfter(start)) {
      start = spot.availableFrom;
    }
    if (_isSameDate(dateOnly, spot.availableUntil) &&
        spot.availableUntil.isBefore(end)) {
      end = spot.availableUntil;
    }

    final now = DateTime.now();
    if (_isSameDate(dateOnly, now) && now.isAfter(start)) {
      start = now;
    }

    if (!end.difference(start).isNegative &&
        end.difference(start) >= minimumDuration) {
      return (start: start, end: end);
    }
    return null;
  }

  static DateTime _roundUpToStep(DateTime value) {
    final cleanValue = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
    final hasSubMinutePrecision =
        value.second > 0 || value.millisecond > 0 || value.microsecond > 0;
    final minute = cleanValue.minute;
    var extraMinutes = minute % slotStep.inMinutes == 0
        ? 0
        : slotStep.inMinutes - (minute % slotStep.inMinutes);
    if (hasSubMinutePrecision && extraMinutes == 0) {
      extraMinutes = slotStep.inMinutes;
    }
    return cleanValue.add(Duration(minutes: extraMinutes));
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
