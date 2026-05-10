import "server-only";

import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { getSupabaseAdmin } from "@/server/db/supabase";
import { decryptNotificationToken } from "./device-token";

export type DeliveryResult =
  | {
      ok: true;
      providerMessageId?: string;
      suppressed?: boolean;
      statusCode?: number;
    }
  | {
      errorCode: string;
      errorMessage: string;
      permanent: boolean;
      statusCode?: number;
      ok: false;
    };

export type DeliveryPayload = {
  body: string;
  deeplink?: string;
  idempotencyKey: string;
  notificationId: string;
  recipientId: string;
  title: string;
};

export interface NotificationProvider {
  readonly name: string;
  send(payload: DeliveryPayload): Promise<DeliveryResult>;
}

export class InAppRealtimeProvider implements NotificationProvider {
  readonly name = "in_app_realtime";

  async send(): Promise<DeliveryResult> {
    return { ok: true };
  }
}

export class SmsDisabledProvider implements NotificationProvider {
  readonly name = "sms_disabled";

  async send(): Promise<DeliveryResult> {
    return {
      errorCode: "provider_unconfigured",
      errorMessage: "SMS provider is not configured.",
      ok: false,
      permanent: true,
      statusCode: 501,
    };
  }
}

export class ResendEmailProvider implements NotificationProvider {
  readonly name = "resend";

  async send(): Promise<DeliveryResult> {
    const apiKey = process.env.RESEND_API_KEY?.trim();
    if (!apiKey) {
      return {
        errorCode: "provider_unconfigured",
        errorMessage: "Resend is not configured.",
        ok: false,
        permanent: true,
        statusCode: 501,
      };
    }

    return {
      errorCode: "email_recipient_unavailable",
      errorMessage:
        "Email delivery requires a verified recipient email resolver.",
      ok: false,
      permanent: true,
      statusCode: 422,
    };
  }
}

export class FcmPushProvider implements NotificationProvider {
  readonly name = "fcm";

  async send(payload: DeliveryPayload): Promise<DeliveryResult> {
    if (!process.env.FCM_SERVICE_ACCOUNT_JSON?.trim()) {
      return {
        errorCode: "provider_unconfigured",
        errorMessage: "FCM service account is not configured.",
        ok: false,
        permanent: true,
        statusCode: 501,
      };
    }

    const devices = await activePushDevicesFor(payload.recipientId);
    if (devices.length === 0) {
      return {
        ok: true,
        suppressed: true,
        statusCode: 204,
      };
    }

    const tokens = devices.map((device) =>
      decryptNotificationToken(device.token_ciphertext),
    );
    const message = {
      android: {
        notification: {
          channelId: "lotzi_high_importance_v1",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          sound: "default",
        },
        priority: "high" as const,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
      data: {
        deeplink: payload.deeplink ?? "",
        idempotencyKey: payload.idempotencyKey,
        notificationId: payload.notificationId,
      },
      notification: {
        body: payload.body,
        title: payload.title,
      },
      tokens,
    };

    try {
      const response = await getMessaging(firebaseApp()).sendEachForMulticast(
        message,
      );
      const invalidDeviceIds: string[] = [];
      const transientErrors: string[] = [];
      const providerMessageIds: string[] = [];

      response.responses.forEach((result, index) => {
        if (result.success) {
          if (result.messageId) providerMessageIds.push(result.messageId);
          return;
        }

        const code = result.error?.code ?? "messaging/unknown-error";
        if (isInvalidTokenError(code)) {
          invalidDeviceIds.push(devices[index]?.id);
          return;
        }
        transientErrors.push(code);
      });

      if (invalidDeviceIds.length > 0) {
        await tombstoneInvalidDevices(invalidDeviceIds);
      }

      if (response.successCount > 0) {
        return {
          ok: true,
          providerMessageId: providerMessageIds[0],
          statusCode: 200,
        };
      }

      if (invalidDeviceIds.length === devices.length) {
        return {
          ok: true,
          suppressed: true,
          statusCode: 410,
        };
      }

      return {
        errorCode: "fcm_send_failed",
        errorMessage:
          transientErrors[0] ?? "Firebase Cloud Messaging send failed.",
        ok: false,
        permanent: false,
        statusCode: 503,
      };
    } catch (error) {
      const code = firebaseErrorCode(error);
      return {
        errorCode: code,
        errorMessage:
          error instanceof Error ? error.message : "Firebase send failed.",
        ok: false,
        permanent: isPermanentFcmError(code),
        statusCode: isPermanentFcmError(code) ? 400 : 503,
      };
    }
  }
}

export function providerFor(channel: string): NotificationProvider {
  if (channel === "in_app" || channel === "realtime") {
    return new InAppRealtimeProvider();
  }
  if (channel === "email") return new ResendEmailProvider();
  if (channel === "push") return new FcmPushProvider();
  return new SmsDisabledProvider();
}

type NotificationDeviceRow = {
  id: string;
  token_ciphertext: string;
};

async function activePushDevicesFor(userId: string) {
  const { data, error } = await getSupabaseAdmin()
    .from("notification_devices")
    .select("id,token_ciphertext")
    .eq("user_id", userId)
    .eq("status", "active")
    .order("last_seen_at", { ascending: false })
    .limit(10);

  if (error) throw new Error(error.message);
  return (data ?? []) as NotificationDeviceRow[];
}

async function tombstoneInvalidDevices(deviceIds: string[]) {
  const ids = deviceIds.filter(Boolean);
  if (ids.length === 0) return;

  const { error } = await getSupabaseAdmin()
    .from("notification_devices")
    .update({
      invalidated_at: new Date().toISOString(),
      status: "expired",
    })
    .in("id", ids);

  if (error) throw new Error(error.message);
}

function firebaseApp(): App {
  const existing = getApps()[0];
  if (existing) return existing;

  const rawServiceAccount = process.env.FCM_SERVICE_ACCOUNT_JSON?.trim();
  if (!rawServiceAccount) {
    throw new Error("FCM service account is not configured.");
  }

  return initializeApp({
    credential: cert(JSON.parse(rawServiceAccount)),
  });
}

function firebaseErrorCode(error: unknown) {
  return typeof error === "object" &&
    error !== null &&
    "code" in error &&
    typeof error.code === "string"
    ? error.code
    : "fcm_unknown_error";
}

function isInvalidTokenError(code: string) {
  return (
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token" ||
    code === "messaging/invalid-argument"
  );
}

function isPermanentFcmError(code: string) {
  return (
    isInvalidTokenError(code) ||
    code === "messaging/mismatched-credential" ||
    code === "messaging/invalid-recipient"
  );
}
