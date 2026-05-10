import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/realtime/notification_realtime_transport.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_controller.dart';
import 'notification_controller.dart';

final notificationLiveSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(_notificationLiveUserIdProvider);
  if (userId == null || !AppConfig.isSupabaseConfigured) return;

  final client = sb.Supabase.instance.client;
  final backoff = NotificationRealtimeBackoff();
  Timer? fallbackPoll;
  Timer? debounce;

  void refreshSoon() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 220), () {
      ref.invalidate(notificationsProvider);
    });
  }

  void scheduleFallback() {
    fallbackPoll?.cancel();
    fallbackPoll = Timer(backoff.next(), () {
      ref.invalidate(notificationsProvider);
      scheduleFallback();
    });
  }

  final channel = client.channel('notifications:$userId');
  channel
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: userId,
        ),
        callback: (_) => refreshSoon(),
      )
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'notification_unread_counters',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => refreshSoon(),
      )
      .subscribe((status, error) {
        switch (status) {
          case sb.RealtimeSubscribeStatus.subscribed:
            backoff.reset();
            fallbackPoll?.cancel();
            appLogger.info('notification_realtime_subscribed');
          case sb.RealtimeSubscribeStatus.channelError:
          case sb.RealtimeSubscribeStatus.timedOut:
            appLogger.warn('notification_realtime_interrupted', {
              'hasError': error != null,
              'status': status.name,
            });
            scheduleFallback();
          case sb.RealtimeSubscribeStatus.closed:
            appLogger.info('notification_realtime_closed');
        }
      });

  ref.onDispose(() {
    debounce?.cancel();
    fallbackPoll?.cancel();
    unawaited(client.removeChannel(channel));
  });
});

final _notificationLiveUserIdProvider = Provider<String?>((ref) {
  return ref.watch(
    authControllerProvider.select((auth) {
      final value = auth.value;
      if (value == null || !value.isAuthenticated) return null;
      return value.user?.id;
    }),
  );
});
