-- Application profiles and server-controlled roles.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext not null,
  avatar_path text,
  height_cm numeric(5,1),
  arm_span_cm numeric(5,1),
  regular_grade smallint,
  favourite_gym_id uuid,
  is_trusted_contributor boolean not null default false,
  trusted_contributor_awarded_at timestamptz,
  helpful_received_count integer not null default 0,
  age_confirmed_16_plus_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint profiles_username_length check (char_length(username::text) between 3 and 30),
  constraint profiles_avatar_path_length check (avatar_path is null or char_length(avatar_path) <= 512),
  constraint profiles_height_range check (height_cm is null or height_cm between 100 and 250),
  constraint profiles_arm_span_range check (arm_span_cm is null or arm_span_cm between 100 and 280),
  constraint profiles_regular_grade_range check (regular_grade is null or regular_grade between -1 and 17),
  constraint profiles_helpful_nonnegative check (helpful_received_count >= 0),
  constraint profiles_trust_award_consistent check (
    (is_trusted_contributor and trusted_contributor_awarded_at is not null)
    or (not is_trusted_contributor)
  )
);

create unique index profiles_username_unique_active
  on public.profiles (lower(username::text))
  where deleted_at is null;

create table public.app_user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (user_id, role)
);

create or replace function public.has_app_role(required_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_user_roles roles
    where roles.user_id = auth.uid()
      and roles.role = required_role
      and roles.revoked_at is null
  );
$$;

create or replace function public.is_admin_or_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_app_role('admin'::public.app_role)
      or public.has_app_role('moderator'::public.app_role);
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_app_role('admin'::public.app_role);
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

revoke all on function public.has_app_role(public.app_role) from public;
revoke all on function public.is_admin_or_moderator() from public;
revoke all on function public.is_admin() from public;
grant execute on function public.has_app_role(public.app_role) to authenticated;
grant execute on function public.is_admin_or_moderator() to authenticated;
grant execute on function public.is_admin() to authenticated;

comment on table public.profiles is
  'App profile keyed by auth.users. Email and provider identifiers never live here.';
comment on column public.profiles.age_confirmed_16_plus_at is
  'Timestamp of the user self-declaration; no birth date is stored.';
