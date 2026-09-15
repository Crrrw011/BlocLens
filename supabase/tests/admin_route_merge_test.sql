-- pgTAP: transactional route merge with impact preview and conflict acknowledgement.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_route_merge_impact',
  array['uuid', 'uuid'],
  'merge impact RPC exists'
);
select has_function(
  'public',
  'admin_merge_routes',
  array['uuid', 'uuid', 'jsonb', 'text', 'jsonb', 'uuid'],
  'merge execution RPC exists'
);

-- Merge fixtures: routes S (source) and C (canonical) share a gym; X is cross-gym.
insert into public.gyms (id, name, slug, suburb, state, latitude, longitude) values
  ('97000000-0000-4000-8000-000000000001', 'Merge Gym', 'merge-gym', 'West End', 'QLD', -27.48, 153.0),
  ('97000000-0000-4000-8000-000000000002', 'Other Gym', 'other-gym', 'City', 'QLD', -27.47, 153.02);

insert into public.wall_zones (id, gym_id, name, wall_kind) values
  ('97000000-0000-4000-8000-000000000011', '97000000-0000-4000-8000-000000000001', 'Merge Slab', 'regular_set_wall'),
  ('97000000-0000-4000-8000-000000000012', '97000000-0000-4000-8000-000000000002', 'Other Slab', 'regular_set_wall');

insert into public.routes (id, gym_id, wall_zone_id, colour, gym_grade) values
  ('97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000011', 'Teal', 3),
  ('97000000-0000-4000-8000-000000000022', '97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000011', 'Cyan', 4),
  ('97000000-0000-4000-8000-000000000023', '97000000-0000-4000-8000-000000000002', '97000000-0000-4000-8000-000000000012', 'Red', 2),
  ('97000000-0000-4000-8000-000000000024', '97000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000011', 'Magenta', 5);

-- Logbook: user .001 on both (conflict), user .002 on source only (migrates).
-- The private note must never appear in any projection.
insert into public.logbook_entries (
  user_id, route_id, status, climbed_at, client_created_at, client_idempotency_key, private_note
) values
  ('90000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000021', 'sent', now(), now(), '97000000-0000-4000-8000-000000000031', 'SECRET-NOTE-source'),
  ('90000000-0000-4000-8000-000000000001', '97000000-0000-4000-8000-000000000022', 'sent', now(), now(), '97000000-0000-4000-8000-000000000032', 'SECRET-NOTE-canonical'),
  ('90000000-0000-4000-8000-000000000002', '97000000-0000-4000-8000-000000000021', 'projecting', now(), now(), '97000000-0000-4000-8000-000000000033', 'SECRET-NOTE-mover');

insert into public.route_grade_votes (route_id, user_id, v_grade) values
  ('97000000-0000-4000-8000-000000000021', '90000000-0000-4000-8000-000000000001', 3),
  ('97000000-0000-4000-8000-000000000022', '90000000-0000-4000-8000-000000000001', 4),
  ('97000000-0000-4000-8000-000000000021', '90000000-0000-4000-8000-000000000002', 3);

insert into public.route_photos (id, route_id, storage_path, uploaded_by) values
  ('97000000-0000-4000-8000-000000000041', '97000000-0000-4000-8000-000000000021', 'merge/photo-1.jpg', '90000000-0000-4000-8000-000000000001'),
  ('97000000-0000-4000-8000-000000000042', '97000000-0000-4000-8000-000000000021', 'merge/photo-2.jpg', '90000000-0000-4000-8000-000000000002');

insert into public.beta_links (
  id, route_id, public_url, normalised_url, normalised_url_hash, platform,
  original_author_display_name, original_post_url, submitted_by
) values
  ('97000000-0000-4000-8000-000000000051', '97000000-0000-4000-8000-000000000021',
   'https://example.invalid/beta/m1', 'https://example.invalid/beta/m1', 'merge-fixture-hash-000000000001',
   'youtube', 'Merge Author', 'https://example.invalid/post/m1', '90000000-0000-4000-8000-000000000001'),
  ('97000000-0000-4000-8000-000000000052', '97000000-0000-4000-8000-000000000022',
   'https://example.invalid/beta/m1', 'https://example.invalid/beta/m1', 'merge-fixture-hash-000000000001',
   'youtube', 'Merge Author', 'https://example.invalid/post/m1', '90000000-0000-4000-8000-000000000001'),
  ('97000000-0000-4000-8000-000000000053', '97000000-0000-4000-8000-000000000021',
   'https://example.invalid/beta/m2', 'https://example.invalid/beta/m2', 'merge-fixture-hash-000000000002',
   'youtube', 'Merge Author', 'https://example.invalid/post/m2', '90000000-0000-4000-8000-000000000001');

