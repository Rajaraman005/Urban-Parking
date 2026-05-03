export type ServiceType = "parking" | "rental" | "service";

export type AvailabilityStatus = "available" | "limited" | "unavailable" | "unknown";

export type GeoSortKey = "distance" | "price" | "rating";

export type GeoResultSource = "network" | "cache" | "mock";

export type GeoFailureCode =
  | "aborted"
  | "backend_timeout"
  | "contract_mismatch"
  | "gps_denied"
  | "gps_timeout"
  | "invalid_cursor"
  | "network_error"
  | "offline"
  | "rate_limited"
  | "schema_version_unsupported"
  | "unknown";

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

export interface GeoDiscoveryFilters {
  availability?: AvailabilityStatus | "any";
  maxPrice?: number;
  minRating?: number;
  [key: string]: string | number | boolean | null | undefined;
}

export interface GeoDiscoveryQuery<TFilters extends GeoDiscoveryFilters = GeoDiscoveryFilters>
  extends GeoPoint {
  cursor?: string;
  filters?: TFilters;
  pageSize?: number;
  radiusKm?: number;
  requestId?: string;
  serviceType: ServiceType;
  sort?: GeoSortKey;
}

export interface GeoDiscoveryBatchQuery<TFilters extends GeoDiscoveryFilters = GeoDiscoveryFilters>
  extends GeoPoint {
  cursors?: Partial<Record<ServiceType, string>>;
  filters?: Partial<Record<ServiceType, TFilters>> | TFilters;
  pageSize?: number;
  radiusKm?: number;
  requestId?: string;
  serviceTypes: readonly ServiceType[];
  sort?: GeoSortKey;
}

export interface GeoDiscoveryNormalizedQuery<TFilters extends GeoDiscoveryFilters = GeoDiscoveryFilters>
  extends GeoPoint {
  cursors: Partial<Record<ServiceType, string>>;
  filters: Partial<Record<ServiceType, TFilters>>;
  pageSize: number;
  queryFingerprint: string;
  radiusKm: number;
  requestId: string;
  roundedGeocell: string;
  schemaVersion: number;
  serviceTypes: readonly ServiceType[];
  sort: GeoSortKey;
}

export interface GeoDiscoveryEntity<TEntity = unknown> {
  availabilityStatus: AvailabilityStatus;
  currency?: string;
  distanceKm: number;
  entity: TEntity;
  id: string;
  imageUrl?: string;
  location: GeoPoint;
  price?: number;
  rating?: number;
  serviceType: ServiceType;
  title: string;
}

export interface GeoDiscoveryPage<TEntity = unknown> {
  cursorInvalidated?: boolean;
  fetchedAt: string;
  isStale: boolean;
  items: GeoDiscoveryEntity<TEntity>[];
  nextCursor?: string;
  queryFingerprint: string;
  schemaVersion: number;
  source: GeoResultSource;
}

export interface GeoDiscoveryPartialFailure {
  code: GeoFailureCode;
  message: string;
  retryable: boolean;
  serviceType: ServiceType;
}

export interface GeoDiscoveryBatchResult<TEntity = unknown> {
  fetchedAt: string;
  partialFailures: GeoDiscoveryPartialFailure[];
  queryFingerprint: string;
  results: Partial<Record<ServiceType, GeoDiscoveryPage<TEntity>>>;
  schemaVersion: number;
  source: GeoResultSource;
}

export interface GeoDiscoveryDataSource {
  searchNearby<TEntity = unknown>(
    query: GeoDiscoveryNormalizedQuery,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryBatchResult<TEntity>>;
}

export interface GeoDiscoveryRepository {
  searchNearby<TEntity = unknown>(
    query: GeoDiscoveryNormalizedQuery,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryBatchResult<TEntity>>;
}

export interface GeoTelemetryPayload {
  cacheHit?: boolean;
  code?: GeoFailureCode;
  durationMs?: number;
  emptyResult?: boolean;
  errorRateBucket?: string;
  geocell?: string;
  isStale?: boolean;
  pageSize?: number;
  queryFingerprint?: string;
  radiusKm?: number;
  retryCount?: number;
  schemaVersion?: number;
  serviceType?: ServiceType;
  serviceTypes?: string;
  source?: GeoResultSource;
  status?: string;
}
