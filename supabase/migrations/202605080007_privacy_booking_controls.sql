create extension if not exists pgcrypto;
create extension if not exists btree_gist;

alter table public.profiles
add column if not exists show_phone_number boolean not null default false,
add column if not exists booking_approval_mode text not null default 'manual';

alter table public.profiles
drop constraint if exists profiles_booking_approval_mode_check;

alter table public.profiles
add constraint profiles_booking_approval_mode_check
check (booking_approval_mode in ('manual', 'auto'));

comment on column public.profiles.show_phone_number is
  'When false, phone is hidden from all public marketplace profile payloads.';

comment on column public.profiles.booking_approval_mode is
  'Host booking approval preference. manual creates pending requests; auto creates approved bookings.';

create or replace function public.update_profile_booking_controls(
  p_show_phone_number boolean,
  p_booking_approval_mode text,
  p_expected_version integer
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $update_profile_booking_controls$
declare
  v_profile public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_booking_approval_mode not in ('manual', 'auto') then
    raise exception 'Invalid booking approval mode' using errcode = '23514';
  end if;

  update public.profiles
  set
    show_phone_number = coalesce(p_show_phone_number, false),
    booking_approval_mode = p_booking_approval_mode,
    version = version + 1
  where id = auth.uid()
    and version = p_expected_version
  returning *
  into v_profile;

  if not found then
    raise exception 'Stale profile version' using errcode = '40001';
  end if;

  return v_profile;
end;
$update_profile_booking_controls$;

revoke all on function public.update_profile_booking_controls(boolean, text, integer) from public;
grant execute on function public.update_profile_booking_controls(boolean, text, integer) to authenticated;

create or replace function public.public_host_profile_payload(p_profile public.profiles)
returns jsonb
language sql
stable
security definer
set search_path = public
as $public_host_profile_payload$
  select jsonb_build_object(
    'hostName', nullif(btrim(to_jsonb(p_profile)->>'full_name'), ''),
    'hostAvatarUrl', nullif(btrim(to_jsonb(p_profile)->>'avatar_url'), ''),
    'hostPhone',
      case
        when coalesce((to_jsonb(p_profile)->>'show_phone_number')::boolean, false)
          then nullif(btrim(to_jsonb(p_profile)->>'phone'), '')
        else null
      end,
    'hostRole', coalesce(nullif(btrim(to_jsonb(p_profile)->>'role'), ''), 'host')
  );
$public_host_profile_payload$;

revoke all on function public.public_host_profile_payload(public.profiles) from public;
grant execute on function public.public_host_profile_payload(public.profiles) to anon, authenticated;

create or replace function public.ensure_user_profile(p_full_name text default null)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $ensure_user_profile$
declare
  v_user_id uuid := auth.uid();
  v_jwt jsonb := coalesce(auth.jwt(), '{}'::jsonb);
  v_full_name text := nullif(trim(coalesce(p_full_name, v_jwt -> 'user_metadata' ->> 'full_name', '')), '');
  v_phone text := nullif(trim(coalesce(v_jwt ->> 'phone', '')), '');
  v_profile public.profiles;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.profiles (
    id,
    full_name,
    phone,
    show_phone_number,
    booking_approval_mode
  )
  values (
    v_user_id,
    v_full_name,
    v_phone,
    false,
    'manual'
  )
  on conflict (id) do update
    set
      full_name = coalesce(public.profiles.full_name, excluded.full_name),
      phone = coalesce(public.profiles.phone, excluded.phone),
      show_phone_number = coalesce(public.profiles.show_phone_number, false),
      booking_approval_mode = coalesce(public.profiles.booking_approval_mode, 'manual')
  returning *
  into v_profile;

  return v_profile;
end;
$ensure_user_profile$;

revoke all on function public.ensure_user_profile(text) from public;
grant execute on function public.ensure_user_profile(text) to authenticated;

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.parking_spaces(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  renter_id uuid not null references auth.users(id) on delete cascade,
  slot_number integer not null check (slot_number > 0),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'expired')),
  vehicle_kind text not null check (vehicle_kind in ('bike', 'car')),
  start_at timestamptz not null,
  end_at timestamptz not null,
  expires_at timestamptz,
  subtotal integer not null check (subtotal >= 0),
  platform_fee integer not null check (platform_fee >= 0),
  taxes integer not null check (taxes >= 0),
  total integer not null check (total >= 0),
  currency text not null default 'INR',
  idempotency_key uuid not null,
  request_hash text not null,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_time_window_check check (end_at > start_at),
  constraint bookings_pending_expiry_check check (
    (status = 'pending' and expires_at is not null)
    or (status <> 'pending')
  ),
  constraint bookings_no_self_booking_check check (host_id <> renter_id),
  unique (renter_id, idempotency_key)
);

