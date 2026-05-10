create extension if not exists pgcrypto;

do $notification_status_check$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'notifications_status_check'
      and conrelid = 'public.notifications'::regclass
  ) then
    alter table public.notifications
    drop constraint notifications_status_check;
  end if;
end;
$notification_status_check$;

alter table public.notifications
  add column if not exists event_id uuid,
  add column if not exists aggregate_type text,
  add column if not exists aggregate_id uuid,
  add column if not exists category text not null default 'message',
  add column if not exists priority text not null default 'normal',
  add column if not exists title text,
  add column if not exists body text,
  add column if not exists deeplink text,
  add column if not exists template_key text,
  add column if not exists template_version integer,
  add column if not exists dedupe_key text,
  add column if not exists channels text[] not null default array['in_app']::text[],
  add column if not exists expires_at timestamptz;

alter table public.notifications
  add column if not exists dedupe_key_normalized text
    generated always as (coalesce(dedupe_key, '')) stored;

alter table public.notifications
  add constraint notifications_status_check
  check (status in ('unread', 'read', 'dismissed', 'archived'));

alter table public.notifications
  drop constraint if exists notifications_category_check;
alter table public.notifications
  add constraint notifications_category_check
  check (category in ('message', 'booking', 'payment', 'security', 'admin', 'system', 'marketing'));

alter table public.notifications
  drop constraint if exists notifications_priority_check;
alter table public.notifications
  add constraint notifications_priority_check
  check (priority in ('low', 'normal', 'high', 'critical'));

alter table public.notifications
  drop constraint if exists notifications_template_version_check;
alter table public.notifications
  add constraint notifications_template_version_check
  check (template_version is null or template_version > 0);

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  actor_id uuid references auth.users(id) on delete set null,
  recipient_selector jsonb not null,
  category text not null check (
    category in ('message', 'booking', 'payment', 'security', 'admin', 'system', 'marketing')
  ),
  priority text not null default 'normal' check (
    priority in ('low', 'normal', 'high', 'critical')
  ),
  channels text[] not null default array['in_app']::text[],
  template_key text not null,
  template_version integer not null check (template_version > 0),
  payload jsonb not null default '{}'::jsonb,
  idempotency_key text not null,
  dedupe_key text,
  scheduled_at timestamptz not null default now(),
  trace_id text not null,
  status text not null default 'pending' check (
    status in ('pending', 'shadow', 'fanout_processing', 'fanout_complete', 'failed', 'dead_lettered', 'discarded')
  ),
  fanout_started_at timestamptz,
  fanout_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(recipient_selector) = 'object'),
  check (cardinality(channels) > 0),
  check (idempotency_key = btrim(idempotency_key)),
  check (trace_id = btrim(trace_id))
);

create unique index if not exists notification_events_idempotency_key_idx
on public.notification_events (idempotency_key);

create index if not exists notification_events_status_scheduled_priority_idx
on public.notification_events (status, scheduled_at, priority, created_at);

create index if not exists notification_events_aggregate_idx
on public.notification_events (aggregate_type, aggregate_id, created_at desc);

create table if not exists public.notification_fanout_jobs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.notification_events(id) on delete cascade,
  cursor_offset integer not null default 0 check (cursor_offset >= 0),
  batch_size integer not null default 500 check (batch_size between 1 and 5000),
  priority text not null default 'normal' check (
    priority in ('low', 'normal', 'high', 'critical')
  ),
  status text not null default 'pending' check (
    status in ('pending', 'processing', 'complete', 'failed', 'dead_lettered', 'discarded')
  ),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  locked_until timestamptz,
  locked_by text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists notification_fanout_jobs_pending_idx
on public.notification_fanout_jobs (status, next_attempt_at, priority, created_at)
where status = 'pending';

create index if not exists notification_fanout_jobs_event_idx
on public.notification_fanout_jobs (event_id, created_at);

create unique index if not exists notification_fanout_jobs_event_cursor_idx
on public.notification_fanout_jobs (event_id, cursor_offset);

create table if not exists public.notification_delivery_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check (channel in ('in_app', 'realtime', 'push', 'email', 'sms')),
  provider text not null,
  priority text not null default 'normal' check (
    priority in ('low', 'normal', 'high', 'critical')
  ),
  status text not null default 'pending' check (
    status in ('pending', 'processing', 'sent', 'failed', 'dead_lettered', 'discarded', 'suppressed')
  ),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  locked_until timestamptz,
  locked_by text,
  idempotency_key text not null,
  provider_message_id text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists notification_delivery_jobs_idempotency_key_idx
on public.notification_delivery_jobs (idempotency_key);

create index if not exists notification_delivery_jobs_pending_idx
on public.notification_delivery_jobs (status, next_attempt_at, priority, created_at)
where status = 'pending';

