-- pgTAP: canonical user penalties with RLS enforcement and audit linkage.
create extension if not exists pgtap;

begin;
select no_plan();

select has_table('public', 'user_restrictions', 'user restrictions table exists');
select has_function(
  'public',
  'admin_user_summary',
  array['uuid'],
  'user summary RPC exists'
);
select has_function(
  'public',
  'admin_apply_user_penalty',
  array['uuid', 'text', 'timestamp with time zone', 'text', 'uuid'],
  'penalty application RPC exists'
);
select has_function(
  'public',
  'admin_reverse_user_penalty',
  array['uuid', 'text', 'uuid'],
  'penalty reversal RPC exists'
);

-- An Administrator restricts publishing for .001, suspends .002, bans .003.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _restrict_publishing as
  select * from public.admin_apply_user_penalty(
    '90000000-0000-4000-8000-000000000001', 'publishing_restriction', null,
    'Repeated off-topic beta links', '98000000-0000-4000-8000-000000000001'
  );
create temp table _suspend as
  select * from public.admin_apply_user_penalty(
    '90000000-0000-4000-8000-000000000002', 'timed_suspension', now() + interval '7 days',
    'Harassment in comments', '98000000-0000-4000-8000-000000000002'
  );
create temp table _ban as
  select * from public.admin_apply_user_penalty(
    '90000000-0000-4000-8000-000000000003', 'permanent_ban', null,
    'Severe safety violation', '98000000-0000-4000-8000-000000000003'
  );
reset role;

select ok((select ok from _restrict_publishing), 'publishing restriction applies');
select ok((select ok from _suspend), 'timed suspension applies');
select ok((select ok from _ban), 'permanent ban applies');
select is(
  (select count(*) from public.user_restrictions where revoked_at is null),
  3::bigint,
  'three canonical restrictions are active'
);

-- Duplicate active penalties are refused.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _duplicate as
  select * from public.admin_apply_user_penalty(
    '90000000-0000-4000-8000-000000000001', 'publishing_restriction', null,
    'Duplicate restriction attempt', '98000000-0000-4000-8000-000000000004'
  );
reset role;

select is((select error_code from _duplicate), 'already_active', 'duplicate penalty reports already_active');

-- Expiry rules are enforced at the boundary.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select throws_ok(
  $$select * from public.admin_apply_user_penalty(
      '90000000-0000-4000-8000-000000000004', 'timed_suspension', now() - interval '1 day',
      'Suspension that already ended', '98000000-0000-4000-8000-000000000005'
    )$$,
  '22023', 'invalid penalty expiry',
  'past suspension expiry is rejected'
);
select throws_ok(
  $$select * from public.admin_apply_user_penalty(
      '90000000-0000-4000-8000-000000000004', 'permanent_ban', now() + interval '1 day',
      'Ban with an expiry', '98000000-0000-4000-8000-000000000006'
    )$$,
  '22023', 'invalid penalty expiry',
  'ban with an expiry is rejected'
);
select throws_ok(
  $$select * from public.admin_apply_user_penalty(
      '90000000-0000-4000-8000-000000000004', 'timed_suspension', null,
      'Suspension without an expiry', '98000000-0000-4000-8000-000000000007'
    )$$,
  '22023', 'invalid penalty expiry',
  'suspension without an expiry is rejected'
);
reset role;

-- A Moderator cannot penalise.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_penalty as
  select * from public.admin_apply_user_penalty(
    '90000000-0000-4000-8000-000000000004', 'publishing_restriction', null,
    'Moderator attempts a penalty', '98000000-0000-4000-8000-000000000008'
  );
reset role;

select is((select error_code from _moderator_penalty), 'forbidden', 'Moderator penalty is forbidden');

-- Enforcement: restricted publishing fails, interaction survives it.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
select throws_ok(
  $$insert into public.routes (gym_id, wall_zone_id, colour, gym_grade, created_by)
    values (
      '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
      'PenaltyProbe', 3, '90000000-0000-4000-8000-000000000001'
    )$$,
  '42501', null,
  'publishing-restricted users cannot create routes'
);
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000002';
select throws_ok(
  $$insert into public.route_photos (id, route_id, storage_path, uploaded_by)
    values (
      '98000000-0000-4000-8000-000000000022', '30000000-0000-4000-8000-000000000001',
      'penalty/vote-target.jpg', '90000000-0000-4000-8000-000000000002'
    )$$,
  '42501', null,
  'suspended users cannot publish photos either'
);
reset role;

