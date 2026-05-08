import "server-only";

import { z } from "zod";
import {
  apiError,
  jsonResponse,
  supabaseError,
  type MobileApiContext,
} from "./core";
import { timedSupabase, withAbortSignal } from "./supabase";

const uuidSchema = z
  .string()
  .regex(
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    "Parking spot id is invalid.",
  );

export async function handleParkingSpotByQuery(context: MobileApiContext) {
  const url = new URL(context.request.url);
  const id = uuidSchema.parse(url.searchParams.get("id") ?? "");
  return handleParkingSpotById(context, id);
}

export async function handleParkingSpotByRoute(
  context: MobileApiContext,
  routeContext?: unknown,
) {
  const params = await paramsFromRouteContext(routeContext);
  const id = uuidSchema.parse(params.id);
  return handleParkingSpotById(context, id);
}

async function handleParkingSpotById(context: MobileApiContext, id: string) {
  const result = await timedSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("get_public_parking_spot", { p_space_id: id }),
      context.signal,
    ),
  );

  if (result.error) {
    throw supabaseError(result.error);
  }

  if (!result.data) {
    throw apiError(404, "SPOT_NOT_FOUND", "Parking spot was not found.");
  }

  const payload =
    typeof result.data === "object" && result.data !== null
      ? { ...(result.data as Record<string, unknown>) }
      : result.data;

  return jsonResponse(payload, { requestId: context.requestId, status: 200 });
}

async function paramsFromRouteContext(routeContext?: unknown) {
  const rawParams =
    typeof routeContext === "object" && routeContext !== null && "params" in routeContext
      ? (routeContext as { params?: unknown }).params
      : {};
  const params =
    typeof (rawParams as Promise<unknown>)?.then === "function"
      ? await (rawParams as Promise<unknown>)
      : rawParams;

  if (typeof params !== "object" || params === null || !("id" in params)) {
    throw apiError(422, "INVALID_REQUEST", "Parking spot id is required.");
  }

  return params as { id: string };
}
