import { useEffect, useState } from "react";

import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { distanceMeters } from "@/core/geo/distance";
import type { GeoPoint } from "@/types/geo";

export function useDebouncedLocation(location: GeoPoint | null, debounceMs = geoDiscoveryConfig.location.debounceMs) {
  const [debouncedLocation, setDebouncedLocation] = useState<GeoPoint | null>(location);

  useEffect(() => {
    if (!location) {
      setDebouncedLocation(null);
      return;
    }

    if (
      debouncedLocation &&
      distanceMeters(debouncedLocation, location) < geoDiscoveryConfig.location.ignoreMovementMeters
    ) {
      return;
    }

    const timer = setTimeout(() => {
      setDebouncedLocation(location);
    }, debounceMs);

    return () => clearTimeout(timer);
  }, [debounceMs, debouncedLocation, location]);

  return debouncedLocation;
}
