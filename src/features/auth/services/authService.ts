import NetInfo from "@react-native-community/netinfo";
import { AuthApiError } from "@supabase/supabase-js";
import * as AuthSession from "expo-auth-session";

import { env } from "@/config/env";
import { getDeviceFingerprint } from "@/features/auth/services/deviceFingerprint";
import { AppAuthError, toAuthError } from "@/features/auth/services/authErrors";
import { googleNativeAuth } from "@/features/auth/services/googleNativeAuth";
import type { AuthErrorState } from "@/features/auth/types/auth.types";
import type { UserProfile } from "@/lib/supabase/database.types";
import { isSupabaseConfigured, supabase } from "@/lib/supabase/client";
import { logger } from "@/utils/logger";

type RetryableOperation<T> = () => Promise<T>;
type AuthFunctionName = "request-signup-otp" | "verify-signup-otp";

interface AuthFunctionEnvelope<T> {
  ok: boolean;
  code?: string;
  message?: string;
  retryAfterSeconds?: number;
  data?: T;
}

interface SignupOtpResponse {
  alreadyVerified?: boolean;
  expiresAt?: string;
  resendAvailableAt?: string;
}

const transientCategories = new Set<AuthErrorState["category"]>(["network", "server"]);

const assertConfigured = () => {
  if (!isSupabaseConfigured) {
    throw new AppAuthError("configuration");
  }
};

const assertOnline = async () => {
  const networkState = await NetInfo.fetch();

  if (networkState.isConnected === false || networkState.isInternetReachable === false) {
    throw new AppAuthError("network");
  }
};

const withLimitedRetry = async <T>(operation: RetryableOperation<T>, maxRetries = 1): Promise<T> => {
  let attempt = 0;

  while (true) {
    try {
      await assertOnline();
      return await operation();
    } catch (error) {
      const mappedError = toAuthError(error);

      if (!transientCategories.has(mappedError.category) || attempt >= maxRetries) {
        throw error;
      }

      attempt += 1;
      await new Promise((resolve) => setTimeout(resolve, 350 * attempt));
    }
  }
};

const getRedirectTo = (path = "auth/callback") =>
  AuthSession.makeRedirectUri({
    scheme: env.authRedirectScheme,
    path
  });

const safeFullName = (fullName?: string | null) => fullName?.trim().slice(0, 80) || null;

const isAlreadyRegisteredError = (error: unknown) => {
  const message = error instanceof Error ? error.message.toLowerCase() : "";
  const code = error instanceof AuthApiError ? error.code?.toLowerCase() ?? "" : "";

  return (
    code === "user_already_exists" ||
    code === "email_exists" ||
    message.includes("already registered") ||
    message.includes("already exists")
  );
};

const registeredEmailMessage =
  "This email is already registered. Log in with the correct password, or reset your password.";

const legacyUnconfirmedEmailMessage =
  "This email exists in Supabase Auth from an older signup. Delete it from Authentication > Users, then sign up again.";

const googleExchangeMessage = (message?: string) => {
  const normalized = message?.toLowerCase() ?? "";

  if (normalized.includes("provider") || normalized.includes("unsupported")) {
    return "Enable and configure Google provider in Supabase Auth.";
  }

  if (normalized.includes("audience") || normalized.includes("aud")) {
    return "Supabase Google Client ID does not match this Firebase Web Client ID.";
  }

  if (normalized.includes("secret") || normalized.includes("oauth")) {
    return "Supabase Google provider needs the Google Web Client ID and Client Secret.";
  }

  return "Supabase could not verify this Google account. Check the Google provider setup.";
};

const otpErrorCategoryForCode = (code?: string): AuthErrorState["category"] => {
  switch (code) {
    case "otp_expired":
      return "otp_expired";
    case "otp_invalid":
      return "otp_invalid";
    case "otp_locked":
      return "otp_locked";
    case "otp_rate_limited":
      return "otp_rate_limited";
    default:
      return "server";
  }
};

const isMissingFunctionResponse = (status: number, payload: AuthFunctionEnvelope<unknown> | null) => {
  const message = payload?.message?.toLowerCase() ?? "";
  const code = payload?.code?.toLowerCase() ?? "";

  return status === 404 || code === "not_found" || message.includes("requested function was not found");
};

