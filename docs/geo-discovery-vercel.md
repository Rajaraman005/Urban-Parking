# Geo Discovery Vercel Deployment

## Endpoint

The mobile app expects this base URL:

```text
API_BASE_URL=https://lotzi.in/api/v1
```

The Vercel function is:

```text
POST /api/v1/geo-discovery/search
```

## Vercel Environment Variables

Set these in Vercel Project Settings:

```text
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
GEO_DISCOVERY_ALLOWED_ORIGIN=*
```

For a public mobile API, keep auth and abuse controls on the backend roadmap. The service role key must only exist in Vercel server env vars, never in client env vars.

## Client Environment Variable

Set this for production builds:

```text
API_BASE_URL=https://lotzi.in/api/v1
```

With the current domain, the app will call:

```text
https://lotzi.in/api/v1/geo-discovery/search
```

## Current Backend Coverage

- `parking`: backed by `public.parking_spaces` with active listings, coordinates, price, slots, and first linked photo.
- `rental`: returns a valid empty page until rental tables exist.
- `service`: returns a valid empty page until service tables exist.

The API accepts all service types in one request so the same location search does not fan out into three mobile requests.
