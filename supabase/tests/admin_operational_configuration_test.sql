-- pgTAP: allow-listed operational configuration with version guard.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_update_configuration',
  array['text', 'jsonb', 'text', 'integer', 'uuid'],
  'configuration update RPC exists'
);

select is(
  (select count(*) from public.operational_configuration),
  4::bigint,
  'four seeded configuration keys exist'
);

-- An Administrator updates an allow-listed key.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _update_order as
  select * from public.admin_update_configuration(
    'review.queue.order', '"severity_first"',
    'Moderators asked for severe-first triage', 1,
    '99000000-0000-4000-8000-000000000001'
  );
reset role;

select ok((select ok from _update_order), 'Administrator updates an allow-listed key');
select is(
  (select version from public.operational_configuration where key = 'review.queue.order'),
  2,
  'update bumps the version'
);

-- Unknown keys and frozen product rules raise instead of storing.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select throws_ok(
  $$select * from public.admin_update_configuration(
      'grades.community_formula', '"median"',
      'Attempt to configure grade math', 1,
      '99000000-0000-4000-8000-000000000002'
    )$$,
  '22023', 'unknown configuration key',
  'grade calculations are not configurable'
);
select throws_ok(
  $$select * from public.admin_update_configuration(
      'trust.helpful_threshold', '5',
      'Attempt to configure trust', 1,
      '99000000-0000-4000-8000-000000000003'
    )$$,
  '22023', 'unknown configuration key',
  'trust thresholds are not configurable'
);
select throws_ok(
  $$select * from public.admin_update_configuration(
      'privacy.logbook_default', '"public"',
      'Attempt to configure privacy', 1,
      '99000000-0000-4000-8000-000000000004'
    )$$,
  '22023', 'unknown configuration key',
  'privacy defaults are not configurable'
);
select throws_ok(
  $$select * from public.admin_update_configuration(
      'overview.default_range', '"13d"',
      'Invalid range value', 1,
      '99000000-0000-4000-8000-000000000005'
    )$$,
  '22023', 'invalid configuration value',
  'mistyped values are rejected'
);
select throws_ok(
  $$select * from public.admin_update_configuration(
      'copy.reason_templates', '[]',
      'Empty templates', 1,
      '99000000-0000-4000-8000-000000000006'
    )$$,
  '22023', 'invalid configuration value',
  'empty template lists are rejected'
);
reset role;

-- Moderators cannot change configuration.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_config as
  select * from public.admin_update_configuration(
    'overview.default_range', '"7d"',
    'Moderator attempts configuration', 1,
    '99000000-0000-4000-8000-000000000007'
  );
reset role;

select is((select error_code from _moderator_config), 'forbidden', 'Moderator update is forbidden');
select is(
  (select value from public.operational_configuration where key = 'overview.default_range'),
  '"30d"'::jsonb,
  'denied update leaves the seeded value (version guard untouched)'
);

-- Stale versions conflict; replays return the original outcome.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_config as
  select * from public.admin_update_configuration(
    'review.queue.order', '"oldest_first"',
    'Update against a stale version', 1,
    '99000000-0000-4000-8000-000000000008'
  );
create temp table _replay_config as
  select * from public.admin_update_configuration(
    'review.queue.order', '"newest_first"',
    'Replay must not rewrite the value', 1,
    '99000000-0000-4000-8000-000000000001'
  );
reset role;

select is((select error_code from _stale_config), 'conflict', 'stale update carries the conflict code');
select ok((select ok from _replay_config), 'replay reports success');
select is(
  (select value from public.operational_configuration where key = 'review.queue.order'),
  '"severity_first"'::jsonb,
  'replay leaves the first value in place'
);
select is(
  (select audit_event_id from _replay_config),
  (select audit_event_id from _update_order),
  'replay returns the original audit event'
);

-- Browser roles cannot write configuration directly; anonymous clients cannot read it.
select ok(
  not has_table_privilege('authenticated', 'public.operational_configuration', 'UPDATE'),
  'browser roles cannot update configuration directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.operational_configuration', 'DELETE'),
  'browser roles cannot delete configuration directly'
);
select ok(
  not has_table_privilege('anon', 'public.operational_configuration', 'SELECT'),
  'anonymous clients cannot read configuration'
);
select ok(
  (
    select count(*) >= 1
    from public.admin_audit_events
    where action_key = 'config.updated'
      and outcome = 'succeeded'
  ),
  'configuration updates are audited'
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
      and procedure.proname = 'admin_update_configuration'
  ),
  'configuration function is SECURITY DEFINER with an empty search path'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_update_configuration(text,jsonb,text,integer,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot change configuration'
);

select * from finish();
rollback;
