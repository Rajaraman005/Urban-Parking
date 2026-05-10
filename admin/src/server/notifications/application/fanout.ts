import "server-only";

import { getSupabaseAdmin } from "@/server/db/supabase";
import { providerFor } from "@/server/notifications/providers/delivery";
import { renderNotificationTemplate } from "./template-renderer";

type JsonMap = Record<string, unknown>;

type FanoutJobRow = {
  attempts: number;
  batch_size: number;
  cursor_offset: number;
  event_id: string;
  id: string;
  priority: string;
};

type DeliveryJobRow = {
  attempts: number;
  channel: string;
  id: string;
  idempotency_key: string;
  notification_id: string;
  priority: string;
  provider: string;
  recipient_id: string;
};

type NotificationEventRow = {
  actor_id: string | null;
  aggregate_id: string;
  aggregate_type: string;
  category: string;
  channels: string[];
  dedupe_key: string | null;
  event_type: string;
  id: string;
  payload: JsonMap;
  priority: string;
  recipient_selector: JsonMap;
  template_key: string;
  template_version: number;
  trace_id: string;
};

type TemplateRow = {
  body_template: string;
  deeplink_template: string | null;
  title_template: string;
};

type NotificationRow = {
  body: string | null;
  channels: string[];
  deeplink: string | null;
  id: string;
  priority: string;
  recipient_id: string;
  title: string | null;
};

const fanoutMaxAttempts = 8;
const retryScheduleSeconds = [30, 120, 600, 1800, 7200];

export async function processNotificationEngineTick(params: {
  deliveryLimit?: number;
  fanoutLimit?: number;
  workerId?: string;
} = {}) {
  const workerId = params.workerId ?? `next-${crypto.randomUUID()}`;
  const fanout = await processFanoutJobs({
    limit: params.fanoutLimit ?? 10,
    workerId,
  });
  const delivery = await processDeliveryJobs({
    limit: params.deliveryLimit ?? 50,
    workerId,
  });
  return { delivery, fanout, workerId };
}

export async function processFanoutJobs(params: {
  limit: number;
  workerId: string;
}) {
  const supabase = getSupabaseAdmin();
  const { data, error } = await supabase.rpc("claim_notification_fanout_jobs", {
    p_limit: params.limit,
    p_worker_id: params.workerId,
  });
  if (error) throw new Error(error.message);

  const jobs = (data ?? []) as FanoutJobRow[];
  let completed = 0;
  let failed = 0;
  for (const job of jobs) {
    try {
      await processOneFanoutJob(job);
      completed++;
    } catch (error) {
      failed++;
      await failFanoutJob(job, error);
    }
  }
  return { claimed: jobs.length, completed, failed };
}

async function processOneFanoutJob(job: FanoutJobRow) {
  const supabase = getSupabaseAdmin();
  const { data: event, error: eventError } = await supabase
    .from("notification_events")
    .select("*")
    .eq("id", job.event_id)
    .maybeSingle();
  if (eventError || !event) {
    throw new Error(eventError?.message ?? "Notification event was not found.");
  }

  const eventRow = event as NotificationEventRow;
  const recipientIds = recipientsForSelector(eventRow.recipient_selector);
  const batch = recipientIds.slice(
    job.cursor_offset,
    job.cursor_offset + job.batch_size,
  );
  if (batch.length === 0) {
    await markFanoutJobComplete(job, eventRow);
    return;
  }

  const template = await loadTemplate(
    eventRow.template_key,
    eventRow.template_version,
  );
  const notifications = batch.map((recipientId) =>
    notificationInsertFor(eventRow, template, recipientId),
  );

  const { data: inserted, error: insertError } = await supabase
    .from("notifications")
    .upsert(notifications, {
      ignoreDuplicates: true,
      onConflict: "event_id,recipient_id,category,dedupe_key_normalized",
    })
    .select("id,recipient_id,channels,priority,title,body,deeplink");
  if (insertError) throw new Error(insertError.message);

  await enqueueDeliveryJobs((inserted ?? []) as NotificationRow[]);

  const nextOffset = job.cursor_offset + batch.length;
  if (nextOffset >= recipientIds.length) {
    await markFanoutJobComplete(job, eventRow);
    return;
  }

  const { error } = await supabase
    .from("notification_fanout_jobs")
    .update({
      cursor_offset: nextOffset,
      locked_by: null,
      locked_until: null,
      status: "pending",
    })
    .eq("id", job.id);
  if (error) throw new Error(error.message);
}

