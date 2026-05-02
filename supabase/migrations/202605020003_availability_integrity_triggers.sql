create or replace function public.validate_parking_space_availability_rule()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.parking_spaces ps
    where ps.id = new.parking_space_id
      and ps.host_id = new.host_id
      and ps.status = 'draft'
  ) then
    raise exception 'Availability can only be changed for own draft listings' using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.parking_space_availability_rules existing_rule
    where existing_rule.parking_space_id = new.parking_space_id
      and existing_rule.weekday = new.weekday
      and existing_rule.id <> new.id
      and new.start_minute < existing_rule.end_minute
      and existing_rule.start_minute < new.end_minute
  ) then
    raise exception 'Availability rules cannot overlap' using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists parking_space_availability_rules_validate on public.parking_space_availability_rules;
create trigger parking_space_availability_rules_validate
before insert or update on public.parking_space_availability_rules
for each row
execute function public.validate_parking_space_availability_rule();

create or replace function public.validate_parking_space_availability_exception()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.parking_spaces ps
    where ps.id = new.parking_space_id
      and ps.host_id = new.host_id
      and ps.status = 'draft'
  ) then
    raise exception 'Availability can only be changed for own draft listings' using errcode = '42501';
  end if;

  if new.exception_date < (now() at time zone 'Asia/Kolkata')::date then
    raise exception 'Blocked dates cannot be in the past' using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists parking_space_availability_exceptions_validate on public.parking_space_availability_exceptions;
create trigger parking_space_availability_exceptions_validate
before insert or update on public.parking_space_availability_exceptions
for each row
execute function public.validate_parking_space_availability_exception();

revoke all on function public.validate_parking_space_availability_rule() from public;
revoke all on function public.validate_parking_space_availability_exception() from public;
