alter table public.parking_spaces
add column if not exists access_instructions text;

grant update (
  access_instructions
) on table public.parking_spaces to authenticated;

comment on column public.parking_spaces.access_instructions is
  'Optional host-written directions that help renters identify the exact parking entry or bay.';
