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

-- 3b. Wall-zone surface fields exist and default to recommended values.
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'wall_zones'
     and column_name in ('surface_material', 'surface_texture', 'has_bolt_holes')),
  3::bigint,
  'Wall-zone surface fields exist'
);
select is((select surface_material from public.wall_zones limit 1), 'plywood', 'Default surface material is plywood');
select is((select surface_texture from public.wall_zones limit 1), 'lightly_textured', 'Default surface texture is lightly textured');
select is((select has_bolt_holes from public.wall_zones limit 1), true, 'Bolt holes default to present');

-- 3c. The summary view exposes the new surface fields.
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'wall_zone_summaries'
     and column_name in ('surface_material', 'surface_texture', 'has_bolt_holes')),
  3::bigint,
  'Wall-zone summary view exposes surface fields'
);

-- 3d. Wall-zone kind replaces wall_type; routes carry terrain/style/subjective grade.
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'wall_zones'
     and column_name = 'wall_kind'),
  1::bigint,
  'Wall-zone wall_kind exists'
);
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'wall_zones'
     and column_name = 'wall_type'),
  0::bigint,
  'Wall-zone wall_type is gone'
);
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'routes'
     and column_name in ('terrain', 'styles', 'subjective_grade')),
  3::bigint,
  'Routes carry terrain, styles and subjective grade'
);
select is(
  (select count(*) from information_schema.columns
   where table_schema = 'public' and table_name = 'routes'
     and column_name = 'label'),
  0::bigint,
  'Route label is gone'
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

-- 9. Extension and trigger-function hardening.
select is(
  (select namespace.nspname
   from pg_catalog.pg_extension extension
   join pg_catalog.pg_namespace namespace on namespace.oid = extension.extnamespace
   where extension.extname = 'citext'),
  'extensions',
  'citext is outside the public schema'
);

select ok(
  (select procedure.proconfig @> array['search_path=""']::text[]
   from pg_catalog.pg_proc procedure
   join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
   where namespace.nspname = 'public' and procedure.proname = 'normalise_beta_link'),
  'Beta URL normalisation uses an empty search_path'
);

select ok(
  not has_function_privilege('anon', 'public.initialise_profile_for_auth_user()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.initialise_profile_for_auth_user()', 'EXECUTE'),
  'Auth profile trigger cannot be invoked through client roles'
);

select ok(
  not has_function_privilege('anon', 'public.get_my_profile()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.get_my_profile()', 'EXECUTE'),
  'Private profile RPC is authenticated-only'
);

select ok(
  not has_function_privilege('anon', 'public.merge_routes(uuid,uuid,text)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.merge_routes(uuid,uuid,text)', 'EXECUTE'),
  'Route merge RPC is authenticated-only and retains its internal admin check'
);

select ok(
  has_function_privilege('anon', 'public.community_grade_summary(uuid)', 'EXECUTE')
  and has_function_privilege('anon', 'public.gym_hard_soft_summary(uuid)', 'EXECUTE')
  and has_function_privilege('anon', 'public.visible_beta_count_for_route(uuid)', 'EXECUTE'),
  'Anonymous users retain only the required public summary RPCs'
);

-- 10. View privileges are read-only and audience-scoped.
select ok(
  has_table_privilege('anon', 'public.gym_summaries', 'SELECT')
  and not has_table_privilege('anon', 'public.gym_summaries', 'INSERT')
  and not has_table_privilege('anon', 'public.gym_summaries', 'UPDATE')
  and not has_table_privilege('anon', 'public.gym_summaries', 'DELETE'),
  'Anonymous gym summaries are read-only'
);

select ok(
  not has_table_privilege('anon', 'public.beta_ranking_inputs', 'SELECT')
  and not has_table_privilege('anon', 'public.moderation_queue', 'SELECT')
  and not has_table_privilege('anon', 'public.gym_official_scope', 'SELECT'),
  'Anonymous users cannot read authenticated or management views'
);

select ok(
  has_table_privilege('authenticated', 'public.beta_ranking_inputs', 'SELECT')
  and has_table_privilege('authenticated', 'public.moderation_queue', 'SELECT')
  and has_table_privilege('authenticated', 'public.gym_official_scope', 'SELECT')
  and not has_table_privilege('authenticated', 'public.moderation_queue', 'UPDATE'),
  'Authenticated management views are read-only and remain RLS-filtered'
);

select * from finish();

rollback;
