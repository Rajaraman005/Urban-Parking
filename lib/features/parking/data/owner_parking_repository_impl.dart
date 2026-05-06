import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/owner_parking_repository.dart';
import '../domain/parking_spot.dart';

class OwnerParkingRepositoryImpl implements OwnerParkingRepository {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<List<ParkingSpot>> listOwnedSpaces() async {
    _assertReady();
    try {
      final response = await _client.rpc('get_owned_parking_spaces');
      if (response is! List) {
        return const [];
      }
      return response
          .whereType<Map>()
          .map(
            (entry) => ParkingSpot.fromJson(Map<String, Object?>.from(entry)),
          )
          .toList(growable: false);
    } on sb.PostgrestException catch (error) {
      throw AuthFailure(
        'Could not load your parking spaces.',
        code: error.code ?? 'owned_parking_load_failed',
      );
    }
  }

  @override
  Future<List<ParkingAddressCandidate>> searchAddress(String query) async {
    _assertReady();
    final normalized = query.trim();
    if (normalized.length < 4) {
      throw const ValidationFailure(
        'Enter a more specific address.',
        code: 'address_query_too_short',
      );
    }

    final data = await _invokeFunctionData('search-address', {
      'query': normalized,
    });
    final results = data['results'];
    if (results is! List) {
      return const [];
    }
    return results
        .whereType<Map>()
        .map(
          (entry) => ParkingAddressCandidate.fromJson(
            Map<String, Object?>.from(entry),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ParkingSpot> updateListingAddress({
    required String spotId,
    required OwnedListingAddressUpdate update,
  }) async {
    _assertReady();
    _validateAddress(update);
    try {
      final response = await _client.rpc(
        'update_owned_parking_space_address',
        params: {
          'p_address': update.address.trim(),
          'p_address_confidence': update.confidence,
          'p_address_place_id': update.placeId,
          'p_address_provider': update.provider,
          'p_address_raw_osm_json': update.raw,
          'p_city': update.city.trim(),
          'p_expected_version': update.expectedVersion,
          'p_latitude': update.latitude,
          'p_locality': update.locality.trim(),
          'p_longitude': update.longitude,
          'p_postal_code': update.postalCode.trim(),
          'p_space_id': spotId,
        },
      );
      return _spotFromRpc(response);
    } on AppFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw _parkingFailure(
        error,
        fallbackMessage: 'Could not update the address.',
      );
    }
  }

  @override
  Future<ParkingSpot> updateListingPricing({
    required String spotId,
    required OwnedListingPricingUpdate update,
  }) async {
    _assertReady();
    _validatePricing(update);
    try {
      final response = await _client.rpc(
        'update_owned_parking_space_pricing',
        params: {
          'p_available_from_date': _dateOnly(update.availableFromDate),
          'p_available_to_date': _dateOnly(update.availableToDate),
          'p_daily_end_minute': update.dailyEndMinute,
          'p_daily_start_minute': update.dailyStartMinute,
          'p_expected_version': update.expectedVersion,
          'p_hourly_price': update.hourlyPrice,
          'p_slots_count': update.slotsCount,
          'p_space_id': spotId,
        },
      );
      return _spotFromRpc(response);
    } on AppFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw _parkingFailure(
        error,
        fallbackMessage: 'Could not update the pricing.',
      );
    }
  }

  Future<Map<String, Object?>> _invokeFunctionData(
    String name,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await _client.functions.invoke(name, body: body);
      final data = response.data;
      if (response.status >= 400 || data is! Map || data['ok'] != true) {
        throw AuthFailure(
          data is Map
              ? data['message']?.toString() ?? 'Address lookup failed.'
              : 'Address lookup failed.',
          code: data is Map ? data['code']?.toString() : name,
        );
      }
      final payload = data['data'];
      if (payload is! Map) {
        throw const AuthFailure(
          'Address lookup returned an invalid response.',
          code: 'address_lookup_invalid_response',
        );
      }
      return Map<String, Object?>.from(payload);
    } on sb.FunctionException catch (error) {
      throw NetworkFailure(
        'Address lookup is temporarily unavailable.',
        code: 'address_lookup_${error.status}',
      );
    }
  }