create index if not exists notification_delivery_jobs_notification_idx
on public.notification_delivery_jobs (notification_id, channel, created_at desc);

create table if not exists public.notification_delivery_logs (
  id uuid not null default gen_random_uuid(),
  delivery_job_id uuid not null,
  notification_id uuid,
  recipient_id uuid,
  channel text not null,
  provider text not null,
  attempt integer not null check (attempt > 0),
  status text not null,
  provider_message_id text,
  provider_status_code integer,
  error_code text,
  error_message text,
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  created_at timestamptz not null default now(),
  primary key (id, created_at)
) partition by range (created_at);

create table if not exists public.notification_delivery_logs_202605
partition of public.notification_delivery_logs
for values from ('2026-05-01') to ('2026-06-01');

create table if not exists public.notification_dead_letters (
  id uuid primary key default gen_random_uuid(),
  source_table text not null check (
    source_table in ('notification_events', 'notification_fanout_jobs', 'notification_delivery_jobs')
  ),
  source_id uuid not null,
  reason text not null,
  payload jsonb not null default '{}'::jsonb,
  replay_status text not null default 'not_replayed' check (
    replay_status in ('not_replayed', 'queued', 'replayed', 'discarded')
  ),
  created_at timestamptz not null default now(),
  replayed_at timestamptz
);

create index if not exists notification_dead_letters_source_idx
on public.notification_dead_letters (source_table, source_id, created_at desc);

create table if not exists public.notification_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (
    category in ('message', 'booking', 'payment', 'security', 'admin', 'system', 'marketing')
  ),
  in_app_enabled boolean not null default true,
  realtime_enabled boolean not null default true,
  push_enabled boolean not null default true,
  email_enabled boolean not null default false,
  sms_enabled boolean not null default false,
  quiet_hours_enabled boolean not null default false,
  quiet_hours_start_minute integer check (
    quiet_hours_start_minute is null or quiet_hours_start_minute between 0 and 1439
  ),
  quiet_hours_end_minute integer check (
    quiet_hours_end_minute is null or quiet_hours_end_minute between 0 and 1439
  ),
  timezone text not null default 'Asia/Kolkata',
  marketing_consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, category)
);

create table if not exists public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  provider text not null default 'fcm' check (provider in ('fcm', 'apns', 'web_push')),
  token_ciphertext text not null,
  token_hash text not null,
  app_version text,
  locale text,
  timezone text not null default 'Asia/Kolkata',
  status text not null default 'active' check (
    status in ('active', 'suspect', 'stale', 'expired', 'invalidated')
  ),
  failure_count integer not null default 0 check (failure_count >= 0),
  last_seen_at timestamptz not null default now(),
  invalidated_at timestamptz,
  invalidation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists notification_devices_user_status_seen_idx
on public.notification_devices (user_id, status, last_seen_at desc);

create unique index if not exists notification_devices_active_token_hash_idx
on public.notification_devices (token_hash)
where status = 'active';

create table if not exists public.notification_templates (
  id uuid primary key default gen_random_uuid(),
  template_key text not null,
  version integer not null check (version > 0),
  status text not null default 'draft' check (
    status in ('draft', 'active', 'deprecated')
  ),
  category text not null check (
    category in ('message', 'booking', 'payment', 'security', 'admin', 'system', 'marketing')
  ),
  title_template text not null,
  body_template text not null,
  deeplink_template text,
  default_channels text[] not null default array['in_app', 'realtime']::text[],
  created_by_admin_id uuid references public.admin_users(id) on delete set null,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  deprecated_at timestamptz,
  unique (template_key, version)
);

create unique index if not exists notification_templates_one_active_idx
on public.notification_templates (template_key)
where status = 'active';

create table if not exists public.notification_unread_counters (
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (
    category in ('all', 'message', 'booking', 'payment', 'security', 'admin', 'system', 'marketing')
  ),
  unread_count integer not null default 0 check (unread_count >= 0),
  counter_version bigint not null default 0 check (counter_version >= 0),
  reconciled_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, category)
);

