import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getServerEnv } from "@/server/env";

let cachedClient: SupabaseClient | null = null;

export function getSupabaseAdmin() {
  if (cachedClient) return cachedClient;
  const env = getServerEnv();
  cachedClient = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  return cachedClient;
}

export function databaseError(message: string) {
  return new Error(`Database operation failed: ${message}`);
}
