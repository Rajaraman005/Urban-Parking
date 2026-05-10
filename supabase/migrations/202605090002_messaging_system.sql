create extension if not exists pgcrypto;

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  conversation_key text not null unique,
  conversation_type text not null check (conversation_type in ('property', 'support', 'system')),
  property_id uuid references public.parking_spaces(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'locked', 'closed')),
  last_message_id uuid,
  last_message_at timestamptz,
  last_message_preview text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'renter', 'admin', 'support')),
  joined_at timestamptz not null default now(),
  last_read_message_seq bigint not null default 0 check (last_read_message_seq >= 0),
  last_read_at timestamptz,
  archived_at timestamptz,
  muted_until timestamptz,
  deleted_after timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  message_seq bigint generated always as identity,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  client_message_id uuid not null,
  client_payload_hash text not null,
  message_type text not null default 'text' check (
    message_type in ('text', 'attachment', 'property_card', 'system')
  ),
  body text,
  metadata jsonb not null default '{}'::jsonb,
  reply_to_message_id uuid references public.messages(id) on delete set null,
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint messages_body_length_check check (body is null or char_length(body) <= 5000),
  constraint messages_body_required_for_text_check check (
    message_type <> 'text' or nullif(btrim(coalesce(body, '')), '') is not null
  ),
  unique (sender_id, client_message_id)
);

do $conversations_last_message_fk$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'conversations_last_message_id_fkey'
      and conrelid = 'public.conversations'::regclass
  ) then
    alter table public.conversations
    add constraint conversations_last_message_id_fkey
    foreign key (last_message_id)
    references public.messages(id)
    on delete set null;
  end if;
end;
$conversations_last_message_fk$;

create table if not exists public.message_reads (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_message_seq bigint not null check (read_message_seq >= 0),
  read_at timestamptz not null default now(),
  unique (conversation_id, user_id, message_id)
);

