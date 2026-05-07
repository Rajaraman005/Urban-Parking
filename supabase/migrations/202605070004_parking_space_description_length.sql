create or replace function public.enforce_parking_space_description_length()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.access_instructions is null then
    return new;
  end if;

  new.access_instructions = btrim(new.access_instructions);

  if char_length(new.access_instructions) < 50
    or char_length(new.access_instructions) > 200 then
    raise exception 'Parking space description must be between 50 and 200 characters.'
      using
        errcode = '23514',
        constraint = 'parking_spaces_description_length_check';
  end if;

  return new;
end;
$$;

drop trigger if exists parking_spaces_description_length
on public.parking_spaces;

create trigger parking_spaces_description_length
before insert or update of access_instructions
on public.parking_spaces
for each row
execute function public.enforce_parking_space_description_length();

comment on function public.enforce_parking_space_description_length() is
  'Trims and enforces the 50-200 character renter-facing parking listing description limit.';

notify pgrst, 'reload schema';
