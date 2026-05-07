comment on column public.parking_spaces.access_instructions is
  'Host-written listing description shown to renters on the property details page.';

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
      nullif(btrim(to_jsonb(ps)->>'access_instructions'), '') as description,
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
    'description', t.description,
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

comment on function public.get_public_parking_spot(uuid) is
  'Returns a safe public parking listing payload with renter-facing description, real availability, ordered photos, and host contact metadata for active spaces only.';

notify pgrst, 'reload schema';
