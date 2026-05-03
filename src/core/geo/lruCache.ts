import { geoDiscoveryConfig } from "@/config/geoDiscovery";

export type CacheFreshness = "fresh" | "miss" | "stale";

interface CacheEntry<TValue> {
  createdAt: number;
  sizeBytes: number;
  value: TValue;
}

export class GeoLruCache<TValue> {
  private entries = new Map<string, CacheEntry<TValue>>();
  private totalSizeBytes = 0;

  get(key: string): { freshness: CacheFreshness; value?: TValue } {
    const entry = this.entries.get(key);

    if (!entry) {
      return { freshness: "miss" };
    }

    this.entries.delete(key);
    this.entries.set(key, entry);

    const ageMs = Date.now() - entry.createdAt;

    if (ageMs <= geoDiscoveryConfig.cache.freshTtlMs) {
      return { freshness: "fresh", value: entry.value };
    }

    if (ageMs <= geoDiscoveryConfig.cache.staleTtlMs) {
      return { freshness: "stale", value: entry.value };
    }

    this.delete(key);
    return { freshness: "miss" };
  }

  set(key: string, value: TValue) {
    this.delete(key);

    const sizeBytes = this.estimateSize(value);
    this.entries.set(key, {
      createdAt: Date.now(),
      sizeBytes,
      value
    });
    this.totalSizeBytes += sizeBytes;
    this.evictIfNeeded();
  }

  delete(key: string) {
    const entry = this.entries.get(key);

    if (!entry) {
      return;
    }

    this.totalSizeBytes -= entry.sizeBytes;
    this.entries.delete(key);
  }

  clear() {
    this.entries.clear();
    this.totalSizeBytes = 0;
  }

  private estimateSize(value: TValue) {
    try {
      return JSON.stringify(value).length * 2;
    } catch {
      return 1024;
    }
  }

  private evictIfNeeded() {
    while (
      this.entries.size > geoDiscoveryConfig.cache.maxEntries ||
      this.totalSizeBytes > geoDiscoveryConfig.cache.maxSizeBytes
    ) {
      const oldestKey = this.entries.keys().next().value as string | undefined;

      if (!oldestKey) {
        break;
      }

      this.delete(oldestKey);
    }
  }
}
