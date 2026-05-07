import "server-only";
import { headers } from "next/headers";

export async function requestIdentity() {
  const headerStore = await headers();
  const forwardedFor = headerStore.get("x-forwarded-for") ?? "";
  const ipAddress = forwardedFor.split(",")[0]?.trim() || headerStore.get("x-real-ip") || "unknown";
  return {
    ipAddress,
    origin: headerStore.get("origin"),
    host: headerStore.get("host"),
    userAgent: headerStore.get("user-agent") ?? "unknown"
  };
}

export async function assertSameOrigin() {
  const { host, origin } = await requestIdentity();
  if (!origin || !host) return;
  const originHost = new URL(origin).host;
  if (originHost !== host) {
    throw new Error("Request origin is not trusted.");
  }
}