create table if not exists public.notification_counter_reconciliation_runs (
  id uuid primary key default gen_random_uuid(),
  ok boolean not null,
  sampled_user_count integer not null default 0 check (sampled_user_count >= 0),
  drifted_user_count integer not null default 0 check (drifted_user_count >= 0),
  max_absolute_drift integer not null default 0 check (max_absolute_drift >= 0),
  duration_ms integer not null default 0 check (duration_ms >= 0),
  error_message text,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_audit_logs (
  id uuid not null default gen_random_uuid(),
  actor_id uuid,
  actor_type text not null check (actor_type in ('user', 'admin', 'system', 'worker')),
  action text not null,
  target_type text not null,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  trace_id text,
  created_at timestamptz not null default now(),
  primary key (id, created_at)
) partition by range (created_at);

create table if not exists public.notification_audit_logs_202605
partition of public.notification_audit_logs
for values from ('2026-05-01') to ('2026-06-01');

create index if not exists notifications_recipient_cursor_idx
on public.notifications (recipient_id, created_at desc, id desc);

create index if not exists notifications_recipient_unread_idx
on public.notifications (recipient_id, status, created_at desc)
where status = 'unread';

create unique index if not exists notifications_event_recipient_dedupe_idx
on public.notifications (
  event_id,
  recipient_id,
  category,
  dedupe_key_normalized
)
where event_id is not null;

drop trigger if exists notification_events_set_updated_at on public.notification_events;
create trigger notification_events_set_updated_at
before update on public.notification_events
for each row
execute function public.set_updated_at();

drop trigger if exists notification_fanout_jobs_set_updated_at on public.notification_fanout_jobs;
create trigger notification_fanout_jobs_set_updated_at
before update on public.notification_fanout_jobs
for each row
execute function public.set_updated_at();

drop trigger if exists notification_delivery_jobs_set_updated_at on public.notification_delivery_jobs;
create trigger notification_delivery_jobs_set_updated_at
before update on public.notification_delivery_jobs
for each row
execute function public.set_updated_at();

drop trigger if exists notification_preferences_set_updated_at on public.notification_preferences;
create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row
execute function public.set_updated_at();

drop trigger if exists notification_devices_set_updated_at on public.notification_devices;
create trigger notification_devices_set_updated_at
before update on public.notification_devices
for each row
execute function public.set_updated_at();

create or replace function public.notification_recipient_count(p_selector jsonb)
returns integer
language sql
immutable
as $notification_recipient_count$
  select case
    when p_selector->>'type' = 'users'
      then coalesce(jsonb_array_length(p_selector->'userIds'), 0)
    else 0
  end;
$notification_recipient_count$;

create or replace function public.create_notification_event(
  p_event_type text,
  p_aggregate_type text,
  p_aggregate_id uuid,
  p_actor_id uuid,
  p_recipient_selector jsonb,
  p_category text,
  p_priority text,
  p_channels text[],
  p_template_key text,
  p_template_version integer,
  p_payload jsonb,
  p_idempotency_key text,
  p_dedupe_key text default null,
  p_scheduled_at timestamptz default now(),
  p_trace_id text default null,
  p_shadow boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $create_notification_event$
declare
  v_event public.notification_events;
  v_recipient_count integer;
  v_batch_size integer;
  v_status text := case when coalesce(p_shadow, false) then 'shadow' else 'pending' end;
begin
  if p_event_type is null or btrim(p_event_type) = '' then
    raise exception 'Notification event type is required' using errcode = '23514';
  end if;

  if coalesce(p_recipient_selector->>'type', '') not in ('users', 'segment') then
    raise exception 'Unsupported notification recipient selector' using errcode = '23514';
  end if;

  if p_recipient_selector->>'type' = 'users'
    and public.notification_recipient_count(p_recipient_selector) = 0 then
    raise exception 'Notification recipient list is empty' using errcode = '23514';
  end if;

  insert into public.notification_events (
    event_type,
    aggregate_type,
    aggregate_id,
    actor_id,
    recipient_selector,
    category,
    priority,
    channels,
    template_key,
    template_version,
    payload,
    idempotency_key,
    dedupe_key,
    scheduled_at,
    trace_id,
    status
  )
  values (
    btrim(p_event_type),
    btrim(p_aggregate_type),
    p_aggregate_id,
    p_actor_id,
    p_recipient_selector,
    p_category,
    coalesce(p_priority, 'normal'),
    coalesce(p_channels, array['in_app']::text[]),
    btrim(p_template_key),
    p_template_version,
    coalesce(p_payload, '{}'::jsonb),
    btrim(p_idempotency_key),
    nullif(btrim(coalesce(p_dedupe_key, '')), ''),
    coalesce(p_scheduled_at, now()),
    coalesce(nullif(btrim(coalesce(p_trace_id, '')), ''), gen_random_uuid()::text),
    v_status
  )
  on conflict (idempotency_key) do update
  set updated_at = public.notification_events.updated_at
  returning *
  into v_event;

  if v_event.status = 'pending' and not coalesce(p_shadow, false) then
    v_recipient_count := public.notification_recipient_count(v_event.recipient_selector);
    v_batch_size := case
      when v_recipient_count <= 20 then 20
      else 500
    end;

    insert into public.notification_fanout_jobs (
      event_id,
      batch_size,
      priority,
      status,
      next_attempt_at
    )
    values (
      v_event.id,
      v_batch_size,
      v_event.priority,
      'pending',
      v_event.scheduled_at
    )
    on conflict do nothing;
  end if;

  return jsonb_build_object(
    'id', v_event.id,
    'status', v_event.status,
    'idempotencyKey', v_event.idempotency_key
  );
end;
$create_notification_event$;

create or replace function public.bump_notification_unread_counter(
  p_user_id uuid,
  p_category text,
  p_delta integer
)
returns void
language plpgsql
security definer
set search_path = public
as $bump_notification_unread_counter$
begin
  insert into public.notification_unread_counters (
    user_id,
    category,
    unread_count,
    counter_version,
    updated_at
  )
  values (
    p_user_id,
    p_category,
    greatest(p_delta, 0),
    1,
    now()
  )
  on conflict (user_id, category) do update
  set
    unread_count = greatest(public.notification_unread_counters.unread_count + p_delta, 0),
    counter_version = public.notification_unread_counters.counter_version + 1,
    updated_at = now();
end;
$bump_notification_unread_counter$;

create or replace function public.sync_notification_unread_counter()
returns trigger
language plpgsql
security definer
set search_path = public
as $sync_notification_unread_counter$
begin
  if tg_op = 'INSERT' then
    if new.status = 'unread' then
      perform public.bump_notification_unread_counter(new.recipient_id, 'all', 1);
      perform public.bump_notification_unread_counter(new.recipient_id, new.category, 1);
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.status = 'unread' and new.status <> 'unread' then
      perform public.bump_notification_unread_counter(new.recipient_id, 'all', -1);
      perform public.bump_notification_unread_counter(new.recipient_id, new.category, -1);
    elsif old.status <> 'unread' and new.status = 'unread' then
      perform public.bump_notification_unread_counter(new.recipient_id, 'all', 1);
      perform public.bump_notification_unread_counter(new.recipient_id, new.category, 1);
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' and old.status = 'unread' then
    perform public.bump_notification_unread_counter(old.recipient_id, 'all', -1);
    perform public.bump_notification_unread_counter(old.recipient_id, old.category, -1);
  end if;
  return old;
end;
$sync_notification_unread_counter$;

drop trigger if exists notifications_unread_counter_sync on public.notifications;
create trigger notifications_unread_counter_sync
after insert or update of status or delete on public.notifications
for each row
execute function public.sync_notification_unread_counter();

create or replace function public.list_notifications(
  p_limit integer default 30,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null,
  p_status text default null,
  p_category text default null
)
returns jsonb
language sql
security definer
set search_path = public
as $list_notifications$
  with items as (
    select jsonb_build_object(
      'id', n.id,
      'cursor', n.created_at::text || '|' || n.id::text,
      'category', n.category,
      'priority', n.priority,
      'title', coalesce(n.title, n.payload->>'title', n.event_type),
      'body', coalesce(n.body, n.payload->>'body', n.payload->>'preview', ''),
      'deeplink', n.deeplink,
      'status', n.status,
      'createdAt', n.created_at,
      'readAt', n.read_at,
      'payload', n.payload,
      'aggregateType', n.aggregate_type,
      'aggregateId', n.aggregate_id
    ) as item
    from public.notifications n
    where n.recipient_id = auth.uid()
      and (p_status is null or n.status = p_status)
      and (p_category is null or n.category = p_category)
      and (
        p_before_created_at is null
        or (n.created_at, n.id) < (
          p_before_created_at,
          coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)
        )
      )
    order by n.created_at desc, n.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  ),
  counters as (
    select jsonb_object_agg(category, unread_count) as unread_by_category
    from public.notification_unread_counters
    where user_id = auth.uid()
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(items.item), '[]'::jsonb),
    'unreadByCategory', coalesce((select unread_by_category from counters), '{}'::jsonb)
  )
  from items;