const callAuthFunction = async <T>(name: AuthFunctionName, body: Record<string, unknown>) => {
  assertConfigured();
  const session = await authService.getCurrentSessionStrict();
  const response = await fetch(`${env.supabaseUrl}/functions/v1/${name}`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      apikey: env.supabaseAnonKey,
      Authorization: `Bearer ${session.access_token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });
  const payload = (await response.json().catch(() => null)) as AuthFunctionEnvelope<T> | null;

  if (!response.ok || !payload?.ok) {
    if (isMissingFunctionResponse(response.status, payload)) {
      throw new AppAuthError(
        "configuration",
        `Supabase Edge Function "${name}" is not deployed. Deploy it before requesting OTP codes.`,
        "function_not_found",
      );
    }

    const category = otpErrorCategoryForCode(payload?.code);
    throw new AppAuthError(category, payload?.message, payload?.code);
  }

  return payload.data as T;
};

export const authService = {
  async getSession() {
    assertConfigured();
    const { data, error } = await supabase.auth.getSession();

    if (error) {
      throw error;
    }

    return data.session;
  },

  async getCurrentSessionStrict() {
    const session = await this.getSession();

    if (!session) {
      throw new AppAuthError("session_expired");
    }

    return session;
  },

  async refreshSessionOrLogout() {
    assertConfigured();

    try {
      const { data, error } = await supabase.auth.refreshSession();

      if (error) {
        logger.warn("session_refresh_failed", { code: error.code });
        await supabase.auth.signOut();
        throw new AppAuthError("session_expired", undefined, error.code);
      }

      return data.session;
    } catch (error) {
      const mapped = toAuthError(error);

      if (mapped.category === "session_expired" || mapped.category === "auth") {
        logger.warn("token_reuse_suspected", { category: mapped.category, code: mapped.code });
      }

      await supabase.auth.signOut();
      throw error;
    }
  },

  async ensureProfile(params?: { fullName?: string | null }): Promise<UserProfile> {
    assertConfigured();
    const session = await this.getCurrentSessionStrict();
    const fullName = safeFullName(params?.fullName ?? session.user.user_metadata?.full_name);
    const synced = await supabase.rpc("ensure_user_profile", {
      p_full_name: fullName
    });

    if (synced.error) {
      logger.error("profile_sync_failed", { code: synced.error.code });
      throw synced.error;
    }

    return synced.data;
  },

  async signUpWithEmailPassword(input: { email: string; password: string; fullName: string }) {
    assertConfigured();
    return withLimitedRetry(async () => {
      const { data, error } = await supabase.auth.signUp({
        email: input.email,
        password: input.password,
        options: {
          data: {
            full_name: input.fullName
          },
          emailRedirectTo: getRedirectTo()
        }
      });

      if (error) {
        if (isAlreadyRegisteredError(error)) {
          const { data: existingData, error: signInError } = await supabase.auth.signInWithPassword({
            email: input.email,
            password: input.password
          });

          if (signInError) {
            const message = signInError.message.toLowerCase().includes("email not confirmed")
              ? legacyUnconfirmedEmailMessage
              : registeredEmailMessage;

            throw new AppAuthError("auth", message, signInError.code ?? "user_already_registered");
          }

          if (existingData.session) {
            await this.ensureProfile({ fullName: input.fullName });
          }

          logger.info("auth_event", { type: "signup_existing_email_resume" });
          return existingData;
        }

        throw error;
      }

      if (data.session) {
        await this.ensureProfile({ fullName: input.fullName });
      }

      logger.info("auth_event", { type: "signup_email" });
      return data;
    });
  },

  async signInWithEmailPassword(input: { email: string; password: string }) {
    assertConfigured();
    return withLimitedRetry(async () => {
      const { data, error } = await supabase.auth.signInWithPassword(input);

      if (error) {
        throw error;
      }

      await this.ensureProfile();
      logger.info("auth_event", { type: "login_email" });
      return data;
    });
  },

  async requestSignupOtp() {
    return withLimitedRetry(async () => {
      const deviceFingerprint = await getDeviceFingerprint();
      const response = await callAuthFunction<SignupOtpResponse>("request-signup-otp", {
        deviceFingerprint
      });

      logger.info("otp_requested", { channel: "email", purpose: "signup_verification" });
      return response;
    });
  },

  async verifySignupOtp(input: { token: string }) {
    const deviceFingerprint = await getDeviceFingerprint();
    const response = await callAuthFunction<SignupOtpResponse>("verify-signup-otp", {
      deviceFingerprint,
      token: input.token
    });
    const refreshed = await supabase.auth.refreshSession();

    if (refreshed.error) {
      throw refreshed.error;
    }

    await this.ensureProfile();
    logger.info("auth_event", { type: "signup_otp_verified" });
    return response;
  },

  async sendPasswordReset(email: string) {
    assertConfigured();
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: getRedirectTo("auth/reset")
    });

    if (error) {
      throw error;
    }
  },

  async updatePassword(password: string) {
    assertConfigured();
    const { data, error } = await supabase.auth.updateUser({ password });

    if (error) {
      throw error;
    }

    return data;
  },

  async exchangeCodeForSession(code: string) {
    assertConfigured();
    const { data, error } = await supabase.auth.exchangeCodeForSession(code);

    if (error) {
      throw error;
    }

    return data;
  },

  async signInWithGoogle() {
    assertConfigured();
    const tokens = await googleNativeAuth.getGoogleTokens();
    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: "google",
      token: tokens.idToken,
      access_token: tokens.accessToken
    });

    if (error) {
      logger.warn("google_token_exchange_failed", {
        errorCode: error.code,
        message: error.message,
        status: error.status ?? null
      });
      throw new AppAuthError("google_token_exchange_failed", googleExchangeMessage(error.message), error.code);
    }

    await this.ensureProfile();
    logger.info("auth_event", { type: "login_google" });
    return data;
  },

  async signOut() {
    assertConfigured();
    const { error } = await supabase.auth.signOut();

    if (error) {
      throw error;
    }

    logger.info("auth_event", { type: "logout" });
    await googleNativeAuth.signOutIfAvailable();
  }
};
