-- pgTAP: client access hardening for beta data.
-- Run by `supabase test db` against the disposable local database after
-- migrations 0001-0011 and seed. Privilege assertions run as the connecting
-- superuser via has_*_privilege; behavioural assertions switch role and capture
-- row counts into temp tables before asserting as the superuser.
create extension if not exists pgtap;

begin;

select no_plan();

-- Anonymous privilege boundary -------------------------------------------------

select ok(
  not has_table_privilege('anon', 'public.beta_links', 'SELECT'),
  'anon lacks SELECT on beta_links'
);
select ok(
  not has_table_privilege('anon', 'public.beta_ranking_inputs', 'SELECT'),
  'anon lacks SELECT on beta_ranking_inputs'
);
select ok(
  not has_column_privilege('anon', 'public.beta_links', 'public_url', 'SELECT'),
  'anon cannot read public_url'
);
select ok(
  not has_column_privilege('anon', 'public.beta_links', 'original_post_url', 'SELECT'),
  'anon cannot read original_post_url'
);
select ok(
  not has_column_privilege('anon', 'public.beta_links', 'platform', 'SELECT'),
  'anon cannot read beta platform metadata'
);
select ok(
  not has_column_privilege('anon', 'public.beta_links', 'original_author_display_name', 'SELECT'),
  'anon cannot read beta author metadata'
);

-- Anonymous keeps public discovery surfaces --------------------------------

select ok(has_table_privilege('anon', 'public.gyms', 'SELECT'), 'anon can read gyms');
select ok(has_table_privilege('anon', 'public.wall_zones', 'SELECT'), 'anon can read wall zones');
select ok(has_table_privilege('anon', 'public.routes', 'SELECT'), 'anon can read routes');
select ok(has_table_privilege('anon', 'public.route_summaries', 'SELECT'), 'anon can read route summaries');
select ok(has_table_privilege('anon', 'public.gym_summaries', 'SELECT'), 'anon can read gym summaries');
select ok(has_table_privilege('anon', 'public.wall_zone_summaries', 'SELECT'), 'anon can read wall zone summaries');
select ok(
  has_function_privilege('anon', 'public.visible_beta_count_for_route(uuid)'::regprocedure, 'EXECUTE'),
  'anon can read the beta count helper'
);

-- Anonymous behavioural results ------------------------------------------

set local role anon;
create temp table _t_anon_gyms as select count(*) as c from public.gyms;
create temp table _t_anon_zones as select count(*) as c from public.wall_zones;
create temp table _t_anon_routes as select count(*) as c from public.route_summaries;
reset role;

select is((select c from _t_anon_gyms), 3::bigint, 'anon reads three gyms');
select is((select c from _t_anon_zones), 9::bigint, 'anon reads nine wall zones');
select is((select c from _t_anon_routes), 26::bigint, 'anon reads 26 visible route summaries');

-- Beta count exposes no URL and excludes hidden beta -----------------------

select is(
  public.visible_beta_count_for_route('30000000-0000-4000-8000-000000000001'),
  3,
  'route beta count is three (hidden beta excluded)'
);

-- Authenticated boundary ---------------------------------------------------

select ok(has_table_privilege('authenticated', 'public.beta_links', 'SELECT'), 'authenticated keeps beta_links select');
select ok(has_table_privilege('authenticated', 'public.beta_ranking_inputs', 'SELECT'), 'authenticated keeps beta_ranking_inputs select');
select ok(has_table_privilege('authenticated', 'public.beta_links', 'INSERT'), 'authenticated keeps beta_links insert');
select ok(has_table_privilege('authenticated', 'public.beta_comments', 'INSERT'), 'authenticated keeps beta_comments insert');
select ok(has_table_privilege('authenticated', 'public.route_photos', 'INSERT'), 'authenticated keeps route_photos insert');
select ok(has_table_privilege('authenticated', 'public.beta_helpful_votes', 'INSERT'), 'authenticated keeps beta_helpful_votes insert');