insert into public.route_photos (id, route_id, storage_path, uploaded_by) values (
  '98000000-0000-4000-8000-000000000021', '30000000-0000-4000-8000-000000000001',
  'penalty/vote-target.jpg', '90000000-0000-4000-8000-000000000004'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000002';
select throws_ok(
  $$insert into public.route_photo_helpful_votes (photo_id, user_id)
    values (
      '98000000-0000-4000-8000-000000000021', '90000000-0000-4000-8000-000000000002'
    )$$,
  '42501', null,
  'suspended users cannot vote'
);
reset role;

-- Reporting stays open for restricted (but not banned) users.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
insert into public.content_reports (target_type, target_id, category, reporter_id, status) values (
  'route', '30000000-0000-4000-8000-000000000001', 'spam',
  '90000000-0000-4000-8000-000000000001', 'open'
);
reset role;

select is(
  (
    select count(*)
    from public.content_reports
    where reporter_id = '90000000-0000-4000-8000-000000000001'
      and target_id = '30000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'restricted users keep the safety report channel'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000003';
select throws_ok(
  $$insert into public.content_reports (target_type, target_id, category, reporter_id, status) values (
      'route', '30000000-0000-4000-8000-000000000001', 'spam',
      '90000000-0000-4000-8000-000000000003', 'open'
    )$$,
  '42501', null,
  'banned users lose the report channel'
);
reset role;

-- Naturally expired suspensions read as inactive without a cron.
insert into public.user_restrictions (user_id, kind, reason, ends_at, created_by) values (
  '90000000-0000-4000-8000-000000000004', 'timed_suspension',
  'Lapsed suspension fixture', now() - interval '1 hour',
  '90000000-0000-4000-8000-000000000007'
);

select ok(
  not public.can_interact('90000000-0000-4000-8000-000000000002'),
  'active suspension blocks interaction'
);
select ok(
  public.can_interact('90000000-0000-4000-8000-000000000004'),
  'lapsed suspension reads as inactive'
);

-- Reversal revokes the canonical row and links the history.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _penalty_action as
  select id as action_id from public.moderation_actions
  where target_user_id = '90000000-0000-4000-8000-000000000001'
    and action_type = 'publishing_restriction'
  order by created_at desc limit 1;
create temp table _reversal as
  select * from public.admin_reverse_user_penalty(
    (select action_id from _penalty_action),
    'Appeal upheld with a warning', '98000000-0000-4000-8000-000000000009'
  );
reset role;

select ok((select ok from _reversal), 'reversal succeeds');
select is(
  (select count(*) from public.user_restrictions
    where user_id = '90000000-0000-4000-8000-000000000001' and revoked_at is null),
  0::bigint,
  'reversal leaves no active restriction'
);
select ok(
  (
    select reversed_by_action_id is not null
    from public.moderation_actions
    where id = (select action_id from _penalty_action)
  ),
  'original penalty links to its reversal'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _double_reversal as
  select * from public.admin_reverse_user_penalty(
    (select action_id from _penalty_action),
    'Second reversal attempt', '98000000-0000-4000-8000-000000000010'
  );
reset role;

select is((select error_code from _double_reversal), 'invalid_transition', 'double reversal is rejected');

-- Summary carries public context only.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_summary as
  select * from public.admin_user_summary('90000000-0000-4000-8000-000000000002');
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_summary as
  select * from public.admin_user_summary('90000000-0000-4000-8000-000000000002');
reset role;

select is((select username from _moderator_summary), 'Fixture Climber Two', 'Moderator sees the public summary');
select ok(
  (select jsonb_array_length(active_restrictions) >= 1 from _moderator_summary),
  'summary lists the active suspension'
);
select is((select count(*) from _non_staff_summary), 0::bigint, 'ordinary users receive no summary');
select is(
  (
    select count(*)
    from _moderator_summary
    where active_restrictions::text like '%@bloclens%'
      or recent_actions::text like '%@bloclens%'
  ),
  0::bigint,
  'summary never carries email addresses'
);

-- Idempotent replay returns the original outcome.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _replay_apply as
  select * from public.admin_apply_user_penalty(
    '90000000-0000-4000-8000-000000000002', 'timed_suspension', now() + interval '7 days',
    'Replay must not duplicate', '98000000-0000-4000-8000-000000000002'
  );
reset role;

select ok((select ok from _replay_apply), 'replay reports success');
select is(
  (select audit_event_id from _replay_apply),
  (select audit_event_id from _suspend),
  'replay returns the original audit event'
);

-- Audit linkage for applied and reversed penalties.
select ok(
  (
    select count(*) >= 3
    from public.admin_audit_events
    where action_key = 'user.penalty.applied'
      and outcome = 'succeeded'
  ),
  'applied penalties are audited'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where action_key = 'user.penalty.reversed'
      and outcome = 'succeeded'
  ),
  1::bigint,
  'reversal is audited once'
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
      and procedure.proname in ('admin_user_summary', 'admin_apply_user_penalty', 'admin_reverse_user_penalty')
  ),
  'penalty functions are SECURITY DEFINER with an empty search path'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('admin_user_summary', 'admin_apply_user_penalty', 'admin_reverse_user_penalty')
      and (pg_catalog.pg_get_functiondef(procedure.oid) ilike '%logbook%'
        or pg_catalog.pg_get_functiondef(procedure.oid) ilike '%private_note%')
  ),
  0::bigint,
  'penalty logic never references private Logbook content'
);
select ok(
  not has_table_privilege('authenticated', 'public.user_restrictions', 'SELECT'),
  'browser roles cannot read the restrictions table'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_apply_user_penalty(uuid,text,timestamp with time zone,text,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot penalise users'
);

select * from finish();
rollback;
