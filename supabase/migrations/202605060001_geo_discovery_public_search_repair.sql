alter table public.parking_spaces
  add column if not exists latitude numeric(9,6),
  add column if not exists longitude numeric(9,6),
  add column if not exists available_from_date date,
  add column if not exists available_to_date date,
  add column if not exists daily_start_minute integer,
  add column if not exists daily_end_minute integer;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'parking_spaces_available_date_range_check'
  ) then
    alter table public.parking_spaces
      add constraint parking_spaces_available_date_range_check
      check (
        available_from_date is null
        or available_to_date is null
        or available_to_date >= available_from_date
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'parking_spaces_daily_minutes_check'
  ) then
    alter table public.parking_spaces
      add constraint parking_spaces_daily_minutes_check
      check (
        (
          daily_start_minute is null
          and daily_end_minute is null
        )
        or (
          daily_start_minute between 0 and 1410
          and daily_end_minute between 30 and 1440
          and daily_start_minute % 30 = 0
          and daily_end_minute % 30 = 0
          and daily_end_minute > daily_start_minute
        )
      );
  end if;
end
$$;

grant update (
  available_from_date,
  available_to_date,
  daily_start_minute,
  daily_end_minute
) on table public.parking_spaces to authenticated;

create index if not exists parking_spaces_active_location_idx
on public.parking_spaces (status, latitude, longitude)
where status = 'active' and latitude is not null and longitude is not null;

create or replace function public.search_public_parking_spots(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km double precision default 5,
  p_limit integer default 250,
  p_offset integer default 0
)
returns table (
  id uuid,
  title text,
  address text,
  locality text,
  latitude double precision,
  longitude double precision,
  slots_count integer,
  hourly_price integer,
  availability_summary text,
  parking_type text,
  vehicle_fit text,
  available_from_date date,
  available_to_date date,
  daily_start_minute integer,
  daily_end_minute integer,
  image_urls text[]
)
language sql
security definer
set search_path = public
as $$
  with normalized as (
    select
      p_latitude as latitude,
      p_longitude as longitude,
      least(greatest(coalesce(p_radius_km, 5), 1), 10) as radius_km,
      least(greatest(coalesce(p_limit, 250), 1), 250) as row_limit,
      greatest(coalesce(p_offset, 0), 0) as row_offset
  )
  select
    ps.id,
    coalesce(ps.title, 'Parking space') as title,
    coalesce(ps.address, '') as address,
    coalesce(ps.locality, '') as locality,
    ps.latitude::double precision as latitude,
    ps.longitude::double precision as longitude,
    ps.slots_count,
    ps.hourly_price,
    ps.availability_summary,
    ps.parking_type,
    ps.vehicle_fit,
    ps.available_from_date,
    ps.available_to_date,
    ps.daily_start_minute,
    ps.daily_end_minute,
    coalesce(photo_data.image_urls, array[]::text[]) as image_urls
  from normalized n
  join public.parking_spaces ps on true
  left join lateral (
    select coalesce(
      array_agg(psp.secure_url order by psp.sort_order asc, psp.created_at asc)
        filter (
          where psp.upload_status = 'linked'
            and nullif(btrim(psp.secure_url), '') is not null
        ),
      array[]::text[]
    ) as image_urls
    from public.parking_space_photos psp
    where psp.parking_space_id = ps.id
  ) photo_data on true
  where ps.status = 'active'
    and ps.latitude is not null
    and ps.longitude is not null
    and ps.latitude::double precision between n.latitude - n.radius_km / 111
      and n.latitude + n.radius_km / 111
    and ps.longitude::double precision between
      n.longitude - n.radius_km / (111 * greatest(cos(radians(n.latitude)), 0.2))
      and n.longitude + n.radius_km / (111 * greatest(cos(radians(n.latitude)), 0.2))
  order by
    abs(ps.latitude::double precision - n.latitude)
      + abs(ps.longitude::double precision - n.longitude),
    ps.id
  limit (select row_limit from normalized)
  offset (select row_offset from normalized);
$$;

revoke all on function public.search_public_parking_spots(
  double precision,
  double precision,
  double precision,
  integer,
  integer
) from public;
grant execute on function public.search_public_parking_spots(
  double precision,
  double precision,
  double precision,
  integer,
  integer
) to anon, authenticated;

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
      coalesce(ps.locality, '') as locality,
      coalesce(ps.latitude, 13.0827)::double precision as latitude,
      coalesce(ps.longitude, 80.2707)::double precision as longitude,
      coalesce(ps.hourly_price, 0) as hourly_price,
      coalesce(ps.slots_count, 0) as slots_count,
      ps.availability_summary,
      coalesce(ps.available_from_date, current_date) as available_from_date,
      coalesce(ps.available_to_date, current_date + 29) as available_to_date,
      coalesce(ps.daily_start_minute, 8 * 60) as daily_start_minute,
      coalesce(ps.daily_end_minute, 20 * 60) as daily_end_minute,
      ps.parking_type,
      ps.vehicle_fit
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
    'locality', t.locality,
    'distanceKm', 0,
    'rating', 0,
    'reviewCount', 0,
    'price', t.hourly_price,
    'currency', 'INR',
    'cadence', 'hourly',
    'availabilitySummary', nullif(btrim(t.availability_summary), ''),
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
    'hostRole', coalesce(nullif(btrim(to_jsonb(p)->>'role'), ''), 'host')
  )
  from target t
  left join photo_data pd on pd.parking_space_id = t.id
  left join public.profiles p on p.id = t.host_id
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

comment on function public.search_public_parking_spots(
  double precision,
  double precision,
  double precision,
  integer,
  integer
) is
  'Returns safe public active parking rows for geo discovery without exposing owner-only tables to anon clients.';

comment on function public.get_public_parking_spot(uuid) is
  'Returns a safe public parking listing payload with real availability, ordered photos, and host contact metadata for active spaces only.';
