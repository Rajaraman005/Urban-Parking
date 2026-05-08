import 'booking.dart';

abstract class BookingRepository {
  Future<ParkingBooking> approveBooking({
    required int expectedVersion,
    required String bookingId,
  });

  Future<ParkingBooking> createBooking(CreateBookingRequest request);

  Future<List<ParkingBooking>> listBookings(BookingListRole role);

  Future<ParkingBooking> rejectBooking({
    required int expectedVersion,
    required String bookingId,
  });
}
