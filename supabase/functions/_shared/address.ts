// eslint-disable-next-line import/no-unresolved
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

export const INDIA_BOUNDS = {
  maxLatitude: 38,
  maxLongitude: 98,
  minLatitude: 6,
  minLongitude: 68
};

export interface NormalizedAddressResult {
  city: string | null;
  confidence: number;
  formattedAddress: string;
  latitude: number;
  locality: string | null;
  longitude: number;
  placeId: string | null;
  postalCode: string | null;
  provider: "nominatim" | "manual";
  raw?: Record<string, unknown>;
  state: string | null;
}

interface NominatimAddress {
  city?: string;
  city_district?: string;
  county?: string;
  hamlet?: string;
  municipality?: string;
  neighbourhood?: string;
  postcode?: string;
  state?: string;
  quarter?: string;
  residential?: string;
  road?: string;
  state_district?: string;
  suburb?: string;
  town?: string;
  village?: string;
}

interface NominatimResult {
  address?: NominatimAddress;
  display_name?: string;
  importance?: number;
  lat?: string;
  licence?: string;
  lon?: string;
  osm_id?: number;
  osm_type?: string;
  place_id?: number;
  type?: string;
}

const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));

export const isIndiaCoordinate = (latitude: number, longitude: number) =>
  Number.isFinite(latitude) &&
  Number.isFinite(longitude) &&
  latitude >= INDIA_BOUNDS.minLatitude &&
  latitude <= INDIA_BOUNDS.maxLatitude &&
  longitude >= INDIA_BOUNDS.minLongitude &&
  longitude <= INDIA_BOUNDS.maxLongitude;

export const normalizeQuery = (value: string) => value.trim().replace(/\s+/g, " ").toLowerCase();

export const sha256Hex = async (value: string) => {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);

  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

export const normalizeNominatimResult = (item: NominatimResult): NormalizedAddressResult | null => {
  const latitude = Number(item.lat);
  const longitude = Number(item.lon);

  if (!isIndiaCoordinate(latitude, longitude)) {
    return null;
  }

  const address = item.address ?? {};
  const locality =
    address.neighbourhood ??
    address.suburb ??
    address.quarter ??
    address.residential ??
    address.road ??
    address.hamlet ??
    address.village ??
    null;
  const city =
    address.city ??
    address.town ??
    address.municipality ??
    address.village ??
    address.city_district ??
    address.state_district ??
    address.county ??
    null;
  const placeId =
    typeof item.place_id === "number"
      ? String(item.place_id)
      : item.osm_type && typeof item.osm_id === "number"
        ? `${item.osm_type}:${item.osm_id}`
        : null;

  return {
    city,
    confidence: clamp(typeof item.importance === "number" ? item.importance : 0.5, 0, 1),
    formattedAddress: item.display_name ?? "",
    latitude,
    locality,
    longitude,
    placeId,
    postalCode: address.postcode ?? null,
    provider: "nominatim",
    raw: item as Record<string, unknown>,
    state: address.state ?? null
  };
};

export const readCache = async <T>(admin: SupabaseClient, cacheKey: string): Promise<T | null> => {
  const { data, error } = await admin
    .from("address_geocode_cache")
    .select("result, expires_at")
    .eq("cache_key", cacheKey)
    .maybeSingle();

  if (error) {
    throw error;
  }

  if (!data || new Date(data.expires_at).getTime() <= Date.now()) {
    return null;
  }

  return data.result as T;
};

export const writeCache = async (
  admin: SupabaseClient,
  cacheKey: string,
  lookupType: "search" | "reverse",
  result: unknown,
  ttlMs = 1000 * 60 * 60 * 24 * 7
) => {
  const { error } = await admin.from("address_geocode_cache").upsert(
    {
      cache_key: cacheKey,
      expires_at: new Date(Date.now() + ttlMs).toISOString(),
      lookup_type: lookupType,
      result
    },
    { onConflict: "cache_key" }
  );

  if (error) {
    throw error;
  }
};

export const enforceLookupRateLimit = async (
  admin: SupabaseClient,
  userId: string,
  lookupType: "search" | "reverse"
) => {
  const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();
  const [userCountResult, globalCountResult] = await Promise.all([
    admin
      .from("address_lookup_events")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", oneMinuteAgo),
    admin
      .from("address_lookup_events")
      .select("id", { count: "exact", head: true })
      .gte("created_at", oneMinuteAgo)
  ]);

  if (userCountResult.error) {
    throw userCountResult.error;
  }

  if (globalCountResult.error) {
    throw globalCountResult.error;
  }

  if ((userCountResult.count ?? 0) >= 12 || (globalCountResult.count ?? 0) >= 55) {
    return false;
  }

  const { error } = await admin.from("address_lookup_events").insert({
    lookup_type: lookupType,
    user_id: userId
  });

  if (error) {
    throw error;
  }

  return true;
};
