import { createClient, type SupabaseClient } from "@supabase/supabase-js";

declare const process: {
  env: Record<string, string | undefined>;
};

type ServiceType = "parking" | "rental" | "service";
type AvailabilityStatus = "available" | "limited" | "unavailable" | "unknown";
type GeoSortKey = "distance" | "price" | "rating";

interface VercelRequestLike {
  body?: unknown;
  headers: Record<string, string | string[] | undefined>;
  method?: string;
}

interface VercelResponseLike {
  end: () => void;
  json: (body: unknown) => void;
  setHeader: (name: string, value: string) => void;
  status: (code: number) => VercelResponseLike;
}

interface GeoPoint {
  latitude: number;
  longitude: number;
}

interface GeoDiscoveryRequest extends GeoPoint {
  cursors?: Partial<Record<ServiceType, string>>;
  filters?: Record<string, unknown>;
  pageSize?: number;
  queryFingerprint?: string;
  radiusKm?: number;
  requestId?: string;
  schemaVersion?: number;
  serviceTypes?: ServiceType[];
  sort?: GeoSortKey;
}

interface ParkingSpaceRow {
  address: string | null;
  available_from_date: string | null;
  available_to_date: string | null;
  availability_summary: string | null;
  daily_end_minute: number | null;
  daily_start_minute: number | null;
  hourly_price: number | null;
  id: string;
  latitude: number | null;
  locality: string | null;
  longitude: number | null;
  parking_type: string | null;
  slots_count: number;
  title: string | null;
  vehicle_fit: string | null;
}

interface ParkingPhotoRow {
  parking_space_id: string;
  secure_url: string | null;
  sort_order: number | null;
  upload_status: string | null;
}

type ParkingSearchRow = ParkingSpaceRow & {
  image_urls?: string[] | null;
  parking_space_photos?: ParkingPhotoRow[];
};

interface GeoDiscoveryEntity {
  availabilityStatus: AvailabilityStatus;
  currency?: "INR";
  distanceKm: number;
  entity: Record<string, unknown>;
  id: string;
  imageUrl?: string;
  location: GeoPoint;
  price?: number;
  rating?: number;
  serviceType: ServiceType;
  title: string;
}

interface GeoDiscoveryPage {
  fetchedAt: string;
  isStale: boolean;
  items: GeoDiscoveryEntity[];
  nextCursor?: string;
  queryFingerprint: string;
  schemaVersion: number;
  source: "network";
}

const SCHEMA_VERSION = 1;
const DEFAULT_RADIUS_KM = 5;
const MIN_RADIUS_KM = 1;
const MAX_RADIUS_KM = 10;
const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 50;
const ALLOWED_SERVICE_TYPES = new Set<ServiceType>(["parking", "rental", "service"]);
const ALLOWED_SORTS = new Set<GeoSortKey>(["distance", "price", "rating"]);
const EARTH_RADIUS_KM = 6371.0088;
const FALLBACK_IMAGE_URL = "https://images.unsplash.com/photo-1506521781263-d8422e82f27a";

const corsOrigin = process.env.GEO_DISCOVERY_ALLOWED_ORIGIN ?? "*";

const toNumber = (value: unknown) => (typeof value === "number" && Number.isFinite(value) ? value : null);

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

const toRadians = (degrees: number) => (degrees * Math.PI) / 180;

const distanceKm = (from: GeoPoint, to: GeoPoint) => {
  const dLat = toRadians(to.latitude - from.latitude);
  const dLon = toRadians(to.longitude - from.longitude);
  const lat1 = toRadians(from.latitude);
  const lat2 = toRadians(to.latitude);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);

  return 2 * EARTH_RADIUS_KM * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

const roundedDistance = (value: number) => Math.round(value * 100) / 100;

const roundedGeocell = (latitude: number, longitude: number) => `${latitude.toFixed(3)},${longitude.toFixed(3)}`;

const stableStringify = (value: unknown): string => {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }

  return `{${Object.entries(value as Record<string, unknown>)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, entry]) => `${JSON.stringify(key)}:${stableStringify(entry)}`)
    .join(",")}}`;
};

