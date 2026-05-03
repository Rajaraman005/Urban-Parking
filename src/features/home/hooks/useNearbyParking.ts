import * as Location from "expo-location";
import { useCallback, useEffect, useMemo, useState } from "react";

import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { CHENNAI_CENTER } from "@/constants/mockParking";
import { useGeoDiscovery } from "@/hooks/useGeoDiscovery";
import type { GeoPoint, ParkingSpot } from "@/models/parking";
import { parkingApi } from "@/services/api/parkingApi";
import { toApiError } from "@/services/api/apiClient";
import { useParkingStore } from "@/store/parkingStore";

const radiusKm = geoDiscoveryConfig.radius.defaultKm;

const useLegacyNearbyParking = (enabled: boolean) => {
  const [spots, setSpots] = useState<ParkingSpot[]>([]);
  const [center, setCenter] = useState<GeoPoint>(CHENNAI_CENTER);
  const [isLoading, setIsLoading] = useState(enabled);
  const [error, setError] = useState<string | null>(null);

  const loadNearby = useCallback(async () => {
    if (!enabled) {
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const permission = await Location.requestForegroundPermissionsAsync();
      let nextCenter: GeoPoint = CHENNAI_CENTER;

      if (permission.status === "granted") {
        const position = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
        nextCenter = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude
        };
      }

      setCenter(nextCenter);
      setSpots(await parkingApi.searchNearby({ center: nextCenter, radiusKm }));
    } catch (loadError) {
      setError(toApiError(loadError).message);
    } finally {
      setIsLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    void loadNearby();
  }, [loadNearby]);

  return useMemo(
    () => ({
      center,
      error,
      isLoading,
      refresh: loadNearby,
      spots
    }),
    [center, error, isLoading, loadNearby, spots],
  );
};

export function useNearbyParking() {
  const useEngine = geoDiscoveryConfig.featureFlags.geoDiscoveryEngineEnabled;
  const setRecentSpots = useParkingStore((state) => state.setRecentSpots);
  const geo = useGeoDiscovery<ParkingSpot>({
    enabled: useEngine,
    radiusKm,
    serviceType: "parking"
  });
  const legacy = useLegacyNearbyParking(!useEngine);
  const geoSpots = useMemo(() => geo.items.map((item) => item.entity), [geo.items]);
  const spots = useEngine ? geoSpots : legacy.spots;

  useEffect(() => {
    setRecentSpots(spots);
  }, [setRecentSpots, spots]);

  return useMemo(
    () =>
      useEngine
        ? {
            center: geo.center ?? CHENNAI_CENTER,
            error: geo.error,
            isLoading: geo.isLoading,
            refresh: geo.refresh,
            spots
          }
        : legacy,
    [geo.center, geo.error, geo.isLoading, geo.refresh, legacy, spots, useEngine],
  );
}
