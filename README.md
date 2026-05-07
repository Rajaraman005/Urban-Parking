# Urban Parking Flutter

Production Flutter migration of the Urban Parking marketplace.

## Stack

- Flutter 3.41, Dart 3.11, iOS/Android.
- Clean Architecture with feature modules under `lib/features`.
- Riverpod for dependency injection and async state.
- `go_router` for route orchestration.
- Dio REST client, Supabase Auth/Postgres/Functions, secure storage.
- Google Maps, Geolocator, Hive-backed geo cache, cached network images.

## Architecture

```txt
lib/
  core/
    constants/
    errors/
    network/
    utils/
      geo_discovery/
  features/
    parking/
    rental/
    services/
    auth/
    home/
    booking/
    user_setup/
    onboarding/
    profile/
    legal/
    splash/
  shared/
  config/
  main.dart
```

Each feature keeps `data/`, `domain/`, and `presentation/` boundaries.
Widgets call Riverpod controllers, controllers call use cases/repositories, and
repositories compose REST/Supabase data sources.

## Geo Discovery

`lib/core/utils/geo_discovery/geo_discovery_engine.dart` implements:

- single and batch discovery for parking, rental, and services
- Haversine distance support
- stable query fingerprints and rounded geocells
- memory + Hive cache with fresh/stale windows
- in-flight request dedupe
- client rate guard and retry with jitter
- stale-cache fallback, invalid cursor recovery, and partial failures

Operational targets and rollout rules live in
`docs/flutter_migration_operating_model.md`.

### Geo Discovery Deployment Checklist

The mobile app calls `API_BASE_URL` for live nearby search. The deployed API
must have these Vercel/serverless environment variables:

```bash
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-public-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

The geo search endpoint also expects the Supabase migrations in
`supabase/migrations/` to be applied, especially
`202605060001_geo_discovery_public_search_repair.sql`. If that migration is
not deployed, the API can still use its service-role table fallback, but only
when `SUPABASE_SERVICE_ROLE_KEY` is configured on the API host.

## Environment

Local Flutter run/build commands read `.env` through
`scripts/flutter_with_env.ps1`. The bridge maps Flutter keys such as
`SUPABASE_URL` into `--dart-define` values without printing secret values.

```bash
npm run android
npm run build:android
```

When more than one Android phone is connected, choose the target device
explicitly:

```powershell
npm run devices
npm run android:device -- <device-id>
```

The raw Flutter bridge also accepts:

```powershell
scripts\flutter_with_env.ps1 run --device-id <device-id>
```

You can also keep using `npm run android` with a selected phone:

```powershell
$env:URBAN_PARKING_DEVICE_ID="<device-id>"
npm run android
```

For Android maps, set this in `.env`:

```bash
GOOGLE_MAPS_API_KEY=your-android-google-maps-api-key
```

## Verification

```bash
npm run verify
```

For a faster loop without rebuilding the APK:

```bash
npm run verify:quick
```

The backend folders `api/` and `supabase/` are preserved as the authoritative
REST/Supabase contracts for the Flutter app.
