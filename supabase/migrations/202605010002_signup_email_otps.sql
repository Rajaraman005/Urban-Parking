alter table public.profiles
add column if not exists email_verified_at timestamptz;

create table if not exists public.signup_email_otps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  otp_hash text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  locked_at timestamptz,
  failed_attempts integer not null default 0 check (failed_attempts >= 0 and failed_attempts <= 5),
  resend_count integer not null default 0 check (resend_count >= 0),
  request_ip inet,
  device_fingerprint text,
  created_at timestamptz not null default now()
);

create index if not exists signup_email_otps_user_created_idx
on public.signup_email_otps (user_id, created_at desc);

create index if not exists signup_email_otps_email_created_idx
on public.signup_email_otps (lower(email), created_at desc);

create index if not exists signup_email_otps_device_created_idx
on public.signup_email_otps (device_fingerprint, created_at desc)
where device_fingerprint is not null;

create index if not exists signup_email_otps_ip_created_idx
on public.signup_email_otps (request_ip, created_at desc)
where request_ip is not null;

alter table public.signup_email_otps enable row level security;
alter table public.signup_email_otps force row level security;

revoke all on table public.signup_email_otps from anon;
revoke all on table public.signup_email_otps from authenticated;

comment on column public.profiles.email_verified_at is
  'Urban Parking app-level email verification timestamp set by trusted signup OTP flow.';

comment on table public.signup_email_otps is
  'Service-role-only signup OTP records. OTP values are hashed with a server-side pepper before storage.';
