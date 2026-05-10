import { getSupabaseAdmin } from "@/server/db/supabase";

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

  const body = await safeJson(request);
  const ids = Array.isArray(body.ids)
    ? body.ids.filter((id): id is string => typeof id === "string")
    : [];
  if (ids.length === 0 || ids.length > 100) {
    return Response.json(
      {
        code: "invalid_request",
        message: "Provide between 1 and 100 dead-letter ids.",
        request_id: requestId,
        status: 422,
      },
      { headers: { "X-Request-ID": requestId }, status: 422 },
    );
  }

  const supabase = getSupabaseAdmin();
  const { data: letters, error } = await supabase
    .from("notification_dead_letters")
    .select("id,source_table,source_id")
    .in("id", ids)
    .eq("replay_status", "not_replayed");
  if (error) {
    return Response.json(
      {
        code: "notification_replay_failed",
        message: error.message,
        request_id: requestId,
        status: 500,
      },
      { headers: { "X-Request-ID": requestId }, status: 500 },
    );
  }

  for (const letter of (letters ?? []) as Array<{
    id: string;
    source_id: string;
    source_table: string;
  }>) {
    if (letter.source_table === "notification_fanout_jobs") {
      await supabase
        .from("notification_fanout_jobs")
        .update({
          last_error: null,
          locked_by: null,
          locked_until: null,
          next_attempt_at: new Date().toISOString(),
          status: "pending",
        })
        .eq("id", letter.source_id);
    }
    if (letter.source_table === "notification_delivery_jobs") {
      await supabase
        .from("notification_delivery_jobs")
        .update({
          last_error: null,
          locked_by: null,
          locked_until: null,
          next_attempt_at: new Date().toISOString(),
          status: "pending",
        })
        .eq("id", letter.source_id);
    }
    await supabase
      .from("notification_dead_letters")
      .update({
        replay_status: "queued",
        replayed_at: new Date().toISOString(),
      })
      .eq("id", letter.id);
  }

  return Response.json(
    { ok: true, queuedCount: letters?.length ?? 0, request_id: requestId },
    { headers: { "X-Request-ID": requestId }, status: 200 },
  );
}

async function safeJson(request: Request) {
  try {
    return (await request.json()) as { ids?: unknown };
  } catch {
    return {};
  }
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
