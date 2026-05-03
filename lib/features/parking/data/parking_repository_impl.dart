import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/geo_discovery/geo_discovery_engine.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../booking/domain/booking_quote.dart';
import '../domain/parking_repository.dart';
import '../domain/parking_spot.dart';

class ParkingRepositoryImpl implements ParkingRepository {
  const ParkingRepositoryImpl({
    required ApiClient apiClient,
    required GeoDiscoveryEngine geoDiscoveryEngine,
  }) : _apiClient = apiClient,
       _geoDiscoveryEngine = geoDiscoveryEngine;

  final ApiClient _apiClient;
  final GeoDiscoveryEngine _geoDiscoveryEngine;

  @override
  Future<List<ParkingSpot>> searchNearby({
    required GeoPoint center,
    required double radiusKm,
  }) async {
    final page = await _geoDiscoveryEngine.getNearby(
      GeoDiscoveryQuery(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusKm: radiusKm,
        serviceType: ServiceType.parking,
      ),
    );
    return page.items.map((item) => ParkingSpot.fromJson(item.entity)).toList();
  }

  @override
  Future<ParkingSpot> getById(String id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, Object?>>(
        '/parking-spots/$id',
      );
      return ParkingSpot.fromJson(response.data);
    } on DioException catch (_) {
      final page = await _geoDiscoveryEngine.getNearby(
        const GeoDiscoveryQuery(
          latitude: 13.0827,
          longitude: 80.2707,
          radiusKm: 10,
          serviceType: ServiceType.parking,
          pageSize: 50,
        ),
      );
      final match = page.items
          .where((item) => item.id == id)
          .map((item) => ParkingSpot.fromJson(item.entity))
          .firstOrNull;
      if (match != null) return match;
      throw Exception('Parking spot not found.');
    }
  }

  @override
  Future<BookingQuote> quoteBooking({
    required String spotId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, Object?>>(
        '/bookings/quote',
        data: {
          'spotId': spotId,
          'startAt': startAt.toIso8601String(),
          'endAt': endAt.toIso8601String(),
        },
      );
      return BookingQuote.fromJson(response.data ?? const {});
    } on DioException {
      final spot = await getById(spotId);
      final durationHours = endAt.difference(startAt).inHours.clamp(1, 24);
      final subtotal = spot.price * durationHours;
      final platformFee = (subtotal * 0.08).round();
      final taxes = ((subtotal + platformFee) * 0.18).round();
      return BookingQuote(
        spotId: spotId,
        startAt: startAt,
        endAt: endAt,
        subtotal: subtotal,
        platformFee: platformFee,
        taxes: taxes,
        total: subtotal + platformFee + taxes,
        currency: spot.currency,
      );
    }
  }
}
