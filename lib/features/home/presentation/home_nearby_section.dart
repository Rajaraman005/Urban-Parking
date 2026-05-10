import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_providers.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../core/utils/location_service.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/product_card.dart';
import '../../parking/domain/parking_spot.dart';
import '../../parking/presentation/parking_listing_store.dart';
import 'home_nearby_controller.dart';
import 'home_nearby_filtering.dart';

final _homeNearbyFavoriteIdsProvider =
    NotifierProvider<_HomeNearbyFavoriteIdsController, Set<String>>(
      _HomeNearbyFavoriteIdsController.new,
    );

class _HomeNearbyFavoriteIdsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) {
    final next = {...state};
    if (!next.add(id)) {
      next.remove(id);
    }
    state = next;
  }
}

class HomeNearbySection extends ConsumerWidget {
  const HomeNearbySection({
    super.key,
    this.filters = HomeNearbyFilterSelection.defaults,
    this.onClearVehicleFilter,
    this.onResetFilters,
    this.vehicleFilter,
  });

  final HomeNearbyFilterSelection filters;
  final VoidCallback? onClearVehicleFilter;
  final VoidCallback? onResetFilters;
  final HomeNearbyVehicleFilter? vehicleFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<GeoPoint>>(resolvedLocationProvider, (_, next) {
      if (!next.hasValue) return;
      final current = ref.read(homeNearbyControllerProvider).value;
      if (current?.center != null) return;
      unawaited(ref.read(homeNearbyControllerProvider.notifier).refresh());
    });

    final nearby = ref.watch(homeNearbyControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeNearbyHeader(
            subtitle: _subtitleFor(nearby),
            vehicleFilter: vehicleFilter,
            onRefresh: () =>
                ref.read(homeNearbyControllerProvider.notifier).refresh(),
          ),
          const SizedBox(height: 14),
          nearby.when(
            loading: () => const _HomeNearbySkeletonList(),
            error: (error, _) => _HomeNearbyMessageCard(
              icon: Icons.wifi_off_rounded,
              title: 'Unable to load nearby places',
              message: error.toString(),
              actionLabel: 'Retry',
              onAction: () =>
                  ref.read(homeNearbyControllerProvider.notifier).refresh(),
            ),
            data: (state) {
              if (state.center == null) {
                return _HomeNearbyMessageCard(
                  icon: _locationIconFor(state),
                  title: _locationTitleFor(state),
                  message:
                      state.message ??
                      'Enable location access to show spaces near you.',
                  actionLabel: _locationActionLabelFor(state),
                  onAction: () => _handleLocationAction(ref, state),
                );
              }

              if (state.items.isEmpty) {
                return _HomeNearbyMessageCard(
                  icon: Icons.search_off_rounded,
                  title: 'No nearby results yet',
                  message:
                      state.message ??
                      'Try refreshing or changing your discovery filters.',
                  actionLabel: 'Refresh',
                  onAction: () =>
                      ref.read(homeNearbyControllerProvider.notifier).refresh(),
                );
              }

              return _HomeNearbyResults(
                filters: filters,
                onClearVehicleFilter: onClearVehicleFilter,
                onResetFilters: onResetFilters,
                state: state,
                vehicleFilter: vehicleFilter,
              );
            },
          ),
        ],
      ),
    );
  }

  String _subtitleFor(AsyncValue<HomeNearbyViewState> nearby) {
    final state = nearby.value;
    if (nearby.isLoading && state == null) return 'Finding your location';
    if (state?.center == null) return 'Enable location to see nearby spaces';
    return vehicleFilter?.nearbySubtitle ?? 'Live spaces from your location';
  }

  IconData _locationIconFor(HomeNearbyViewState state) {
    return switch (state.locationFailureReason) {
      LocationFailureReason.servicesDisabled => Icons.location_disabled_rounded,
      LocationFailureReason.permissionDenied ||
      LocationFailureReason.permissionDeniedForever =>
        Icons.location_off_rounded,
      LocationFailureReason.timeout => Icons.location_searching_rounded,
      LocationFailureReason.unavailable ||
      LocationFailureReason.none => Icons.my_location_rounded,
    };
  }

  String _locationTitleFor(HomeNearbyViewState state) {
    return switch (state.locationFailureReason) {
      LocationFailureReason.servicesDisabled => 'Turn on device location',
      LocationFailureReason.permissionDenied ||
      LocationFailureReason.permissionDeniedForever =>
        'Location permission needed',
      LocationFailureReason.timeout => 'Location is taking longer than usual',
      LocationFailureReason.unavailable ||
      LocationFailureReason.none => 'Enable location to start',
    };
  }

  String _locationActionLabelFor(HomeNearbyViewState state) {
    return switch (state.locationFailureReason) {
      LocationFailureReason.servicesDisabled => 'Open location settings',
      LocationFailureReason.permissionDeniedForever => 'Open app settings',
      LocationFailureReason.permissionDenied => 'Allow location',
      LocationFailureReason.timeout => 'Open location settings',
      LocationFailureReason.unavailable ||
      LocationFailureReason.none => 'Try again',
    };
  }

  void _handleLocationAction(WidgetRef ref, HomeNearbyViewState state) {
    unawaited(_openSettingsIfNeededAndRefresh(ref, state));
  }

  Future<void> _openSettingsIfNeededAndRefresh(
    WidgetRef ref,
    HomeNearbyViewState state,
  ) async {
    final locationService = ref.read(locationServiceProvider);
    if (state.locationFailureReason == LocationFailureReason.servicesDisabled ||
        state.locationFailureReason == LocationFailureReason.timeout) {
      await locationService.openLocationSettings();
    } else if (state.locationFailureReason ==
        LocationFailureReason.permissionDeniedForever) {
      await locationService.openAppSettings();
    }
    await ref.read(homeNearbyControllerProvider.notifier).refresh();
  }
}

