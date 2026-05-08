import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../config/app_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/parking_repository.dart';
import '../domain/parking_spot.dart';

class ParkingListingRevision {
  const ParkingListingRevision({
    required this.listingRevision,
    required this.spaceId,
    this.updatedAt,
  });

  final int listingRevision;
  final String spaceId;
  final DateTime? updatedAt;
}

class ParkingListingSnapshot {
  const ParkingListingSnapshot({
    this.error,
    this.isDeleted = false,
    this.isOptimistic = false,
    this.isRefreshing = false,
    this.lastResolvedAt,
    this.spot,
  });

  final Object? error;
  final bool isDeleted;
  final bool isOptimistic;
  final bool isRefreshing;
  final DateTime? lastResolvedAt;
  final ParkingSpot? spot;

  ParkingListingSnapshot copyWith({
    Object? error,
    bool clearError = false,
    bool? isDeleted,
    bool? isOptimistic,
    bool? isRefreshing,
    DateTime? lastResolvedAt,
    ParkingSpot? spot,
  }) {
    return ParkingListingSnapshot(
      error: clearError ? null : error ?? this.error,
      isDeleted: isDeleted ?? this.isDeleted,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastResolvedAt: lastResolvedAt ?? this.lastResolvedAt,
      spot: spot ?? this.spot,
    );
  }
}

final parkingListingStoreProvider =
    NotifierProvider<ParkingListingStore, Map<String, ParkingListingSnapshot>>(
      ParkingListingStore.new,
    );

final parkingListingSnapshotProvider =
    Provider.family<ParkingListingSnapshot?, String>((ref, spotId) {
      return ref.watch(
        parkingListingStoreProvider.select((state) => state[spotId]),
      );
    });

final liveParkingSpotProvider = FutureProvider.family<ParkingSpot, String>((
  ref,
  spotId,
) async {
  final snapshot = ref.watch(parkingListingSnapshotProvider(spotId));
  final spot = snapshot?.spot;
  if (snapshot?.isDeleted == true) {
    throw StateError('Listing was deleted.');
  }
  if (spot != null) {
    return spot;
  }
  final loaded = await ref.watch(parkingRepositoryProvider).getById(spotId);
  scheduleMicrotask(() {
    try {
      ref.read(parkingListingStoreProvider.notifier).seed(loaded);
    } catch (_) {
      // The provider may have been disposed before the microtask runs.
    }
  });
  return loaded;
});

class ParkingListingStore
    extends Notifier<Map<String, ParkingListingSnapshot>> {
  final _inFlight = <String, Future<ParkingSpot>>{};

  @override
  Map<String, ParkingListingSnapshot> build() {
    ref.onDispose(_inFlight.clear);
    return const {};
  }

  ParkingSpot? spotFor(String spotId) => state[spotId]?.spot;

  void seed(ParkingSpot spot) {
    if (state[spot.id]?.isDeleted == true) {
      return;
    }
    final existing = state[spot.id]?.spot;
    if (existing != null && !_isNewer(spot, existing)) {
      return;
    }
    _setSnapshot(
      spot.id,
      ParkingListingSnapshot(spot: spot, lastResolvedAt: DateTime.now()),
    );
  }

  Future<ParkingSpot> load(
    String spotId, {
    ParkingSpotFetchPolicy fetchPolicy = ParkingSpotFetchPolicy.cacheFirst,
  }) {
    final active = _inFlight[spotId];
    if (active != null) return active;

    final current = state[spotId];
    _setSnapshot(
      spotId,
      (current ?? const ParkingListingSnapshot()).copyWith(
        clearError: true,
        isRefreshing: true,
      ),
    );

    final future = ref
        .read(parkingRepositoryProvider)
        .getById(spotId, fetchPolicy: fetchPolicy)
        .then((spot) {
          seed(spot);
          return spot;
        })
        .catchError((Object error) {
          final latest = state[spotId] ?? const ParkingListingSnapshot();
          _setSnapshot(
            spotId,
            latest.copyWith(error: error, isRefreshing: false),
          );
          throw error;
        })
        .whenComplete(() {
          _inFlight.remove(spotId);
          final latest = state[spotId];
          if (latest != null) {
            _setSnapshot(spotId, latest.copyWith(isRefreshing: false));
          }
        });

    _inFlight[spotId] = future;
    return future;
  }

  Future<ParkingSpot> refresh(String spotId) {
    return load(spotId, fetchPolicy: ParkingSpotFetchPolicy.networkOnly);
  }

  void applyOptimistic(ParkingSpot spot) {
    _setSnapshot(
      spot.id,
      ParkingListingSnapshot(
        isOptimistic: true,
        isRefreshing: true,
        lastResolvedAt: DateTime.now(),
        spot: spot,
      ),
    );
  }

  void restore(String spotId, ParkingListingSnapshot? snapshot) {
    final next = {...state};
    if (snapshot == null) {
      next.remove(spotId);
    } else {
      next[spotId] = snapshot;
    }
    state = next;
  }

  void markDeleted(String spotId) {
    _setSnapshot(
      spotId,
      ParkingListingSnapshot(isDeleted: true, lastResolvedAt: DateTime.now()),
    );
  }

  void _setSnapshot(String spotId, ParkingListingSnapshot snapshot) {
    state = {...state, spotId: snapshot};
  }

  bool _isNewer(ParkingSpot candidate, ParkingSpot current) {
    if (candidate.listingRevision != current.listingRevision) {
      return candidate.listingRevision > current.listingRevision;
    }
    if (candidate.version != current.version) {
      return candidate.version > current.version;
    }
    final candidateUpdatedAt = candidate.updatedAt;
    final currentUpdatedAt = current.updatedAt;
    if (candidateUpdatedAt != null && currentUpdatedAt != null) {
      return candidateUpdatedAt.isAfter(currentUpdatedAt) ||
          candidateUpdatedAt.isAtSameMomentAs(currentUpdatedAt);
    }
    return true;
  }
}

