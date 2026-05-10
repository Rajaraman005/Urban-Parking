# Notification Engine Runbook

## Worker

The worker calls the secured processing endpoint:

```text
POST /api/internal/notifications/process
Authorization: Bearer $NOTIFICATION_WORKER_SECRET
```

The first deploy can use the lightweight Node worker in
`services/notification-worker` or an external scheduler that calls the same
endpoint every 5 seconds. Scale out by running more workers; Postgres claims
jobs with `FOR UPDATE SKIP LOCKED`.

## SLO Alerts

- High-priority queue oldest pending job > 60 seconds.
- Fanout pending jobs > 10,000 or oldest fanout job > 5 minutes.
- DLQ rate > 0.1% of jobs over 15 minutes.
- Push permanent failure rate > 5% over 30 minutes.
- Feed API p95 > 250 ms or p99 > 750 ms for 10 minutes.
- Counter reconciliation drift > 100 for one user or > 1% of sampled users.

## Replay

Replay dead-lettered fanout or delivery work:

```text
POST /api/internal/notifications/replay-dlq
Authorization: Bearer $NOTIFICATION_WORKER_SECRET
Content-Type: application/json

{"ids":["<dead-letter-id>"]}
```

Keep DLQ replay paused during rollback unless explicitly approved.

## Provider Hygiene

- FCM `UNREGISTERED` and known-good `INVALID_ARGUMENT` responses should
  invalidate tokens immediately.
- Transient provider failures remain retryable.
- SMS remains intentionally disabled until a vendor is selected.