class _HomeNearbyHeader extends StatelessWidget {
  const _HomeNearbyHeader({
    required this.onRefresh,
    required this.subtitle,
    required this.vehicleFilter,
  });

  final VoidCallback onRefresh;
  final String subtitle;
  final HomeNearbyVehicleFilter? vehicleFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nearby for you',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF0B0B0C),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onRefresh,
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.refresh_rounded,
                color: Color(0xFF0B0B0C),
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeNearbyResults extends ConsumerWidget {
  const _HomeNearbyResults({
    required this.filters,
    required this.onResetFilters,
    required this.state,
    required this.vehicleFilter,
    required this.onClearVehicleFilter,
  });

  final HomeNearbyFilterSelection filters;
  final VoidCallback? onClearVehicleFilter;
  final VoidCallback? onResetFilters;
  final HomeNearbyViewState state;
  final HomeNearbyVehicleFilter? vehicleFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(_homeNearbyFavoriteIdsProvider);
    final vehicleItems = filterHomeNearbyItems(state.items, vehicleFilter);
    final filteredItems = applyHomeNearbyFilters(
      state.items,
      filters: filters,
      vehicleFilter: vehicleFilter,
    );

    if (vehicleFilter != null && vehicleItems.isEmpty) {
      return _HomeNearbyMessageCard(
        icon: vehicleFilter == HomeNearbyVehicleFilter.bike
            ? Icons.two_wheeler_rounded
            : Icons.directions_car_rounded,
        title: vehicleFilter!.emptyTitle,
        message: vehicleFilter!.emptyMessage,
        actionLabel: onClearVehicleFilter == null ? 'Refresh' : 'Clear filter',
        onAction:
            onClearVehicleFilter ??
            () => ref.read(homeNearbyControllerProvider.notifier).refresh(),
      );
    }

    if (filteredItems.isEmpty) {
      return _HomeNearbyMessageCard(
        icon: Icons.tune_rounded,
        title: 'No spaces match these filters',
        message: 'Try removing a quick filter to see more nearby spaces.',
        actionLabel: onResetFilters == null ? 'Refresh' : 'Reset filters',
        onAction:
            onResetFilters ??
            () => ref.read(homeNearbyControllerProvider.notifier).refresh(),
      );
    }

    ref.watch(
      visibleParkingListingRevisionsProvider(
        parkingListingIdsKey(filteredItems.map((item) => item.id), maxIds: 8),
      ),
    );

    return Column(
      children: [
        if (state.isRefreshingWithData) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
        ],
        if (state.isStale ||
            state.hasPartialFailures ||
            state.isFallbackLocation ||
            state.message != null) ...[
          _HomeNearbyStatusBanner(state: state),
          const SizedBox(height: 12),
        ],
        ListView.separated(
          itemCount: filteredItems.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final route = _routeFor(item);
            final isFavorite = favoriteIds.contains(item.id);
            final liveSpot = item.serviceType == ServiceType.parking
                ? ref.watch(parkingListingSnapshotProvider(item.id))?.spot
                : null;
            final imageUrls = liveSpot?.imageUrls ?? _imageUrlsFor(item);
            return ProductCard(
              imageUrl: imageUrls.isEmpty ? '' : imageUrls.first,
              imageUrls: imageUrls,
              title: liveSpot?.title ?? item.title,
              subtitle: liveSpot == null
                  ? _subtitleFor(item)
                  : _spotSubtitleFor(liveSpot, item),
              priceText: liveSpot == null
                  ? item.price == null
                        ? null
                        : formatHourlyMoney(item.price!, item.currency ?? 'INR')
                  : formatHourlyMoney(liveSpot.price, liveSpot.currency),
              stats: liveSpot == null
                  ? _statsFor(item)
                  : _spotStatsFor(liveSpot, item),
              statsEvenlySpaced: true,
              favoriteSelected: isFavorite,
              imageHeight: 162,
              onTap: route == null ? null : () => context.push(route),
              onFavoritePressed: () => ref
                  .read(_homeNearbyFavoriteIdsProvider.notifier)
                  .toggle(item.id),
            );
          },
        ),
      ],
    );
  }

  String _spotSubtitleFor(
    ParkingSpot spot,
    GeoDiscoveryEntity<Map<String, Object?>> item,
  ) {
    if (spot.address.trim().isNotEmpty) {
      return spot.address;
    }
    if (spot.locality.trim().isNotEmpty) {
      return spot.locality;
    }
    return '${item.distanceKm.toStringAsFixed(1)} km nearby';
  }

  String? _routeFor(GeoDiscoveryEntity<Map<String, Object?>> item) {
    switch (item.serviceType) {
      case ServiceType.parking:
        return '/booking/${item.id}';
      case ServiceType.rental:
        return '/rental';
      case ServiceType.service:
        return '/services';
    }
  }

  List<String> _imageUrlsFor(GeoDiscoveryEntity<Map<String, Object?>> item) {
    final urls = <String>{};

    void addUrl(Object? value) {
      if (value is String) {
        final url = value.trim();
        if (url.isNotEmpty) {
          urls.add(url);
        }
        return;
      }

      if (value is Iterable) {
        for (final entry in value) {
          addUrl(entry);
        }
        return;
      }

      if (value is Map) {
        addUrl(value['secure_url']);
        addUrl(value['url']);
        addUrl(value['imageUrl']);
      }
    }

    addUrl(item.entity['imageUrls']);
    addUrl(item.entity['images']);
    addUrl(item.entity['photos']);
    addUrl(item.entity['parking_space_photos']);
    addUrl(item.imageUrl);
    addUrl(item.entity['imageUrl']);

    return urls.toList(growable: false);
  }

  String _subtitleFor(GeoDiscoveryEntity<Map<String, Object?>> item) {
    final address = item.entity['address']?.toString();
    if (address != null && address.trim().isNotEmpty) {
      return address;
    }

    final locality = item.entity['locality']?.toString();
    if (locality != null && locality.trim().isNotEmpty) {
      return locality;
    }

    return '${item.distanceKm.toStringAsFixed(1)} km nearby';
  }

  List<ProductCardStat> _statsFor(
    GeoDiscoveryEntity<Map<String, Object?>> item,
  ) {
    final slotsAvailable = (item.entity['slotsAvailable'] as num?)?.toInt();
    final stats = <ProductCardStat>[
      ProductCardStat(
        icon: Icons.near_me_outlined,
        label: '${item.distanceKm.toStringAsFixed(1)} km',
      ),
    ];

    if (slotsAvailable != null && slotsAvailable > 0) {
      stats.add(
        ProductCardStat(
          icon: Icons.local_parking_rounded,
          label: '$slotsAvailable spots',
        ),
      );
    }

    stats.add(
      ProductCardStat(
        icon: Icons.check_circle_outline_rounded,
        label: item.availabilityStatus.apiValue,
      ),
    );

    return stats;
  }

  List<ProductCardStat> _spotStatsFor(
    ParkingSpot spot,
    GeoDiscoveryEntity<Map<String, Object?>> item,
  ) {
    return [
      ProductCardStat(
        icon: Icons.near_me_outlined,
        label: '${item.distanceKm.toStringAsFixed(1)} km',
      ),
      ProductCardStat(
        icon: Icons.local_parking_rounded,
        label: '${spot.slotsAvailable} spots',
      ),
      ProductCardStat(icon: Icons.sync_rounded, label: 'Live'),
    ];
  }
}

