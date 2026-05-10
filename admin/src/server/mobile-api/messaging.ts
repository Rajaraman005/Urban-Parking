import "server-only";

import { z } from "zod";
import {
  apiError,
  jsonResponse,
  readJsonBody,
  sha256Hex,
  type MobileApiContext,
} from "./core";
import {
  currentUserIdFromBearer,
  timedUserSupabase,
  withAbortSignal,
} from "./supabase";

type SupabaseErrorLike = {
  code?: string;
  message?: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const uuidSchema = z.string().regex(uuidPattern, "UUID is invalid.");
const messageTypeSchema = z.enum(["text", "attachment", "property_card"]);
const reportReasonSchema = z.enum([
  "spam",
  "harassment",
  "fraud",
  "unsafe_content",
  "other",
]);

const startConversationSchema = z.object({
  propertyId: uuidSchema,
});

const sendMessageSchema = z.object({
  body: z.string().max(5000).optional().nullable(),
  clientMessageId: uuidSchema,
  messageType: messageTypeSchema.default("text"),
  metadata: z.unknown().optional(),
  replyToMessageId: uuidSchema.optional().nullable(),
});

const markReadSchema = z.object({
  lastSeenMessageSeq: z.number().int().nonnegative().optional().nullable(),
});

const attachmentSlotSchema = z.object({
  byteSize: z.number().int().positive().max(26_214_400),
  conversationId: uuidSchema,
  fileName: z.string().trim().min(1).max(160),
  height: z.number().int().positive().optional().nullable(),
  messageId: uuidSchema,
  mimeType: z.string().trim().min(3).max(120),
  width: z.number().int().positive().optional().nullable(),
});

const blockUserSchema = z.object({
  blockedId: uuidSchema,
  reason: z.string().max(500).optional().nullable(),
});

const reportMessageSchema = z.object({
  conversationId: uuidSchema,
  details: z.string().max(2000).optional().nullable(),
  messageId: uuidSchema,
  reason: reportReasonSchema,
});

const notificationReadSchema = z.object({
  notificationId: uuidSchema.optional().nullable(),
});

export async function handleStartConversation(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  await enforceUserRateLimit(context, userId, "conversation-start", 30, 60);

  const body = startConversationSchema.parse(await readJsonBody(context.request));
  context.log.listing_id = body.propertyId;
  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("start_or_get_property_conversation", {
        p_property_id: body.propertyId,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  context.log.conversation_id = stringField(result.data, "id");
  return jsonResponse(result.data, { requestId: context.requestId, status: 200 });
}

export async function handleListConversations(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);

  const url = new URL(context.request.url);
  const limit = boundedInt(url.searchParams.get("limit"), 20, 1, 50);
  const beforeLastMessageAt = nullableDateParam(
    url.searchParams.get("beforeLastMessageAt"),
  );
  const beforeId = nullableUuidParam(url.searchParams.get("beforeId"));

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("list_conversations", {
        p_before_id: beforeId,
        p_before_last_message_at: beforeLastMessageAt,
        p_limit: limit,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse(
    { items: Array.isArray(result.data) ? result.data : [] },
    { requestId: context.requestId, status: 200 },
  );
}

export async function handleListMessages(
  context: MobileApiContext,
  routeContext?: unknown,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const conversationId = uuidSchema.parse((await paramsFromRouteContext(routeContext)).id);
  context.log.conversation_id = conversationId;

  const url = new URL(context.request.url);
  const limit = boundedInt(url.searchParams.get("limit"), 50, 1, 100);
  const beforeSeq = nullableBigIntNumber(url.searchParams.get("beforeSeq"));

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("list_conversation_messages", {
        p_before_message_seq: beforeSeq,
        p_conversation_id: conversationId,
        p_limit: limit,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse(
    { items: Array.isArray(result.data) ? result.data : [] },
    { requestId: context.requestId, status: 200 },
  );
}

export async function handleSendMessage(
  context: MobileApiContext,
  routeContext?: unknown,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  await enforceUserRateLimit(context, userId, "message-send", 120, 60);

  const conversationId = uuidSchema.parse((await paramsFromRouteContext(routeContext)).id);
  context.log.conversation_id = conversationId;
  const body = sendMessageSchema.parse(await readJsonBody(context.request));
  if (body.messageType === "text" && !body.body?.trim()) {
    throw apiError(422, "MESSAGE_TEXT_REQUIRED", "Message text is required.");
  }

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("send_message", {
        p_body: body.body ?? null,
        p_client_message_id: body.clientMessageId,
        p_conversation_id: conversationId,
        p_message_type: body.messageType,
        p_metadata: body.metadata ?? {},
        p_reply_to_message_id: body.replyToMessageId ?? null,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  context.log.message_id = stringField(result.data, "id");
  return jsonResponse(result.data, { requestId: context.requestId, status: 201 });
}

export async function handleMarkConversationRead(
  context: MobileApiContext,
  routeContext?: unknown,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const conversationId = uuidSchema.parse((await paramsFromRouteContext(routeContext)).id);
  context.log.conversation_id = conversationId;
  const body = markReadSchema.parse(await readJsonBody(context.request));

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("mark_conversation_read", {
        p_conversation_id: conversationId,
        p_last_seen_message_seq: body.lastSeenMessageSeq ?? null,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse(result.data, { requestId: context.requestId, status: 200 });
}

export async function handleCreateAttachmentSlot(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  await enforceUserRateLimit(context, userId, "attachment-slot", 60, 3600);

  const body = attachmentSlotSchema.parse(await readJsonBody(context.request));
  context.log.conversation_id = body.conversationId;
  context.log.message_id = body.messageId;
  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("create_message_attachment_slot", {
        p_byte_size: body.byteSize,
        p_conversation_id: body.conversationId,
        p_file_name: body.fileName,
        p_height: body.height ?? null,
        p_message_id: body.messageId,
        p_mime_type: body.mimeType,
        p_width: body.width ?? null,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse(result.data, { requestId: context.requestId, status: 201 });
}

export async function handleCompleteAttachmentUpload(
  context: MobileApiContext,
  routeContext?: unknown,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const attachmentId = uuidSchema.parse((await paramsFromRouteContext(routeContext)).id);

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("complete_message_attachment_upload", {
        p_attachment_id: attachmentId,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse(result.data, { requestId: context.requestId, status: 200 });
}

export async function handleBlockUser(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  await enforceUserRateLimit(context, userId, "block-user", 30, 3600);

  const body = blockUserSchema.parse(await readJsonBody(context.request));
  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("block_user", {
        p_blocked_id: body.blockedId,
        p_reason: body.reason ?? null,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse(result.data, { requestId: context.requestId, status: 201 });
}

export async function handleReportMessage(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  await enforceUserRateLimit(context, userId, "report-message", 20, 3600);

  const body = reportMessageSchema.parse(await readJsonBody(context.request));
  context.log.conversation_id = body.conversationId;
  context.log.message_id = body.messageId;
  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("report_message", {
        p_conversation_id: body.conversationId,
        p_details: body.details ?? null,
        p_message_id: body.messageId,
        p_reason: body.reason,
      }),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse(result.data, { requestId: context.requestId, status: 201 });
}

export async function handleListNotifications(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const url = new URL(context.request.url);
  const limit = boundedInt(url.searchParams.get("limit"), 30, 1, 100);

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client
        .from("notifications")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(limit),
      context.signal,
    ),
  );

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse(
    { items: Array.isArray(result.data) ? result.data : [] },
    { requestId: context.requestId, status: 200 },
  );
}

export async function handleMarkNotificationRead(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const body = notificationReadSchema.parse(await readJsonBody(context.request));

  const result = await timedUserSupabase(context, (client) => {
    const query = client
      .from("notifications")
      .update({ read_at: new Date().toISOString(), status: "read" })
      .eq("recipient_id", userId);
    return withAbortSignal(
      body.notificationId ? query.eq("id", body.notificationId) : query.eq("status", "unread"),
      context.signal,
    );
  });

  if (result.error) throw messagingSupabaseError(result.error);
  return jsonResponse({ ok: true }, { requestId: context.requestId, status: 200 });
}

async function requireUserId(context: MobileApiContext) {
  const userId = await currentUserIdFromBearer(context);
  if (!userId) {
    throw apiError(401, "AUTH_REQUIRED", "Sign in before using messages.");
  }
  return userId;
}

async function enforceUserRateLimit(
  context: MobileApiContext,
  userId: string,
  bucket: string,
  limit: number,
  windowSeconds: number,
) {
  const mode = messagingRateLimitMode();
  if (mode === "disabled") return;

  const restUrl = process.env.UPSTASH_REDIS_REST_URL?.trim();
  const restToken = process.env.UPSTASH_REDIS_REST_TOKEN?.trim();
  if (!restUrl || !restToken) return;

  const key = `mobile-api:messaging:${bucket}:${Math.floor(
    Date.now() / (windowSeconds * 1000),
  )}:${sha256Hex(userId)}`;
  try {
    const response = await fetch(`${restUrl.replace(/\/$/, "")}/pipeline`, {
      body: JSON.stringify([
        ["INCR", key],
        ["EXPIRE", key, windowSeconds],
      ]),
      headers: {
        Authorization: `Bearer ${restToken}`,
        "Content-Type": "application/json",
      },
      method: "POST",
      signal: context.signal,
    });
    const payload = (await response.json()) as Array<{ result?: unknown }>;
    const count = Number(payload[0]?.result ?? 0);
    const limited = Number.isFinite(count) && count > limit;
    context.log.rate_limited = limited;
    if (limited && mode === "enforce") {
      throw apiError(
        429,
        "MESSAGING_RATE_LIMITED",
        "Too many messaging actions. Try again later.",
        { retryAfter: windowSeconds },
      );
    }
  } catch (error) {
    if (error instanceof Error && error.name === "MobileApiError") throw error;
    context.log.error_code = "MESSAGING_RATE_LIMITER_OPEN";
  }
}

function messagingRateLimitMode() {
  const configured = process.env.MESSAGING_RATE_LIMIT_MODE?.trim();
  if (
    configured === "disabled" ||
    configured === "dry-run" ||
    configured === "enforce"
  ) {
    return configured;
  }
  return process.env.VERCEL_ENV === "production" ? "enforce" : "dry-run";
}

function messagingSupabaseError(error: SupabaseErrorLike) {
  const message = error.message ?? "Messaging request failed.";
  const lowerMessage = message.toLowerCase();
  const code = error.code ?? "MESSAGING_DATABASE_ERROR";

  if (code === "23505" || lowerMessage.includes("client message id")) {
    return apiError(
      409,
      "MESSAGE_IDEMPOTENCY_CONFLICT",
      "This message retry key was already used with different content.",
    );
  }
  if (code === "42501") {
    return apiError(403, "MESSAGING_FORBIDDEN", message);
  }
  if (code === "P0002") {
    return apiError(404, "MESSAGING_NOT_FOUND", message);
  }
  if (code === "23514") {
    return apiError(422, "MESSAGING_VALIDATION_FAILED", message);
  }
  if (code === "57014") {
    return apiError(
      503,
      "BACKEND_TIMEOUT",
      "Messaging is temporarily slow. Please try again.",
      { retryAfter: 2 },
    );
  }

  return apiError(500, "MESSAGING_DATABASE_ERROR", "Messaging service failed.");
}

async function paramsFromRouteContext(routeContext?: unknown) {
  const rawParams =
    typeof routeContext === "object" &&
    routeContext !== null &&
    "params" in routeContext
      ? (routeContext as { params?: unknown }).params
      : {};
  const params =
    typeof (rawParams as Promise<unknown>)?.then === "function"
      ? await (rawParams as Promise<unknown>)
      : rawParams;

  if (typeof params !== "object" || params === null || !("id" in params)) {
    throw apiError(422, "INVALID_REQUEST", "Route id is required.");
  }

  return params as { id: string };
}

function boundedInt(
  value: string | null,
  fallback: number,
  min: number,
  max: number,
) {
  const parsed = Number(value ?? "");
  if (!Number.isInteger(parsed)) return fallback;
  return Math.min(Math.max(parsed, min), max);
}

function nullableDateParam(value: string | null) {
  if (!value) return null;
  const timestamp = Date.parse(value);
  if (Number.isNaN(timestamp)) {
    throw apiError(422, "INVALID_REQUEST", "Date cursor is invalid.");
  }
  return new Date(timestamp).toISOString();
}

function nullableUuidParam(value: string | null) {
  if (!value) return null;
  return uuidSchema.parse(value);
}

function nullableBigIntNumber(value: string | null) {
  if (!value) return null;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw apiError(422, "INVALID_REQUEST", "Message cursor is invalid.");
  }
  return parsed;
}

function stringField(data: unknown, field: string) {
  if (typeof data !== "object" || data === null || !(field in data)) {
    return undefined;
  }
  const value = (data as Record<string, unknown>)[field];
  return typeof value === "string" ? value : undefined;
}
