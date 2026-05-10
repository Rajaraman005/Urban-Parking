import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

vi.mock("@/server/db/supabase", () => ({
  getSupabaseAdmin: vi.fn(),
}));

import { getMobileSupabaseForBearer } from "./supabase";
import type { MobileApiContext } from "./core";

describe("mobile api supabase auth client", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
  });

  it("reports missing user auth env as deployment misconfiguration", () => {
    vi.stubEnv("SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "");
    vi.stubEnv("EXPO_PUBLIC_SUPABASE_URL", "");
    vi.stubEnv("SUPABASE_ANON_KEY", "");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "");
    vi.stubEnv("EXPO_PUBLIC_SUPABASE_ANON_KEY", "");

    try {
      getMobileSupabaseForBearer(contextWithBearer());
      throw new Error("Expected getMobileSupabaseForBearer to throw.");
    } catch (error) {
      expect(error).toMatchObject({
        code: "DEPLOYMENT_MISCONFIGURATION",
        status: 503,
      });
    }
  });

  it("accepts Expo public Supabase env names used by the mobile project", () => {
    vi.stubEnv("SUPABASE_URL", "");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "");
    vi.stubEnv("EXPO_PUBLIC_SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv("SUPABASE_ANON_KEY", "");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "");
    vi.stubEnv("EXPO_PUBLIC_SUPABASE_ANON_KEY", "anon-key");

    expect(() => getMobileSupabaseForBearer(contextWithBearer())).not.toThrow();
  });
});

function contextWithBearer(): MobileApiContext {
  const abortController = new AbortController();
  return {
    addSupabaseQueryMs: vi.fn(),
    log: {},
    request: new Request("https://lotzi.in/api/v1/conversations", {
      headers: { Authorization: "Bearer user-token" },
      method: "GET",
    }),
    requestId: "request-1",
    signal: abortController.signal,
  };
}
