import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../booking/domain/booking_quote.dart';
import 'parking_spot.dart';

abstract interface class ParkingRepository {
  Future<List<ParkingSpot>> searchNearby({
    required GeoPoint center,
    required double radiusKm,
  });

  Future<ParkingSpot> getById(String id);

  Future<BookingQuote> quoteBooking({
    required String spotId,
    required DateTime startAt,
    required DateTime endAt,
  });
}
