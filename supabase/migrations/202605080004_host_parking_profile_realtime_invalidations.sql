create or replace function public.touch_profile_on_host_parking_draft_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft_id uuid;
  v_host_id uuid;
begin
  v_draft_id := coalesce(new.id, old.id);
  v_host_id := coalesce(new.host_id, old.host_id);

  if v_draft_id is null or v_host_id is null then
    return coalesce(new, old);
  end if;

  update public.profiles
  set version = version + 1
  where id = v_host_id
    and (
      host_parking_draft_id = v_draft_id
      or setup_draft_id = v_draft_id
    );

  return coalesce(new, old);
end;
$$;

drop trigger if exists parking_listing_drafts_profile_realtime_touch
on public.parking_listing_drafts;

create trigger parking_listing_drafts_profile_realtime_touch
after insert or update or delete
on public.parking_listing_drafts
for each row
execute function public.touch_profile_on_host_parking_draft_change();

comment on function public.touch_profile_on_host_parking_draft_change() is
  'Bumps the owning profile version when a linked host parking draft changes, letting profile realtime drive Flutter cache invalidation without exposing draft tables directly.';

notify pgrst, 'reload schema';
