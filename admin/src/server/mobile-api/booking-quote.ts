import "server-only";

import { z } from "zod";
import {
  apiError,
  jsonResponse,
  readJsonBody,
  supabaseError,
  type MobileApiContext,
} from "./core";
import { timedSupabase, withAbortSignal } from "./supabase";

type QuoteSourceRow = {
  hourly_price: number | null;
  id: string;
  skip_weekends: boolean | null;
};

const quoteRequestSchema = z.object({
  endAt: z
    .string()
    .refine((value) => !Number.isNaN(Date.parse(value)), "Invalid end time."),
  spotId: z
    .string()
    .regex(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      "Parking spot id is invalid.",
    ),
  startAt: z
    .string()
    .refine((value) => !Number.isNaN(Date.parse(value)), "Invalid start time."),
});

export async function handleBookingQuote(context: MobileApiContext) {
  const body = quoteRequestSchema.parse(await readJsonBody(context.request));
  const startDate = new Date(body.startAt);
  const endDate = new Date(body.endAt);

  if (endDate.getTime() <= startDate.getTime()) {
    throw apiError(
      422,
      "INVALID_BOOKING_WINDOW",
      "Booking end time must be after start time.",
    );
  }

  const source = await loadQuoteSource(context, body.spotId);
  if (source.skip_weekends === true && containsWeekendDate(body.startAt, body.endAt)) {
    throw apiError(
      422,
      "WEEKEND_BOOKING_UNAVAILABLE",
      "This parking spot is not available on Saturday or Sunday.",
    );
  }

  if (typeof source.hourly_price !== "number" || source.hourly_price <= 0) {
    throw apiError(
      422,
      "PRICING_UNAVAILABLE",
      "Parking spot pricing is unavailable.",
    );
  }

  return jsonResponse(
    calculateQuote({
      endAt: body.endAt,
      hourlyPrice: source.hourly_price,
      spotId: source.id,
      startAt: body.startAt,
    }),
    { requestId: context.requestId, status: 200 },
  );
}

async function loadQuoteSource(context: MobileApiContext, spotId: string) {
  const result = await timedSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("get_public_parking_quote_source", { p_space_id: spotId }),
      context.signal,
    ),
  );

  if (result.error) {
    throw supabaseError(result.error);
  }

  const rows = (result.data ?? []) as QuoteSourceRow[];
  const row = rows[0];
  if (!row) {
    throw apiError(404, "SPOT_NOT_FOUND", "Parking spot was not found.");
  }
  return row;
}

function calculateQuote(params: {
  endAt: string;
  hourlyPrice: number;
  spotId: string;
  startAt: string;
}) {
  const startDate = new Date(params.startAt);
  const endDate = new Date(params.endAt);
  const durationHours = Math.min(
    24,
    Math.max(1, Math.ceil((endDate.getTime() - startDate.getTime()) / 3_600_000)),
  );
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
    total: subtotal + platformFee + taxes,
  };
}

function dateOnlyUtc(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (!match) return null;
  return new Date(
    Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])),
  );
}

function containsWeekendDate(startAt: string, endAt: string) {
  const startDate = dateOnlyUtc(startAt);
  const endDate = dateOnlyUtc(endAt);
  if (!startDate || !endDate) return false;

  for (
    let cursor = new Date(startDate);
    cursor.getTime() <= endDate.getTime();
    cursor.setUTCDate(cursor.getUTCDate() + 1)
  ) {
    const day = cursor.getUTCDay();
    if (day === 0 || day === 6) return true;
  }
  return false;
}
