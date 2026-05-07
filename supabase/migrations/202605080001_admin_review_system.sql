create extension if not exists citext;

create table if not exists public.admin_users (
  id uuid primary key default gen_random_uuid(),
  username citext not null unique,
  display_name text not null,
  password_hash text not null,
  role text not null default 'reviewer' check (role in ('owner', 'admin', 'reviewer')),
  is_active boolean not null default true,
  last_login_at timestamptz,
  password_changed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(btrim(username::text)) between 2 and 120),
  check (char_length(btrim(display_name)) between 2 and 120),
  check (char_length(password_hash) between 32 and 512)
);

create table if not exists public.admin_sessions (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references public.admin_users(id) on delete cascade,
  session_token_hash text not null unique,
  ip_hash text not null,
  user_agent_hash text not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  check (char_length(session_token_hash) = 64),
  check (char_length(ip_hash) = 64),
  check (char_length(user_agent_hash) = 64)
);

create table if not exists public.admin_login_attempts (
  id uuid primary key default gen_random_uuid(),
  username citext not null,
  ip_hash text not null,
  success boolean not null default false,
  failure_reason text,
  created_at timestamptz not null default now(),
  check (char_length(ip_hash) = 64),
  check (failure_reason is null or char_length(failure_reason) <= 80)
);

alter table public.parking_spaces
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by_admin_id uuid references public.admin_users(id) on delete set null,
  add column if not exists rejection_reason text,
  add column if not exists suspension_reason text,
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by_admin_id uuid references public.admin_users(id) on delete set null,
  add column if not exists deleted_by_host_id uuid references auth.users(id) on delete set null;

alter table public.parking_spaces
  drop constraint if exists parking_spaces_status_check;

alter table public.parking_spaces
  add constraint parking_spaces_status_check
  check (status in ('draft', 'pending_review', 'active', 'rejected', 'suspended'));

do $admin_review_constraints$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'parking_spaces_rejection_reason_length_check'
  ) then
    alter table public.parking_spaces
      add constraint parking_spaces_rejection_reason_length_check
      check (rejection_reason is null or char_length(btrim(rejection_reason)) between 4 and 1000);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'parking_spaces_suspension_reason_length_check'
  ) then
    alter table public.parking_spaces
      add constraint parking_spaces_suspension_reason_length_check
      check (suspension_reason is null or char_length(btrim(suspension_reason)) between 4 and 1000);
  end if;
end $admin_review_constraints$;

create table if not exists public.parking_listing_review_events (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.parking_spaces(id) on delete cascade,
  admin_user_id uuid references public.admin_users(id) on delete set null,
  event_type text not null check (
    event_type in ('approved', 'rejected', 'suspended', 'internal_note', 'soft_deleted')
  ),
  previous_status text check (
    previous_status is null
    or previous_status in ('draft', 'pending_review', 'active', 'rejected', 'suspended')
  ),
  new_status text check (
    new_status is null
    or new_status in ('draft', 'pending_review', 'active', 'rejected', 'suspended')
  ),
  reason text,
  internal_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (reason is null or char_length(btrim(reason)) between 4 and 1000),
  check (internal_note is null or char_length(btrim(internal_note)) between 2 and 2000)
);

drop trigger if exists admin_users_set_updated_at on public.admin_users;
create trigger admin_users_set_updated_at
before update on public.admin_users
for each row
execute function public.set_updated_at();

create index if not exists admin_users_active_username_idx
on public.admin_users (username)
where is_active = true;

create index if not exists admin_sessions_user_active_idx
on public.admin_sessions (admin_user_id, expires_at desc)
where revoked_at is null;

create index if not exists admin_login_attempts_username_recent_idx
on public.admin_login_attempts (username, created_at desc)
where success = false;

create index if not exists admin_login_attempts_ip_recent_idx
on public.admin_login_attempts (ip_hash, created_at desc)
where success = false;

create index if not exists parking_spaces_review_queue_idx
on public.parking_spaces (status, submitted_at desc, updated_at desc)
where deleted_at is null;

