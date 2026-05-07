import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/owner_parking_repository.dart';
import '../domain/parking_availability.dart';
import '../domain/parking_spot.dart';

bool isPricingSkipWeekendsRpcUnavailable(sb.PostgrestException error) {
  final text = [error.message, error.details, error.hint]
      .whereType<Object>()
      .map((value) => value.toString())
      .join(' ')
      .toLowerCase();
  final isFunctionLookupFailure =
      error.code == 'PGRST202' ||
      error.code == 'PGRST203' ||
      text.contains('could not find the function') ||
      text.contains('schema cache') ||
      text.contains('overloaded') ||
      text.contains('parameter');

  return isFunctionLookupFailure &&
      text.contains('update_owned_parking_space_pricing');
}

class OwnerParkingRepositoryImpl implements OwnerParkingRepository {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<List<ParkingSpot>> listOwnedSpaces() async {
    _assertReady();
    try {
      final response = await _client
          .from('parking_spaces')
          .select(
            '*, parking_space_photos(parking_space_id, secure_url, sort_order, upload_status)',
          )
          .eq('host_id', _client.auth.currentUser!.id)
          .inFilter('status', const ['active', 'draft', 'pending_review'])
          .order('updated_at', ascending: false);
      final legacySpaces = response
          .whereType<Map>()
          .map(
            (entry) => ParkingSpot.fromJson(Map<String, Object?>.from(entry)),
          )
          .toList(growable: false);
      final v2Drafts = await _listHostParkingDrafts();
      return [...v2Drafts, ...legacySpaces];
    } on sb.PostgrestException catch (error) {
      throw AuthFailure(
        'Could not load your parking spaces.',
        code: error.code ?? 'owned_parking_load_failed',
      );
    }
  }

