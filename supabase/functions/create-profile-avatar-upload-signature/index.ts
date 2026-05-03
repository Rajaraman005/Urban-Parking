// eslint-disable-next-line import/no-unresolved
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

import { corsHeaders, getBearerToken, jsonResponse, readJsonBody } from "../_shared/http.ts";

const MAX_AVATAR_BYTES = 5 * 1024 * 1024;
const MIN_AVATAR_DIMENSION = 256;
const SIGNATURE_TTL_SECONDS = 120;
const SIGNATURE_RATE_LIMIT_PER_MINUTE = 8;
const FUNCTION_VERSION = "profile-avatar-signature-20260502-uuid-v2";
const allowedMimeTypes = new Set(["image/jpeg", "image/jpg", "image/png", "image/webp"]);

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key);

  if (!value) {
    throw new Error(`Missing ${key}`);
  }

  return value;
};

const supabaseUrl = requiredEnv("SUPABASE_URL");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const cloudinaryCloudName = requiredEnv("CLOUDINARY_CLOUD_NAME");
const cloudinaryApiKey = requiredEnv("CLOUDINARY_API_KEY");
const cloudinaryApiSecret = requiredEnv("CLOUDINARY_API_SECRET");
const profileAvatarFolder = Deno.env.get("CLOUDINARY_PROFILE_AVATAR_FOLDER") ?? "urban-parking/profile-avatars";

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

const sha1Hex = async (value: string) => {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-1", bytes);

  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

const signCloudinaryParams = async (params: Record<string, string | number>) => {
  const canonical = Object.keys(params)
    .sort()
    .map((key) => `${key}=${params[key]}`)
    .join("&");

  return sha1Hex(`${canonical}${cloudinaryApiSecret}`);
};

const isUuid = (value: unknown) =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);

const isPositiveSequence = (value: unknown): value is number =>
  typeof value === "number" && Number.isSafeInteger(value) && value > 0;

const functionHeaders = { "x-function-version": FUNCTION_VERSION };
const functionResponse = (body: Record<string, unknown>, status = 200) => jsonResponse(body, status, functionHeaders);
const invalid = (message: string) => functionResponse({ ok: false, code: "validation", message }, 400);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: { ...corsHeaders, ...functionHeaders } });
  }

  if (request.method !== "POST") {
    return functionResponse({ ok: false, code: "method_not_allowed", message: "Method not allowed." }, 405);
  }

  try {
    const token = getBearerToken(request);

    if (!token) {
      return functionResponse({ ok: false, code: "unauthorized", message: "Authentication is required." }, 401);
    }

    const { data: authData, error: authError } = await admin.auth.getUser(token);

    if (authError || !authData.user) {
      return functionResponse({ ok: false, code: "unauthorized", message: "Authentication is required." }, 401);
    }

    const body = await readJsonBody<{
      fileName?: string;
      fileSize?: number | null;
      height?: number;
      mimeType?: string;
      sequence?: number;
      uploadId?: string;
      width?: number;
    }>(request);

    if (!isUuid(body.uploadId)) {
      return invalid("Invalid upload request.");
    }

    if (!isPositiveSequence(body.sequence)) {
      return invalid("Invalid upload sequence.");
    }

    const mimeType = body.mimeType?.toLowerCase();

    if (!mimeType || !allowedMimeTypes.has(mimeType)) {
      return invalid("Upload a JPG, PNG, or WebP profile photo.");
    }

    if (typeof body.fileSize === "number" && body.fileSize > MAX_AVATAR_BYTES) {
      return invalid("Profile photo must be 5MB or smaller.");
    }

    if (
      typeof body.width !== "number" ||
      typeof body.height !== "number" ||
      body.width < MIN_AVATAR_DIMENSION ||
      body.height < MIN_AVATAR_DIMENSION
    ) {
      return invalid("Profile photo must be at least 256px wide and tall.");
    }

    const userId = authData.user.id;
    const { data: existingUpload, error: existingError } = await admin
      .from("profile_avatar_uploads")
      .select("*")
      .eq("upload_id", body.uploadId)
      .maybeSingle();

    if (existingError) {
      throw existingError;
    }

    if (existingUpload) {
      if (existingUpload.user_id !== userId) {
        return functionResponse({ ok: false, code: "forbidden", message: "Upload does not belong to this user." }, 403);
      }

      if (new Date(existingUpload.expires_at).getTime() <= Date.now()) {
        return functionResponse({ ok: false, code: "signature_expired", message: "Upload session expired." }, 410);
      }

      const signature = await signCloudinaryParams({
        public_id: existingUpload.public_id,
        timestamp: existingUpload.signature_timestamp
      });

      console.info(JSON.stringify({ event: "profile_avatar_signature_requested", reused: true }));

      return functionResponse({
        ok: true,
        data: {
          apiKey: cloudinaryApiKey,
          cloudName: cloudinaryCloudName,
          expiresAt: existingUpload.expires_at,
          folder: `${profileAvatarFolder}/${userId}`,
          publicId: existingUpload.public_id,
          signature,
          timestamp: existingUpload.signature_timestamp,
          uploadId: existingUpload.upload_id
        }
      });
    }

    const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();
    const { count, error: rateError } = await admin
      .from("profile_avatar_uploads")
      .select("upload_id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", oneMinuteAgo);

    if (rateError) {
      throw rateError;
    }

    if ((count ?? 0) >= SIGNATURE_RATE_LIMIT_PER_MINUTE) {
      return functionResponse({ ok: false, code: "rate_limit", message: "Too many profile photo attempts. Try again shortly." }, 429);
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const expiresAt = new Date(Date.now() + SIGNATURE_TTL_SECONDS * 1000).toISOString();
    const fullPublicId = `${profileAvatarFolder}/${userId}/${body.uploadId}`;
    const signature = await signCloudinaryParams({
      public_id: fullPublicId,
      timestamp
    });

    const { error: insertError } = await admin.from("profile_avatar_uploads").insert({
      expires_at: expiresAt,
      public_id: fullPublicId,
      sequence: body.sequence,
      signature_timestamp: timestamp,
      status: "signed",
      upload_id: body.uploadId,
      user_id: userId
    });

    if (insertError) {
      throw insertError;
    }

    console.info(JSON.stringify({ event: "profile_avatar_signature_requested", reused: false }));

    return functionResponse({
      ok: true,
      data: {
        apiKey: cloudinaryApiKey,
        cloudName: cloudinaryCloudName,
        expiresAt,
        folder: `${profileAvatarFolder}/${userId}`,
        publicId: fullPublicId,
        signature,
        timestamp,
        uploadId: body.uploadId
      }
    });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "profile_avatar_signature_failed",
        message: error instanceof Error ? error.message : "unknown"
      })
    );

    return functionResponse({ ok: false, code: "server", message: "Profile photo upload is temporarily unavailable." }, 500);
  }
});
