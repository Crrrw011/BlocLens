-- pgTAP: administrator-only gym claim decisions with membership effects.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_decide_gym_claim',
  array['uuid', 'text', 'text', 'timestamp with time zone', 'uuid'],
  'gym claim decision RPC exists'
);

insert into public.gym_claims (
  id, gym_id, applicant_id, domain_email, verification_method, status
) values
  (
    '99000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
    '90000000-0000-4000-8000-000000000005', 'manager@example.invalid', 'manual_review', 'submitted'
  ),
  (
    '99000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002',
    '90000000-0000-4000-8000-000000000004', 'owner@example.invalid', 'domain_email', 'submitted'
  );

-- Approval creates the verified membership.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _approve as
  select * from public.admin_decide_gym_claim(
    '99000000-0000-4000-8000-000000000001', 'approved',
    'Domain matches the gym website',
    (select updated_at from public.gym_claims where id = '99000000-0000-4000-8000-000000000001'),
    '99000000-0000-4000-8000-000000000011'
  );
reset role;

select ok((select ok from _approve), 'Administrator approves a gym claim');
select is(
  (select status from public.gym_claims where id = '99000000-0000-4000-8000-000000000001'),
  'approved'::public.claim_status,
  'approval moves the claim forward'
);
select is(
  (
    select count(*)
    from public.gym_memberships
    where gym_id = '10000000-0000-4000-8000-000000000001'
      and user_id = '90000000-0000-4000-8000-000000000005'
      and role = 'verified_representative'
      and revoked_at is null
  ),
  1::bigint,
  'approval creates an active verified membership'
);
select is(
  (select reviewer_id from public.gym_claims where id = '99000000-0000-4000-8000-000000000001'),
  '90000000-0000-4000-8000-000000000007',
  'approval records the reviewer'
);

-- Rejection creates no membership.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _reject as
  select * from public.admin_decide_gym_claim(
    '99000000-0000-4000-8000-000000000002', 'rejected',
    'Domain does not match any official contact',
    (select updated_at from public.gym_claims where id = '99000000-0000-4000-8000-000000000002'),
    '99000000-0000-4000-8000-000000000012'
  );
reset role;

select ok((select ok from _reject), 'Administrator rejects a gym claim');
select is(
  (
    select count(*)
    from public.gym_memberships
    where gym_id = '10000000-0000-4000-8000-000000000002'
      and user_id = '90000000-0000-4000-8000-000000000004'
  ),
  0::bigint,
  'rejection creates no membership'
);

-- Decided claims cannot be decided again; notes are mandatory.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _redecide as
  select * from public.admin_decide_gym_claim(
    '99000000-0000-4000-8000-000000000001', 'rejected',
    'Second decision attempt',
    (select updated_at from public.gym_claims where id = '99000000-0000-4000-8000-000000000001'),
    '99000000-0000-4000-8000-000000000013'
  );
select throws_ok(
  $$select * from public.admin_decide_gym_claim(
      '99000000-0000-4000-8000-000000000002', 'approved', '',
      now(), '99000000-0000-4000-8000-000000000014'
    )$$,
  '22023', 'invalid gym claim decision',
  'missing review note is rejected'
);
select throws_ok(
  $$select * from public.admin_decide_gym_claim(
      '99000000-0000-4000-8000-000000000002', 'maybe',
      'Invalid decision value', now(), '99000000-0000-4000-8000-000000000015'
    )$$,
  '22023', 'invalid gym claim decision',
  'unknown decisions are rejected'
);
reset role;

select is((select error_code from _redecide), 'invalid_transition', 'decided claims cannot be redecided');

-- Moderators cannot decide claims; stale versions conflict.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_claim as
  select * from public.admin_decide_gym_claim(
    '99000000-0000-4000-8000-000000000002', 'approved',
    'Moderator attempts a claim decision', now(),
    '99000000-0000-4000-8000-000000000016'
  );
reset role;

select is((select error_code from _moderator_claim), 'forbidden', 'Moderator claim decision is forbidden');

insert into public.gym_claims (
  id, gym_id, applicant_id, domain_email, verification_method, status
) values (
  '99000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003',
  '90000000-0000-4000-8000-000000000005', 'stale@example.invalid', 'manual_review', 'submitted'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _stale_claim as
  select * from public.admin_decide_gym_claim(
    '99000000-0000-4000-8000-000000000003', 'approved',
    'Decision against a stale version', now() - interval '1 hour',
    '99000000-0000-4000-8000-000000000017'
  );
reset role;

select is((select error_code from _stale_claim), 'conflict', 'stale claim decision conflicts');
select is(
  (select status from public.gym_claims where id = '99000000-0000-4000-8000-000000000003'),
  'submitted'::public.claim_status,
  'conflict leaves the claim untouched'
);

-- Audit coverage and privilege posture.
select is(
  (
    select count(*)
    from public.admin_audit_events
    where action_key = 'gym.claim.decided'
      and outcome = 'succeeded'
  ),
  2::bigint,
  'claim decisions are audited'
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
      and procedure.proname = 'admin_decide_gym_claim'
  ),
  'claim function is SECURITY DEFINER with an empty search path'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_decide_gym_claim(uuid,text,text,timestamp with time zone,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot decide claims'
);

select * from finish();
rollback;
