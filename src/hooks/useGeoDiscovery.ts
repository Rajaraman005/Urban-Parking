import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { geoDiscoveryEngine } from "@/services/geo";
import { useGeoDiscoveryStore } from "@/store/geoDiscoveryStore";
import { useCurrentLocation } from "@/hooks/useCurrentLocation";
import { useDebouncedLocation } from "@/hooks/useDebouncedLocation";
import type {
  GeoDiscoveryEntity,
  GeoDiscoveryFilters,
  GeoDiscoveryPage,
  GeoSortKey,
  ServiceType
} from "@/types/geo";
import { geoTelemetry } from "@/utils/telemetry/geoTelemetry";

interface UseGeoDiscoveryParams<TFilters extends GeoDiscoveryFilters = GeoDiscoveryFilters> {
  enabled?: boolean;
  filters?: TFilters;
  pageSize?: number;
  radiusKm?: number;
  serviceType: ServiceType;
  sort?: GeoSortKey;
}

interface GeoDiscoveryHookState<TEntity> {
  error: string | null;
  isLoading: boolean;
  isPaginating: boolean;
  isRefreshing: boolean;
  lastMessage: string | null;
  page: GeoDiscoveryPage<TEntity> | null;
}

const queryIdentityFor = (params: {
  filters?: GeoDiscoveryFilters;
  latitude?: number;
  longitude?: number;
  radiusKm: number;
  serviceType: ServiceType;
  sort: GeoSortKey;
}) =>
  [
    params.serviceType,
    params.latitude?.toFixed(3) ?? "no-lat",
    params.longitude?.toFixed(3) ?? "no-lon",
    params.radiusKm,
    params.sort,
    JSON.stringify(params.filters ?? {})
  ].join("|");

export function useGeoDiscovery<TEntity = unknown, TFilters extends GeoDiscoveryFilters = GeoDiscoveryFilters>({
  enabled = true,
  filters,
  pageSize = geoDiscoveryConfig.pagination.defaultPageSize,
  radiusKm = geoDiscoveryConfig.radius.defaultKm,
  serviceType,
  sort = "distance"
}: UseGeoDiscoveryParams<TFilters>) {
  const locationState = useCurrentLocation(enabled);
  const location = useDebouncedLocation(locationState.location);
  const setBatchResult = useGeoDiscoveryStore((state) => state.setBatchResult);
  const [items, setItems] = useState<GeoDiscoveryEntity<TEntity>[]>([]);
  const [state, setState] = useState<GeoDiscoveryHookState<TEntity>>({
    error: null,
    isLoading: enabled,
    isPaginating: false,
    isRefreshing: false,
    lastMessage: null,
    page: null
  });
  const abortRef = useRef<AbortController | null>(null);
  const pageRef = useRef<GeoDiscoveryPage<TEntity> | null>(null);
  const queryIdentityRef = useRef<string | null>(null);

  const queryIdentity = useMemo(
    () =>
      queryIdentityFor({
        filters,
        latitude: location?.latitude,
        longitude: location?.longitude,
        radiusKm,
        serviceType,
        sort
      }),
    [filters, location?.latitude, location?.longitude, radiusKm, serviceType, sort],
  );

  const load = useCallback(
    async (mode: "append" | "refresh" = "refresh") => {
      if (!enabled || !location) {
        setState((current) => ({ ...current, isLoading: false, isRefreshing: false }));
        return;
      }

      const identityChanged = queryIdentityRef.current !== null && queryIdentityRef.current !== queryIdentity;

      if (identityChanged) {
        setItems([]);
      }

      queryIdentityRef.current = queryIdentity;
      abortRef.current?.abort();
      const controller = new AbortController();
      abortRef.current = controller;

      setState((current) => ({
        ...current,
        error: null,
        isLoading: current.page === null && mode !== "append",
        isPaginating: mode === "append",
        isRefreshing: mode === "refresh" && current.page !== null,
        lastMessage: identityChanged ? "Updated for your new location." : current.lastMessage
      }));

      try {
        const page = await geoDiscoveryEngine.getNearby<TEntity>(
          {
            cursor: mode === "append" ? pageRef.current?.nextCursor : undefined,
            filters,
            latitude: location.latitude,
            longitude: location.longitude,
            pageSize,
            radiusKm,
            serviceType,
            sort
          },
          controller.signal,
        );

        if (controller.signal.aborted) {
          return;
        }

        setItems((current) =>
          mode === "append" && !page.cursorInvalidated ? [...current, ...page.items] : page.items,
        );
        pageRef.current = page;
        setState({
          error: null,
          isLoading: false,
          isPaginating: false,
          isRefreshing: false,
          lastMessage: page.cursorInvalidated ? "Updated for your new location." : null,
          page
        });
        setBatchResult({
          fetchedAt: page.fetchedAt,
          partialFailures: [],
          queryFingerprint: page.queryFingerprint,
          results: { [serviceType]: page },
          schemaVersion: page.schemaVersion,
          source: page.source
        });
        geoTelemetry.event("geo_results_rendered", {
          emptyResult: page.items.length === 0,
          isStale: page.isStale,
          queryFingerprint: page.queryFingerprint,
          serviceType,
          source: page.source
        });
      } catch (error) {
        if (controller.signal.aborted) {
          return;
        }

        setState((current) => ({
          ...current,
          error: error instanceof Error ? error.message : "Unable to load nearby results.",
          isLoading: false,
          isPaginating: false,
          isRefreshing: false
        }));
      }
    },
    [enabled, filters, location, pageSize, queryIdentity, radiusKm, serviceType, setBatchResult, sort],
  );

  useEffect(() => {
    void load("refresh");

    return () => abortRef.current?.abort();
  }, [load]);

  const loadMore = useCallback(async () => {
    if (!state.page?.nextCursor || state.isPaginating) {
      return;
    }

    await load("append");
  }, [load, state.isPaginating, state.page?.nextCursor]);

  return useMemo(
    () => ({
      center: location,
      error: state.error ?? locationState.error,
      hasMore: Boolean(state.page?.nextCursor),
      isFallbackLocation: locationState.isFallback,
      isLoading: state.isLoading || locationState.isResolving,
      isPaginating: state.isPaginating,
      isRefreshing: state.isRefreshing,
      items,
      lastMessage: state.lastMessage,
      page: state.page,
      permissionStatus: locationState.permissionStatus,
      refresh: () => load("refresh"),
      refreshLocation: locationState.refreshLocation,
      loadMore
    }),
    [items, load, loadMore, location, locationState, state],
  );
}
