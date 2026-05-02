alter table public.profiles
add column if not exists gender text check (gender in ('male', 'female', 'other', 'prefer_not_to_say')),
add column if not exists dob date;

comment on column public.profiles.gender is 'User gender choice (male, female, other, prefer_not_to_say)';
comment on column public.profiles.dob is 'Date of birth of the user';

grant update (gender, dob) on table public.profiles to authenticated;
