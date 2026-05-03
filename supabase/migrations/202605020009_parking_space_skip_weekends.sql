alter table public.parking_spaces
  add column if not exists skip_weekends boolean not null default false;

grant update (skip_weekends) on table public.parking_spaces to authenticated;

comment on column public.parking_spaces.skip_weekends is
  'When true, Saturday and Sunday are excluded from the booking window shown to renters.';
