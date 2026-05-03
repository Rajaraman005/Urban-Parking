import type { ServiceType } from "@/types/geo";

export type GeoMockScenario =
  | "empty"
  | "malformed"
  | "none"
  | "partialFailure"
  | "rateLimited"
  | "serverError"
  | "timeout";

export type GeoMockLatencyProfile = "fast" | "normal" | "slow";

export const GEO_DISCOVERY_SCHEMA_VERSION = 1;

export const geoDiscoveryConfig = {
  api: {
    endpoint: "/geo-discovery/search",
    schemaVersion: GEO_DISCOVERY_SCHEMA_VERSION,
    timeoutMs: 8000
  },
  cache: {
    freshTtlMs: 60_000,
    maxEntries: 100,
    maxSizeBytes: 10 * 1024 * 1024,
    staleTtlMs: 5 * 60_000
  },
  featureFlags: {
    geoDiscoveryBatchEnabled: true,
    geoDiscoveryEngineEnabled: true,
    geoDiscoveryShadowModeEnabled: __DEV__
  },
  location: {
    debounceMs: 750,
    forceRefreshDistanceMeters: 1000,
    gpsTimeoutMs: 5000,
    ignoreMovementMeters: 75,
    invalidateCacheDistanceMeters: 250,
    resetSessionDistanceMeters: 10_000
  },
  mock: {
    latencyProfile: "normal" as GeoMockLatencyProfile,
    scenario: "none" as GeoMockScenario,
    seed: "chennai-egmore"
  },
  pagination: {
    defaultPageSize: 20,
    maxPageSize: 50
  },
  performance: {
    coldNetworkTtfrBudgetMs: 3000,
    haversineBatchBudgetMs: 50,
    haversineBatchSize: 10_000,
    maxInitialMarkers: 100,
    rawMarkerHardLimit: 200,
    warmCacheTtfrBudgetMs: 1500
  },
  radius: {
    defaultKm: 5,
    maxKm: 10,
    minKm: 1
  },
  rateLimit: {
    minIntervalMs: 600,
    retryDelaysMs: [500, 1000, 2000, 4000],
    retryMaxDelayMs: 16_000,
    retryMaxAttempts: 3
  },
  serviceTypes: ["parking", "rental", "service"] as const satisfies readonly ServiceType[]
} as const;
