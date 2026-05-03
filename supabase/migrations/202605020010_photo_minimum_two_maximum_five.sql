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
    or v_space.slots_count < 1
    or v_space.available_from_date is null
    or v_space.available_to_date is null
    or v_space.available_to_date < v_space.available_from_date
    or v_space.daily_start_minute is null
    or v_space.daily_end_minute is null
    or v_space.daily_start_minute not between 0 and 1410
    or v_space.daily_end_minute not between 30 and 1440
    or v_space.daily_start_minute % 30 <> 0
    or v_space.daily_end_minute % 30 <> 0
    or v_space.daily_end_minute <= v_space.daily_start_minute then
    raise exception 'Listing is incomplete' using errcode = '23514';
  end if;

  select count(*)
  into v_photo_count
  from public.parking_space_photos
  where parking_space_id = p_space_id
    and host_id = auth.uid()
    and upload_status = 'linked';

  if v_photo_count < 2 then
    raise exception 'At least two photos are required' using errcode = '23514';
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

comment on function public.submit_parking_space_for_review(uuid, integer) is
  'Draft-only review submission gate. Existing pending/live listings created under older photo rules remain grandfathered.';
