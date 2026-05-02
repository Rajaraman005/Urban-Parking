import { AuthApiError } from "@supabase/supabase-js";

import type { AuthErrorCategory, AuthErrorState } from "@/features/auth/types/auth.types";

const messageForCategory: Record<AuthErrorCategory, string> = {
  validation: "Please check the details and try again.",
  auth: "We could not verify those credentials.",
  network: "You appear to be offline. Check your connection and try again.",
  server: "Authentication is temporarily unavailable. Please try again.",
  rate_limit: "Too many attempts. Please wait before trying again.",
  otp_expired: "That code expired. Request a new one and try again.",
  otp_invalid: "That code is not correct. Check it and try again.",
  otp_locked: "That code was locked after too many attempts. Request a new one.",
  otp_rate_limited: "Too many code requests. Please wait before trying again.",
  google_native_failed: "Google sign-in could not be completed on this build.",
  google_token_exchange_failed: "Google sign-in could not start a secure session.",
  session_expired: "Your session expired. Please log in again.",
  token_reuse_suspected: "Your session was ended for security. Please log in again.",
  configuration: "Authentication is not configured correctly.",
  unknown: "Something went wrong. Please try again."
};

export class AppAuthError extends Error {
  category: AuthErrorCategory;
  code?: string;

  constructor(category: AuthErrorCategory, message = messageForCategory[category], code?: string) {
    super(message);
    this.name = "AppAuthError";
    this.category = category;
    this.code = code;
  }
}

const isPostgrestLikeError = (error: unknown): error is { code?: string; message?: string } =>
  typeof error === "object" && error !== null && ("code" in error || "message" in error);

export const toAuthError = (error: unknown): AuthErrorState => {
  if (error instanceof AppAuthError) {
    return {
      category: error.category,
      message: error.message,
      code: error.code
    };
  }

  if (error instanceof AuthApiError) {
    const status = error.status ?? 0;
    const lowerMessage = error.message.toLowerCase();

    if (status === 429) {
      return { category: "rate_limit", message: messageForCategory.rate_limit, code: error.code };
    }

    if (status === 401 && lowerMessage.includes("refresh")) {
      return { category: "session_expired", message: messageForCategory.session_expired, code: error.code };
    }

    if (status >= 500) {
      return { category: "server", message: messageForCategory.server, code: error.code };
    }

    return { category: "auth", message: error.message || messageForCategory.auth, code: error.code };
  }

  if (error instanceof TypeError && /network|fetch|request/i.test(error.message)) {
    return { category: "network", message: messageForCategory.network };
  }

  if (isPostgrestLikeError(error)) {
    if (error.code === "42501") {
      return {
        category: "server",
        message: "Database permissions need to be updated. Please run the latest Supabase migrations.",
        code: error.code
      };
    }

    if (error.message) {
      return { category: "server", message: error.message, code: error.code };
    }
  }

  return {
    category: "unknown",
    message: error instanceof Error ? error.message : messageForCategory.unknown
  };
};
