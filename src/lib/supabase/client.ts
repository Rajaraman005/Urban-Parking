import "react-native-url-polyfill/auto";

import { createClient } from "@supabase/supabase-js";

import { env } from "@/config/env";
import type { Database } from "@/lib/supabase/database.types";
import { supabaseSecureStorage } from "@/lib/supabase/secureStorage";

export const isSupabaseConfigured = Boolean(env.supabaseUrl && env.supabaseAnonKey);

const supabaseUrl = env.supabaseUrl || "https://placeholder.supabase.co";
const supabaseAnonKey = env.supabaseAnonKey || "placeholder-anon-key";

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    detectSessionInUrl: false,
    flowType: "pkce",
    persistSession: true,
    storage: supabaseSecureStorage
  }
});
