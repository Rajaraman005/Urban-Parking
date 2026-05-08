import { getSupabaseAdmin } from "@/server/db/supabase";

export const runtime = "nodejs";

type ExpiryResult = {
  batchSize?: number;
  durationMs?: number;
  error?: string;
  expiredCount?: number;
  expiryBatchSaturated?: boolean;
  ok?: boolean;
};

export async function POST(request: Request) {
  const startedAt = Date.now();
  const requestId = request.headers.get("x-request-id") || crypto.randomUUID();

  if (!isAuthorized(request)) {
    return Response.json(
      {
        code: "cron_unauthorized",
        message: "Cron secret is required.",
        request_id: requestId,
        status: 401,
      },
      { headers: { "X-Request-ID": requestId }, status: 401 },
    );
  }

  const { data, error } = await getSupabaseAdmin().rpc(
    "expire_pending_bookings",
    { p_batch_size: 500 },
  );
  const payload = (data ?? {}) as ExpiryResult;
  const ok = !error && payload.ok !== false;
  const status = ok ? 200 : 500;

  console.log(
    JSON.stringify({
      duration_ms: Date.now() - startedAt,
      error_code: error?.code ?? (ok ? undefined : "BOOKING_EXPIRY_FAILED"),
      expired_count: payload.expiredCount ?? 0,
      expiry_batch_saturated: payload.expiryBatchSaturated ?? false,
      request_id: requestId,
      route: "/api/internal/jobs/expire-pending-bookings",
      status_code: status,
      supabase_error: error?.message,
    }),
  );

  return Response.json(
    {
      ...payload,
      code: ok ? undefined : "booking_expiry_failed",
      message: ok ? undefined : error?.message ?? payload.error ?? "Expiry failed.",
      request_id: requestId,
      status,
    },
    { headers: { "X-Request-ID": requestId }, status },
  );
}

export async function GET(request: Request) {
  return POST(request);
}

function isAuthorized(request: Request) {
  const secret = process.env.CRON_SECRET?.trim();
  if (!secret) return false;
  const authorization = request.headers.get("authorization")?.trim();
  const headerSecret = request.headers.get("x-cron-secret")?.trim();
  return authorization === `Bearer ${secret}` || headerSecret === secret;
}
