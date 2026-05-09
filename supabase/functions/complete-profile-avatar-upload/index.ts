// eslint-disable-next-line import/no-unresolved
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

import { corsHeaders, getBearerToken, jsonResponse, readJsonBody } from "../_shared/http.ts";

const MAX_AVATAR_BYTES = 5 * 1024 * 1024;
const MIN_AVATAR_DIMENSION = 256;
const COMPLETION_RATE_LIMIT_PER_UPLOAD = 8;
const FUNCTION_VERSION = "profile-avatar-complete-20260502-uuid-v2";
const allowedFormats = new Set(["jpg", "jpeg", "png", "webp"]);

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key);

  if (!value) {
    throw new Error(`Missing ${key}`);
  }

  return value;
};

const supabaseUrl = requiredEnv("SUPABASE_URL");
const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
const profileAvatarFolder = Deno.env.get("CLOUDINARY_PROFILE_AVATAR_FOLDER") ?? "lotzi/profile-avatars";

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

const isUuid = (value: unknown) =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);

const isPositiveSequence = (value: unknown): value is number =>
  typeof value === "number" && Number.isSafeInteger(value) && value > 0;

const isCloudinarySecureUrl = (value: unknown) => {
  if (typeof value !== "string") {
    return false;
  }

  try {
    const url = new URL(value);

    return url.protocol === "https:" && url.hostname === "res.cloudinary.com";
  } catch {
    return false;
  }
};

const enqueueCleanup = async (publicId: string, reason: string) => {
  const now = new Date().toISOString();
  const { error } = await admin.from("avatar_cleanup_queue").upsert(
    {
      next_attempt_at: now,
      public_id: publicId,
      reason,
      updated_at: now
    },
    { onConflict: "public_id" }
  );

  if (error) {
    console.warn(JSON.stringify({ event: "profile_avatar_cleanup_failed" }));
  } else {
    console.info(JSON.stringify({ event: "profile_avatar_cleanup_queued", reason }));
  }
};

const functionHeaders = { "x-function-version": FUNCTION_VERSION };
const functionResponse = (body: Record<string, unknown>, status = 200) => jsonResponse(body, status, functionHeaders);
const invalid = (message: string, code = "validation") => functionResponse({ ok: false, code, message }, 400);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: { ...corsHeaders, ...functionHeaders } });
  }

  if (request.method !== "POST") {
    return functionResponse({ ok: false, code: "method_not_allowed", message: "Method not allowed." }, 405);
  }

  let cleanupPublicId: string | null = null;
  let profileUpdated = false;

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
      bytes?: number;
      format?: string;
      height?: number;
      publicId?: string;
      secureUrl?: string;
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

    if (typeof body.publicId !== "string" || body.publicId.trim().length === 0) {
      return invalid("Invalid uploaded image.");
    }

    cleanupPublicId = body.publicId;

    if (!isCloudinarySecureUrl(body.secureUrl)) {
      return invalid("Invalid uploaded image URL.");
    }

    if (typeof body.bytes !== "number" || body.bytes <= 0 || body.bytes > MAX_AVATAR_BYTES) {
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

    const format = body.format?.toLowerCase();

    if (!format || !allowedFormats.has(format)) {
      return invalid("Upload a JPG, PNG, or WebP profile photo.");
    }

    const userId = authData.user.id;
    const expectedPublicId = `${profileAvatarFolder}/${userId}/${body.uploadId}`;

    if (body.publicId !== expectedPublicId) {
      return functionResponse({ ok: false, code: "forbidden", message: "Uploaded image does not belong to this user." }, 403);
    }

    const { data: upload, error: uploadError } = await admin
      .from("profile_avatar_uploads")
      .select("*")
      .eq("upload_id", body.uploadId)
      .maybeSingle();

    if (uploadError) {
      throw uploadError;
    }

    if (!upload || upload.user_id !== userId) {
      return functionResponse({ ok: false, code: "forbidden", message: "Upload session was not found." }, 403);
    }

    if (upload.status === "completed") {
      const { data: profile, error: profileError } = await admin.from("profiles").select("*").eq("id", userId).single();

      if (profileError) {
        throw profileError;
      }

      console.info(JSON.stringify({ event: "profile_avatar_completion_retry" }));
      return functionResponse({ ok: true, data: { profile } });
    }

    const attemptCount = Number(upload.completion_attempt_count ?? 0);

    if (attemptCount >= COMPLETION_RATE_LIMIT_PER_UPLOAD) {
      return functionResponse({ ok: false, code: "rate_limit", message: "Too many completion attempts. Try again shortly." }, 429);
    }

    await admin
      .from("profile_avatar_uploads")
      .update({ completion_attempt_count: attemptCount + 1 })
      .eq("upload_id", body.uploadId);

    if (new Date(upload.expires_at).getTime() <= Date.now()) {
      await admin
        .from("profile_avatar_uploads")
        .update({ status: "cleanup_pending", secure_url: body.secureUrl })
        .eq("upload_id", body.uploadId);
      await enqueueCleanup(body.publicId, "expired_avatar_upload");

      return functionResponse({ ok: false, code: "signature_expired", message: "Upload session expired." }, 410);
    }

    const { data: latestUpload, error: latestError } = await admin
      .from("profile_avatar_uploads")
      .select("upload_id, sequence")
      .eq("user_id", userId)
      .order("sequence", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (latestError) {
      throw latestError;
    }

    if (latestUpload && Number(latestUpload.sequence) > body.sequence) {
      await admin
        .from("profile_avatar_uploads")
        .update({ status: "cleanup_pending", secure_url: body.secureUrl })
        .eq("upload_id", body.uploadId);
      await enqueueCleanup(body.publicId, "stale_avatar_upload");

      console.warn(JSON.stringify({ event: "profile_avatar_stale_completion_rejected" }));
      return functionResponse({ ok: false, code: "stale_avatar_upload", message: "A newer profile photo is already active." }, 409);
    }

    const { data: currentProfile, error: currentProfileError } = await admin
      .from("profiles")
      .select("*")
      .eq("id", userId)
      .single();

    if (currentProfileError) {
      throw currentProfileError;
    }

    const { data: updatedProfile, error: updateProfileError } = await admin
      .from("profiles")
      .update({
        avatar_public_id: body.publicId,
        avatar_url: body.secureUrl,
        version: (currentProfile.version ?? 0) + 1
      })
      .eq("id", userId)
      .select("*")
      .single();

    if (updateProfileError) {
      throw updateProfileError;
    }

    profileUpdated = true;

    const { error: completeError } = await admin
      .from("profile_avatar_uploads")
      .update({
        secure_url: body.secureUrl,
        status: "completed"
      })
      .eq("upload_id", body.uploadId);

    if (completeError) {
      throw completeError;
    }

    if (currentProfile.avatar_public_id && currentProfile.avatar_public_id !== body.publicId) {
      await enqueueCleanup(currentProfile.avatar_public_id, "profile_avatar_replaced");
    }

    console.info(JSON.stringify({ event: "profile_avatar_upload_completed" }));

    return functionResponse({ ok: true, data: { profile: updatedProfile } });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "profile_avatar_completion_failed",
        message: error instanceof Error ? error.message : "unknown"
      })
    );

    if (cleanupPublicId && !profileUpdated) {
      await enqueueCleanup(cleanupPublicId, "avatar_completion_failed");
    }

    return functionResponse({ ok: false, code: "server", message: "Profile photo could not be saved." }, 500);
  }
});
