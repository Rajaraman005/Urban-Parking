import "server-only";

import { z } from "zod";
import {
  apiError,
  jsonResponse,
  readJsonBody,
  sha256Hex,
  supabaseError,
  type MobileApiContext,
} from "./core";
import { timedSupabase, withAbortSignal } from "./supabase";

type ServiceType = "parking" | "rental" | "service";
type AvailabilityStatus = "available" | "limited" | "unavailable" | "unknown";
type GeoSortKey = "distance" | "price" | "rating";

type GeoPoint = {
  latitude: number;
  longitude: number;
};

type ParkingSpaceRow = {
  address: string | null;
  available_from_date: string | null;
  available_to_date: string | null;
  availability_summary: string | null;
  daily_end_minute: number | null;
  daily_start_minute: number | null;
  hourly_price: number | null;
  id: string;
  image_urls?: string[] | null;
  latitude: number | null;
  locality: string | null;
  longitude: number | null;
  parking_type: string | null;
  skip_weekends?: boolean | null;
  slots_count: number;
  title: string | null;
  vehicle_fit: string | null;
};

type GeoDiscoveryEntity = {
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
};

type GeoDiscoveryPage = {
  fetchedAt: string;
  isStale: boolean;
  items: GeoDiscoveryEntity[];
  nextCursor?: string;
  queryFingerprint: string;
  schemaVersion: number;
  source: "network";
};

const schemaVersion = 1;
const fallbackImageUrl =
  "https://images.unsplash.com/photo-1506521781263-d8422e82f27a";
const earthRadiusKm = 6371.0088;

const serviceTypeSchema = z.enum(["parking", "rental", "service"]);
const sortSchema = z.enum(["distance", "price", "rating"]);

const geoSearchSchema = z
  .object({
    cursors: z.record(z.string(), z.string()).optional().default({}),
    filters: z.record(z.string(), z.unknown()).optional().default({}),
    latitude: z.number().finite().min(-90).max(90),
    longitude: z.number().finite().min(-180).max(180),
    pageSize: z.number().int().min(1).max(50).optional().default(20),
    queryFingerprint: z.string().trim().min(1).optional(),
    radiusKm: z.number().finite().min(1).max(10).optional().default(5),
    requestId: z.string().trim().optional(),
    schemaVersion: z.literal(schemaVersion).optional().default(schemaVersion),
    serviceTypes: z
      .array(serviceTypeSchema)
      .min(1)
      .optional()
      .default(["parking"]),
    sort: sortSchema.optional().default("distance"),
  })
  .transform((value) => {
    const serviceTypes = Array.from(new Set(value.serviceTypes));
    const geocell = roundedGeocell(value.latitude, value.longitude);
    const queryFingerprint =
      value.queryFingerprint ??
      [
        `v${schemaVersion}`,
        serviceTypes.join(","),
        geocell,
        value.radiusKm.toFixed(2),
        value.sort,
        stableStringify(value.filters),
      ].join("|");

    return {
      ...value,
      geocell,
      queryFingerprint,
      serviceTypes,
    };
  });

type GeoSearchQuery = z.infer<typeof geoSearchSchema>;

export async function handleGeoDiscoverySearch(context: MobileApiContext) {
  const body = await readJsonBody(context.request);
  const query = geoSearchSchema.parse(body);
  context.log.geo_fingerprint_hash = sha256Hex(query.queryFingerprint).slice(
    0,
    16,
  );

  const fetchedAt = new Date().toISOString();
  const results: Partial<Record<ServiceType, GeoDiscoveryPage>> = {};

  for (const serviceType of query.serviceTypes) {
    results[serviceType] =
      serviceType === "parking"
        ? await loadParking(context, query)
        : emptyPage(query);
  }

  return jsonResponse(
    {
      fetchedAt,
      partialFailures: [],
      queryFingerprint: query.queryFingerprint,
      results,
      schemaVersion,
      source: "network",
    },
    { requestId: context.requestId, status: 200 },
  );
}

async function loadParking(context: MobileApiContext, query: GeoSearchQuery) {
  const center = { latitude: query.latitude, longitude: query.longitude };
  const parkingRows = await loadParkingRows(context, query);

  const entities = parkingRows.flatMap((row) => {
    if (row.latitude === null || row.longitude === null) return [];

    const location = {
      latitude: Number(row.latitude),
      longitude: Number(row.longitude),
    };
    const itemDistanceKm = roundedDistance(distanceKm(center, location));
    if (itemDistanceKm > query.radiusKm) return [];

    const imageUrls = imageUrlsFor(row);
    const imageUrl = imageUrls[0] ?? fallbackImageUrl;
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
          availableFrom: isoAtMinute(
            startDate,
            row.daily_start_minute,
            8 * 60,
          ),
          availableUntil: isoAtMinute(
            endDate,
            row.daily_end_minute,
            20 * 60,
          ),
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
          skipWeekends: row.skip_weekends ?? false,
          slotsAvailable: row.slots_count,
          supportedVehicleTypes: supportedVehicleTypesFor(row.vehicle_fit),
          title: row.title,
          vehicleFit: row.vehicle_fit,
          vehicle_fit: row.vehicle_fit,
        },
        id: row.id,
        imageUrl,
        location,
        price: row.hourly_price ?? undefined,
        rating: undefined,
        serviceType: "parking",
        title: row.title ?? "Parking space",
      } satisfies GeoDiscoveryEntity,
    ];
  });

  const sorted = sortItems(entities, query.sort);
  const offset = parseCursor(
    cursorForService(query.cursors, "parking"),
    query.queryFingerprint,
    "parking",
  );
  const pageItems = sorted.slice(offset, offset + query.pageSize);
  const nextOffset = offset + query.pageSize;

  return {
    fetchedAt: new Date().toISOString(),
    isStale: false,
    items: pageItems,
    nextCursor:
      nextOffset < sorted.length
        ? makeCursor(query.queryFingerprint, "parking", nextOffset)
        : undefined,
    queryFingerprint: query.queryFingerprint,
    schemaVersion,
    source: "network",
  } satisfies GeoDiscoveryPage;
}

