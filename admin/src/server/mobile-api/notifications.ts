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
  timedSupabase,
  timedUserSupabase,
  withAbortSignal,
} from "./supabase";
import {
  notificationCategories,
  notificationCategorySchema,
  notificationStatusSchema,
  uuidSchema,
  type NotificationPreferenceDto,
} from "@/server/notifications/domain/types";
import {
  encryptNotificationToken,
  notificationTokenHash,
} from "@/server/notifications/providers/device-token";

type SupabaseErrorLike = {
  code?: string;
  message?: string;
};

type SupabaseResult<T> = {
  data: T;
  error: SupabaseErrorLike | null;
};

const markReadSchema = z.object({
  category: notificationCategorySchema.optional().nullable(),
  notificationId: uuidSchema.optional().nullable(),
});

const preferencePatchSchema = z.object({
  category: notificationCategorySchema,
  emailEnabled: z.boolean().optional(),
  inAppEnabled: z.boolean().optional(),
  marketingConsent: z.boolean().optional(),
  pushEnabled: z.boolean().optional(),
  quietHoursEnabled: z.boolean().optional(),
  quietHoursEndMinute: z.number().int().min(0).max(1439).optional().nullable(),
  quietHoursStartMinute: z.number().int().min(0).max(1439).optional().nullable(),
  realtimeEnabled: z.boolean().optional(),
  smsEnabled: z.boolean().optional(),
  timezone: z.string().trim().min(1).max(80).optional(),
});

const deviceRegistrationSchema = z.object({
  appVersion: z.string().trim().max(80).optional().nullable(),
  locale: z.string().trim().max(32).optional().nullable(),
  platform: z.enum(["android", "ios", "web"]),
  provider: z.enum(["fcm", "apns", "web_push"]).default("fcm"),
  timezone: z.string().trim().min(1).max(80).default("Asia/Kolkata"),
  token: z.string().trim().min(20).max(4096),
});

export async function handleListNotifications(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const url = new URL(context.request.url);
  const limit = boundedInt(url.searchParams.get("limit"), 30, 1, 100);
  const cursor = parseCursor(url.searchParams.get("cursor"));
  const status = nullableEnum(
    url.searchParams.get("status"),
    notificationStatusSchema,
  );
  const category = nullableEnum(
    url.searchParams.get("category"),
    notificationCategorySchema,
  );

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("list_notifications", {
        p_before_created_at: cursor?.createdAt ?? null,
        p_before_id: cursor?.id ?? null,
        p_category: category,
        p_limit: limit,
        p_status: status,
      }),
      context.signal,
    ),
  );

  if (result.error) throw notificationSupabaseError(result.error);
  return jsonResponse(normalizeListPayload(result.data), {
    requestId: context.requestId,
    status: 200,
  });
}

export async function handleSyncNotifications(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const url = new URL(context.request.url);
  const cursor = parseCursor(url.searchParams.get("afterCursor"));
  const limit = boundedInt(url.searchParams.get("limit"), 100, 1, 500);

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("sync_notifications", {
        p_after_created_at: cursor?.createdAt ?? null,
        p_after_id: cursor?.id ?? null,
        p_limit: limit,
      }),
      context.signal,
    ),
  );

  if (result.error) throw notificationSupabaseError(result.error);
  return jsonResponse(result.data ?? { items: [] }, {
    requestId: context.requestId,
    status: 200,
  });
}

export async function handleMarkNotificationsRead(context: MobileApiContext) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const body = markReadSchema.parse(await readJsonBody(context.request));

  const result = await timedUserSupabase(context, (client) =>
    withAbortSignal(
      client.rpc("mark_notifications_read", {
        p_category: body.category ?? null,
        p_notification_id: body.notificationId ?? null,
      }),
      context.signal,
    ),
  );

  if (result.error) throw notificationSupabaseError(result.error);
  return jsonResponse(result.data ?? { ok: true }, {
    requestId: context.requestId,
    status: 200,
  });
}

