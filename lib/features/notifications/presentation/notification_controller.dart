import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../data/notification_repository_impl.dart';
import '../domain/notification_models.dart';
import '../domain/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final notificationsProvider = FutureProvider<NotificationFeedPage>((ref) {
  return ref.watch(notificationRepositoryProvider).listNotifications();
});

final notificationUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(
    notificationsProvider.select((value) => value.value?.totalUnread ?? 0),
  );
});

final notificationPreferencesProvider =
    FutureProvider<List<NotificationPreference>>((ref) {
      return ref.watch(notificationRepositoryProvider).listPreferences();
    });

final notificationReadControllerProvider =
    AsyncNotifierProvider<NotificationReadController, void>(
      NotificationReadController.new,
    );

class NotificationReadController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> markRead(String notificationId) {
    return _mark(notificationId: notificationId);
  }

  Future<void> markCategoryRead(NotificationCategory category) {
    return _mark(category: category);
  }

  Future<void> markAllRead() {
    return _mark();
  }

  Future<void> _mark({
    NotificationCategory? category,
    String? notificationId,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(notificationRepositoryProvider)
          .markRead(category: category, notificationId: notificationId);
      ref.invalidate(notificationsProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final notificationPreferenceControllerProvider =
    AsyncNotifierProvider<NotificationPreferenceController, void>(
      NotificationPreferenceController.new,
    );

class NotificationPreferenceController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<NotificationPreference> save(
    NotificationPreferenceUpdate preferenceUpdate,
  ) async {
    state = const AsyncLoading();
    try {
      final preference = await ref
          .read(notificationRepositoryProvider)
          .updatePreference(preferenceUpdate);
      ref.invalidate(notificationPreferencesProvider);
      state = const AsyncData(null);
      return preference;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final notificationDeviceControllerProvider =
    AsyncNotifierProvider<NotificationDeviceController, void>(
      NotificationDeviceController.new,
    );

class NotificationDeviceController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> register(NotificationDeviceRegistration registration) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(notificationRepositoryProvider)
          .registerDevice(registration);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> delete(String deviceId) async {
    state = const AsyncLoading();
    try {
      await ref.read(notificationRepositoryProvider).deleteDevice(deviceId);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
