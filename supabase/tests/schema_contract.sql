-- Run only against a disposable local Supabase database after migrations and seed.
begin;

do $$
declare
  table_name text;
  threshold_vote_count integer;
  threshold_eligible boolean;
  threshold_median smallint;
  private_vote_count integer;
  private_eligible boolean;
  private_median smallint;
  expected_tables text[] := array[
    'profiles', 'app_user_roles', 'gyms', 'gym_facilities', 'gym_memberships',
    'wall_zones', 'routes', 'gym_reset_patterns', 'reset_events',
    'reset_confirmations', 'route_photos', 'route_photo_helpful_votes',
    'beta_links', 'beta_helpful_votes', 'beta_comments', 'logbook_entries',
    'route_grade_votes', 'route_corrections', 'route_removal_reports',
    'route_merge_suggestions', 'content_reports', 'moderation_actions',
    'favourite_gyms', 'user_follows', 'user_blocks',
    'notification_preferences', 'notification_outbox', 'gym_claims',
    'app_feedback'
  ];
begin
  foreach table_name in array expected_tables loop
    if not exists (
      select 1
      from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = table_name
        and c.relrowsecurity
    ) then
      raise exception 'Expected RLS-enabled table public.%', table_name;
    end if;

    if not exists (
      select 1 from pg_catalog.pg_policies
      where schemaname = 'public' and tablename = table_name
    ) then
      raise exception 'Expected at least one policy on public.%', table_name;
    end if;
  end loop;

  if exists (
    select 1
    from pg_catalog.pg_tables
    where schemaname = 'public' and tablename ilike '%video%'
  ) then
    raise exception 'Video tables are excluded from the BlocLens data contract';
  end if;

  if (select count(*) from public.gyms where data_source = 'development_fixture') <> 3 then
    raise exception 'Expected three development gyms';
  end if;
  if (select count(*) from public.wall_zones) <> 9 then
    raise exception 'Expected nine development wall zones';
  end if;
  if (select count(*) from public.routes) <> 27 then
    raise exception 'Expected twenty-seven development routes';
  end if;
  if (select count(*) from public.beta_links) <> 6 then
    raise exception 'Expected six development beta links';
  end if;

  select vote_count, is_display_eligible, median_v_grade
  into threshold_vote_count, threshold_eligible, threshold_median
  from public.community_grade_summary('30000000-0000-4000-8000-000000000001');
  if threshold_vote_count <> 3 or not threshold_eligible or threshold_median <> 3 then
    raise exception 'Expected the three-vote route to expose median V3';
  end if;

  select vote_count, is_display_eligible, median_v_grade
  into private_vote_count, private_eligible, private_median
  from public.community_grade_summary('30000000-0000-4000-8000-000000000002');
  if private_vote_count <> 2 or private_eligible or private_median is not null then
    raise exception 'Expected the two-vote route to hide its median';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('public_profiles', 'gym_summaries', 'route_summaries')
      and column_name = 'private_note'
  ) then
    raise exception 'A public view exposes a private Logbook note';
  end if;
end;
$$;

rollback;