export async function handleGetNotificationPreferences(
  context: MobileApiContext,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);

  const result = await timedSupabase(context, (client) =>
    withAbortSignal(
      client
        .from("notification_preferences")
        .select("*")
        .eq("user_id", userId),
      context.signal,
    ),
  );

  if (result.error) throw notificationSupabaseError(result.error);
  const byCategory = new Map(
    ((result.data ?? []) as PreferenceRow[]).map((row) => [
      row.category,
      preferenceDto(row),
    ]),
  );
  return jsonResponse(
    {
      items: notificationCategories.map(
        (category) => byCategory.get(category) ?? defaultPreference(category),
      ),
    },
    { requestId: context.requestId, status: 200 },
  );
}

export async function handlePatchNotificationPreferences(
  context: MobileApiContext,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const body = preferencePatchSchema.parse(await readJsonBody(context.request));
  const now = new Date().toISOString();

  const row = {
    category: body.category,
    email_enabled: body.emailEnabled ?? undefined,
    in_app_enabled: body.inAppEnabled ?? undefined,
    marketing_consent_at:
      body.marketingConsent === undefined
        ? undefined
        : body.marketingConsent
          ? now
          : null,
    push_enabled: body.pushEnabled ?? undefined,
    quiet_hours_enabled: body.quietHoursEnabled ?? undefined,
    quiet_hours_end_minute: body.quietHoursEndMinute ?? undefined,
    quiet_hours_start_minute: body.quietHoursStartMinute ?? undefined,
    realtime_enabled: body.realtimeEnabled ?? undefined,
    sms_enabled: body.smsEnabled ?? undefined,
    timezone: body.timezone ?? undefined,
    user_id: userId,
  };

  const result = (await timedSupabase(context, async (client) =>
    await client
        .from("notification_preferences")
        .upsert(stripUndefined(row), { onConflict: "user_id,category" })
        .select("*")
        .single(),
  )) as SupabaseResult<PreferenceRow>;

  if (result.error) throw notificationSupabaseError(result.error);
  return jsonResponse(preferenceDto(result.data as PreferenceRow), {
    requestId: context.requestId,
    status: 200,
  });
}

export async function handleRegisterNotificationDevice(
  context: MobileApiContext,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const body = deviceRegistrationSchema.parse(await readJsonBody(context.request));
  const tokenHash = notificationTokenHash(body.token);
  const encryptedToken = encryptNotificationToken(body.token);
  const now = new Date().toISOString();

  const existing = (await timedSupabase(context, async (client) =>
    await client
        .from("notification_devices")
        .select("id")
        .eq("token_hash", tokenHash)
        .maybeSingle(),
  )) as SupabaseResult<{ id: string } | null>;
  if (existing.error) throw notificationSupabaseError(existing.error);

  const payload = {
    app_version: body.appVersion ?? null,
    failure_count: 0,
    invalidated_at: null,
    invalidation_reason: null,
    last_seen_at: now,
    locale: body.locale ?? null,
    platform: body.platform,
    provider: body.provider,
    status: "active",
    timezone: body.timezone,
    token_ciphertext: encryptedToken,
    token_hash: tokenHash,
    user_id: userId,
  };

  const result = existing.data
    ? ((await timedSupabase(context, async (client) =>
        await client
            .from("notification_devices")
            .update(payload)
            .eq("id", existing.data!.id)
            .select("id,platform,provider,status,last_seen_at")
            .single(),
      )) as SupabaseResult<unknown>)
    : ((await timedSupabase(context, async (client) =>
        await client
            .from("notification_devices")
            .insert(payload)
            .select("id,platform,provider,status,last_seen_at")
            .single(),
      )) as SupabaseResult<unknown>);

  if (result.error) throw notificationSupabaseError(result.error);
  return jsonResponse(result.data, { requestId: context.requestId, status: 201 });
}

export async function handleDeleteNotificationDevice(
  context: MobileApiContext,
  routeContext?: unknown,
) {
  const userId = await requireUserId(context);
  context.log.actor_id_hash = sha256Hex(userId);
  const id = uuidSchema.parse((await paramsFromRouteContext(routeContext)).id);

  const result = await timedSupabase(context, (client) =>
    withAbortSignal(
      client
        .from("notification_devices")
        .update({
          invalidated_at: new Date().toISOString(),
          invalidation_reason: "client_deleted",
          status: "invalidated",
        })
        .eq("id", id)
        .eq("user_id", userId),
      context.signal,
    ),
  );

  if (result.error) throw notificationSupabaseError(result.error);
  return jsonResponse({ ok: true }, { requestId: context.requestId, status: 200 });
}