drop trigger if exists bookings_set_updated_at on public.bookings;
create trigger bookings_set_updated_at
before update on public.bookings
for each row
execute function public.set_updated_at();

create index if not exists bookings_host_status_updated_idx
on public.bookings (host_id, status, updated_at desc);

create index if not exists bookings_renter_status_updated_idx
on public.bookings (renter_id, status, updated_at desc);

create index if not exists bookings_space_status_window_idx
on public.bookings (space_id, status, start_at, end_at);

create index if not exists bookings_pending_expiry_idx
on public.bookings (expires_at, id)
where status = 'pending';

do $bookings_overlap_constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bookings_active_slot_no_overlap'
      and conrelid = 'public.bookings'::regclass
  ) then
    alter table public.bookings
    add constraint bookings_active_slot_no_overlap
    exclude using gist (
      space_id with =,
      slot_number with =,
      tstzrange(start_at, end_at, '[)') with &&
    )
    where (status in ('pending', 'approved'));
  end if;
end;
$bookings_overlap_constraint$;

create table if not exists public.booking_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null check (
    event_type in (
      'created',
      'approved',
      'rejected',
      'expired',
      'idempotent_replay'
    )
  ),
  previous_status text,
  new_status text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists booking_events_booking_created_idx
on public.booking_events (booking_id, created_at desc);

create table if not exists public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete cascade,
  event_type text not null,
  channel text not null default 'in_app' check (channel in ('in_app', 'push', 'sms', 'email')),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed', 'discarded')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists notification_outbox_set_updated_at on public.notification_outbox;
create trigger notification_outbox_set_updated_at
before update on public.notification_outbox
for each row
execute function public.set_updated_at();

create index if not exists notification_outbox_pending_idx
on public.notification_outbox (status, next_attempt_at, created_at)
where status = 'pending';

create index if not exists notification_outbox_booking_idx
on public.notification_outbox (booking_id, created_at desc);

create table if not exists public.booking_expiry_job_runs (
  id uuid primary key default gen_random_uuid(),
  ok boolean not null,
  expired_count integer not null default 0 check (expired_count >= 0),
  batch_size integer not null default 500 check (batch_size > 0),
  expiry_batch_saturated boolean not null default false,
  duration_ms integer not null default 0 check (duration_ms >= 0),
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists booking_expiry_job_runs_created_idx
on public.booking_expiry_job_runs (created_at desc);

alter table public.bookings enable row level security;
alter table public.bookings force row level security;
alter table public.booking_events enable row level security;
alter table public.booking_events force row level security;
alter table public.notification_outbox enable row level security;
alter table public.notification_outbox force row level security;
alter table public.booking_expiry_job_runs enable row level security;
alter table public.booking_expiry_job_runs force row level security;

drop policy if exists "bookings_select_participant" on public.bookings;
create policy "bookings_select_participant"
on public.bookings
for select
to authenticated
using ((select auth.uid()) = renter_id or (select auth.uid()) = host_id);

drop policy if exists "booking_events_select_participant" on public.booking_events;
create policy "booking_events_select_participant"
on public.booking_events
for select
to authenticated
using (
  exists (
    select 1
    from public.bookings b
    where b.id = booking_events.booking_id
      and ((select auth.uid()) = b.renter_id or (select auth.uid()) = b.host_id)
  )
);

drop policy if exists "notification_outbox_select_recipient" on public.notification_outbox;
create policy "notification_outbox_select_recipient"
on public.notification_outbox
for select
to authenticated
using ((select auth.uid()) = recipient_id);

drop policy if exists "booking_expiry_job_runs_no_client_access" on public.booking_expiry_job_runs;
create policy "booking_expiry_job_runs_no_client_access"
on public.booking_expiry_job_runs
for all
to anon, authenticated
using (false)
with check (false);

revoke all on table public.bookings from anon, authenticated;
grant select on table public.bookings to authenticated;

revoke all on table public.booking_events from anon, authenticated;
grant select on table public.booking_events to authenticated;

revoke all on table public.notification_outbox from anon, authenticated;
grant select on table public.notification_outbox to authenticated;

revoke all on table public.booking_expiry_job_runs from anon, authenticated;

do $booking_realtime_publication$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'bookings'
  ) then
    alter publication supabase_realtime add table public.bookings;
  end if;
