import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../config/app_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/home_nearby_controller.dart';
import '../../user_setup/presentation/host_setup_launch_controller.dart';
import '../../user_setup/presentation/user_setup_controller.dart';
import 'owner_parking_controller.dart';

final ownedParkingLiveSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(_ownedParkingLiveUserIdProvider);
  if (userId == null || !AppConfig.isSupabaseConfigured) {
    return;
  }

  final client = sb.Supabase.instance.client;
  Timer? discoveryDebounce;
  Timer? ownedDebounce;

  void queueNearbyRefresh() {
    discoveryDebounce?.cancel();
    discoveryDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(ref.read(geoDiscoveryCacheProvider).clear());
      ref.invalidate(ownedParkingSpacesProvider);
      ref.invalidate(userSetupControllerProvider);
      ref.invalidate(homeNearbyControllerProvider);
    });
  }

  void queueOwnedRefresh() {
    ownedDebounce?.cancel();
    ownedDebounce = Timer(const Duration(milliseconds: 250), () {
      ref
          .read(hostSetupLaunchControllerProvider.notifier)
          .clearCachedResumeCandidate();
      ref.invalidate(ownedParkingSpacesProvider);
      ref.invalidate(userSetupControllerProvider);
    });
  }

  final channel = client.channel('owned-parking-live:$userId');

  channel
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
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'parking_spaces',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'host_id',
          value: userId,
        ),
        callback: (_) => queueOwnedRefresh(),
      )
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'parking_listing_drafts',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'host_id',
          value: userId,
        ),
        callback: (_) => queueOwnedRefresh(),
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
    discoveryDebounce?.cancel();
    ownedDebounce?.cancel();
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
