create table if not exists public.parking_space_availability_rules (
  id uuid primary key default gen_random_uuid(),
  parking_space_id uuid not null references public.parking_spaces(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  weekday integer not null check (weekday between 0 and 6),
  start_minute integer not null check (start_minute between 0 and 1410 and start_minute % 30 = 0),
  end_minute integer not null check (end_minute between 30 and 1440 and end_minute % 30 = 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_minute > start_minute),
  unique (parking_space_id, weekday, start_minute, end_minute)
);

create table if not exists public.parking_space_availability_exceptions (
  id uuid primary key default gen_random_uuid(),
  parking_space_id uuid not null references public.parking_spaces(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  exception_date date not null,
  is_available boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (parking_space_id, exception_date)
);

create index if not exists parking_space_availability_rules_space_weekday_idx
on public.parking_space_availability_rules (parking_space_id, weekday, start_minute);

create index if not exists parking_space_availability_exceptions_space_date_idx
on public.parking_space_availability_exceptions (parking_space_id, exception_date);

drop trigger if exists parking_space_availability_rules_set_updated_at on public.parking_space_availability_rules;
create trigger parking_space_availability_rules_set_updated_at
before update on public.parking_space_availability_rules
for each row
execute function public.set_updated_at();

drop trigger if exists parking_space_availability_exceptions_set_updated_at on public.parking_space_availability_exceptions;
create trigger parking_space_availability_exceptions_set_updated_at
before update on public.parking_space_availability_exceptions
for each row
execute function public.set_updated_at();

alter table public.parking_space_availability_rules enable row level security;
alter table public.parking_space_availability_rules force row level security;
alter table public.parking_space_availability_exceptions enable row level security;
alter table public.parking_space_availability_exceptions force row level security;

drop policy if exists "parking_space_availability_rules_select_own" on public.parking_space_availability_rules;
create policy "parking_space_availability_rules_select_own"
on public.parking_space_availability_rules
for select
to authenticated
using ((select auth.uid()) = host_id);

drop policy if exists "parking_space_availability_rules_insert_own_draft" on public.parking_space_availability_rules;
create policy "parking_space_availability_rules_insert_own_draft"
on public.parking_space_availability_rules
for insert
to authenticated
with check (
  (select auth.uid()) = host_id
  and exists (
    select 1
    from public.parking_spaces ps
    where ps.id = parking_space_id
      and ps.host_id = (select auth.uid())
      and ps.status = 'draft'
  )
);

drop policy if exists "parking_space_availability_rules_update_own_draft" on public.parking_space_availability_rules;
create policy "parking_space_availability_rules_update_own_draft"
on public.parking_space_availability_rules
for update
to authenticated
using (
  (select auth.uid()) = host_id
  and exists (
    select 1
    from public.parking_spaces ps
    where ps.id = parking_space_id
      and ps.host_id = (select auth.uid())
      and ps.status = 'draft'
  )
)
with check ((select auth.uid()) = host_id);

drop policy if exists "parking_space_availability_rules_delete_own_draft" on public.parking_space_availability_rules;
create policy "parking_space_availability_rules_delete_own_draft"
on public.parking_space_availability_rules
for delete
to authenticated
using (
  (select auth.uid()) = host_id
  and exists (
    select 1
    from public.parking_spaces ps
    where ps.id = parking_space_id
      and ps.host_id = (select auth.uid())
      and ps.status = 'draft'
  )
);

drop policy if exists "parking_space_availability_exceptions_select_own" on public.parking_space_availability_exceptions;
create policy "parking_space_availability_exceptions_select_own"
on public.parking_space_availability_exceptions
for select
to authenticated
using ((select auth.uid()) = host_id);

drop policy if exists "parking_space_availability_exceptions_insert_own_draft" on public.parking_space_availability_exceptions;
create policy "parking_space_availability_exceptions_insert_own_draft"
on public.parking_space_availability_exceptions
for insert
to authenticated
with check (
  (select auth.uid()) = host_id
  and exists (
    select 1
    from public.parking_spaces ps
    where ps.id = parking_space_id
      and ps.host_id = (select auth.uid())
      and ps.status = 'draft'
  )
);

drop policy if exists "parking_space_availability_exceptions_update_own_draft" on public.parking_space_availability_exceptions;
create policy "parking_space_availability_exceptions_update_own_draft"
on public.parking_space_availability_exceptions
for update
to authenticated
using (
  (select auth.uid()) = host_id
  and exists (
    select 1
    from public.parking_spaces ps
    where ps.id = parking_space_id
      and ps.host_id = (select auth.uid())
      and ps.status = 'draft'
  )
)
with check ((select auth.uid()) = host_id);

drop policy if exists "parking_space_availability_exceptions_delete_own_draft" on public.parking_space_availability_exceptions;
create policy "parking_space_availability_exceptions_delete_own_draft"
on public.parking_space_availability_exceptions
for delete
to authenticated
using (
  (select auth.uid()) = host_id
  and exists (
    select 1
    from public.parking_spaces ps
    where ps.id = parking_space_id
      and ps.host_id = (select auth.uid())
      and ps.status = 'draft'
  )
);

revoke all on table public.parking_space_availability_rules from anon;
revoke all on table public.parking_space_availability_rules from authenticated;
grant select, insert, delete on table public.parking_space_availability_rules to authenticated;
grant update (weekday, start_minute, end_minute, updated_at) on table public.parking_space_availability_rules to authenticated;

revoke all on table public.parking_space_availability_exceptions from anon;
revoke all on table public.parking_space_availability_exceptions from authenticated;
grant select, insert, delete on table public.parking_space_availability_exceptions to authenticated;
grant update (exception_date, is_available, updated_at) on table public.parking_space_availability_exceptions to authenticated;

create or replace function public.save_parking_space_pricing_and_availability(
  p_space_id uuid,
  p_expected_version integer,
  p_hourly_price integer,
  p_length_feet numeric,
  p_width_feet numeric,
  p_height_feet numeric,
  p_slots_count integer,
  p_availability_summary text,
  p_rules jsonb,
  p_blocked_dates text[]
)
returns public.parking_spaces
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space public.parking_spaces;
  v_rule jsonb;
  v_rule_count integer := 0;
  v_weekday integer;
  v_start_minute integer;
  v_end_minute integer;
  v_blocked_date text;
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

  if p_hourly_price < 10 or p_hourly_price > 10000 then
    raise exception 'Invalid hourly price' using errcode = '23514';
  end if;

  if p_length_feet < 4 or p_length_feet > 80 or p_width_feet < 3 or p_width_feet > 40 then
    raise exception 'Invalid parking dimensions' using errcode = '23514';
  end if;

  if p_height_feet is not null and (p_height_feet < 0 or p_height_feet > 30) then
    raise exception 'Invalid height clearance' using errcode = '23514';
  end if;

  if p_slots_count < 1 or p_slots_count > 50 then
    raise exception 'Invalid slot count' using errcode = '23514';
  end if;

  if p_rules is null or jsonb_typeof(p_rules) <> 'array' or jsonb_array_length(p_rules) = 0 then
    raise exception 'At least one availability rule is required' using errcode = '23514';
  end if;

  update public.parking_spaces
  set
    hourly_price = p_hourly_price,
    length_feet = p_length_feet,
    width_feet = p_width_feet,
    height_feet = p_height_feet,
    slots_count = p_slots_count,
    availability_summary = nullif(btrim(p_availability_summary), ''),
    version = version + 1,
    updated_at = now()
  where id = p_space_id
  returning *
  into v_space;

  delete from public.parking_space_availability_rules
  where parking_space_id = p_space_id
    and host_id = auth.uid();

  for v_rule in select * from jsonb_array_elements(p_rules)
  loop
    v_weekday := (v_rule ->> 'weekday')::integer;
    v_start_minute := (v_rule ->> 'start_minute')::integer;
    v_end_minute := (v_rule ->> 'end_minute')::integer;

    if v_weekday not between 0 and 6
      or v_start_minute not between 0 and 1410
      or v_end_minute not between 30 and 1440
      or v_start_minute % 30 <> 0
      or v_end_minute % 30 <> 0
      or v_end_minute <= v_start_minute then
      raise exception 'Invalid availability rule' using errcode = '23514';
    end if;

    insert into public.parking_space_availability_rules (
      parking_space_id,
      host_id,
      weekday,
      start_minute,
      end_minute
    )
    values (
      p_space_id,
      auth.uid(),
      v_weekday,
      v_start_minute,
      v_end_minute
    );

    v_rule_count := v_rule_count + 1;
  end loop;

  if v_rule_count = 0 then
    raise exception 'At least one availability rule is required' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.parking_space_availability_rules current_rule
    join public.parking_space_availability_rules compared_rule
      on compared_rule.parking_space_id = current_rule.parking_space_id
      and compared_rule.weekday = current_rule.weekday
      and compared_rule.id <> current_rule.id
      and current_rule.start_minute < compared_rule.end_minute
      and compared_rule.start_minute < current_rule.end_minute
    where current_rule.parking_space_id = p_space_id
  ) then
    raise exception 'Availability rules cannot overlap' using errcode = '23514';
  end if;

  delete from public.parking_space_availability_exceptions
  where parking_space_id = p_space_id
    and host_id = auth.uid();

  foreach v_blocked_date in array coalesce(p_blocked_dates, array[]::text[])
  loop
    if v_blocked_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      raise exception 'Invalid blocked date' using errcode = '23514';
    end if;

    insert into public.parking_space_availability_exceptions (
      parking_space_id,
      host_id,
      exception_date,
      is_available
    )
    values (
      p_space_id,
      auth.uid(),
      v_blocked_date::date,
      false
    );
  end loop;

  return v_space;
end;
$$;

revoke all on function public.save_parking_space_pricing_and_availability(
  uuid,
  integer,
  integer,
  numeric,
  numeric,
  numeric,
  integer,
  text,
  jsonb,
  text[]
) from public;
grant execute on function public.save_parking_space_pricing_and_availability(
  uuid,
  integer,
  integer,
  numeric,
  numeric,
  numeric,
  integer,
  text,
  jsonb,
  text[]
) to authenticated;

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
  v_availability_count integer;
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
  into v_availability_count
  from public.parking_space_availability_rules
  where parking_space_id = p_space_id
    and host_id = auth.uid();

  if v_availability_count < 1 then
    raise exception 'At least one availability rule is required' using errcode = '23514';
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

comment on table public.parking_space_availability_rules is
  'Recurring host availability windows stored as weekday and minutes since midnight in Asia/Kolkata.';

comment on table public.parking_space_availability_exceptions is
  'Date-only host availability exceptions. V1 stores blocked full days only.';
