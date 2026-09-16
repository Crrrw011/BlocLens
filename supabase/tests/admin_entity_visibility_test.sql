-- pgTAP: visibility transitions for wall zones, photos, beta links, comments.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_set_visibility',
  array['text', 'uuid', 'text', 'text', 'timestamp with time zone', 'uuid'],
  'visibility RPC exists'
);

-- Fixture chain: gym -> zone -> route -> photo/link -> comment.
insert into public.gyms (id, name, slug, suburb, state, latitude, longitude) values (
  '98000000-0000-4000-8000-000000000001', 'Visibility Gym', 'visibility-gym',
  'West End', 'QLD', -27.48, 153.0
);

insert into public.wall_zones (id, gym_id, name, wall_kind) values (
  '98000000-0000-4000-8000-000000000002', '98000000-0000-4000-8000-000000000001',
  'Visibility Slab', 'regular_set_wall'
);

insert into public.routes (id, gym_id, wall_zone_id, colour, gym_grade) values (
  '98000000-0000-4000-8000-000000000003', '98000000-0000-4000-8000-000000000001',
  '98000000-0000-4000-8000-000000000002', 'Teal', 3
);

insert into public.route_photos (id, route_id, storage_path, uploaded_by) values (
  '98000000-0000-4000-8000-000000000004', '98000000-0000-4000-8000-000000000003',
  'visibility/photo-1.jpg', '90000000-0000-4000-8000-000000000001'
);

insert into public.beta_links (
  id, route_id, public_url, normalised_url, normalised_url_hash, platform,
  original_author_display_name, original_post_url, submitted_by
) values (
  '98000000-0000-4000-8000-000000000005', '98000000-0000-4000-8000-000000000003',
  'https://example.invalid/beta/v1', 'https://example.invalid/beta/v1',
  'visibility-fixture-hash-000000000001', 'youtube',
  'Visibility Author', 'https://example.invalid/post/v1',
  '90000000-0000-4000-8000-000000000001'
);

insert into public.beta_comments (id, beta_link_id, author_id, body) values (
  '98000000-0000-4000-8000-000000000006', '98000000-0000-4000-8000-000000000005',
  '90000000-0000-4000-8000-000000000002', 'Visibility comment fixture'
);

-- Administrator archives the wall zone; Moderator cannot.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _zone_archive as
  select * from public.admin_set_visibility(
    'wall_zone', '98000000-0000-4000-8000-000000000002', 'archive',
    'Wall closed for reset', now(),
    '98000000-0000-4000-8000-000000000011'
  );
reset role;

