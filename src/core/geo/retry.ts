import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { GeoDiscoveryError, toGeoDiscoveryError } from "@/core/geo/geoError";
import { sleepWithAbort } from "@/core/geo/rateGuard";
import { geoTelemetry } from "@/utils/telemetry/geoTelemetry";

const retryableCodes = new Set(["backend_timeout", "network_error", "offline", "rate_limited", "unknown"]);

const jitter = (delayMs: number) => Math.round(Math.random() * delayMs);

export const withGeoRetry = async <TValue>(
  operation: () => Promise<TValue>,
  options: {
    queryFingerprint: string;
    serviceTypes: string;
    signal?: AbortSignal;
  },
): Promise<TValue> => {
  let attempt = 0;
  let lastError: GeoDiscoveryError | null = null;

  while (attempt <= geoDiscoveryConfig.rateLimit.retryMaxAttempts) {
    try {
      return await operation();
    } catch (error) {
      const geoError = toGeoDiscoveryError(error);
      lastError = geoError;

      if (
        options.signal?.aborted ||
        !geoError.retryable ||
        !retryableCodes.has(geoError.code) ||
        attempt >= geoDiscoveryConfig.rateLimit.retryMaxAttempts
      ) {
        throw geoError;
      }

      const configuredDelay =
        geoError.retryAfterMs ??
        geoDiscoveryConfig.rateLimit.retryDelaysMs[
          Math.min(attempt, geoDiscoveryConfig.rateLimit.retryDelaysMs.length - 1)
        ] ??
        geoDiscoveryConfig.rateLimit.retryMaxDelayMs;
      const delayMs = Math.min(jitter(configuredDelay), geoDiscoveryConfig.rateLimit.retryMaxDelayMs);

      geoTelemetry.warn("geo_search_failed", {
        code: geoError.code,
        durationMs: delayMs,
        queryFingerprint: options.queryFingerprint,
        retryCount: attempt + 1,
        serviceTypes: options.serviceTypes,
        status: "retrying"
      });

      await sleepWithAbort(delayMs, options.signal);
      attempt += 1;
    }
  }

  throw lastError ?? new GeoDiscoveryError("Geo discovery retry failed", { code: "unknown" });
};