  Future<List<ParkingSpot>> _listHostParkingDrafts() async {
    try {
      final response = await _client.rpc('get_owned_host_parking_drafts');
      if (response is! List) return const [];
      return response
          .whereType<Map>()
          .map(
            (entry) => ParkingSpot.fromJson(Map<String, Object?>.from(entry)),
          )
          .toList(growable: false);
    } on sb.PostgrestException catch (error) {
      final text = [error.message, error.details, error.hint]
          .whereType<Object>()
          .map((value) => value.toString())
          .join(' ')
          .toLowerCase();
      if (error.code == 'PGRST202' || text.contains('schema cache')) {
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteListing(String spotId) async {
    _assertReady();
    try {
      await _client.rpc(
        'delete_owned_parking_listing',
        params: {'p_listing_id': spotId},
      );
    } on sb.PostgrestException catch (error) {
      throw _deleteListingFailure(error);
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
      appLogger.info('owner_pricing_repository_update_requested', {
        ..._pricingUpdateLogPayload(spotId: spotId, update: update),
        'path': 'new_rpc',
      });
      final response = await _invokePricingRpc(
        spotId: spotId,
        update: update,
        includeSkipWeekends: true,
      );
      appLogger.info('owner_pricing_repository_update_succeeded', {
        'spotId': spotId,
        'path': 'new_rpc',
        'responseType': response.runtimeType.toString(),
      });
      return _spotFromRpc(response);
    } on AppFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      appLogger.error('owner_pricing_repository_update_failed', {
        ..._pricingUpdateLogPayload(spotId: spotId, update: update),
        ..._postgrestLogPayload(error),
        'path': 'new_rpc',
      }, error);
      if (isPricingSkipWeekendsRpcUnavailable(error)) {
        try {
          appLogger.warn('owner_pricing_repository_fallback_requested', {
            ..._pricingUpdateLogPayload(spotId: spotId, update: update),
            'reason': 'pricing_rpc_signature_drift',
            'path': 'legacy_rpc',
          });
          final response = await _invokePricingRpc(
            spotId: spotId,
            update: update,
            includeSkipWeekends: false,
          );
          appLogger.info('owner_pricing_repository_fallback_succeeded', {
            'spotId': spotId,
            'path': 'legacy_rpc',
            'responseType': response.runtimeType.toString(),
          });
          return _spotFromRpc(response);
        } on sb.PostgrestException catch (fallbackError) {
          appLogger.error('owner_pricing_repository_fallback_failed', {
            ..._pricingUpdateLogPayload(spotId: spotId, update: update),
            ..._postgrestLogPayload(fallbackError),
            'path': 'legacy_rpc',
          }, fallbackError);
          throw _parkingFailure(
            fallbackError,
            fallbackMessage: 'Could not update the pricing.',
          );
        }
      }
      throw _parkingFailure(
        error,
        fallbackMessage: 'Could not update the pricing.',
      );
    }
  }

  Future<Object?> _invokePricingRpc({
    required String spotId,
    required OwnedListingPricingUpdate update,
    required bool includeSkipWeekends,
  }) {
    final params = <String, Object?>{
      'p_available_from_date': _dateOnly(update.availableFromDate),
      'p_available_to_date': _dateOnly(update.availableToDate),
      'p_daily_end_minute': update.dailyEndMinute,
      'p_daily_start_minute': update.dailyStartMinute,
      'p_expected_version': update.expectedVersion,
      'p_hourly_price': update.hourlyPrice,
      'p_slots_count': update.slotsCount,
      'p_space_id': spotId,
    };
    if (includeSkipWeekends) {
      params['p_skip_weekends'] = update.skipWeekends;
    }

    appLogger.info('owner_pricing_rpc_calling', {
      'spotId': spotId,
      'includeSkipWeekends': includeSkipWeekends,
      'paramKeys': params.keys.toList(growable: false).join(','),
      'expectedVersion': update.expectedVersion,
      'hourlyPrice': update.hourlyPrice,
      'slotsCount': update.slotsCount,
      'availableFromDate': _dateOnly(update.availableFromDate),
      'availableToDate': _dateOnly(update.availableToDate),
      'dailyStartMinute': update.dailyStartMinute,
      'dailyEndMinute': update.dailyEndMinute,
      'skipWeekends': update.skipWeekends,
    });
    return _client.rpc('update_owned_parking_space_pricing', params: params);
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

  AppFailure _deleteListingFailure(sb.PostgrestException error) {
    final code = error.code ?? 'delete_listing_failed';
    if (code == 'P0002') {
      return const AuthFailure(
        'Listing was not found for this account.',
        code: 'owned_listing_not_found',
      );
    }
    if (code == '42501') {
      return const AuthFailure(
        'Sign in again before deleting this listing.',
        code: 'delete_listing_unauthorized',
      );
    }
    return AuthFailure('Could not delete the listing.', code: code);
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
    if (!parkingRangeContainsBookableDay(
      from,
      to,
      skipWeekends: update.skipWeekends,
    )) {
      throw const ValidationFailure(
        'Date range must include at least one weekday.',
        code: 'listing_date_range_has_no_bookable_days',
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

  Map<String, Object?> _pricingUpdateLogPayload({
    required String spotId,
    required OwnedListingPricingUpdate update,
  }) {
    return {
      'spotId': spotId,
      'expectedVersion': update.expectedVersion,
      'hourlyPrice': update.hourlyPrice,
      'slotsCount': update.slotsCount,
      'availableFromDate': _dateOnly(update.availableFromDate),
      'availableToDate': _dateOnly(update.availableToDate),
      'dailyStartMinute': update.dailyStartMinute,
      'dailyEndMinute': update.dailyEndMinute,
      'skipWeekends': update.skipWeekends,
    };
  }

  Map<String, Object?> _postgrestLogPayload(sb.PostgrestException error) {
    return {
      'postgrestCode': error.code,
      'postgrestMessage': error.message,
      'postgrestDetails': error.details?.toString(),
      'postgrestHint': error.hint,
    };
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