select ok((select ok from _zone_archive), 'Administrator archives a wall zone');
select is(
  (select availability from public.wall_zones where id = '98000000-0000-4000-8000-000000000002'),
  'archived'::public.wall_zone_availability,
  'archive flips zone availability'
);
select ok(
  (select archived_at is not null from public.wall_zones where id = '98000000-0000-4000-8000-000000000002'),
  'archive stamps archived_at'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_zone_archive as
  select * from public.admin_set_visibility(
    'wall_zone', '98000000-0000-4000-8000-000000000002', 'archive',
    'Moderator attempts zone archive', now(),
    '98000000-0000-4000-8000-000000000012'
  );
reset role;

select is((select error_code from _moderator_zone_archive), 'forbidden', 'Moderator zone archive is forbidden');

-- Administrator restores the zone; double archive is invalid.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _zone_unarchive as
  select * from public.admin_set_visibility(
    'wall_zone', '98000000-0000-4000-8000-000000000002', 'unarchive',
    'Wall reopened', now(),
    '98000000-0000-4000-8000-000000000013'
  );
create temp table _zone_hide as
  select * from public.admin_set_visibility(
    'wall_zone', '98000000-0000-4000-8000-000000000002', 'hide',
    'Hide is not a zone transition', now(),
    '98000000-0000-4000-8000-000000000014'
  );
reset role;

select ok((select ok from _zone_unarchive), 'Administrator restores a wall zone');
select is(
  (select availability from public.wall_zones where id = '98000000-0000-4000-8000-000000000002'),
  'active'::public.wall_zone_availability,
  'restore returns zone availability'
);
select is((select error_code from _zone_hide), 'invalid_transition', 'zone hide is rejected');

-- Moderator hides and unhides a photo; archive needs an Administrator.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_hide as
  select * from public.admin_set_visibility(
    'route_photo', '98000000-0000-4000-8000-000000000004', 'hide',
    'Blurry photo hidden', now(),
    '98000000-0000-4000-8000-000000000015'
  );
reset role;

select ok((select ok from _moderator_hide), 'Moderator hides a photo');
select is(
  (select moderation_status from public.route_photos where id = '98000000-0000-4000-8000-000000000004'),
  'temporarily_hidden'::public.moderation_status,
  'hide flips photo moderation'
);
select is(
  (
    select count(*)
    from public.moderation_actions
    where target_id = '98000000-0000-4000-8000-000000000004'
      and action_type = 'hide'
  ),
  1::bigint,
  'hide records one moderation history row'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_archive_photo as
  select * from public.admin_set_visibility(
    'route_photo', '98000000-0000-4000-8000-000000000004', 'archive',
    'Moderator attempts photo archive', now(),
    '98000000-0000-4000-8000-000000000016'
  );
create temp table _moderator_unhide as
  select * from public.admin_set_visibility(
    'route_photo', '98000000-0000-4000-8000-000000000004', 'unhide',
    'Replacement uploaded', now(),
    '98000000-0000-4000-8000-000000000017'
  );
reset role;

select is((select error_code from _moderator_archive_photo), 'forbidden', 'Moderator photo archive is forbidden');
select ok((select ok from _moderator_unhide), 'Moderator restores a photo');

-- Gyms and resets expose no archive affordance.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select throws_ok(
  $$select * from public.admin_set_visibility(
      'gym', '98000000-0000-4000-8000-000000000001', 'archive',
      'Gym archive attempt', now(),
      '98000000-0000-4000-8000-000000000018'
    )$$,
  '22023', 'invalid visibility action',
  'gym archive is rejected at validation'
);
select throws_ok(
  $$select * from public.admin_set_visibility(
      'reset', '98000000-0000-4000-8000-000000000001', 'archive',
      'Reset archive attempt', now(),
      '98000000-0000-4000-8000-000000000019'
    )$$,
  '22023', 'invalid visibility action',
  'reset archive is rejected at validation'
);
select throws_ok(
  $$select * from public.admin_set_visibility(
      'beta_link', '98000000-0000-4000-8000-000000000005', 'delete',
      'Unknown action attempt', now(),
      '98000000-0000-4000-8000-000000000020'
    )$$,
  '22023', 'invalid visibility action',
  'unknown actions are rejected at validation'
);
reset role;

-- Non-staff attempts are rejected without changing state.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_hide as
  select * from public.admin_set_visibility(
    'beta_link', '98000000-0000-4000-8000-000000000005', 'hide',
    'Attempted hide from a non-staff account', now(),
    '98000000-0000-4000-8000-000000000021'
  );
reset role;

select is((select error_code from _non_staff_hide), 'forbidden', 'non-staff hide is forbidden');
select is(
  (select moderation_status from public.beta_links where id = '98000000-0000-4000-8000-000000000005'),
  'visible'::public.moderation_status,
  'rejected hide leaves the link untouched'
);

-- Stale versions conflict instead of overwriting.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_version as
  select updated_at as version from public.beta_comments
  where id = '98000000-0000-4000-8000-000000000006';
reset role;

alter table public.beta_comments disable trigger beta_comments_set_updated_at;
update public.beta_comments
set updated_at = now() + interval '1 minute'
where id = '98000000-0000-4000-8000-000000000006';
alter table public.beta_comments enable trigger beta_comments_set_updated_at;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_hide as
  select * from public.admin_set_visibility(
    'route_comment', '98000000-0000-4000-8000-000000000006', 'hide',
    'Hide against a stale version', (select version from _stale_version),
    '98000000-0000-4000-8000-000000000022'
  );
reset role;

select is((select error_code from _stale_hide), 'conflict', 'stale hide carries the conflict code');

-- Idempotent replay returns the original outcome.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _fresh_version as
  select updated_at as version from public.beta_comments
  where id = '98000000-0000-4000-8000-000000000006';
create temp table _first_hide as
  select * from public.admin_set_visibility(
    'route_comment', '98000000-0000-4000-8000-000000000006', 'hide',
    'Hide with idempotency protection', (select version from _fresh_version),
    '98000000-0000-4000-8000-000000000023'
  );
create temp table _replay_hide as
  select * from public.admin_set_visibility(
    'route_comment', '98000000-0000-4000-8000-000000000006', 'hide',
    'Replay must not duplicate', (select version from _fresh_version),
    '98000000-0000-4000-8000-000000000023'
  );
reset role;

select ok((select ok from _first_hide), 'first hide succeeds');
select is(
  (select audit_event_id from _replay_hide),
  (select audit_event_id from _first_hide),
  'replay returns the original audit event'
);

-- Audit coverage and privilege posture.
select ok(
  (
    select count(*) >= 3
    from public.admin_audit_events
    where action_key in ('entity.archived', 'entity.restored', 'entity.hidden')
      and outcome = 'succeeded'
  ),
  'visibility transitions are audited'
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
      and procedure.proname = 'admin_set_visibility'
  ),
  'visibility function is SECURITY DEFINER with an empty search path'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'admin_set_visibility'
      and pg_catalog.pg_get_functiondef(procedure.oid) ilike '%logbook%'
  ),
  0::bigint,
  'visibility logic never references private Logbook content'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_set_visibility(text,uuid,text,text,timestamp with time zone,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot change visibility'
);

select * from finish();
rollback;
