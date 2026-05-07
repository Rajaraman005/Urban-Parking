import "server-only";
import { getSupabaseAdmin } from "@/server/db/supabase";
import { verifyPassword } from "./password";
import { createAdminSession, setSessionCookie } from "./session";
import type { AdminUserRow } from "./types";

export async function authenticateAdmin(params: {
  ipHash: string;
  password: string;
  userAgent: string;
  username: string;
}) {
  const { data, error } = await getSupabaseAdmin()
    .from("admin_users")
    .select("id,username,display_name,role,is_active,password_hash")
    .eq("username", params.username)
    .maybeSingle();

  if (error || !data || !(data as AdminUserRow).is_active) {
    return { ok: false as const, reason: "invalid_credentials" };
  }

  const admin = data as AdminUserRow;
  const passwordMatches = await verifyPassword(admin.password_hash, params.password);
  if (!passwordMatches) {
    return { ok: false as const, reason: "invalid_credentials" };
  }

  const session = await createAdminSession({
    adminUserId: admin.id,
    ipHash: params.ipHash,
    userAgent: params.userAgent
  });
  await setSessionCookie(session.token, session.expiresAt);
  await getSupabaseAdmin().from("admin_users").update({ last_login_at: new Date().toISOString() }).eq("id", admin.id);
  return { admin, ok: true as const };
}
