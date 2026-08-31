-- Allow authenticated users to update their grade system preferences.
grant update (grade_system, yds_grade) on public.profiles to authenticated;