function recipientsForSelector(selector: JsonMap) {
  if (selector.type !== "users" || !Array.isArray(selector.userIds)) {
    throw new Error("Only explicit user recipient selectors are enabled.");
  }
  return [...new Set(selector.userIds.map(String))];
}

async function loadTemplate(key: string, version: number): Promise<TemplateRow> {
  const { data, error } = await getSupabaseAdmin()
    .from("notification_templates")
    .select("title_template,body_template,deeplink_template")
    .eq("template_key", key)
    .eq("version", version)
    .maybeSingle();
  if (error || !data) {
    throw new Error(error?.message ?? `Notification template ${key}@${version} was not found.`);
  }
  return data as TemplateRow;
}

function notificationInsertFor(
  event: NotificationEventRow,
  template: TemplateRow,
  recipientId: string,
) {
  const payload = event.payload ?? {};
  return {
    actor_id: event.actor_id,
    aggregate_id: event.aggregate_id,
    aggregate_type: event.aggregate_type,
    body:
      renderNotificationTemplate(template.body_template, payload) ??
      stringField(payload, "body") ??
      "",
    category: event.category,
    channels: event.channels,
    deeplink:
      renderNotificationTemplate(template.deeplink_template, payload) ??
      stringField(payload, "deeplink"),
    dedupe_key: event.dedupe_key,
    event_id: event.id,
    event_type: event.event_type,
    payload,
    priority: event.priority,
    recipient_id: recipientId,
    status: "unread",
    template_key: event.template_key,
    template_version: event.template_version,
    title:
      renderNotificationTemplate(template.title_template, payload) ??
      stringField(payload, "title") ??
      "Lotzi update",
  };
}

async function enqueueDeliveryJobs(notifications: NotificationRow[]) {
  const rows = notifications.flatMap((notification) =>
    notification.channels
      .filter((channel) => channel !== "in_app")
      .map((channel) => ({
        channel,
        idempotency_key: `${notification.id}:${channel}`,
        next_attempt_at: new Date().toISOString(),
        notification_id: notification.id,
        priority: notification.priority,
        provider: providerFor(channel).name,
        recipient_id: notification.recipient_id,
        status: "pending",
      })),
  );
  if (rows.length === 0) return;

  const { error } = await getSupabaseAdmin()
    .from("notification_delivery_jobs")
    .upsert(rows, {
      ignoreDuplicates: true,
      onConflict: "idempotency_key",
    });
  if (error) throw new Error(error.message);
}

async function markFanoutJobComplete(
  job: FanoutJobRow,
  event: NotificationEventRow,
) {
  const supabase = getSupabaseAdmin();
  const [{ error: jobError }, { error: eventError }] = await Promise.all([
    supabase
      .from("notification_fanout_jobs")
      .update({
        locked_by: null,
        locked_until: null,
        status: "complete",
      })
      .eq("id", job.id),
    supabase
      .from("notification_events")
      .update({
        fanout_completed_at: new Date().toISOString(),
        status: "fanout_complete",
      })
      .eq("id", event.id),
  ]);
  if (jobError || eventError) {
    throw new Error(jobError?.message ?? eventError?.message);
  }
}

async function failFanoutJob(job: FanoutJobRow, error: unknown) {
  const message = errorMessage(error);
  const supabase = getSupabaseAdmin();
  if (job.attempts >= fanoutMaxAttempts) {
    await Promise.all([
      supabase
        .from("notification_fanout_jobs")
        .update({
          last_error: message,
          locked_by: null,
          locked_until: null,
          status: "dead_lettered",
        })
        .eq("id", job.id),
      supabase.from("notification_dead_letters").insert({
        payload: { job },
        reason: message,
        source_id: job.id,
        source_table: "notification_fanout_jobs",
      }),
    ]);
    return;
  }

  const { error: updateError } = await supabase
    .from("notification_fanout_jobs")
    .update({
      last_error: message,
      locked_by: null,
      locked_until: null,
      next_attempt_at: retryAt(job.attempts),
      status: "pending",
    })
    .eq("id", job.id);
  if (updateError) throw new Error(updateError.message);
}

