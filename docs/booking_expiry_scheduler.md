# Booking Expiry Scheduler

Pending bookings expire through the secured API endpoint:

```text
POST /api/internal/jobs/expire-pending-bookings
Authorization: Bearer $CRON_SECRET
```

## Vercel Hobby Compatibility

Vercel Hobby only allows cron schedules that run once per day. To keep Hobby
deployments green, `admin/vercel.json` uses a daily safety-net invocation:

```json
{
  "path": "/api/internal/jobs/expire-pending-bookings",
  "schedule": "0 3 * * *"
}
```

That daily run is not the production active-expiry cadence. It is only a
deployment-safe backstop for Hobby projects.

## Five-Minute Active Expiry

Use one of these production schedulers:

1. GitHub Actions: enable `.github/workflows/expire-pending-bookings.yml`.
2. Vercel Pro or Enterprise: change the Vercel schedule to `*/5 * * * *`.
3. Any external scheduler: call the same endpoint every five minutes.

For GitHub Actions, configure repository secrets:

```text
BOOKING_EXPIRY_JOB_URL=https://your-domain.example/api/internal/jobs/expire-pending-bookings
CRON_SECRET=<same value configured in Vercel>
```

## Operations

Alert when the last successful expiry run is older than 10 minutes. This
threshold intentionally tolerates scheduler jitter and cold starts while still
catching broken auth, failed deployments, or a paused scheduler.

The expiry job processes up to 500 bookings per run. If
`expiryBatchSaturated=true` appears repeatedly, increase frequency or batch
size on a scheduler that supports the needed cadence.
