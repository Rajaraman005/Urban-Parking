import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_controller.dart';
import 'messaging_controller.dart';

class MessagingRealtimeBackoff {
  static const schedule = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  int _attempt = 0;

  Duration next() {
    final index = _attempt.clamp(0, schedule.length - 1);
    _attempt++;
    return schedule[index];
  }

  void reset() {
    _attempt = 0;
  }
}

final messagingInboxLiveSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(_messagingLiveUserIdProvider);
  if (userId == null || !AppConfig.isSupabaseConfigured) return;

  final client = sb.Supabase.instance.client;
  final backoff = MessagingRealtimeBackoff();
  Timer? fallbackPoll;
  Timer? debounce;

  void refreshSoon() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () {
      ref.invalidate(conversationsProvider);
    });
  }

  void scheduleFallback() {
    fallbackPoll?.cancel();
    fallbackPoll = Timer(backoff.next(), () {
      ref.invalidate(conversationsProvider);
      scheduleFallback();
    });
  }

  final channel = client.channel('messaging-inbox:$userId');
  channel
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_participants',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => refreshSoon(),
      )
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
      .subscribe((status, error) {
        switch (status) {
          case sb.RealtimeSubscribeStatus.subscribed:
            backoff.reset();
            fallbackPoll?.cancel();
            appLogger.info('messaging_inbox_realtime_subscribed');
          case sb.RealtimeSubscribeStatus.channelError:
          case sb.RealtimeSubscribeStatus.timedOut:
            appLogger.warn('messaging_inbox_realtime_interrupted', {
              'status': status.name,
              'hasError': error != null,
            });
            scheduleFallback();
          case sb.RealtimeSubscribeStatus.closed:
            appLogger.info('messaging_inbox_realtime_closed');
        }
      });

  ref.onDispose(() {
    debounce?.cancel();
    fallbackPoll?.cancel();
    unawaited(client.removeChannel(channel));
  });
});

final messagingThreadLiveSyncProvider = Provider.family<void, String>((
  ref,
  conversationId,
) {
  final userId = ref.watch(_messagingLiveUserIdProvider);
  if (userId == null || !AppConfig.isSupabaseConfigured) return;

  final client = sb.Supabase.instance.client;
  final backoff = MessagingRealtimeBackoff();
  Timer? fallbackPoll;
  Timer? debounce;

  void refreshSoon() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 180), () {
      ref.invalidate(messagesProvider(conversationId));
      ref.invalidate(conversationsProvider);
    });
  }

  void scheduleFallback() {
    fallbackPoll?.cancel();
    fallbackPoll = Timer(backoff.next(), () {
      ref.invalidate(messagesProvider(conversationId));
      ref.invalidate(conversationsProvider);
      scheduleFallback();
    });
  }

  final channel = client.channel('messaging-thread:$conversationId:$userId');
  channel
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (_) => refreshSoon(),
      )
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_reads',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (_) => refreshSoon(),
      )
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_attachments',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (_) => refreshSoon(),
      )
      .subscribe((status, error) {
        switch (status) {
          case sb.RealtimeSubscribeStatus.subscribed:
            backoff.reset();
            fallbackPoll?.cancel();
            appLogger.info('messaging_thread_realtime_subscribed', {
              'conversationId': conversationId,
            });
          case sb.RealtimeSubscribeStatus.channelError:
          case sb.RealtimeSubscribeStatus.timedOut:
            appLogger.warn('messaging_thread_realtime_interrupted', {
              'conversationId': conversationId,
              'status': status.name,
              'hasError': error != null,
            });
            scheduleFallback();
          case sb.RealtimeSubscribeStatus.closed:
            appLogger.info('messaging_thread_realtime_closed', {
              'conversationId': conversationId,
            });
        }
      });

  ref.onDispose(() {
    debounce?.cancel();
    fallbackPoll?.cancel();
    unawaited(client.removeChannel(channel));
  });
});

final _messagingLiveUserIdProvider = Provider<String?>((ref) {
  return ref.watch(
    authControllerProvider.select((auth) {
      final value = auth.value;
      if (value == null || !value.isAuthenticated) return null;
      return value.user?.id;
    }),
  );
});
