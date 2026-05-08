alter table public.profiles
add column if not exists vehicle_type text,
add column if not exists vehicle_registration text,
add column if not exists vehicle_make text,
add column if not exists vehicle_model text;

alter table public.profiles
drop constraint if exists profiles_setup_step_check;

alter table public.profiles
add constraint profiles_setup_step_check
check (
  setup_step in (
    'intent',
    'profile',
    'vehicle_details',
    'host_basics',
    'host_pricing',
    'host_photos',
    'host_review',
    'complete'
  )
);

alter table public.profiles
drop constraint if exists profiles_vehicle_type_check;

alter table public.profiles
add constraint profiles_vehicle_type_check
check (vehicle_type is null or vehicle_type in ('bike', 'car'));

alter table public.profiles
drop constraint if exists profiles_vehicle_registration_format_check;

alter table public.profiles
add constraint profiles_vehicle_registration_format_check
check (
  vehicle_registration is null
  or vehicle_registration ~ '^[A-Z]{2}[0-9]{2}[A-Z]{1,3}[0-9]{4}$'
  or vehicle_registration ~ '^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$'
);

grant update (
  vehicle_type,
  vehicle_registration,
  vehicle_make,
  vehicle_model,
  setup_step,
  onboarding_completed_at,
  version
) on table public.profiles to authenticated;

comment on column public.profiles.vehicle_type is
  'Primary renter vehicle type used for parking discovery and booking defaults.';
comment on column public.profiles.vehicle_registration is
  'Uppercase Indian vehicle registration number without spaces or separators.';
comment on column public.profiles.vehicle_make is
  'Optional renter vehicle manufacturer label.';
comment on column public.profiles.vehicle_model is
  'Optional renter vehicle model label.';
