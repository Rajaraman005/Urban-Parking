alter table public.parking_spaces
  add column if not exists available_from_date date,
  add column if not exists available_to_date date,
  add column if not exists daily_start_minute integer,
  add column if not exists daily_end_minute integer,
  add column if not exists skip_weekends boolean;

update public.parking_spaces
set
  available_from_date = coalesce(available_from_date, current_date),
  available_to_date = coalesce(available_to_date, current_date + 29),
  daily_start_minute = coalesce(daily_start_minute, 8 * 60),
  daily_end_minute = coalesce(daily_end_minute, 20 * 60),
  skip_weekends = coalesce(skip_weekends, false)
where available_from_date is null
  or available_to_date is null
  or daily_start_minute is null
  or daily_end_minute is null
  or skip_weekends is null;

alter table public.parking_spaces
  alter column skip_weekends set default false,
  alter column skip_weekends set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'parking_spaces_available_date_range_check'
  ) then
    alter table public.parking_spaces
      add constraint parking_spaces_available_date_range_check
      check (
        available_from_date is null
        or available_to_date is null
        or available_to_date >= available_from_date
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'parking_spaces_daily_minutes_check'
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
  daily_end_minute,
  skip_weekends
) on table public.parking_spaces to authenticated;

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
      coalesce(ps.available_from_date, current_date) as available_from_date,
      coalesce(ps.available_to_date, current_date + 29) as available_to_date,
      coalesce(ps.daily_start_minute, 8 * 60) as daily_start_minute,
      coalesce(ps.daily_end_minute, 20 * 60) as daily_end_minute,
      coalesce(ps.skip_weekends, false) as skip_weekends,
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
    'skipWeekends', t.skip_weekends,
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

create or replace function public.update_owned_parking_space_pricing(
  p_space_id uuid,
  p_expected_version integer,
  p_hourly_price integer,
  p_slots_count integer,
  p_available_from_date date,
  p_available_to_date date,
  p_daily_start_minute integer,
  p_daily_end_minute integer,
  p_skip_weekends boolean
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
    or p_daily_end_minute <= p_daily_start_minute
    or (
      coalesce(p_skip_weekends, false)
      and not exists (
        select 1
        from generate_series(p_available_from_date, p_available_to_date, interval '1 day') as active_day(day)
        where extract(isodow from active_day.day)::integer not in (6, 7)
      )
    ) then
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
    skip_weekends = coalesce(p_skip_weekends, false),
    version = version + 1,
    updated_at = now()
  where id = p_space_id
  returning *
  into v_space;

  return public.get_public_parking_spot(v_space.id);
end;
$$;

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
language sql
security definer
set search_path = public
as $$
  select public.update_owned_parking_space_pricing(
    p_space_id,
    p_expected_version,
    p_hourly_price,
    p_slots_count,
    p_available_from_date,
    p_available_to_date,
    p_daily_start_minute,
    p_daily_end_minute,
    coalesce((
      select ps.skip_weekends
      from public.parking_spaces ps
      where ps.id = p_space_id
        and ps.host_id = auth.uid()
    ), false)
  );
$$;

revoke all on function public.update_owned_parking_space_pricing(
  uuid,
  integer,
  integer,
  integer,
  date,
  date,
  integer,
  integer,
  boolean
) from public;
grant execute on function public.update_owned_parking_space_pricing(
  uuid,
  integer,
  integer,
  integer,
  date,
  date,
  integer,
  integer,
  boolean
) to authenticated;

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

comment on function public.update_owned_parking_space_pricing(
  uuid,
  integer,
  integer,
  integer,
  date,
  date,
  integer,
  integer,
  boolean
) is
  'Owner-only active listing pricing update with bounded dates, daily hours, weekend exclusion, and optimistic version conflict protection.';

notify pgrst, 'reload schema';
