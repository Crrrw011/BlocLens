-- pgTAP: auditable staff review decisions with role matrix and concurrency guards.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_decide_review',
  array['text', 'uuid', 'text', 'text', 'timestamp with time zone', 'uuid'],
  'protected review decision RPC exists'
);

-- Decision fixtures: one open item per review kind.
insert into public.content_reports (
  id, target_type, target_id, category, reporter_id, details, status
) values
  (
    '97000000-0000-4000-8000-000000000001', 'route',
    '30000000-0000-4000-8000-000000000001', 'spam',
    '90000000-0000-4000-8000-000000000001', 'Decision matrix fixture',
    'open'
  ),
  (
    '97000000-0000-4000-8000-000000000002', 'route',
    '30000000-0000-4000-8000-000000000002', 'harassment',
    '90000000-0000-4000-8000-000000000002', 'Escalation fixture',
    'open'
  );

insert into public.route_corrections (
  id, route_id, submitted_by, issue_key, explanation, status
) values
  (
    '97000000-0000-4000-8000-000000000011', '30000000-0000-4000-8000-000000000001',
    '90000000-0000-4000-8000-000000000001', 'grade', 'Grade looks soft', 'open'
  ),
  (
    '97000000-0000-4000-8000-000000000012', '30000000-0000-4000-8000-000000000002',
    '90000000-0000-4000-8000-000000000002', 'holds', 'Hold text outdated', 'open'
  );

insert into public.route_removal_reports (id, route_id, reported_by, status) values (
  '97000000-0000-4000-8000-000000000021', '30000000-0000-4000-8000-000000000003',
  '90000000-0000-4000-8000-000000000001', 'open'
);

insert into public.route_merge_suggestions (
  id, source_route_id, proposed_canonical_route_id, suggested_by, reason, status
) values (
  '97000000-0000-4000-8000-000000000031',
  '30000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000004',
  '90000000-0000-4000-8000-000000000002', 'Likely duplicate fixture', 'proposed'
);

-- A Moderator dismisses a report and escalates a severe one.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_dismiss as
  select * from public.admin_decide_review(
    'content_report', '97000000-0000-4000-8000-000000000001', 'dismiss',
    'Spam pattern confirmed by a Moderator', (select updated_at from public.content_reports where id = '97000000-0000-4000-8000-000000000001'),
    '97000000-0000-4000-8000-000000000101'
  );
create temp table _moderator_escalate as
  select * from public.admin_decide_review(
    'content_report', '97000000-0000-4000-8000-000000000002', 'escalate',
    'Severe report needs a second pair of eyes', (select updated_at from public.content_reports where id = '97000000-0000-4000-8000-000000000002'),
    '97000000-0000-4000-8000-000000000102'
  );
reset role;

select ok((select ok from _moderator_dismiss), 'Moderator dismisses a report');
select is(
  (select status from public.content_reports where id = '97000000-0000-4000-8000-000000000001'),
  'dismissed'::public.report_status,
  'dismissal closes the report'
);
select ok((select ok from _moderator_escalate), 'Moderator escalates a severe report');
select is(
  (select status from public.content_reports where id = '97000000-0000-4000-8000-000000000002'),
  'under_review'::public.report_status,
  'escalation moves the report to under review'
);

-- Non-staff attempts are rejected as outcome rows without changing state.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_hide as
  select * from public.admin_decide_review(
    'content_report', '97000000-0000-4000-8000-000000000002', 'hide',
    'Attempted hide from a non-staff account', now(),
    '97000000-0000-4000-8000-000000000103'
  );
reset role;

select ok(not (select ok from _non_staff_hide), 'non-staff hide is rejected');
select is(
  (select error_code from _non_staff_hide),
  'forbidden',
  'non-staff rejection carries the forbidden code'
);
select is(
  (select status from public.content_reports where id = '97000000-0000-4000-8000-000000000002'),
  'under_review'::public.report_status,
  'rejected hide leaves the item untouched'
);

-- Accepting a correction is Administrator-only; rejecting is shared.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_accept as
  select * from public.admin_decide_review(
    'route_correction', '97000000-0000-4000-8000-000000000011', 'accept_correction',
    'Moderator attempts to accept a correction', now(),
    '97000000-0000-4000-8000-000000000104'
  );
