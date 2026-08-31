drop function if exists public.get_my_profile();

create function public.get_my_profile()
returns table (
  id uuid,
  username citext,
  avatar_path text,
  height_cm numeric,
  arm_span_cm numeric,
  regular_grade smallint,
  grade_system text,
  yds_grade text,
  favourite_gym_id uuid,
  is_trusted_contributor boolean,
  trusted_contributor_awarded_at timestamptz,
  helpful_received_count integer,
  age_confirmed_16_plus_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.id, profile.username, profile.avatar_path, profile.height_cm,
    profile.arm_span_cm, profile.regular_grade, profile.grade_system, profile.yds_grade, profile.favourite_gym_id,
    profile.is_trusted_contributor, profile.trusted_contributor_awarded_at,
    profile.helpful_received_count, profile.age_confirmed_16_plus_at,
    profile.created_at, profile.updated_at
  from public.profiles profile
  where profile.id = auth.uid() and profile.deleted_at is null;
$$;

revoke all on function public.get_my_profile() from public;
grant execute on function public.get_my_profile() to authenticated;