create index if not exists parking_spaces_host_visible_status_idx
on public.parking_spaces (host_id, status, updated_at desc)
where deleted_at is null;

create index if not exists parking_spaces_active_location_not_deleted_idx
on public.parking_spaces (status, latitude, longitude)
where status = 'active' and deleted_at is null and latitude is not null and longitude is not null;

create index if not exists parking_listing_review_events_listing_created_idx
on public.parking_listing_review_events (listing_id, created_at desc);

create index if not exists parking_listing_review_events_admin_created_idx
on public.parking_listing_review_events (admin_user_id, created_at desc);

create or replace function public.prevent_review_event_mutation()
returns trigger
language plpgsql
as $prevent_review_event_mutation$
begin
  raise exception 'Review events are immutable' using errcode = '42501';
end;
$prevent_review_event_mutation$;

drop trigger if exists parking_listing_review_events_immutable_update
on public.parking_listing_review_events;
create trigger parking_listing_review_events_immutable_update
before update or delete on public.parking_listing_review_events
for each row
execute function public.prevent_review_event_mutation();

alter table public.admin_users enable row level security;
alter table public.admin_users force row level security;
alter table public.admin_sessions enable row level security;
alter table public.admin_sessions force row level security;
alter table public.admin_login_attempts enable row level security;
alter table public.admin_login_attempts force row level security;
alter table public.parking_listing_review_events enable row level security;
alter table public.parking_listing_review_events force row level security;

drop policy if exists "admin_users_no_client_access" on public.admin_users;
create policy "admin_users_no_client_access"
on public.admin_users
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "admin_sessions_no_client_access" on public.admin_sessions;
create policy "admin_sessions_no_client_access"
on public.admin_sessions
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "admin_login_attempts_no_client_access" on public.admin_login_attempts;
create policy "admin_login_attempts_no_client_access"
on public.admin_login_attempts
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "parking_listing_review_events_no_client_access" on public.parking_listing_review_events;
create policy "parking_listing_review_events_no_client_access"
on public.parking_listing_review_events
for all
to anon, authenticated
using (false)
with check (false);

revoke all on table public.admin_users from anon, authenticated;
revoke all on table public.admin_sessions from anon, authenticated;
revoke all on table public.admin_login_attempts from anon, authenticated;
revoke all on table public.parking_listing_review_events from anon, authenticated;

