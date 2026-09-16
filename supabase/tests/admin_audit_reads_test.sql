-- pgTAP: staff-only audit browsing and 90-day IP redaction.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_list_audit',
  array['uuid', 'text', 'text', 'text', 'timestamp with time zone', 'timestamp with time zone', 'text', 'integer'],
  'audit list RPC exists'
);
select has_function(
  'private',
  'redact_expired_admin_audit_ips',
  array['timestamp with time zone'],
  'IP redaction routine exists'
);

-- Audit fixtures with distinct outcomes and one raw IP each.
insert into public.admin_audit_events (
  actor_id, action_key, target_type, target_id, reason, outcome,
  correlation_id, idempotency_key, source_ip
) values
  (
    '90000000-0000-4000-8000-000000000007', 'review.decision', 'content_report',
    '96000000-0000-4000-8000-000000000001', 'Audit browse fixture', 'succeeded',
    '93000000-0000-4000-8000-000000000001', '94000000-0000-4000-8000-000000000001',
    '203.0.113.7'
  ),
  (
    '90000000-0000-4000-8000-000000000006', 'review.decision', 'content_report',
    '96000000-0000-4000-8000-000000000002', 'Failed audit fixture', 'failed',
    '93000000-0000-4000-8000-000000000002', '94000000-0000-4000-8000-000000000002',
    '203.0.113.8'
  );

-- Staff filter by outcome; ordinary users see nothing.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _audit_failed as
  select * from public.admin_list_audit(
    null, null, null, 'failed',
    now() - interval '30 days', now() + interval '1 minute', null, 100
  );
create temp table _audit_actor as
  select * from public.admin_list_audit(
    '90000000-0000-4000-8000-000000000007', null, null, null,
    now() - interval '30 days', now() + interval '1 minute', null, 100
  );
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_audit as
  select * from public.admin_list_audit(
    null, null, null, null,
    now() - interval '30 days', now() + interval '1 minute', null, 100
  );
reset role;

select ok(
  (select count(*) >= 1 from _audit_failed),
  'staff filters audit events by outcome'
);
select ok(
  (
    select bool_and(outcome = 'failed')
    from _audit_failed
  ),
  'outcome filter returns only matching rows'
);
select ok(
  (select count(*) >= 1 from _audit_actor),
  'staff filters audit events by actor'
);
select is((select count(*) from _non_staff_audit), 0::bigint, 'ordinary users see no audit rows');

-- Read projections never carry raw IPs, even before redaction.
select is(
  (
    select count(*)
    from _audit_failed
    where to_jsonb(_audit_failed)::text like '%203.0.113%'
  ),
  0::bigint,
  'browse projections never carry raw IPs'
);

-- Cursor pagination is stable and bounded.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _audit_first as
  select * from public.admin_list_audit(
    null, null, null, null,
    now() - interval '30 days', now() + interval '1 minute', null, 1
  );
create temp table _audit_second as
  select * from public.admin_list_audit(
    null, null, null, null,
    now() - interval '30 days', now() + interval '1 minute',
    (select created_at::text || '|' || id::text from _audit_first limit 1),
    100
  );
reset role;

select is(
  (
    select count(*)
    from _audit_second second
    where second.id = (select id from _audit_first limit 1)
  ),
  0::bigint,
  'cursor continuation overlaps no previously returned row'
);

-- Invalid ranges and filters raise at the boundary.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select throws_ok(
  $$select * from public.admin_list_audit(
      null, null, null, null, now(), now() - interval '1 day', null, 10
    )$$,
  '22023', 'invalid audit range',
  'reversed ranges are rejected'
);
select throws_ok(
  $$select * from public.admin_list_audit(
      null, 'drop table;', null, null,
      now() - interval '1 day', now(), null, 10
    )$$,
  '22023', 'invalid audit action filter',
  'action filters reject injection-shaped input'
);
select throws_ok(
  $$select * from public.admin_list_audit(
      null, null, null, 'bogus',
      now() - interval '1 day', now(), null, 10
    )$$,
  '22023', 'invalid audit outcome filter',
  'unknown outcomes are rejected'
);
reset role;

-- Redaction replaces old raw IPs with stable digests and keeps recent ones.
update public.admin_audit_events
set created_at = now() - interval '100 days'
where idempotency_key = '94000000-0000-4000-8000-000000000001';

select is(
  private.redact_expired_admin_audit_ips(now() - interval '90 days'),
  1,
  'redaction reports exactly the expired row'
);
select is(
  (
    select source_ip
    from public.admin_audit_events
    where idempotency_key = '94000000-0000-4000-8000-000000000001'
  ),
  null,
  'expired raw IP is removed'
);
select ok(
  (
    select source_ip_digest like 'v1:%'
    from public.admin_audit_events
    where idempotency_key = '94000000-0000-4000-8000-000000000001'
  ),
  'expired IP leaves a versioned digest'
);
select is(
  (
    select source_ip::text
    from public.admin_audit_events
    where idempotency_key = '94000000-0000-4000-8000-000000000002'
  ),
  '203.0.113.8/32',
  'recent raw IP is retained'
);
select is(
  private.redact_expired_admin_audit_ips(now() - interval '90 days'),
  0,
  'repeated redaction runs change nothing'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where source_ip_digest is not null
      and (source_ip_digest like '%203.0.113%' or source_ip_digest like '%@bloclens%')
  ),
  0::bigint,
  'digests never embed raw IPs or emails'
);

-- Browser roles hold no write grants on the audit table.
select ok(
  not has_table_privilege('authenticated', 'public.admin_audit_events', 'UPDATE'),
  'authenticated clients lack audit UPDATE privilege'
);
select ok(
  not has_table_privilege('authenticated', 'public.admin_audit_events', 'DELETE'),
  'authenticated clients lack audit DELETE privilege'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_list_audit(uuid,text,text,text,timestamp with time zone,timestamp with time zone,text,integer)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot browse audit events'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'private.redact_expired_admin_audit_ips(timestamp with time zone)'::regprocedure,
    'EXECUTE'
  ),
  'browser roles cannot run IP redaction'
);

select * from finish();
rollback;
