# Host Parking Drafts V2 Operating Model

## Production SLOs

| Area | Contract | Alert |
| --- | ---: | --- |
| Draft PATCH latency | p95 <= 400ms, p99 <= 800ms at Edge/RPC ingress | p99 > 1.2s for 10 minutes |
| Draft PATCH availability | 99.9% monthly | error-budget burn > 2x |
| Local autosave durability | 99.99% successful local writes | failure > 0.1% |
| Publish transaction latency | p95 <= 900ms, p99 <= 2s | p99 > 3s for 10 minutes |
| Conflict rate | < 1% of autosaves | > 3% for 30 minutes |
| Photo completion success | >= 99%, excluding user cancellation | failure > 2% |
| Offline queue drain | p95 <= 30s after reconnect | p95 > 2 minutes |

## Capacity Envelope

- Naive worst case: 10,000 concurrent hosts autosaving every 1.2s is about 8,333 draft patch requests per second.
- Expected with client coalescing: one remote patch every 8-15s, or roughly 700-1,250 requests per second.
- Design target: sustain 1,500 requests per second and burst to 5,000 requests per second for five minutes.
- Degradation ladder: raise client debounce, batch field masks, return `429 Retry-After`, then enable queued write-behind if database CPU stays above 70% for 15 minutes.

## Rollout And Rollback

- Gate new draft creation behind `host_parking_drafts_v2`.
- Ramp internal, 1%, 5%, 25%, 50%, 100%, with 24-hour holds.
- Halt if autosave failure exceeds 1%, publish failure exceeds 2%, conflict rate exceeds 3%, or draft patch p99 exceeds 1.2s for 10 minutes.
- Kill switch disables new V2 draft creation while preserving existing V2 draft read/edit.
- Keep dual-read for 30 days and retain fallback support until V2 runs 14 days at 100% without an SLO breach.

## Sensitive Data Policy

`draft_mutation_log` is service-role only. It is never client-readable, never added to Supabase Realtime, and never exported without redaction. Its patch metadata can reveal address, description, or pricing intent, so successful rows are retained for 30 days and failed/conflict rows for 90 days before purge or non-PII compaction.
