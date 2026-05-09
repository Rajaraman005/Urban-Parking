import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { jsonResponse, withMobileApi } from "./core";

const testHandler = withMobileApi(
  {
    methods: ["POST"],
    rateLimit: { bucket: "test", limit: 1, windowSeconds: 60 },
    route: "/api/v1/test",
  },
  async (context) =>
    jsonResponse({ ok: true }, { requestId: context.requestId, status: 200 }),
);

describe("mobile api wrapper", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
  });

  it("handles CORS preflight without calling the route handler", async () => {
    const response = await testHandler(
      new Request("https://lotzi.in/api/v1/test", {
        headers: { Origin: "https://lotzi.in" },
        method: "OPTIONS",
      }),
    );

    expect(response.status).toBe(204);
    expect(response.headers.get("Access-Control-Allow-Origin")).toBe(
      "https://lotzi.in",
    );
    expect(response.headers.get("Access-Control-Expose-Headers")).toContain(
      "X-Request-ID",
    );
  });

  it("rejects wrong methods with JSON and a request id", async () => {
    const response = await testHandler(
      new Request("https://lotzi.in/api/v1/test", { method: "GET" }),
    );
    const body = (await response.json()) as { error_code: string };

    expect(response.status).toBe(405);
    expect(body.error_code).toBe("METHOD_NOT_ALLOWED");
    expect(response.headers.get("X-Request-ID")).toBeTruthy();
  });

  it("supports the mobile api kill switch", async () => {
    vi.stubEnv("MOBILE_API_ENABLED", "false");

    const response = await testHandler(
      new Request("https://lotzi.in/api/v1/test", { method: "POST" }),
    );
    const body = (await response.json()) as { error_code: string };

    expect(response.status).toBe(503);
    expect(body.error_code).toBe("API_DISABLED");
    expect(response.headers.get("Retry-After")).toBe("60");
  });

  it("rate limits in enforce mode and only logs in dry-run mode", async () => {
    vi.stubEnv("UPSTASH_REDIS_REST_URL", "https://redis.example.com");
    vi.stubEnv("UPSTASH_REDIS_REST_TOKEN", "token");
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        Response.json([{ result: 2 }, { result: 1 }]),
      ),
    );

    vi.stubEnv("MOBILE_API_RATE_LIMIT_MODE", "dry-run");
    const dryRun = await testHandler(
      new Request("https://lotzi.in/api/v1/test", { method: "POST" }),
    );
    expect(dryRun.status).toBe(200);

    vi.stubEnv("MOBILE_API_RATE_LIMIT_MODE", "enforce");
    const enforced = await testHandler(
      new Request("https://lotzi.in/api/v1/test", { method: "POST" }),
    );
    const body = (await enforced.json()) as { error_code: string };

    expect(enforced.status).toBe(429);
    expect(body.error_code).toBe("RATE_LIMITED");
    expect(enforced.headers.get("Retry-After")).toBe("60");
  });
});
