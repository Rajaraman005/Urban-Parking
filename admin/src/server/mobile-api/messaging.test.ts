import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

vi.mock("./supabase", () => ({
  currentUserIdFromBearer: vi.fn(),
  timedUserSupabase: vi.fn(),
  withAbortSignal: vi.fn((value) => value),
}));

import {
  handleListConversations,
  handleMarkConversationRead,
  handleSendMessage,
  handleStartConversation,
} from "./messaging";
import { currentUserIdFromBearer, timedUserSupabase } from "./supabase";
import type { MobileApiContext } from "./core";

describe("messaging mobile api", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("starts property conversations through the canonical RPC", async () => {
    const rpc = vi.fn(() => ({
      data: { id: "conversation-1" },
      error: null,
    }));
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");
    vi.mocked(timedUserSupabase).mockImplementation(
      async (_context, callback) => callback({ rpc } as never),
    );

    const response = await handleStartConversation(
      contextWithBody("/api/v1/conversations/start", {
        propertyId: "22222222-2222-4222-8222-222222222222",
      }),
    );

    expect(response.status).toBe(200);
    expect(rpc).toHaveBeenCalledWith("start_or_get_property_conversation", {
      p_property_id: "22222222-2222-4222-8222-222222222222",
    });
  });

  it("passes client message id to the idempotent send RPC", async () => {
    const rpc = vi.fn(() => ({
      data: { id: "message-1" },
      error: null,
    }));
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");
    vi.mocked(timedUserSupabase).mockImplementation(
      async (_context, callback) => callback({ rpc } as never),
    );

    const response = await handleSendMessage(
      contextWithBody(
        "/api/v1/conversations/33333333-3333-4333-8333-333333333333/messages",
        {
          body: "Hello host",
          clientMessageId: "11111111-1111-4111-8111-111111111111",
        },
      ),
      {
        params: {
          id: "33333333-3333-4333-8333-333333333333",
        },
      },
    );

    expect(response.status).toBe(201);
    expect(rpc).toHaveBeenCalledWith("send_message", {
      p_body: "Hello host",
      p_client_message_id: "11111111-1111-4111-8111-111111111111",
      p_conversation_id: "33333333-3333-4333-8333-333333333333",
      p_message_type: "text",
      p_metadata: {},
      p_reply_to_message_id: null,
    });
  });

  it("marks reads through the row-locked read RPC", async () => {
    const rpc = vi.fn(() => ({
      data: { lastReadMessageSeq: 42 },
      error: null,
    }));
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");
    vi.mocked(timedUserSupabase).mockImplementation(
      async (_context, callback) => callback({ rpc } as never),
    );

    const response = await handleMarkConversationRead(
      contextWithBody(
        "/api/v1/conversations/33333333-3333-4333-8333-333333333333/read",
        {
          lastSeenMessageSeq: 42,
        },
      ),
      {
        params: {
          id: "33333333-3333-4333-8333-333333333333",
        },
      },
    );

    expect(response.status).toBe(200);
    expect(rpc).toHaveBeenCalledWith("mark_conversation_read", {
      p_conversation_id: "33333333-3333-4333-8333-333333333333",
      p_last_seen_message_seq: 42,
    });
  });

  it("reports missing messaging RPCs as deployment misconfiguration", async () => {
    const rpc = vi.fn(() => ({
      data: null,
      error: {
        code: "42883",
        message: "function public.list_conversations does not exist",
      },
    }));
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");
    vi.mocked(timedUserSupabase).mockImplementation(
      async (_context, callback) => callback({ rpc } as never),
    );

    await expect(
      handleListConversations(contextWithGet("/api/v1/conversations")),
    ).rejects.toMatchObject({
      code: "DEPLOYMENT_MISCONFIGURATION",
      status: 503,
    });
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
    request: new Request(`https://lotzi.in${path}`, {
      method: "GET",
    }),
    requestId: "request-1",
    signal: abortController.signal,
  };
}
