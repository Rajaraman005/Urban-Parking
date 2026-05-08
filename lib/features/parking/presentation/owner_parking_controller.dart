import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/home_nearby_controller.dart';
import '../../user_setup/presentation/host_setup_launch_controller.dart';
import '../../user_setup/presentation/user_setup_controller.dart';
import '../data/owner_parking_repository_impl.dart';
import '../domain/owner_parking_repository.dart';
import '../domain/parking_spot.dart';
import 'geo_discovery_controller.dart';
import 'parking_listing_store.dart';

final ownerParkingRepositoryProvider = Provider<OwnerParkingRepository>((ref) {
  return OwnerParkingRepositoryImpl();
});

final ownedParkingSpacesProvider = FutureProvider<List<ParkingSpot>>((
  ref,
) async {
  final spaces = await ref
      .read(ownerParkingRepositoryProvider)
      .listOwnedSpaces();
  final store = ref.read(parkingListingStoreProvider.notifier);
  for (final space in spaces) {
    store.seed(space);
  }
  return spaces;
});

final ownerListingEditorControllerProvider =
    AsyncNotifierProvider<OwnerListingEditorController, void>(
      OwnerListingEditorController.new,
    );

class OwnerListingEditorController extends AsyncNotifier<void> {
  late final OwnerParkingRepository _repository;

  @override
  void build() {
    _repository = ref.watch(ownerParkingRepositoryProvider);
  }

  Future<List<ParkingAddressCandidate>> searchAddress(String query) {
    return _repository.searchAddress(query);
  }

