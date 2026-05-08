import "server-only";

import { z } from "zod";
import {
  apiError,
  jsonResponse,
  readJsonBody,
  sha256Hex,
  type MobileApiContext,
} from "./core";
import {
  currentUserIdFromBearer,
  timedUserSupabase,
  withAbortSignal,
} from "./supabase";

type SupabaseErrorLike = {
  code?: string;
  message?: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const uuidSchema = z.string().regex(uuidPattern, "UUID is invalid.");
const vehicleKindSchema = z.enum(["bike", "car"]);

const createBookingSchema = z.object({
  endAt: z
    .string()
    .refine((value) => !Number.isNaN(Date.parse(value)), "Invalid end time."),
  idempotencyKey: uuidSchema,
  spotId: uuidSchema,
  startAt: z
    .string()
    .refine((value) => !Number.isNaN(Date.parse(value)), "Invalid start time."),
  vehicleKind: vehicleKindSchema,
});

const transitionSchema = z.object({
  expectedVersion: z.number().int().positive(),
});

export async function handleCreateBooking(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  await enforceBookingCreateRateLimit(context, userId);

  const body = createBookingSchema.parse(await readJsonBody(context.request));
  context.log.listing_id = body.spotId;
  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("create_booking_request", {
        p_end_at: body.endAt,
        p_idempotency_key: body.idempotencyKey,
        p_space_id: body.spotId,
        p_start_at: body.startAt,
        p_vehicle_kind: body.vehicleKind,
      }),
      context.signal,
    ),
  );

  if (result.error) {
    throw bookingSupabaseError(result.error);
  }

  context.log.booking_id = bookingStringField(result.data, "id");
  context.log.booking_status = bookingStringField(result.data, "status");
  return jsonResponse(result.data, {
    requestId: context.requestId,
    status: 201,
  });
}

export async function handleListBookings(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const url = new URL(context.request.url);
  const role = url.searchParams.get("role") === "host" ? "host" : "renter";
  const rpcName =
    role === "host" ? "list_host_bookings" : "list_renter_bookings";
  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(client.rpc(rpcName), context.signal),
  );

  if (result.error) {
    throw bookingSupabaseError(result.error);
  }

  return jsonResponse(
    {
      items: Array.isArray(result.data) ? result.data : [],
      role,
    },
    { requestId: context.requestId, status: 200 },
  );
}

export async function handleApproveBooking(
  context: MobileApiContext,
  routeContext?: unknown,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const id = uuidSchema.parse((await paramsFromRouteContext(routeContext)).id);
  context.log.booking_id = id;
  const body = transitionSchema.parse(await readJsonBody(context.request));
  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("approve_booking", {
        p_booking_id: id,
        p_expected_version: body.expectedVersion,
      }),
      context.signal,
    ),
  );

  if (result.error) {
    throw bookingSupabaseError(result.error);
  }

  context.log.listing_id = bookingStringField(result.data, "spotId");
  context.log.booking_status = bookingStringField(result.data, "status");
  return jsonResponse(result.data, {
    requestId: context.requestId,
    status: 200,
  });
}

export async function handleRejectBooking(
  context: MobileApiContext,
  routeContext?: unknown,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const id = uuidSchema.parse((await paramsFromRouteContext(routeContext)).id);
  context.log.booking_id = id;
  const body = transitionSchema.parse(await readJsonBody(context.request));
  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("reject_booking", {
        p_booking_id: id,
        p_expected_version: body.expectedVersion,
      }),
      context.signal,
    ),
  );

  if (result.error) {
    throw bookingSupabaseError(result.error);
  }

  context.log.listing_id = bookingStringField(result.data, "spotId");
  context.log.booking_status = bookingStringField(result.data, "status");
  return jsonResponse(result.data, {
    requestId: context.requestId,
    status: 200,
  });
}

async function requireUserId(context: MobileApiContext) {
  const userId = await currentUserIdFromBearer(context);
  if (!userId) {
    throw apiError(401, "AUTH_REQUIRED", "Sign in before managing bookings.");
  }
  return userId;
}

