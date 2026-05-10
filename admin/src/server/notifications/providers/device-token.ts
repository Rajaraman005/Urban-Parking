import "server-only";

import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto";
import { apiError } from "@/server/mobile-api/core";

export function notificationTokenHash(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

export function encryptNotificationToken(token: string) {
  const secret = process.env.NOTIFICATION_DEVICE_TOKEN_SECRET?.trim();
  if (!secret) {
    if (process.env.NODE_ENV === "production") {
      throw apiError(
        503,
        "DEPLOYMENT_MISCONFIGURATION",
        "Notification device token encryption is not configured.",
      );
    }
    return `dev-plaintext:${token}`;
  }

  const key = createHash("sha256").update(secret).digest();
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([
    cipher.update(token, "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return `v1:${iv.toString("base64url")}:${tag.toString("base64url")}:${encrypted.toString("base64url")}`;
}

export function decryptNotificationToken(ciphertext: string) {
  if (ciphertext.startsWith("dev-plaintext:")) {
    return ciphertext.slice("dev-plaintext:".length);
  }

  const secret = process.env.NOTIFICATION_DEVICE_TOKEN_SECRET?.trim();
  if (!secret) {
    throw apiError(
      503,
      "DEPLOYMENT_MISCONFIGURATION",
      "Notification device token encryption is not configured.",
    );
  }

  const [version, ivBase64, tagBase64, encryptedBase64] = ciphertext.split(":");
  if (
    version !== "v1" ||
    !ivBase64 ||
    !tagBase64 ||
    !encryptedBase64
  ) {
    throw new Error("Notification device token has an unsupported format.");
  }

  const key = createHash("sha256").update(secret).digest();
  const decipher = createDecipheriv(
    "aes-256-gcm",
    key,
    Buffer.from(ivBase64, "base64url"),
  );
  decipher.setAuthTag(Buffer.from(tagBase64, "base64url"));
  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(encryptedBase64, "base64url")),
    decipher.final(),
  ]);
  return decrypted.toString("utf8");
}
