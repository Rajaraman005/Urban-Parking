import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import type {
  GeoDiscoveryBatchQuery,
  GeoDiscoveryFilters,
  GeoDiscoveryNormalizedQuery,
  GeoDiscoveryQuery,
  ServiceType
} from "@/types/geo";

const DEFAULT_REQUEST_PREFIX = "geo";

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

const stableStringify = (value: unknown): string => {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }

  return `{${Object.entries(value as Record<string, unknown>)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, entry]) => `${JSON.stringify(key)}:${stableStringify(entry)}`)
    .join(",")}}`;
};

export const roundedGeocell = (latitude: number, longitude: number) => {
  const lat = latitude.toFixed(3);
  const lon = longitude.toFixed(3);

  return `${lat},${lon}`;
};

const normalizeFilters = <TFilters extends GeoDiscoveryFilters>(
  serviceTypes: readonly ServiceType[],
  filters?: Partial<Record<ServiceType, TFilters>> | TFilters,
) => {
  if (!filters) {
    return {};
  }

  const maybeByService = filters as Partial<Record<ServiceType, TFilters>>;
  const hasServiceKeys = serviceTypes.some((serviceType) => maybeByService[serviceType]);

  if (hasServiceKeys) {
    return maybeByService;
  }

  return Object.fromEntries(serviceTypes.map((serviceType) => [serviceType, filters as TFilters]));
};

const buildFingerprint = (
  serviceTypes: readonly ServiceType[],
  geocell: string,
  radiusKm: number,
  sort: string,
  filters: unknown,
) =>
  [
    `v${geoDiscoveryConfig.api.schemaVersion}`,
    serviceTypes.join(","),
    geocell,
    radiusKm.toFixed(2),
    sort,
    stableStringify(filters)
  ].join("|");

export const normalizeGeoQuery = <TFilters extends GeoDiscoveryFilters>(
  query: GeoDiscoveryQuery<TFilters>,
): GeoDiscoveryNormalizedQuery<TFilters> =>
  normalizeGeoBatchQuery({
    ...query,
    cursors: query.cursor ? { [query.serviceType]: query.cursor } : undefined,
    filters: query.filters,
    serviceTypes: [query.serviceType]
  });

export const normalizeGeoBatchQuery = <TFilters extends GeoDiscoveryFilters>(
  query: GeoDiscoveryBatchQuery<TFilters>,
): GeoDiscoveryNormalizedQuery<TFilters> => {
  const serviceTypes = Array.from(new Set(query.serviceTypes));
  const radiusKm = clamp(
    query.radiusKm ?? geoDiscoveryConfig.radius.defaultKm,
    geoDiscoveryConfig.radius.minKm,
    geoDiscoveryConfig.radius.maxKm,
  );
  const pageSize = Math.round(
    clamp(
      query.pageSize ?? geoDiscoveryConfig.pagination.defaultPageSize,
      1,
      geoDiscoveryConfig.pagination.maxPageSize,
    ),
  );
  const sort = query.sort ?? "distance";
  const geocell = roundedGeocell(query.latitude, query.longitude);
  const filters = normalizeFilters(serviceTypes, query.filters);
  const queryFingerprint = buildFingerprint(serviceTypes, geocell, radiusKm, sort, filters);

  return {
    cursors: query.cursors ?? {},
    filters,
    latitude: query.latitude,
    longitude: query.longitude,
    pageSize,
    queryFingerprint,
    radiusKm,
    requestId: query.requestId ?? `${DEFAULT_REQUEST_PREFIX}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    roundedGeocell: geocell,
    schemaVersion: geoDiscoveryConfig.api.schemaVersion,
    serviceTypes,
    sort
  };
};
