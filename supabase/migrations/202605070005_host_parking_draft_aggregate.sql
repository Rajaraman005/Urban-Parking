create table if not exists public.parking_listing_drafts (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'draft' check (
    status in ('draft', 'published', 'discarded', 'expired')
  ),
  current_step text not null default 'host_basics' check (
    current_step in ('host_basics', 'host_pricing', 'host_photos', 'host_review', 'complete')
  ),
  version integer not null default 1 check (version > 0),
  completion_percent integer not null default 0 check (
    completion_percent between 0 and 100
  ),
  draft_data jsonb not null default '{}'::jsonb,
  validation_state jsonb not null default '{}'::jsonb,
  last_autosaved_at timestamptz,
  last_client_mutation_id text,
  expires_at timestamptz not null default now() + interval '90 days',
  published_space_id uuid unique references public.parking_spaces(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.parking_listing_draft_photos (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null references public.parking_listing_drafts(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  client_upload_id text not null,
  public_id text not null,
  secure_url text not null,
  width integer,
  height integer,
  sort_order integer not null default 0,
  upload_status text not null default 'linked' check (
    upload_status in ('pending', 'uploaded', 'linked', 'failed', 'deleted')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (draft_id, client_upload_id),
  unique (draft_id, public_id)
);

create table if not exists public.draft_mutation_log (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  draft_id uuid not null references public.parking_listing_drafts(id) on delete cascade,
  client_mutation_id text not null,
  device_id text,
  idempotency_key_hash text not null,
  request_hash text not null,
  base_version integer not null check (base_version > 0),
  result_version integer,
  field_mask text[] not null default array[]::text[],
  patch_metadata jsonb not null default '{}'::jsonb,
  result_status text not null check (
    result_status in ('applied', 'auto_merged', 'conflict', 'idempotent_replay', 'failed', 'published')
  ),
  created_at timestamptz not null default now(),
  unique (host_id, draft_id, idempotency_key_hash),
  unique (host_id, draft_id, client_mutation_id)
);

alter table public.profiles
add column if not exists host_parking_draft_id uuid
references public.parking_listing_drafts(id) on delete set null;

create index if not exists parking_listing_drafts_host_status_updated_idx
on public.parking_listing_drafts (host_id, status, updated_at desc);

create index if not exists parking_listing_drafts_expiry_idx
on public.parking_listing_drafts (expires_at)
where status = 'draft';

create index if not exists parking_listing_draft_photos_draft_order_idx
on public.parking_listing_draft_photos (draft_id, sort_order asc, created_at asc);

create index if not exists draft_mutation_log_draft_version_idx
on public.draft_mutation_log (draft_id, result_version desc, created_at desc);

create index if not exists draft_mutation_log_retention_idx
on public.draft_mutation_log (result_status, created_at);

drop trigger if exists parking_listing_drafts_set_updated_at
on public.parking_listing_drafts;
create trigger parking_listing_drafts_set_updated_at
before update on public.parking_listing_drafts
for each row
execute function public.set_updated_at();

drop trigger if exists parking_listing_draft_photos_set_updated_at
on public.parking_listing_draft_photos;
create trigger parking_listing_draft_photos_set_updated_at
before update on public.parking_listing_draft_photos
for each row
execute function public.set_updated_at();

alter table public.parking_listing_drafts enable row level security;
alter table public.parking_listing_drafts force row level security;
alter table public.parking_listing_draft_photos enable row level security;
alter table public.parking_listing_draft_photos force row level security;
alter table public.draft_mutation_log enable row level security;
alter table public.draft_mutation_log force row level security;

drop policy if exists "parking_listing_drafts_no_direct_access"
on public.parking_listing_drafts;
create policy "parking_listing_drafts_no_direct_access"
on public.parking_listing_drafts
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "parking_listing_draft_photos_no_direct_access"
on public.parking_listing_draft_photos;
create policy "parking_listing_draft_photos_no_direct_access"
on public.parking_listing_draft_photos
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "draft_mutation_log_service_role_only"
on public.draft_mutation_log;
create policy "draft_mutation_log_service_role_only"
on public.draft_mutation_log
for all
to anon, authenticated
using (false)
with check (false);

revoke all on table public.parking_listing_drafts from anon, authenticated;
revoke all on table public.parking_listing_draft_photos from anon, authenticated;
revoke all on table public.draft_mutation_log from anon, authenticated;

grant update (host_parking_draft_id) on table public.profiles to authenticated;

create or replace function public.host_parking_jsonb_deep_merge(
  p_target jsonb,
  p_patch jsonb
)
returns jsonb
language sql
immutable
as $$
  select
    case
      when jsonb_typeof(coalesce(p_target, '{}'::jsonb)) <> 'object'
        or jsonb_typeof(coalesce(p_patch, '{}'::jsonb)) <> 'object'
        then coalesce(p_patch, p_target, '{}'::jsonb)
      else (
        select jsonb_object_agg(
          coalesce(target_item.key, patch_item.key),
          case
            when target_item.value is null then patch_item.value
            when patch_item.value is null then target_item.value
            when jsonb_typeof(target_item.value) = 'object'
              and jsonb_typeof(patch_item.value) = 'object'
              then public.host_parking_jsonb_deep_merge(
                target_item.value,
                patch_item.value
              )
            else patch_item.value
          end
        )
        from jsonb_each(coalesce(p_target, '{}'::jsonb)) target_item
        full join jsonb_each(coalesce(p_patch, '{}'::jsonb)) patch_item
          on patch_item.key = target_item.key
      )
    end;
$$;

create or replace function public.host_parking_draft_completion(
  p_draft_data jsonb,
  p_photo_count integer
)
returns integer
language plpgsql
immutable
set search_path = public
as $$
declare
  v_basics jsonb := coalesce(p_draft_data->'basics', '{}'::jsonb);
  v_pricing jsonb := coalesce(p_draft_data->'pricing', '{}'::jsonb);
  v_score integer := 0;
begin
  if nullif(btrim(v_basics->>'title'), '') is not null
    and nullif(btrim(v_basics->>'address'), '') is not null
    and nullif(btrim(v_basics->>'city'), '') is not null
    and nullif(btrim(v_basics->>'locality'), '') is not null
    and nullif(btrim(v_basics->>'postalCode'), '') is not null
    and v_basics->'location' is not null
    and nullif(btrim(v_basics->>'vehicleFit'), '') is not null
    and nullif(btrim(v_basics->>'parkingType'), '') is not null then
    v_score := v_score + 35;
  end if;

  if (v_pricing->>'hourlyPrice') is not null
    and (v_pricing->>'slotsCount') is not null
    and nullif(btrim(v_pricing->>'availableFromDate'), '') is not null
    and nullif(btrim(v_pricing->>'availableToDate'), '') is not null
    and (v_pricing->>'dailyStartMinute') is not null
    and (v_pricing->>'dailyEndMinute') is not null then
    v_score := v_score + 35;
  end if;

  if coalesce(p_photo_count, 0) >= 2 then
    v_score := v_score + 20;
  elsif coalesce(p_photo_count, 0) = 1 then
    v_score := v_score + 10;
  end if;

  if v_score >= 90 then
    return 100;
  end if;

  return v_score;
end;
$$;

create or replace function public.host_parking_validate_step(
  p_step text
)
returns text
language plpgsql
immutable
as $$
begin
  if p_step not in ('host_basics', 'host_pricing', 'host_photos', 'host_review', 'complete') then
    raise exception 'Invalid host parking step' using errcode = '23514';
  end if;
  return p_step;
end;
$$;

create or replace function public.host_parking_draft_payload(
  p_draft_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  with photo_data as (
    select
      pldp.draft_id,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', pldp.id,
            'clientUploadId', pldp.client_upload_id,
            'publicId', pldp.public_id,
            'public_id', pldp.public_id,
            'secureUrl', pldp.secure_url,
            'secure_url', pldp.secure_url,
            'width', pldp.width,
            'height', pldp.height,
            'sortOrder', pldp.sort_order,
            'sort_order', pldp.sort_order,
            'uploadStatus', pldp.upload_status,
            'upload_status', pldp.upload_status
          )
          order by pldp.sort_order asc, pldp.created_at asc
        ) filter (where pldp.upload_status = 'linked'),
        '[]'::jsonb
      ) as photos
    from public.parking_listing_draft_photos pldp
    where pldp.draft_id = p_draft_id
    group by pldp.draft_id
  )
  select jsonb_build_object(
    'id', d.id,
    'host_id', d.host_id,
    'status', d.status,
    'currentStep', d.current_step,
    'current_step', d.current_step,
    'version', d.version,
    'completionPercent', d.completion_percent,
    'completion_percent', d.completion_percent,
    'draftData', d.draft_data,
    'draft_data', d.draft_data,
    'validationState', d.validation_state,
    'validation_state', d.validation_state,
    'lastAutosavedAt', d.last_autosaved_at,
    'last_autosaved_at', d.last_autosaved_at,
    'publishedSpaceId', d.published_space_id,
    'published_space_id', d.published_space_id,
    'expiresAt', d.expires_at,
    'expires_at', d.expires_at,
    'updatedAt', d.updated_at,
    'updated_at', d.updated_at,
    'parking_listing_draft_photos', coalesce(pd.photos, '[]'::jsonb),
    'parking_space_photos', coalesce(pd.photos, '[]'::jsonb)
  )
  from public.parking_listing_drafts d
  left join photo_data pd on pd.draft_id = d.id
  where d.id = p_draft_id;
$$;

create or replace function public.ensure_host_parking_draft(
  p_requested_draft_id uuid default null,
  p_create_new boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.parking_listing_drafts;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  if not coalesce(p_create_new, false) and p_requested_draft_id is not null then
    select *
    into v_draft
    from public.parking_listing_drafts
    where id = p_requested_draft_id
      and host_id = auth.uid()
      and status = 'draft';

    if found then
      return public.host_parking_draft_payload(v_draft.id);
    end if;
  end if;

  if not coalesce(p_create_new, false) then
    select *
    into v_draft
    from public.parking_listing_drafts
    where host_id = auth.uid()
      and status = 'draft'
    order by updated_at desc
    limit 1;

    if found then
      return public.host_parking_draft_payload(v_draft.id);
    end if;
  end if;

  insert into public.parking_listing_drafts (host_id)
  values (auth.uid())
  returning *
  into v_draft;

  return public.host_parking_draft_payload(v_draft.id);
end;
$$;

create or replace function public.get_host_parking_draft(
  p_draft_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.parking_listing_drafts;
begin
  select *
  into v_draft
  from public.parking_listing_drafts
  where id = p_draft_id
    and host_id = auth.uid();

  if not found then
    raise exception 'Draft listing not found' using errcode = 'P0002';
  end if;

  return public.host_parking_draft_payload(v_draft.id);
end;
$$;

create or replace function public.patch_host_parking_draft(
  p_draft_id uuid,
  p_base_version integer,
  p_client_mutation_id text,
  p_device_id text,
  p_field_mask text[],
  p_patch jsonb,
  p_idempotency_key_hash text,
  p_request_hash text,
  p_current_step text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.parking_listing_drafts;
  v_existing public.draft_mutation_log;
  v_conflicting_paths text[];
  v_merge_status text := 'applied';
  v_photo_count integer;
  v_next_data jsonb;
  v_next_step text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  if p_base_version is null or p_base_version < 1 then
    raise exception 'Invalid base version' using errcode = '23514';
  end if;

  if nullif(btrim(p_client_mutation_id), '') is null
    or nullif(btrim(p_idempotency_key_hash), '') is null
    or nullif(btrim(p_request_hash), '') is null
    or coalesce(array_length(p_field_mask, 1), 0) = 0 then
    raise exception 'Invalid mutation metadata' using errcode = '23514';
  end if;

  select *
  into v_draft
  from public.parking_listing_drafts
  where id = p_draft_id
    and host_id = auth.uid()
    and status = 'draft'
  for update;

  if not found then
    raise exception 'Draft listing not found' using errcode = 'P0002';
  end if;

  select *
  into v_existing
  from public.draft_mutation_log
  where host_id = auth.uid()
    and draft_id = p_draft_id
    and idempotency_key_hash = p_idempotency_key_hash;

  if found then
    if v_existing.request_hash <> p_request_hash then
      raise exception 'Idempotency key reused with different request'
        using errcode = '23505';
    end if;

    return jsonb_build_object(
      'ok', true,
      'mergeStatus', 'idempotent_replay',
      'draft', public.host_parking_draft_payload(p_draft_id)
    );
  end if;

  if p_base_version <> v_draft.version then
    select coalesce(array_agg(distinct changed_path), array[]::text[])
    into v_conflicting_paths
    from public.draft_mutation_log log_entry
    cross join unnest(log_entry.field_mask) as changed(changed_path)
    where log_entry.draft_id = p_draft_id
      and log_entry.host_id = auth.uid()
      and log_entry.result_version > p_base_version
      and log_entry.result_status in ('applied', 'auto_merged')
      and changed_path = any(p_field_mask);

    if coalesce(array_length(v_conflicting_paths, 1), 0) > 0 then
      insert into public.draft_mutation_log (
        host_id,
        draft_id,
        client_mutation_id,
        device_id,
        idempotency_key_hash,
        request_hash,
        base_version,
        result_version,
        field_mask,
        patch_metadata,
        result_status
      )
      values (
        auth.uid(),
        p_draft_id,
        btrim(p_client_mutation_id),
        nullif(btrim(p_device_id), ''),
        btrim(p_idempotency_key_hash),
        btrim(p_request_hash),
        p_base_version,
        v_draft.version,
        p_field_mask,
        jsonb_build_object(
          'fieldMaskSize', coalesce(array_length(p_field_mask, 1), 0),
          'conflictingPaths', to_jsonb(v_conflicting_paths)
        ),
        'conflict'
      );

      return jsonb_build_object(
        'ok', false,
        'code', 'draft_conflict',
        'conflict', true,
        'serverDraft', public.host_parking_draft_payload(p_draft_id),
        'serverVersion', v_draft.version,
        'conflictingPaths', to_jsonb(v_conflicting_paths),
        'resolutionToken', gen_random_uuid()
      );
    end if;

    v_merge_status := 'auto_merged';
  end if;

  v_next_data := public.host_parking_jsonb_deep_merge(
    v_draft.draft_data,
    coalesce(p_patch, '{}'::jsonb)
  );
  v_next_step := coalesce(
    public.host_parking_validate_step(p_current_step),
    v_draft.current_step
  );

  select count(*)
  into v_photo_count
  from public.parking_listing_draft_photos
  where draft_id = p_draft_id
    and host_id = auth.uid()
    and upload_status = 'linked';

  update public.parking_listing_drafts
  set
    current_step = v_next_step,
    version = version + 1,
    completion_percent = public.host_parking_draft_completion(v_next_data, v_photo_count),
    draft_data = v_next_data,
    last_autosaved_at = now(),
    last_client_mutation_id = btrim(p_client_mutation_id),
    expires_at = now() + interval '90 days',
    updated_at = now()
  where id = p_draft_id
  returning *
  into v_draft;

  insert into public.draft_mutation_log (
    host_id,
    draft_id,
    client_mutation_id,
    device_id,
    idempotency_key_hash,
    request_hash,
    base_version,
    result_version,
    field_mask,
    patch_metadata,
    result_status
  )
  values (
    auth.uid(),
    p_draft_id,
    btrim(p_client_mutation_id),
    nullif(btrim(p_device_id), ''),
    btrim(p_idempotency_key_hash),
    btrim(p_request_hash),
    p_base_version,
    v_draft.version,
    p_field_mask,
    jsonb_build_object('fieldMaskSize', coalesce(array_length(p_field_mask, 1), 0)),
    v_merge_status
  );

  return jsonb_build_object(
    'ok', true,
    'mergeStatus', v_merge_status,
    'draft', public.host_parking_draft_payload(p_draft_id)
  );
end;
$$;

create or replace function public.link_host_parking_draft_photo(
  p_draft_id uuid,
  p_client_upload_id text,
  p_public_id text,
  p_secure_url text,
  p_width integer,
  p_height integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.parking_listing_drafts;
  v_photo_count integer;
begin
  select *
  into v_draft
  from public.parking_listing_drafts
  where id = p_draft_id
    and host_id = auth.uid()
    and status = 'draft'
  for update;

  if not found then
    raise exception 'Draft listing not found' using errcode = 'P0002';
  end if;

  if nullif(btrim(p_client_upload_id), '') is null
    or nullif(btrim(p_public_id), '') is null
    or nullif(btrim(p_secure_url), '') is null then
    raise exception 'Invalid photo upload' using errcode = '23514';
  end if;

  select count(*)
  into v_photo_count
  from public.parking_listing_draft_photos
  where draft_id = p_draft_id
    and host_id = auth.uid()
    and upload_status = 'linked';

  if not exists (
    select 1
    from public.parking_listing_draft_photos
    where draft_id = p_draft_id
      and client_upload_id = p_client_upload_id
  ) and v_photo_count >= 5 then
    raise exception 'Maximum photo count reached' using errcode = '23514';
  end if;

  insert into public.parking_listing_draft_photos (
    draft_id,
    host_id,
    client_upload_id,
    public_id,
    secure_url,
    width,
    height,
    sort_order,
    upload_status
  )
  values (
    p_draft_id,
    auth.uid(),
    btrim(p_client_upload_id),
    btrim(p_public_id),
    btrim(p_secure_url),
    p_width,
    p_height,
    v_photo_count,
    'linked'
  )
  on conflict (draft_id, client_upload_id) do update
  set
    public_id = excluded.public_id,
    secure_url = excluded.secure_url,
    width = excluded.width,
    height = excluded.height,
    upload_status = 'linked',
    updated_at = now();

  select count(*)
  into v_photo_count
  from public.parking_listing_draft_photos
  where draft_id = p_draft_id
    and host_id = auth.uid()
    and upload_status = 'linked';

  update public.parking_listing_drafts
  set
    version = version + 1,
    completion_percent = public.host_parking_draft_completion(draft_data, v_photo_count),
    current_step = 'host_photos',
    last_autosaved_at = now(),
    updated_at = now()
  where id = p_draft_id;

  return public.host_parking_draft_payload(p_draft_id);
end;
$$;

create or replace function public.delete_host_parking_draft_photo(
  p_draft_id uuid,
  p_photo_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.parking_listing_drafts;
  v_photo_count integer;
begin
  select *
  into v_draft
  from public.parking_listing_drafts
  where id = p_draft_id
    and host_id = auth.uid()
    and status = 'draft'
  for update;

  if not found then
    raise exception 'Draft listing not found' using errcode = 'P0002';
  end if;

  update public.parking_listing_draft_photos
  set
    upload_status = 'deleted',
    updated_at = now()
  where id = p_photo_id
    and draft_id = p_draft_id
    and host_id = auth.uid();

  with ordered as (
    select
      id,
      row_number() over (order by sort_order asc, created_at asc) - 1 as next_order
    from public.parking_listing_draft_photos
    where draft_id = p_draft_id
      and host_id = auth.uid()
      and upload_status = 'linked'
  )
  update public.parking_listing_draft_photos p
  set sort_order = ordered.next_order
  from ordered
  where p.id = ordered.id;

  select count(*)
  into v_photo_count
  from public.parking_listing_draft_photos
  where draft_id = p_draft_id
    and host_id = auth.uid()
    and upload_status = 'linked';

  update public.parking_listing_drafts
  set
    version = version + 1,
    completion_percent = public.host_parking_draft_completion(draft_data, v_photo_count),
    last_autosaved_at = now(),
    updated_at = now()
  where id = p_draft_id;

  return public.host_parking_draft_payload(p_draft_id);
end;
$$;

create or replace function public.reorder_host_parking_draft_photos(
  p_draft_id uuid,
  p_photo_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expected_count integer;
  v_actual_count integer;
  v_photo_id uuid;
  v_index integer := 0;
begin
  if not exists (
    select 1
    from public.parking_listing_drafts
    where id = p_draft_id
      and host_id = auth.uid()
      and status = 'draft'
    for update
  ) then
    raise exception 'Draft listing not found' using errcode = 'P0002';
  end if;

  select count(*)
  into v_expected_count
  from public.parking_listing_draft_photos
  where draft_id = p_draft_id
    and host_id = auth.uid()
    and upload_status = 'linked';

  select count(distinct photo_id)
  into v_actual_count
  from unnest(coalesce(p_photo_ids, array[]::uuid[])) as input(photo_id)
  join public.parking_listing_draft_photos p
    on p.id = photo_id
    and p.draft_id = p_draft_id
    and p.host_id = auth.uid()
    and p.upload_status = 'linked';

  if v_expected_count <> v_actual_count then
    raise exception 'Photo order is invalid' using errcode = '23514';
  end if;

  foreach v_photo_id in array p_photo_ids loop
    update public.parking_listing_draft_photos
    set
      sort_order = v_index,
      updated_at = now()
    where id = v_photo_id
      and draft_id = p_draft_id
      and host_id = auth.uid();
    v_index := v_index + 1;
  end loop;

  update public.parking_listing_drafts
  set
    version = version + 1,
    last_autosaved_at = now(),
    updated_at = now()
  where id = p_draft_id;

  return public.host_parking_draft_payload(p_draft_id);
end;
$$;

create or replace function public.publish_host_parking_draft(
  p_draft_id uuid,
  p_expected_version integer,
  p_client_mutation_id text,
  p_idempotency_key_hash text,
  p_request_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.parking_listing_drafts;
  v_basics jsonb;
  v_pricing jsonb;
  v_photo_count integer;
  v_space public.parking_spaces;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select *
  into v_draft
  from public.parking_listing_drafts
  where id = p_draft_id
    and host_id = auth.uid()
  for update;

  if not found then
    raise exception 'Draft listing not found' using errcode = 'P0002';
  end if;

  if v_draft.status = 'published' and v_draft.published_space_id is not null then
    return jsonb_build_object(
      'ok', true,
      'draft', public.host_parking_draft_payload(v_draft.id),
      'publishedSpaceId', v_draft.published_space_id
    );
  end if;

  if v_draft.status <> 'draft' then
    raise exception 'Draft cannot be published' using errcode = '23514';
  end if;

  if v_draft.version <> p_expected_version then
    raise exception 'Stale draft version' using errcode = '40001';
  end if;

  v_basics := coalesce(v_draft.draft_data->'basics', '{}'::jsonb);
  v_pricing := coalesce(v_draft.draft_data->'pricing', '{}'::jsonb);

  if nullif(btrim(v_basics->>'title'), '') is null
    or nullif(btrim(v_basics->>'address'), '') is null
    or nullif(btrim(v_basics->>'locality'), '') is null
    or nullif(btrim(v_basics->>'city'), '') is null
    or (v_basics->>'postalCode') !~ '^[1-9][0-9]{5}$'
    or nullif(btrim(v_basics->>'vehicleFit'), '') is null
    or (v_basics->>'vehicleFit') not in ('bike', 'car', 'both')
    or nullif(btrim(v_basics->>'parkingType'), '') is null
    or (v_basics->>'parkingType') not in ('basement', 'covered', 'driveway', 'garage', 'open')
    or nullif(btrim(v_basics->>'accessInstructions'), '') is null
    or char_length(btrim(v_basics->>'accessInstructions')) not between 50 and 200
    or (v_basics#>>'{location,latitude}') is null
    or (v_basics#>>'{location,longitude}') is null
    or (v_basics#>>'{location,latitude}')::numeric not between 6 and 38
    or (v_basics#>>'{location,longitude}')::numeric not between 68 and 98
    or nullif(btrim(v_basics->>'addressProvider'), '') is null
    or (v_basics->>'addressProvider') not in ('nominatim', 'manual')
    or (v_basics->>'addressConfidence') is null
    or (v_basics->>'addressConfidence')::numeric not between 0 and 1 then
    raise exception 'Listing basics are incomplete' using errcode = '23514';
  end if;

  if (v_pricing->>'hourlyPrice') is null
    or (v_pricing->>'hourlyPrice')::integer not between 10 and 10000
    or (v_pricing->>'slotsCount') is null
    or (v_pricing->>'slotsCount')::integer not between 1 and 50
    or nullif(btrim(v_pricing->>'availableFromDate'), '') is null
    or nullif(btrim(v_pricing->>'availableToDate'), '') is null
    or (v_pricing->>'availableToDate')::date < (v_pricing->>'availableFromDate')::date
    or (v_pricing->>'dailyStartMinute') is null
    or (v_pricing->>'dailyStartMinute')::integer not between 0 and 1410
    or (v_pricing->>'dailyEndMinute') is null
    or (v_pricing->>'dailyEndMinute')::integer not between 30 and 1440
    or (v_pricing->>'dailyStartMinute')::integer % 30 <> 0
    or (v_pricing->>'dailyEndMinute')::integer % 30 <> 0
    or (v_pricing->>'dailyEndMinute')::integer <= (v_pricing->>'dailyStartMinute')::integer then
    raise exception 'Listing pricing is incomplete' using errcode = '23514';
  end if;

  select count(*)
  into v_photo_count
  from public.parking_listing_draft_photos
  where draft_id = p_draft_id
    and host_id = auth.uid()
    and upload_status = 'linked';

  if v_photo_count < 2 then
    raise exception 'At least two photos are required' using errcode = '23514';
  end if;

  insert into public.parking_spaces (
    host_id,
    title,
    address,
    locality,
    city,
    postal_code,
    latitude,
    longitude,
    address_place_id,
    address_provider,
    address_confidence,
    address_raw_osm_json,
    location_confirmed_at,
    parking_type,
    vehicle_fit,
    access_instructions,
    hourly_price,
    slots_count,
    available_from_date,
    available_to_date,
    daily_start_minute,
    daily_end_minute,
    skip_weekends,
    availability_summary,
    status,
    submitted_at
  )
  values (
    auth.uid(),
    btrim(v_basics->>'title'),
    btrim(v_basics->>'address'),
    btrim(v_basics->>'locality'),
    btrim(v_basics->>'city'),
    btrim(v_basics->>'postalCode'),
    (v_basics#>>'{location,latitude}')::numeric,
    (v_basics#>>'{location,longitude}')::numeric,
    nullif(btrim(v_basics->>'addressPlaceId'), ''),
    btrim(v_basics->>'addressProvider'),
    (v_basics->>'addressConfidence')::numeric,
    v_basics->'addressRaw',
    now(),
    btrim(v_basics->>'parkingType'),
    btrim(v_basics->>'vehicleFit'),
    btrim(v_basics->>'accessInstructions'),
    (v_pricing->>'hourlyPrice')::integer,
    (v_pricing->>'slotsCount')::integer,
    (v_pricing->>'availableFromDate')::date,
    (v_pricing->>'availableToDate')::date,
    (v_pricing->>'dailyStartMinute')::integer,
    (v_pricing->>'dailyEndMinute')::integer,
    coalesce((v_pricing->>'skipWeekends')::boolean, false),
    nullif(btrim(v_pricing->>'availabilitySummary'), ''),
    'pending_review',
    now()
  )
  returning *
  into v_space;

  insert into public.parking_space_photos (
    parking_space_id,
    host_id,
    public_id,
    secure_url,
    width,
    height,
    sort_order,
    upload_status
  )
  select
    v_space.id,
    auth.uid(),
    public_id,
    secure_url,
    width,
    height,
    sort_order,
    'linked'
  from public.parking_listing_draft_photos
  where draft_id = p_draft_id
    and host_id = auth.uid()
    and upload_status = 'linked'
  order by sort_order asc, created_at asc;

  update public.profiles
  set
    role = case when role = 'admin' then 'admin' else 'host' end,
    intent = 'host',
    setup_step = 'complete',
    host_parking_draft_id = p_draft_id,
    onboarding_completed_at = coalesce(onboarding_completed_at, now()),
    version = version + 1
  where id = auth.uid();

  update public.parking_listing_drafts
  set
    status = 'published',
    current_step = 'complete',
    version = version + 1,
    completion_percent = 100,
    published_space_id = v_space.id,
    updated_at = now()
  where id = p_draft_id
  returning *
  into v_draft;

  insert into public.draft_mutation_log (
    host_id,
    draft_id,
    client_mutation_id,
    idempotency_key_hash,
    request_hash,
    base_version,
    result_version,
    field_mask,
    patch_metadata,
    result_status
  )
  values (
    auth.uid(),
    p_draft_id,
    btrim(p_client_mutation_id),
    btrim(p_idempotency_key_hash),
    btrim(p_request_hash),
    p_expected_version,
    v_draft.version,
    array['publish'],
    jsonb_build_object('publishedSpaceId', v_space.id),
    'published'
  )
  on conflict (host_id, draft_id, idempotency_key_hash) do nothing;

  return jsonb_build_object(
    'ok', true,
    'draft', public.host_parking_draft_payload(p_draft_id),
    'publishedSpaceId', v_space.id
  );
end;
$$;

create or replace function public.get_owned_host_parking_drafts()
returns setof jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', d.id,
    'title', coalesce(nullif(btrim(d.draft_data#>>'{basics,title}'), ''), 'Parking space draft'),
    'address', coalesce(nullif(btrim(d.draft_data#>>'{basics,address}'), ''), ''),
    'locality', coalesce(nullif(btrim(d.draft_data#>>'{basics,locality}'), ''), ''),
    'city', nullif(btrim(d.draft_data#>>'{basics,city}'), ''),
    'postalCode', nullif(btrim(d.draft_data#>>'{basics,postalCode}'), ''),
    'distanceKm', 0,
    'rating', 0,
    'reviewCount', 0,
    'price', coalesce(nullif(d.draft_data#>>'{pricing,hourlyPrice}', '')::integer, 0),
    'currency', 'INR',
    'cadence', 'hourly',
    'availableFromDate', nullif(d.draft_data#>>'{pricing,availableFromDate}', ''),
    'availableToDate', nullif(d.draft_data#>>'{pricing,availableToDate}', ''),
    'dailyStartMinute', nullif(d.draft_data#>>'{pricing,dailyStartMinute}', '')::integer,
    'dailyEndMinute', nullif(d.draft_data#>>'{pricing,dailyEndMinute}', '')::integer,
    'skipWeekends', coalesce(nullif(d.draft_data#>>'{pricing,skipWeekends}', '')::boolean, false),
    'slotsAvailable', coalesce(nullif(d.draft_data#>>'{pricing,slotsCount}', '')::integer, 0),
    'location', jsonb_build_object(
      'latitude', coalesce(nullif(d.draft_data#>>'{basics,location,latitude}', '')::double precision, 13.0827),
      'longitude', coalesce(nullif(d.draft_data#>>'{basics,location,longitude}', '')::double precision, 80.2707)
    ),
    'amenities', '[]'::jsonb,
    'imageUrl', coalesce(
      (
        select p.secure_url
        from public.parking_listing_draft_photos p
        where p.draft_id = d.id
          and p.upload_status = 'linked'
        order by p.sort_order asc, p.created_at asc
        limit 1
      ),
      'https://images.unsplash.com/photo-1506521781263-d8422e82f27a'
    ),
    'imageUrls', coalesce(
      (
        select jsonb_agg(p.secure_url order by p.sort_order asc, p.created_at asc)
        from public.parking_listing_draft_photos p
        where p.draft_id = d.id
          and p.upload_status = 'linked'
      ),
      '[]'::jsonb
    ),
    'status', 'draft',
    'version', d.version,
    'updatedAt', d.updated_at
  )
  from public.parking_listing_drafts d
  where d.host_id = auth.uid()
    and d.status = 'draft'
  order by d.updated_at desc;
$$;

revoke all on function public.ensure_host_parking_draft(uuid, boolean) from public;
grant execute on function public.ensure_host_parking_draft(uuid, boolean) to authenticated;

revoke all on function public.get_host_parking_draft(uuid) from public;
grant execute on function public.get_host_parking_draft(uuid) to authenticated;

revoke all on function public.patch_host_parking_draft(
  uuid,
  integer,
  text,
  text,
  text[],
  jsonb,
  text,
  text,
  text
) from public;
grant execute on function public.patch_host_parking_draft(
  uuid,
  integer,
  text,
  text,
  text[],
  jsonb,
  text,
  text,
  text
) to authenticated;

revoke all on function public.link_host_parking_draft_photo(
  uuid,
  text,
  text,
  text,
  integer,
  integer
) from public;
grant execute on function public.link_host_parking_draft_photo(
  uuid,
  text,
  text,
  text,
  integer,
  integer
) to authenticated;

revoke all on function public.delete_host_parking_draft_photo(uuid, uuid) from public;
grant execute on function public.delete_host_parking_draft_photo(uuid, uuid) to authenticated;

revoke all on function public.reorder_host_parking_draft_photos(uuid, uuid[]) from public;
grant execute on function public.reorder_host_parking_draft_photos(uuid, uuid[]) to authenticated;

revoke all on function public.publish_host_parking_draft(
  uuid,
  integer,
  text,
  text,
  text
) from public;
grant execute on function public.publish_host_parking_draft(
  uuid,
  integer,
  text,
  text,
  text
) to authenticated;

revoke all on function public.get_owned_host_parking_drafts() from public;
grant execute on function public.get_owned_host_parking_drafts() to authenticated;

comment on table public.parking_listing_drafts is
  'Private host parking draft aggregate. Incomplete listing data lives here until publish transaction creates a parking_spaces row.';

comment on table public.parking_listing_draft_photos is
  'Private draft-scoped Cloudinary photo links. Records are copied to parking_space_photos during publish.';

comment on table public.draft_mutation_log is
  'Service-role-only idempotency, audit, and conflict ledger. Never expose to clients, realtime, analytics exports, or logs without redaction.';

notify pgrst, 'reload schema';
