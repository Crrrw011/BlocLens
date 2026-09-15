-- pgTAP: staff-only climbing-data entity projections.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_list_entities',
  array['text', 'text', 'text', 'uuid', 'text', 'integer'],
  'entity list RPC exists'
);
select has_function(
  'public',
  'admin_entity_detail',
  array['text', 'uuid'],
  'entity detail RPC exists'
);

-- Fixture chain: gym -> zone -> routes, photo, beta link, comment, reset.
insert into public.gyms (
  id, name, slug, suburb, state, latitude, longitude
) values (
  '99000000-0000-4000-8000-000000000001', 'Projection Gym', 'projection-gym',
  'West End', 'QLD', -27.48, 153.0
);

insert into public.wall_zones (id, gym_id, name, wall_kind) values (
  '99000000-0000-4000-8000-000000000002', '99000000-0000-4000-8000-000000000001',
  'Projection Slab', 'regular_set_wall'
);

insert into public.routes (id, gym_id, wall_zone_id, colour, gym_grade) values
  (
    '99000000-0000-4000-8000-000000000003', '99000000-0000-4000-8000-000000000001',
    '99000000-0000-4000-8000-000000000002', 'Teal', 3
  ),
  (
    '99000000-0000-4000-8000-000000000004', '99000000-0000-4000-8000-000000000001',
    '99000000-0000-4000-8000-000000000002', 'Magenta', 5
  );

update public.routes
set moderation_status = 'temporarily_hidden', hidden_at = now()
where id = '99000000-0000-4000-8000-000000000003';

update public.routes
set lifecycle = 'archived', archived_at = now()
where id = '99000000-0000-4000-8000-000000000004';

insert into public.route_photos (id, route_id, storage_path, uploaded_by) values (
  '99000000-0000-4000-8000-000000000005', '99000000-0000-4000-8000-000000000003',
  'projection/photo-1.jpg', '90000000-0000-4000-8000-000000000001'
);

insert into public.beta_links (
  id, route_id, public_url, normalised_url, normalised_url_hash, platform,
  original_author_display_name, original_post_url, submitted_by
) values (
  '99000000-0000-4000-8000-000000000006', '99000000-0000-4000-8000-000000000003',
  'https://example.invalid/beta/p1', 'https://example.invalid/beta/p1',
  'projection-fixture-hash-000000000001', 'youtube',
  'Projection Author', 'https://example.invalid/post/p1',
  '90000000-0000-4000-8000-000000000001'
);

insert into public.beta_comments (id, beta_link_id, author_id, body) values (
  '99000000-0000-4000-8000-000000000007', '99000000-0000-4000-8000-000000000006',
  '90000000-0000-4000-8000-000000000002', 'Projection comment fixture'
);

insert into public.reset_events (id, gym_id, wall_zone_id, reset_date, source, state) values (
  '99000000-0000-4000-8000-000000000008', '99000000-0000-4000-8000-000000000001',
  '99000000-0000-4000-8000-000000000002', now(), 'estimated', 'estimated'
);

insert into public.gyms (
  id, name, slug, suburb, state, latitude, longitude, deleted_at
) values (
  '99000000-0000-4000-8000-000000000009', 'Deleted Gym', 'deleted-gym',
  'Nowhere', 'QLD', -27.48, 153.0, now()
);

-- Staff sees every kind; ordinary users see nothing.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _gyms as
  select * from public.admin_list_entities('gym', 'all', 'Projection Gym', null, null, 100);
create temp table _hidden_routes as
  select * from public.admin_list_entities('route', 'hidden', null, null, null, 100);
create temp table _archived_routes as
  select * from public.admin_list_entities('route', 'archived', null, null, null, 100);
create temp table _deleted_gyms as
  select * from public.admin_list_entities('gym', 'deleted', null, null, null, 100);
create temp table _route_detail as
  select * from public.admin_entity_detail('route', '99000000-0000-4000-8000-000000000003');
create temp table _photo_list as
  select * from public.admin_list_entities('route_photo', 'all', null, null, null, 100);
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_routes as
  select * from public.admin_list_entities('route', 'all', null, null, null, 100);
create temp table _non_staff_detail as
  select * from public.admin_entity_detail('route', '99000000-0000-4000-8000-000000000003');
reset role;

select ok((select count(*) >= 1 from _gyms), 'Administrator lists gyms by search');
select ok(
  (select bool_and(status = 'hidden') from _hidden_routes where id = '99000000-0000-4000-8000-000000000003'),
  'hidden filter surfaces the hidden fixture route'
);
select ok(
  (select bool_and(status = 'archived') from _archived_routes where id = '99000000-0000-4000-8000-000000000004'),
  'archived filter surfaces the archived fixture route'
);
select ok(
  (select count(*) >= 1 from _deleted_gyms),
  'deleted filter surfaces the deleted fixture gym'
);
select is((select count(*) from _non_staff_routes), 0::bigint, 'ordinary users receive no entities');
select is((select count(*) from _non_staff_detail), 0::bigint, 'ordinary users receive no entity detail');

-- Dependent counts reflect the fixture chain.
select is(
  (select dependent_counts->>'wall_zones' from _gyms limit 1),
  '1',
  'gym reports its wall zone count'
);
select is(
  (select jsonb_array_length(related->'photos') from _route_detail),
  1,
  'route detail reports its photo count'
);
select is(
  (select jsonb_array_length(related->'beta_links') from _route_detail),
  1,
  'route detail reports its beta link count'
);
select ok(
  (select jsonb_array_length(related->'photos') >= 1 from _route_detail),
  'route detail relates its photos'
);
select ok(
  (select title is not null and subtitle is not null from _route_detail),
  'route detail names the route and its location'
);
select ok(
  (select count(*) >= 1 from _photo_list),
  'staff lists route photos'
);

update public.route_photos
set moderation_status = 'temporarily_hidden', hidden_at = now()
where id = '99000000-0000-4000-8000-000000000005';

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _hidden_photos as
  select * from public.admin_list_entities('route_photo', 'hidden', null, null, null, 100);
reset role;

select is(
  (select count(*) from _hidden_photos where id = '99000000-0000-4000-8000-000000000005'),
  1::bigint,
  'hidden filter surfaces the hidden fixture photo'
);

-- Stable cursor pagination without overlap.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _first_routes as
  select * from public.admin_list_entities('route', 'all', null, null, null, 1);
create temp table _second_routes as
  select * from public.admin_list_entities(
    'route', 'all', null, null,
    (select updated_at::text || '|' || id::text from _first_routes limit 1),
    100
  );
reset role;

select is(
  (
    select count(*)
    from _second_routes second
    where second.id = (
      select first.id from _first_routes first
      order by first.updated_at desc, first.id desc limit 1
    )
  ),
  0::bigint,
  'cursor continuation overlaps no previously returned entity'
);

select ok(
  (
    select bool_and(
      procedure.prosecdef
      and procedure.proconfig @> array['search_path=""']::text[]
    )
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('admin_list_entities', 'admin_entity_detail')
  ),
  'entity functions are SECURITY DEFINER with an empty search path'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('admin_list_entities', 'admin_entity_detail')
      and pg_catalog.pg_get_functiondef(procedure.oid) ilike '%logbook%'
  ),
  0::bigint,
  'entity projections never reference private Logbook content'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_list_entities(text,text,text,uuid,text,integer)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot list entities'
);

select * from finish();
rollback;
