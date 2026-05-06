create table if not exists public.parking_listing_revisions (
  space_id uuid primary key references public.parking_spaces(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  listing_revision integer not null default 1 check (listing_revision > 0),
  reason text not null default 'listing',
  updated_at timestamptz not null default now()
);

create index if not exists parking_listing_revisions_host_updated_idx
on public.parking_listing_revisions (host_id, updated_at desc);

alter table public.parking_listing_revisions enable row level security;
alter table public.parking_listing_revisions force row level security;

drop policy if exists "parking_listing_revisions_public_select" on public.parking_listing_revisions;
create policy "parking_listing_revisions_public_select"
on public.parking_listing_revisions
for select
to anon, authenticated
using (true);

grant select on table public.parking_listing_revisions to anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'parking_listing_revisions'
  ) then
    alter publication supabase_realtime add table public.parking_listing_revisions;
  end if;
end $$;

create or replace function public.touch_parking_listing_revision(
  p_space_id uuid,
  p_reason text default 'listing'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_host_id uuid;
begin
  select host_id
  into v_host_id
  from public.parking_spaces
  where id = p_space_id;

  if v_host_id is null then
    delete from public.parking_listing_revisions
    where space_id = p_space_id;
    return;
  end if;

  insert into public.parking_listing_revisions (
    space_id,
    host_id,
    listing_revision,
    reason,
    updated_at
  )
  values (
    p_space_id,
    v_host_id,
    1,
    coalesce(nullif(btrim(p_reason), ''), 'listing'),
    now()
  )
  on conflict (space_id) do update
  set
    host_id = excluded.host_id,
    listing_revision = public.parking_listing_revisions.listing_revision + 1,
    reason = excluded.reason,
    updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.touch_parking_listing_revision(uuid, text) from public;
grant execute on function public.touch_parking_listing_revision(uuid, text) to authenticated;

create or replace function public.sync_parking_space_revision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.touch_parking_listing_revision(old.id, 'listing_deleted');
    return old;
  end if;

  if new.status = 'active' then
    perform public.touch_parking_listing_revision(new.id, 'listing');
  elsif tg_op = 'UPDATE' and old.status = 'active' then
    perform public.touch_parking_listing_revision(old.id, 'listing_status');
  end if;

  return new;
end;
$$;

create or replace function public.sync_parking_photo_revision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space_id uuid;
begin
  v_space_id := coalesce(new.parking_space_id, old.parking_space_id);
  if v_space_id is not null then
    perform public.touch_parking_listing_revision(v_space_id, 'photos');
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.sync_host_profile_listing_revisions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space record;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new.full_name is not distinct from old.full_name
    and new.avatar_url is not distinct from old.avatar_url
    and new.phone is not distinct from old.phone then
    return new;
  end if;

  for v_space in
    select id
    from public.parking_spaces
    where host_id = new.id
      and status = 'active'
  loop
    perform public.touch_parking_listing_revision(v_space.id, 'host_profile');
  end loop;

  return new;
end;
$$;

drop trigger if exists parking_spaces_revision_sync on public.parking_spaces;
create trigger parking_spaces_revision_sync
after insert or update or delete on public.parking_spaces
for each row
execute function public.sync_parking_space_revision();

drop trigger if exists parking_space_photos_revision_sync on public.parking_space_photos;
create trigger parking_space_photos_revision_sync
after insert or update or delete on public.parking_space_photos
for each row
execute function public.sync_parking_photo_revision();

drop trigger if exists profiles_listing_revision_sync on public.profiles;
create trigger profiles_listing_revision_sync
after update of full_name, avatar_url, phone on public.profiles
for each row
execute function public.sync_host_profile_listing_revisions();

insert into public.parking_listing_revisions (
  space_id,
  host_id,
  listing_revision,
  reason,
  updated_at
)
select
  ps.id,
  ps.host_id,
  1,
  'backfill',
  greatest(ps.updated_at, coalesce(max(psp.updated_at), ps.updated_at))
from public.parking_spaces ps
left join public.parking_space_photos psp on psp.parking_space_id = ps.id
where ps.status = 'active'
group by ps.id, ps.host_id, ps.updated_at
on conflict (space_id) do nothing;

create or replace function public.get_public_parking_spot(p_space_id uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
  with target as (
    select
      ps.id,
      ps.host_id,
      coalesce(ps.title, 'Parking space') as title,
      coalesce(ps.address, '') as address,
      nullif(btrim(to_jsonb(ps)->>'city'), '') as city,
      nullif(btrim(to_jsonb(ps)->>'postal_code'), '') as postal_code,
      coalesce(ps.locality, '') as locality,
      coalesce(ps.latitude, 13.0827)::double precision as latitude,
      coalesce(ps.longitude, 80.2707)::double precision as longitude,
      nullif(btrim(to_jsonb(ps)->>'address_place_id'), '') as address_place_id,
      nullif(btrim(to_jsonb(ps)->>'address_provider'), '') as address_provider,
      nullif(to_jsonb(ps)->>'address_confidence', '')::numeric as address_confidence,
      coalesce(ps.hourly_price, 0) as hourly_price,
      coalesce(ps.slots_count, 0) as slots_count,
      ps.availability_summary,
      coalesce(
        nullif(to_jsonb(ps)->>'available_from_date', '')::date,
        current_date
      ) as available_from_date,
      coalesce(
        nullif(to_jsonb(ps)->>'available_to_date', '')::date,
        current_date + 29
      ) as available_to_date,
      coalesce(
        nullif(to_jsonb(ps)->>'daily_start_minute', '')::integer,
        8 * 60
      ) as daily_start_minute,
      coalesce(
        nullif(to_jsonb(ps)->>'daily_end_minute', '')::integer,
        20 * 60
      ) as daily_end_minute,
      ps.parking_type,
      ps.vehicle_fit,
      ps.version,
      ps.updated_at
    from public.parking_spaces ps
    where ps.id = p_space_id
      and ps.status = 'active'
  ),
  photo_data as (
    select
      psp.parking_space_id,
      coalesce(
        array_agg(psp.secure_url order by psp.sort_order asc, psp.created_at asc)
          filter (
            where psp.upload_status = 'linked'
              and nullif(btrim(psp.secure_url), '') is not null
          ),
        array[]::text[]
      ) as image_urls
    from public.parking_space_photos psp
    join target t on t.id = psp.parking_space_id
    group by psp.parking_space_id
  )
  select jsonb_build_object(
    'id', t.id,
    'title', t.title,
    'address', t.address,
    'addressConfidence', t.address_confidence,
    'addressPlaceId', t.address_place_id,
    'addressProvider', t.address_provider,
    'city', t.city,
    'locality', t.locality,
    'postalCode', t.postal_code,
    'distanceKm', 0,
    'rating', 0,
    'reviewCount', 0,
    'price', t.hourly_price,
    'currency', 'INR',
    'cadence', 'hourly',
    'availabilitySummary', nullif(btrim(t.availability_summary), ''),
    'availableFromDate', to_char(t.available_from_date, 'YYYY-MM-DD'),
    'availableToDate', to_char(t.available_to_date, 'YYYY-MM-DD'),
    'dailyStartMinute', t.daily_start_minute,
    'dailyEndMinute', t.daily_end_minute,
    'availableFrom',
      to_char(t.available_from_date, 'YYYY-MM-DD')
      || 'T'
      || lpad((t.daily_start_minute / 60)::text, 2, '0')
      || ':'
      || lpad((t.daily_start_minute % 60)::text, 2, '0')
      || ':00.000+05:30',
    'availableUntil',
      to_char(t.available_to_date, 'YYYY-MM-DD')
      || 'T'
      || lpad((t.daily_end_minute / 60)::text, 2, '0')
      || ':'
      || lpad((t.daily_end_minute % 60)::text, 2, '0')
      || ':00.000+05:30',
    'slotsAvailable', t.slots_count,
    'location', jsonb_build_object(
      'latitude', t.latitude,
      'longitude', t.longitude
    ),
    'amenities', to_jsonb(
      case
        when cardinality(a.amenities) = 0 then array['covered']
        else a.amenities
      end
    ),
    'imageUrl', coalesce(
      pd.image_urls[1],
      'https://images.unsplash.com/photo-1506521781263-d8422e82f27a'
    ),
    'imageUrls', to_jsonb(
      case
        when cardinality(coalesce(pd.image_urls, array[]::text[])) = 0 then array[
          'https://images.unsplash.com/photo-1506521781263-d8422e82f27a'
        ]
        else pd.image_urls
      end
    ),
    'hostName', nullif(btrim(to_jsonb(p)->>'full_name'), ''),
    'hostAvatarUrl', nullif(btrim(to_jsonb(p)->>'avatar_url'), ''),
    'hostPhone', nullif(btrim(to_jsonb(p)->>'phone'), ''),
    'hostRole', coalesce(nullif(btrim(to_jsonb(p)->>'role'), ''), 'host'),
    'isHostedByCurrentUser', coalesce(auth.uid() = t.host_id, false),
    'listingRevision', coalesce(plr.listing_revision, 0),
    'updatedAt', t.updated_at,
    'version', t.version
  )
  from target t
  left join photo_data pd on pd.parking_space_id = t.id
  left join public.profiles p on p.id = t.host_id
  left join public.parking_listing_revisions plr on plr.space_id = t.id
  cross join lateral (
    select array_remove(
      array[
        case
          when t.parking_type in ('covered', 'garage', 'basement')
            then 'covered'
          else null
        end,
        case
          when t.vehicle_fit = 'bike'
            then 'twoWheeler'
          else null
        end
      ],
      null
    ) as amenities
  ) a;
$$;

revoke all on function public.get_public_parking_spot(uuid) from public;
grant execute on function public.get_public_parking_spot(uuid) to anon, authenticated;

create or replace function public.get_owned_parking_spaces()
returns setof jsonb
language sql
security definer
set search_path = public
as $$
  select public.get_public_parking_spot(ps.id)
  from public.parking_spaces ps
  where ps.host_id = auth.uid()
    and ps.status = 'active'
  order by ps.updated_at desc;
$$;

revoke all on function public.get_owned_parking_spaces() from public;
grant execute on function public.get_owned_parking_spaces() to authenticated;

create or replace function public.update_owned_parking_space_address(
  p_space_id uuid,
  p_expected_version integer,
  p_address text,
  p_locality text,
  p_city text,
  p_postal_code text,
  p_latitude double precision,
  p_longitude double precision,
  p_address_provider text,
  p_address_confidence numeric,
  p_address_place_id text default null,
  p_address_raw_osm_json jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space public.parking_spaces;
begin
  select *
  into v_space
  from public.parking_spaces
  where id = p_space_id
    and host_id = auth.uid()
    and status = 'active'
  for update;

  if not found then
    raise exception 'Active listing not found' using errcode = 'P0002';
  end if;

  if v_space.version <> p_expected_version then
    raise exception 'Stale listing version' using errcode = '40001';
  end if;

  if nullif(btrim(p_address), '') is null
    or nullif(btrim(p_locality), '') is null
    or nullif(btrim(p_city), '') is null
    or p_postal_code !~ '^[1-9][0-9]{5}$'
    or p_latitude not between 6 and 38
    or p_longitude not between 68 and 98
    or p_address_provider not in ('nominatim', 'manual')
    or p_address_confidence is null
    or p_address_confidence < 0
    or p_address_confidence > 1 then
    raise exception 'Listing address is invalid' using errcode = '23514';
  end if;

  update public.parking_spaces
  set
    address = btrim(p_address),
    locality = btrim(p_locality),
    city = btrim(p_city),
    postal_code = btrim(p_postal_code),
    latitude = p_latitude,
    longitude = p_longitude,
    address_place_id = nullif(btrim(p_address_place_id), ''),
    address_provider = p_address_provider,
    address_confidence = p_address_confidence,
    address_raw_osm_json = p_address_raw_osm_json,
    location_confirmed_at = now(),
    version = version + 1,
    updated_at = now()
  where id = p_space_id
  returning *
  into v_space;

  return public.get_public_parking_spot(v_space.id);
end;
$$;

revoke all on function public.update_owned_parking_space_address(
  uuid,
  integer,
  text,
  text,
  text,
  text,
  double precision,
  double precision,
  text,
  numeric,
  text,
  jsonb
) from public;
grant execute on function public.update_owned_parking_space_address(
  uuid,
  integer,
  text,
  text,
  text,
  text,
  double precision,
  double precision,
  text,
  numeric,
  text,
  jsonb
) to authenticated;

create or replace function public.update_owned_parking_space_pricing(
  p_space_id uuid,
  p_expected_version integer,
  p_hourly_price integer,
  p_slots_count integer,
  p_available_from_date date,
  p_available_to_date date,
  p_daily_start_minute integer,
  p_daily_end_minute integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space public.parking_spaces;
begin
  select *
  into v_space
  from public.parking_spaces
  where id = p_space_id
    and host_id = auth.uid()
    and status = 'active'
  for update;

  if not found then
    raise exception 'Active listing not found' using errcode = 'P0002';
  end if;

  if v_space.version <> p_expected_version then
    raise exception 'Stale listing version' using errcode = '40001';
  end if;

  if p_hourly_price < 10
    or p_hourly_price > 10000
    or p_slots_count < 1
    or p_slots_count > 50
    or p_available_from_date is null
    or p_available_to_date is null
    or p_available_to_date < p_available_from_date
    or p_daily_start_minute not between 0 and 1410
    or p_daily_end_minute not between 30 and 1440
    or p_daily_start_minute % 30 <> 0
    or p_daily_end_minute % 30 <> 0
    or p_daily_end_minute <= p_daily_start_minute then
    raise exception 'Listing pricing is invalid' using errcode = '23514';
  end if;

  update public.parking_spaces
  set
    hourly_price = p_hourly_price,
    slots_count = p_slots_count,
    available_from_date = p_available_from_date,
    available_to_date = p_available_to_date,
    daily_start_minute = p_daily_start_minute,
    daily_end_minute = p_daily_end_minute,
    version = version + 1,
    updated_at = now()
  where id = p_space_id
  returning *
  into v_space;

  return public.get_public_parking_spot(v_space.id);
end;
$$;

revoke all on function public.update_owned_parking_space_pricing(
  uuid,
  integer,
  integer,
  integer,
  date,
  date,
  integer,
  integer
) from public;
grant execute on function public.update_owned_parking_space_pricing(
  uuid,
  integer,
  integer,
  integer,
  date,
  date,
  integer,
  integer
) to authenticated;

comment on table public.parking_listing_revisions is
  'Public realtime-safe revision metadata for active parking listings. It intentionally contains no private profile fields.';

comment on function public.update_owned_parking_space_address(
  uuid,
  integer,
  text,
  text,
  text,
  text,
  double precision,
  double precision,
  text,
  numeric,
  text,
  jsonb
) is
  'Owner-only active listing address update with optimistic version conflict protection.';

comment on function public.update_owned_parking_space_pricing(
  uuid,
  integer,
  integer,
  integer,
  date,
  date,
  integer,
  integer
) is
  'Owner-only active listing pricing and availability update with optimistic version conflict protection.';
