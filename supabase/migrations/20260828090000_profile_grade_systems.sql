-- Stage 6-7 profile: support two climbing grade systems (V Scale and YDS) plus
-- a separate optional YDS grade. The existing regular_grade smallint remains
-- the V Scale value; when grade_system = 'YDS' the yds_grade text is the source
-- of truth and regular_grade is left null.

alter table public.profiles
  add column grade_system text,
  add column yds_grade text;

-- grade_system is one of 'V' or 'YDS', or null when not supplied.
alter table public.profiles
  add constraint profiles_grade_system_check
  check (grade_system is null or grade_system in ('V', 'YDS'));

-- yds_grade must be a well-formed YDS value when present (for example 5.0 to
-- 5.15+). We keep the check loose enough to allow future sub-grades.
alter table public.profiles
  add constraint profiles_yds_grade_check
  check (
    yds_grade is null
    or yds_grade ~ '^5\.[0-9]+([a-d]|\+)?$'
  );

-- Consistency: a YDS grade is only meaningful when the selected system is YDS,
-- and the V Scale value is only meaningful when the selected system is V.
alter table public.profiles
  add constraint profiles_grade_system_consistency
  check (
    (grade_system = 'YDS' and yds_grade is not null and regular_grade is null)
    or (grade_system = 'V' and regular_grade is not null and yds_grade is null)
    or (grade_system is null and regular_grade is null and yds_grade is null)
  );

comment on column public.profiles.grade_system is
  'Chosen grade system: V Scale (V) or YDS. Null when the user has not supplied a regular grade.';
comment on column public.profiles.yds_grade is
  'YDS regular grade (for example 5.10a). Only set when grade_system is YDS.';
