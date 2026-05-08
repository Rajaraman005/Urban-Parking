import "server-only";

import { createHash, randomUUID } from "node:crypto";
import { z } from "zod";

type RateLimitConfig = {
  bucket: string;
  limit: number;
  windowSeconds: number;
};

type MobileApiOptions = {
  methods: string[];
  rateLimit: RateLimitConfig;
  route: string;
};

type LogFields = {
  error_code?: string;
  geo_fingerprint_hash?: string;
  rate_limit_mode?: string;
  rate_limited?: boolean;
  supabase_query_ms?: number;
};

export type MobileApiContext = {
  addSupabaseQueryMs: (durationMs: number) => void;
  log: LogFields;
  request: Request;
  requestId: string;
  signal: AbortSignal;
};

type MobileApiHandler = (
  context: MobileApiContext,
  routeContext?: unknown,
) => Promise<Response>;

const corsAllowedHeaders =
  "Content-Type, Authorization, X-Request-ID, X-Retry-Of";
const corsAllowedMethods = "GET, POST, OPTIONS";
const corsExposedHeaders = "X-Request-ID, Retry-After";
const defaultAllowedOrigins = new Set([
  "https://flowaux.in",
  "https://www.flowaux.in",
]);

export class MobileApiError extends Error {
  constructor({
    code,
    details,
    message,
    retryAfter,
    status,
  }: {
    code: string;
    details?: unknown;
    message: string;
    retryAfter?: number;
    status: number;
  }) {
    super(message);
    this.name = "MobileApiError";
    this.code = code;
    this.details = details;
    this.retryAfter = retryAfter;
    this.status = status;
  }

  readonly code: string;
  readonly details?: unknown;
  readonly retryAfter?: number;
  readonly status: number;
}

export function apiError(
  status: number,
  code: string,
  message: string,
  options: { details?: unknown; retryAfter?: number } = {},
) {
  return new MobileApiError({
    code,
    details: options.details,
    message,
    retryAfter: options.retryAfter,
    status,
  });
}

export function jsonResponse(
  body: unknown,
  init: ResponseInit & { requestId?: string } = {},
) {
  return Response.json(body, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init.requestId ? { "X-Request-ID": init.requestId } : {}),
      ...init.headers,
    },
  });
}

export function withMobileApi(
  options: MobileApiOptions,
  handler: MobileApiHandler,
) {
  return async (request: Request, routeContext?: unknown) => {
    const startedAt = Date.now();
    const requestId = request.headers.get("x-request-id") || randomUUID();
    const log: LogFields = {};
    const abortController = new AbortController();
    const abortTimer = setTimeout(() => abortController.abort(), 6500);
    let response: Response;

    const context: MobileApiContext = {
      addSupabaseQueryMs(durationMs) {
        log.supabase_query_ms = (log.supabase_query_ms ?? 0) + durationMs;
      },
      log,
      request,
      requestId,
      signal: abortController.signal,
    };

    try {
      const origin = request.headers.get("origin");
      if (!isAllowedOrigin(origin)) {
        throw apiError(
          403,
          "CORS_ORIGIN_DENIED",
          "This origin is not allowed to access the mobile API.",
        );
      }

      if (request.method === "OPTIONS") {
        response = new Response(null, { status: 204 });
      } else if (!options.methods.includes(request.method)) {
        throw apiError(405, "METHOD_NOT_ALLOWED", "Use an allowed method.");
      } else if (process.env.MOBILE_API_ENABLED === "false") {
        throw apiError(503, "API_DISABLED", "Mobile API is temporarily disabled.", {
          retryAfter: 60,
        });
      } else {
        await enforceRateLimit(request, options.rateLimit, log);
        response = await handler(context, routeContext);
      }
    } catch (error) {
      const api = normalizeError(error);
      log.error_code = api.code;
      response = jsonResponse(
        {
          code: api.code.toLowerCase(),
          error_code: api.code,
          message: api.message,
          request_id: requestId,
          status: api.status,
        },
        {
          requestId,
          status: api.status,
          headers:
            api.retryAfter == null
              ? undefined
              : { "Retry-After": String(api.retryAfter) },
        },
      );
    } finally {
      clearTimeout(abortTimer);
    }

    applyCorsHeaders(response, request.headers.get("origin"), requestId);
    emitStructuredLog({
      durationMs: Date.now() - startedAt,
      log,
      requestId,
      route: options.route,
      statusCode: response.status,
    });
    return response;
  };
}

export function sha256Hex(value: string) {
  return createHash("sha256").update(value).digest("hex");
}

export async function readJsonBody(request: Request) {
  try {
    return await request.json();
  } catch {
    throw apiError(422, "INVALID_REQUEST", "Request body must be valid JSON.");
  }
}

