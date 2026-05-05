import { createClient } from "@supabase/supabase-js";

declare const process: {
  env: Record<string, string | undefined>;
};

interface VercelRequestLike {
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
  available_from_date: string | null;
  available_to_date: string | null;
  availability_summary: string | null;
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
  slots_count: number;
  title: string | null;
  vehicle_fit: string | null;
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

const supabase = () => {
  const url = process.env.SUPABASE_URL ?? process.env.EXPO_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !serviceKey) {
    throw Object.assign(new Error("Missing Supabase server environment variables"), {
      code: "server_config_error",
      status: 500
    });
  }

  return createClient(url, serviceKey, {
    auth: {
      persistSession: false
    }
  });
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

  return [...amenities];
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

  return [...urls];
};

const toParkingSpot = (row: ParkingSpaceRow, profile?: ProfileRow | null) => {
  const startDate = datePart(row.available_from_date, 0);
  const endDate = datePart(row.available_to_date, 1);
  const imageUrls = photoUrlsFor(row.parking_space_photos);
  const imageUrl = imageUrls[0] ?? fallbackImageUrl;

  return {
    address: row.address ?? "",
    amenities: amenitiesFor(row),
    availabilitySummary: row.availability_summary ?? undefined,
    availableFrom: isoAtMinute(startDate, row.daily_start_minute, 8 * 60),
    availableUntil: isoAtMinute(endDate, row.daily_end_minute, 20 * 60),
    cadence: "hourly",
    currency: "INR",
    distanceKm: 0,
    hostAvatarUrl: profile?.avatar_url?.trim() || undefined,
    hostName: profile?.full_name?.trim() || undefined,
    hostPhone: profile?.phone?.trim() || undefined,
    hostRole: profile?.role?.trim() || "host",
    id: row.id,
    imageUrl,
    imageUrls: imageUrls.length > 0 ? imageUrls : [imageUrl],
    locality: row.locality ?? "",
    location: {
      latitude: Number(row.latitude ?? 13.0827),
      longitude: Number(row.longitude ?? 80.2707)
    },
    price: row.hourly_price ?? 0,
    rating: 0,
    reviewCount: 0,
    slotsAvailable: row.slots_count,
    title: row.title ?? "Parking space"
  };
};

const loadHostProfile = async (
  client: ReturnType<typeof supabase>,
  hostId: string,
) => {
  const { data, error } = await client
    .from("profiles")
    .select("full_name,avatar_url,phone,role")
    .eq("id", hostId)
    .maybeSingle();

  if (error) {
    throw Object.assign(new Error(error.message), {
      code: "database_error",
      status: 500
    });
  }

  return data as ProfileRow | null;
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

    const client = supabase();
    const { data, error } = await client
      .from("parking_spaces")
      .select(
        [
          "id",
          "host_id",
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
          "parking_space_photos(secure_url,sort_order,upload_status)"
        ].join(",")
      )
      .eq("id", id)
      .eq("status", "active")
      .maybeSingle();

    if (error) {
      throw Object.assign(new Error(error.message), { code: "database_error", status: 500 });
    }

    if (!data) {
      throw Object.assign(new Error("Parking spot was not found"), {
        code: "parking_spot_not_found",
        status: 404
      });
    }

    const parkingRow = data as unknown as ParkingSpaceRow;
    const profile = await loadHostProfile(client, parkingRow.host_id);

    response.status(200).json(toParkingSpot(parkingRow, profile));
  } catch (error) {
    responseError(response, error);
  }
}
