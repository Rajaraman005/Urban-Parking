import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/geo_discovery_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/geo_discovery/geo_discovery_engine.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../booking/domain/booking_quote.dart';
import '../domain/parking_availability.dart';
import '../domain/parking_repository.dart';
import '../domain/parking_spot.dart';
import 'parking_spot_cache.dart';

class ParkingRepositoryImpl implements ParkingRepository {
  const ParkingRepositoryImpl({
    required ApiClient apiClient,
    required GeoDiscoveryEngine geoDiscoveryEngine,
    required ParkingSpotCache parkingSpotCache,
  }) : _apiClient = apiClient,
       _geoDiscoveryEngine = geoDiscoveryEngine,
       _parkingSpotCache = parkingSpotCache;

  final ApiClient _apiClient;
  final GeoDiscoveryEngine _geoDiscoveryEngine;
  final ParkingSpotCache _parkingSpotCache;

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
    final spots = page.items.map(ParkingSpot.fromDiscoveryEntity).toList();
    _parkingSpotCache.upsertMany(spots);
    return spots;
  }

  @override
  Future<ParkingSpot> getById(
    String id, {
    ParkingSpotFetchPolicy fetchPolicy = ParkingSpotFetchPolicy.cacheFirst,
  }) async {
    final cached = fetchPolicy == ParkingSpotFetchPolicy.cacheFirst
        ? _parkingSpotCache.getById(id)
        : null;

    try {
      final spot = await _loadSpotWithUpgrade(id);
      _parkingSpotCache.upsert(spot);
      return spot;
    } on DioException {
      if (cached != null) return cached;
      final discovered = await _findByDiscovery(id);
      if (discovered != null) return discovered;
      throw Exception('Parking spot not found.');
    } catch (_) {
      if (cached != null) return cached;
      final discovered = await _findByDiscovery(id);
      if (discovered != null) return discovered;
      throw Exception('Parking spot not found.');
    }
  }

  @override
  Future<ParkingSpot> refreshById(String id) {
    return getById(id, fetchPolicy: ParkingSpotFetchPolicy.networkOnly);
  }

  Future<ParkingSpot> _loadSpotWithUpgrade(String id) async {
    try {
      final spot = await _loadSpotFromDatabase(id);
      _parkingSpotCache.upsert(spot);
      return spot;
    } catch (_) {
      // Fall through to HTTP while environments roll forward.
    }

    ParkingSpot? spot;

    try {
      spot = await _loadSpotFromApi(id, preferQueryRoute: false);
      _parkingSpotCache.upsert(spot);
      if (spot.imageUrls.length > 1) {
        return spot;
      }
    } on DioException {
      // Some deployed environments miss the dynamic route; retry the stable
      // query endpoint before falling back to stale discovery data.
    }

    final upgradedSpot = await _loadSpotFromApi(id, preferQueryRoute: true);
    _parkingSpotCache.upsert(upgradedSpot);
    if (spot == null) return upgradedSpot;
    return upgradedSpot.imageUrls.length >= spot.imageUrls.length
        ? upgradedSpot
        : spot;
  }

  Future<ParkingSpot> _loadSpotFromDatabase(String id) async {
    final response = await Supabase.instance.client.rpc(
      'get_public_parking_spot',
      params: {'p_space_id': id},
    );
    if (response is! Map) {
      throw Exception('Parking spot not found.');
    }

    final spot = ParkingSpot.fromJson(Map<String, Object?>.from(response));
    if (spot.id.trim().isEmpty) {
      throw Exception('Parking spot not found.');
    }
    return spot;
  }

  Future<ParkingSpot> _loadSpotFromApi(
    String id, {
    required bool preferQueryRoute,
  }) async {
    final response = preferQueryRoute
        ? await _apiClient.dio.get<Map<String, Object?>>(
            '/parking-spots',
            queryParameters: {'id': id},
          )
        : await _apiClient.dio.get<Map<String, Object?>>('/parking-spots/$id');
    final spot = ParkingSpot.fromJson(response.data);
    if (spot.id.trim().isEmpty) {
      throw Exception('Parking spot not found.');
    }
    return spot;
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
      final spot = _parkingSpotCache.getById(spotId) ?? await getById(spotId);
      return _localQuoteFor(spot: spot, startAt: startAt, endAt: endAt);
    } catch (_) {
      final spot = _parkingSpotCache.getById(spotId) ?? await getById(spotId);
      return _localQuoteFor(spot: spot, startAt: startAt, endAt: endAt);
    }
  }

  Future<ParkingSpot?> _findByDiscovery(String id) async {
    try {
      final page = await _geoDiscoveryEngine.getNearby(
        GeoDiscoveryQuery(
          latitude: AppConstants.chennaiCenter.latitude,
          longitude: AppConstants.chennaiCenter.longitude,
          radiusKm: GeoDiscoveryConfig.maxRadiusKm,
          serviceType: ServiceType.parking,
          pageSize: GeoDiscoveryConfig.maxPageSize,
        ),
      );
      final match = page.items
          .where((item) => item.id == id)
          .map(ParkingSpot.fromDiscoveryEntity)
          .firstOrNull;
      if (match != null) {
        _parkingSpotCache.upsert(match);
      }
      return match;
    } catch (_) {
      return null;
    }
  }

  BookingQuote _localQuoteFor({
    required ParkingSpot spot,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (spot.skipWeekends && parkingRangeContainsWeekend(startAt, endAt)) {
      throw Exception('This parking spot is not available on weekends.');
    }

    final minutes = endAt.difference(startAt).inMinutes;
    final durationHours = (minutes / 60).ceil().clamp(1, 24).toInt();
    final subtotal = spot.price * durationHours;
    final platformFee = (subtotal * 0.15).round();
    final taxes = (platformFee * 0.18).round();
    return BookingQuote(
      spotId: spot.id,
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
