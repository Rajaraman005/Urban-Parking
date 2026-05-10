import "server-only";

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "@/server/db/supabase";
import { apiError, type MobileApiContext } from "./core";

export function getMobileSupabase() {
  return getSupabaseAdmin();
}

export function accessTokenFromBearer(context: MobileApiContext) {
  const header = context.request.headers.get("authorization");
  const match = header?.match(/^Bearer\s+(.+)$/i);
  const accessToken = match?.[1]?.trim();
  return accessToken && accessToken.length > 0 ? accessToken : null;
}

export function getMobileSupabaseForBearer(context: MobileApiContext) {
  const accessToken = accessTokenFromBearer(context);
  const { anonKey, url } = userSupabaseConfig();

  if (!accessToken) {
    throw apiError(401, "AUTH_REQUIRED", "Sign in before using messages.");
  }

  if (!anonKey || !url) {
    throw apiError(
      503,
      "DEPLOYMENT_MISCONFIGURATION",
      "Mobile API authentication is not configured.",
    );
  }

  return createClient(url, anonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  });
}

function userSupabaseConfig() {
  return {
    anonKey:
      process.env.SUPABASE_ANON_KEY?.trim() ||
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim() ||
      process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY?.trim(),
    url:
      process.env.SUPABASE_URL?.trim() ||
      process.env.NEXT_PUBLIC_SUPABASE_URL?.trim() ||
      process.env.EXPO_PUBLIC_SUPABASE_URL?.trim(),
  };
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

export async function timedUserSupabase<T>(
  context: MobileApiContext,
  operation: (client: SupabaseClient) => PromiseLike<T>,
) {
  const startedAt = Date.now();
  try {
    return await operation(getMobileSupabaseForBearer(context));
  } finally {
    context.addSupabaseQueryMs(Date.now() - startedAt);
  }
}

export async function currentUserIdFromBearer(
  context: MobileApiContext,
): Promise<string | null> {
  const accessToken = accessTokenFromBearer(context);
  if (!accessToken) return null;

  try {
    const result = await timedSupabase(context, (client) =>
      client.auth.getUser(accessToken),
    );
    return result.data.user?.id ?? null;
  } catch {
    const { anonKey, url } = userSupabaseConfig();
    if (!anonKey || !url) return null;
    try {
      const result = await createClient(url, anonKey, {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }).auth.getUser(accessToken);
      return result.data.user?.id ?? null;
    } catch {
      return null;
    }
  }
}

export function withAbortSignal<
  T extends { abortSignal: (signal: AbortSignal) => T },
>(request: T, signal: AbortSignal) {
  return request.abortSignal(signal);
}
