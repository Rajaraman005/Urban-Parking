import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

vi.mock("./supabase", () => ({
  currentUserIdFromBearer: vi.fn(),
  timedUserSupabase: vi.fn(),
  withAbortSignal: vi.fn((value) => value),
}));

import { handleCreateBooking } from "./bookings";
import {
  currentUserIdFromBearer,
  timedUserSupabase,
} from "./supabase";
import type { MobileApiContext } from "./core";

describe("booking mobile api", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it("passes idempotency key and full booking intent to the create RPC", async () => {
    const rpc = vi.fn(() => ({
      data: { id: "booking-1", status: "pending" },
      error: null,
    }));
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");
    vi.mocked(timedUserSupabase).mockImplementation(async (_context, callback) =>
      callback({ rpc } as never),
    );

    const response = await handleCreateBooking(
      contextWithBody({
        endAt: "2026-05-09T10:00:00.000Z",
        idempotencyKey: "11111111-1111-4111-8111-111111111111",
        spotId: "22222222-2222-4222-8222-222222222222",
        startAt: "2026-05-09T09:00:00.000Z",
        vehicleKind: "car",
      }),
    );

    expect(response.status).toBe(201);
    expect(rpc).toHaveBeenCalledWith("create_booking_request", {
      p_end_at: "2026-05-09T10:00:00.000Z",
      p_idempotency_key: "11111111-1111-4111-8111-111111111111",
      p_space_id: "22222222-2222-4222-8222-222222222222",
      p_start_at: "2026-05-09T09:00:00.000Z",
      p_vehicle_kind: "car",
    });
  });

  it("enforces the per-renter booking creation rate limit", async () => {
    vi.stubEnv("BOOKING_CREATE_RATE_LIMIT_MODE", "enforce");
    vi.stubEnv("UPSTASH_REDIS_REST_URL", "https://redis.example.com");
    vi.stubEnv("UPSTASH_REDIS_REST_TOKEN", "token");
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => Response.json([{ result: 11 }, { result: 1 }])),
    );
    vi.mocked(currentUserIdFromBearer).mockResolvedValue("user-1");

    await expect(
      handleCreateBooking(
        contextWithBody({
          endAt: "2026-05-09T10:00:00.000Z",
          idempotencyKey: "11111111-1111-4111-8111-111111111111",
          spotId: "22222222-2222-4222-8222-222222222222",
          startAt: "2026-05-09T09:00:00.000Z",
          vehicleKind: "car",
        }),
      ),
    ).rejects.toMatchObject({
      code: "BOOKING_CREATE_RATE_LIMITED",
      status: 429,
    });
  });
});

function contextWithBody(body: unknown): MobileApiContext {
  const abortController = new AbortController();
  return {
    addSupabaseQueryMs: vi.fn(),
    log: {},
    request: new Request("https://flowaux.in/api/v1/bookings", {
      body: JSON.stringify(body),
      headers: { "Content-Type": "application/json" },
      method: "POST",
    }),
    requestId: "request-1",
    signal: abortController.signal,
  };
}
