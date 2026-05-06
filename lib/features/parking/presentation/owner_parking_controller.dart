import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../home/presentation/home_nearby_controller.dart';
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
    state = const AsyncLoading();
    final previous = ref.read(parkingListingSnapshotProvider(spotId));
    final current =
        previous?.spot ??
        await ref.read(parkingListingStoreProvider.notifier).load(spotId);
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
      slotsAvailable: update.slotsCount,
      updatedAt: DateTime.now(),
      version: current.version + 1,
    );

    ref.read(parkingListingStoreProvider.notifier).applyOptimistic(optimistic);
    try {
      final spot = await _repository.updateListingPricing(
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
}
