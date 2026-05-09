// eslint-disable-next-line import/no-unresolved
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

import { corsHeaders, getBearerToken, getClientIp, jsonResponse, readJsonBody } from "../_shared/http.ts";
import {
  generateOtpCode,
  hashOtpCode,
  isDeviceFingerprint,
  OTP_DEVICE_WINDOW_LIMIT,
  OTP_EXPIRY_MS,
  OTP_IP_WINDOW_LIMIT,
  OTP_RESEND_COOLDOWN_MS,
  OTP_USER_WINDOW_LIMIT,
  OTP_USER_WINDOW_MS
} from "../_shared/otp.ts";

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key);

  if (!value) {
    throw new Error(`Missing ${key}`);
  }

  return value;
};

const supabaseUrl = requiredEnv("SUPABASE_URL");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const resendApiKey = requiredEnv("RESEND_API_KEY");
const resendFromEmail = requiredEnv("RESEND_FROM_EMAIL");
const otpPepper = requiredEnv("OTP_PEPPER");

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

const rateLimited = (message: string, retryAfterSeconds = 60) =>
  jsonResponse({ ok: false, code: "otp_rate_limited", message, retryAfterSeconds }, 429);

const countRecent = async (column: "device_fingerprint" | "request_ip" | "user_id", value: string, since: string) => {
  const { count, error } = await admin
    .from("signup_email_otps")
    .select("id", { count: "exact", head: true })
    .eq(column, value)
    .gte("created_at", since);

  if (error) {
    throw error;
  }

  return count ?? 0;
};

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

    const body = await readJsonBody<{ deviceFingerprint?: string }>(request);
    const deviceFingerprint = isDeviceFingerprint(body.deviceFingerprint) ? body.deviceFingerprint : null;
    const clientIp = getClientIp(request);
    const email = authData.user.email.trim().toLowerCase();
    const now = Date.now();
    const windowStart = new Date(now - OTP_USER_WINDOW_MS).toISOString();

    await admin.from("profiles").upsert(
      {
        id: authData.user.id,
        full_name: authData.user.user_metadata?.full_name ?? null,
        avatar_url: authData.user.user_metadata?.avatar_url ?? null,
        phone: authData.user.phone ?? null
      },
      { onConflict: "id" }
    );

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("email_verified_at")
      .eq("id", authData.user.id)
      .maybeSingle();

    if (profileError) {
      throw profileError;
    }

    if (profile?.email_verified_at) {
      return jsonResponse({ ok: true, data: { alreadyVerified: true } });
    }

    const { data: recentRows, error: recentError } = await admin
      .from("signup_email_otps")
      .select("created_at")
      .eq("user_id", authData.user.id)
      .eq("email", email)
      .gte("created_at", windowStart)
      .order("created_at", { ascending: false });

    if (recentError) {
      throw recentError;
    }

    const latestCreatedAt = recentRows?.[0]?.created_at ? new Date(recentRows[0].created_at).getTime() : 0;
    const resendAvailableAtMs = latestCreatedAt + OTP_RESEND_COOLDOWN_MS;

    if (latestCreatedAt && resendAvailableAtMs > now) {
      return rateLimited(
        "Please wait before requesting another code.",
        Math.ceil((resendAvailableAtMs - now) / 1000)
      );
    }

    if ((recentRows?.length ?? 0) >= OTP_USER_WINDOW_LIMIT) {
      return rateLimited("Too many verification code requests. Please try again later.", 15 * 60);
    }

    if (deviceFingerprint) {
      const deviceCount = await countRecent("device_fingerprint", deviceFingerprint, windowStart);

      if (deviceCount >= OTP_DEVICE_WINDOW_LIMIT) {
        return rateLimited("Too many verification code requests from this device. Please try again later.", 15 * 60);
      }
    }

    if (clientIp) {
      const ipCount = await countRecent("request_ip", clientIp, windowStart);

      if (ipCount >= OTP_IP_WINDOW_LIMIT) {
        return rateLimited("Too many verification code requests from this network. Please try again later.", 15 * 60);
      }
    }

    const code = generateOtpCode();
    const otpHash = await hashOtpCode(code, otpPepper);
    const expiresAt = new Date(now + OTP_EXPIRY_MS).toISOString();
    const resendAvailableAt = new Date(now + OTP_RESEND_COOLDOWN_MS).toISOString();
    const { data: insertedOtp, error: insertError } = await admin
      .from("signup_email_otps")
      .insert({
        user_id: authData.user.id,
        email,
        otp_hash: otpHash,
        expires_at: expiresAt,
        resend_count: (recentRows?.length ?? 0) + 1,
        request_ip: clientIp,
        device_fingerprint: deviceFingerprint
      })
      .select("id")
      .single();

    if (insertError) {
      throw insertError;
    }

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: resendFromEmail,
        to: [email],
        subject: "Your Lotzi verification code",
        html: `<p>Your Lotzi verification code is <strong>${code}</strong>.</p><p>This code expires in 5 minutes.</p>`,
        text: `Your Lotzi verification code is ${code}. This code expires in 5 minutes.`
      })
    });

    if (!resendResponse.ok) {
      await admin
        .from("signup_email_otps")
        .update({ locked_at: new Date().toISOString() })
        .eq("id", insertedOtp.id);

      return jsonResponse(
        { ok: false, code: "server", message: "Verification email could not be sent. Please try again." },
        502
      );
    }

    return jsonResponse({ ok: true, data: { expiresAt, resendAvailableAt } });
  } catch {
    return jsonResponse({ ok: false, code: "server", message: "Verification is temporarily unavailable." }, 500);
  }
});
