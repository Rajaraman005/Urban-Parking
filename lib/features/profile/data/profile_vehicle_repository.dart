import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/profile_vehicle.dart';

final profileVehicleRepositoryProvider = Provider<ProfileVehicleRepository>((
  ref,
) {
  return ProfileVehicleRepository();
});

final profileVehiclesProvider = FutureProvider<List<ProfileVehicle>>((ref) {
  final auth = ref.watch(authControllerProvider).value;
  final profile = auth?.profile;
  final fallback = profileVehiclesFromProfile(profile);
  final userId = auth?.user?.id ?? profile?.id;

  return ref
      .read(profileVehicleRepositoryProvider)
      .loadVehicles(fallback: fallback, userId: userId);
});

class ProfileVehicleRepository {
  static const _vehicleSelect =
      'id,user_id,vehicle_type,vehicle_registration,vehicle_make,vehicle_model,is_primary,created_at,updated_at';

  Future<List<ProfileVehicle>> loadVehicles({
    required List<ProfileVehicle> fallback,
    required String? userId,
  }) async {
    if (userId == null || userId.trim().isEmpty) return fallback;
    if (!AppConfig.isSupabaseConfigured) return fallback;

    final sb.SupabaseClient client;
    try {
      client = sb.Supabase.instance.client;
    } catch (_) {
      return fallback;
    }

    if (client.auth.currentUser == null) return fallback;

    try {
      final response = await client
          .from('profile_vehicles')
          .select(_vehicleSelect)
          .eq('user_id', userId)
          .order('is_primary', ascending: false)
          .order('created_at');
      final vehicles = (response as List)
          .whereType<Map>()
          .map((row) => ProfileVehicle.fromJson(Map<String, Object?>.from(row)))
          .where((vehicle) => vehicle.registration.trim().isNotEmpty)
          .toList(growable: false);
      return vehicles.isEmpty ? fallback : vehicles;
    } on sb.PostgrestException catch (error) {
      if (_isProfileVehiclesSchemaUnavailable(error)) {
        appLogger.warn('profile_vehicles_schema_missing', {
          'code': error.code,
          'hasFallback': fallback.isNotEmpty,
        });
        return fallback;
      }
      rethrow;
    } catch (error) {
      appLogger.warn('profile_vehicles_load_failed', {
        'errorType': error.runtimeType.toString(),
        'hasFallback': fallback.isNotEmpty,
      });
      return fallback;
    }
  }

  Future<ProfileVehicle> setPrimaryVehicle(ProfileVehicle vehicle) async {
    if (_isLegacyVehicle(vehicle)) return vehicle;

    final client = _readyClient();
    final userId = _currentUserId(client);

    try {
      await client
          .from('profile_vehicles')
          .update({'is_primary': false})
          .eq('user_id', userId);
      final response = await client
          .from('profile_vehicles')
          .update({'is_primary': true})
          .eq('id', vehicle.id)
          .eq('user_id', userId)
          .select(_vehicleSelect)
          .single();
      final primary = ProfileVehicle.fromJson(
        Map<String, Object?>.from(response as Map),
      );
      await _syncProfilePrimary(
        client: client,
        userId: userId,
        vehicle: primary,
      );
      return primary;
    } on sb.PostgrestException catch (error) {
      throw _profileVehicleFailure(
        error,
        fallbackMessage: 'Could not set primary vehicle. Please try again.',
      );
    }
  }

  Future<ProfileVehicle?> deleteVehicle(ProfileVehicle vehicle) async {
    final client = _readyClient();
    final userId = _currentUserId(client);

    if (_isLegacyVehicle(vehicle)) {
      await _syncProfilePrimary(client: client, userId: userId, vehicle: null);
      return null;
    }

    try {
      final deletedResponse = await client
          .from('profile_vehicles')
          .delete()
          .eq('id', vehicle.id)
          .eq('user_id', userId)
          .select(_vehicleSelect)
          .maybeSingle();
      if (deletedResponse == null) {
        throw const ValidationFailure(
          'Vehicle was already removed.',
          code: 'vehicle_not_found',
        );
      }

      final deleted = ProfileVehicle.fromJson(
        Map<String, Object?>.from(deletedResponse as Map),
      );
      if (!deleted.isPrimary) return null;

      final remainingResponse = await client
          .from('profile_vehicles')
          .select(_vehicleSelect)
          .eq('user_id', userId)
          .order('created_at')
          .limit(1);
      final remaining = (remainingResponse as List).whereType<Map>().toList();
      if (remaining.isEmpty) {
        await _syncProfilePrimary(
          client: client,
          userId: userId,
          vehicle: null,
        );
        return null;
      }

      final nextVehicle = ProfileVehicle.fromJson(
        Map<String, Object?>.from(remaining.first),
      );
      return setPrimaryVehicle(nextVehicle);
    } on sb.PostgrestException catch (error) {
      throw _profileVehicleFailure(
        error,
        fallbackMessage: 'Could not delete vehicle. Please try again.',
      );
    }
  }

  sb.SupabaseClient _readyClient() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const ConfigurationFailure(
        'Vehicle storage is not configured for this build.',
        code: 'profile_vehicle_storage_not_configured',
      );
    }

    final sb.SupabaseClient client;
    try {
      client = sb.Supabase.instance.client;
    } catch (_) {
      throw const ConfigurationFailure(
        'Vehicle storage is not initialized for this build.',
        code: 'profile_vehicle_storage_not_initialized',
      );
    }

    if (client.auth.currentUser == null) {
      throw const AuthFailure('Session expired.', code: 'session_expired');
    }
    return client;
  }

  String _currentUserId(sb.SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw const AuthFailure('Session expired.', code: 'session_expired');
    }
    return userId;
  }

  Future<void> _syncProfilePrimary({
    required sb.SupabaseClient client,
    required String userId,
    required ProfileVehicle? vehicle,
  }) async {
    await client
        .from('profiles')
        .update({
          'vehicle_type': vehicle?.type,
          'vehicle_registration': vehicle?.registration,
          'vehicle_make': vehicle?.make,
          'vehicle_model': vehicle?.model,
        })
        .eq('id', userId);
  }

  AppFailure _profileVehicleFailure(
    sb.PostgrestException error, {
    required String fallbackMessage,
  }) {
    if (_isProfileVehiclesSchemaUnavailable(error)) {
      return const ConfigurationFailure(
        'Vehicle list storage is not deployed yet. Apply the latest profile migration.',
        code: 'profile_vehicles_schema_missing',
      );
    }
    return NetworkFailure(fallbackMessage, code: error.code);
  }

  bool _isLegacyVehicle(ProfileVehicle vehicle) {
    return vehicle.id.startsWith('legacy-');
  }

  bool _isProfileVehiclesSchemaUnavailable(sb.PostgrestException error) {
    final text = [
      error.code,
      error.message,
      error.details,
      error.hint,
    ].whereType<String>().join(' ').toLowerCase();
    return text.contains('profile_vehicles') &&
        (text.contains('does not exist') ||
            text.contains('schema cache') ||
            text.contains('42p01') ||
            text.contains('pgrst205'));
  }
}