async function enforceBookingCreateRateLimit(
  context: MobileApiContext,
  userId: string,
) {
  const mode = bookingRateLimitMode();
  if (mode === "disabled") return;

  const restUrl = process.env.UPSTASH_REDIS_REST_URL?.trim();
  const restToken = process.env.UPSTASH_REDIS_REST_TOKEN?.trim();
  if (!restUrl || !restToken) return;

  const key = `mobile-api:booking-create:${Math.floor(Date.now() / 3_600_000)}:${sha256Hex(userId)}`;
  try {
    const response = await fetch(`${restUrl.replace(/\/$/, "")}/pipeline`, {
      body: JSON.stringify([
        ["INCR", key],
        ["EXPIRE", key, 3600],
      ]),
      headers: {
        Authorization: `Bearer ${restToken}`,
        "Content-Type": "application/json",
      },
      method: "POST",
      signal: context.signal,
    });
    const payload = (await response.json()) as Array<{ result?: unknown }>;
    const count = Number(payload[0]?.result ?? 0);
    const limited = Number.isFinite(count) && count > 10;
    context.log.rate_limited = limited;
    if (limited && mode === "enforce") {
      throw apiError(
        429,
        "BOOKING_CREATE_RATE_LIMITED",
        "Too many booking requests. Try again later.",
        { retryAfter: 3600 },
      );
    }
  } catch (error) {
    if (error instanceof Error && error.name === "MobileApiError") throw error;
    context.log.error_code = "BOOKING_RATE_LIMITER_OPEN";
  }
}

function bookingRateLimitMode() {
  const configured = process.env.BOOKING_CREATE_RATE_LIMIT_MODE?.trim();
  if (
    configured === "disabled" ||
    configured === "dry-run" ||
    configured === "enforce"
  ) {
    return configured;
  }
  return process.env.VERCEL_ENV === "production" ? "enforce" : "dry-run";
}

function bookingStringField(data: unknown, field: string) {
  if (typeof data !== "object" || data === null || !(field in data)) {
    return undefined;
  }
  const value = (data as Record<string, unknown>)[field];
  return typeof value === "string" ? value : undefined;
}

function bookingSupabaseError(error: SupabaseErrorLike) {
  const message = error.message ?? "Booking request failed.";
  const lowerMessage = message.toLowerCase();
  const code = error.code ?? "BOOKING_DATABASE_ERROR";

  if (code === "23505" || lowerMessage.includes("idempotency")) {
    return apiError(
      409,
      "IDEMPOTENCY_KEY_REUSED",
      "This retry key was already used for a different booking request.",
    );
  }
  if (code === "23P01" || lowerMessage.includes("no available slot")) {
    return apiError(
      409,
      "BOOKING_SLOT_UNAVAILABLE",
      "This parking slot is no longer available for that time.",
    );
  }
  if (code === "40001" || lowerMessage.includes("stale")) {
    return apiError(
      409,
      "STALE_BOOKING_VERSION",
      "This booking changed. Refresh and try again.",
    );
  }
  if (code === "42501") {
    return apiError(403, "BOOKING_FORBIDDEN", message);
  }
  if (code === "P0002") {
    return apiError(404, "BOOKING_NOT_FOUND", message);
  }
  if (code === "23514") {
    return apiError(422, "BOOKING_VALIDATION_FAILED", message);
  }
  if (code === "57014") {
    return apiError(
      503,
      "BACKEND_TIMEOUT",
      "Booking service is temporarily slow. Please try again.",
      { retryAfter: 2 },
    );
  }

  return apiError(500, "BOOKING_DATABASE_ERROR", "Booking service failed.");
}

async function paramsFromRouteContext(routeContext?: unknown) {
  const rawParams =
    typeof routeContext === "object" &&
    routeContext !== null &&
    "params" in routeContext
      ? (routeContext as { params?: unknown }).params
      : {};
  const params =
    typeof (rawParams as Promise<unknown>)?.then === "function"
      ? await (rawParams as Promise<unknown>)
      : rawParams;

  if (typeof params !== "object" || params === null || !("id" in params)) {
    throw apiError(422, "INVALID_REQUEST", "Booking id is required.");
  }

  return params as { id: string };
}
