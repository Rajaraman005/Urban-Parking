// eslint-disable-next-line import/no-unresolved
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

import { corsHeaders, getBearerToken, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { hashOtpCode, isSixDigitCode, OTP_MAX_FAILED_ATTEMPTS } from "../_shared/otp.ts";

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key);

  if (!value) {
    throw new Error(`Missing ${key}`);
  }

  return value;
};

const supabaseUrl = requiredEnv("SUPABASE_URL");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const otpPepper = requiredEnv("OTP_PEPPER");

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ ok: false, code: "method_not_allowed", message: "Method not allowed." }, 405);
  }

  try {
    const token = getBearerToken(request);

    if (!token) {
      return jsonResponse({ ok: false, code: "unauthorized", message: "Authentication is required." }, 401);
    }

    const { data: authData, error: authError } = await admin.auth.getUser(token);

    if (authError || !authData.user?.email) {
      return jsonResponse({ ok: false, code: "unauthorized", message: "Authentication is required." }, 401);
    }

    const body = await readJsonBody<{ token?: string }>(request);

    if (!isSixDigitCode(body.token)) {
      return jsonResponse({ ok: false, code: "otp_invalid", message: "Enter the 6-digit verification code." }, 400);
    }

    const email = authData.user.email.trim().toLowerCase();
    const { data: otp, error: otpError } = await admin
      .from("signup_email_otps")
      .select("id, otp_hash, expires_at, used_at, locked_at, failed_attempts")
      .eq("user_id", authData.user.id)
      .eq("email", email)
      .is("used_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (otpError) {
      throw otpError;
    }

    if (!otp) {
      return jsonResponse({ ok: false, code: "otp_expired", message: "Request a new verification code." }, 410);
    }

    if (otp.locked_at) {
      return jsonResponse({ ok: false, code: "otp_locked", message: "This code is locked. Request a new one." }, 423);
    }

    if (otp.used_at) {
      return jsonResponse({ ok: false, code: "otp_expired", message: "This code was already used." }, 410);
    }

    if (new Date(otp.expires_at).getTime() <= Date.now()) {
      await admin
        .from("signup_email_otps")
        .update({ locked_at: new Date().toISOString() })
        .eq("id", otp.id);

      return jsonResponse({ ok: false, code: "otp_expired", message: "This code expired. Request a new one." }, 410);
    }

    const submittedHash = await hashOtpCode(body.token, otpPepper);

    if (submittedHash !== otp.otp_hash) {
      const failedAttempts = Math.min((otp.failed_attempts ?? 0) + 1, OTP_MAX_FAILED_ATTEMPTS);
      const shouldLock = failedAttempts >= OTP_MAX_FAILED_ATTEMPTS;

      await admin
        .from("signup_email_otps")
        .update({
          failed_attempts: failedAttempts,
          locked_at: shouldLock ? new Date().toISOString() : null
        })
        .eq("id", otp.id);

      return jsonResponse(
        {
          ok: false,
          code: shouldLock ? "otp_locked" : "otp_invalid",
          message: shouldLock ? "Too many wrong attempts. Request a new code." : "That code is not correct."
        },
        shouldLock ? 423 : 401
      );
    }

    const verifiedAt = new Date().toISOString();
    const { error: profileError } = await admin
      .from("profiles")
      .update({ email_verified_at: verifiedAt })
      .eq("id", authData.user.id);

    if (profileError) {
      throw profileError;
    }

    const { error: userError } = await admin.auth.admin.updateUserById(authData.user.id, {
      email_confirm: true
    });

    if (userError) {
      throw userError;
    }

    const { error: usedError } = await admin
      .from("signup_email_otps")
      .update({ used_at: verifiedAt })
      .eq("id", otp.id);

    if (usedError) {
      throw usedError;
    }

    return jsonResponse({ ok: true, data: { expiresAt: otp.expires_at } });
  } catch {
    return jsonResponse({ ok: false, code: "server", message: "Verification is temporarily unavailable." }, 500);
  }
});
