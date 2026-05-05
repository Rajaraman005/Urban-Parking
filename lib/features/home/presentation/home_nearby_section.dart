import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/product_card.dart';
import 'home_nearby_controller.dart';

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
  const HomeNearbySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(homeNearbyControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeNearbyHeader(
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
              if (state.permissionDenied && state.center == null) {
                return _HomeNearbyMessageCard(
                  icon: Icons.location_off_rounded,
                  title: 'Location permission needed',
                  message:
                      state.message ??
                      'Allow location access to show spaces near you.',
                  actionLabel: 'Try again',
                  onAction: () =>
                      ref.read(homeNearbyControllerProvider.notifier).refresh(),
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

              return _HomeNearbyResults(state: state);
            },
          ),
        ],
      ),
    );
  }
}

class _HomeNearbyHeader extends StatelessWidget {
  const _HomeNearbyHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
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
                'Live spaces from your location',
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
          color: const Color(0xFFF7F7F8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  const _HomeNearbyResults({required this.state});

  final HomeNearbyViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(_homeNearbyFavoriteIdsProvider);

    return Column(
      children: [
        if (state.isStale ||
            state.hasPartialFailures ||
            state.isFallbackLocation ||
            state.message != null) ...[
          _HomeNearbyStatusBanner(state: state),
          const SizedBox(height: 12),
        ],
        ListView.separated(
          itemCount: state.items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final item = state.items[index];
            final route = _routeFor(item);
            final isFavorite = favoriteIds.contains(item.id);
            return ProductCard(
              imageUrl: _imageUrlFor(item),
              title: item.title,
              subtitle: _subtitleFor(item),
              priceText: item.price == null
                  ? null
                  : formatHourlyMoney(item.price!, item.currency ?? 'INR'),
              stats: _statsFor(item),
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

  String _imageUrlFor(GeoDiscoveryEntity<Map<String, Object?>> item) {
    return item.imageUrl ??
        item.entity['imageUrl']?.toString() ??
        'https://images.unsplash.com/photo-1506521781263-d8422e82f27a';
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
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFF0B0B0C),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0B0B0C),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B0B0C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(112, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(actionLabel),
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
            const ColoredBox(
              color: Color(0xFFE4E4E7),
              child: SizedBox(height: 162, width: double.infinity),
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
