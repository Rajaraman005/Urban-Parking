import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/state_view.dart';
import '../domain/parking_spot.dart';
import 'parking_listing_store.dart';

class GeoListView extends ConsumerWidget {
  const GeoListView({
    required this.items,
    required this.isLoading,
    required this.onRetry,
    super.key,
    this.error,
    this.isStale = false,
    this.partialFailures = const [],
    this.permissionDenied = false,
  });

  final List<GeoDiscoveryEntity<Map<String, Object?>>> items;
  final bool isLoading;
  final VoidCallback onRetry;
  final String? error;
  final bool isStale;
  final List<GeoDiscoveryPartialFailure> partialFailures;
  final bool permissionDenied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (permissionDenied) {
      return StateView(
        title: 'Location permission needed',
        body: 'Enable location access to discover resources near you.',
        actionLabel: 'Try again',
        onAction: onRetry,
      );
    }
    if (isLoading && items.isEmpty) {
      return const StateView(
        title: 'Searching nearby',
        body: 'Finding nearby resources around you.',
        isLoading: true,
      );
    }
    if (error != null && items.isEmpty) {
      return StateView(
        title: 'Unable to load results',
        body: error!,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }
    if (items.isEmpty) {
      return StateView(
        title: 'No nearby results',
        body: 'Try increasing the radius or changing filters.',
        actionLabel: 'Refresh',
        onAction: onRetry,
      );
    }

    ref.watch(
      visibleParkingListingRevisionsProvider(
        parkingListingIdsKey(items.map((item) => item.id), maxIds: 20),
      ),
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length + (isStale || partialFailures.isNotEmpty ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index == 0 && (isStale || partialFailures.isNotEmpty)) {
          return _Banner(
            isError: partialFailures.isNotEmpty,
            text: partialFailures.isNotEmpty
                ? 'Some categories could not refresh. Pull to retry.'
                : 'Showing cached nearby results.',
          );
        }
        final adjustedIndex = isStale || partialFailures.isNotEmpty
            ? index - 1
            : index;
        final item = items[adjustedIndex];
        final detailsRoute = item.serviceType == ServiceType.parking
            ? '/booking/${item.id}'
            : null;
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
          badge: _availabilityLabel(item.availabilityStatus),
          priceText: liveSpot == null
              ? item.price == null
                    ? null
                    : formatHourlyMoney(item.price!, item.currency ?? 'INR')
              : formatHourlyMoney(liveSpot.price, liveSpot.currency),
          stats: liveSpot == null
              ? _statsFor(item)
              : _spotStatsFor(liveSpot, item),
          onTap: detailsRoute == null ? null : () => context.push(detailsRoute),
          onOpenPressed: detailsRoute == null
              ? null
              : () => context.push(detailsRoute),
        );
      },
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

  String _availabilityLabel(AvailabilityStatus status) {
    switch (status) {
      case AvailabilityStatus.available:
        return 'Available';
      case AvailabilityStatus.limited:
        return 'Limited';
      case AvailabilityStatus.unavailable:
        return 'Unavailable';
      case AvailabilityStatus.unknown:
        return 'Nearby';
    }
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

    if (item.rating != null && item.rating! > 0) {
      stats.add(
        ProductCardStat(
          icon: Icons.star_rounded,
          label: item.rating!.toStringAsFixed(1),
        ),
      );
    }

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
      const ProductCardStat(icon: Icons.sync_rounded, label: 'Live'),
    ];
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