const normalizeRequest = (body: unknown): Required<Omit<GeoDiscoveryRequest, "requestId">> & {
  requestId?: string;
} => {
  const payload = typeof body === "object" && body !== null ? (body as Record<string, unknown>) : {};
  const latitude = toNumber(payload.latitude);
  const longitude = toNumber(payload.longitude);

  if (latitude === null || longitude === null || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw Object.assign(new Error("Invalid latitude or longitude"), { status: 400, code: "invalid_location" });
  }

  const requestedServiceTypes = Array.isArray(payload.serviceTypes)
    ? payload.serviceTypes.filter((value): value is ServiceType => ALLOWED_SERVICE_TYPES.has(value as ServiceType))
    : ["parking" as ServiceType];
  const serviceTypes = Array.from(new Set(requestedServiceTypes));

  if (serviceTypes.length === 0) {
    throw Object.assign(new Error("At least one service type is required"), { status: 400, code: "invalid_service_type" });
  }

  const schemaVersion = toNumber(payload.schemaVersion) ?? SCHEMA_VERSION;

  if (schemaVersion !== SCHEMA_VERSION) {
    throw Object.assign(new Error("Unsupported schema version"), {
      code: "schema_version_unsupported",
      status: 426
    });
  }

  const radiusKm = clamp(toNumber(payload.radiusKm) ?? DEFAULT_RADIUS_KM, MIN_RADIUS_KM, MAX_RADIUS_KM);
  const pageSize = Math.round(clamp(toNumber(payload.pageSize) ?? DEFAULT_PAGE_SIZE, 1, MAX_PAGE_SIZE));
  const sort = ALLOWED_SORTS.has(payload.sort as GeoSortKey) ? (payload.sort as GeoSortKey) : "distance";
  const filters: Record<string, unknown> =
    typeof payload.filters === "object" && payload.filters !== null
      ? (payload.filters as Record<string, unknown>)
      : {};
  const cursors: Partial<Record<ServiceType, string>> =
    typeof payload.cursors === "object" && payload.cursors !== null
      ? (payload.cursors as Partial<Record<ServiceType, string>>)
      : {};
  const geocell = roundedGeocell(latitude, longitude);
  const queryFingerprint =
    typeof payload.queryFingerprint === "string"
      ? payload.queryFingerprint
      : [`v${SCHEMA_VERSION}`, serviceTypes.join(","), geocell, radiusKm.toFixed(2), sort, stableStringify(filters)].join(
          "|",
        );

  return {
    cursors,
    filters,
    latitude,
    longitude,
    pageSize,
    queryFingerprint,
    radiusKm,
    requestId: typeof payload.requestId === "string" ? payload.requestId : undefined,
    schemaVersion,
    serviceTypes,
    sort
  };
};

const cursorFor = (queryFingerprint: string, serviceType: ServiceType, offset: number) =>
  `${queryFingerprint}::${serviceType}::${offset}`;

const parseCursor = (cursor: string | undefined, queryFingerprint: string, serviceType: ServiceType) => {
  if (!cursor) {
    return 0;
  }

  const [cursorFingerprint, cursorServiceType, offsetText] = cursor.split("::");
  const offset = Number(offsetText);

  if (cursorFingerprint !== queryFingerprint || cursorServiceType !== serviceType || !Number.isInteger(offset)) {
    throw Object.assign(new Error("Cursor is invalid for the current query"), {
      code: "invalid_cursor",
      status: 409
    });
  }

  return offset;
};

const sortItems = (items: GeoDiscoveryEntity[], sort: GeoSortKey) =>
  [...items].sort((left, right) => {
    if (sort === "price") {
      return (left.price ?? Number.MAX_SAFE_INTEGER) - (right.price ?? Number.MAX_SAFE_INTEGER);
    }

    if (sort === "rating") {
      return (right.rating ?? 0) - (left.rating ?? 0);
    }

    return left.distanceKm - right.distanceKm;
  });

const activeAvailability = (slotsCount: number): AvailabilityStatus => {
  if (slotsCount <= 0) {
    return "unavailable";
  }

  return slotsCount <= 2 ? "limited" : "available";
};

const datePart = (value: string | null, fallbackOffsetDays: number) => {
  if (value) return value;
  const date = new Date();
  date.setDate(date.getDate() + fallbackOffsetDays);
  return date.toISOString().slice(0, 10);
};

