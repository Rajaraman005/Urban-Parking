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

## Environment

Local Flutter run/build commands read `.env` through
`scripts/flutter_with_env.ps1`. The bridge maps existing Expo-style keys such as
`EXPO_PUBLIC_SUPABASE_URL` into Flutter `--dart-define` keys such as
`SUPABASE_URL`, without printing secret values.

```bash
npm run android
npm run build:android
```

For Android maps, set one of these in `.env`:

```bash
EXPO_PUBLIC_GOOGLE_MAPS_API_KEY=your-android-google-maps-api-key
```

or:

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