class _HomeNearbyStatusBanner extends StatelessWidget {
  const _HomeNearbyStatusBanner({required this.state});

  final HomeNearbyViewState state;

  @override
  Widget build(BuildContext context) {
    final message = _messageFor(state);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF0B0B0C),
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF3F3F46),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageFor(HomeNearbyViewState state) {
    if (state.hasPartialFailures) {
      return 'Some categories could not refresh. Showing available results.';
    }
    if (state.isStale) {
      return 'Showing cached nearby results while the network recovers.';
    }
    if (state.isFallbackLocation) {
      return 'Using a fallback location for discovery.';
    }
    return state.message ?? 'Nearby discovery updated.';
  }
}

class _HomeNearbyMessageCard extends StatelessWidget {
  const _HomeNearbyMessageCard({
    required this.actionLabel,
    required this.icon,
    required this.message,
    required this.onAction,
    required this.title,
  });

  final String actionLabel;
  final IconData icon;
  final String message;
  final VoidCallback onAction;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111113),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: _HomeNearbyMessageIcon(icon: icon),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.28,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(_actionIconFor(actionLabel), size: 18),
              label: Text(
                actionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0B0B0C),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIconFor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('clear')) {
      return Icons.layers_clear_rounded;
    }
    if (normalized.contains('retry') || normalized.contains('refresh')) {
      return Icons.refresh_rounded;
    }
    if (normalized.contains('settings')) {
      return Icons.settings_rounded;
    }
    if (normalized.contains('try')) {
      return Icons.location_searching_rounded;
    }
    return Icons.arrow_forward_rounded;
  }
}

class _HomeNearbyMessageIcon extends StatelessWidget {
  const _HomeNearbyMessageIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFB9F45E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB9F45E).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Icon(icon, color: const Color(0xFF0B0B0C), size: 22),
      ),
    );
  }
}

class _HomeNearbySkeletonList extends StatelessWidget {
  const _HomeNearbySkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _HomeNearbySkeletonCard(),
        SizedBox(height: 14),
        _HomeNearbySkeletonCard(),
      ],
    );
  }
}

class _HomeNearbySkeletonCard extends StatelessWidget {
  const _HomeNearbySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E4E7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: const SizedBox(height: 162, width: double.infinity),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 13, 14, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(widthFactor: 0.62, height: 18),
                  SizedBox(height: 8),
                  _SkeletonLine(widthFactor: 0.88, height: 13),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _SkeletonPill(width: 76),
                      SizedBox(width: 8),
                      _SkeletonPill(width: 72),
                      SizedBox(width: 8),
                      _SkeletonPill(width: 84),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.height, required this.widthFactor});

  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE4E4E7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  const _SkeletonPill({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4E7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(width: width, height: 28),
    );
  }
}
