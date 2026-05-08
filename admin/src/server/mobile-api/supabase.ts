import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "@/server/db/supabase";
import type { MobileApiContext } from "./core";

export function getMobileSupabase() {
  return getSupabaseAdmin();
}

export async function timedSupabase<T>(
  context: MobileApiContext,
  operation: (client: SupabaseClient) => PromiseLike<T>,
) {
  const startedAt = Date.now();
  try {
    return await operation(getMobileSupabase());
  } finally {
    context.addSupabaseQueryMs(Date.now() - startedAt);
  }
}

export async function currentUserIdFromBearer(
  context: MobileApiContext,
): Promise<string | null> {
  const header = context.request.headers.get("authorization");
  const match = header?.match(/^Bearer\s+(.+)$/i);
  const accessToken = match?.[1]?.trim();
  if (!accessToken) return null;

  try {
    const result = await timedSupabase(context, (client) =>
      client.auth.getUser(accessToken),
    );
    return result.data.user?.id ?? null;
  } catch {
    return null;
  }
}

export function withAbortSignal<T extends { abortSignal: (signal: AbortSignal) => T }>(
  request: T,
  signal: AbortSignal,
) {
  return request.abortSignal(signal);
}
