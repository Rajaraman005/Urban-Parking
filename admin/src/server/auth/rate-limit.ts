import "server-only";
import { getSupabaseAdmin } from "@/server/db/supabase";
import { getServerEnv } from "@/server/env";
import { LOGIN_WINDOW_MINUTES, MAX_IP_FAILURES, MAX_USERNAME_FAILURES } from "./constants";
import { ipHash } from "./session-crypto";

export function normalizeUsername(value: string) {
  return value.trim().toLowerCase();
}

export async function loginRateState(username: string, ipAddress: string) {
  const env = getServerEnv();
  const hashedIp = ipHash(ipAddress, env.ADMIN_SESSION_SECRET);
  const since = new Date(Date.now() - LOGIN_WINDOW_MINUTES * 60 * 1000).toISOString();
  const supabase = getSupabaseAdmin();
  const [{ count: usernameFailures }, { count: ipFailures }] = await Promise.all([
    supabase
      .from("admin_login_attempts")
      .select("id", { count: "exact", head: true })
      .eq("username", username)
      .eq("success", false)
      .gte("created_at", since),
    supabase
      .from("admin_login_attempts")
      .select("id", { count: "exact", head: true })
      .eq("ip_hash", hashedIp)
      .eq("success", false)
      .gte("created_at", since)
  ]);

  return {
    blocked: (usernameFailures ?? 0) >= MAX_USERNAME_FAILURES || (ipFailures ?? 0) >= MAX_IP_FAILURES,
    ipHash: hashedIp
  };
}

export async function recordLoginAttempt(params: {
  failureReason?: string;
  ipHash: string;
  success: boolean;
  username: string;
}) {
  await getSupabaseAdmin().from("admin_login_attempts").insert({
    failure_reason: params.failureReason ?? null,
    ip_hash: params.ipHash,
    success: params.success,
    username: params.username
  });
}
