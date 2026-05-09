// eslint-disable-next-line import/no-unresolved
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

import {
  enforceLookupRateLimit,
  isIndiaCoordinate,
  normalizeNominatimResult,
  readCache,
  sha256Hex,
  writeCache
} from "../_shared/address.ts";
import { corsHeaders, getBearerToken, jsonResponse, readJsonBody } from "../_shared/http.ts";

const FUNCTION_VERSION = "reverse-geocode-address-20260502-v1";
const functionHeaders = { "x-function-version": FUNCTION_VERSION };
const functionResponse = (body: Record<string, unknown>, status = 200) => jsonResponse(body, status, functionHeaders);

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key);

  if (!value) {
    throw new Error(`Missing ${key}`);
  }

  return value;
};

const supabaseUrl = requiredEnv("SUPABASE_URL");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const nominatimUserAgent =
  Deno.env.get("OSM_NOMINATIM_USER_AGENT") ?? "Lotzi/1.0 (contact: support@lotzi.in)";

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: { ...corsHeaders, ...functionHeaders } });
  }

  if (request.method !== "POST") {
    return functionResponse({ ok: false, code: "method_not_allowed", message: "Method not allowed." }, 405);
  }

  try {
    const token = getBearerToken(request);

    if (!token) {
      return functionResponse({ ok: false, code: "unauthorized", message: "Authentication is required." }, 401);
    }

    const { data: authData, error: authError } = await admin.auth.getUser(token);

    if (authError || !authData.user) {
      return functionResponse({ ok: false, code: "unauthorized", message: "Authentication is required." }, 401);
    }

    const body = await readJsonBody<{ latitude?: number; longitude?: number }>(request);
    const latitude = Number(body.latitude);
    const longitude = Number(body.longitude);

    if (!isIndiaCoordinate(latitude, longitude)) {
      return functionResponse({ ok: false, code: "validation", message: "Choose a location inside India." }, 400);
    }

    const roundedLatitude = latitude.toFixed(5);
    const roundedLongitude = longitude.toFixed(5);
    const cacheKey = `reverse:${await sha256Hex(`${roundedLatitude},${roundedLongitude}`)}`;
    const cached = await readCache<{ result: unknown | null }>(admin, cacheKey);

    if (cached) {
      return functionResponse({ ok: true, data: cached });
    }

    const allowed = await enforceLookupRateLimit(admin, authData.user.id, "reverse");

    if (!allowed) {
      return functionResponse({ ok: false, code: "rate_limit", message: "Too many map lookups. Please wait a moment." }, 429);
    }

    const url = new URL("https://nominatim.openstreetmap.org/reverse");
    url.searchParams.set("format", "jsonv2");
    url.searchParams.set("addressdetails", "1");
    url.searchParams.set("lat", roundedLatitude);
    url.searchParams.set("lon", roundedLongitude);

    const response = await fetch(url, {
      headers: {
        "Accept-Language": "en-IN,en",
        "User-Agent": nominatimUserAgent
      }
    });

    if (!response.ok) {
      return functionResponse({ ok: false, code: "server", message: "Map lookup is temporarily unavailable." }, 502);
    }

    const payload = (await response.json().catch(() => null)) as unknown;
    const result = payload ? normalizeNominatimResult(payload as never) : null;
    const data = { result };

    await writeCache(admin, cacheKey, "reverse", data);

    return functionResponse({ ok: true, data });
  } catch {
    return functionResponse({ ok: false, code: "server", message: "Map lookup is temporarily unavailable." }, 500);
  }
});