create table if not exists public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  uploader_id uuid not null references auth.users(id) on delete cascade,
  storage_bucket text not null default 'message-attachments',
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0 and byte_size <= 26214400),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  status text not null default 'reserved' check (
    status in (
      'reserved',
      'uploaded',
      'scanning',
      'available',
      'rejected',
      'scan_failed_retryable',
      'expired'
    )
  ),
  moderation_reason text,
  scan_started_at timestamptz,
  scan_completed_at timestamptz,
  expires_at timestamptz not null default now() + interval '30 minutes',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'offline' check (status in ('online', 'away', 'offline')),
  last_seen_at timestamptz not null default now(),
  device_count integer not null default 0 check (device_count >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.typing_status (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  typing_until timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint blocks_no_self_check check (blocker_id <> blocked_id)
);

create unique index if not exists blocks_active_pair_idx
on public.blocks (blocker_id, blocked_id)
where deleted_at is null;

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  reason text not null check (
    reason in ('spam', 'harassment', 'fraud', 'unsafe_content', 'other')
  ),
  details text,
  evidence jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (
    status in ('open', 'reviewing', 'resolved', 'dismissed')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete cascade,
  message_id uuid references public.messages(id) on delete cascade,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'unread' check (
    status in ('unread', 'read', 'dismissed')
  ),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists conversation_participants_user_updated_idx
on public.conversation_participants (user_id, archived_at, updated_at desc);

create index if not exists conversations_last_message_idx
on public.conversations (coalesce(last_message_at, updated_at) desc, id desc)
where deleted_at is null;

create index if not exists conversations_property_idx
on public.conversations (property_id, updated_at desc)
where conversation_type = 'property' and deleted_at is null;

create index if not exists messages_conversation_seq_visible_idx
on public.messages (conversation_id, message_seq desc)
where deleted_at is null;

create index if not exists messages_sender_client_idx
on public.messages (sender_id, client_message_id);

create index if not exists message_reads_user_read_idx
on public.message_reads (user_id, read_at desc);

create index if not exists message_attachments_message_idx
on public.message_attachments (message_id, status);

create index if not exists message_attachments_cleanup_idx
on public.message_attachments (status, expires_at, id)
where status in ('reserved', 'uploaded', 'scanning', 'scan_failed_retryable');

create index if not exists typing_status_expiry_idx
on public.typing_status (typing_until);

create index if not exists reports_status_created_idx
on public.reports (status, created_at desc);

create index if not exists notifications_recipient_status_created_idx
on public.notifications (recipient_id, status, created_at desc);

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
before update on public.conversations
for each row
execute function public.set_updated_at();

drop trigger if exists conversation_participants_set_updated_at on public.conversation_participants;
create trigger conversation_participants_set_updated_at
before update on public.conversation_participants
for each row
execute function public.set_updated_at();

drop trigger if exists messages_set_updated_at on public.messages;
create trigger messages_set_updated_at
before update on public.messages
for each row
execute function public.set_updated_at();

drop trigger if exists message_attachments_set_updated_at on public.message_attachments;
create trigger message_attachments_set_updated_at
before update on public.message_attachments
for each row
execute function public.set_updated_at();

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
before update on public.reports
for each row
execute function public.set_updated_at();

drop trigger if exists notifications_set_updated_at on public.notifications;
create trigger notifications_set_updated_at
before update on public.notifications
for each row
execute function public.set_updated_at();

create or replace function public.is_conversation_participant(
  p_conversation_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $is_conversation_participant$
  select exists (
    select 1
    from public.conversation_participants cp
    join public.conversations c on c.id = cp.conversation_id
    where cp.conversation_id = p_conversation_id
      and cp.user_id = p_user_id
      and c.deleted_at is null
  );
$is_conversation_participant$;

create or replace function public.are_users_blocked(p_left_user_id uuid, p_right_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $are_users_blocked$
  select exists (
    select 1
    from public.blocks b
    where b.deleted_at is null
      and (
        (b.blocker_id = p_left_user_id and b.blocked_id = p_right_user_id)
        or (b.blocker_id = p_right_user_id and b.blocked_id = p_left_user_id)
      )
  );
$are_users_blocked$;

create or replace function public.property_conversation_key(
  p_property_id uuid,
  p_user_a uuid,
  p_user_b uuid
)
returns text
language sql
immutable
set search_path = public
as $property_conversation_key$
  select 'property:'
    || p_property_id::text
    || ':users:'
    || least(p_user_a::text, p_user_b::text)
    || ':'
    || greatest(p_user_a::text, p_user_b::text)
    || ':v1';
$property_conversation_key$;

create or replace function public.messaging_message_preview(
  p_body text,
  p_message_type text
)
returns text
language sql
immutable
as $messaging_message_preview$
  select left(
    case
      when p_message_type = 'attachment' then 'Attachment'
      when p_message_type = 'property_card' then 'Property shared'
      when nullif(btrim(coalesce(p_body, '')), '') is null then 'Message'
      else regexp_replace(btrim(p_body), '\s+', ' ', 'g')
    end,
    180
  );
$messaging_message_preview$;

create or replace function public.message_to_json(
  p_message public.messages,
  p_viewer_id uuid default auth.uid()
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $message_to_json$
  select jsonb_build_object(
    'id', p_message.id,
    'conversationId', p_message.conversation_id,
    'messageSeq', p_message.message_seq,
    'senderId', p_message.sender_id,
    'clientMessageId', p_message.client_message_id,
    'messageType', p_message.message_type,
    'body', p_message.body,
    'metadata', p_message.metadata,
    'replyToMessageId', p_message.reply_to_message_id,
    'createdAt', p_message.created_at,
    'updatedAt', p_message.updated_at,
    'editedAt', p_message.edited_at,
    'deletedAt', p_message.deleted_at,
    'isMine', p_message.sender_id = p_viewer_id,
    'readByOther', exists (
      select 1
      from public.conversation_participants cp
      where cp.conversation_id = p_message.conversation_id
        and cp.user_id <> p_message.sender_id
        and cp.last_read_message_seq >= p_message.message_seq
    ),
    'attachments', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', ma.id,
          'fileName', ma.file_name,
          'mimeType', ma.mime_type,
          'byteSize', ma.byte_size,
          'width', ma.width,
          'height', ma.height,
          'status', ma.status,
          'storageBucket', ma.storage_bucket,
          'storagePath',
            case
              when ma.status = 'available' or ma.uploader_id = p_viewer_id
                then ma.storage_path
              else null
            end,
          'createdAt', ma.created_at,
          'updatedAt', ma.updated_at
        )
        order by ma.created_at asc
      )
      from public.message_attachments ma
      where ma.message_id = p_message.id
    ), '[]'::jsonb)
  );
$message_to_json$;

create or replace function public.conversation_to_json(
  p_conversation_id uuid,
  p_viewer_id uuid default auth.uid()
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $conversation_to_json$
  with participant as (
    select *
    from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id = p_viewer_id
    limit 1
  ),
  other_participant as (
    select cp.*
    from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id <> p_viewer_id
    order by cp.joined_at asc
    limit 1
  ),
  property_photo as (
    select psp.secure_url
    from public.conversations c
    join public.parking_space_photos psp on psp.parking_space_id = c.property_id
    where c.id = p_conversation_id
      and psp.upload_status = 'linked'
      and nullif(btrim(psp.secure_url), '') is not null
    order by psp.sort_order asc, psp.created_at asc
    limit 1
  )
  select jsonb_build_object(
    'id', c.id,
    'conversationKey', c.conversation_key,
    'conversationType', c.conversation_type,
    'propertyId', c.property_id,
    'propertyTitle', ps.title,
    'propertyAddress', ps.address,
    'propertyLocality', ps.locality,
    'propertyImageUrl', property_photo.secure_url,
    'status', c.status,
    'lastMessageId', c.last_message_id,
    'lastMessageAt', c.last_message_at,
    'lastMessagePreview', c.last_message_preview,
    'createdAt', c.created_at,
    'updatedAt', c.updated_at,
    'participantRole', participant.role,
    'lastReadMessageSeq', participant.last_read_message_seq,
    'archivedAt', participant.archived_at,
    'deletedAfter', participant.deleted_after,
    'otherUserId', other_participant.user_id,
    'otherName', nullif(btrim(op.full_name), ''),
    'otherAvatarUrl', nullif(btrim(op.avatar_url), ''),
    'otherPresenceStatus', coalesce(up.status, 'offline'),
    'otherLastSeenAt', up.last_seen_at,
    'unreadCount', (
      select count(*)::integer
      from public.messages m
      where m.conversation_id = c.id
        and m.message_seq > coalesce(participant.last_read_message_seq, 0)
        and m.sender_id <> p_viewer_id
        and m.deleted_at is null
        and (
          participant.deleted_after is null
          or m.created_at > participant.deleted_after
        )
    )
  )
  from public.conversations c
  join participant on true
  left join other_participant on true
  left join public.profiles op on op.id = other_participant.user_id
  left join public.user_presence up on up.user_id = other_participant.user_id
  left join public.parking_spaces ps on ps.id = c.property_id
  left join property_photo on true
  where c.id = p_conversation_id
    and c.deleted_at is null;
$conversation_to_json$;

create or replace function public.sync_conversation_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $sync_conversation_last_message$
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
    event_type,
    payload
  )
  select
    cp.user_id,
    new.sender_id,
    new.conversation_id,
    new.id,
    'message_received',
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

  return new;
end;
$sync_conversation_last_message$;

drop trigger if exists messages_sync_conversation_last_message on public.messages;
create trigger messages_sync_conversation_last_message
after insert on public.messages
for each row
execute function public.sync_conversation_last_message();

create or replace function public.start_or_get_property_conversation(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $start_or_get_property_conversation$
declare
  v_user_id uuid := auth.uid();
  v_property public.parking_spaces;
  v_key text;
  v_conversation public.conversations;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
  into v_property
  from public.parking_spaces
  where id = p_property_id
    and status = 'active'
  for share;

  if not found then
    raise exception 'Property was not found' using errcode = 'P0002';
  end if;

  if v_property.host_id = v_user_id then
    raise exception 'Hosts cannot message themselves about their own listing' using errcode = '42501';
  end if;

  if public.are_users_blocked(v_user_id, v_property.host_id) then
    raise exception 'Messaging is unavailable between these users' using errcode = '42501';
  end if;

  v_key := public.property_conversation_key(p_property_id, v_user_id, v_property.host_id);

  insert into public.conversations (
    conversation_key,
    conversation_type,
    property_id,
    created_by,
    status
  )
  values (
    v_key,
    'property',
    p_property_id,
    v_user_id,
    'active'
  )
  on conflict (conversation_key) do update
  set updated_at = public.conversations.updated_at
  returning *
  into v_conversation;

  insert into public.conversation_participants (
    conversation_id,
    user_id,
    role,
    archived_at,
    deleted_after
  )
  values
    (v_conversation.id, v_user_id, 'renter', null, null),
    (v_conversation.id, v_property.host_id, 'owner', null, null)
  on conflict (conversation_id, user_id) do update
  set
    archived_at = null,
    deleted_after = null;

  return public.conversation_to_json(v_conversation.id, v_user_id);
end;
$start_or_get_property_conversation$;

create or replace function public.list_conversations(
  p_limit integer default 20,
  p_before_last_message_at timestamptz default null,
  p_before_id uuid default null
)
returns setof jsonb
language sql
security definer
set search_path = public
as $list_conversations$
  select public.conversation_to_json(c.id, auth.uid())
  from public.conversation_participants cp
  join public.conversations c on c.id = cp.conversation_id
  where cp.user_id = auth.uid()
    and c.deleted_at is null
    and (
      p_before_last_message_at is null
      or (
        coalesce(c.last_message_at, c.updated_at),
        c.id
      ) < (
        p_before_last_message_at,
        coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)
      )
    )
  order by coalesce(c.last_message_at, c.updated_at) desc, c.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$list_conversations$;

create or replace function public.list_conversation_messages(
  p_conversation_id uuid,
  p_limit integer default 50,
  p_before_message_seq bigint default null
)
returns setof jsonb
language sql
security definer
set search_path = public
as $list_conversation_messages$
  select public.message_to_json(m, auth.uid())
  from public.messages m
  join public.conversation_participants cp
    on cp.conversation_id = m.conversation_id
   and cp.user_id = auth.uid()
  where m.conversation_id = p_conversation_id
    and m.deleted_at is null
    and (
      p_before_message_seq is null
      or m.message_seq < p_before_message_seq
    )
    and (
      cp.deleted_after is null
      or m.created_at > cp.deleted_after
    )
  order by m.message_seq desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$list_conversation_messages$;

create or replace function public.send_message(
  p_conversation_id uuid,
  p_client_message_id uuid,
  p_body text,
  p_message_type text default 'text',
  p_metadata jsonb default '{}'::jsonb,
  p_reply_to_message_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $send_message$
declare
  v_user_id uuid := auth.uid();
  v_conversation public.conversations;
  v_existing public.messages;
  v_message public.messages;
  v_payload_hash text;
  v_other_user_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_message_type not in ('text', 'attachment', 'property_card') then
    raise exception 'Invalid message type' using errcode = '23514';
  end if;

  if p_message_type = 'text' and nullif(btrim(coalesce(p_body, '')), '') is null then
    raise exception 'Message text is required' using errcode = '23514';
  end if;

  if char_length(coalesce(p_body, '')) > 5000 then
    raise exception 'Message is too long' using errcode = '23514';
  end if;

  select *
  into v_conversation
  from public.conversations
  where id = p_conversation_id
    and deleted_at is null
  for share;

  if not found or not public.is_conversation_participant(p_conversation_id, v_user_id) then
    raise exception 'Conversation was not found' using errcode = 'P0002';
  end if;

  if v_conversation.status <> 'active' then
    raise exception 'Conversation is not active' using errcode = '23514';
  end if;

  select cp.user_id
  into v_other_user_id
  from public.conversation_participants cp
  where cp.conversation_id = p_conversation_id
    and cp.user_id <> v_user_id
  order by cp.joined_at asc
  limit 1;

  if v_other_user_id is not null and public.are_users_blocked(v_user_id, v_other_user_id) then
    raise exception 'Messaging is unavailable between these users' using errcode = '42501';
  end if;

  v_payload_hash := encode(
    digest(
      convert_to(
        jsonb_build_object(
          'conversationId', p_conversation_id,
          'body', coalesce(p_body, ''),
          'messageType', p_message_type,
          'metadata', coalesce(p_metadata, '{}'::jsonb),
          'replyToMessageId', p_reply_to_message_id
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  select *
  into v_existing
  from public.messages
  where sender_id = v_user_id
    and client_message_id = p_client_message_id
  limit 1;

  if found then
    if v_existing.client_payload_hash <> v_payload_hash then
      raise exception 'Client message id reused with a different payload'
        using errcode = '23505';
    end if;
    return public.message_to_json(v_existing, v_user_id);
  end if;

  insert into public.messages (
    conversation_id,
    sender_id,
    client_message_id,
    client_payload_hash,
    message_type,
    body,
    metadata,
    reply_to_message_id
  )
  values (
    p_conversation_id,
    v_user_id,
    p_client_message_id,
    v_payload_hash,
    p_message_type,
    nullif(btrim(coalesce(p_body, '')), ''),
    coalesce(p_metadata, '{}'::jsonb),
    p_reply_to_message_id
  )
  returning *
  into v_message;

  update public.conversation_participants
  set archived_at = null
  where conversation_id = p_conversation_id
    and user_id = v_user_id;

  return public.message_to_json(v_message, v_user_id);
end;
$send_message$;

create or replace function public.mark_conversation_read(
  p_conversation_id uuid,
  p_last_seen_message_seq bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $mark_conversation_read$
declare
  v_user_id uuid := auth.uid();
  v_participant public.conversation_participants;
  v_next_seq bigint;
  v_message public.messages;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
  into v_participant
  from public.conversation_participants
  where conversation_id = p_conversation_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'Conversation was not found' using errcode = 'P0002';
  end if;

  select coalesce(p_last_seen_message_seq, max(message_seq), v_participant.last_read_message_seq)
  into v_next_seq
  from public.messages
  where conversation_id = p_conversation_id
    and deleted_at is null;

  update public.conversation_participants
  set
    last_read_message_seq = greatest(coalesce(last_read_message_seq, 0), coalesce(v_next_seq, 0)),
    last_read_at = now()
  where conversation_id = p_conversation_id
    and user_id = v_user_id
  returning *
  into v_participant;

  select *
  into v_message
  from public.messages
  where conversation_id = p_conversation_id
    and message_seq <= v_participant.last_read_message_seq
    and sender_id <> v_user_id
    and deleted_at is null
  order by message_seq desc
  limit 1;

  if found then
    insert into public.message_reads (
      conversation_id,
      message_id,
      user_id,
      read_message_seq,
      read_at
    )
    values (
      p_conversation_id,
      v_message.id,
      v_user_id,
      v_participant.last_read_message_seq,
      now()
    )
    on conflict (conversation_id, user_id, message_id) do update
    set
      read_message_seq = greatest(
        public.message_reads.read_message_seq,
        excluded.read_message_seq
      ),
      read_at = excluded.read_at;
  end if;

  return jsonb_build_object(
    'conversationId', p_conversation_id,
    'lastReadMessageSeq', v_participant.last_read_message_seq,
    'lastReadAt', v_participant.last_read_at
  );
end;
$mark_conversation_read$;

create or replace function public.archive_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $archive_conversation$
declare
  v_user_id uuid := auth.uid();
begin
  update public.conversation_participants
  set archived_at = now()
  where conversation_id = p_conversation_id
    and user_id = v_user_id;

  if not found then
    raise exception 'Conversation was not found' using errcode = 'P0002';
  end if;

  return public.conversation_to_json(p_conversation_id, v_user_id);
end;
$archive_conversation$;

create or replace function public.delete_conversation_for_me(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $delete_conversation_for_me$
declare
  v_user_id uuid := auth.uid();
begin
  update public.conversation_participants
  set
    deleted_after = now(),
    archived_at = now()
  where conversation_id = p_conversation_id
    and user_id = v_user_id;

  if not found then
    raise exception 'Conversation was not found' using errcode = 'P0002';
  end if;

  return public.conversation_to_json(p_conversation_id, v_user_id);
end;
$delete_conversation_for_me$;

create or replace function public.create_message_attachment_slot(
  p_conversation_id uuid,
  p_message_id uuid,
  p_file_name text,
  p_mime_type text,
  p_byte_size bigint,
  p_width integer default null,
  p_height integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $create_message_attachment_slot$
declare
  v_user_id uuid := auth.uid();
  v_message public.messages;
  v_attachment public.message_attachments;
  v_safe_name text;
  v_recent_uploads integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.is_conversation_participant(p_conversation_id, v_user_id) then
    raise exception 'Conversation was not found' using errcode = 'P0002';
  end if;

  select *
  into v_message
  from public.messages
  where id = p_message_id
    and conversation_id = p_conversation_id
    and sender_id = v_user_id
    and deleted_at is null;

  if not found then
    raise exception 'Message was not found' using errcode = 'P0002';
  end if;

  if p_byte_size is null or p_byte_size <= 0 or p_byte_size > 26214400 then
    raise exception 'Attachment size is invalid' using errcode = '23514';
  end if;

  if lower(p_mime_type) not in (
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'application/pdf',
    'text/plain'
  ) then
    raise exception 'Attachment type is not allowed' using errcode = '23514';
  end if;

  select count(*)
  into v_recent_uploads
  from public.message_attachments
  where uploader_id = v_user_id
    and created_at >= now() - interval '1 day';

  if v_recent_uploads >= 100 then
    raise exception 'Daily attachment limit reached' using errcode = '23514';
  end if;

  v_safe_name := regexp_replace(
    lower(coalesce(nullif(btrim(p_file_name), ''), 'attachment')),
    '[^a-z0-9._-]+',
    '-',
    'g'
  );
  v_safe_name := left(nullif(v_safe_name, ''), 120);

  insert into public.message_attachments (
    conversation_id,
    message_id,
    uploader_id,
    storage_path,
    file_name,
    mime_type,
    byte_size,
    width,
    height,
    status
  )
  values (
    p_conversation_id,
    p_message_id,
    v_user_id,
    p_conversation_id::text || '/' || p_message_id::text || '/' || gen_random_uuid()::text || '/' || v_safe_name,
    v_safe_name,
    lower(p_mime_type),
    p_byte_size,
    p_width,
    p_height,
    'reserved'
  )
  returning *
  into v_attachment;

  return jsonb_build_object(
    'id', v_attachment.id,
    'conversationId', v_attachment.conversation_id,
    'messageId', v_attachment.message_id,
    'storageBucket', v_attachment.storage_bucket,
    'storagePath', v_attachment.storage_path,
    'status', v_attachment.status,
    'expiresAt', v_attachment.expires_at
  );
end;
$create_message_attachment_slot$;

create or replace function public.complete_message_attachment_upload(p_attachment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $complete_message_attachment_upload$
declare
  v_user_id uuid := auth.uid();
  v_attachment public.message_attachments;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.message_attachments
  set
    status = 'scanning',
    scan_started_at = now()
  where id = p_attachment_id
    and uploader_id = v_user_id
    and status in ('reserved', 'uploaded')
    and expires_at > now()
  returning *
  into v_attachment;

  if not found then
    raise exception 'Attachment upload was not found' using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'id', v_attachment.id,
    'status', v_attachment.status,
    'scanStartedAt', v_attachment.scan_started_at,
    'scanSlaSeconds', 30,
    'scanHardTimeoutSeconds', 300
  );
end;
$complete_message_attachment_upload$;

create or replace function public.mark_message_attachment_scan_result(
  p_attachment_id uuid,
  p_status text,
  p_reason text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $mark_message_attachment_scan_result$
declare
  v_attachment public.message_attachments;
begin
  if p_status not in ('available', 'rejected', 'scan_failed_retryable') then
    raise exception 'Invalid scan result' using errcode = '23514';
  end if;

  update public.message_attachments
  set
    status = p_status,
    moderation_reason = nullif(btrim(p_reason), ''),
    metadata = coalesce(metadata, '{}'::jsonb) || coalesce(p_metadata, '{}'::jsonb),
    scan_completed_at = now()
  where id = p_attachment_id
    and status in ('scanning', 'scan_failed_retryable')
  returning *
  into v_attachment;

  if not found then
    raise exception 'Attachment was not found' using errcode = 'P0002';
  end if;

  return jsonb_build_object('id', v_attachment.id, 'status', v_attachment.status);
end;
$mark_message_attachment_scan_result$;

create or replace function public.expire_stale_message_attachment_slots(
  p_batch_size integer default 500
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $expire_stale_message_attachment_slots$
declare
  v_batch_size integer := least(greatest(coalesce(p_batch_size, 500), 1), 5000);
  v_expired_count integer;
begin
  with candidates as (
    select id
    from public.message_attachments
    where status in ('reserved', 'uploaded')
      and expires_at <= now()
    order by expires_at asc, id asc
    limit v_batch_size
    for update skip locked
  ),
  updated as (
    update public.message_attachments ma
    set status = 'expired'
    from candidates c
    where ma.id = c.id
    returning ma.id
  )
  select count(*)::integer
  into v_expired_count
  from updated;

  update public.message_attachments
  set
    status = 'scan_failed_retryable',
    moderation_reason = 'scan_timeout',
    scan_completed_at = now()
  where status = 'scanning'
    and scan_started_at <= now() - interval '5 minutes';

  return jsonb_build_object(
    'ok', true,
    'expiredCount', v_expired_count,
    'batchSize', v_batch_size
  );
end;
$expire_stale_message_attachment_slots$;

create or replace function public.set_typing_status(
  p_conversation_id uuid,
  p_is_typing boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $set_typing_status$
declare
  v_user_id uuid := auth.uid();
  v_until timestamptz;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.is_conversation_participant(p_conversation_id, v_user_id) then
    raise exception 'Conversation was not found' using errcode = 'P0002';
  end if;

  if coalesce(p_is_typing, false) then
    v_until := now() + interval '8 seconds';
    insert into public.typing_status (conversation_id, user_id, typing_until)
    values (p_conversation_id, v_user_id, v_until)
    on conflict (conversation_id, user_id) do update
    set
      typing_until = excluded.typing_until,
      updated_at = now();
  else
    delete from public.typing_status
    where conversation_id = p_conversation_id
      and user_id = v_user_id;
    v_until := now();
  end if;

  return jsonb_build_object(
    'conversationId', p_conversation_id,
    'typingUntil', v_until
  );
end;
$set_typing_status$;

create or replace function public.cleanup_expired_typing_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $cleanup_expired_typing_status$
declare
  v_deleted integer;
begin
  delete from public.typing_status
  where typing_until <= now();

  get diagnostics v_deleted = row_count;
  return jsonb_build_object('ok', true, 'deletedCount', v_deleted);
end;
$cleanup_expired_typing_status$;

create or replace function public.set_user_presence(
  p_status text,
  p_device_count integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $set_user_presence$
declare
  v_user_id uuid := auth.uid();
  v_presence public.user_presence;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_status not in ('online', 'away', 'offline') then
    raise exception 'Invalid presence status' using errcode = '23514';
  end if;

  insert into public.user_presence (
    user_id,
    status,
    device_count,
    last_seen_at,
    updated_at
  )
  values (
    v_user_id,
    p_status,
    greatest(coalesce(p_device_count, 0), 0),
    now(),
    now()
  )
  on conflict (user_id) do update
  set
    status = excluded.status,
    device_count = excluded.device_count,
    last_seen_at = excluded.last_seen_at,
    updated_at = excluded.updated_at
  returning *
  into v_presence;

  return jsonb_build_object(
    'userId', v_presence.user_id,
    'status', v_presence.status,
    'lastSeenAt', v_presence.last_seen_at
  );
end;
$set_user_presence$;

create or replace function public.block_user(
  p_blocked_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $block_user$
declare
  v_user_id uuid := auth.uid();
  v_block public.blocks;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_blocked_id = v_user_id then
    raise exception 'You cannot block yourself' using errcode = '23514';
  end if;

  insert into public.blocks (blocker_id, blocked_id, reason)
  values (v_user_id, p_blocked_id, nullif(btrim(p_reason), ''))
  on conflict (blocker_id, blocked_id)
  where deleted_at is null
  do update
  set reason = excluded.reason
  returning *
  into v_block;

  return jsonb_build_object(
    'id', v_block.id,
    'blockedId', v_block.blocked_id,
    'createdAt', v_block.created_at
  );
end;
$block_user$;

create or replace function public.report_message(
  p_conversation_id uuid,
  p_message_id uuid,
  p_reason text,
  p_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $report_message$
declare
  v_user_id uuid := auth.uid();
  v_message public.messages;
  v_report public.reports;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_reason not in ('spam', 'harassment', 'fraud', 'unsafe_content', 'other') then
    raise exception 'Invalid report reason' using errcode = '23514';
  end if;

  if not public.is_conversation_participant(p_conversation_id, v_user_id) then
    raise exception 'Conversation was not found' using errcode = 'P0002';
  end if;

  select *
  into v_message
  from public.messages
  where id = p_message_id
    and conversation_id = p_conversation_id;

  if not found then
    raise exception 'Message was not found' using errcode = 'P0002';
  end if;

  insert into public.reports (
    reporter_id,
    reported_user_id,
    conversation_id,
    message_id,
    reason,
    details,
    evidence
  )
  values (
    v_user_id,
    v_message.sender_id,
    p_conversation_id,
    p_message_id,
    p_reason,
    nullif(btrim(p_details), ''),
    public.message_to_json(v_message, v_user_id)
  )
  returning *
  into v_report;

  return jsonb_build_object('id', v_report.id, 'status', v_report.status);
end;
$report_message$;

alter table public.conversations enable row level security;
alter table public.conversations force row level security;
alter table public.conversation_participants enable row level security;
alter table public.conversation_participants force row level security;
alter table public.messages enable row level security;
alter table public.messages force row level security;
alter table public.message_reads enable row level security;
alter table public.message_reads force row level security;
alter table public.message_attachments enable row level security;
alter table public.message_attachments force row level security;
alter table public.user_presence enable row level security;
alter table public.user_presence force row level security;
alter table public.typing_status enable row level security;
alter table public.typing_status force row level security;
alter table public.blocks enable row level security;
alter table public.blocks force row level security;
alter table public.reports enable row level security;
alter table public.reports force row level security;
alter table public.notifications enable row level security;
alter table public.notifications force row level security;

drop policy if exists "conversations_select_participant" on public.conversations;
create policy "conversations_select_participant"
on public.conversations
for select
to authenticated
using (public.is_conversation_participant(id, auth.uid()));

drop policy if exists "conversation_participants_select_same_conversation" on public.conversation_participants;
create policy "conversation_participants_select_same_conversation"
on public.conversation_participants
for select
to authenticated
using (public.is_conversation_participant(conversation_id, auth.uid()));

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant"
on public.messages
for select
to authenticated
using (public.is_conversation_participant(conversation_id, auth.uid()));

drop policy if exists "message_reads_select_participant" on public.message_reads;
create policy "message_reads_select_participant"
on public.message_reads
for select
to authenticated
using (public.is_conversation_participant(conversation_id, auth.uid()));

drop policy if exists "message_attachments_select_participant" on public.message_attachments;
create policy "message_attachments_select_participant"
on public.message_attachments
for select
to authenticated
using (public.is_conversation_participant(conversation_id, auth.uid()));

drop policy if exists "user_presence_select_authenticated" on public.user_presence;
create policy "user_presence_select_authenticated"
on public.user_presence
for select
to authenticated
using (true);

drop policy if exists "typing_status_select_participant" on public.typing_status;
create policy "typing_status_select_participant"
on public.typing_status
for select
to authenticated
using (public.is_conversation_participant(conversation_id, auth.uid()));

drop policy if exists "blocks_select_own" on public.blocks;
create policy "blocks_select_own"
on public.blocks
for select
to authenticated
using (auth.uid() = blocker_id or auth.uid() = blocked_id);

drop policy if exists "reports_select_own" on public.reports;
create policy "reports_select_own"
on public.reports
for select
to authenticated
using (auth.uid() = reporter_id);

drop policy if exists "notifications_select_recipient" on public.notifications;
create policy "notifications_select_recipient"
on public.notifications
for select
to authenticated
using (auth.uid() = recipient_id);

drop policy if exists "notifications_update_recipient" on public.notifications;
create policy "notifications_update_recipient"
on public.notifications
for update
to authenticated
using (auth.uid() = recipient_id)
with check (auth.uid() = recipient_id);

revoke all on table public.conversations from anon, authenticated;
revoke all on table public.conversation_participants from anon, authenticated;
revoke all on table public.messages from anon, authenticated;
revoke all on table public.message_reads from anon, authenticated;
revoke all on table public.message_attachments from anon, authenticated;
revoke all on table public.user_presence from anon, authenticated;
revoke all on table public.typing_status from anon, authenticated;
revoke all on table public.blocks from anon, authenticated;
revoke all on table public.reports from anon, authenticated;
revoke all on table public.notifications from anon, authenticated;

grant select on table public.conversations to authenticated;
grant select on table public.conversation_participants to authenticated;
grant select on table public.messages to authenticated;
grant select on table public.message_reads to authenticated;
grant select on table public.message_attachments to authenticated;
grant select on table public.user_presence to authenticated;
grant select on table public.typing_status to authenticated;
grant select on table public.blocks to authenticated;
grant select on table public.reports to authenticated;
grant select, update (status, read_at, updated_at) on table public.notifications to authenticated;

revoke all on function public.is_conversation_participant(uuid, uuid) from public;
revoke all on function public.are_users_blocked(uuid, uuid) from public;
revoke all on function public.property_conversation_key(uuid, uuid, uuid) from public;
revoke all on function public.start_or_get_property_conversation(uuid) from public;
revoke all on function public.list_conversations(integer, timestamptz, uuid) from public;
revoke all on function public.list_conversation_messages(uuid, integer, bigint) from public;
revoke all on function public.send_message(uuid, uuid, text, text, jsonb, uuid) from public;
revoke all on function public.mark_conversation_read(uuid, bigint) from public;
revoke all on function public.archive_conversation(uuid) from public;
revoke all on function public.delete_conversation_for_me(uuid) from public;
revoke all on function public.create_message_attachment_slot(uuid, uuid, text, text, bigint, integer, integer) from public;
revoke all on function public.complete_message_attachment_upload(uuid) from public;
revoke all on function public.set_typing_status(uuid, boolean) from public;
revoke all on function public.set_user_presence(text, integer) from public;
revoke all on function public.block_user(uuid, text) from public;
revoke all on function public.report_message(uuid, uuid, text, text) from public;
revoke all on function public.expire_stale_message_attachment_slots(integer) from public;
revoke all on function public.cleanup_expired_typing_status() from public;
revoke all on function public.mark_message_attachment_scan_result(uuid, text, text, jsonb) from public;

grant execute on function public.start_or_get_property_conversation(uuid) to authenticated;
grant execute on function public.list_conversations(integer, timestamptz, uuid) to authenticated;
grant execute on function public.list_conversation_messages(uuid, integer, bigint) to authenticated;
grant execute on function public.send_message(uuid, uuid, text, text, jsonb, uuid) to authenticated;
grant execute on function public.mark_conversation_read(uuid, bigint) to authenticated;
grant execute on function public.archive_conversation(uuid) to authenticated;
grant execute on function public.delete_conversation_for_me(uuid) to authenticated;
grant execute on function public.create_message_attachment_slot(uuid, uuid, text, text, bigint, integer, integer) to authenticated;
grant execute on function public.complete_message_attachment_upload(uuid) to authenticated;
grant execute on function public.set_typing_status(uuid, boolean) to authenticated;
grant execute on function public.set_user_presence(text, integer) to authenticated;
grant execute on function public.block_user(uuid, text) to authenticated;
grant execute on function public.report_message(uuid, uuid, text, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'message-attachments',
  'message-attachments',
  false,
  26214400,
  array[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'application/pdf',
    'text/plain'
  ]
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "message_attachments_storage_select_available" on storage.objects;
create policy "message_attachments_storage_select_available"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'message-attachments'
  and exists (
    select 1
    from public.message_attachments ma
    where ma.storage_bucket = bucket_id
      and ma.storage_path = name
      and ma.status = 'available'
      and public.is_conversation_participant(ma.conversation_id, auth.uid())
  )
);

drop policy if exists "message_attachments_storage_insert_reserved" on storage.objects;
create policy "message_attachments_storage_insert_reserved"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'message-attachments'
  and exists (
    select 1
    from public.message_attachments ma
    where ma.storage_bucket = bucket_id
      and ma.storage_path = name
      and ma.uploader_id = auth.uid()
      and ma.status = 'reserved'
      and ma.expires_at > now()
  )
);

do $messaging_realtime_publication$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'conversations'
    ) then
      alter publication supabase_realtime add table public.conversations;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'conversation_participants'
    ) then
      alter publication supabase_realtime add table public.conversation_participants;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'messages'
    ) then
      alter publication supabase_realtime add table public.messages;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'message_reads'
    ) then
      alter publication supabase_realtime add table public.message_reads;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'message_attachments'
    ) then
      alter publication supabase_realtime add table public.message_attachments;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'typing_status'
    ) then
      alter publication supabase_realtime add table public.typing_status;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'notifications'
    ) then
      alter publication supabase_realtime add table public.notifications;
    end if;
  end if;
end;
$messaging_realtime_publication$;

comment on table public.conversations is
  'Canonical messaging conversations. Property conversations use deterministic property/user-pair keys to prevent duplicate threads under concurrent starts.';
comment on table public.conversation_participants is
  'Participant-local messaging state. Unread counts are derived from messages.message_seq and last_read_message_seq, never stored as mutable counters.';
comment on table public.message_attachments is
  'Private Supabase Storage-backed attachment lifecycle. Recipients can open files only after async scanning marks them available.';
comment on index public.messages_conversation_seq_visible_idx is
  'Critical unread/pagination index. Production readiness requires EXPLAIN ANALYZE on list_conversations unread lateral counts at 10x expected volume.';
comment on function public.mark_conversation_read(uuid, bigint) is
  'Monotonic read marker with FOR UPDATE row lock to prevent multi-device read races.';
comment on function public.start_or_get_property_conversation(uuid) is
  'Concurrency-idempotent property conversation starter using canonical conversation_key and ON CONFLICT DO UPDATE RETURNING.';

notify pgrst, 'reload schema';
