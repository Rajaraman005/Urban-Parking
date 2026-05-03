import * as Location from "expo-location";
import { useCallback, useEffect, useMemo, useState } from "react";

import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { CHENNAI_CENTER } from "@/constants/mockParking";
import { geoTelemetry } from "@/utils/telemetry/geoTelemetry";
import type { GeoPoint } from "@/types/geo";

export type LocationPermissionState = "denied" | "granted" | "undetermined";

interface LocationState {
  error: string | null;
  isFallback: boolean;
  isResolving: boolean;
  location: GeoPoint | null;
  permissionStatus: LocationPermissionState;
}

const timeout = <TValue,>(promise: Promise<TValue>, timeoutMs: number) =>
  Promise.race([
    promise,
    new Promise<never>((_, reject) => {
      setTimeout(() => reject(new Error("GPS location timed out")), timeoutMs);
    })
  ]);

const toGeoPoint = (position: Location.LocationObject): GeoPoint => ({
  latitude: position.coords.latitude,
  longitude: position.coords.longitude
});

const devFallbackLocation = (): GeoPoint | null =>
  __DEV__
    ? {
        latitude: CHENNAI_CENTER.latitude,
        longitude: CHENNAI_CENTER.longitude
      }
    : null;

export function useCurrentLocation(enabled = true) {
  const [state, setState] = useState<LocationState>({
    error: null,
    isFallback: false,
    isResolving: enabled,
    location: null,
    permissionStatus: "undetermined"
  });

  const resolveLocation = useCallback(async () => {
    if (!enabled) {
      return;
    }

    setState((current) => ({ ...current, error: null, isResolving: true }));
    const startedAt = Date.now();

    try {
      geoTelemetry.event("geo_permission_requested");
      const permission = await Location.requestForegroundPermissionsAsync();
      const permissionStatus = permission.status as LocationPermissionState;

      if (permission.status !== "granted") {
        geoTelemetry.warn("geo_permission_denied", { status: permission.status });
        const fallback = devFallbackLocation();

        setState({
          error: "Location permission is required to show nearby results.",
          isFallback: Boolean(fallback),
          isResolving: false,
          location: fallback,
          permissionStatus
        });
        return;
      }

      const position = await timeout(
        Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced }),
        geoDiscoveryConfig.location.gpsTimeoutMs,
      ).catch(async () => {
        const lastKnown = await Location.getLastKnownPositionAsync();

        if (!lastKnown) {
          throw new Error("GPS location timed out");
        }

        return lastKnown;
      });
      const location = toGeoPoint(position);

      geoTelemetry.event("geo_location_resolved", {
        durationMs: Date.now() - startedAt,
        geocell: `${location.latitude.toFixed(3)},${location.longitude.toFixed(3)}`,
        status: "granted"
      });

      setState({
        error: null,
        isFallback: false,
        isResolving: false,
        location,
        permissionStatus
      });
    } catch (error) {
      const fallback = devFallbackLocation();

      setState({
        error: error instanceof Error ? error.message : "Unable to resolve location.",
        isFallback: Boolean(fallback),
        isResolving: false,
        location: fallback,
        permissionStatus: "granted"
      });
    }
  }, [enabled]);

  useEffect(() => {
    void resolveLocation();
  }, [resolveLocation]);

  return useMemo(
    () => ({
      ...state,
      refreshLocation: resolveLocation
    }),
    [resolveLocation, state],
  );
}
