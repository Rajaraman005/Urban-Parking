alter table public.profiles
add column if not exists avatar_public_id text;

create table if not exists public.profile_avatar_uploads (
  upload_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  public_id text not null,
  secure_url text,
  status text not null default 'signed' check (
    status in ('signed', 'uploaded', 'completed', 'failed', 'cleanup_pending')
  ),
  sequence bigint not null check (sequence > 0),
  completion_attempt_count integer not null default 0 check (completion_attempt_count >= 0),
  signature_timestamp integer not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, public_id)
);

create table if not exists public.avatar_cleanup_queue (
  id uuid primary key default gen_random_uuid(),
  public_id text not null unique,
  reason text not null,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profile_avatar_uploads_user_created_idx
on public.profile_avatar_uploads (user_id, created_at desc);

create index if not exists profile_avatar_uploads_user_sequence_idx
on public.profile_avatar_uploads (user_id, sequence desc);

create index if not exists profile_avatar_uploads_cleanup_idx
on public.profile_avatar_uploads (status, expires_at)
where status in ('signed', 'uploaded', 'failed', 'cleanup_pending');

create index if not exists avatar_cleanup_queue_due_idx
on public.avatar_cleanup_queue (next_attempt_at, updated_at);

drop trigger if exists profile_avatar_uploads_set_updated_at on public.profile_avatar_uploads;
create trigger profile_avatar_uploads_set_updated_at
before update on public.profile_avatar_uploads
for each row
execute function public.set_updated_at();

drop trigger if exists avatar_cleanup_queue_set_updated_at on public.avatar_cleanup_queue;
create trigger avatar_cleanup_queue_set_updated_at
before update on public.avatar_cleanup_queue
for each row
execute function public.set_updated_at();

alter table public.profile_avatar_uploads enable row level security;
alter table public.profile_avatar_uploads force row level security;

alter table public.avatar_cleanup_queue enable row level security;
alter table public.avatar_cleanup_queue force row level security;

drop policy if exists "profile_avatar_uploads_select_own" on public.profile_avatar_uploads;
create policy "profile_avatar_uploads_select_own"
on public.profile_avatar_uploads
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.profile_avatar_uploads from anon;
revoke all on table public.profile_avatar_uploads from authenticated;
grant select on table public.profile_avatar_uploads to authenticated;

revoke all on table public.avatar_cleanup_queue from anon;
revoke all on table public.avatar_cleanup_queue from authenticated;

revoke update (avatar_url) on table public.profiles from authenticated;
revoke update (avatar_public_id) on table public.profiles from authenticated;

comment on column public.profiles.avatar_public_id is
  'Cloudinary public ID for the current profile avatar. Written only by trusted avatar completion functions.';

comment on table public.profile_avatar_uploads is
  'Idempotency and race-safety ledger for signed profile avatar uploads.';

comment on table public.avatar_cleanup_queue is
  'Retryable Cloudinary asset cleanup queue for stale, orphaned, or replaced profile avatars.';
