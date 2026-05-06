import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../config/app_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/home_nearby_controller.dart';

final ownedParkingLiveSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(_ownedParkingLiveUserIdProvider);
  if (userId == null || !AppConfig.isSupabaseConfigured) {
    return;
  }

  final client = sb.Supabase.instance.client;
  Timer? debounce;

  void queueNearbyRefresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(ref.read(geoDiscoveryCacheProvider).clear());
      ref.invalidate(homeNearbyControllerProvider);
    });
  }

  final channel = client
      .channel('owned-parking-live:$userId')
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'parking_listing_revisions',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'host_id',
          value: userId,
        ),
        callback: (_) => queueNearbyRefresh(),
      )
      .subscribe((status, error) {
        switch (status) {
          case sb.RealtimeSubscribeStatus.subscribed:
            appLogger.info('owned_parking_live_subscribed');
          case sb.RealtimeSubscribeStatus.channelError:
          case sb.RealtimeSubscribeStatus.timedOut:
            appLogger.warn('owned_parking_live_interrupted', {
              'status': status.name,
              'hasError': error != null,
            });
          case sb.RealtimeSubscribeStatus.closed:
            appLogger.info('owned_parking_live_closed');
        }
      });

  ref.onDispose(() {
    debounce?.cancel();
    unawaited(client.removeChannel(channel));
  });
});

final _ownedParkingLiveUserIdProvider = Provider<String?>((ref) {
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
