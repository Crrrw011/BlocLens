-- pgTAP: version-checked climbing-data edits and route lifecycle actions.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_update_entity',
  array['text', 'uuid', 'jsonb', 'text', 'timestamp with time zone', 'uuid'],
  'entity update RPC exists'
);
select has_function(
  'public',
  'admin_change_lifecycle',
  array['uuid', 'text', 'text', 'timestamp with time zone', 'uuid'],
  'route lifecycle RPC exists'
);

-- Action fixtures, separate from seed rows.
insert into public.gyms (id, name, slug, suburb, state, latitude, longitude) values (
  '98000000-0000-4000-8000-000000000001', 'Action Gym', 'action-gym',
  'West End', 'QLD', -27.48, 153.0
);
insert into public.wall_zones (id, gym_id, name, wall_kind) values (
  '98000000-0000-4000-8000-000000000002', '98000000-0000-4000-8000-000000000001',
  'Action Slab', 'regular_set_wall'
);
insert into public.routes (id, gym_id, wall_zone_id, colour, gym_grade) values (
  '98000000-0000-4000-8000-000000000003', '98000000-0000-4000-8000-000000000001',
  '98000000-0000-4000-8000-000000000002', 'Teal', 3
);

-- A Moderator edits an allowed route field.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_edit as
  select * from public.admin_update_entity(
    'route', '98000000-0000-4000-8000-000000000003',
    '{"colour": "Cyan", "gym_grade": 4}'::jsonb,
    'Colour verified against the wall', now(),
    '98000000-0000-4000-8000-000000000101'
  );
reset role;

