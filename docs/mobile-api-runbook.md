# Mobile API Runbook

## Original Failure Reproduction

Before this fix, production returned the admin 404 HTML page for the mobile API:

```powershell
curl.exe -i -L --max-time 20 https://lotzi.in/api/v1/geo-discovery/search `
  -H "Content-Type: application/json" `
  -d "{\"latitude\":8.713,\"longitude\":77.422,\"serviceTypes\":[\"parking\"],\"radiusKm\":5,\"pageSize\":1,\"schemaVersion\":1}"
```

The broken response is `404 text/html`. Flutter must classify that as
`deployment_misconfiguration`, not retry it as a network error.

## Local Verification

Run the focused mobile API and geo checks:

```powershell
npm run analyze
npm run test -- --no-pub test/core/network/api_client_test.dart test/core/utils/geo_discovery/geo_discovery_engine_test.dart test/features/home/home_nearby_controller_test.dart
Set-Location admin
npm run typecheck
npm run lint
npm run test -- src/server/mobile-api/core.test.ts
```

## Deployment Order

1. Apply `supabase/migrations/202605080002_mobile_api_timeout_guards.sql`.
2. Deploy the admin app to a Vercel preview with `MOBILE_API_RATE_LIMIT_MODE=dry-run`.
3. Point one test device at the preview `API_BASE_URL` for 30 minutes.
4. Confirm `POST /api/v1/geo-discovery/search` returns JSON with `schemaVersion: 1`.
5. Confirm logs include `request_id`, `route`, `duration_ms`, `status_code`, and no raw coordinates or secrets.
6. Promote to production with `MOBILE_API_RATE_LIMIT_MODE=enforce`.

## Smoke Tests

```powershell
curl.exe -i --max-time 20 https://lotzi.in/api/v1/geo-discovery/search `
  -H "Content-Type: application/json" `
  -H "X-Request-ID: smoke-geo-001" `
  -d "{\"latitude\":8.713,\"longitude\":77.422,\"serviceTypes\":[\"parking\"],\"radiusKm\":5,\"pageSize\":1,\"schemaVersion\":1}"

curl.exe -i --max-time 20 https://lotzi.in/api/v1/bookings/quote `
  -H "Content-Type: application/json" `
  -H "X-Request-ID: smoke-quote-001" `
  -d "{}"
```

The quote smoke test should return a JSON validation error, not HTML.

For authenticated messaging routes, production also needs the public Supabase
anon key in the admin/Vercel environment. The admin API accepts either the
server names (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) or the existing mobile names
(`EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`):

```powershell
curl.exe -i --max-time 20 https://lotzi.in/api/v1/conversations `
  -H "Authorization: Bearer <valid-user-access-token>" `
  -H "X-Request-ID: smoke-messages-001"
```

Missing Supabase auth env should return JSON with
`code: deployment_misconfiguration` so the app can use its direct Supabase RPC
fallback instead of showing a generic internal error.

## Alerts

Configure the Vercel log drain destination with:

- Geo discovery 5xx rate above `1%` for 5 minutes.
- Geo discovery p95 latency above `3s` for 5 minutes.
- Any `deployment_misconfiguration` client event above zero.

## Rollback

If geo discovery 5xx exceeds `5%` for 2 minutes after production promotion:

1. Immediately roll back to the previous Vercel production deployment via
   `vercel rollback` or the Vercel dashboard.
2. Target recovery under 60 seconds.
3. Use `MOBILE_API_ENABLED=false` only as a temporary kill switch if rollback is blocked.
4. Keep rate limiting in enforce mode after rollback unless it is the confirmed cause.
