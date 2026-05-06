import { createClient, type SupabaseClient } from "@supabase/supabase-js";

declare const process: {
  env: Record<string, string | undefined>;
};

interface VercelRequestLike {
  headers?: Record<string, string | string[] | undefined>;
  method?: string;
  query?: Record<string, string | string[] | undefined>;
}

interface VercelResponseLike {
  end: () => void;
  json: (body: unknown) => void;
  setHeader: (name: string, value: string) => void;
  status: (code: number) => VercelResponseLike;
}

interface ParkingPhotoRow {
  secure_url: string | null;
  sort_order: number | null;
  upload_status: string | null;
}

interface ParkingSpaceRow {
  address: string | null;
  address_confidence: number | null;
  address_place_id: string | null;
  address_provider: string | null;
  available_from_date: string | null;
  available_to_date: string | null;
  availability_summary: string | null;
  city: string | null;
  daily_end_minute: number | null;
  daily_start_minute: number | null;
  host_id: string;
  hourly_price: number | null;
  id: string;
  latitude: number | null;
  locality: string | null;
  longitude: number | null;
  parking_space_photos?: ParkingPhotoRow[];
  parking_type: string | null;
  postal_code: string | null;
  slots_count: number;
  title: string | null;
  updated_at: string | null;
  vehicle_fit: string | null;
  version: number | null;
}

interface ProfileRow {
  avatar_url: string | null;
  full_name: string | null;
  phone: string | null;
  role: string | null;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const corsOrigin = process.env.GEO_DISCOVERY_ALLOWED_ORIGIN ?? "*";
const fallbackImageUrl = "https://images.unsplash.com/photo-1506521781263-d8422e82f27a";

const setCorsHeaders = (response: VercelResponseLike) => {
  response.setHeader("Access-Control-Allow-Origin", corsOrigin);
  response.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  response.setHeader("Cache-Control", "private, max-age=30, stale-while-revalidate=120");
  response.setHeader("Vary", "Origin");
};

const responseError = (response: VercelResponseLike, error: unknown) => {
  const status =
    typeof error === "object" && error !== null && "status" in error && typeof error.status === "number"
      ? error.status
      : 500;
  const code =
    typeof error === "object" && error !== null && "code" in error && typeof error.code === "string"
      ? error.code
      : "parking_spot_error";
  const message = error instanceof Error ? error.message : "Parking spot lookup failed";

  response.status(status).json({ code, message, status });
};

const databaseError = (message: string) =>
  Object.assign(new Error(message), {
    code: "database_error",
    status: 500
  });

const serverConfigError = (message: string) =>
  Object.assign(new Error(message), {
    code: "server_config_error",
    status: 500
  });

const notFoundError = () =>
  Object.assign(new Error("Parking spot was not found"), {
    code: "parking_spot_not_found",
    status: 404
  });

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

const supabaseUrl = () => {
  const url = process.env.SUPABASE_URL;
  if (!url) {
    throw serverConfigError("Missing Supabase URL server environment variable");
  }
  return url;
};

const createServerSupabaseClient = (key: string, accessToken?: string) =>
  createClient(supabaseUrl(), key, {
    auth: {
      persistSession: false
    },
    global: accessToken
      ? {
          headers: {
            Authorization: `Bearer ${accessToken}`
          }
        }
      : undefined
  });

const bearerTokenFor = (request: VercelRequestLike) => {
  const header = request.headers?.authorization ?? request.headers?.Authorization;
  const value = Array.isArray(header) ? header[0] : header;
  const match = value?.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
};

const supabaseForRpc = (request: VercelRequestLike) => {
  const accessToken = bearerTokenFor(request);
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (accessToken && anonKey) {
    return createServerSupabaseClient(anonKey, accessToken);
  }

  const key =
    process.env.SUPABASE_SERVICE_ROLE_KEY ??
    anonKey;

  if (!key) {
    throw serverConfigError("Missing Supabase RPC environment variable");
  }

  return createServerSupabaseClient(key);
};

const authenticatedUserIdFor = async (request: VercelRequestLike) => {
  const accessToken = bearerTokenFor(request);
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!accessToken || !anonKey) {
    return null;
  }

  const { data, error } = await createServerSupabaseClient(anonKey).auth.getUser(accessToken);
  if (error || !data.user) {
    return null;
  }
  return data.user.id;
};

const supabaseForTableFallback = () => {
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!serviceKey) {
    throw serverConfigError("Missing SUPABASE_SERVICE_ROLE_KEY for direct table fallback");
  }

  return createServerSupabaseClient(serviceKey);
};

