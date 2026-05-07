import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { getSupabaseAdmin } from "@/server/db/supabase";
import { getServerEnv } from "@/server/env";
import { SESSION_COOKIE_NAME, SESSION_TTL_SECONDS } from "./constants";
import { csrfTokenForSession, generateOpaqueToken, safeEqual, sha256Hex } from "./session-crypto";
import type { AdminSessionDTO, AdminSessionRow, AdminUserDTO, AdminUserRow } from "./types";

function toAdminDTO(row: AdminUserRow): AdminUserDTO {
  return {
    id: row.id,
    displayName: row.display_name,
    role: row.role,
    username: row.username
  };
}

export function sessionExpiresAt() {
  return new Date(Date.now() + SESSION_TTL_SECONDS * 1000);
}

export async function createAdminSession(params: {
  adminUserId: string;
  ipHash: string;
  userAgent: string;
}) {
  const token = generateOpaqueToken();
  const tokenHash = sha256Hex(token);
  const expiresAt = sessionExpiresAt();
  const supabase = getSupabaseAdmin();
  const { error } = await supabase.from("admin_sessions").insert({
    admin_user_id: params.adminUserId,
    expires_at: expiresAt.toISOString(),
    ip_hash: params.ipHash,
    session_token_hash: tokenHash,
    user_agent_hash: sha256Hex(params.userAgent)
  });
  if (error) {
    throw new Error("Could not create admin session.");
  }
  return { expiresAt, token };
}

export async function setSessionCookie(token: string, expiresAt: Date) {
  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE_NAME, token, {
    expires: expiresAt,
    httpOnly: true,
    path: "/",
    sameSite: "strict",
    secure: true
  });
}

export async function clearSessionCookie() {
  const cookieStore = await cookies();
  cookieStore.delete(SESSION_COOKIE_NAME);
}

export async function getSessionToken() {
  const cookieStore = await cookies();
  return cookieStore.get(SESSION_COOKIE_NAME)?.value ?? null;
}

export async function getCurrentAdminSession(): Promise<AdminSessionDTO | null> {
  const token = await getSessionToken();
  if (!token) return null;

  const tokenHash = sha256Hex(token);
  const supabase = getSupabaseAdmin();
  const { data: session, error: sessionError } = await supabase
    .from("admin_sessions")
    .select("id,admin_user_id,expires_at,revoked_at,session_token_hash")
    .eq("session_token_hash", tokenHash)
    .is("revoked_at", null)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();

  if (sessionError || !session) return null;

  const sessionRow = session as AdminSessionRow;
  const { data: admin, error: adminError } = await supabase
    .from("admin_users")
    .select("id,username,display_name,role,is_active,password_hash")
    .eq("id", sessionRow.admin_user_id)
    .eq("is_active", true)
    .maybeSingle();

  if (adminError || !admin) return null;

  void supabase.from("admin_sessions").update({ last_seen_at: new Date().toISOString() }).eq("id", sessionRow.id);

  return {
    admin: toAdminDTO(admin as AdminUserRow),
    expiresAt: sessionRow.expires_at,
    id: sessionRow.id,
    sessionToken: token
  };
}

export async function requireAdmin() {
  const session = await getCurrentAdminSession();
  if (!session) {
    redirect("/login");
  }
  return session;
}

export async function revokeCurrentSession() {
  const token = await getSessionToken();
  if (!token) return;
  await getSupabaseAdmin()
    .from("admin_sessions")
    .update({ revoked_at: new Date().toISOString() })
    .eq("session_token_hash", sha256Hex(token))
    .is("revoked_at", null);
}

export async function csrfToken() {
  const token = await getSessionToken();
  if (!token) return "";
  return csrfTokenForSession(token, getServerEnv().ADMIN_SESSION_SECRET);
}

export async function assertValidCsrfToken(candidate: unknown) {
  const token = await getSessionToken();
  if (!token || typeof candidate !== "string") {
    throw new Error("CSRF validation failed.");
  }
  const expected = csrfTokenForSession(token, getServerEnv().ADMIN_SESSION_SECRET);
  if (!safeEqual(expected, candidate)) {
    throw new Error("CSRF validation failed.");
  }
}
