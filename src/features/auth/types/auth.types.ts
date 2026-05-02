import type { Session, User } from "@supabase/supabase-js";

import type { UserProfile } from "@/lib/supabase/database.types";

export type AuthStatus = "idle" | "hydrating" | "authenticated" | "unauthenticated" | "expired" | "error";

export type NetworkStatus = "unknown" | "online" | "offline";

export type AuthErrorCategory =
  | "validation"
  | "auth"
  | "network"
  | "server"
  | "rate_limit"
  | "otp_expired"
  | "otp_invalid"
  | "otp_locked"
  | "otp_rate_limited"
  | "google_native_failed"
  | "google_token_exchange_failed"
  | "session_expired"
  | "token_reuse_suspected"
  | "configuration"
  | "unknown";

export interface AuthErrorState {
  category: AuthErrorCategory;
  message: string;
  code?: string;
}

export interface AuthCooldowns {
  emailOtpUntil?: number;
  passwordResetUntil?: number;
}

export interface AuthStateSnapshot {
  session: Session | null;
  user: User | null;
  profile: UserProfile | null;
}
