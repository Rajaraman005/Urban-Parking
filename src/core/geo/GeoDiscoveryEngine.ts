import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { GeoDiscoveryError, toGeoDiscoveryError } from "@/core/geo/geoError";
import { GeoLruCache } from "@/core/geo/lruCache";
import { normalizeGeoBatchQuery } from "@/core/geo/query";
import { GeoRequestRateGuard } from "@/core/geo/rateGuard";
import { withGeoRetry } from "@/core/geo/retry";
import type {
  GeoDiscoveryBatchQuery,
  GeoDiscoveryBatchResult,
  GeoDiscoveryNormalizedQuery,
  GeoDiscoveryPage,
  GeoDiscoveryQuery,
  GeoDiscoveryRepository,
  ServiceType
} from "@/types/geo";
import { geoTelemetry } from "@/utils/telemetry/geoTelemetry";

const stableCursorKey = (cursors: Partial<Record<ServiceType, string>>) =>
  Object.entries(cursors)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([serviceType, cursor]) => `${serviceType}:${cursor ?? "first"}`)
    .join(",");

const cacheKeyFor = (query: GeoDiscoveryNormalizedQuery) =>
  `${query.queryFingerprint}|cursor:${stableCursorKey(query.cursors) || "first"}`;

const markPage = <TEntity>(
  page: GeoDiscoveryPage<TEntity>,
  isStale: boolean,
  source: "cache",
): GeoDiscoveryPage<TEntity> => ({
  ...page,
  isStale,
  source
});

const markBatch = <TEntity>(
  result: GeoDiscoveryBatchResult<TEntity>,
  isStale: boolean,
): GeoDiscoveryBatchResult<TEntity> => ({
  ...result,
  results: Object.fromEntries(
    Object.entries(result.results).map(([serviceType, page]) => [
      serviceType,
      page ? markPage(page as GeoDiscoveryPage<TEntity>, isStale, "cache") : page
    ]),
  ),
  source: "cache"
});

export class GeoDiscoveryEngine {
  private cache = new GeoLruCache<GeoDiscoveryBatchResult<unknown>>();
  private inFlight = new Map<string, Promise<GeoDiscoveryBatchResult<unknown>>>();
  private rateGuard = new GeoRequestRateGuard();

  constructor(private readonly repository: GeoDiscoveryRepository) {}