  ParkingSpot _spotFromRpc(Object? response) {
    if (response is Map) {
      return ParkingSpot.fromJson(Map<String, Object?>.from(response));
    }
    throw const NetworkFailure(
      'Listing service returned an invalid response.',
      code: 'listing_invalid_response',
    );
  }

  AppFailure _parkingFailure(
    sb.PostgrestException error, {
    required String fallbackMessage,
  }) {
    final code = error.code ?? 'owner_listing_update_failed';
    if (code == '40001') {
      return const ValidationFailure(
        'This listing changed elsewhere. Refresh and try again.',
        code: 'listing_version_conflict',
      );
    }
    if (code == '23514') {
      return ValidationFailure(
        error.message.isEmpty ? 'Check the listing details.' : error.message,
        code: 'listing_validation_failed',
      );
    }
    if (code == 'P0002') {
      return const AuthFailure(
        'Active listing not found for this account.',
        code: 'owned_listing_not_found',
      );
    }
    return AuthFailure(fallbackMessage, code: code);
  }

  void _validateAddress(OwnedListingAddressUpdate update) {
    if (update.address.trim().length < 8 ||
        update.locality.trim().length < 2 ||
        update.city.trim().length < 2) {
      throw const ValidationFailure(
        'Choose a complete parking address.',
        code: 'listing_address_incomplete',
      );
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(update.postalCode.trim())) {
      throw const ValidationFailure(
        'Enter a valid 6 digit Indian PIN code.',
        code: 'listing_postal_code_invalid',
      );
    }
    if (update.latitude < 6 ||
        update.latitude > 38 ||
        update.longitude < 68 ||
        update.longitude > 98) {
      throw const ValidationFailure(
        'Choose a location inside India.',
        code: 'listing_location_out_of_bounds',
      );
    }
    if (update.confidence < 0 || update.confidence > 1) {
      throw const ValidationFailure(
        'Choose a verified map result.',
        code: 'listing_address_confidence_invalid',
      );
    }
    if (!const {'nominatim', 'manual'}.contains(update.provider)) {
      throw const ValidationFailure(
        'Choose a supported address provider.',
        code: 'listing_address_provider_invalid',
      );
    }
  }

  void _validatePricing(OwnedListingPricingUpdate update) {
    if (update.hourlyPrice < 10 || update.hourlyPrice > 10000) {
      throw const ValidationFailure(
        'Hourly price must be between INR 10 and INR 10,000.',
        code: 'listing_price_invalid',
      );
    }
    if (update.slotsCount < 1 || update.slotsCount > 50) {
      throw const ValidationFailure(
        'Slots must be between 1 and 50.',
        code: 'listing_slots_invalid',
      );
    }
    final from = DateTime(
      update.availableFromDate.year,
      update.availableFromDate.month,
      update.availableFromDate.day,
    );
    final to = DateTime(
      update.availableToDate.year,
      update.availableToDate.month,
      update.availableToDate.day,
    );
    if (to.isBefore(from)) {
      throw const ValidationFailure(
        'End date cannot be before start date.',
        code: 'listing_date_range_invalid',
      );
    }
    if (update.dailyStartMinute < 0 ||
        update.dailyStartMinute > 1410 ||
        update.dailyEndMinute < 30 ||
        update.dailyEndMinute > 1440 ||
        update.dailyStartMinute % 30 != 0 ||
        update.dailyEndMinute % 30 != 0 ||
        update.dailyEndMinute <= update.dailyStartMinute) {
      throw const ValidationFailure(
        'Daily availability must use a valid 30 minute window.',
        code: 'listing_daily_window_invalid',
      );
    }
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  void _assertReady() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const ConfigurationFailure(
        'Supabase is not configured for this build.',
        code: 'supabase_not_configured',
      );
    }
    if (_client.auth.currentUser == null) {
      throw const AuthFailure('Session expired.', code: 'session_expired');
    }
  }
}
