// eslint-disable-next-line import/no-unresolved
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

import {
  corsHeaders,
  getBearerToken,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";

const MAX_PHOTO_BYTES = 25 * 1024 * 1024;
const FUNCTION_VERSION = "parking-photo-complete-20260507-v1";
const isValidCloudinaryImageFormat = (value: unknown) =>
  typeof value === "string" && /^[a-z0-9]{2,12}$/i.test(value.trim());

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
const cloudinaryUploadFolder =
  Deno.env.get("CLOUDINARY_UPLOAD_FOLDER") ?? "lotzi/listing-photos";

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const isUuid = (value: unknown) =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );

const normalizeCloudinaryPublicId = (value: unknown) =>
  typeof value === "string"
    ? value
        .trim()
        .replace(/^\/+/, "")
        .replace(/\.[a-z0-9]+$/i, "")
    : "";

const cloudinarySecureUrlFor = (publicId: string) =>
  `https://res.cloudinary.com/${cloudinaryCloudName}/image/upload/${publicId
    .split("/")
    .map(encodeURIComponent)
    .join("/")}`;

const numberFrom = (...values: unknown[]) => {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === "string" && value.trim().length > 0) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
  }

  return null;
};

const functionHeaders = { "x-function-version": FUNCTION_VERSION };
const functionResponse = (body: Record<string, unknown>, status = 200) =>
  jsonResponse(body, status, functionHeaders);
const invalid = (message: string, code = "validation") =>
  functionResponse({ ok: false, code, message }, 400);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: { ...corsHeaders, ...functionHeaders },
    });
  }

  if (request.method !== "POST") {
    return functionResponse(
      { ok: false, code: "method_not_allowed", message: "Method not allowed." },
      405,
    );
  }

  try {
    const token = getBearerToken(request);

    if (!token) {
      return functionResponse(
        {
          ok: false,
          code: "unauthorized",
          message: "Authentication is required.",
        },
        401,
      );
    }

    const { data: authData, error: authError } =
      await admin.auth.getUser(token);

    if (authError || !authData.user) {
      return functionResponse(
        {
          ok: false,
          code: "unauthorized",
          message: "Authentication is required.",
        },
        401,
      );
    }

    const body = await readJsonBody<{
      bytes?: number;
      clientBytes?: number;
      clientHeight?: number;
      clientMimeType?: string;
      clientWidth?: number;
      cloudinaryPublicId?: string;
      format?: string;
      height?: number;
      parkingSpaceId?: string;
      publicId?: string;
      secureUrl?: string;
      width?: number;
    }>(request);

    if (!isUuid(body.parkingSpaceId)) {
      return invalid("Invalid parking space.", "invalid_parking_space_id");
    }

    const publicId = normalizeCloudinaryPublicId(body.publicId);
    if (publicId.length === 0) {
      return invalid("Invalid uploaded photo.", "invalid_uploaded_photo");
    }

    const expectedPrefix = `${cloudinaryUploadFolder}/${authData.user.id}/${body.parkingSpaceId}/`;
    const canonicalPublicId = publicId.startsWith(expectedPrefix)
      ? publicId
      : `${expectedPrefix}${publicId}`;

    if (!canonicalPublicId.startsWith(expectedPrefix)) {
      return functionResponse(
        {
          ok: false,
          code: "forbidden",
          message: "Uploaded photo does not belong to this draft.",
        },
        403,
      );
    }

    const byteCount = numberFrom(body.bytes, body.clientBytes);
    const width = numberFrom(body.width, body.clientWidth);
    const height = numberFrom(body.height, body.clientHeight);
    const secureUrl = cloudinarySecureUrlFor(canonicalPublicId);

    if (
      typeof byteCount !== "number" ||
      byteCount <= 0 ||
      byteCount > MAX_PHOTO_BYTES
    ) {
      return invalid(
        "Uploaded photo is larger than the service can process.",
        "invalid_photo_metadata",
      );
    }

    if (
      typeof width !== "number" ||
      typeof height !== "number" ||
      width <= 0 ||
      height <= 0
    ) {
      return invalid(
        "Invalid uploaded photo dimensions.",
        "invalid_dimensions",
      );
    }

    const format = body.format ?? body.clientMimeType?.split("/").pop();
    if (!isValidCloudinaryImageFormat(format)) {
      return invalid("Unsupported photo format.", "invalid_photo_format");
    }

    const { data: draft, error: draftError } = await admin
      .from("parking_spaces")
      .select("id, host_id, status")
      .eq("id", body.parkingSpaceId)
      .eq("host_id", authData.user.id)
      .eq("status", "draft")
      .maybeSingle();

    if (draftError) {
      throw draftError;
    }

    if (!draft) {
      return functionResponse(
        {
          ok: false,
          code: "forbidden",
          message: "Draft listing was not found.",
        },
        403,
      );
    }

    const { count, error: countError } = await admin
      .from("parking_space_photos")
      .select("id", { count: "exact", head: true })
      .eq("parking_space_id", body.parkingSpaceId);

    if (countError) {
      throw countError;
    }

    const { data: existing, error: existingError } = await admin
      .from("parking_space_photos")
      .select("id")
      .eq("parking_space_id", body.parkingSpaceId)
      .eq("public_id", canonicalPublicId)
      .maybeSingle();

    if (existingError) {
      throw existingError;
    }

    if (!existing && (count ?? 0) >= 5) {
      return invalid("Maximum photo count reached.");
    }

    const photoRecord: Record<string, unknown> = {
      height: Math.round(height),
      host_id: authData.user.id,
      parking_space_id: body.parkingSpaceId,
      public_id: canonicalPublicId,
      secure_url: secureUrl,
      upload_status: "linked",
      width: Math.round(width),
    };

    if (!existing) {
      photoRecord.sort_order = count ?? 0;
    }

    const { error: upsertError } = await admin
      .from("parking_space_photos")
      .upsert(photoRecord, { onConflict: "parking_space_id,public_id" });

    if (upsertError) {
      throw upsertError;
    }

    const { data: photos, error: photosError } = await admin
      .from("parking_space_photos")
      .select(
        "id, public_id, secure_url, width, height, sort_order, upload_status",
      )
      .eq("parking_space_id", body.parkingSpaceId)
      .order("sort_order", { ascending: true });

    if (photosError) {
      throw photosError;
    }

    const { data: draftWithPhotos, error: reloadError } = await admin
      .from("parking_spaces")
      .select(
        "*, parking_space_photos(id, public_id, secure_url, width, height, sort_order, upload_status)",
      )
      .eq("id", body.parkingSpaceId)
      .single();

    if (reloadError) {
      throw reloadError;
    }

    console.info(JSON.stringify({ event: "parking_photo_upload_completed" }));
    return functionResponse({
      ok: true,
      data: { draft: draftWithPhotos, photos },
    });
  } catch (error) {
    console.error(
      JSON.stringify({
        event: "parking_photo_completion_failed",
        message: error instanceof Error ? error.message : "unknown",
      }),
    );

    return functionResponse(
      {
        ok: false,
        code: "server",
        message: "Parking photo could not be saved.",
      },
      500,
    );
  }
});
