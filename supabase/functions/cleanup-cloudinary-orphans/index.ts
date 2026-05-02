import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key);

  if (!value) {
    throw new Error(`Missing ${key}`);
  }

  return value;
};

const cloudinaryCloudName = requiredEnv("CLOUDINARY_CLOUD_NAME");
const cloudinaryApiKey = requiredEnv("CLOUDINARY_API_KEY");
const cloudinaryApiSecret = requiredEnv("CLOUDINARY_API_SECRET");
const cleanupSecret = requiredEnv("CLOUDINARY_CLEANUP_SECRET");

const isSafePublicId = (value: unknown) =>
  typeof value === "string" && /^urban-parking\/listing-photos\/[0-9a-f-]+\/[0-9a-f-]+\/[0-9a-f-]+$/i.test(value);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ ok: false, code: "method_not_allowed", message: "Method not allowed." }, 405);
  }

  if (request.headers.get("x-cleanup-secret") !== cleanupSecret) {
    return jsonResponse({ ok: false, code: "unauthorized", message: "Unauthorized." }, 401);
  }

  const body = await readJsonBody<{ publicIds?: unknown[] }>(request);
  const publicIds = (body.publicIds ?? []).filter(isSafePublicId);

  if (publicIds.length === 0) {
    return jsonResponse({ ok: true, data: { deleted: 0 } });
  }

  const auth = btoa(`${cloudinaryApiKey}:${cloudinaryApiSecret}`);
  const response = await fetch(`https://api.cloudinary.com/v1_1/${cloudinaryCloudName}/resources/image/upload`, {
    method: "DELETE",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ public_ids: publicIds })
  });

  if (!response.ok) {
    return jsonResponse({ ok: false, code: "server", message: "Cloudinary cleanup failed." }, 502);
  }

  return jsonResponse({ ok: true, data: { deleted: publicIds.length } });
});