insert into public.route_corrections (id, route_id, submitted_by, issue_key, explanation, status) values
  ('97000000-0000-4000-8000-000000000061', '97000000-0000-4000-8000-000000000021',
   '90000000-0000-4000-8000-000000000001', 'grade', 'Grade looks soft', 'open'),
  ('97000000-0000-4000-8000-000000000062', '97000000-0000-4000-8000-000000000022',
   '90000000-0000-4000-8000-000000000001', 'grade', 'Grade looks soft here too', 'open'),
  ('97000000-0000-4000-8000-000000000063', '97000000-0000-4000-8000-000000000021',
   '90000000-0000-4000-8000-000000000002', 'holds', 'Hold text outdated', 'open');

insert into public.content_reports (
  id, target_type, target_id, category, reporter_id, details, status
) values
  ('97000000-0000-4000-8000-000000000071', 'route', '97000000-0000-4000-8000-000000000021',
   'spam', '90000000-0000-4000-8000-000000000001', 'Merge report fixture', 'open'),
  ('97000000-0000-4000-8000-000000000072', 'route', '97000000-0000-4000-8000-000000000022',
   'spam', '90000000-0000-4000-8000-000000000001', 'Merge report canonical', 'open');

insert into public.route_merge_suggestions (
  id, source_route_id, proposed_canonical_route_id, suggested_by, reason, status
) values
  ('97000000-0000-4000-8000-000000000081', '97000000-0000-4000-8000-000000000021',
   '97000000-0000-4000-8000-000000000022', '90000000-0000-4000-8000-000000000001',
   'Satisfied by this very merge', 'proposed');

-- Impact preview as Administrator.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _impact as
  select * from public.admin_route_merge_impact(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000022'
  );
reset role;

select ok((select ok from _impact), 'impact preview succeeds for staff');
select is(
  (select impact->'counts'->>'logbook_entries' from _impact),
  '2',
  'impact counts source Logbook references without content'
);
select is(
  (select impact->'counts'->>'route_photos' from _impact),
  '2',
  'impact counts source photos'
);
select is(
  (select jsonb_array_length(impact->'conflicts') from _impact),
  5::integer,
  'impact lists one conflict per duplicate relationship'
);
select is(
  (select impact::text like '%SECRET-NOTE%' from _impact),
  false,
  'impact preview never carries private Logbook notes'
);

-- Non-staff preview is refused.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_impact as
  select * from public.admin_route_merge_impact(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000022'
  );
reset role;

select is((select error_code from _non_staff_impact), 'forbidden', 'non-staff preview is forbidden');

-- Cross-gym, self, and missing pairs are refused.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _cross_gym as
  select * from public.admin_route_merge_impact(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000023'
  );
create temp table _self_merge as
  select * from public.admin_route_merge_impact(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000021'
  );
create temp table _missing_pair as
  select * from public.admin_route_merge_impact(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000099'
  );
reset role;

select is((select error_code from _cross_gym), 'cross_gym', 'cross-gym merge is refused');
select is((select error_code from _self_merge), 'invalid', 'self merge is refused');
select is((select error_code from _missing_pair), 'not_found', 'missing routes report not_found');

-- A Moderator cannot execute a merge.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_merge as
  select * from public.admin_merge_routes(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000022',
    '{}'::jsonb, 'Moderator attempts a merge',
    jsonb_build_object('source', now(), 'canonical', now()),
    '97000000-0000-4000-8000-000000000091'
  );
reset role;

select is((select error_code from _moderator_merge), 'forbidden', 'Moderator merge is forbidden');
select is(
  (select lifecycle from public.routes where id = '97000000-0000-4000-8000-000000000021'),
  'active'::public.route_lifecycle,
  'denied merge leaves the source untouched'
);

-- Unacknowledged conflicts refuse the merge.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _unresolved_merge as
  select * from public.admin_merge_routes(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000022',
    '{}'::jsonb, 'Merge without acknowledging duplicates',
    (select jsonb_build_object(
      'source', (select updated_at from public.routes where id = '97000000-0000-4000-8000-000000000021'),
      'canonical', (select updated_at from public.routes where id = '97000000-0000-4000-8000-000000000022')
    )),
    '97000000-0000-4000-8000-000000000092'
  );
reset role;

select is((select error_code from _unresolved_merge), 'unresolved_conflicts', 'unacknowledged duplicates refuse the merge');
select is(
  (select lifecycle from public.routes where id = '97000000-0000-4000-8000-000000000021'),
  'active'::public.route_lifecycle,
  'refused merge leaves the source untouched'
);

-- Full acknowledgement executes the merge transactionally.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _resolutions as
  select jsonb_object_agg(conflict ->> 'key', 'skip') as resolutions
  from public.admin_route_merge_impact(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000022'
  ) as preview, jsonb_array_elements(preview.impact -> 'conflicts') as conflict
  where preview.ok;
create temp table _versions as
  select jsonb_build_object(
    'source', (select updated_at from public.routes where id = '97000000-0000-4000-8000-000000000021'),
    'canonical', (select updated_at from public.routes where id = '97000000-0000-4000-8000-000000000022')
  ) as versions;
create temp table _merge as
  select * from public.admin_merge_routes(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000022',
    (select resolutions from _resolutions),
    'Duplicate confirmed on the wall', (select versions from _versions),
    '97000000-0000-4000-8000-000000000093'
  );