-- Authenticated behavioural results ---------------------------------------

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _t_auth_beta as select count(*) as c from public.beta_ranking_inputs;
create temp table _t_auth_hidden as
  select count(*) as c from public.beta_links where id = '40000000-0000-4000-8000-000000000004';
create temp table _t_auth_logbook as select count(*) as c from public.logbook_entries;
create temp table _t_auth_other_logbook as
  select count(*) as c from public.logbook_entries where user_id <> '90000000-0000-4000-8000-000000000001';
reset role;

select is((select c from _t_auth_beta), 5::bigint, 'authenticated reads five visible beta links');
select is((select c from _t_auth_hidden), 0::bigint, 'authenticated cannot read hidden beta');
select is((select c from _t_auth_logbook), 2::bigint, 'authenticated reads only own logbook');
select is((select c from _t_auth_other_logbook), 0::bigint, 'authenticated cannot read another users logbook');

-- Wall zone creation: signed-in user may add their own zone and read it back ----------

select ok(
  has_table_privilege('authenticated', 'public.wall_zones', 'INSERT'),
  'authenticated keeps wall_zones insert grant'
);
select ok(has_column_privilege('authenticated', 'public.wall_zones', 'created_by', 'INSERT'), 'authenticated may set created_by');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
insert into public.wall_zones (
  id, gym_id, name, location_description, wall_type, display_order,
  availability, created_by
) values (
  '90000000-0000-4000-8000-00000000ff01',
  '10000000-0000-4000-8000-000000000001',
  'User Added Slab', 'Left wall near the mats', 'slab', 3,
  'active', auth.uid()
);
create temp table _t_auth_zone_created as
  select count(*) as c from public.wall_zones
  where id = '90000000-0000-4000-8000-00000000ff01' and created_by = auth.uid();
reset role;

select is((select c from _t_auth_zone_created), 1::bigint, 'signed-in user creates and reads back a wall zone');

-- The policy rejects a wall zone attributed to another user ----------------------

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
do $$
begin
  insert into public.wall_zones (
    id, gym_id, name, wall_type, display_order, availability, created_by
  ) values (
    '90000000-0000-4000-8000-00000000ff02',
    '10000000-0000-4000-8000-000000000001',
    'Forged Zone', 'slab', 4, 'active', '90000000-0000-4000-8000-000000000002'
  );
  raise exception 'expected forged wall zone insert to be rejected';
exception when insufficient_privilege then
  null;
end $$;
reset role;

select ok(true, 'wall zone attributed to another user is rejected (no row inserted)');
select is(
  (select count(*) from public.wall_zones where id = '90000000-0000-4000-8000-00000000ff02'),
  0::bigint,
  'forged wall zone is absent downstream'
);

-- Moderation and search ----------------------------------------------------

select ok(
  has_function_privilege('authenticated', 'public.is_admin()'::regprocedure, 'EXECUTE'),
  'admin role check remains granted'
);
select ok(
  has_function_privilege('authenticated', 'public.is_admin_or_moderator()'::regprocedure, 'EXECUTE'),
  'moderator role check remains granted'
);
select ok(
  exists (select 1 from pg_extension where extname = 'pg_trgm'),
  'pg_trgm extension is installed'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'gyms_name_trgm_idx'),
  'gym name trigram index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'gyms_suburb_trgm_idx'),
  'gym suburb trigram index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'wall_zones_name_trgm_idx'),
  'wall zone name trigram index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'routes_colour_trgm_idx'),
  'route colour trigram index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'routes_label_trgm_idx'),
  'route label trigram index exists'
);
select ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'gyms_name_trgm_idx'
      and indexdef ilike '%gin%' and indexdef ilike '%gin_trgm_ops%'
  ),
  'gym name trigram index uses gin_trgm_ops on lower(name)'
);

select * from finish();

rollback;
