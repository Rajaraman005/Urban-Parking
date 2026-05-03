import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { geoTelemetry } from "@/utils/telemetry/geoTelemetry";

const sleep = (ms: number, signal?: AbortSignal) =>
  new Promise<void>((resolve, reject) => {
    if (signal?.aborted) {
      reject(new Error("Aborted"));
      return;
    }

    const timeout = setTimeout(resolve, ms);

    signal?.addEventListener(
      "abort",
      () => {
        clearTimeout(timeout);
        reject(new Error("Aborted"));
      },
      { once: true },
    );
  });

export class GeoRequestRateGuard {
  private lastAttemptByFingerprint = new Map<string, number>();

  async waitForSlot(queryFingerprint: string, signal?: AbortSignal) {
    const now = Date.now();
    const lastAttempt = this.lastAttemptByFingerprint.get(queryFingerprint) ?? 0;
    const elapsed = now - lastAttempt;
    const waitMs = geoDiscoveryConfig.rateLimit.minIntervalMs - elapsed;

    if (waitMs > 0) {
      geoTelemetry.warn("geo_rate_limited", {
        durationMs: waitMs,
        queryFingerprint,
        status: "client_wait"
      });
      await sleep(waitMs, signal);
    }

    this.lastAttemptByFingerprint.set(queryFingerprint, Date.now());
  }
}

export const sleepWithAbort = sleep;