export function normalizeError(error: unknown) {
  if (error instanceof MobileApiError) {
    return error;
  }

  if (error instanceof z.ZodError) {
    return apiError(422, "INVALID_REQUEST", "Request body is invalid.", {
      details: error.issues,
    });
  }

  if (isAbortLike(error)) {
    return apiError(
      503,
      "BACKEND_TIMEOUT",
      "Nearby discovery is temporarily slow. Please try again.",
      { retryAfter: 2 },
    );
  }

  const code = codeFromUnknown(error);
  if (code === "57014") {
    return apiError(
      503,
      "BACKEND_TIMEOUT",
      "Nearby discovery is temporarily slow. Please try again.",
      { retryAfter: 2 },
    );
  }

  return apiError(500, "INTERNAL_ERROR", "Mobile API request failed.");
}

export function supabaseError(error: { code?: string; message?: string }) {
  if (error.code === "57014") {
    return apiError(
      503,
      "BACKEND_TIMEOUT",
      "Nearby discovery is temporarily slow. Please try again.",
      { retryAfter: 2 },
    );
  }
  return apiError(500, "DATABASE_ERROR", "Search data is temporarily unavailable.");
}

function applyCorsHeaders(response: Response, origin: string | null, requestId: string) {
  response.headers.set("Access-Control-Allow-Origin", corsOriginFor(origin));
  response.headers.set("Access-Control-Allow-Headers", corsAllowedHeaders);
  response.headers.set("Access-Control-Allow-Methods", corsAllowedMethods);
  response.headers.set("Access-Control-Expose-Headers", corsExposedHeaders);
  response.headers.set("Access-Control-Max-Age", "86400");
  response.headers.set("Cache-Control", "private, max-age=0, must-revalidate");
  response.headers.set("Vary", "Origin");
  response.headers.set("X-Request-ID", requestId);
}

function allowedOrigins() {
  const configured = (process.env.MOBILE_API_ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
  return new Set([...defaultAllowedOrigins, ...configured]);
}

function corsOriginFor(origin: string | null) {
  if (origin && allowedOrigins().has(origin)) {
    return origin;
  }
  return "https://flowaux.in";
}

function isAllowedOrigin(origin: string | null) {
  if (!origin) return true;
  return allowedOrigins().has(origin);
}

async function enforceRateLimit(
  request: Request,
  config: RateLimitConfig,
  log: LogFields,
) {
  const mode = rateLimitMode();
  log.rate_limit_mode = mode;
  if (mode === "disabled") return;

  const restUrl = process.env.UPSTASH_REDIS_REST_URL?.trim();
  const restToken = process.env.UPSTASH_REDIS_REST_TOKEN?.trim();
  if (!restUrl || !restToken) {
    log.rate_limit_mode = "disabled_missing_upstash";
    return;
  }

  const ipHash = sha256Hex(clientIp(request));
  const windowId = Math.floor(Date.now() / (config.windowSeconds * 1000));
  const key = `mobile-api:${config.bucket}:${windowId}:${ipHash}`;
  const retryAfter = config.windowSeconds;

  try {
    const response = await fetch(`${restUrl.replace(/\/$/, "")}/pipeline`, {
      body: JSON.stringify([
        ["INCR", key],
        ["EXPIRE", key, config.windowSeconds],
      ]),
      headers: {
        Authorization: `Bearer ${restToken}`,
        "Content-Type": "application/json",
      },
      method: "POST",
    });
    const payload = (await response.json()) as Array<{ result?: unknown }>;
    const count = Number(payload[0]?.result ?? 0);
    const limited = Number.isFinite(count) && count > config.limit;
    log.rate_limited = limited;
    if (limited && mode === "enforce") {
      throw apiError(429, "RATE_LIMITED", "Too many requests.", {
        retryAfter,
      });
    }
  } catch (error) {
    if (error instanceof MobileApiError) throw error;
    log.error_code = "RATE_LIMITER_OPEN";
  }
}

function rateLimitMode() {
  const configured = process.env.MOBILE_API_RATE_LIMIT_MODE?.trim();
  if (
    configured === "disabled" ||
    configured === "dry-run" ||
    configured === "enforce"
  ) {
    return configured;
  }
  return process.env.VERCEL_ENV === "production" ? "enforce" : "dry-run";
}

function clientIp(request: Request) {
  return (
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    request.headers.get("x-real-ip")?.trim() ||
    "unknown"
  );
}

function isAbortLike(error: unknown) {
  if (!(error instanceof Error)) return false;
  return error.name === "AbortError" || error.message.toLowerCase().includes("aborted");
}

function codeFromUnknown(error: unknown) {
  if (typeof error === "object" && error !== null && "code" in error) {
    const code = error.code;
    return typeof code === "string" ? code : null;
  }
  return null;
}

function emitStructuredLog({
  durationMs,
  log,
  requestId,
  route,
  statusCode,
}: {
  durationMs: number;
  log: LogFields;
  requestId: string;
  route: string;
  statusCode: number;
}) {
  const payload = {
    duration_ms: durationMs,
    error_code: log.error_code,
    geo_fingerprint_hash: log.geo_fingerprint_hash,
    rate_limit_mode: log.rate_limit_mode,
    rate_limited: log.rate_limited ?? false,
    request_id: requestId,
    route,
    status_code: statusCode,
    supabase_query_ms: log.supabase_query_ms ?? 0,
  };
  console.log(JSON.stringify(payload));
}
