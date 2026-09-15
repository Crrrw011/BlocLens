-- pgTAP: guarded permanent deletion with eligibility revalidation and tombstones.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_deletion_impact',
  array['text', 'uuid'],
  'deletion impact RPC exists'
);
select has_function(
  'public',
  'admin_permanently_delete',
  array['text', 'uuid', 'text', 'timestamp with time zone', 'uuid'],
  'permanent deletion RPC exists'
);

-- Deletion fixtures.
insert into public.gyms (id, name, slug, suburb, state, latitude, longitude) values (
  '96000000-0000-4000-8000-000000000001', 'Deletion Gym', 'deletion-gym',
  'West End', 'QLD', -27.48, 153.0
);
insert into public.wall_zones (id, gym_id, name, wall_kind) values (
  '96000000-0000-4000-8000-000000000002', '96000000-0000-4000-8000-000000000001',
  'Deletion Slab', 'regular_set_wall'
);
insert into public.routes (id, gym_id, wall_zone_id, colour, gym_grade) values
  ('96000000-0000-4000-8000-000000000003', '96000000-0000-4000-8000-000000000001',
   '96000000-0000-4000-8000-000000000002', 'Bare', 2),
  ('96000000-0000-4000-8000-000000000004', '96000000-0000-4000-8000-000000000001',
   '96000000-0000-4000-8000-000000000002', 'Logged', 2);

insert into public.logbook_entries (
  user_id, route_id, status, climbed_at, client_created_at, client_idempotency_key
) values (
  '90000000-0000-4000-8000-000000000001', '96000000-0000-4000-8000-000000000004',
  'sent', now(), now(), '96000000-0000-4000-8000-000000000005'
);

insert into public.route_photos (id, route_id, storage_path, uploaded_by) values (
  '96000000-0000-4000-8000-000000000006', '96000000-0000-4000-8000-000000000004',
  'deletion/photo-1.jpg', '90000000-0000-4000-8000-000000000001'
);

insert into public.beta_links (
  id, route_id, public_url, normalised_url, normalised_url_hash, platform,
  original_author_display_name, original_post_url, submitted_by
) values (
  '96000000-0000-4000-8000-000000000007', '96000000-0000-4000-8000-000000000004',
  'https://example.invalid/beta/d1', 'https://example.invalid/beta/d1',
  'deletion-fixture-hash-000000000001', 'youtube',
  'Deletion Author', 'https://example.invalid/post/d1',
  '90000000-0000-4000-8000-000000000001'
);

insert into public.beta_comments (id, beta_link_id, author_id, body) values (
  '96000000-0000-4000-8000-000000000008', '96000000-0000-4000-8000-000000000007',
  '90000000-0000-4000-8000-000000000002', 'Deletion comment fixture'
);

insert into public.reset_events (id, gym_id, reset_date, source, state) values (
  '96000000-0000-4000-8000-000000000009', '96000000-0000-4000-8000-000000000001',
  now(), 'estimated', 'estimated'
);

-- Impact: bare route eligible, logged route blocked, gym retained.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _bare_impact as
  select * from public.admin_deletion_impact('route', '96000000-0000-4000-8000-000000000003');
create temp table _logged_impact as
  select * from public.admin_deletion_impact('route', '96000000-0000-4000-8000-000000000004');
create temp table _gym_impact as
  select * from public.admin_deletion_impact('gym', '96000000-0000-4000-8000-000000000001');
create temp table _reset_impact as
  select * from public.admin_deletion_impact('reset', '96000000-0000-4000-8000-000000000009');
create temp table _photo_impact as
  select * from public.admin_deletion_impact('route_photo', '96000000-0000-4000-8000-000000000006');
create temp table _link_impact as
  select * from public.admin_deletion_impact('beta_link', '96000000-0000-4000-8000-000000000007');
reset role;

select ok((select eligible from _bare_impact), 'bare route is deletion-eligible');
select ok(not (select eligible from _logged_impact), 'route with Logbook references is blocked');
select is(
  (select alternative from _logged_impact),
  'merge',
  'Logbook-blocked route suggests merging'
);
select is(
  (select blockers from _gym_impact),
  array['retained_relationship']::text[],
  'gyms report a retained relationship'
);
select is(
  (select blockers from _reset_impact),
  array['retained_relationship']::text[],
  'resets report a retained relationship'
);
select ok((select eligible from _photo_impact), 'photo is deletion-eligible');
select is(
  (select storage_paths from _photo_impact),
  array['deletion/photo-1.jpg']::text[],
  'photo impact names its storage path'
);
select ok(not (select eligible from _link_impact), 'beta link with comments is blocked');
select is(
  (select dependent_counts->>'beta_comments' from _link_impact),
  '1',
  'link impact counts its comments'
);

-- Non-staff impact is denied.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_impact as
  select * from public.admin_deletion_impact('route', '96000000-0000-4000-8000-000000000003');
reset role;

select is((select blockers from _non_staff_impact), array['forbidden']::text[], 'non-staff impact is denied');

-- A Moderator cannot permanently delete.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_delete as
  select * from public.admin_permanently_delete(
    'route_photo', '96000000-0000-4000-8000-000000000006',
    'Moderator attempts deletion', now(),
    '96000000-0000-4000-8000-000000000011'
  );
reset role;

select is((select error_code from _moderator_delete), 'forbidden', 'Moderator deletion is forbidden');
select is(
  (select count(*) from public.route_photos where id = '96000000-0000-4000-8000-000000000006'),
  1::bigint,
  'denied deletion leaves the row intact'
);