final parkingListingRevisionSyncProvider = Provider.family<void, String>((
  ref,
  spotId,
) {
  if (!AppConfig.isSupabaseConfigured || !_isUuid(spotId)) {
    return;
  }

  final client = sb.Supabase.instance.client;
  Timer? debounce;

  void refreshFromRevision(ParkingListingRevision? revision) {
    final current = ref
        .read(parkingListingStoreProvider.notifier)
        .spotFor(spotId);
    if (revision != null &&
        current != null &&
        revision.listingRevision <= current.listingRevision) {
      return;
    }

    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(ref.read(parkingListingStoreProvider.notifier).refresh(spotId));
    });
  }

  final channel = client
      .channel('parking-listing-revision:$spotId')
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'parking_listing_revisions',
        filter: sb.PostgresChangeFilter(
          type: sb.PostgresChangeFilterType.eq,
          column: 'space_id',
          value: spotId,
        ),
        callback: (payload) {
          if (payload.eventType == sb.PostgresChangeEvent.delete) {
            refreshFromRevision(null);
            return;
          }
          refreshFromRevision(
            parkingListingRevisionFromRealtimeRecord(payload.newRecord),
          );
        },
      )
      .subscribe((status, error) {
        switch (status) {
          case sb.RealtimeSubscribeStatus.subscribed:
            appLogger.info('parking_listing_revision_subscribed', {
              'spotId': spotId,
            });
          case sb.RealtimeSubscribeStatus.channelError:
          case sb.RealtimeSubscribeStatus.timedOut:
            appLogger.warn('parking_listing_revision_interrupted', {
              'spotId': spotId,
              'status': status.name,
              'hasError': error != null,
            });
          case sb.RealtimeSubscribeStatus.closed:
            appLogger.info('parking_listing_revision_closed', {
              'spotId': spotId,
            });
        }
      });

  ref.onDispose(() {
    debounce?.cancel();
    unawaited(client.removeChannel(channel));
  });
});

final visibleParkingListingRevisionsProvider = Provider.family<void, String>((
  ref,
  idsKey,
) {
  if (!AppConfig.isSupabaseConfigured || idsKey.trim().isEmpty) {
    return;
  }

  final ids = idsKey
      .split('|')
      .map((entry) => entry.trim())
      .where(_isUuid)
      .toSet();
  if (ids.isEmpty) return;

  final client = sb.Supabase.instance.client;
  final debouncers = <String, Timer>{};

  void queueRefresh(String spotId, ParkingListingRevision? revision) {
    final current = ref
        .read(parkingListingStoreProvider.notifier)
        .spotFor(spotId);
    if (revision != null &&
        current != null &&
        revision.listingRevision <= current.listingRevision) {
      return;
    }

    debouncers[spotId]?.cancel();
    debouncers[spotId] = Timer(const Duration(milliseconds: 320), () {
      unawaited(ref.read(parkingListingStoreProvider.notifier).refresh(spotId));
    });
  }

  final channel = client
      .channel('visible-parking-listing-revisions:${ids.join(',')}')
      .onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: 'parking_listing_revisions',
        callback: (payload) {
          final record = payload.eventType == sb.PostgresChangeEvent.delete
              ? payload.oldRecord
              : payload.newRecord;
          final spotId = record['space_id']?.toString();
          if (spotId == null || !ids.contains(spotId)) return;
          queueRefresh(
            spotId,
            payload.eventType == sb.PostgresChangeEvent.delete
                ? null
                : parkingListingRevisionFromRealtimeRecord(payload.newRecord),
          );
        },
      )
      .subscribe();

  ref.onDispose(() {
    for (final timer in debouncers.values) {
      timer.cancel();
    }
    unawaited(client.removeChannel(channel));
  });
});

String parkingListingIdsKey(Iterable<String> ids, {int maxIds = 20}) {
  final normalized =
      ids.where(_isUuid).toSet().take(maxIds).toList(growable: false)..sort();
  return normalized.join('|');
}

@visibleForTesting
ParkingListingRevision? parkingListingRevisionFromRealtimeRecord(
  Map<String, dynamic> record,
) {
  final spaceId = record['space_id']?.toString().trim();
  if (spaceId == null || spaceId.isEmpty) {
    return null;
  }

  final revisionRaw = record['listing_revision'];
  final revision = revisionRaw is num
      ? revisionRaw.toInt()
      : int.tryParse(revisionRaw?.toString() ?? '');
  if (revision == null || revision < 1) {
    return null;
  }

  return ParkingListingRevision(
    listingRevision: revision,
    spaceId: spaceId,
    updatedAt: DateTime.tryParse(record['updated_at']?.toString() ?? ''),
  );
}

bool _isUuid(String value) {
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
}
