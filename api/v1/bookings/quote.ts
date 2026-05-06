import { createClient } from "@supabase/supabase-js";

declare const process: {
  env: Record<string, string | undefined>;
};

interface VercelRequestLike {
  body?: unknown;
  method?: string;
}

interface VercelResponseLike {
  end: () => void;
  json: (body: unknown) => void;
  setHeader: (name: string, value: string) => void;
  status: (code: number) => VercelResponseLike;
}

interface QuoteRequestBody {
  endAt?: unknown;
  spotId?: unknown;
  startAt?: unknown;
}

interface NormalizedQuoteRequest {
  endAt: string;
  spotId: string;
  startAt: string;
}

interface ParkingSpacePriceRow {
  hourly_price: number | null;
  id: string;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const corsOrigin = process.env.GEO_DISCOVERY_ALLOWED_ORIGIN ?? "*";

const setCorsHeaders = (response: VercelResponseLike) => {
  response.setHeader("Access-Control-Allow-Origin", corsOrigin);
  response.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
  response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.setHeader("Cache-Control", "private, max-age=0, must-revalidate");
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
      : "booking_quote_error";
  const message = error instanceof Error ? error.message : "Booking quote failed";

  response.status(status).json({ code, message, status });
};

const supabase = () => {
  const url = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.SUPABASE_ANON_KEY;

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

const parseBody = (body: unknown): NormalizedQuoteRequest => {
  const payload = typeof body === "object" && body !== null ? (body as QuoteRequestBody) : {};
  const spotId = typeof payload.spotId === "string" ? payload.spotId : "";
  const startAt = typeof payload.startAt === "string" ? payload.startAt : "";
  const endAt = typeof payload.endAt === "string" ? payload.endAt : "";

  if (!UUID_PATTERN.test(spotId)) {
    throw Object.assign(new Error("Parking spot id is invalid"), {
      code: "invalid_parking_spot_id",
      status: 400
    });
  }

  if (!startAt || Number.isNaN(Date.parse(startAt)) || !endAt || Number.isNaN(Date.parse(endAt))) {
    throw Object.assign(new Error("Booking time window is invalid"), {
      code: "invalid_booking_window",
      status: 400
    });
  }

  return { endAt, spotId, startAt };
};

const calculateQuote = (params: {
  endAt: string;
  hourlyPrice: number;
  spotId: string;
  startAt: string;
}) => {
  const startDate = new Date(params.startAt);
  const endDate = new Date(params.endAt);
  const durationMs = endDate.getTime() - startDate.getTime();

  if (durationMs <= 0) {
    throw Object.assign(new Error("Booking end time must be after start time"), {
      code: "invalid_booking_window",
      status: 400
    });
  }

  const durationHours = Math.min(24, Math.max(1, Math.ceil(durationMs / 3_600_000)));
  const subtotal = params.hourlyPrice * durationHours;
  const platformFee = Math.round(subtotal * 0.08);
  const taxes = Math.round((subtotal + platformFee) * 0.18);

  return {
    currency: "INR",
    endAt: endDate.toISOString(),
    platformFee,
    spotId: params.spotId,
    startAt: startDate.toISOString(),
    subtotal,
    taxes,
    total: subtotal + platformFee + taxes
  };
};

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
    const body = parseBody(request.body);
    const client = supabase();
    const { data, error } = await client
      .from("parking_spaces")
      .select("id,hourly_price")
      .eq("id", body.spotId)
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

    const row = data as ParkingSpacePriceRow;
    if (typeof row.hourly_price !== "number" || row.hourly_price <= 0) {
      throw Object.assign(new Error("Parking spot pricing is unavailable"), {
        code: "pricing_unavailable",
        status: 422
      });
    }

    response.status(200).json(
      calculateQuote({
        endAt: body.endAt,
        hourlyPrice: row.hourly_price,
        spotId: row.id,
        startAt: body.startAt
      })
    );
  } catch (error) {
    responseError(response, error);
  }
}
