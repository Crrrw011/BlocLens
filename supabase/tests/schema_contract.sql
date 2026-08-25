-- pgTAP contract test for the BlocLens local schema.
-- Run by `supabase test db` (pg_prove) against the disposable local database
-- after migrations and seed. Assertions fail loudly; none mask or weaken RLS.
create extension if not exists pgtap;

begin;

select no_plan();

-- 1. Every client-facing business table has RLS enabled and at least one policy.
select is(
  (select count(*) from unnest(array[
    'profiles', 'app_user_roles', 'gyms', 'gym_facilities', 'gym_memberships',
    'wall_zones', 'routes', 'gym_reset_patterns', 'reset_events',
    'reset_confirmations', 'route_photos', 'route_photo_helpful_votes',
    'beta_links', 'beta_helpful_votes', 'beta_comments', 'logbook_entries',
    'route_grade_votes', 'route_corrections', 'route_removal_reports',
    'route_merge_suggestions', 'content_reports', 'moderation_actions',
    'favourite_gyms', 'user_follows', 'user_blocks',
    'notification_preferences', 'notification_outbox', 'gym_claims',
    'app_feedback'
  ]::text[]) as t(name)
  where not exists (
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = t.name and c.relrowsecurity
  )),
  0::bigint,
  'All 29 client-facing business tables have RLS enabled'
);

select is(
  (select count(*) from unnest(array[
    'profiles', 'app_user_roles', 'gyms', 'gym_facilities', 'gym_memberships',
    'wall_zones', 'routes', 'gym_reset_patterns', 'reset_events',
    'reset_confirmations', 'route_photos', 'route_photo_helpful_votes',
    'beta_links', 'beta_helpful_votes', 'beta_comments', 'logbook_entries',
    'route_grade_votes', 'route_corrections', 'route_removal_reports',
    'route_merge_suggestions', 'content_reports', 'moderation_actions',
    'favourite_gyms', 'user_follows', 'user_blocks',
    'notification_preferences', 'notification_outbox', 'gym_claims',
    'app_feedback'
  ]::text[]) as t(name)
  where not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = t.name
  )),
  0::bigint,
  'All 29 client-facing business tables have at least one RLS policy'
);

-- 2. No video storage surfaces.
select is(
  (select count(*) from information_schema.tables
   where table_schema = 'public' and table_name ilike '%video%'),
  0::bigint,
  'No video table exists'
);
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and column_name ilike '%video%'),
  0::bigint,
  'No video column exists'
);

-- 3. No wall-zone geometry or indoor-navigation model.
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'wall_zones'
     and column_name ~* 'geometry|polygon|hotspot|floor_plan|coordinate_[xy]'),
  0::bigint,
  'No wall-zone geometry columns exist'
);

-- 4. Development fixture cardinality.
select is((select count(*) from public.gyms where data_source = 'development_fixture'), 3::bigint, 'Three development gyms seeded');
select is((select count(*) from public.wall_zones), 9::bigint, 'Nine development wall zones seeded');
select is((select count(*) from public.routes), 27::bigint, 'Twenty-seven development routes seeded');
select is((select count(*) from public.beta_links), 6::bigint, 'Six development beta links seeded');

-- 5. Community grade threshold behaviour (median only at three distinct votes).
select is(
  (select vote_count from public.community_grade_summary('30000000-0000-4000-8000-000000000001')),
  3::integer,
  'Three-vote route reports three votes'
);
select is(
  (select is_display_eligible from public.community_grade_summary('30000000-0000-4000-8000-000000000001')),
  true,
  'Three-vote route is display-eligible'
);
select is(
  (select median_v_grade from public.community_grade_summary('30000000-0000-4000-8000-000000000001')),
  3::smallint,
  'Three-vote route median is V3'
);
select is(
  (select vote_count from public.community_grade_summary('30000000-0000-4000-8000-000000000002')),
  2::integer,
  'Two-vote route reports two votes'
);
select is(
  (select is_display_eligible from public.community_grade_summary('30000000-0000-4000-8000-000000000002')),
  false,
  'Two-vote route is not display-eligible'
);
select is(
  (select median_v_grade from public.community_grade_summary('30000000-0000-4000-8000-000000000002')),
  null,
  'Two-vote route hides its median'
);

-- 6. Public projections leak no private, reporter, block or moderation columns.
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public'
     and table_name in (
       'public_profiles', 'gym_summaries', 'wall_zone_summaries',
       'route_summaries', 'beta_ranking_inputs', 'reset_summaries'
     )
     and column_name ~* 'email|private_note|reporter|reported_by|block|penalt|restriction|helpful_received|awarded_at|favourite|age_confirmed|provider'),
  0::bigint,
  'Public views expose no sensitive or private columns'
);

-- 7. All eight read surfaces are security_invoker.
select is(
  (select count(*) from unnest(array[
    'public_profiles', 'gym_summaries', 'wall_zone_summaries', 'route_summaries',
    'beta_ranking_inputs', 'reset_summaries', 'moderation_queue', 'gym_official_scope'
  ]::text[]) as v(name)
  where not exists (
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = v.name and c.relkind = 'v'
      and c.reloptions @> array['security_invoker=true']::text[]
  )),
  0::bigint,
  'All eight views are security_invoker'
);

-- 8. Every SECURITY DEFINER function declares an empty search_path.
select is(
  (select count(*) from pg_catalog.pg_proc p
   join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and (p.proconfig is null or not (p.proconfig @> array['search_path=""']::text[]))),
  0::bigint,
  'SECURITY DEFINER functions declare an empty search_path'
);

select * from finish();

rollback;