reset role;

select ok((select ok from _merge), 'acknowledged merge succeeds');
select is(
  (select lifecycle from public.routes where id = '97000000-0000-4000-8000-000000000021'),
  'archived'::public.route_lifecycle,
  'source is archived after merge'
);
select is(
  (select canonical_route_id from public.routes where id = '97000000-0000-4000-8000-000000000021'),
  '97000000-0000-4000-8000-000000000022',
  'source points at its canonical route'
);
select is(
  (select route_id from public.logbook_entries where client_idempotency_key = '97000000-0000-4000-8000-000000000033'),
  '97000000-0000-4000-8000-000000000022',
  'non-conflicting Logbook reference migrates to canonical'
);
select is(
  (select route_id from public.logbook_entries where client_idempotency_key = '97000000-0000-4000-8000-000000000031'),
  '97000000-0000-4000-8000-000000000021',
  'conflicting Logbook reference stays on the archived source'
);
select is(
  (select count(*) from public.route_photos where route_id = '97000000-0000-4000-8000-000000000022'),
  2::bigint,
  'photos migrate to canonical'
);
select is(
  (select count(*) from public.beta_links where route_id = '97000000-0000-4000-8000-000000000022'),
  2::bigint,
  'non-conflicting beta link migrates while the duplicate stays'
);
select is(
  (select status from public.route_merge_suggestions where id = '97000000-0000-4000-8000-000000000081'),
  'completed'::public.merge_status,
  'the satisfied suggestion completes instead of looping'
);
select is(
  (
    select count(*)
    from public.moderation_actions
    where target_id = '97000000-0000-4000-8000-000000000021'
      and action_type = 'merge'
  ),
  1::bigint,
  'merge records one canonical moderation action'
);

-- Merging an already-merged source is refused.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _remerge as
  select * from public.admin_merge_routes(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000024',
    '{}'::jsonb, 'Merge an already-merged source',
    (select jsonb_build_object(
      'source', (select updated_at from public.routes where id = '97000000-0000-4000-8000-000000000021'),
      'canonical', (select updated_at from public.routes where id = '97000000-0000-4000-8000-000000000024')
    )),
    '97000000-0000-4000-8000-000000000094'
  );
reset role;

select is((select error_code from _remerge), 'already_merged', 'merged sources cannot merge again');

-- Replay returns the original outcome without duplicating.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _replay_merge as
  select * from public.admin_merge_routes(
    '97000000-0000-4000-8000-000000000021', '97000000-0000-4000-8000-000000000022',
    (select resolutions from _resolutions),
    'Replay must not duplicate', (select versions from _versions),
    '97000000-0000-4000-8000-000000000093'
  );
reset role;

select ok((select ok from _replay_merge), 'replay reports success');
select is(
  (select audit_event_id from _replay_merge),
  (select audit_event_id from _merge),
  'replay returns the original audit event'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where idempotency_key = '97000000-0000-4000-8000-000000000093'
  ),
  1::bigint,
  'idempotent replay leaves exactly one audit event'
);

-- Stale versions conflict instead of merging.
alter table public.routes disable trigger routes_set_updated_at;
update public.routes
set updated_at = now() + interval '1 minute'
where id = '97000000-0000-4000-8000-000000000024';
alter table public.routes enable trigger routes_set_updated_at;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_merge as
  select * from public.admin_merge_routes(
    '97000000-0000-4000-8000-000000000024', '97000000-0000-4000-8000-000000000022',
    '{}'::jsonb, 'Merge against a stale version',
    jsonb_build_object('source', now() - interval '1 hour', 'canonical', now()),
    '97000000-0000-4000-8000-000000000095'
  );
reset role;

select is((select error_code from _stale_merge), 'conflict', 'stale merge carries the conflict code');

-- Audit coverage without private content.
select is(
  (
    select count(*)
    from public.admin_audit_events
    where action_key = 'route.merge'
      and outcome = 'succeeded'
      and target_id = '97000000-0000-4000-8000-000000000021'
  ),
  1::bigint,
  'successful merge is audited once'
);
select ok(
  (
    select count(*) >= 3
    from public.admin_audit_events
    where action_key = 'route.merge'
      and outcome = 'failed'
  ),
  'forbidden, unresolved, and invalid merges are audited'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where action_key = 'route.merge'
      and (before_summary::text like '%SECRET-NOTE%' or after_summary::text like '%SECRET-NOTE%')
  ),
  0::bigint,
  'merge audit never carries private Logbook notes'
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
      and procedure.proname in ('admin_route_merge_impact', 'admin_merge_routes')
  ),
  'merge functions are SECURITY DEFINER with an empty search path'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('admin_route_merge_impact', 'admin_merge_routes')
      and pg_catalog.pg_get_functiondef(procedure.oid) ilike '%private_note%'
  ),
  0::bigint,
  'merge logic never references private Logbook notes'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_merge_routes(uuid,uuid,jsonb,text,jsonb,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot merge routes'
);

select * from finish();
rollback;
