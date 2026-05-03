import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../booking/domain/booking_quote.dart';
import '../../parking/domain/parking_spot.dart';

final bookingControllerProvider = FutureProvider.family<BookingState, String>((
  ref,
  spotId,
) async {
  final repository = ref.watch(parkingRepositoryProvider);
  final startAt = DateTime.now().add(const Duration(hours: 1));
  final endAt = startAt.add(const Duration(hours: 3));
  final results = await Future.wait([
    repository.getById(spotId),
    repository.quoteBooking(spotId: spotId, startAt: startAt, endAt: endAt),
  ]);
  return BookingState(
    spot: results[0] as ParkingSpot,
    quote: results[1] as BookingQuote,
  );
});

class BookingState {
  const BookingState({required this.spot, required this.quote});

  final ParkingSpot spot;
  final BookingQuote quote;
}