  async getNearby<TEntity = unknown>(
    query: GeoDiscoveryQuery,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryPage<TEntity>> {
    const batchResult = await this.getNearbyBatch<TEntity>(
      {
        ...query,
        cursors: query.cursor ? { [query.serviceType]: query.cursor } : undefined,
        serviceTypes: [query.serviceType]
      },
      signal,
    );
    const page = batchResult.results[query.serviceType];

    if (!page) {
      throw new GeoDiscoveryError(`No ${query.serviceType} results returned`, {
        code: "unknown",
        retryable: true
      });
    }

    return page as GeoDiscoveryPage<TEntity>;
  }

  async getNearbyBatch<TEntity = unknown>(
    query: GeoDiscoveryBatchQuery,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryBatchResult<TEntity>> {
    const normalized = normalizeGeoBatchQuery(query);

    if (normalized.serviceTypes.length === 0) {
      throw new GeoDiscoveryError("At least one service type is required", {
        code: "unknown",
        retryable: false
      });
    }

    geoTelemetry.event(
      normalized.serviceTypes.length > 1 ? "geo_batch_search_requested" : "geo_search_requested",
      {
        geocell: normalized.roundedGeocell,
        pageSize: normalized.pageSize,
        queryFingerprint: normalized.queryFingerprint,
        radiusKm: normalized.radiusKm,
        schemaVersion: normalized.schemaVersion,
        serviceTypes: normalized.serviceTypes.join(",")
      },
    );

    return this.execute<TEntity>(normalized, signal);
  }

  clearCache() {
    this.cache.clear();
  }

  private async execute<TEntity>(
    normalized: GeoDiscoveryNormalizedQuery,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryBatchResult<TEntity>> {
    const key = cacheKeyFor(normalized);
    const cached = this.cache.get(key);

    if (cached.freshness === "fresh" && cached.value) {
      geoTelemetry.event("geo_cache_hit", {
        cacheHit: true,
        geocell: normalized.roundedGeocell,
        queryFingerprint: normalized.queryFingerprint,
        serviceTypes: normalized.serviceTypes.join(",")
      });
      return markBatch(cached.value as GeoDiscoveryBatchResult<TEntity>, false);
    }

    try {
      const result = await this.fetchNetwork<TEntity>(normalized, key, signal);
      this.cache.set(key, result as GeoDiscoveryBatchResult<unknown>);
      return result;
    } catch (error) {
      const geoError = toGeoDiscoveryError(error);

      if (geoError.code === "invalid_cursor") {
        geoTelemetry.warn("geo_cursor_invalidated", {
          code: geoError.code,
          geocell: normalized.roundedGeocell,
          queryFingerprint: normalized.queryFingerprint,
          serviceTypes: normalized.serviceTypes.join(",")
        });
        const firstPageQuery = { ...normalized, cursors: {} };
        const firstPageKey = cacheKeyFor(firstPageQuery);
        const result = await this.fetchNetwork<TEntity>(firstPageQuery, firstPageKey, signal);
        const cursorInvalidatedResult = {
          ...result,
          results: Object.fromEntries(
            Object.entries(result.results).map(([serviceType, page]) => [
              serviceType,
              page ? { ...page, cursorInvalidated: true } : page
            ]),
          )
        } as GeoDiscoveryBatchResult<TEntity>;
        this.cache.set(firstPageKey, cursorInvalidatedResult as GeoDiscoveryBatchResult<unknown>);
        return cursorInvalidatedResult;
      }

      if (cached.freshness === "stale" && cached.value) {
        geoTelemetry.warn("geo_cache_stale_served", {
          code: geoError.code,
          geocell: normalized.roundedGeocell,
          isStale: true,
          queryFingerprint: normalized.queryFingerprint,
          serviceTypes: normalized.serviceTypes.join(",")
        });
        return markBatch(cached.value as GeoDiscoveryBatchResult<TEntity>, true);
      }

      geoTelemetry.error("geo_search_failed", {
        code: geoError.code,
        geocell: normalized.roundedGeocell,
        queryFingerprint: normalized.queryFingerprint,
        serviceTypes: normalized.serviceTypes.join(","),
        status: "failed"
      });

      throw geoError;
    }
  }

  private async fetchNetwork<TEntity>(
    normalized: GeoDiscoveryNormalizedQuery,
    key: string,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryBatchResult<TEntity>> {
    const activeRequest = this.inFlight.get(key);

    if (activeRequest) {
      return activeRequest as Promise<GeoDiscoveryBatchResult<TEntity>>;
    }

    const startedAt = Date.now();
    const promise = (async () => {
      await this.rateGuard.waitForSlot(normalized.queryFingerprint, signal);

      const result = await withGeoRetry(
        () => this.repository.searchNearby<TEntity>(normalized, signal),
        {
          queryFingerprint: normalized.queryFingerprint,
          serviceTypes: normalized.serviceTypes.join(","),
          signal
        },
      );

      if (result.schemaVersion !== geoDiscoveryConfig.api.schemaVersion) {
        throw new GeoDiscoveryError("Geo discovery schema version is unsupported", {
          code: "schema_version_unsupported",
          retryable: false
        });
      }

      geoTelemetry.event("geo_search_succeeded", {
        durationMs: Date.now() - startedAt,
        emptyResult: Object.values(result.results).every((page) => !page || page.items.length === 0),
        geocell: normalized.roundedGeocell,
        queryFingerprint: normalized.queryFingerprint,
        schemaVersion: result.schemaVersion,
        serviceTypes: normalized.serviceTypes.join(","),
        source: result.source
      });

      return result;
    })();

    this.inFlight.set(key, promise as Promise<GeoDiscoveryBatchResult<unknown>>);

    try {
      return await promise;
    } finally {
      this.inFlight.delete(key);
    }
  }
}
