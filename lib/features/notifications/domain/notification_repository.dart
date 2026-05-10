import 'notification_models.dart';

abstract interface class NotificationRepository {
  Future<NotificationFeedPage> listNotifications({
    NotificationCategory? category,
    String? cursor,
    int limit = 30,
    NotificationStatus? status,
  });

  Future<List<AppNotification>> syncNotifications({
    String? afterCursor,
    int limit = 100,
  });

  Future<void> markRead({
    String? notificationId,
    NotificationCategory? category,
  });

  Future<List<NotificationPreference>> listPreferences();

  Future<NotificationPreference> updatePreference(
    NotificationPreferenceUpdate update,
  );

  Future<void> registerDevice(NotificationDeviceRegistration registration);

  Future<void> deleteDevice(String deviceId);
}