async function loadParkingRows(
  context: MobileApiContext,
  query: GeoSearchQuery,
) {
  const result = await timedSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("search_public_parking_spots", {
        p_latitude: query.latitude,
        p_limit: 250,
        p_longitude: query.longitude,
        p_offset: 0,
        p_radius_km: query.radiusKm,
      }),
      context.signal,
    ),
  );

  if (result.error) {
    throw supabaseError(result.error);
  }

  return (result.data ?? []) as unknown as ParkingSpaceRow[];
}

function emptyPage(query: GeoSearchQuery): GeoDiscoveryPage {
  return {
    fetchedAt: new Date().toISOString(),
    isStale: false,
    items: [],
    nextCursor: undefined,
    queryFingerprint: query.queryFingerprint,
    schemaVersion,
    source: "network",
  };
}

function cursorForService(
  cursors: Record<string, string>,
  serviceType: ServiceType,
) {
  return cursors[serviceType];
}

function makeCursor(
  queryFingerprint: string,
  serviceType: ServiceType,
  offset: number,
) {
  return `${queryFingerprint}::${serviceType}::${offset}`;
}

function parseCursor(
  cursor: string | undefined,
  queryFingerprint: string,
  serviceType: ServiceType,
) {
  if (!cursor) return 0;
  const [cursorFingerprint, cursorServiceType, offsetText] = cursor.split("::");
  const offset = Number(offsetText);
  if (
    cursorFingerprint !== queryFingerprint ||
    cursorServiceType !== serviceType ||
    !Number.isInteger(offset) ||
    offset < 0
  ) {
    throw apiError(
      409,
      "INVALID_CURSOR",
      "Cursor is invalid for the current query.",
    );
  }
  return offset;
}

function sortItems(items: GeoDiscoveryEntity[], sort: GeoSortKey) {
  return [...items].sort((left, right) => {
    if (sort === "price") {
      return (
        (left.price ?? Number.MAX_SAFE_INTEGER) -
        (right.price ?? Number.MAX_SAFE_INTEGER)
      );
    }
    if (sort === "rating") {
      return (right.rating ?? 0) - (left.rating ?? 0);
    }
    return left.distanceKm - right.distanceKm;
  });
}

function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  return `{${Object.entries(value as Record<string, unknown>)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, entry]) => `${JSON.stringify(key)}:${stableStringify(entry)}`)
    .join(",")}}`;
}

function roundedGeocell(latitude: number, longitude: number) {
  return `${latitude.toFixed(3)},${longitude.toFixed(3)}`;
}

function toRadians(degrees: number) {
  return (degrees * Math.PI) / 180;
}

function distanceKm(from: GeoPoint, to: GeoPoint) {
  const dLat = toRadians(to.latitude - from.latitude);
  const dLon = toRadians(to.longitude - from.longitude);
  const lat1 = toRadians(from.latitude);
  const lat2 = toRadians(to.latitude);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return 2 * earthRadiusKm * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function roundedDistance(value: number) {
  return Math.round(value * 100) / 100;
}

function activeAvailability(slotsCount: number): AvailabilityStatus {
  if (slotsCount <= 0) return "unavailable";
  return slotsCount <= 2 ? "limited" : "available";
}

function datePart(value: string | null, fallbackOffsetDays: number) {
  if (value) return value;
  const date = new Date();
  date.setDate(date.getDate() + fallbackOffsetDays);
  return date.toISOString().slice(0, 10);
}

function isoAtMinute(date: string, minute: number | null, fallbackMinute: number) {
  const safeMinute =
    typeof minute === "number" && Number.isInteger(minute)
      ? minute
      : fallbackMinute;
  const hours = Math.floor(safeMinute / 60).toString().padStart(2, "0");
  const minutes = (safeMinute % 60).toString().padStart(2, "0");
  return `${date}T${hours}:${minutes}:00.000+05:30`;
}

function amenitiesFor(row: ParkingSpaceRow) {
  const amenities = new Set<string>();
  if (
    row.parking_type === "covered" ||
    row.parking_type === "garage" ||
    row.parking_type === "basement"
  ) {
    amenities.add("covered");
  }
  if (row.vehicle_fit === "bike") amenities.add("twoWheeler");
  if (amenities.size === 0) amenities.add("covered");
  return Array.from(amenities);
}

function imageUrlsFor(row: ParkingSpaceRow) {
  if (!Array.isArray(row.image_urls)) return [];
  return Array.from(
    new Set(
      row.image_urls
        .map((url) => url?.trim())
        .filter((url): url is string => Boolean(url)),
    ),
  );
}

function supportedVehicleTypesFor(vehicleFit: string | null) {
  switch (vehicleFit) {
    case "bike":
      return ["bike"];
    case "both":
      return ["bike", "car"];
    case "car":
    default:
      return ["car"];
  }
}