create or replace function public.admin_transition_parking_listing(
  p_listing_id uuid,
  p_admin_id uuid,
  p_action text,
  p_reason text default null,
  p_internal_note text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $admin_transition_parking_listing$
declare
  v_admin public.admin_users;
  v_space public.parking_spaces;
  v_previous_status text;
  v_next_status text;
  v_event_type text;
  v_reason text := nullif(btrim(p_reason), '');
  v_internal_note text := nullif(btrim(p_internal_note), '');
begin
  select *
  into v_admin
  from public.admin_users
  where id = p_admin_id
    and is_active = true;

  if not found then
    raise exception 'Admin account is not active' using errcode = '42501';
  end if;

  select *
  into v_space
  from public.parking_spaces
  where id = p_listing_id
  for update;

  if not found or v_space.deleted_at is not null then
    raise exception 'Listing was not found' using errcode = 'P0002';
  end if;

  v_previous_status := v_space.status;
  v_next_status := v_space.status;

  if p_action = 'approve' then
    if v_space.status not in ('pending_review', 'rejected', 'suspended') then
      raise exception 'Listing cannot be approved from current status' using errcode = '23514';
    end if;
    v_event_type := 'approved';
    v_next_status := 'active';
    update public.parking_spaces
    set
      status = v_next_status,
      reviewed_at = now(),
      reviewed_by_admin_id = p_admin_id,
      rejection_reason = null,
      suspension_reason = null,
      version = version + 1,
      updated_at = now()
    where id = p_listing_id
    returning *
    into v_space;
  elsif p_action = 'reject' then
    if v_space.status <> 'pending_review' then
      raise exception 'Only pending listings can be rejected' using errcode = '23514';
    end if;
    if v_reason is null or char_length(v_reason) < 4 then
      raise exception 'Rejection reason is required' using errcode = '23514';
    end if;
    v_event_type := 'rejected';
    v_next_status := 'rejected';
    update public.parking_spaces
    set
      status = v_next_status,
      reviewed_at = now(),
      reviewed_by_admin_id = p_admin_id,
      rejection_reason = v_reason,
      suspension_reason = null,
      version = version + 1,
      updated_at = now()
    where id = p_listing_id
    returning *
    into v_space;
  elsif p_action = 'suspend' then
    if v_space.status <> 'active' then
      raise exception 'Only active listings can be suspended' using errcode = '23514';
    end if;
    if v_reason is null or char_length(v_reason) < 4 then
      raise exception 'Suspension reason is required' using errcode = '23514';
    end if;
    v_event_type := 'suspended';
    v_next_status := 'suspended';
    update public.parking_spaces
    set
      status = v_next_status,
      reviewed_at = now(),
      reviewed_by_admin_id = p_admin_id,
      suspension_reason = v_reason,
      version = version + 1,
      updated_at = now()
    where id = p_listing_id
    returning *
    into v_space;
  elsif p_action = 'note' then
    if v_internal_note is null or char_length(v_internal_note) < 2 then
      raise exception 'Internal note is required' using errcode = '23514';
    end if;
    v_event_type := 'internal_note';
  elsif p_action = 'soft_delete' then
    if v_internal_note is null or char_length(v_internal_note) < 2 then
      raise exception 'Internal note is required' using errcode = '23514';
    end if;
    v_event_type := 'soft_deleted';
    update public.parking_spaces
    set
      deleted_at = now(),
      deleted_by_admin_id = p_admin_id,
      version = version + 1,
      updated_at = now()
    where id = p_listing_id
    returning *
    into v_space;
  else
    raise exception 'Unsupported review action' using errcode = '23514';
  end if;

  insert into public.parking_listing_review_events (
    listing_id,
    admin_user_id,
    event_type,
    previous_status,
    new_status,
    reason,
    internal_note,
    metadata
  )
  values (
    p_listing_id,
    p_admin_id,
    v_event_type,
    v_previous_status,
    v_next_status,
    v_reason,
    v_internal_note,
    coalesce(p_metadata, '{}'::jsonb)
  );

  return jsonb_build_object(
    'ok', true,
    'listingId', p_listing_id,
    'previousStatus', v_previous_status,
    'status', v_next_status,
    'eventType', v_event_type
  );
end;
$admin_transition_parking_listing$;

revoke all on function public.admin_transition_parking_listing(
  uuid,
  uuid,
  text,
  text,
  text,
  jsonb
) from public;
grant execute on function public.admin_transition_parking_listing(
  uuid,
  uuid,
  text,
  text,
  text,
  jsonb
) to service_role;

create or replace function public.delete_owned_parking_listing(
  p_listing_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $delete_owned_parking_listing$
declare
  v_draft public.parking_listing_drafts;
  v_space public.parking_spaces;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select *
  into v_draft
  from public.parking_listing_drafts
  where id = p_listing_id
    and host_id = auth.uid()
    and status = 'draft'
  for update;

  if found then
    update public.parking_listing_draft_photos
    set
      upload_status = 'deleted',
      updated_at = now()
    where draft_id = p_listing_id
      and host_id = auth.uid()
      and upload_status <> 'deleted';

    update public.parking_listing_drafts
    set
      status = 'discarded',
      version = version + 1,
      last_autosaved_at = now(),
      expires_at = least(expires_at, now() + interval '30 days'),
      updated_at = now()
    where id = p_listing_id
      and host_id = auth.uid()
      and status = 'draft'
    returning *
    into v_draft;

    update public.profiles
    set
      host_parking_draft_id = case
        when host_parking_draft_id = p_listing_id then null
        else host_parking_draft_id
      end,
      setup_draft_id = case
        when setup_draft_id = p_listing_id then null
        else setup_draft_id
      end,
      setup_step = case
        when (
          host_parking_draft_id = p_listing_id
          or setup_draft_id = p_listing_id
        )
        and setup_step in (
          'host_basics',
          'host_pricing',
          'host_photos',
          'host_review'
        )
          then 'profile'
        else setup_step
      end,
      version = version + 1
    where id = auth.uid()
      and (
        host_parking_draft_id = p_listing_id
        or setup_draft_id = p_listing_id
      );

    return jsonb_build_object(
      'ok', true,
      'deleted', true,
      'listingId', p_listing_id,
      'storageKind', 'host_parking',
      'status', 'discarded'
    );
  end if;

  update public.parking_spaces
  set
    deleted_at = now(),
    deleted_by_host_id = auth.uid(),
    version = version + 1,
    updated_at = now()
  where id = p_listing_id
    and host_id = auth.uid()
    and status in ('draft', 'pending_review', 'active', 'rejected', 'suspended')
    and deleted_at is null
  returning *
  into v_space;

  if found then
    update public.profiles
    set
      setup_draft_id = case
        when setup_draft_id = p_listing_id then null
        else setup_draft_id
      end,
      setup_step = case
        when setup_draft_id = p_listing_id
        and setup_step in (
          'host_basics',
          'host_pricing',
          'host_photos',
          'host_review'
        )
          then 'profile'
        else setup_step
      end,
      version = version + 1
    where id = auth.uid()
      and setup_draft_id = p_listing_id;

    return jsonb_build_object(
      'ok', true,
      'deleted', true,
      'listingId', p_listing_id,
      'storageKind', 'parking_space',
      'status', v_space.status
    );
  end if;

  raise exception 'Listing not found' using errcode = 'P0002';
end;
$delete_owned_parking_listing$;

revoke all on function public.delete_owned_parking_listing(uuid) from public;
grant execute on function public.delete_owned_parking_listing(uuid) to authenticated;

drop function if exists public.search_public_parking_spots(
  double precision,
  double precision,
  double precision,
  integer,
  integer
);

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
  skip_weekends boolean,
  image_urls text[]
)
language sql
security definer
set search_path = public
as $search_public_parking_spots$
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
    coalesce(ps.skip_weekends, false) as skip_weekends,
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
    and ps.deleted_at is null
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
$search_public_parking_spots$;

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
$get_public_parking_spot$;

revoke all on function public.get_public_parking_spot(uuid) from public;
grant execute on function public.get_public_parking_spot(uuid) to anon, authenticated;

create or replace function public.get_owned_parking_spaces()
returns setof jsonb
language sql
security definer
set search_path = public
as $get_owned_parking_spaces$
  select public.get_public_parking_spot(ps.id)
  from public.parking_spaces ps
  where ps.host_id = auth.uid()
    and ps.status = 'active'
    and ps.deleted_at is null
  order by ps.updated_at desc;
$get_owned_parking_spaces$;

revoke all on function public.get_owned_parking_spaces() from public;
grant execute on function public.get_owned_parking_spaces() to authenticated;

comment on table public.admin_users is
  'Dedicated staff admin identities for the Next.js admin console. Password hashes only; never store plaintext credentials.';

comment on table public.admin_sessions is
  'Opaque admin web sessions. Only SHA-256 token hashes are stored.';

comment on table public.admin_login_attempts is
  'Rate-limit ledger for admin login attempts keyed by normalized username and keyed IP hash.';

comment on table public.parking_listing_review_events is
  'Immutable admin review audit log for parking listing lifecycle decisions and internal notes.';

comment on function public.admin_transition_parking_listing(
  uuid,
  uuid,
  text,
  text,
  text,
  jsonb
) is
  'Atomic admin review transition function. Updates listing visibility state and appends an immutable review event.';

comment on function public.delete_owned_parking_listing(uuid) is
  'Soft-deletes user-owned listings from My parking spaces while preserving review and listing audit history.';

notify pgrst, 'reload schema';
