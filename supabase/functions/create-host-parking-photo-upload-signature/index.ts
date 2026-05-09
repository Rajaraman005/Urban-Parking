// eslint-disable-next-line import/no-unresolved
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

import { corsHeaders, getBearerToken, jsonResponse, readJsonBody } from "../_shared/http.ts";

const allowedMimeTypes = new Set(["image/jpeg", "image/jpg", "image/png", "image/webp", "image/heic", "image/heif"]);

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
const cloudinaryUploadFolder = Deno.env.get("CLOUDINARY_UPLOAD_FOLDER") ?? "lotzi/listing-photos";

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

const invalid = (message: string) => jsonResponse({ ok: false, code: "validation", message }, 400);

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

    if (authError || !authData.user) {
      return jsonResponse({ ok: false, code: "unauthorized", message: "Authentication is required." }, 401);
    }

    const body = await readJsonBody<{
      draftId?: string;
      fileName?: string;
      fileSize?: number | null;
      height?: number;
      mimeType?: string;
      width?: number;
    }>(request);

    if (!isUuid(body.draftId)) {
      return invalid("Invalid parking draft.");
    }

    const mimeType = body.mimeType?.toLowerCase();

    if (!mimeType || !allowedMimeTypes.has(mimeType)) {
      return invalid("Unsupported image type.");
    }

    const { data: draft, error: draftError } = await admin
      .from("parking_listing_drafts")
      .select("id, host_id, status")
      .eq("id", body.draftId)
      .eq("host_id", authData.user.id)
      .eq("status", "draft")
      .maybeSingle();

    if (draftError) {
      throw draftError;
    }

    if (!draft) {
      return jsonResponse({ ok: false, code: "forbidden", message: "Draft listing was not found." }, 403);
    }

    const { count, error: countError } = await admin
      .from("parking_listing_draft_photos")
      .select("id", { count: "exact", head: true })
      .eq("draft_id", body.draftId)
      .eq("upload_status", "linked");

    if (countError) {
      throw countError;
    }

    if ((count ?? 0) >= 5) {
      return invalid("Maximum photo count reached.");
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const clientUploadId = crypto.randomUUID();
    const safePrefix = `${authData.user.id}/${body.draftId}`;
    const folder = `${cloudinaryUploadFolder}/${safePrefix}`;
    const publicId = `${folder}/${clientUploadId}`;
    const signature = await signCloudinaryParams({
      public_id: publicId,
      timestamp
    });

    return jsonResponse({
      ok: true,
      data: {
        apiKey: cloudinaryApiKey,
        clientUploadId,
        cloudName: cloudinaryCloudName,
        folder,
        publicId,
        signature,
        timestamp
      }
    });
  } catch {
    return jsonResponse({ ok: false, code: "server", message: "Photo upload is temporarily unavailable." }, 500);
  }
});
