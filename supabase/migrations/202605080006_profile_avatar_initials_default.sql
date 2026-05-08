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
  v_phone text := nullif(trim(coalesce(v_jwt ->> 'phone', '')), '');
begin
  if v_user_id is null then
    raise exception 'Authentication is required' using errcode = '28000';
  end if;

  insert into public.profiles (id, full_name, phone)
  values (v_user_id, v_full_name, v_phone)
  on conflict (id) do update
    set
      full_name = coalesce(public.profiles.full_name, excluded.full_name),
      phone = coalesce(public.profiles.phone, excluded.phone)
  returning *
  into v_profile;

  return v_profile;
end;
$$;

update public.profiles
set avatar_url = null
where avatar_public_id is null
  and avatar_url is not null
  and avatar_url ~* '(googleusercontent\.com|ggpht\.com|googleapis\.com)';

comment on function public.ensure_user_profile(text) is
  'Trusted self-healing profile sync for authenticated users. Fills missing safe profile fields only; provider avatars stay opt-in via explicit user upload.';
