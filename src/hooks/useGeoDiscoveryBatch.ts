import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { geoDiscoveryEngine } from "@/services/geo";
import { useGeoDiscoveryStore } from "@/store/geoDiscoveryStore";
import { useCurrentLocation } from "@/hooks/useCurrentLocation";
import { useDebouncedLocation } from "@/hooks/useDebouncedLocation";
import type {
  GeoDiscoveryBatchResult,
  GeoDiscoveryFilters,
  GeoSortKey,
  ServiceType
} from "@/types/geo";
import { geoTelemetry } from "@/utils/telemetry/geoTelemetry";

interface UseGeoDiscoveryBatchParams<TFilters extends GeoDiscoveryFilters = GeoDiscoveryFilters> {
  enabled?: boolean;
  filters?: Partial<Record<ServiceType, TFilters>> | TFilters;
  pageSize?: number;
  radiusKm?: number;
  serviceTypes?: readonly ServiceType[];
  sort?: GeoSortKey;
}

interface BatchState<TEntity> {
  error: string | null;
  isLoading: boolean;
  isRefreshing: boolean;
  result: GeoDiscoveryBatchResult<TEntity> | null;
}

export function useGeoDiscoveryBatch<TEntity = unknown, TFilters extends GeoDiscoveryFilters = GeoDiscoveryFilters>({
  enabled = true,
  filters,
  pageSize = geoDiscoveryConfig.pagination.defaultPageSize,
  radiusKm = geoDiscoveryConfig.radius.defaultKm,
  serviceTypes = geoDiscoveryConfig.serviceTypes,
  sort = "distance"
}: UseGeoDiscoveryBatchParams<TFilters> = {}) {
  const locationState = useCurrentLocation(enabled);
  const location = useDebouncedLocation(locationState.location);
  const setBatchResult = useGeoDiscoveryStore((state) => state.setBatchResult);
  const [state, setState] = useState<BatchState<TEntity>>({
    error: null,
    isLoading: enabled,
    isRefreshing: false,
    result: null
  });
  const abortRef = useRef<AbortController | null>(null);

  const load = useCallback(async () => {
    if (!enabled || !location) {
      setState((current) => ({ ...current, isLoading: false, isRefreshing: false }));
      return;
    }

    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    setState((current) => ({
      ...current,
      error: null,
      isLoading: current.result === null,
      isRefreshing: current.result !== null
    }));

    try {
      const result = await geoDiscoveryEngine.getNearbyBatch<TEntity>(
        {
          filters,
          latitude: location.latitude,
          longitude: location.longitude,
          pageSize,
          radiusKm,
          serviceTypes,
          sort
        },
        controller.signal,
      );

      if (controller.signal.aborted) {
        return;
      }

      setBatchResult(result as GeoDiscoveryBatchResult);
      setState({
        error: null,
        isLoading: false,
        isRefreshing: false,
        result
      });
      geoTelemetry.event("geo_results_rendered", {
        emptyResult: Object.values(result.results).every((page) => !page || page.items.length === 0),
        queryFingerprint: result.queryFingerprint,
        serviceTypes: serviceTypes.join(","),
        source: result.source
      });
    } catch (error) {
      if (controller.signal.aborted) {
        return;
      }

      setState((current) => ({
        ...current,
        error: error instanceof Error ? error.message : "Unable to load nearby results.",
        isLoading: false,
        isRefreshing: false
      }));
    }
  }, [enabled, filters, location, pageSize, radiusKm, serviceTypes, setBatchResult, sort]);

  useEffect(() => {
    void load();

    return () => abortRef.current?.abort();
  }, [load]);

  return useMemo(
    () => ({
      center: location,
      error: state.error ?? locationState.error,
      isFallbackLocation: locationState.isFallback,
      isLoading: state.isLoading || locationState.isResolving,
      isRefreshing: state.isRefreshing,
      partialFailures: state.result?.partialFailures ?? [],
      permissionStatus: locationState.permissionStatus,
      refresh: load,
      refreshLocation: locationState.refreshLocation,
      result: state.result
    }),
    [load, location, locationState, state],
  );
}