-- Missing reasons raise at the validation boundary.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select throws_ok(
  $$select * from public.admin_permanently_delete(
      'route_photo', '96000000-0000-4000-8000-000000000006',
      '   ', now(), '96000000-0000-4000-8000-000000000012'
    )$$,
  '22023', 'invalid deletion input',
  'missing reason is rejected'
);
reset role;

-- Blocked targets refuse deletion without changing state.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _blocked_delete as
  select * from public.admin_permanently_delete(
    'route', '96000000-0000-4000-8000-000000000004',
    'Attempt to delete a logged route',
    (select updated_at from public.routes where id = '96000000-0000-4000-8000-000000000004'),
    '96000000-0000-4000-8000-000000000013'
  );
reset role;

select is((select error_code from _blocked_delete), 'blocked', 'blocked deletion reports blockers');
select is(
  (select count(*) from public.routes where id = '96000000-0000-4000-8000-000000000004'),
  1::bigint,
  'blocked deletion leaves the row intact'
);

-- Eligible photo deletion removes the row and leaves a tombstone.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _photo_version as
  select updated_at as version from public.route_photos
  where id = '96000000-0000-4000-8000-000000000006';
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _photo_delete as
  select * from public.admin_permanently_delete(
    'route_photo', '96000000-0000-4000-8000-000000000006',
    'Blurry duplicate with no references', (select version from _photo_version),
    '96000000-0000-4000-8000-000000000014'
  );
reset role;

select ok((select ok from _photo_delete), 'eligible photo deletion succeeds');
select is(
  (select count(*) from public.route_photos where id = '96000000-0000-4000-8000-000000000006'),
  0::bigint,
  'deleted photo row is gone'
);
select is(
  (
    select after_summary->'storage_paths'->>0
    from public.admin_audit_events
    where id = (select audit_event_id from _photo_delete)
  ),
  'deletion/photo-1.jpg',
  'tombstone retains the storage path'
);

-- Eligible comment deletion removes the row and leaves a tombstone.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _comment_version as
  select updated_at as version from public.beta_comments
  where id = '96000000-0000-4000-8000-000000000008';
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _comment_delete as
  select * from public.admin_permanently_delete(
    'route_comment', '96000000-0000-4000-8000-000000000008',
    'Spam comment with no references', (select version from _comment_version),
    '96000000-0000-4000-8000-000000000015'
  );
reset role;

select ok((select ok from _comment_delete), 'eligible comment deletion succeeds');
select is(
  (select count(*) from public.beta_comments where id = '96000000-0000-4000-8000-000000000008'),
  0::bigint,
  'deleted comment row is gone'
);

-- The beta link unblocks once its comment is gone.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _link_delete as
  select * from public.admin_permanently_delete(
    'beta_link', '96000000-0000-4000-8000-000000000007',
    'Broken link with no remaining references',
    (select updated_at from public.beta_links where id = '96000000-0000-4000-8000-000000000007'),
    '96000000-0000-4000-8000-000000000016'
  );
reset role;

select ok((select ok from _link_delete), 'unblocked beta link deletion succeeds');

-- Stale versions conflict instead of deleting.
alter table public.routes disable trigger routes_set_updated_at;
update public.routes
set updated_at = now() + interval '1 minute'
where id = '96000000-0000-4000-8000-000000000003';
alter table public.routes enable trigger routes_set_updated_at;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_delete as
  select * from public.admin_permanently_delete(
    'route', '96000000-0000-4000-8000-000000000003',
    'Deletion against a stale version', now() - interval '1 hour',
    '96000000-0000-4000-8000-000000000017'
  );
reset role;

select is((select error_code from _stale_delete), 'conflict', 'stale deletion carries the conflict code');
select is(
  (select count(*) from public.routes where id = '96000000-0000-4000-8000-000000000003'),
  1::bigint,
  'conflict leaves the row intact'
);

-- Replay returns the original outcome without duplicating.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _replay_delete as
  select * from public.admin_permanently_delete(
    'route_comment', '96000000-0000-4000-8000-000000000008',
    'Replay must not duplicate', (select version from _comment_version),
    '96000000-0000-4000-8000-000000000015'
  );
reset role;

select ok((select ok from _replay_delete), 'replay reports success');
select is(
  (select audit_event_id from _replay_delete),
  (select audit_event_id from _comment_delete),
  'replay returns the original audit event'
);

-- Audit coverage without private content.
select ok(
  (
    select count(*) >= 3
    from public.admin_audit_events
    where action_key = 'entity.deleted'
      and outcome = 'succeeded'
  ),
  'successful deletions are audited'
);
select ok(
  (
    select count(*) >= 2
    from public.admin_audit_events
    where action_key = 'entity.deleted'
      and outcome = 'failed'
  ),
  'forbidden and blocked deletions are audited'
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
      and procedure.proname in ('admin_deletion_impact', 'admin_permanently_delete')
  ),
  'deletion functions are SECURITY DEFINER with an empty search path'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('admin_deletion_impact', 'admin_permanently_delete')
      and pg_catalog.pg_get_functiondef(procedure.oid) ilike '%private_note%'
  ),
  0::bigint,
  'deletion logic never references private Logbook notes'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_permanently_delete(text,uuid,text,timestamp with time zone,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot delete records'
);

select * from finish();
rollback;
