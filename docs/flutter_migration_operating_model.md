# Flutter Migration Operating Model

## Success Criteria

| Area | Target | Rollback Trigger |
|---|---:|---:|
| Crash-free sessions | >= 99.8% | < 99.5% for 1 hour |
| Geo time to first result | p50 <= 900ms, p95 <= 3000ms | p95 > 4500ms |
| Warm-cache result render | p95 <= 250ms | p95 > 750ms |
| Geo API error rate | < 1.5% | > 4% for 15 min |
| Permission denial recovery | fallback/empty state shown 100% | blank screen or stuck loader |
| Cache hit rate after first search | >= 35% | < 15% after rollout |
| Flutter frame health | >= 95% frames under 16ms | visible jank in search/map |

## Observability

Required telemetry events are implemented in `lib/core/utils/telemetry.dart`.
Payloads must not include precise coordinates, passwords, OTPs, tokens,
authorization headers, or Cloudinary signatures. Geo telemetry logs rounded
geocells only.

Alerts:
- Geo error rate > 4% for 15 minutes.
- Schema mismatch > 0.5%.
- Crash-free sessions < 99.5%.
- Auth refresh failure > 3%.
- Upload completion failure > 2%.

## Failure Modes

The Flutter geo engine serves stale cache on REST/Supabase failure, retries
eligible transient errors with jitter, invalidates bad cursors by retrying the
first page once, and renders partial batch results without blocking healthy
service tabs.

Location behavior:
- GPS denied: show permission state; dev builds may use Chennai fallback.
- GPS timeout: use last known location; otherwise show typed error/fallback.
- Offline: avoid network spam; render cache or offline state.

## Rollout

Keep the last production build available until Flutter is fully stable. Roll
out via internal QA, alpha, beta, then staged production
25/50/100. Halt rollout and promote the prior store build if any rollback
trigger fires.

Risk flags to keep remotely controllable before launch:
- Batch geo discovery.
- Map rendering.
- Persistent geo cache.
- Dev/mock fallback behavior.
