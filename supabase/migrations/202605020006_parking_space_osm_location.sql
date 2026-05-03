alter table public.parking_spaces
add column if not exists latitude numeric(9,6),
add column if not exists longitude numeric(9,6),
add column if not exists address_place_id text,
add column if not exists address_provider text,
add column if not exists address_confidence numeric(4,3),
add column if not exists address_raw_osm_json jsonb,
add column if not exists location_confirmed_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'parking_spaces_address_provider_check'
  ) then
    alter table public.parking_spaces
    add constraint parking_spaces_address_provider_check
    check (address_provider is null or address_provider in ('nominatim', 'manual'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'parking_spaces_address_confidence_check'
  ) then
    alter table public.parking_spaces
    add constraint parking_spaces_address_confidence_check
    check (address_confidence is null or (address_confidence >= 0 and address_confidence <= 1));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'parking_spaces_india_coordinates_check'
  ) then
    alter table public.parking_spaces
    add constraint parking_spaces_india_coordinates_check
    check (
      (latitude is null and longitude is null)
      or (latitude between 6 and 38 and longitude between 68 and 98)
    );
  end if;
end $$;

create table if not exists public.address_geocode_cache (
  cache_key text primary key,
  lookup_type text not null check (lookup_type in ('search', 'reverse')),
  result jsonb not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.address_lookup_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  lookup_type text not null check (lookup_type in ('search', 'reverse')),
  created_at timestamptz not null default now()
);

create index if not exists address_geocode_cache_expiry_idx
on public.address_geocode_cache (expires_at);

create index if not exists address_lookup_events_user_recent_idx
on public.address_lookup_events (user_id, created_at desc);

create index if not exists address_lookup_events_recent_idx
on public.address_lookup_events (created_at desc);

drop trigger if exists address_geocode_cache_set_updated_at on public.address_geocode_cache;
create trigger address_geocode_cache_set_updated_at
before update on public.address_geocode_cache
for each row
execute function public.set_updated_at();

alter table public.address_geocode_cache enable row level security;
alter table public.address_geocode_cache force row level security;
alter table public.address_lookup_events enable row level security;
alter table public.address_lookup_events force row level security;

revoke all on table public.address_geocode_cache from anon;
revoke all on table public.address_geocode_cache from authenticated;
revoke all on table public.address_lookup_events from anon;
revoke all on table public.address_lookup_events from authenticated;

grant update (
  latitude,
  longitude,
  address_place_id,
  address_provider,
  address_confidence,
  address_raw_osm_json,
  location_confirmed_at
) on table public.parking_spaces to authenticated;

create or replace function public.submit_parking_space_for_review(
  p_space_id uuid,
  p_expected_version integer
)
returns public.parking_spaces
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space public.parking_spaces;
  v_photo_count integer;
begin
  select *
  into v_space
  from public.parking_spaces
  where id = p_space_id
    and host_id = auth.uid()
    and status = 'draft'
  for update;

  if not found then
    raise exception 'Draft listing not found' using errcode = 'P0002';
  end if;

  if v_space.version <> p_expected_version then
    raise exception 'Stale listing version' using errcode = '40001';
  end if;

  if nullif(btrim(v_space.address), '') is null
    or nullif(btrim(v_space.locality), '') is null
    or nullif(btrim(v_space.city), '') is null
    or v_space.postal_code is null
    or v_space.postal_code !~ '^[1-9][0-9]{5}$'
    or v_space.latitude is null
    or v_space.longitude is null
    or v_space.latitude not between 6 and 38
    or v_space.longitude not between 68 and 98
    or v_space.address_provider not in ('nominatim', 'manual')
    or v_space.address_confidence is null
    or v_space.address_confidence < 0
    or v_space.address_confidence > 1
    or v_space.location_confirmed_at is null
    or v_space.vehicle_fit is null
    or v_space.parking_type is null
    or v_space.hourly_price is null
    or v_space.slots_count < 1 then
    raise exception 'Listing is incomplete' using errcode = '23514';
  end if;

  select count(*)
  into v_photo_count
  from public.parking_space_photos
  where parking_space_id = p_space_id
    and host_id = auth.uid()
    and upload_status = 'linked';

  if v_photo_count < 1 then
    raise exception 'At least one photo is required' using errcode = '23514';
  end if;

  update public.parking_spaces
  set
    status = 'pending_review',
    submitted_at = now(),
    version = version + 1
  where id = p_space_id
  returning *
  into v_space;

  update public.profiles
  set
    role = case when role = 'admin' then 'admin' else 'host' end,
    intent = 'host',
    setup_step = 'complete',
    setup_draft_id = p_space_id,
    onboarding_completed_at = coalesce(onboarding_completed_at, now()),
    version = version + 1
  where id = auth.uid();

  return v_space;
end;
$$;

revoke all on function public.submit_parking_space_for_review(uuid, integer) from public;
grant execute on function public.submit_parking_space_for_review(uuid, integer) to authenticated;

comment on column public.parking_spaces.latitude is
  'Confirmed host listing latitude. Must remain within India bounds.';
comment on column public.parking_spaces.longitude is
  'Confirmed host listing longitude. Must remain within India bounds.';
comment on column public.parking_spaces.address_confidence is
  'Normalized confidence score from 0 to 1 for the selected address source.';
comment on table public.address_geocode_cache is
  'Service-role only cache for normalized OSM/Nominatim address lookups.';
comment on table public.address_lookup_events is
  'Service-role only rate-limit ledger for address lookup attempts.';
