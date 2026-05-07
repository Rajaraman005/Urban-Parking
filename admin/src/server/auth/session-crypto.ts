import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";

export function generateOpaqueToken(byteLength = 32) {
  return randomBytes(byteLength).toString("base64url");
}

export function sha256Hex(value: string) {
  return createHash("sha256").update(value).digest("hex");
}

export function hmacSha256Hex(value: string, secret: string) {
  return createHmac("sha256", secret).update(value).digest("hex");
}

export function csrfTokenForSession(sessionToken: string, secret: string) {
  return hmacSha256Hex(`admin-csrf:${sessionToken}`, secret);
}

export function safeEqual(left: string, right: string) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return timingSafeEqual(leftBuffer, rightBuffer);
}

export function ipHash(ipAddress: string, secret: string) {
  return hmacSha256Hex(`admin-login-ip:${ipAddress}`, secret);
}
