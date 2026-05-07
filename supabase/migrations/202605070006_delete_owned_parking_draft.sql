create or replace function public.delete_owned_parking_draft(
  p_draft_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.parking_listing_drafts;
  v_legacy_space public.parking_spaces;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select *
  into v_draft
  from public.parking_listing_drafts
  where id = p_draft_id
    and host_id = auth.uid()
    and status = 'draft'
  for update;

  if found then
    update public.parking_listing_draft_photos
    set
      upload_status = 'deleted',
      updated_at = now()
    where draft_id = p_draft_id
      and host_id = auth.uid()
      and upload_status <> 'deleted';

    update public.parking_listing_drafts
    set
      status = 'discarded',
      version = version + 1,
      last_autosaved_at = now(),
      expires_at = least(expires_at, now() + interval '30 days'),
      updated_at = now()
    where id = p_draft_id
      and host_id = auth.uid()
      and status = 'draft'
    returning *
    into v_draft;

    update public.profiles
    set
      host_parking_draft_id = case
        when host_parking_draft_id = p_draft_id then null
        else host_parking_draft_id
      end,
      setup_draft_id = case
        when setup_draft_id = p_draft_id then null
        else setup_draft_id
      end,
      setup_step = case
        when (
          host_parking_draft_id = p_draft_id
          or setup_draft_id = p_draft_id
        )
        and setup_step in (
          'host_basics',
          'host_pricing',
          'host_photos',
          'host_review'
        )
          then 'profile'
        else setup_step
      end,
      version = version + 1
    where id = auth.uid()
      and (
        host_parking_draft_id = p_draft_id
        or setup_draft_id = p_draft_id
      );

    return jsonb_build_object(
      'ok', true,
      'deleted', true,
      'draftId', p_draft_id,
      'storageKind', 'host_parking'
    );
  end if;

  delete from public.parking_spaces
  where id = p_draft_id
    and host_id = auth.uid()
    and status = 'draft'
  returning *
  into v_legacy_space;

  if found then
    update public.profiles
    set
      setup_draft_id = case
        when setup_draft_id = p_draft_id then null
        else setup_draft_id
      end,
      setup_step = case
        when setup_draft_id = p_draft_id
        and setup_step in (
          'host_basics',
          'host_pricing',
          'host_photos',
          'host_review'
        )
          then 'profile'
        else setup_step
      end,
      version = version + 1
    where id = auth.uid()
      and setup_draft_id = p_draft_id;

    return jsonb_build_object(
      'ok', true,
      'deleted', true,
      'draftId', p_draft_id,
      'storageKind', 'legacy_parking_space'
    );
  end if;

  raise exception 'Draft listing not found' using errcode = 'P0002';
end;
$$;

revoke all on function public.delete_owned_parking_draft(uuid) from public;
grant execute on function public.delete_owned_parking_draft(uuid) to authenticated;

comment on function public.delete_owned_parking_draft(uuid) is
  'Deletes a user-owned draft listing from My parking spaces. V2 host parking drafts are soft-discarded for auditability; legacy parking_space drafts are hard-deleted because they do not support a discarded status.';

notify pgrst, 'reload schema';