end;
$booking_realtime_publication$;

create or replace function public.booking_request_hash(
  p_space_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_vehicle_kind text
)
returns text
language sql
immutable
set search_path = public, extensions
as $booking_request_hash$
  select encode(
    digest(
      convert_to(
        jsonb_build_object(
          'spotId', p_space_id,
          'startAt', to_char(p_start_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
          'endAt', to_char(p_end_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
          'vehicleKind', p_vehicle_kind
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
$booking_request_hash$;

create or replace function public.booking_to_json(p_booking public.bookings)
returns jsonb
language sql
stable
set search_path = public
as $booking_to_json$
  select jsonb_build_object(
    'id', p_booking.id,
    'spotId', p_booking.space_id,
    'spotTitle', (
      select s.title
      from public.parking_spaces s
      where s.id = p_booking.space_id
      limit 1
    ),
    'spotAddress', (
      select s.address
      from public.parking_spaces s
      where s.id = p_booking.space_id
      limit 1
    ),
    'spotLocality', (
      select s.locality
      from public.parking_spaces s
      where s.id = p_booking.space_id
      limit 1
    ),
    'hostId', p_booking.host_id,
    'hostName', (
      select h.full_name
      from public.profiles h
      where h.id = p_booking.host_id
      limit 1
    ),
    'hostAvatarUrl', (
      select h.avatar_url
      from public.profiles h
      where h.id = p_booking.host_id
      limit 1
    ),
    'renterId', p_booking.renter_id,
    'renterName', (
      select r.full_name
      from public.profiles r
      where r.id = p_booking.renter_id
      limit 1
    ),
    'renterAvatarUrl', (
      select r.avatar_url
      from public.profiles r
      where r.id = p_booking.renter_id
      limit 1
    ),
    'slotNumber', p_booking.slot_number,
    'status', p_booking.status,
    'vehicleKind', p_booking.vehicle_kind,
    'startAt', p_booking.start_at,
    'endAt', p_booking.end_at,
    'expiresAt', p_booking.expires_at,
    'subtotal', p_booking.subtotal,
    'platformFee', p_booking.platform_fee,
    'taxes', p_booking.taxes,
    'total', p_booking.total,
    'currency', p_booking.currency,
    'idempotencyKey', p_booking.idempotency_key,
    'requestHash', p_booking.request_hash,
    'version', p_booking.version,
    'createdAt', p_booking.created_at,
    'updatedAt', p_booking.updated_at
  );
$booking_to_json$;

create or replace function public.insert_booking_event(
  p_booking public.bookings,
  p_actor_id uuid,
  p_event_type text,
  p_previous_status text,
  p_new_status text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $insert_booking_event$
begin
  insert into public.booking_events (
    booking_id,
    actor_id,
    event_type,
    previous_status,
    new_status,
    metadata
  )
  values (
    p_booking.id,
    p_actor_id,
    p_event_type,
    p_previous_status,
    p_new_status,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$insert_booking_event$;

create or replace function public.enqueue_booking_notification(
  p_booking public.bookings,
  p_recipient_id uuid,
  p_actor_id uuid,
  p_event_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $enqueue_booking_notification$
begin
  insert into public.notification_outbox (
    recipient_id,
    actor_id,
    booking_id,
    event_type,
    payload
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_booking.id,
    p_event_type,
    jsonb_build_object(
      'bookingId', p_booking.id,
      'spotId', p_booking.space_id,
      'status', p_booking.status,
      'startAt', p_booking.start_at,
      'endAt', p_booking.end_at
    )
  );
end;
$enqueue_booking_notification$;

create or replace function public.local_minute_of_day(p_value timestamptz)
returns integer
language sql
immutable
as $local_minute_of_day$
  select extract(hour from p_value at time zone 'Asia/Kolkata')::integer * 60
    + extract(minute from p_value at time zone 'Asia/Kolkata')::integer;
$local_minute_of_day$;

create or replace function public.range_contains_weekend(
  p_start_at timestamptz,
  p_end_at timestamptz
)
returns boolean
language sql
stable
as $range_contains_weekend$
  select exists (
    select 1
    from generate_series(
      (p_start_at at time zone 'Asia/Kolkata')::date,
      (p_end_at at time zone 'Asia/Kolkata')::date,
      interval '1 day'
    ) day_value
    where extract(isodow from day_value)::integer in (6, 7)
  );
$range_contains_weekend$;

create or replace function public.create_booking_request(
  p_space_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_vehicle_kind text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $create_booking_request$
declare
  v_user_id uuid := auth.uid();
  v_space public.parking_spaces;
  v_host_profile public.profiles;
  v_existing public.bookings;
  v_booking public.bookings;
  v_request_hash text;
  v_duration_hours integer;
  v_platform_rate numeric;
  v_subtotal integer;
  v_platform_fee integer;
  v_taxes integer;
  v_total integer;
  v_status text;
  v_expires_at timestamptz;
  v_candidate_slot integer;
  v_slot integer;
  v_start_date date := (p_start_at at time zone 'Asia/Kolkata')::date;
  v_end_date date := (p_end_at at time zone 'Asia/Kolkata')::date;
  v_start_minute integer := public.local_minute_of_day(p_start_at);
  v_end_minute integer := public.local_minute_of_day(p_end_at);
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_vehicle_kind not in ('bike', 'car') then
    raise exception 'Invalid vehicle kind' using errcode = '23514';
  end if;

  if p_end_at <= p_start_at then
    raise exception 'Booking end time must be after start time' using errcode = '23514';
  end if;

  if p_start_at < now() - interval '2 minutes' then
    raise exception 'Booking start time is in the past' using errcode = '23514';
  end if;

  if p_end_at > p_start_at + interval '24 hours' then
    raise exception 'Booking duration is too long' using errcode = '23514';
  end if;

  v_request_hash := public.booking_request_hash(
    p_space_id,
    p_start_at,
    p_end_at,
    p_vehicle_kind
  );

  select *
  into v_existing
  from public.bookings
  where renter_id = v_user_id
    and idempotency_key = p_idempotency_key
  limit 1;

  if found then
    if v_existing.request_hash <> v_request_hash then
      raise exception 'Idempotency key reused for a different booking request'
        using errcode = '23505';
    end if;

    perform public.insert_booking_event(
      v_existing,
      v_user_id,
      'idempotent_replay',
      v_existing.status,
      v_existing.status,
      jsonb_build_object('requestHash', v_request_hash)
    );

    return public.booking_to_json(v_existing);
  end if;

  select *
  into v_space
  from public.parking_spaces
  where id = p_space_id
    and status = 'active'
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Parking spot was not found' using errcode = 'P0002';
  end if;

  if v_space.host_id = v_user_id then
    raise exception 'Hosts cannot book their own listing' using errcode = '42501';
  end if;

  select *
  into v_host_profile
  from public.profiles
  where id = v_space.host_id
  for share;

  if not found then
    raise exception 'Host profile was not found' using errcode = 'P0002';
  end if;

  update public.bookings
  set
    status = 'expired',
    version = version + 1,
    expires_at = null
  where space_id = p_space_id
    and status = 'pending'
    and expires_at <= now();

  if coalesce(v_space.hourly_price, 0) <= 0 then
    raise exception 'Parking spot pricing is unavailable' using errcode = '23514';
  end if;

  if v_start_date < coalesce(v_space.available_from_date, current_date)
    or v_end_date > coalesce(v_space.available_to_date, current_date + 29)
    or v_start_date <> v_end_date then
    raise exception 'Booking date is outside the available window' using errcode = '23514';
  end if;

  if coalesce(v_space.skip_weekends, false)
    and public.range_contains_weekend(p_start_at, p_end_at) then
    raise exception 'This parking spot is not available on weekends' using errcode = '23514';
  end if;

  if v_start_minute < coalesce(v_space.daily_start_minute, 8 * 60)
    or v_end_minute > coalesce(v_space.daily_end_minute, 20 * 60)
    or v_end_minute <= v_start_minute then
    raise exception 'Booking time is outside the daily availability window' using errcode = '23514';
  end if;

  v_duration_hours := greatest(
    1,
    least(24, ceiling(extract(epoch from (p_end_at - p_start_at)) / 3600.0)::integer)
  );
  v_platform_rate := case when p_vehicle_kind = 'bike' then 0.10 else 0.15 end;
  v_subtotal := coalesce(v_space.hourly_price, 0) * v_duration_hours;
  v_platform_fee := round(v_subtotal * v_platform_rate)::integer;
  v_taxes := round(v_platform_fee * 0.18)::integer;
  v_total := v_subtotal + v_platform_fee + v_taxes;
  v_status := case
    when coalesce(v_host_profile.booking_approval_mode, 'manual') = 'auto'
      then 'approved'
    else 'pending'
  end;
  v_expires_at := case when v_status = 'pending' then now() + interval '24 hours' else null end;

  for v_candidate_slot in 1..greatest(coalesce(v_space.slots_count, 1), 1) loop
    if not exists (
      select 1
      from public.bookings b
      where b.space_id = p_space_id
        and b.slot_number = v_candidate_slot
        and b.status in ('pending', 'approved')
        and tstzrange(b.start_at, b.end_at, '[)')
          && tstzrange(p_start_at, p_end_at, '[)')
    ) then
      v_slot := v_candidate_slot;
      exit;
    end if;
  end loop;

  if v_slot is null or v_slot > greatest(coalesce(v_space.slots_count, 1), 1) then
    raise exception 'No available slot for this booking window'
      using errcode = '23P01';
  end if;

  insert into public.bookings (
    space_id,
    host_id,
    renter_id,
    slot_number,
    status,
    vehicle_kind,
    start_at,
    end_at,
    expires_at,
    subtotal,
    platform_fee,
    taxes,
    total,
    currency,
    idempotency_key,
    request_hash
  )
  values (
    p_space_id,
    v_space.host_id,
    v_user_id,
    v_slot,
    v_status,
    p_vehicle_kind,
    p_start_at,
    p_end_at,
    v_expires_at,
    v_subtotal,
    v_platform_fee,
    v_taxes,
    v_total,
    'INR',
    p_idempotency_key,
    v_request_hash
  )
  returning *
  into v_booking;

  perform public.insert_booking_event(
    v_booking,
    v_user_id,
    'created',
    null,
    v_booking.status,
    jsonb_build_object('requestHash', v_request_hash)
  );

  if v_booking.status = 'pending' then
    perform public.enqueue_booking_notification(
      v_booking,
      v_booking.host_id,
      v_user_id,
      'host_booking_requested'
    );
  else
    perform public.enqueue_booking_notification(
      v_booking,
      v_booking.renter_id,
      v_booking.host_id,
      'booking_auto_approved'
    );
  end if;

  return public.booking_to_json(v_booking);
exception
  when exclusion_violation then
    raise exception 'No available slot for this booking window'
      using errcode = '23P01';
end;
$create_booking_request$;

create or replace function public.approve_booking(
  p_booking_id uuid,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $approve_booking$
declare
  v_user_id uuid := auth.uid();
  v_booking public.bookings;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
  into v_booking
  from public.bookings
  where id = p_booking_id
  for update;

  if not found then
    raise exception 'Booking was not found' using errcode = 'P0002';
  end if;

  if v_booking.host_id <> v_user_id then
    raise exception 'Only the host can approve this booking' using errcode = '42501';
  end if;

  if v_booking.version <> p_expected_version then
    raise exception 'Stale booking version' using errcode = '40001';
  end if;

  if v_booking.status <> 'pending' then
    raise exception 'Only pending bookings can be approved' using errcode = '23514';
  end if;

  if v_booking.expires_at <= now() then
    update public.bookings
    set status = 'expired', expires_at = null, version = version + 1
    where id = p_booking_id
    returning *
    into v_booking;
    perform public.insert_booking_event(v_booking, v_user_id, 'expired', 'pending', 'expired');
    perform public.enqueue_booking_notification(
      v_booking,
      v_booking.renter_id,
      v_user_id,
      'booking_expired'
    );
    raise exception 'Booking request has expired' using errcode = '23514';
  end if;

  update public.bookings
  set
    status = 'approved',
    expires_at = null,
    version = version + 1
  where id = p_booking_id
  returning *
  into v_booking;

  perform public.insert_booking_event(v_booking, v_user_id, 'approved', 'pending', 'approved');
  perform public.enqueue_booking_notification(
    v_booking,
    v_booking.renter_id,
    v_user_id,
    'booking_approved'
  );

  return public.booking_to_json(v_booking);
end;
$approve_booking$;

create or replace function public.reject_booking(
  p_booking_id uuid,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $reject_booking$
declare
  v_user_id uuid := auth.uid();
  v_booking public.bookings;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
  into v_booking
  from public.bookings
  where id = p_booking_id
  for update;

  if not found then
    raise exception 'Booking was not found' using errcode = 'P0002';
  end if;

  if v_booking.host_id <> v_user_id then
    raise exception 'Only the host can reject this booking' using errcode = '42501';
  end if;

  if v_booking.version <> p_expected_version then
    raise exception 'Stale booking version' using errcode = '40001';
  end if;

  if v_booking.status <> 'pending' then
    raise exception 'Only pending bookings can be rejected' using errcode = '23514';
  end if;

  update public.bookings
  set
    status = 'rejected',
    expires_at = null,
    version = version + 1
  where id = p_booking_id
  returning *
  into v_booking;

  perform public.insert_booking_event(v_booking, v_user_id, 'rejected', 'pending', 'rejected');
  perform public.enqueue_booking_notification(
    v_booking,
    v_booking.renter_id,
    v_user_id,
    'booking_rejected'
  );

  return public.booking_to_json(v_booking);
end;
$reject_booking$;

create or replace function public.expire_pending_bookings(p_batch_size integer default 500)
returns jsonb
language plpgsql
security definer
set search_path = public
as $expire_pending_bookings$
declare
  v_started_at timestamptz := clock_timestamp();
  v_batch_size integer := least(greatest(coalesce(p_batch_size, 500), 1), 5000);
  v_expired_count integer := 0;
  v_duration_ms integer;
  v_error text;
begin
  with candidates as (
    select id
    from public.bookings
    where status = 'pending'
      and expires_at <= now()
    order by expires_at asc, id asc
    limit v_batch_size
    for update skip locked
  ),
  updated as (
    update public.bookings b
    set
      status = 'expired',
      expires_at = null,
      version = version + 1
    from candidates c
    where b.id = c.id
    returning b.*
  ),
  inserted_events as (
    insert into public.booking_events (
      booking_id,
      actor_id,
      event_type,
      previous_status,
      new_status,
      metadata
    )
    select
      id,
      null,
      'expired',
      'pending',
      'expired',
      jsonb_build_object('source', 'expiry_job')
    from updated
    returning 1
  ),
  inserted_notifications as (
    insert into public.notification_outbox (
      recipient_id,
      actor_id,
      booking_id,
      event_type,
      payload
    )
    select
      renter_id,
      null,
      id,
      'booking_expired',
      jsonb_build_object(
        'bookingId', id,
        'spotId', space_id,
        'status', status,
        'startAt', start_at,
        'endAt', end_at
      )
    from updated
    returning 1
  )
  select count(*)
  into v_expired_count
  from updated;

  v_duration_ms := greatest(
    0,
    (extract(epoch from (clock_timestamp() - v_started_at)) * 1000)::integer
  );

  insert into public.booking_expiry_job_runs (
    ok,
    expired_count,
    batch_size,
    expiry_batch_saturated,
    duration_ms
  )
  values (
    true,
    v_expired_count,
    v_batch_size,
    v_expired_count = v_batch_size,
    v_duration_ms
  );

  delete from public.booking_expiry_job_runs r
  where r.created_at < now() - interval '7 days'
    and r.id not in (
      select id
      from public.booking_expiry_job_runs
      order by created_at desc
      limit 10000
    );

  return jsonb_build_object(
    'ok', true,
    'expiredCount', v_expired_count,
    'batchSize', v_batch_size,
    'expiryBatchSaturated', v_expired_count = v_batch_size,
    'durationMs', v_duration_ms
  );
exception
  when others then
    v_error := sqlerrm;
    v_duration_ms := greatest(
      0,
      (extract(epoch from (clock_timestamp() - v_started_at)) * 1000)::integer
    );
    insert into public.booking_expiry_job_runs (
      ok,
      expired_count,
      batch_size,
      expiry_batch_saturated,
      duration_ms,
      error_message
    )
    values (
      false,
      0,
      v_batch_size,
      false,
      v_duration_ms,
      left(v_error, 500)
    );
    return jsonb_build_object(
      'ok', false,
      'expiredCount', 0,
      'batchSize', v_batch_size,
      'expiryBatchSaturated', false,
      'durationMs', v_duration_ms,
      'error', v_error
    );
end;
$expire_pending_bookings$;

create or replace function public.list_host_bookings()
returns setof jsonb
language sql
security definer
set search_path = public
as $list_host_bookings$
  select public.booking_to_json(b)
  from public.bookings b
  where b.host_id = auth.uid()
  order by
    case when b.status = 'pending' then 0 else 1 end,
    b.start_at asc,
    b.updated_at desc
  limit 100;
$list_host_bookings$;

create or replace function public.list_renter_bookings()
returns setof jsonb
language sql
security definer
set search_path = public
as $list_renter_bookings$
  select public.booking_to_json(b)
  from public.bookings b
  where b.renter_id = auth.uid()
  order by b.updated_at desc
  limit 100;
$list_renter_bookings$;

revoke all on function public.create_booking_request(uuid, timestamptz, timestamptz, text, uuid) from public;
revoke all on function public.approve_booking(uuid, integer) from public;
revoke all on function public.reject_booking(uuid, integer) from public;
revoke all on function public.expire_pending_bookings(integer) from public;
revoke all on function public.list_host_bookings() from public;
revoke all on function public.list_renter_bookings() from public;

grant execute on function public.create_booking_request(uuid, timestamptz, timestamptz, text, uuid) to authenticated;
grant execute on function public.approve_booking(uuid, integer) to authenticated;
grant execute on function public.reject_booking(uuid, integer) to authenticated;
grant execute on function public.list_host_bookings() to authenticated;
grant execute on function public.list_renter_bookings() to authenticated;

create or replace function public.sync_host_profile_listing_revisions()
returns trigger
language plpgsql
security definer
set search_path = public
as $sync_host_profile_listing_revisions$
declare
  v_space record;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new.full_name is not distinct from old.full_name
    and new.avatar_url is not distinct from old.avatar_url
    and new.phone is not distinct from old.phone
    and new.show_phone_number is not distinct from old.show_phone_number then
    return new;
  end if;

  for v_space in
    select id
    from public.parking_spaces
    where host_id = new.id
      and status = 'active'
      and deleted_at is null
  loop
    perform public.touch_parking_listing_revision(v_space.id, 'host_profile');
  end loop;

  return new;
end;
$sync_host_profile_listing_revisions$;

drop trigger if exists profiles_listing_revision_sync on public.profiles;
create trigger profiles_listing_revision_sync
after update of full_name, avatar_url, phone, show_phone_number on public.profiles
for each row
execute function public.sync_host_profile_listing_revisions();

create or replace function public.get_public_parking_spot(p_space_id uuid)
returns jsonb
language sql
security definer
set search_path = public
set statement_timeout = '5s'
as $get_public_parking_spot$
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
      and ps.deleted_at is null
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
    'hostName', public.public_host_profile_payload(p)->>'hostName',
    'hostAvatarUrl', public.public_host_profile_payload(p)->>'hostAvatarUrl',
    'hostPhone', public.public_host_profile_payload(p)->>'hostPhone',
    'hostRole', public.public_host_profile_payload(p)->>'hostRole',
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
$get_public_parking_spot$;

revoke all on function public.get_public_parking_spot(uuid) from public;
grant execute on function public.get_public_parking_spot(uuid) to anon, authenticated;

comment on table public.bookings is
  'Operational booking reservations. Payment hold, escrow, and capture are intentionally deferred to a future payment-provider rollout.';

comment on table public.notification_outbox is
  'Durable notification queue for booking lifecycle events. Payloads must not include phone numbers or sensitive profile fields.';

comment on table public.booking_expiry_job_runs is
  'Health and saturation telemetry for the scheduled pending-booking expiry job. The expiry job retains recent rows and prunes older history.';

notify pgrst, 'reload schema';
