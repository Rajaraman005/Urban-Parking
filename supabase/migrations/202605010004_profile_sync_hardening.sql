grant usage on schema public to anon, authenticated;

create or replace function public.ensure_user_profile(p_full_name text default null)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_jwt jsonb := auth.jwt();
  v_profile public.profiles;
  v_full_name text := nullif(trim(coalesce(p_full_name, v_jwt -> 'user_metadata' ->> 'full_name', '')), '');
  v_avatar_url text := nullif(trim(coalesce(v_jwt -> 'user_metadata' ->> 'avatar_url', '')), '');
  v_phone text := nullif(trim(coalesce(v_jwt ->> 'phone', '')), '');
begin
  if v_user_id is null then
    raise exception 'Authentication is required' using errcode = '28000';
  end if;

  insert into public.profiles (id, full_name, avatar_url, phone)
  values (v_user_id, v_full_name, v_avatar_url, v_phone)
  on conflict (id) do update
    set
      full_name = coalesce(public.profiles.full_name, excluded.full_name),
      avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
      phone = coalesce(public.profiles.phone, excluded.phone)
  returning *
  into v_profile;

  return v_profile;
end;
$$;

revoke all on function public.ensure_user_profile(text) from public;
grant execute on function public.ensure_user_profile(text) to authenticated;

grant select on table public.profiles to authenticated;
grant insert (id, full_name, avatar_url, phone) on table public.profiles to authenticated;
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

comment on function public.ensure_user_profile(text) is
  'Trusted self-healing profile sync for authenticated users. Fills missing safe profile fields only and never accepts role or authorization metadata from clients.';
