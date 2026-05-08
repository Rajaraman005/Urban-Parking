alter function public.search_public_parking_spots(
  double precision,
  double precision,
  double precision,
  integer,
  integer
) set statement_timeout = '5s';

alter function public.get_public_parking_spot(uuid)
set statement_timeout = '5s';

create or replace function public.get_public_parking_quote_source(p_space_id uuid)
returns table (
  id uuid,
  hourly_price integer,
  skip_weekends boolean
)
language sql
security definer
set search_path = public
set statement_timeout = '5s'
as $$
  select
    ps.id,
    ps.hourly_price,
    coalesce(ps.skip_weekends, false) as skip_weekends
  from public.parking_spaces ps
  where ps.id = p_space_id
    and ps.status = 'active'
    and ps.deleted_at is null
  limit 1;
$$;

revoke all on function public.get_public_parking_quote_source(uuid) from public;
grant execute on function public.get_public_parking_quote_source(uuid) to anon, authenticated;

comment on function public.get_public_parking_quote_source(uuid) is
  'Returns bounded public pricing inputs for mobile booking quotes with a DB-side timeout guard.';
