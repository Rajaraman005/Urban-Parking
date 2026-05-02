alter table public.profiles
add column if not exists intent text check (intent in ('park', 'host')),
add column if not exists setup_step text not null default 'intent' check (
  setup_step in ('intent', 'profile', 'host_basics', 'host_pricing', 'host_photos', 'host_review', 'complete')
),
add column if not exists setup_draft_id uuid,
add column if not exists onboarding_completed_at timestamptz,
add column if not exists version integer not null default 1 check (version > 0);

create table if not exists public.parking_spaces (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  title text,
  address text,
  landmark text,
  locality text,
  parking_type text check (parking_type in ('covered', 'open', 'garage', 'driveway', 'basement')),
  vehicle_fit text check (vehicle_fit in ('bike', 'car', 'both')),
  length_feet numeric(6, 2),
  width_feet numeric(6, 2),
  height_feet numeric(6, 2),
  slots_count integer not null default 1 check (slots_count between 1 and 50),
  hourly_price integer check (hourly_price between 1 and 10000),
  availability_summary text,
  status text not null default 'draft' check (status in ('draft', 'pending_review', 'active', 'rejected')),
  version integer not null default 1 check (version > 0),
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.parking_space_photos (
  id uuid primary key default gen_random_uuid(),
  parking_space_id uuid not null references public.parking_spaces(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  public_id text not null,
  secure_url text not null,
  width integer,
  height integer,
  sort_order integer not null default 0,
  upload_status text not null default 'linked' check (upload_status in ('pending', 'uploaded', 'linked', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (parking_space_id, public_id)
);

create index if not exists parking_spaces_host_status_idx
on public.parking_spaces (host_id, status, updated_at desc);

create index if not exists parking_spaces_draft_cleanup_idx
on public.parking_spaces (status, updated_at)
where status = 'draft';

create index if not exists parking_space_photos_space_order_idx
on public.parking_space_photos (parking_space_id, sort_order asc);

drop trigger if exists parking_spaces_set_updated_at on public.parking_spaces;
create trigger parking_spaces_set_updated_at
before update on public.parking_spaces
for each row
execute function public.set_updated_at();

drop trigger if exists parking_space_photos_set_updated_at on public.parking_space_photos;
create trigger parking_space_photos_set_updated_at
before update on public.parking_space_photos
for each row
execute function public.set_updated_at();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_setup_draft_id_fkey'
  ) then
    alter table public.profiles
    add constraint profiles_setup_draft_id_fkey
    foreign key (setup_draft_id)
    references public.parking_spaces(id)
    on delete set null;
  end if;
end $$;

alter table public.parking_spaces enable row level security;
alter table public.parking_spaces force row level security;
alter table public.parking_space_photos enable row level security;
alter table public.parking_space_photos force row level security;

drop policy if exists "parking_spaces_select_own" on public.parking_spaces;
create policy "parking_spaces_select_own"
on public.parking_spaces
for select
to authenticated
using ((select auth.uid()) = host_id);

drop policy if exists "parking_spaces_insert_own_draft" on public.parking_spaces;
create policy "parking_spaces_insert_own_draft"
on public.parking_spaces
for insert
to authenticated
with check ((select auth.uid()) = host_id and status = 'draft');

drop policy if exists "parking_spaces_update_own_draft" on public.parking_spaces;
create policy "parking_spaces_update_own_draft"
on public.parking_spaces
for update
to authenticated
using ((select auth.uid()) = host_id and status = 'draft')
with check ((select auth.uid()) = host_id and status = 'draft');

drop policy if exists "parking_space_photos_select_own" on public.parking_space_photos;
create policy "parking_space_photos_select_own"
on public.parking_space_photos
for select
to authenticated
using ((select auth.uid()) = host_id);

drop policy if exists "parking_space_photos_insert_own_draft" on public.parking_space_photos;
create policy "parking_space_photos_insert_own_draft"
on public.parking_space_photos
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

drop policy if exists "parking_space_photos_update_own_draft" on public.parking_space_photos;
create policy "parking_space_photos_update_own_draft"
on public.parking_space_photos
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

drop policy if exists "parking_space_photos_delete_own_draft" on public.parking_space_photos;
create policy "parking_space_photos_delete_own_draft"
on public.parking_space_photos
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

revoke all on table public.parking_spaces from anon;
revoke all on table public.parking_spaces from authenticated;
grant select, insert on table public.parking_spaces to authenticated;
grant update (
  title,
  address,
  landmark,
  locality,
  parking_type,
  vehicle_fit,
  length_feet,
  width_feet,
  height_feet,
  slots_count,
  hourly_price,
  availability_summary,
  version,
  updated_at
) on table public.parking_spaces to authenticated;

revoke all on table public.parking_space_photos from anon;
revoke all on table public.parking_space_photos from authenticated;
grant select, insert, delete on table public.parking_space_photos to authenticated;
grant update (secure_url, width, height, sort_order, upload_status, updated_at) on table public.parking_space_photos to authenticated;

grant update (
  full_name,
  avatar_url,
  phone,
  intent,
  setup_step,
  setup_draft_id,
  onboarding_completed_at,
  version
) on table public.profiles to authenticated;

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

  if v_space.address is null
    or v_space.locality is null
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

comment on table public.parking_spaces is
  'Host-owned parking space lifecycle records. Client can draft only; trusted function submits for review.';

comment on table public.parking_space_photos is
  'Cloudinary-backed parking photos linked only after signed upload succeeds.';
