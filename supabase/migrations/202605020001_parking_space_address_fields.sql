alter table public.parking_spaces
add column if not exists city text,
add column if not exists postal_code text;

grant update (
  city,
  postal_code
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

comment on column public.parking_spaces.city is
  'City for host listing address validation and marketplace discovery.';

comment on column public.parking_spaces.postal_code is
  'Indian postal code for host listing address validation and regional discovery.';
