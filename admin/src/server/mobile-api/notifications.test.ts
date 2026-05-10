import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

vi.mock("./supabase", () => ({
  currentUserIdFromBearer: vi.fn(),
  timedSupabase: vi.fn(),
  timedUserSupabase: vi.fn(),
  withAbortSignal: vi.fn((value) => value),
}));

import {
  handleListNotifications,
  handleMarkNotificationsRead,
  handleRegisterNotificationDevice,
} from "./notifications";
import {
  currentUserIdFromBearer,
  timedSupabase,
  timedUserSupabase,
} from "./supabase";
import type { MobileApiContext } from "./core";

describe("notifications mobile api", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
  });

  it("lists notifications through the cursor-aware RPC", async () => {
    const rpc = vi.fn(() => ({
      data: { items: [], unreadByCategory: { all: 2 } },
      error: null,
    }));
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");
    vi.mocked(timedUserSupabase).mockImplementation(
      async (_context, callback) => callback({ rpc } as never),
    );

    const response = await handleListNotifications(
      contextWithGet("/api/v1/notifications?limit=10&status=unread"),
    );

    expect(response.status).toBe(200);
    expect(rpc).toHaveBeenCalledWith("list_notifications", {
      p_before_created_at: null,
      p_before_id: null,
      p_category: null,
      p_limit: 10,
      p_status: "unread",
    });
  });

  it("marks a notification read through the canonical RPC", async () => {
    const rpc = vi.fn(() => ({
      data: { ok: true, updatedCount: 1 },
      error: null,
    }));
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");
    vi.mocked(timedUserSupabase).mockImplementation(
      async (_context, callback) => callback({ rpc } as never),
    );

    const response = await handleMarkNotificationsRead(
      contextWithBody("/api/v1/notifications/read", {
        notificationId: "22222222-2222-4222-8222-222222222222",
      }),
    );

    expect(response.status).toBe(200);
    expect(rpc).toHaveBeenCalledWith("mark_notifications_read", {
      p_category: null,
      p_notification_id: "22222222-2222-4222-8222-222222222222",
    });
  });

  it("registers push devices with hashed token identity", async () => {
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");
    vi.mocked(timedSupabase)
      .mockImplementationOnce(async (_context, callback) =>
        callback(deviceLookupClient(null) as never),
      )
      .mockImplementationOnce(async (_context, callback) =>
        callback(deviceInsertClient() as never),
      );

    const response = await handleRegisterNotificationDevice(
      contextWithBody("/api/v1/notification-devices", {
        platform: "android",
        token: "fcm-token-with-enough-length-for-validation",
      }),
    );

    expect(response.status).toBe(201);
  });
});

function contextWithBody(path: string, body: unknown): MobileApiContext {
  const abortController = new AbortController();
  return {
    addSupabaseQueryMs: vi.fn(),
    log: {},
    request: new Request(`https://lotzi.in${path}`, {
      body: JSON.stringify(body),
      headers: { "Content-Type": "application/json" },
      method: "POST",
    }),
    requestId: "request-1",
    signal: abortController.signal,
  };
}

function contextWithGet(path: string): MobileApiContext {
  const abortController = new AbortController();
  return {
    addSupabaseQueryMs: vi.fn(),
    log: {},
    request: new Request(`https://lotzi.in${path}`, { method: "GET" }),
    requestId: "request-1",
    signal: abortController.signal,
  };
}

function deviceLookupClient(data: unknown) {
  return {
    from: () => ({
      select: () => ({
        eq: () => ({
          maybeSingle: () => ({ data, error: null }),
        }),
      }),
    }),
  };
}

function deviceInsertClient() {
  return {
    from: () => ({
      insert: () => ({
        select: () => ({
          single: () => ({
            data: {
              id: "device-1",
              last_seen_at: "2026-05-10T00:00:00.000Z",
              platform: "android",
              provider: "fcm",
              status: "active",
            },
            error: null,
          }),
        }),
      }),
    }),
  };
}
