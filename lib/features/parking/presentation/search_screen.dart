import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo_discovery/geo_types.dart';
import '../../../shared/widgets/app_screen.dart';
import 'geo_discovery_controller.dart';
import 'geo_list_view.dart';
import 'nearby_map_view.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedServiceTypeProvider);
    final discovery = ref.watch(geoDiscoveryControllerProvider);

    return AppScreen(
      padded: false,
      appBar: AppBar(
        title: const Text('Nearby'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(geoDiscoveryControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final serviceType in ServiceType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_labelFor(serviceType)),
                      selected: selected == serviceType,
                      onSelected: (_) {
                        ref
                            .read(selectedServiceTypeProvider.notifier)
                            .select(serviceType);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: discovery.when(
              loading: () => GeoListView(
                isLoading: true,
                items: const [],
                onRetry: () =>
                    ref.read(geoDiscoveryControllerProvider.notifier).refresh(),
              ),
              error: (error, _) => GeoListView(
                error: error.toString(),
                isLoading: false,
                items: const [],
                onRetry: () =>
                    ref.read(geoDiscoveryControllerProvider.notifier).refresh(),
              ),
              data: (state) {
                final page = state.result?.results[selected];
                final items = page?.items ?? const [];
                return Column(
                  children: [
                    if (state.isRefreshingWithData)
                      const LinearProgressIndicator(minHeight: 2),
                    SizedBox(
                      height: 220,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: NearbyMapView(
                          center: state.center,
                          items: items,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GeoListView(
                        isLoading: false,
                        items: items,
                        isStale: page?.isStale ?? false,
                        partialFailures: state.failuresFor(selected),
                        permissionDenied:
                            state.permissionDenied && state.center == null,
                        error: state.message,
                        onRetry: () => ref
                            .read(geoDiscoveryControllerProvider.notifier)
                            .refresh(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(ServiceType type) {
    switch (type) {
      case ServiceType.parking:
        return 'Parking';
      case ServiceType.rental:
        return 'Rentals';
      case ServiceType.service:
        return 'Services';
    }
  }
}
