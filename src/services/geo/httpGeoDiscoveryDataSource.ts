import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { GeoDiscoveryError } from "@/core/geo/geoError";
import { apiClient, toApiError } from "@/services/api/apiClient";
import type {
  GeoDiscoveryBatchResult,
  GeoDiscoveryDataSource,
  GeoDiscoveryNormalizedQuery
} from "@/types/geo";

interface GeoDiscoveryApiErrorDetails {
  retryAfterMs?: number;
}

export class HttpGeoDiscoveryDataSource implements GeoDiscoveryDataSource {
  async searchNearby<TEntity = unknown>(
    query: GeoDiscoveryNormalizedQuery,
    signal?: AbortSignal,
  ): Promise<GeoDiscoveryBatchResult<TEntity>> {
    try {
      const response = await apiClient.post<GeoDiscoveryBatchResult<TEntity>>(
        geoDiscoveryConfig.api.endpoint,
        {
          cursors: query.cursors,
          filters: query.filters,
          latitude: query.latitude,
          longitude: query.longitude,
          pageSize: query.pageSize,
          queryFingerprint: query.queryFingerprint,
          radiusKm: query.radiusKm,
          requestId: query.requestId,
          schemaVersion: query.schemaVersion,
          serviceTypes: query.serviceTypes,
          sort: query.sort
        },
        { signal },
      );

      return response.data;
    } catch (error) {
      const apiError = toApiError(error);
      const details = apiError.details as GeoDiscoveryApiErrorDetails | undefined;

      if (apiError.code === "invalid_cursor") {
        throw new GeoDiscoveryError("Geo discovery cursor is invalid", {
          code: "invalid_cursor",
          retryable: true
        });
      }

      if (apiError.status === 429) {
        throw new GeoDiscoveryError("Geo discovery request was rate limited", {
          code: "rate_limited",
          retryAfterMs: details?.retryAfterMs,
          retryable: true
        });
      }

      if (apiError.status === 408 || apiError.status === 504) {
        throw new GeoDiscoveryError(apiError.message, {
          code: "backend_timeout",
          retryable: true
        });
      }

      if (apiError.status && apiError.status >= 500) {
        throw new GeoDiscoveryError(apiError.message, {
          code: "network_error",
          retryable: true
        });
      }

      throw new GeoDiscoveryError(apiError.message, {
        code: "network_error",
        retryable: true
      });
    }
  }
}