export async function processDeliveryJobs(params: {
  limit: number;
  workerId: string;
}) {
  const supabase = getSupabaseAdmin();
  const { data, error } = await supabase.rpc(
    "claim_notification_delivery_jobs",
    {
      p_limit: params.limit,
      p_worker_id: params.workerId,
    },
  );
  if (error) throw new Error(error.message);

  const jobs = (data ?? []) as DeliveryJobRow[];
  let sent = 0;
  let failed = 0;
  for (const job of jobs) {
    try {
      const ok = await processOneDeliveryJob(job);
      if (ok) sent++;
      else failed++;
    } catch (deliveryError) {
      failed++;
      await failDeliveryJob(job, deliveryError, false);
    }
  }
  return { claimed: jobs.length, failed, sent };
}

async function processOneDeliveryJob(job: DeliveryJobRow) {
  const supabase = getSupabaseAdmin();
  const { data, error } = await supabase
    .from("notifications")
    .select("id,title,body,deeplink")
    .eq("id", job.notification_id)
    .maybeSingle();
  if (error || !data) {
    throw new Error(error?.message ?? "Notification was not found.");
  }

  const notification = data as {
    body: string | null;
    deeplink: string | null;
    id: string;
    title: string | null;
  };
  const provider = providerFor(job.channel);
  const startedAt = Date.now();
  const result = await provider.send({
    body: notification.body ?? "",
    deeplink: notification.deeplink ?? undefined,
    idempotencyKey: job.idempotency_key,
    notificationId: notification.id,
    recipientId: job.recipient_id,
    title: notification.title ?? "Lotzi update",
  });
  const latencyMs = Date.now() - startedAt;

  await supabase.from("notification_delivery_logs").insert({
    attempt: job.attempts,
    channel: job.channel,
    delivery_job_id: job.id,
    error_code: result.ok ? null : result.errorCode,
    error_message: result.ok ? null : result.errorMessage,
    latency_ms: latencyMs,
    notification_id: job.notification_id,
    provider: provider.name,
    provider_message_id: result.ok ? result.providerMessageId ?? null : null,
    provider_status_code: result.statusCode ?? null,
    recipient_id: job.recipient_id,
    status: result.ok && result.suppressed ? "suppressed" : result.ok ? "sent" : "failed",
  });

  if (!result.ok) {
    await failDeliveryJob(job, result.errorMessage, result.permanent);
    return false;
  }

  const { error: updateError } = await supabase
    .from("notification_delivery_jobs")
    .update({
      locked_by: null,
      locked_until: null,
      provider_message_id: result.providerMessageId ?? null,
      status: result.suppressed ? "suppressed" : "sent",
    })
    .eq("id", job.id);
  if (updateError) throw new Error(updateError.message);
  return true;
}

async function failDeliveryJob(
  job: DeliveryJobRow,
  error: unknown,
  permanent: boolean,
) {
  const message = errorMessage(error);
  const supabase = getSupabaseAdmin();
  const maxAttempts = maxAttemptsFor(job.channel);
  const finalStatus =
    permanent && job.channel === "sms"
      ? "suppressed"
      : permanent || job.attempts >= maxAttempts
        ? "dead_lettered"
        : "pending";

  await supabase
    .from("notification_delivery_jobs")
    .update({
      last_error: message,
      locked_by: null,
      locked_until: null,
      next_attempt_at: finalStatus === "pending" ? retryAt(job.attempts) : null,
      status: finalStatus,
    })
    .eq("id", job.id);

  if (finalStatus === "dead_lettered") {
    await supabase.from("notification_dead_letters").insert({
      payload: { job },
      reason: message,
      source_id: job.id,
      source_table: "notification_delivery_jobs",
    });
  }
}

function maxAttemptsFor(channel: string) {
  if (channel === "push") return 5;
  if (channel === "email") return 6;
  if (channel === "sms") return 0;
  return 3;
}

function retryAt(attempt: number) {
  const index = Math.min(
    Math.max(attempt - 1, 0),
    retryScheduleSeconds.length - 1,
  );
  const jitter = Math.floor(Math.random() * 15);
  return new Date(Date.now() + (retryScheduleSeconds[index] + jitter) * 1000)
    .toISOString();
}

function stringField(payload: JsonMap, key: string) {
  const value = payload[key];
  return typeof value === "string" && value.trim() ? value : undefined;
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
