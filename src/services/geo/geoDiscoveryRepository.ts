import type {
  GeoDiscoveryBatchResult,
  GeoDiscoveryDataSource,
  GeoDiscoveryNormalizedQuery,
  GeoDiscoveryRepository
} from "@/types/geo";

export class DefaultGeoDiscoveryRepository implements GeoDiscoveryRepository {
  constructor(private readonly dataSource: GeoDiscoveryDataSource) {}

  searchNearby<TEntity = unknown>(
    query: GeoDiscoveryNormalizedQuery,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryBatchResult<TEntity>> {
    return this.dataSource.searchNearby<TEntity>(query, signal);
  }
}