const isoAtMinute = (date: string, minute: number | null, fallbackMinute: number) => {
  const safeMinute = typeof minute === "number" && Number.isInteger(minute) ? minute : fallbackMinute;
  const hours = Math.floor(safeMinute / 60)
    .toString()
    .padStart(2, "0");
  const minutes = (safeMinute % 60).toString().padStart(2, "0");
  return `${date}T${hours}:${minutes}:00.000+05:30`;
};

const amenitiesFor = (row: ParkingSpaceRow) => {
  const amenities = new Set<string>();

  if (row.parking_type === "covered" || row.parking_type === "garage" || row.parking_type === "basement") {
    amenities.add("covered");
  }
  if (row.vehicle_fit === "bike") {
    amenities.add("twoWheeler");
  }

  if (amenities.size === 0) {
    amenities.add("covered");
  }

  return Array.from(amenities);
};

const photoUrlsFor = (photos: ParkingPhotoRow[] | undefined) => {
  const urls = new Set<string>();

  for (const photo of [...(photos ?? [])].sort((left, right) => {
    const leftOrder = typeof left.sort_order === "number" ? left.sort_order : Number.MAX_SAFE_INTEGER;
    const rightOrder = typeof right.sort_order === "number" ? right.sort_order : Number.MAX_SAFE_INTEGER;
    return leftOrder - rightOrder;
  })) {
    if (photo.upload_status && photo.upload_status !== "linked") continue;
    const url = photo.secure_url?.trim();
    if (url) urls.add(url);
  }

  return Array.from(urls);
};

const imageUrlsFor = (row: ParkingSearchRow) => {
  if (Array.isArray(row.image_urls)) {
    const urls = row.image_urls.map((url) => url?.trim()).filter((url): url is string => Boolean(url));
    return Array.from(new Set(urls));
  }

  return photoUrlsFor(row.parking_space_photos);
};

const supportedVehicleTypesFor = (vehicleFit: string | null) => {
  switch (vehicleFit) {
    case "bike":
      return ["bike"];
    case "both":
      return ["bike", "car"];
    case "car":
    default:
      return ["car"];
  }
};

const parkingSelectCandidates = [
  [
    "id",
    "title",
    "address",
    "locality",
    "latitude",
    "longitude",
    "slots_count",
    "hourly_price",
    "availability_summary",
    "parking_type",
    "vehicle_fit",
    "available_from_date",
    "available_to_date",
    "daily_start_minute",
    "daily_end_minute",
    "parking_space_photos(parking_space_id,secure_url,sort_order,upload_status)",
  ].join(","),
  [
    "id",
    "title",
    "address",
    "locality",
    "latitude",
    "longitude",
    "slots_count",
    "hourly_price",
    "availability_summary",
    "parking_type",
    "vehicle_fit",
    "parking_space_photos(parking_space_id,secure_url,sort_order,upload_status)",
  ].join(","),
  [
    "id",
    "title",
    "address",
    "locality",
    "latitude",
    "longitude",
    "slots_count",
    "hourly_price",
    "availability_summary",
    "parking_type",
    "vehicle_fit",
    "available_from_date",
    "available_to_date",
    "daily_start_minute",
    "daily_end_minute",
  ].join(","),
  [
    "id",
    "title",
    "address",
    "locality",
    "latitude",
    "longitude",
    "slots_count",
    "hourly_price",
    "availability_summary",
    "parking_type",
    "vehicle_fit",
  ].join(","),
] as const;

const looksLikeSchemaMismatch = (message: string) => {
  const normalized = message.toLowerCase();
  return (
    normalized.includes("column") ||
    normalized.includes("relationship") ||
    normalized.includes("schema cache") ||
    normalized.includes("could not find") ||
    normalized.includes("does not exist")
  );
};

const shouldAttemptTableFallback = (error: unknown) => {
  if (!(error instanceof Error)) {
    return false;
  }

  const normalized = error.message.toLowerCase();
  return (
    looksLikeSchemaMismatch(error.message) ||
    normalized.includes("function") ||
    normalized.includes("permission denied") ||
    normalized.includes("rpc")
  );
};

const databaseError = (message: string) =>
  Object.assign(new Error(message), {
    code: "database_error",
    status: 500,
  });