async function requireUserId(context: MobileApiContext) {
  const userId = await currentUserIdFromBearer(context);
  if (!userId) {
    throw apiError(401, "AUTH_REQUIRED", "Sign in before using notifications.");
  }
  return userId;
}

type PreferenceRow = {
  category: string;
  email_enabled?: boolean;
  in_app_enabled?: boolean;
  marketing_consent_at?: string | null;
  push_enabled?: boolean;
  quiet_hours_enabled?: boolean;
  quiet_hours_end_minute?: number | null;
  quiet_hours_start_minute?: number | null;
  realtime_enabled?: boolean;
  sms_enabled?: boolean;
  timezone?: string;
};

function preferenceDto(row: PreferenceRow): NotificationPreferenceDto {
  return {
    category: notificationCategorySchema.parse(row.category),
    emailEnabled: row.email_enabled ?? false,
    inAppEnabled: row.in_app_enabled ?? true,
    marketingConsentAt: row.marketing_consent_at ?? undefined,
    pushEnabled: row.push_enabled ?? true,
    quietHoursEnabled: row.quiet_hours_enabled ?? false,
    quietHoursEndMinute: row.quiet_hours_end_minute ?? undefined,
    quietHoursStartMinute: row.quiet_hours_start_minute ?? undefined,
    realtimeEnabled: row.realtime_enabled ?? true,
    smsEnabled: row.sms_enabled ?? false,
    timezone: row.timezone ?? "Asia/Kolkata",
  };
}

function defaultPreference(category: string): NotificationPreferenceDto {
  return {
    category: notificationCategorySchema.parse(category),
    emailEnabled: category === "security",
    inAppEnabled: true,
    pushEnabled: category !== "marketing",
    quietHoursEnabled: false,
    realtimeEnabled: true,
    smsEnabled: false,
    timezone: "Asia/Kolkata",
  };
}

function normalizeListPayload(data: unknown) {
  if (typeof data !== "object" || data === null) {
    return { items: [], unreadByCategory: {} };
  }
  const payload = data as { items?: unknown; unreadByCategory?: unknown };
  return {
    items: Array.isArray(payload.items) ? payload.items : [],
    unreadByCategory:
      typeof payload.unreadByCategory === "object" &&
      payload.unreadByCategory !== null
        ? payload.unreadByCategory
        : {},
  };
}

function parseCursor(value: string | null) {
  if (!value) return null;
  const separator = value.lastIndexOf("|");
  if (separator <= 0) {
    throw apiError(422, "INVALID_CURSOR", "Notification cursor is invalid.");
  }
  const createdAt = value.slice(0, separator);
  const id = uuidSchema.parse(value.slice(separator + 1));
  if (Number.isNaN(Date.parse(createdAt))) {
    throw apiError(422, "INVALID_CURSOR", "Notification cursor is invalid.");
  }
  return { createdAt: new Date(createdAt).toISOString(), id };
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

function nullableEnum<T extends z.ZodTypeAny>(
  value: string | null,
  schema: T,
): z.infer<T> | null {
  if (!value) return null;
  return schema.parse(value);
}

function stripUndefined<T extends Record<string, unknown>>(value: T) {
  return Object.fromEntries(
    Object.entries(value).filter((entry) => entry[1] !== undefined),
  );
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
    throw apiError(422, "INVALID_REQUEST", "Device id is required.");
  }
  return params as { id: string };
}

function notificationSupabaseError(error: SupabaseErrorLike) {
  const code = error.code ?? "NOTIFICATION_DATABASE_ERROR";
  const message = error.message ?? "Notification request failed.";
  if (code === "42501") return apiError(403, "NOTIFICATION_FORBIDDEN", message);
  if (code === "P0002") return apiError(404, "NOTIFICATION_NOT_FOUND", message);
  if (code === "23514") {
    return apiError(422, "NOTIFICATION_VALIDATION_FAILED", message);
  }
  if (code === "42883" || code === "42P01") {
    return apiError(
      503,
      "DEPLOYMENT_MISCONFIGURATION",
      "Notification database migration is not installed yet.",
    );
  }
  return apiError(
    500,
    "NOTIFICATION_DATABASE_ERROR",
    "Notification service failed.",
  );
}
