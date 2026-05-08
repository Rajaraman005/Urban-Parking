import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/booking.dart';
import 'booking_controller.dart';

final bookingLiveSyncProvider = Provider.family<void, BookingListRole>((
  ref,
  role,
) {
  final userId = ref.watch(_bookingLiveUserIdProvider);
  if (userId == null || !AppConfig.isSupabaseConfigured) {
    return;
  }

  Timer? debounce;
  final client = sb.Supabase.instance.client;
  final column = role == BookingListRole.host ? 'host_id' : 'renter_id';
  final channel = client
      .channel('booking-live-sync:${role.name}:$userId')
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'bookings',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: column,
          value: userId,
        ),
        callback: (_) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 250), () {
            ref.invalidate(
              role == BookingListRole.host
                  ? hostBookingsProvider
                  : renterBookingsProvider,
            );
          });
        },
      )
      .subscribe((status, error) {
        switch (status) {
          case sb.RealtimeSubscribeStatus.subscribed:
            appLogger.info('booking_live_sync_subscribed', {'role': role.name});
          case sb.RealtimeSubscribeStatus.channelError:
          case sb.RealtimeSubscribeStatus.timedOut:
            appLogger.warn('booking_live_sync_interrupted', {
              'hasError': error != null,
              'role': role.name,
              'status': status.name,
            });
          case sb.RealtimeSubscribeStatus.closed:
            appLogger.info('booking_live_sync_closed', {'role': role.name});
        }
      });

  ref.onDispose(() {
    debounce?.cancel();
    unawaited(client.removeChannel(channel));
  });
});

final _bookingLiveUserIdProvider = Provider<String?>((ref) {
  return ref.watch(
    authControllerProvider.select((auth) {
      final value = auth.value;
      if (value == null || !value.isAuthenticated) {
        return null;
      }
      return value.user?.id;
    }),
  );
});
