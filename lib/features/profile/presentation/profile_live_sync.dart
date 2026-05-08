import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../parking/presentation/owner_parking_controller.dart';
import '../../user_setup/presentation/host_setup_launch_controller.dart';
import '../../user_setup/presentation/user_setup_controller.dart';

final profileLiveSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(_profileLiveUserIdProvider);
  if (userId == null || !AppConfig.isSupabaseConfigured) {
    return;
  }

  final client = sb.Supabase.instance.client;
  final channel = client
      .channel('profile-live-sync:$userId')
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (payload) {
          if (payload.eventType == sb.PostgresChangeEvent.delete) {
            unawaited(
              ref
                  .read(authControllerProvider.notifier)
                  .refreshSessionOrLogout(),
            );
            return;
          }
          final profile = userProfileFromRealtimeRecord(payload.newRecord);
          if (profile == null) {
            return;
          }
          final previousProfile = ref
              .read(authControllerProvider)
              .value
              ?.profile;
          ref.read(authControllerProvider.notifier).replaceProfile(profile);
          final hostDraftChanged =
              previousProfile?.hostParkingDraftId !=
                  profile.hostParkingDraftId ||
              previousProfile?.setupDraftId != profile.setupDraftId ||
              previousProfile?.setupStep != profile.setupStep;
          if (!hostDraftChanged) return;

          for (final oldDraftId in {
            previousProfile?.hostParkingDraftId,
            previousProfile?.setupDraftId,
          }) {
            if (oldDraftId == null ||
                oldDraftId == profile.hostParkingDraftId ||
                oldDraftId == profile.setupDraftId) {
              continue;
            }
            ref
                .read(hostSetupLaunchControllerProvider.notifier)
                .clearCachedResumeCandidate(draftId: oldDraftId);
          }
          ref.invalidate(userSetupControllerProvider);
          ref.invalidate(ownedParkingSpacesProvider);
        },
      )
      .subscribe((status, error) {
        switch (status) {
          case sb.RealtimeSubscribeStatus.subscribed:
            appLogger.info('profile_live_sync_subscribed');
          case sb.RealtimeSubscribeStatus.channelError:
          case sb.RealtimeSubscribeStatus.timedOut:
            appLogger.warn('profile_live_sync_interrupted', {
              'status': status.name,
              'hasError': error != null,
            });
          case sb.RealtimeSubscribeStatus.closed:
            appLogger.info('profile_live_sync_closed');
        }
      });

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final _profileLiveUserIdProvider = Provider<String?>((ref) {
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

@visibleForTesting
UserProfile? userProfileFromRealtimeRecord(Map<String, dynamic> record) {
  final id = record['id']?.toString().trim();
  if (id == null || id.isEmpty) {
    return null;
  }
  return UserProfile.fromJson(Map<String, Object?>.from(record));
}