const serverConfigError = (message: string) =>
  Object.assign(new Error(message), {
    code: "server_config_error",
    status: 500,
  });

const queryParkingRows = async (
  client: SupabaseClient,
  query: ReturnType<typeof normalizeRequest>,
  selectClause: string,
) =>
  client
    .from("parking_spaces")
    .select(selectClause)
    .eq("status", "active")
    .not("latitude", "is", null)
    .not("longitude", "is", null)
    .gte("latitude", query.latitude - query.radiusKm / 111)
    .lte("latitude", query.latitude + query.radiusKm / 111)
    .gte(
      "longitude",
      query.longitude -
        query.radiusKm / (111 * Math.max(Math.cos(toRadians(query.latitude)), 0.2)),
    )
    .lte(
      "longitude",
      query.longitude +
        query.radiusKm / (111 * Math.max(Math.cos(toRadians(query.latitude)), 0.2)),
    )
    .limit(250);

const loadCompatibleParkingRows = async (
  client: SupabaseClient,
  query: ReturnType<typeof normalizeRequest>,
) => {
  let lastError: { message: string } | null = null;

  for (const selectClause of parkingSelectCandidates) {
    const { data, error } = await queryParkingRows(client, query, selectClause);
    if (!error) {
      return (data ?? []) as unknown as ParkingSearchRow[];
    }

    lastError = error;
    if (!looksLikeSchemaMismatch(error.message)) {
      break;
    }
  }

  throw databaseError(lastError?.message ?? "Parking discovery query failed");
};

const responseError = (response: VercelResponseLike, error: unknown) => {
  const status =
    typeof error === "object" && error !== null && "status" in error && typeof error.status === "number"
      ? error.status
      : 500;
  const code =
    typeof error === "object" && error !== null && "code" in error && typeof error.code === "string"
      ? error.code
      : "geo_discovery_error";
  const message = error instanceof Error ? error.message : "Geo discovery failed";

  response.status(status).json({
    code,
    message,
    status
  });
};

const setCorsHeaders = (response: VercelResponseLike) => {
  response.setHeader("Access-Control-Allow-Origin", corsOrigin);
  response.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.setHeader("Cache-Control", "private, max-age=0, must-revalidate");
  response.setHeader("Vary", "Origin");
};

const supabaseUrl = () => {
  const url = process.env.SUPABASE_URL;
  if (!url) {
    throw serverConfigError("Missing Supabase URL server environment variable");
  }
  return url;
};

const createServerSupabaseClient = (key: string) =>
  createClient(supabaseUrl(), key, {
    auth: {
      persistSession: false
    }
  });

const supabaseForRpc = () => {
  const key =
    process.env.SUPABASE_SERVICE_ROLE_KEY ??
    process.env.SUPABASE_ANON_KEY;

  if (!key) {
    throw serverConfigError("Missing Supabase RPC environment variable");
  }

  return createServerSupabaseClient(key);
};

const supabaseForTableFallback = () => {
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!serviceKey) {
    throw serverConfigError("Missing SUPABASE_SERVICE_ROLE_KEY for direct table fallback");
  }

  return createServerSupabaseClient(serviceKey);
};

const loadParkingRowsFromRpc = async (
  client: SupabaseClient,
  query: ReturnType<typeof normalizeRequest>,
) => {
  const { data, error } = await client.rpc("search_public_parking_spots", {
    p_latitude: query.latitude,
    p_limit: 250,
    p_longitude: query.longitude,
    p_offset: 0,
    p_radius_km: query.radiusKm,
  });

  if (error) {
    throw databaseError(`search_public_parking_spots failed: ${error.message}`);
  }

  return (data ?? []) as unknown as ParkingSearchRow[];
};

const loadParkingRows = async (query: ReturnType<typeof normalizeRequest>) => {
  try {
    return await loadParkingRowsFromRpc(supabaseForRpc(), query);
  } catch (rpcError) {
    if (!shouldAttemptTableFallback(rpcError)) {
      throw rpcError;
    }

    try {
      return await loadCompatibleParkingRows(supabaseForTableFallback(), query);
    } catch (fallbackError) {
      if (
        typeof fallbackError === "object" &&
        fallbackError !== null &&
        "code" in fallbackError &&
        fallbackError.code === "server_config_error"
      ) {
        throw rpcError;
      }

      throw fallbackError;
    }
  }
};