select ok((select ok from _moderator_edit), 'Moderator edits an allowed route field');
select is(
  (select colour from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'Cyan',
  'edit applies the new colour'
);

-- Unknown patch keys are rejected loudly, never ignored.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select throws_ok(
  $$select * from public.admin_update_entity(
      'route', '98000000-0000-4000-8000-000000000003',
      '{"grade_aggregate": 99}'::jsonb,
      'Attempt to touch a forbidden field', now(),
      '98000000-0000-4000-8000-000000000102'
    )$$,
  '22023', 'invalid entity patch',
  'unknown patch keys are rejected'
);
select throws_ok(
  $$select * from public.admin_update_entity(
      'route', '98000000-0000-4000-8000-000000000003',
      '{"lifecycle": "archived"}'::jsonb,
      'Attempt to bypass the lifecycle action', now(),
      '98000000-0000-4000-8000-000000000103'
    )$$,
  '22023', 'invalid entity patch',
  'lifecycle fields are not patchable'
);
reset role;

select is(
  (select colour from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'Cyan',
  'rejected patches leave the row untouched'
);

-- Archiving is Administrator-only.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_archive as
  select * from public.admin_change_lifecycle(
    '98000000-0000-4000-8000-000000000003', 'archive',
    'Moderator attempts to archive', now(),
    '98000000-0000-4000-8000-000000000104'
  );
reset role;

select ok(not (select ok from _moderator_archive), 'Moderator cannot archive a route');
select is((select error_code from _moderator_archive), 'forbidden', 'archive denial is forbidden');
select is(
  (select lifecycle from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'active'::public.route_lifecycle,
  'denied archive leaves the lifecycle untouched'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _admin_archive as
  select * from public.admin_change_lifecycle(
    '98000000-0000-4000-8000-000000000003', 'archive',
    'Route retired after reset', now(),
    '98000000-0000-4000-8000-000000000105'
  );
reset role;

select ok((select ok from _admin_archive), 'Administrator archives a route');
select is(
  (select lifecycle from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'archived'::public.route_lifecycle,
  'archive moves the lifecycle forward'
);

-- Archiving twice is an invalid transition, not a silent no-op.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _double_archive as
  select * from public.admin_change_lifecycle(
    '98000000-0000-4000-8000-000000000003', 'archive',
    'Archive an already-archived route', now(),
    '98000000-0000-4000-8000-000000000106'
  );
create temp table _admin_unarchive as
  select * from public.admin_change_lifecycle(
    '98000000-0000-4000-8000-000000000003', 'unarchive',
    'Route reinstated after reset', now(),
    '98000000-0000-4000-8000-000000000107'
  );
reset role;

select is((select error_code from _double_archive), 'invalid_transition', 'double archive is rejected');
select ok((select ok from _admin_unarchive), 'Administrator restores an archived route');
select is(
  (select lifecycle from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'active'::public.route_lifecycle,
  'unarchive returns the route to active'
);

-- Hiding is shared; it changes the canonical moderation state.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_hide as
  select * from public.admin_change_lifecycle(
    '98000000-0000-4000-8000-000000000003', 'hide',
    'Hold broken, hiding pending reset', now(),
    '98000000-0000-4000-8000-000000000108'
  );
reset role;

select ok((select ok from _moderator_hide), 'Moderator hides a route');
select is(
  (select moderation_status from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'temporarily_hidden'::public.moderation_status,
  'hide changes the canonical moderation state'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_unhide as
  select * from public.admin_change_lifecycle(
    '98000000-0000-4000-8000-000000000003', 'unhide',
    'Hold fixed, restoring', now(),
    '98000000-0000-4000-8000-000000000109'
  );
reset role;

select ok((select ok from _moderator_unhide), 'Moderator restores a hidden route');
select is(
  (select moderation_status from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'visible'::public.moderation_status,
  'unhide returns the route to visible'
);

-- Non-staff attempts are rejected without changing state.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_edit as
  select * from public.admin_update_entity(
    'route', '98000000-0000-4000-8000-000000000003',
    '{"colour": "Red"}'::jsonb,
    'Attempted edit from a non-staff account', now(),
    '98000000-0000-4000-8000-000000000110'
  );
reset role;

select ok(not (select ok from _non_staff_edit), 'non-staff edit is rejected');
select is((select error_code from _non_staff_edit), 'forbidden', 'non-staff rejection is forbidden');
select is(
  (select colour from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'Cyan',
  'rejected edit leaves the row untouched'
);

-- Stale versions conflict instead of overwriting.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_version as
  select updated_at as version from public.routes
  where id = '98000000-0000-4000-8000-000000000003';
reset role;

-- now() is frozen per transaction and the updated_at trigger reuses it, so the
-- trigger is disabled for one statement to advance the version honestly.
alter table public.routes disable trigger routes_set_updated_at;
update public.routes
set updated_at = now() + interval '1 minute'
where id = '98000000-0000-4000-8000-000000000003';
alter table public.routes enable trigger routes_set_updated_at;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_edit as
  select * from public.admin_update_entity(
    'route', '98000000-0000-4000-8000-000000000003',
    '{"colour": "Stale"}'::jsonb,
    'Edit against a stale version', (select version from _stale_version),
    '98000000-0000-4000-8000-000000000111'
  );
reset role;

select ok(not (select ok from _stale_edit), 'stale edit is rejected');
select is((select error_code from _stale_edit), 'conflict', 'stale rejection carries the conflict code');

-- Replays with the same idempotency key return the original outcome once.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _fresh_version as
  select updated_at as version from public.routes
  where id = '98000000-0000-4000-8000-000000000003';
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _first_edit as
  select * from public.admin_update_entity(
    'route', '98000000-0000-4000-8000-000000000003',
    '{"colour": "Teal"}'::jsonb,
    'Edit with idempotency protection', (select version from _fresh_version),
    '98000000-0000-4000-8000-000000000112'
  );
create temp table _replay_edit as
  select * from public.admin_update_entity(
    'route', '98000000-0000-4000-8000-000000000003',
    '{"colour": "Other"}'::jsonb,
    'Replay must not apply a different patch', (select version from _fresh_version),
    '98000000-0000-4000-8000-000000000112'
  );
reset role;

select ok((select ok from _first_edit), 'first edit succeeds');
select ok((select ok from _replay_edit), 'replay reports success without duplicating');
select is(
  (select audit_event_id from _replay_edit),
  (select audit_event_id from _first_edit),
  'replay returns the original audit event'
);
select is(
  (select colour from public.routes where id = '98000000-0000-4000-8000-000000000003'),
  'Teal',
  'replay leaves the first patch in place'
);

-- Every material and rejected outcome is audited.
select ok(
  (
    select count(*) >= 4
    from public.admin_audit_events
    where action_key in ('climbing.entity_updated', 'climbing.lifecycle')
      and outcome = 'succeeded'
  ),
  'successful edits and lifecycle changes are audited'
);
select ok(
  (
    select count(*) >= 3
    from public.admin_audit_events
    where action_key in ('climbing.entity_updated', 'climbing.lifecycle')
      and outcome = 'failed'
  ),
  'forbidden, conflict, and invalid outcomes are audited'
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
      and procedure.proname in ('admin_update_entity', 'admin_change_lifecycle')
  ),
  'entity functions are SECURITY DEFINER with an empty search path'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('admin_update_entity', 'admin_change_lifecycle')
      and pg_catalog.pg_get_functiondef(procedure.oid) ilike '%logbook%'
  ),
  0::bigint,
  'entity logic never references private Logbook content'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_update_entity(text,uuid,jsonb,text,timestamp with time zone,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot update entities'
);

select * from finish();
rollback;