$list_notifications$;

create or replace function public.sync_notifications(
  p_after_created_at timestamptz,
  p_after_id uuid,
  p_limit integer default 100
)
returns jsonb
language sql
security definer
set search_path = public
as $sync_notifications$
  with delta as (
    select n.*
    from public.notifications n
    where n.recipient_id = auth.uid()
      and (
        p_after_created_at is null
        or (n.created_at, n.id) > (
          p_after_created_at,
          coalesce(p_after_id, '00000000-0000-0000-0000-000000000000'::uuid)
        )
      )
    order by n.created_at asc, n.id asc
    limit least(greatest(coalesce(p_limit, 100), 1), 500)
  )
  select jsonb_build_object(
    'items',
    coalesce(jsonb_agg(
      jsonb_build_object(
        'id', n.id,
        'cursor', n.created_at::text || '|' || n.id::text,
        'category', n.category,
        'priority', n.priority,
        'title', coalesce(n.title, n.payload->>'title', n.event_type),
        'body', coalesce(n.body, n.payload->>'body', n.payload->>'preview', ''),
        'deeplink', n.deeplink,
        'status', n.status,
        'createdAt', n.created_at,
        'readAt', n.read_at,
        'payload', n.payload
      )
      order by n.created_at asc, n.id asc
    ), '[]'::jsonb)
  )
  from delta n;
