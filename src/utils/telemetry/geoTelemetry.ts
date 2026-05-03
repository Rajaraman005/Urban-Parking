import { logger } from "@/utils/logger";
import type { GeoTelemetryPayload } from "@/types/geo";

type SafeTelemetryMeta = Record<string, string | number | boolean | null | undefined>;

export type GeoTelemetryEvent =
  | "geo_batch_search_requested"
  | "geo_cache_hit"
  | "geo_cache_stale_served"
  | "geo_cursor_invalidated"
  | "geo_location_resolved"
  | "geo_permission_denied"
  | "geo_permission_requested"
  | "geo_rate_limited"
  | "geo_results_rendered"
  | "geo_search_failed"
  | "geo_search_requested"
  | "geo_search_succeeded";

const sanitizePayload = (payload?: GeoTelemetryPayload): SafeTelemetryMeta | undefined => {
  if (!payload) {
    return undefined;
  }

  const { geocell, ...rest } = payload;

  return {
    ...(rest as SafeTelemetryMeta),
    geocell
  };
};

export const geoTelemetry = {
  event(event: GeoTelemetryEvent, payload?: GeoTelemetryPayload) {
    logger.info(event, sanitizePayload(payload));
  },

  error(event: GeoTelemetryEvent, payload?: GeoTelemetryPayload) {
    logger.error(event, sanitizePayload(payload));
  },

  warn(event: GeoTelemetryEvent, payload?: GeoTelemetryPayload) {
    logger.warn(event, sanitizePayload(payload));
  }
};