  Future<void> deleteListing(String spotId) async {
    state = const AsyncLoading();
    final previous = ref.read(parkingListingSnapshotProvider(spotId));
    ref.read(parkingListingStoreProvider.notifier).markDeleted(spotId);
    ref
        .read(hostSetupLaunchControllerProvider.notifier)
        .clearCachedResumeCandidate(draftId: spotId);
    ref
        .read(authControllerProvider.notifier)
        .clearHostDraftReference(draftId: spotId);
    try {
      await _repository.deleteListing(spotId);
      state = const AsyncData(null);
      ref.invalidate(ownedParkingSpacesProvider);
      ref.invalidate(userSetupControllerProvider);
      unawaited(_refreshAuthAfterListingDelete());
      unawaited(ref.read(geoDiscoveryCacheProvider).clear());
      ref.invalidate(homeNearbyControllerProvider);
      ref.invalidate(geoDiscoveryControllerProvider);
    } catch (error, stackTrace) {
      ref.read(parkingListingStoreProvider.notifier).restore(spotId, previous);
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ParkingSpot> updateAddress({
    required String spotId,
    required OwnedListingAddressUpdate update,
  }) async {
    state = const AsyncLoading();
    final previous = ref.read(parkingListingSnapshotProvider(spotId));
    final current =
        previous?.spot ??
        await ref.read(parkingListingStoreProvider.notifier).load(spotId);
    final optimistic = current.copyWith(
      address: update.address.trim(),
      addressConfidence: update.confidence,
      addressPlaceId: update.placeId,
      addressProvider: update.provider,
      city: update.city.trim(),
      listingRevision: current.listingRevision + 1,
      locality: update.locality.trim(),
      location: GeoPoint(
        latitude: update.latitude,
        longitude: update.longitude,
      ),
      postalCode: update.postalCode.trim(),
      updatedAt: DateTime.now(),
      version: current.version + 1,
    );

    ref.read(parkingListingStoreProvider.notifier).applyOptimistic(optimistic);
    try {
      final spot = await _repository.updateListingAddress(
        spotId: spotId,
        update: update,
      );
      _acceptCanonicalSpot(spot);
      state = const AsyncData(null);
      return spot;
    } catch (error, stackTrace) {
      ref.read(parkingListingStoreProvider.notifier).restore(spotId, previous);
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ParkingSpot> updatePricing({
    required String spotId,
    required OwnedListingPricingUpdate update,
  }) async {
    appLogger.info('owner_pricing_controller_update_started', {
      ..._pricingControllerLogPayload(spotId: spotId, update: update),
    });
    state = const AsyncLoading();
    final previous = ref.read(parkingListingSnapshotProvider(spotId));
    final current =
        previous?.spot ??
        await ref.read(parkingListingStoreProvider.notifier).load(spotId);
    appLogger.info('owner_pricing_controller_snapshot_loaded', {
      'spotId': spotId,
      'currentVersion': current.version,
      'currentRevision': current.listingRevision,
      'hadPreviousSnapshot': previous != null,
    });
    final optimistic = current.copyWith(
      availableFrom: _dateAtMinute(
        update.availableFromDate,
        update.dailyStartMinute,
      ),
      availableFromDate: DateTime(
        update.availableFromDate.year,
        update.availableFromDate.month,
        update.availableFromDate.day,
      ),
      availableToDate: DateTime(
        update.availableToDate.year,
        update.availableToDate.month,
        update.availableToDate.day,
      ),
      availableUntil: _dateAtMinute(
        update.availableToDate,
        update.dailyEndMinute,
      ),
      dailyEndMinute: update.dailyEndMinute,
      dailyStartMinute: update.dailyStartMinute,
      listingRevision: current.listingRevision + 1,
      price: update.hourlyPrice,
      skipWeekends: update.skipWeekends,
      slotsAvailable: update.slotsCount,
      updatedAt: DateTime.now(),
      version: current.version + 1,
    );

    ref.read(parkingListingStoreProvider.notifier).applyOptimistic(optimistic);
    appLogger.info('owner_pricing_controller_optimistic_applied', {
      'spotId': spotId,
      'optimisticVersion': optimistic.version,
      'optimisticRevision': optimistic.listingRevision,
    });
    try {
      final spot = await _repository.updateListingPricing(
        spotId: spotId,
        update: update,
      );
      _acceptCanonicalSpot(spot);
      state = const AsyncData(null);
      appLogger.info('owner_pricing_controller_update_succeeded', {
        'spotId': spotId,
        'canonicalVersion': spot.version,
        'canonicalRevision': spot.listingRevision,
      });
      return spot;
    } catch (error, stackTrace) {
      if (_isListingVersionConflict(error)) {
        try {
          appLogger.warn('owner_pricing_controller_version_conflict_retrying', {
            ..._pricingControllerLogPayload(spotId: spotId, update: update),
            ..._failureLogPayload(error),
          });
          ref
              .read(parkingListingStoreProvider.notifier)
              .restore(spotId, previous);
          final latest = await ref
              .read(parkingListingStoreProvider.notifier)
              .refresh(spotId);
          appLogger.info('owner_pricing_controller_retry_snapshot_loaded', {
            'spotId': spotId,
            'latestVersion': latest.version,
            'latestRevision': latest.listingRevision,
          });
          final retryUpdate = update.copyWith(expectedVersion: latest.version);
          final retryOptimistic = _pricingOptimisticSpot(latest, retryUpdate);
          ref
              .read(parkingListingStoreProvider.notifier)
              .applyOptimistic(retryOptimistic);
          appLogger.info('owner_pricing_controller_retry_optimistic_applied', {
            'spotId': spotId,
            'optimisticVersion': retryOptimistic.version,
            'optimisticRevision': retryOptimistic.listingRevision,
          });
          final spot = await _repository.updateListingPricing(
            spotId: spotId,
            update: retryUpdate,
          );
          _acceptCanonicalSpot(spot);
          state = const AsyncData(null);
          appLogger.info('owner_pricing_controller_retry_succeeded', {
            'spotId': spotId,
            'canonicalVersion': spot.version,
            'canonicalRevision': spot.listingRevision,
          });
          return spot;
        } catch (retryError, retryStackTrace) {
          appLogger.error('owner_pricing_controller_retry_failed', {
            'spotId': spotId,
            ..._failureLogPayload(retryError),
          }, retryError);
          ref
              .read(parkingListingStoreProvider.notifier)
              .restore(spotId, previous);
          state = AsyncError(retryError, retryStackTrace);
          Error.throwWithStackTrace(retryError, retryStackTrace);
        }
      }
      appLogger.error('owner_pricing_controller_update_failed', {
        'spotId': spotId,
        ..._failureLogPayload(error),
      }, error);
      ref.read(parkingListingStoreProvider.notifier).restore(spotId, previous);
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _acceptCanonicalSpot(ParkingSpot spot) {
    ref.read(parkingListingStoreProvider.notifier).seed(spot);
    ref.invalidate(ownedParkingSpacesProvider);
    unawaited(ref.read(geoDiscoveryCacheProvider).clear());
    ref.invalidate(homeNearbyControllerProvider);
    ref.invalidate(geoDiscoveryControllerProvider);
  }

  DateTime _dateAtMinute(DateTime date, int minuteOfDay) {
    final safeMinute = minuteOfDay.clamp(0, 24 * 60);
    final displayMinute = safeMinute >= 24 * 60 ? (24 * 60) - 1 : safeMinute;
    return DateTime(
      date.year,
      date.month,
      date.day,
      displayMinute ~/ 60,
      displayMinute % 60,
    );
  }

  ParkingSpot _pricingOptimisticSpot(
    ParkingSpot current,
    OwnedListingPricingUpdate update,
  ) {
    return current.copyWith(
      availableFrom: _dateAtMinute(
        update.availableFromDate,
        update.dailyStartMinute,
      ),
      availableFromDate: DateTime(
        update.availableFromDate.year,
        update.availableFromDate.month,
        update.availableFromDate.day,
      ),
      availableToDate: DateTime(
        update.availableToDate.year,
        update.availableToDate.month,
        update.availableToDate.day,
      ),
      availableUntil: _dateAtMinute(
        update.availableToDate,
        update.dailyEndMinute,
      ),
      dailyEndMinute: update.dailyEndMinute,
      dailyStartMinute: update.dailyStartMinute,
      listingRevision: current.listingRevision + 1,
      price: update.hourlyPrice,
      skipWeekends: update.skipWeekends,
      slotsAvailable: update.slotsCount,
      updatedAt: DateTime.now(),
      version: current.version + 1,
    );
  }

  bool _isListingVersionConflict(Object error) {
    return error is AppFailure && error.code == 'listing_version_conflict';
  }

  Future<void> _refreshAuthAfterListingDelete() async {
    try {
      await ref.read(authControllerProvider.notifier).refreshSessionOrLogout();
    } catch (error) {
      appLogger.warn('owner_listing_delete_auth_refresh_failed', {
        ..._failureLogPayload(error),
      });
    }
  }
}

Map<String, Object?> _pricingControllerLogPayload({
  required String spotId,
  required OwnedListingPricingUpdate update,
}) {
  return {
    'spotId': spotId,
    'expectedVersion': update.expectedVersion,
    'hourlyPrice': update.hourlyPrice,
    'slotsCount': update.slotsCount,
    'availableFromDate': _logDateOnly(update.availableFromDate),
    'availableToDate': _logDateOnly(update.availableToDate),
    'dailyStartMinute': update.dailyStartMinute,
    'dailyEndMinute': update.dailyEndMinute,
    'skipWeekends': update.skipWeekends,
  };
}

Map<String, Object?> _failureLogPayload(Object error) {
  if (error is AppFailure) {
    return {
      'failureCode': error.code,
      'failureMessage': error.message,
      'failureType': error.runtimeType.toString(),
    };
  }
  return {
    'failureCode': null,
    'failureMessage': error.toString(),
    'failureType': error.runtimeType.toString(),
  };
}

String _logDateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
