import "server-only";
import { getSupabaseAdmin } from "@/server/db/supabase";
import { hashPassword, verifyPassword } from "@/server/auth/password";

export interface AdminSessionListItem {
  createdAt: string;
  expiresAt: string;
  id: string;
  isCurrent: boolean;
  lastSeenAt?: string;
}

export async function listAdminSessions(adminUserId: string, currentSessionId: string) {
  const { data, error } = await getSupabaseAdmin()
    .from("admin_sessions")
    .select("id,created_at,last_seen_at,expires_at")
    .eq("admin_user_id", adminUserId)
    .is("revoked_at", null)
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false });

  if (error) throw new Error("Could not load sessions.");

  return (data ?? []).map((row) => ({
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    id: row.id,
    isCurrent: row.id === currentSessionId,
    lastSeenAt: row.last_seen_at ?? undefined
  })) satisfies AdminSessionListItem[];
}

export async function changeAdminPassword(params: {
  adminUserId: string;
  currentPassword: string;
  newPassword: string;
}) {
  const { data, error } = await getSupabaseAdmin()
    .from("admin_users")
    .select("id,password_hash")
    .eq("id", params.adminUserId)
    .eq("is_active", true)
    .maybeSingle();

  if (error || !data) {
    throw new Error("Admin account was not found.");
  }

  const matches = await verifyPassword(data.password_hash, params.currentPassword);
  if (!matches) {
    throw new Error("Current password is incorrect.");
  }

  const passwordHash = await hashPassword(params.newPassword);
  const { error: updateError } = await getSupabaseAdmin()
    .from("admin_users")
    .update({ password_hash: passwordHash, password_changed_at: new Date().toISOString() })
    .eq("id", params.adminUserId);

  if (updateError) throw new Error("Could not update password.");
}

export async function revokeOtherSessions(adminUserId: string, currentSessionId: string) {
  const { error } = await getSupabaseAdmin()
    .from("admin_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("admin_user_id", adminUserId)
    .neq("id", currentSessionId)
    .is("revoked_at", null);

  if (error) throw new Error("Could not revoke sessions.");
}