const resolveId = (request: VercelRequestLike) => {
  const id = request.query?.id;
  return Array.isArray(id) ? id[0] : id;
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

const toParkingSpot = (row: ParkingSpaceRow, profile?: ProfileRow | null, currentUserId?: string | null) => {
  const startDate = datePart(row.available_from_date, 0);
  const endDate = datePart(row.available_to_date, 1);
  const imageUrls = photoUrlsFor(row.parking_space_photos);
  const imageUrl = imageUrls[0] ?? fallbackImageUrl;

  return {
    address: row.address ?? "",
    addressConfidence: row.address_confidence ?? undefined,
    addressPlaceId: row.address_place_id?.trim() || undefined,
    addressProvider: row.address_provider?.trim() || undefined,
    amenities: amenitiesFor(row),
    availabilitySummary: row.availability_summary ?? undefined,
    availableFrom: isoAtMinute(startDate, row.daily_start_minute, 8 * 60),
    availableUntil: isoAtMinute(endDate, row.daily_end_minute, 20 * 60),
    cadence: "hourly",
    city: row.city?.trim() || undefined,
    currency: "INR",
    distanceKm: 0,
    hostAvatarUrl: profile?.avatar_url?.trim() || undefined,
    hostName: profile?.full_name?.trim() || undefined,
    hostPhone: profile?.phone?.trim() || undefined,
    hostRole: profile?.role?.trim() || "host",
    id: row.id,
    imageUrl,
    imageUrls: imageUrls.length > 0 ? imageUrls : [imageUrl],
    isHostedByCurrentUser: currentUserId === row.host_id,
    locality: row.locality ?? "",
    location: {
      latitude: Number(row.latitude ?? 13.0827),
      longitude: Number(row.longitude ?? 80.2707)
    },
    price: row.hourly_price ?? 0,
    postalCode: row.postal_code?.trim() || undefined,
    rating: 0,
    reviewCount: 0,
    slotsAvailable: row.slots_count,
    title: row.title ?? "Parking space",
    updatedAt: row.updated_at ?? undefined,
    version: row.version ?? 1
  };
};

const loadHostProfile = async (
  client: SupabaseClient,
  hostId: string,
) => {
  const { data, error } = await client
    .from("profiles")
    .select("full_name,avatar_url,phone,role")
    .eq("id", hostId)
    .maybeSingle();

  if (error) {
    throw databaseError(error.message);
  }

  return data as ProfileRow | null;
};

const parkingDetailSelectCandidates = [
  [
    "id",
    "host_id",
    "title",
    "address",
    "address_confidence",
    "address_place_id",
    "address_provider",
    "city",
    "locality",
    "latitude",
    "longitude",
    "slots_count",
    "hourly_price",
    "availability_summary",
    "parking_type",
    "postal_code",
    "updated_at",
    "vehicle_fit",
    "version",
    "available_from_date",
    "available_to_date",
    "daily_start_minute",
    "daily_end_minute",
    "parking_space_photos(secure_url,sort_order,upload_status)"
  ].join(","),
  [
    "id",
    "host_id",
    "title",
    "address",
    "city",
    "locality",
    "latitude",
    "longitude",
    "slots_count",
    "hourly_price",
    "availability_summary",
    "parking_type",
    "postal_code",
    "updated_at",
    "vehicle_fit",
    "version",
    "parking_space_photos(secure_url,sort_order,upload_status)"
  ].join(","),
  [
    "id",
    "host_id",
    "title",
    "address",
    "address_confidence",
    "address_place_id",
    "address_provider",
    "city",
    "locality",
    "latitude",
    "longitude",
    "slots_count",
    "hourly_price",
    "availability_summary",
    "parking_type",
    "postal_code",
    "updated_at",
    "vehicle_fit",
    "version",
    "available_from_date",
    "available_to_date",
    "daily_start_minute",
    "daily_end_minute"
  ].join(","),
  [
    "id",
    "host_id",
    "title",
    "address",
    "city",
    "locality",
    "latitude",
    "longitude",
    "slots_count",
    "hourly_price",
    "availability_summary",
    "parking_type",
    "postal_code",
    "updated_at",
    "vehicle_fit"
  ].join(",")
] as const;

const loadSpotFromRpc = async (client: SupabaseClient, id: string) => {
  const { data, error } = await client.rpc("get_public_parking_spot", {
    p_space_id: id
  });

  if (error) {
    throw databaseError(`get_public_parking_spot failed: ${error.message}`);
  }

  if (!data) {
    throw notFoundError();
  }

  return data as Record<string, unknown>;
};

const queryParkingSpot = async (
  client: SupabaseClient,
  id: string,
  selectClause: string
) =>
  client
    .from("parking_spaces")
    .select(selectClause)
    .eq("id", id)
    .eq("status", "active")
    .maybeSingle();

const loadCompatibleParkingSpot = async (client: SupabaseClient, id: string) => {
  let lastError: { message: string } | null = null;

  for (const selectClause of parkingDetailSelectCandidates) {
    const { data, error } = await queryParkingSpot(client, id, selectClause);
    if (!error) {
      return (data ?? null) as unknown as ParkingSpaceRow | null;
    }

    lastError = error;
    if (!looksLikeSchemaMismatch(error.message)) {
      break;
    }
  }

  throw databaseError(lastError?.message ?? "Parking spot lookup query failed");
};

const loadSpotWithTableFallback = async (id: string, currentUserId?: string | null) => {
  const client = supabaseForTableFallback();
  const parkingRow = await loadCompatibleParkingSpot(client, id);

  if (!parkingRow) {
    throw notFoundError();
  }

  const profile = await loadHostProfile(client, parkingRow.host_id);
  return toParkingSpot(parkingRow, profile, currentUserId);
};

const loadPublicParkingSpot = async (id: string, request: VercelRequestLike) => {
  try {
    return await loadSpotFromRpc(supabaseForRpc(request), id);
  } catch (rpcError) {
    if (!shouldAttemptTableFallback(rpcError)) {
      throw rpcError;
    }

    try {
      return await loadSpotWithTableFallback(
        id,
        await authenticatedUserIdFor(request)
      );
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

export default async function handler(request: VercelRequestLike, response: VercelResponseLike) {
  setCorsHeaders(response);

  if (request.method === "OPTIONS") {
    response.status(204).end();
    return;
  }

  if (request.method !== "GET") {
    response.status(405).json({ code: "method_not_allowed", message: "Use GET", status: 405 });
    return;
  }

  try {
    const id = resolveId(request);

    if (!id || !UUID_PATTERN.test(id)) {
      throw Object.assign(new Error("Parking spot id is invalid"), {
        code: "invalid_parking_spot_id",
        status: 400
      });
    }

    response.status(200).json(await loadPublicParkingSpot(id, request));
  } catch (error) {
    responseError(response, error);
  }
}