const loadParking = async (query: ReturnType<typeof normalizeRequest>): Promise<GeoDiscoveryPage> => {
  const center = { latitude: query.latitude, longitude: query.longitude };
  const parkingRows = await loadParkingRows(query);

  const entities = parkingRows
    .flatMap((row) => {
      if (row.latitude === null || row.longitude === null) {
        return [];
      }

      const location = { latitude: Number(row.latitude), longitude: Number(row.longitude) };
      const itemDistanceKm = roundedDistance(distanceKm(center, location));

      if (itemDistanceKm > query.radiusKm) {
        return [];
      }

      const imageUrls = imageUrlsFor(row);
      const imageUrl = imageUrls[0] ?? FALLBACK_IMAGE_URL;
      const startDate = datePart(row.available_from_date, 0);
      const endDate = datePart(row.available_to_date, 1);

      return [
        {
          availabilityStatus: activeAvailability(row.slots_count),
          currency: "INR",
          distanceKm: itemDistanceKm,
          entity: {
            address: row.address,
            amenities: amenitiesFor(row),
            availabilitySummary: row.availability_summary,
            availableFrom: isoAtMinute(startDate, row.daily_start_minute, 8 * 60),
            availableUntil: isoAtMinute(endDate, row.daily_end_minute, 20 * 60),
            cadence: "hourly",
            currency: "INR",
            distanceKm: itemDistanceKm,
            hourlyPrice: row.hourly_price,
            id: row.id,
            imageUrl,
            imageUrls: imageUrls.length > 0 ? imageUrls : [imageUrl],
            locality: row.locality,
            location,
            price: row.hourly_price,
            rating: 0,
            reviewCount: 0,
            slotsAvailable: row.slots_count,
            title: row.title,
            supportedVehicleTypes: supportedVehicleTypesFor(row.vehicle_fit),
            vehicleFit: row.vehicle_fit,
            vehicle_fit: row.vehicle_fit
          },
          id: row.id,
          imageUrl,
          location,
          price: row.hourly_price ?? undefined,
          rating: undefined,
          serviceType: "parking",
          title: row.title ?? "Parking space"
        } satisfies GeoDiscoveryEntity
      ];
    });
  const sorted = sortItems(entities, query.sort);
  const offset = parseCursor(query.cursors.parking, query.queryFingerprint, "parking");
  const pageItems = sorted.slice(offset, offset + query.pageSize);
  const nextOffset = offset + query.pageSize;

  return {
    fetchedAt: new Date().toISOString(),
    isStale: false,
    items: pageItems,
    nextCursor: nextOffset < sorted.length ? cursorFor(query.queryFingerprint, "parking", nextOffset) : undefined,
    queryFingerprint: query.queryFingerprint,
    schemaVersion: SCHEMA_VERSION,
    source: "network"
  };
};

const emptyPage = (query: ReturnType<typeof normalizeRequest>, _serviceType: ServiceType): GeoDiscoveryPage => ({
  fetchedAt: new Date().toISOString(),
  isStale: false,
  items: [],
  nextCursor: undefined,
  queryFingerprint: query.queryFingerprint,
  schemaVersion: SCHEMA_VERSION,
  source: "network"
});

export default async function handler(request: VercelRequestLike, response: VercelResponseLike) {
  setCorsHeaders(response);

  if (request.method === "OPTIONS") {
    response.status(204).end();
    return;
  }

  if (request.method !== "POST") {
    response.status(405).json({ code: "method_not_allowed", message: "Use POST", status: 405 });
    return;
  }

  try {
    const query = normalizeRequest(request.body);
    const fetchedAt = new Date().toISOString();
    const results: Partial<Record<ServiceType, GeoDiscoveryPage>> = {};

    for (const serviceType of query.serviceTypes) {
      results[serviceType] = serviceType === "parking" ? await loadParking(query) : emptyPage(query, serviceType);
    }

    response.status(200).json({
      fetchedAt,
      partialFailures: [],
      queryFingerprint: query.queryFingerprint,
      results,
      schemaVersion: SCHEMA_VERSION,
      source: "network"
    });
  } catch (error) {
    responseError(response, error);
  }
}