$sync_notifications$;

create or replace function public.mark_notifications_read(
  p_notification_id uuid default null,
  p_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $mark_notifications_read$
declare
  v_updated integer;
begin
  update public.notifications
  set
    status = 'read',
    read_at = coalesce(read_at, now())
  where recipient_id = auth.uid()
    and status = 'unread'
    and (p_notification_id is null or id = p_notification_id)
    and (p_category is null or category = p_category);

  get diagnostics v_updated = row_count;
  return jsonb_build_object('ok', true, 'updatedCount', v_updated);
end;
$mark_notifications_read$;

create or replace function public.claim_notification_fanout_jobs(
  p_worker_id text,
  p_limit integer default 10
)
returns setof public.notification_fanout_jobs
language plpgsql
security definer
set search_path = public
as $claim_notification_fanout_jobs$
begin
  return query
  with candidates as (
    select id
    from public.notification_fanout_jobs
    where status = 'pending'
      and next_attempt_at <= now()
    order by
      case priority
        when 'critical' then 0
        when 'high' then 1
        when 'normal' then 2
        else 3
      end,
      created_at asc
    limit least(greatest(coalesce(p_limit, 10), 1), 100)
    for update skip locked
  )
  update public.notification_fanout_jobs job
  set
    status = 'processing',
    attempts = attempts + 1,
    locked_by = left(coalesce(p_worker_id, 'unknown'), 120),
    locked_until = now() + interval '2 minutes'
  from candidates
  where job.id = candidates.id
  returning job.*;
end;
$claim_notification_fanout_jobs$;

create or replace function public.claim_notification_delivery_jobs(
  p_worker_id text,
  p_limit integer default 50
)
returns setof public.notification_delivery_jobs
language plpgsql
security definer
set search_path = public
as $claim_notification_delivery_jobs$
begin
  return query
  with candidates as (
    select id
    from public.notification_delivery_jobs
    where status = 'pending'
      and next_attempt_at <= now()
    order by
      case priority
        when 'critical' then 0
        when 'high' then 1
        when 'normal' then 2
        else 3
      end,
      created_at asc
    limit least(greatest(coalesce(p_limit, 50), 1), 500)
    for update skip locked
  )
  update public.notification_delivery_jobs job
  set
    status = 'processing',
    attempts = attempts + 1,
    locked_by = left(coalesce(p_worker_id, 'unknown'), 120),
    locked_until = now() + interval '2 minutes'
  from candidates
  where job.id = candidates.id
  returning job.*;
end;
$claim_notification_delivery_jobs$;

create or replace function public.reconcile_notification_unread_counters(
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $reconcile_notification_unread_counters$
declare
  v_started_at timestamptz := clock_timestamp();
  v_users integer := 0;
  v_drifted integer := 0;
  v_max_drift integer := 0;
  v_duration integer;
begin
  with target_users as (
    select distinct recipient_id as user_id
    from public.notifications
    where p_user_id is null or recipient_id = p_user_id
    limit case when p_user_id is null then 5000 else 1 end
  ),
  desired as (
    select user_id, 'all'::text as category, count(n.id)::integer as unread_count
    from target_users tu
    left join public.notifications n
      on n.recipient_id = tu.user_id
     and n.status = 'unread'
    group by user_id
    union all
    select tu.user_id, c.category, count(n.id)::integer as unread_count
    from target_users tu
    cross join (
      values
        ('message'), ('booking'), ('payment'), ('security'), ('admin'), ('system'), ('marketing')
    ) c(category)
    left join public.notifications n
      on n.recipient_id = tu.user_id
     and n.status = 'unread'
     and n.category = c.category
    group by tu.user_id, c.category
  ),
  existing as (
    select d.user_id, d.category, d.unread_count, coalesce(c.unread_count, 0) as current_count
    from desired d
    left join public.notification_unread_counters c
      on c.user_id = d.user_id
     and c.category = d.category
  ),
  upserted as (
    insert into public.notification_unread_counters (
      user_id,
      category,
      unread_count,
      counter_version,
      reconciled_at,
      updated_at
    )
    select
      user_id,
      category,
      unread_count,
      1,
      now(),
      now()
    from existing
    on conflict (user_id, category) do update
    set
      unread_count = excluded.unread_count,
      counter_version = public.notification_unread_counters.counter_version + 1,
      reconciled_at = now(),
      updated_at = now()
    returning user_id, category
  )
  select
    count(distinct user_id)::integer,
    count(*) filter (where unread_count <> current_count)::integer,
    coalesce(max(abs(unread_count - current_count)), 0)::integer
  into v_users, v_drifted, v_max_drift
  from existing;

  v_duration := greatest(0, (extract(epoch from clock_timestamp() - v_started_at) * 1000)::integer);

  insert into public.notification_counter_reconciliation_runs (
    ok,
    sampled_user_count,
    drifted_user_count,
    max_absolute_drift,
    duration_ms
  )
  values (true, v_users, v_drifted, v_max_drift, v_duration);

  return jsonb_build_object(
    'ok', true,
    'sampledUserCount', v_users,
    'driftedUserCount', v_drifted,
    'maxAbsoluteDrift', v_max_drift,
    'durationMs', v_duration
  );
exception
  when others then
    v_duration := greatest(0, (extract(epoch from clock_timestamp() - v_started_at) * 1000)::integer);
    insert into public.notification_counter_reconciliation_runs (
      ok,
      sampled_user_count,
      drifted_user_count,
      max_absolute_drift,
      duration_ms,
      error_message
    )
    values (false, 0, 0, 0, v_duration, left(sqlerrm, 500));
    return jsonb_build_object('ok', false, 'error', sqlerrm, 'durationMs', v_duration);
end;
$reconcile_notification_unread_counters$;

create or replace function public.sync_conversation_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $sync_conversation_last_message$
declare
  v_recipient_ids jsonb;
begin
  if new.deleted_at is not null then
    return new;
  end if;

  update public.conversations
  set
    last_message_id = new.id,
    last_message_at = new.created_at,
    last_message_preview = public.messaging_message_preview(new.body, new.message_type)
  where id = new.conversation_id
    and (
      last_message_at is null
      or new.created_at >= last_message_at
    );

  insert into public.notifications (
    recipient_id,
    actor_id,
    conversation_id,
    message_id,
    aggregate_type,
    aggregate_id,
    category,
    priority,
    event_type,
    title,
    body,
    deeplink,
    template_key,
    template_version,
    dedupe_key,
    channels,
    payload
  )
  select
    cp.user_id,
    new.sender_id,
    new.conversation_id,
    new.id,
    'message',
    new.id,
    'message',
    'high',
    'message_received',
    'New message',
    public.messaging_message_preview(new.body, new.message_type),
    '/messages/' || new.conversation_id::text,
    'message.received',
    1,
    'message:' || new.id::text || ':recipient:' || cp.user_id::text,
    array['in_app', 'realtime']::text[],
    jsonb_build_object(
      'conversationId', new.conversation_id,
      'messageId', new.id,
      'messageSeq', new.message_seq,
      'preview', public.messaging_message_preview(new.body, new.message_type)
    )
  from public.conversation_participants cp
  where cp.conversation_id = new.conversation_id
    and cp.user_id <> new.sender_id
    and cp.muted_until is distinct from 'infinity'::timestamptz;

  select coalesce(jsonb_agg(cp.user_id::text), '[]'::jsonb)
  into v_recipient_ids
  from public.conversation_participants cp
  where cp.conversation_id = new.conversation_id
    and cp.user_id <> new.sender_id
    and cp.muted_until is distinct from 'infinity'::timestamptz;

  if jsonb_array_length(v_recipient_ids) > 0 then
    perform public.create_notification_event(
      p_event_type := 'message_received',
      p_aggregate_type := 'message',
      p_aggregate_id := new.id,
      p_actor_id := new.sender_id,
      p_recipient_selector := jsonb_build_object(
        'type', 'users',
        'userIds', v_recipient_ids
      ),
      p_category := 'message',
      p_priority := 'high',
      p_channels := array['in_app', 'realtime', 'push']::text[],
      p_template_key := 'message.received',
      p_template_version := 1,
      p_payload := jsonb_build_object(
        'title', 'New message',
        'body', public.messaging_message_preview(new.body, new.message_type),
        'conversationId', new.conversation_id,
        'messageId', new.id,
        'messageSeq', new.message_seq,
        'deeplink', '/messages/' || new.conversation_id::text
      ),
      p_idempotency_key := 'message:' || new.id::text || ':notification-event',
      p_dedupe_key := 'message:' || new.id::text,
      p_trace_id := 'message:' || new.id::text,
      p_shadow := true
    );
  end if;

  return new;
end;
$sync_conversation_last_message$;

create or replace function public.enqueue_booking_notification(
  p_booking public.bookings,
  p_recipient_id uuid,
  p_actor_id uuid,
  p_event_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $enqueue_booking_notification$
declare
  v_title text := case
    when p_event_type = 'host_booking_requested' then 'New booking request'
    when p_event_type = 'booking_auto_approved' then 'Booking approved'
    when p_event_type = 'booking_approved' then 'Booking approved'
    when p_event_type = 'booking_rejected' then 'Booking rejected'
    when p_event_type = 'booking_expired' then 'Booking expired'
    else 'Booking update'
  end;
begin
  insert into public.notification_outbox (
    recipient_id,
    actor_id,
    booking_id,
    event_type,
    payload
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_booking.id,
    p_event_type,
    jsonb_build_object(
      'bookingId', p_booking.id,
      'spotId', p_booking.space_id,
      'status', p_booking.status,
      'startAt', p_booking.start_at,
      'endAt', p_booking.end_at
    )
  );

  perform public.create_notification_event(
    p_event_type := p_event_type,
    p_aggregate_type := 'booking',
    p_aggregate_id := p_booking.id,
    p_actor_id := p_actor_id,
    p_recipient_selector := jsonb_build_object(
      'type', 'users',
      'userIds', jsonb_build_array(p_recipient_id::text)
    ),
    p_category := 'booking',
    p_priority := case when p_event_type = 'host_booking_requested' then 'high' else 'normal' end,
    p_channels := array['in_app', 'realtime', 'push', 'email']::text[],
    p_template_key := 'booking.lifecycle',
    p_template_version := 1,
    p_payload := jsonb_build_object(
      'title', v_title,
      'body', 'Your parking booking status is ' || p_booking.status,
      'bookingId', p_booking.id,
      'spotId', p_booking.space_id,
      'status', p_booking.status,
      'startAt', p_booking.start_at,
      'endAt', p_booking.end_at,
      'deeplink', '/profile/booking-requests'
    ),
    p_idempotency_key := 'booking:' || p_booking.id::text || ':' || p_event_type || ':' || p_recipient_id::text,
    p_dedupe_key := 'booking:' || p_booking.id::text || ':' || p_event_type,
    p_trace_id := 'booking:' || p_booking.id::text,
    p_shadow := true
  );
end;
$enqueue_booking_notification$;

insert into public.notification_templates (
  template_key,
  version,
  status,
  category,
  title_template,
  body_template,
  deeplink_template,
  default_channels,
  activated_at
)
values
  (
    'message.received',
    1,
    'active',
    'message',
    'New message',
    '{{body}}',
    '/messages/{{conversationId}}',
    array['in_app', 'realtime', 'push']::text[],
    now()
  ),
  (
    'booking.lifecycle',
    1,
    'active',
    'booking',
    '{{title}}',
    '{{body}}',
    '{{deeplink}}',
    array['in_app', 'realtime', 'push', 'email']::text[],
    now()
  ),
  (
    'admin.announcement',
    1,
    'active',
    'admin',
    '{{title}}',
    '{{body}}',
    '{{deeplink}}',
    array['in_app', 'realtime', 'push']::text[],
    now()
  )
on conflict (template_key, version) do nothing;

alter table public.notification_events enable row level security;
alter table public.notification_events force row level security;
alter table public.notification_fanout_jobs enable row level security;
alter table public.notification_fanout_jobs force row level security;
alter table public.notification_delivery_jobs enable row level security;
alter table public.notification_delivery_jobs force row level security;
alter table public.notification_delivery_logs enable row level security;
alter table public.notification_delivery_logs force row level security;
alter table public.notification_dead_letters enable row level security;
alter table public.notification_dead_letters force row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_preferences force row level security;
alter table public.notification_devices enable row level security;
alter table public.notification_devices force row level security;
alter table public.notification_templates enable row level security;
alter table public.notification_templates force row level security;
alter table public.notification_unread_counters enable row level security;
alter table public.notification_unread_counters force row level security;
alter table public.notification_counter_reconciliation_runs enable row level security;
alter table public.notification_counter_reconciliation_runs force row level security;
alter table public.notification_audit_logs enable row level security;
alter table public.notification_audit_logs force row level security;

drop policy if exists "notification_events_no_client_access" on public.notification_events;
create policy "notification_events_no_client_access"
on public.notification_events
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "notification_fanout_jobs_no_client_access" on public.notification_fanout_jobs;
create policy "notification_fanout_jobs_no_client_access"
on public.notification_fanout_jobs
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "notification_delivery_jobs_no_client_access" on public.notification_delivery_jobs;
create policy "notification_delivery_jobs_no_client_access"
on public.notification_delivery_jobs
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "notification_delivery_logs_no_client_access" on public.notification_delivery_logs;
create policy "notification_delivery_logs_no_client_access"
on public.notification_delivery_logs
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "notification_dead_letters_no_client_access" on public.notification_dead_letters;
create policy "notification_dead_letters_no_client_access"
on public.notification_dead_letters
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "notification_preferences_select_own" on public.notification_preferences;
create policy "notification_preferences_select_own"
on public.notification_preferences
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notification_preferences_update_own" on public.notification_preferences;
create policy "notification_preferences_update_own"
on public.notification_preferences
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "notification_devices_select_own" on public.notification_devices;
create policy "notification_devices_select_own"
on public.notification_devices
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notification_devices_update_own" on public.notification_devices;
create policy "notification_devices_update_own"
on public.notification_devices
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "notification_templates_select_active" on public.notification_templates;
create policy "notification_templates_select_active"
on public.notification_templates
for select
to authenticated
using (status in ('active', 'deprecated'));

drop policy if exists "notification_unread_counters_select_own" on public.notification_unread_counters;
create policy "notification_unread_counters_select_own"
on public.notification_unread_counters
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notification_counter_reconciliation_runs_no_client_access" on public.notification_counter_reconciliation_runs;
create policy "notification_counter_reconciliation_runs_no_client_access"
on public.notification_counter_reconciliation_runs
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "notification_audit_logs_no_client_access" on public.notification_audit_logs;
create policy "notification_audit_logs_no_client_access"
on public.notification_audit_logs
for all
to anon, authenticated
using (false)
with check (false);

revoke all on table public.notification_events from anon, authenticated;
revoke all on table public.notification_fanout_jobs from anon, authenticated;
revoke all on table public.notification_delivery_jobs from anon, authenticated;
revoke all on table public.notification_delivery_logs from anon, authenticated;
revoke all on table public.notification_dead_letters from anon, authenticated;
revoke all on table public.notification_preferences from anon, authenticated;
revoke all on table public.notification_devices from anon, authenticated;
revoke all on table public.notification_templates from anon, authenticated;
revoke all on table public.notification_unread_counters from anon, authenticated;
revoke all on table public.notification_counter_reconciliation_runs from anon, authenticated;
revoke all on table public.notification_audit_logs from anon, authenticated;

grant select on table public.notification_preferences to authenticated;
grant select on table public.notification_devices to authenticated;
grant select on table public.notification_templates to authenticated;
grant select on table public.notification_unread_counters to authenticated;

revoke all on function public.create_notification_event(
  text, text, uuid, uuid, jsonb, text, text, text[], text, integer, jsonb, text, text, timestamptz, text, boolean
) from public;
revoke all on function public.list_notifications(integer, timestamptz, uuid, text, text) from public;
revoke all on function public.sync_notifications(timestamptz, uuid, integer) from public;
revoke all on function public.mark_notifications_read(uuid, text) from public;
revoke all on function public.reconcile_notification_unread_counters(uuid) from public;
revoke all on function public.claim_notification_fanout_jobs(text, integer) from public;
revoke all on function public.claim_notification_delivery_jobs(text, integer) from public;

grant execute on function public.list_notifications(integer, timestamptz, uuid, text, text) to authenticated;
grant execute on function public.sync_notifications(timestamptz, uuid, integer) to authenticated;
grant execute on function public.mark_notifications_read(uuid, text) to authenticated;
grant execute on function public.create_notification_event(
  text, text, uuid, uuid, jsonb, text, text, text[], text, integer, jsonb, text, text, timestamptz, text, boolean
) to service_role;
grant execute on function public.reconcile_notification_unread_counters(uuid) to service_role;
grant execute on function public.claim_notification_fanout_jobs(text, integer) to service_role;
grant execute on function public.claim_notification_delivery_jobs(text, integer) to service_role;

do $notification_realtime_publication$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notification_unread_counters'
  ) then
    alter publication supabase_realtime add table public.notification_unread_counters;
  end if;
end;
$notification_realtime_publication$;

comment on table public.notification_events is
  'Canonical globally idempotent notification event log. Kept unpartitioned so Postgres can enforce a true unique idempotency key; delivery/audit attempts are monthly partitioned.';
comment on table public.notification_fanout_jobs is
  'Bounded fanout work queue. Large audiences are expanded asynchronously by worker batches instead of domain transactions.';
comment on table public.notification_delivery_jobs is
  'Per-channel delivery queue. External providers are best-effort and idempotent where the provider supports it.';
comment on table public.notification_unread_counters is
  'Postgres source of truth for unread badges. Redis may cache these values but reconciliation writes back here.';
comment on table public.notification_templates is
  'Immutable versioned notification templates. Notifications snapshot rendered copy at creation time.';

notify pgrst, 'reload schema';
