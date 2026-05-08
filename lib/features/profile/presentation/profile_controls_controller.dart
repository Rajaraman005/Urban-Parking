import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/home_nearby_controller.dart';
import '../../parking/presentation/geo_discovery_controller.dart';
import '../../parking/presentation/parking_listing_store.dart';
import '../domain/profile_repository.dart';
import 'profile_details_controller.dart';

final profileControlsControllerProvider =
    AsyncNotifierProvider<ProfileControlsController, void>(
      ProfileControlsController.new,
    );

class ProfileControlsController extends AsyncNotifier<void> {
  late final ProfileRepository _repository;

  @override
  void build() {
    _repository = ref.watch(profileRepositoryProvider);
  }

  Future<UserProfile> updateControls({
    required BookingApprovalMode bookingApprovalMode,
    required bool showPhoneNumber,
  }) async {
    final auth = ref.read(authControllerProvider).value;
    final current = auth?.profile;
    if (current == null) {
      throw const AuthFailure('Session expired.', code: 'session_expired');
    }

    final optimistic = current.copyWith(
      bookingApprovalMode: bookingApprovalMode,
      showPhoneNumber: showPhoneNumber,
      version: current.version + 1,
    );

    ref.read(authControllerProvider.notifier).replaceProfile(optimistic);
    state = const AsyncLoading();

    try {
      final profile = await _repository.updateBookingControls(
        ProfileBookingControlsUpdate(
          bookingApprovalMode: bookingApprovalMode,
          expectedVersion: current.version,
          showPhoneNumber: showPhoneNumber,
        ),
      );
      ref.read(authControllerProvider.notifier).replaceProfile(profile);
      _invalidatePublicListingCaches();
      state = const AsyncData(null);
      return profile;
    } catch (error, stackTrace) {
      ref.read(authControllerProvider.notifier).replaceProfile(current);
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _invalidatePublicListingCaches() {
    ref.read(parkingSpotCacheProvider).clear();
    unawaited(ref.read(geoDiscoveryCacheProvider).clear());
    ref.invalidate(homeNearbyControllerProvider);
    ref.invalidate(geoDiscoveryControllerProvider);
    ref.invalidate(parkingListingStoreProvider);
  }
}
