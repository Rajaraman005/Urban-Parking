import { processNotificationEngineTick } from "@/server/notifications/application/fanout";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const requestId = request.headers.get("x-request-id") || crypto.randomUUID();
  if (!isAuthorized(request)) {
    return Response.json(
      {
        code: "notification_worker_unauthorized",
        message: "Worker secret is required.",
        request_id: requestId,
        status: 401,
      },
      { headers: { "X-Request-ID": requestId }, status: 401 },
    );
  }

  const startedAt = Date.now();
  try {
    const result = await processNotificationEngineTick({
      deliveryLimit: 50,
      fanoutLimit: 10,
      workerId: request.headers.get("x-worker-id") ?? undefined,
    });
    console.log(
      JSON.stringify({
        duration_ms: Date.now() - startedAt,
        notification_delivery_claimed: result.delivery.claimed,
        notification_delivery_failed: result.delivery.failed,
        notification_fanout_claimed: result.fanout.claimed,
        notification_fanout_failed: result.fanout.failed,
        request_id: requestId,
        route: "/api/internal/notifications/process",
        status_code: 200,
      }),
    );
    return Response.json(
      { ok: true, request_id: requestId, ...result },
      { headers: { "X-Request-ID": requestId }, status: 200 },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.log(
      JSON.stringify({
        duration_ms: Date.now() - startedAt,
        error_code: "NOTIFICATION_PROCESS_FAILED",
        request_id: requestId,
        route: "/api/internal/notifications/process",
        status_code: 500,
      }),
    );
    return Response.json(
      {
        code: "notification_process_failed",
        message,
        request_id: requestId,
        status: 500,
      },
      { headers: { "X-Request-ID": requestId }, status: 500 },
    );
  }
}

export async function GET(request: Request) {
  return POST(request);
}

function isAuthorized(request: Request) {
  const secrets = [
    process.env.NOTIFICATION_WORKER_SECRET?.trim(),
    process.env.CRON_SECRET?.trim(),
  ].filter((secret): secret is string => Boolean(secret));
  if (secrets.length === 0) return false;
  const authorization = request.headers.get("authorization")?.trim();
  const headerSecret = request.headers.get("x-notification-worker-secret")?.trim();
  return secrets.some(
    (secret) => authorization === `Bearer ${secret}` || headerSecret === secret,
  );
}
