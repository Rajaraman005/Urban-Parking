create table if not exists public.profile_vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_type text not null check (vehicle_type in ('bike', 'car')),
  vehicle_registration text not null check (
    vehicle_registration ~ '^[A-Z]{2}[0-9]{2}[A-Z]{1,3}[0-9]{4}$'
    or vehicle_registration ~ '^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$'
  ),
  vehicle_make text,
  vehicle_model text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, vehicle_registration)
);

create unique index if not exists profile_vehicles_one_primary_idx
on public.profile_vehicles (user_id)
where is_primary;

create index if not exists profile_vehicles_user_created_idx
on public.profile_vehicles (user_id, created_at);

drop trigger if exists profile_vehicles_set_updated_at on public.profile_vehicles;
create trigger profile_vehicles_set_updated_at
before update on public.profile_vehicles
for each row
execute function public.set_updated_at();

insert into public.profile_vehicles (
  user_id,
  vehicle_type,
  vehicle_registration,
  vehicle_make,
  vehicle_model,
  is_primary
)
select
  id,
  vehicle_type,
  vehicle_registration,
  nullif(btrim(vehicle_make), ''),
  nullif(btrim(vehicle_model), ''),
  true
from public.profiles
where vehicle_type in ('bike', 'car')
  and vehicle_registration is not null
  and btrim(vehicle_registration) <> ''
on conflict (user_id, vehicle_registration) do update
set
  vehicle_type = excluded.vehicle_type,
  vehicle_make = excluded.vehicle_make,
  vehicle_model = excluded.vehicle_model,
  is_primary = public.profile_vehicles.is_primary or excluded.is_primary,
  updated_at = now();

alter table public.profile_vehicles enable row level security;
alter table public.profile_vehicles force row level security;

drop policy if exists "profile_vehicles_select_own" on public.profile_vehicles;
create policy "profile_vehicles_select_own"
on public.profile_vehicles
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "profile_vehicles_insert_own" on public.profile_vehicles;
create policy "profile_vehicles_insert_own"
on public.profile_vehicles
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "profile_vehicles_update_own" on public.profile_vehicles;
create policy "profile_vehicles_update_own"
on public.profile_vehicles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "profile_vehicles_delete_own" on public.profile_vehicles;
create policy "profile_vehicles_delete_own"
on public.profile_vehicles
for delete
to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.profile_vehicles from anon;
revoke all on table public.profile_vehicles from authenticated;
grant select, insert, delete on table public.profile_vehicles to authenticated;
grant update (
  vehicle_type,
  vehicle_registration,
  vehicle_make,
  vehicle_model,
  is_primary,
  updated_at
) on table public.profile_vehicles to authenticated;

comment on table public.profile_vehicles is
  'Renter vehicles owned by a profile. profiles.vehicle_* remains a primary-vehicle compatibility copy.';
comment on column public.profile_vehicles.is_primary is
  'Marks the default vehicle copied into public.profiles.vehicle_* for legacy reads.';
