import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<ParkingBooking> approveBooking({
    required int expectedVersion,
    required String bookingId,
  }) {
    return _transition(
      bookingId: bookingId,
      expectedVersion: expectedVersion,
      transition: 'approve',
    );
  }

  @override
  Future<ParkingBooking> createBooking(CreateBookingRequest request) async {
    try {
      final response = await _apiClient.dio.post<Map<String, Object?>>(
        '/bookings',
        data: request.toJson(),
      );
      return ParkingBooking.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure(
        'Could not create this booking. Please try again.',
        code: 'booking_create_failed',
      );
    }
  }

  @override
  Future<List<ParkingBooking>> listBookings(BookingListRole role) async {
    try {
      final response = await _apiClient.dio.get<Map<String, Object?>>(
        '/bookings',
        queryParameters: {'role': role.name},
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items.map(ParkingBooking.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure(
        'Could not load bookings. Please try again.',
        code: 'booking_list_failed',
      );
    }
  }

  @override
  Future<ParkingBooking> rejectBooking({
    required int expectedVersion,
    required String bookingId,
  }) {
    return _transition(
      bookingId: bookingId,
      expectedVersion: expectedVersion,
      transition: 'reject',
    );
  }

  Future<ParkingBooking> _transition({
    required String bookingId,
    required int expectedVersion,
    required String transition,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, Object?>>(
        '/bookings/$bookingId/$transition',
        data: {'expectedVersion': expectedVersion},
      );
      return ParkingBooking.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure(
        'Could not update this booking. Refresh and try again.',
        code: 'booking_transition_failed',
      );
    }
  }
}
