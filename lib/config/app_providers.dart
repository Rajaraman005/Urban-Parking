import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/network/api_client.dart';
import '../core/utils/geo_discovery/geo_cache.dart';
import '../core/utils/geo_discovery/geo_discovery_engine.dart';
import '../core/utils/geo_discovery/geo_repository.dart';
import '../core/utils/geo_discovery/marketplace_data_sources.dart';
import '../core/utils/location_service.dart';
import '../features/parking/data/parking_repository_impl.dart';
import '../features/parking/domain/parking_repository.dart';
import 'app_config.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    accessTokenReader: () {
      if (!AppConfig.isSupabaseConfigured) return null;
      return Supabase.instance.client.auth.currentSession?.accessToken;
    },
  );
});

final geoDiscoveryCacheProvider = Provider<GeoDiscoveryCache>((ref) {
  return GeoDiscoveryCache();
});

final geoDiscoveryEngineProvider = Provider<GeoDiscoveryEngine>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final dataSource = createMarketplaceDataSource(apiClient);
  final repository = DefaultGeoDiscoveryRepository(dataSource);
  return GeoDiscoveryEngine(
    repository: repository,
    cache: ref.watch(geoDiscoveryCacheProvider),
  );
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    geoDiscoveryEngine: ref.watch(geoDiscoveryEngineProvider),
  );
});