create temp table _moderator_reject as
  select * from public.admin_decide_review(
    'route_correction', '97000000-0000-4000-8000-000000000012', 'reject_correction',
    'Correction does not match the wall', (select updated_at from public.route_corrections where id = '97000000-0000-4000-8000-000000000012'),
    '97000000-0000-4000-8000-000000000105'
  );
reset role;

select ok(not (select ok from _moderator_accept), 'Moderator cannot accept a correction');
select is((select error_code from _moderator_accept), 'forbidden', 'accept rejection is forbidden');
select ok((select ok from _moderator_reject), 'Moderator rejects a correction');
select is(
  (select status from public.route_corrections where id = '97000000-0000-4000-8000-000000000012'),
  'rejected'::public.correction_status,
  'rejection closes the correction'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _admin_accept as
  select * from public.admin_decide_review(
    'route_correction', '97000000-0000-4000-8000-000000000011', 'accept_correction',
    'Grade correction verified against the wall', (select updated_at from public.route_corrections where id = '97000000-0000-4000-8000-000000000011'),
    '97000000-0000-4000-8000-000000000106'
  );
create temp table _admin_approve_merge as
  select * from public.admin_decide_review(
    'merge_suggestion', '97000000-0000-4000-8000-000000000031', 'accept_correction',
    'Duplicate approved for a later merge', (select updated_at from public.route_merge_suggestions where id = '97000000-0000-4000-8000-000000000031'),
    '97000000-0000-4000-8000-000000000107'
  );
reset role;

select ok((select ok from _admin_accept), 'Administrator accepts a correction');
select is(
  (select reviewed_by from public.route_corrections where id = '97000000-0000-4000-8000-000000000011'),
  '90000000-0000-4000-8000-000000000007',
  'acceptance records the deciding Administrator'
);
select ok((select ok from _admin_approve_merge), 'Administrator approves a merge suggestion');
select is(
  (select status from public.route_merge_suggestions where id = '97000000-0000-4000-8000-000000000031'),
  'approved'::public.merge_status,
  'approval moves the merge suggestion forward without executing it'
);

-- Hiding changes the canonical target; restoring reverses it.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _admin_hide as
  select * from public.admin_decide_review(
    'content_report', '97000000-0000-4000-8000-000000000002', 'hide',
    'Severe content hidden pending review', (select updated_at from public.content_reports where id = '97000000-0000-4000-8000-000000000002'),
    '97000000-0000-4000-8000-000000000108'
  );
reset role;

select ok((select ok from _admin_hide), 'Administrator hides reported content');
select is(
  (select moderation_status from public.routes where id = '30000000-0000-4000-8000-000000000002'),
  'temporarily_hidden'::public.moderation_status,
  'hide changes the canonical route target'
);
select is(
  (
    select count(*)
    from public.moderation_actions
    where target_id = '30000000-0000-4000-8000-000000000002'
      and action_type = 'hide'
      and performed_by = '90000000-0000-4000-8000-000000000007'
  ),
  1::bigint,
  'hide records one staff-performed canonical moderation action'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_restore as
  select * from public.admin_decide_review(
    'content_report', '97000000-0000-4000-8000-000000000002', 'restore',
    'Content reviewed and cleared', (select updated_at from public.content_reports where id = '97000000-0000-4000-8000-000000000002'),
    '97000000-0000-4000-8000-000000000109'
  );
reset role;

select ok((select ok from _moderator_restore), 'Moderator restores cleared content');
select is(
  (select moderation_status from public.routes where id = '30000000-0000-4000-8000-000000000002'),
  'visible'::public.moderation_status,
  'restore returns the canonical route target'
);

-- Stale versions conflict instead of overwriting.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_version as
  select updated_at as version from public.route_removal_reports
  where id = '97000000-0000-4000-8000-000000000021';
reset role;

-- now() is frozen per transaction and the updated_at trigger reuses it, so the
-- trigger is disabled for one statement to advance the version honestly.
alter table public.route_removal_reports
  disable trigger route_removal_reports_set_updated_at;
update public.route_removal_reports
set updated_at = now() + interval '1 minute'
where id = '97000000-0000-4000-8000-000000000021';
alter table public.route_removal_reports
  enable trigger route_removal_reports_set_updated_at;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_decision as
  select * from public.admin_decide_review(
    'removal_report', '97000000-0000-4000-8000-000000000021', 'dismiss',
    'Dismissal against a stale version', (select version from _stale_version),
    '97000000-0000-4000-8000-000000000110'
  );
reset role;

select ok(not (select ok from _stale_decision), 'stale decision is rejected');
select is((select error_code from _stale_decision), 'conflict', 'stale rejection carries the conflict code');
select is(
  (select status from public.route_removal_reports where id = '97000000-0000-4000-8000-000000000021'),
  'open'::public.report_status,
  'conflict leaves the item untouched'
);

-- Replays with the same idempotency key return the original outcome once.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _fresh_version as
  select updated_at as version from public.route_removal_reports
  where id = '97000000-0000-4000-8000-000000000021';
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _first_dismiss as
  select * from public.admin_decide_review(
    'removal_report', '97000000-0000-4000-8000-000000000021', 'dismiss',
    'Dismissal with idempotency protection', (select version from _fresh_version),
    '97000000-0000-4000-8000-000000000111'
  );
create temp table _replay_dismiss as
  select * from public.admin_decide_review(
    'removal_report', '97000000-0000-4000-8000-000000000021', 'dismiss',
    'Dismissal replay must not duplicate', now(),
    '97000000-0000-4000-8000-000000000111'
  );
reset role;

select ok((select ok from _first_dismiss), 'first dismissal succeeds');
select ok((select ok from _replay_dismiss), 'replay reports success without duplicating');
select is(
  (select audit_event_id from _replay_dismiss),
  (select audit_event_id from _first_dismiss),
  'replay returns the original audit event'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where idempotency_key = '97000000-0000-4000-8000-000000000111'
  ),
  1::bigint,
  'idempotent replay leaves exactly one audit event'
);

-- Invalid transitions are rejected as outcome rows.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _invalid_dismiss_correction as
  select * from public.admin_decide_review(
    'route_correction', '97000000-0000-4000-8000-000000000011', 'dismiss',
    'Dismiss is not a correction transition', now(),
    '97000000-0000-4000-8000-000000000112'
  );
create temp table _invalid_escalate_merge as
  select * from public.admin_decide_review(
    'merge_suggestion', '97000000-0000-4000-8000-000000000031', 'escalate',
    'Escalation is not a merge transition', now(),
    '97000000-0000-4000-8000-000000000113'
  );
create temp table _missing_item as
  select * from public.admin_decide_review(
    'content_report', '97000000-0000-4000-8000-000000000099', 'dismiss',
    'Decision on a missing item', now(),
    '97000000-0000-4000-8000-000000000114'
  );
reset role;

select is((select error_code from _invalid_dismiss_correction), 'invalid_transition', 'dismiss on a correction is rejected');
select is((select error_code from _invalid_escalate_merge), 'invalid_transition', 'escalate on a merge is rejected');
select is((select error_code from _missing_item), 'not_found', 'missing items report not_found');

-- Every material and rejected outcome is audited without reporter identity leakage.
select ok(
  (
    select count(*) >= 5
    from public.admin_audit_events
    where action_key = 'review.decision'
      and outcome = 'succeeded'
  ),
  'successful decisions are audited'
);
select ok(
  (
    select count(*) >= 3
    from public.admin_audit_events
    where action_key = 'review.decision'
      and outcome = 'failed'
  ),
  'forbidden, conflict, and invalid outcomes are audited'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where action_key = 'review.decision'
      and (before_summary::text ~* 'reporter' or after_summary::text ~* 'reporter')
  ),
  0::bigint,
  'decision audit summaries never carry reporter identity'
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
      and procedure.proname = 'admin_decide_review'
  ),
  'decision function is SECURITY DEFINER with an empty search path'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'admin_decide_review'
      and pg_catalog.pg_get_functiondef(procedure.oid) ilike '%logbook%'
  ),
  0::bigint,
  'decision logic never references private Logbook content'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_decide_review(text,uuid,text,text,timestamp with time zone,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot decide reviews'
);

select * from finish();
rollback;
