const endpoint =
  process.env.NOTIFICATION_WORKER_ENDPOINT ||
  "https://lotzi.in/api/internal/notifications/process";
const secret = process.env.NOTIFICATION_WORKER_SECRET || process.env.CRON_SECRET;
const intervalMs = Number(process.env.NOTIFICATION_WORKER_INTERVAL_MS || 5000);
const workerId =
  process.env.NOTIFICATION_WORKER_ID ||
  `notification-worker-${Math.random().toString(36).slice(2)}`;

if (!secret) {
  throw new Error("NOTIFICATION_WORKER_SECRET or CRON_SECRET is required.");
}

async function tick() {
  const requestId = `${workerId}-${Date.now()}`;
  const response = await fetch(endpoint, {
    headers: {
      Authorization: `Bearer ${secret}`,
      "Content-Type": "application/json",
      "X-Request-ID": requestId,
      "X-Worker-ID": workerId,
    },
    method: "POST",
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Notification worker tick failed: ${response.status} ${text}`);
  }
  console.log(text);
}

async function loop() {
  for (;;) {
    const started = Date.now();
    try {
      await tick();
    } catch (error) {
      console.error(
        JSON.stringify({
          error: error instanceof Error ? error.message : String(error),
          event: "notification_worker_tick_failed",
          worker_id: workerId,
        }),
      );
    }
    const elapsed = Date.now() - started;
    await new Promise((resolve) =>
      setTimeout(resolve, Math.max(1000, intervalMs - elapsed)),
    );
  }
}

void loop();
