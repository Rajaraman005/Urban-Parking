import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_models.dart';
import '../domain/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<NotificationFeedPage> listNotifications({
    NotificationCategory? category,
    String? cursor,
    int limit = 30,
    NotificationStatus? status,
  }) async {
    try {
      final query = <String, Object?>{
        'category': category?.apiValue,
        'cursor': cursor,
        'limit': limit,
        'status': status?.name,
      }..removeWhere((_, value) => value == null);
      final response = await _apiClient.dio.get<Map<String, Object?>>(
        '/notifications',
        queryParameters: query,
      );
      return NotificationFeedPage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure(
        'Could not load notifications. Please try again.',
        code: 'notification_list_failed',
      );
    }
  }

  @override
  Future<List<AppNotification>> syncNotifications({
    String? afterCursor,
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, Object?>>(
        '/notifications/sync',
        queryParameters: {'afterCursor': afterCursor, 'limit': limit}
          ..removeWhere((_, value) => value == null),
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items.map(AppNotification.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } catch (_) {
      throw const NetworkFailure(
        'Could not sync notifications.',
        code: 'notification_sync_failed',
      );
    }
  }

  @override
  Future<void> markRead({
    String? notificationId,
    NotificationCategory? category,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, Object?>>(
        '/notifications/read',
        data: {'category': category?.apiValue, 'notificationId': notificationId}
          ..removeWhere((_, value) => value == null),
      );
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } catch (_) {
      throw const NetworkFailure(
        'Could not update notification state.',
        code: 'notification_read_failed',
      );
    }
  }

  @override
  Future<List<NotificationPreference>> listPreferences() async {
    try {
      final response = await _apiClient.dio.get<Map<String, Object?>>(
        '/notification-preferences',
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items.map(NotificationPreference.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } catch (_) {
      throw const NetworkFailure(
        'Could not load notification preferences.',
        code: 'notification_preferences_failed',
      );
    }
  }

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreferenceUpdate update,
  ) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, Object?>>(
        '/notification-preferences',
        data: update.toJson(),
      );
      return NotificationPreference.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } catch (_) {
      throw const NetworkFailure(
        'Could not save notification preferences.',
        code: 'notification_preferences_update_failed',
      );
    }
  }

  @override
  Future<void> registerDevice(
    NotificationDeviceRegistration registration,
  ) async {
    try {
      await _apiClient.dio.post<Map<String, Object?>>(
        '/notification-devices',
        data: registration.toJson(),
      );
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } catch (_) {
      throw const NetworkFailure(
        'Could not register this device for notifications.',
        code: 'notification_device_register_failed',
      );
    }
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    try {
      await _apiClient.dio.delete<Map<String, Object?>>(
        '/notification-devices/$deviceId',
      );
    } on DioException catch (error) {
      throw ApiClient.toFailure(error);
    } catch (_) {
      throw const NetworkFailure(
        'Could not remove this notification device.',
        code: 'notification_device_delete_failed',
      );
    }
  }
}
