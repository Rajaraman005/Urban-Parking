import * as Location from "expo-location";
import { useCallback, useEffect, useMemo, useState } from "react";

import { CHENNAI_CENTER } from "@/constants/mockParking";
import type { GeoPoint, ParkingSpot } from "@/models/parking";
import { parkingApi } from "@/services/api/parkingApi";
import { toApiError } from "@/services/api/apiClient";
import { useParkingStore } from "@/store/parkingStore";

export function useNearbyParking() {
  const [spots, setSpots] = useState<ParkingSpot[]>([]);
  const [center, setCenter] = useState<GeoPoint>(CHENNAI_CENTER);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const setRecentSpots = useParkingStore((state) => state.setRecentSpots);

  const loadNearby = useCallback(async () => {
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
      const nearby = await parkingApi.searchNearby({ center: nextCenter, radiusKm: 15 });
      setSpots(nearby);
      setRecentSpots(nearby);
    } catch (loadError) {
      setError(toApiError(loadError).message);
    } finally {
      setIsLoading(false);
    }
  }, [setRecentSpots]);

  useEffect(() => {
    void loadNearby();
  }, [loadNearby]);

  return useMemo(
    () => ({
      spots,
      center,
      isLoading,
      error,
      refresh: loadNearby
    }),
    [center, error, isLoading, loadNearby, spots]
  );
}
