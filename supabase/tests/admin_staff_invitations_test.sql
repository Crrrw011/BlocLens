-- pgTAP: closed administrator staff invitation creation and acceptance.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'create_staff_invitation',
  array['text', 'public.app_role', 'bytea', 'timestamp with time zone', 'text'],
  'protected staff invitation creation RPC exists'
);
select has_function(
  'public',
  'accept_staff_invitation',
  array['bytea'],
  'protected staff invitation acceptance RPC exists'
);

insert into public.staff_capabilities (
  user_id, can_manage_administrators, granted_by
) values (
  '90000000-0000-4000-8000-000000000007',
  true,
  '90000000-0000-4000-8000-000000000007'
)
on conflict (user_id) do update
set can_manage_administrators = excluded.can_manage_administrators,
    granted_by = excluded.granted_by,
    granted_at = now();

insert into public.app_user_roles (user_id, role)
values ('90000000-0000-4000-8000-000000000002', 'admin')
on conflict (user_id, role) do update
set revoked_at = null;

-- The bootstrap owner may invite either staff role.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _owner_moderator_invite as
  select * from public.create_staff_invitation(
    'fixture-climber-1@bloclens.invalid',
    'moderator',
    decode(repeat('11', 32), 'hex'),
    now() + interval '24 hours',
    'Add a Moderator for invitation verification'
  );
create temp table _owner_administrator_invite as
  select * from public.create_staff_invitation(
    'fixture-climber-3@bloclens.invalid',
    'admin',
    decode(repeat('12', 32), 'hex'),
    now() + interval '24 hours',
    'Add an Administrator for invitation verification'
  );
reset role;

select ok(
  (select invitation_created from _owner_moderator_invite),
  'bootstrap owner may invite a Moderator'
);
select ok(
  (select invitation_created from _owner_administrator_invite),
  'bootstrap owner may invite an Administrator'
);

-- An ordinary Administrator may invite Moderators but not Administrators.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000002';
create temp table _administrator_moderator_invite as
  select * from public.create_staff_invitation(
    'fixture-trusted@bloclens.invalid',
    'moderator',
    decode(repeat('13', 32), 'hex'),
    now() + interval '24 hours',
    'Add a Moderator from an ordinary Administrator'
  );
create temp table _administrator_admin_invite as
  select * from public.create_staff_invitation(
    'fixture-gym-official@bloclens.invalid',
    'admin',
    decode(repeat('14', 32), 'hex'),
    now() + interval '24 hours',
    'Attempt an Administrator invitation without owner capability'
  );
reset role;

select ok(
  (select invitation_created from _administrator_moderator_invite),
  'ordinary Administrator may invite a Moderator'
);
select is(
  (select result_status from _administrator_admin_invite),
  'forbidden',
  'ordinary Administrator cannot invite an Administrator'
);
select is(
  (
    select count(*)
    from public.staff_invitations
    where token_digest = decode(repeat('14', 32), 'hex')
  ),
  0::bigint,
  'forbidden Administrator invitation creates no invitation row'
);

-- A Moderator cannot invite any staff role.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_invite_attempt as
  select * from public.create_staff_invitation(
    'moderator-attempt@bloclens.invalid',
    'moderator',
    decode(repeat('15', 32), 'hex'),
    now() + interval '24 hours',
    'Attempt a staff invitation from a Moderator'
  );
reset role;

select is(
  (select result_status from _moderator_invite_attempt),
  'forbidden',
  'Moderator invitation attempt is rejected'
);

-- Expired pending invitations become terminal before replacement so the
-- immutable partial uniqueness predicate remains valid.
insert into public.staff_invitations (
  id, email, role, token_digest, invited_by, created_at, expires_at
) values (
  '95000000-0000-4000-8000-000000000001',
  'Expired.Replace@BlocLens.invalid',
  'moderator',
  decode(repeat('16', 32), 'hex'),
  '90000000-0000-4000-8000-000000000007',
  now() - interval '2 hours',
  now() - interval '1 hour'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _replacement_invite as
  select * from public.create_staff_invitation(
    ' expired.replace@bloclens.invalid ',
    'moderator',
    decode(repeat('17', 32), 'hex'),
    now() + interval '24 hours',
    'Replace an expired invitation'
  );
reset role;

select ok(
  (select invitation_created from _replacement_invite),
  'expired pending invitation can be replaced atomically'
);
select ok(
  (
    select expired_at is not null
    from public.staff_invitations
    where id = '95000000-0000-4000-8000-000000000001'
  ),
  'replacement marks the prior expired invitation terminal'
);
select is(
  (
    select count(*)
    from public.staff_invitations
    where lower(btrim(email)) = 'expired.replace@bloclens.invalid'
      and accepted_at is null
      and revoked_at is null
      and expired_at is null
  ),
  1::bigint,
  'replacement leaves exactly one pending invitation for the normalized email'
);

-- Revoked invitations cannot be accepted.
update public.staff_invitations
set revoked_at = now(),
    revoked_by = '90000000-0000-4000-8000-000000000007'
where token_digest = decode(repeat('11', 32), 'hex');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _revoked_acceptance as
  select * from public.accept_staff_invitation(decode(repeat('11', 32), 'hex'));
reset role;

select is(
  (select result_status from _revoked_acceptance),
  'revoked',
  'revoked invitation cannot be accepted'
);
select ok(
  not (select invitation_accepted from _revoked_acceptance),
  'revoked invitation does not assign a role'
);

-- Expired invitations become terminal and cannot be accepted.
update public.staff_invitations
set created_at = now() - interval '2 hours',
    expires_at = now() - interval '1 hour'
where token_digest = decode(repeat('12', 32), 'hex');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000003';
create temp table _expired_acceptance as
  select * from public.accept_staff_invitation(decode(repeat('12', 32), 'hex'));
reset role;

select is(
  (select result_status from _expired_acceptance),
  'expired',
  'expired invitation cannot be accepted'
);
select ok(
  (
    select expired_at is not null
    from public.staff_invitations
    where token_digest = decode(repeat('12', 32), 'hex')
  ),
  'expired acceptance marks the invitation terminal'
);

-- A valid invitation is accepted once and activates exactly the invited role.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000004';
create temp table _first_acceptance as
  select * from public.accept_staff_invitation(decode(repeat('13', 32), 'hex'));
create temp table _second_acceptance as
  select * from public.accept_staff_invitation(decode(repeat('13', 32), 'hex'));
reset role;

select ok(
  (select invitation_accepted from _first_acceptance),
  'valid invitation is accepted'
);
select is(
  (select assigned_role from _first_acceptance),
  'moderator'::public.app_role,
  'acceptance assigns only the invited role'
);
select is(
  (select result_status from _second_acceptance),
  'already_accepted',
  'accepted invitation cannot be consumed twice'
);
select is(
  (
    select count(*)
    from public.app_user_roles
    where user_id = '90000000-0000-4000-8000-000000000004'
      and role = 'moderator'
      and revoked_at is null
  ),
  1::bigint,
  'acceptance leaves one active invited role assignment'
);

-- Acceptance revalidates the inviter's current authority inside the same
-- transaction, including the owner capability for Administrator invitations.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _authority_revalidation_invite as
  select * from public.create_staff_invitation(
    'fixture-gym-official@bloclens.invalid',
    'admin',
    decode(repeat('18', 32), 'hex'),
    now() + interval '24 hours',
    'Verify authority is revalidated during acceptance'
  );
reset role;

update public.staff_capabilities
set can_manage_administrators = false
where user_id = '90000000-0000-4000-8000-000000000007';

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000005';
create temp table _authority_revalidation_acceptance as
  select * from public.accept_staff_invitation(decode(repeat('18', 32), 'hex'));
reset role;

select is(
  (select result_status from _authority_revalidation_acceptance),
  'inviter_not_authorized',
  'acceptance rejects an Administrator invite after owner capability is removed'
);
select is(
  (
    select count(*)
    from public.app_user_roles
    where user_id = '90000000-0000-4000-8000-000000000005'
      and role = 'admin'
      and revoked_at is null
  ),
  0::bigint,
  'failed authority revalidation assigns no Administrator role'
);

-- Every material creation, expiry, acceptance, rejection, and assignment
-- outcome leaves an append-only audit event without token or email data.
select ok(
  (
    select count(*) >= 4
    from public.admin_audit_events
    where action_key = 'staff.invitation.created'
      and outcome = 'succeeded'
  ),
  'successful invitation creation is audited'
);
select ok(
  (
    select count(*) >= 2
    from public.admin_audit_events
    where action_key = 'staff.invitation.create_rejected'
      and outcome = 'failed'
  ),
  'forbidden invitation attempts are audited'
);
select ok(
  (
    select count(*) >= 2
    from public.admin_audit_events
    where action_key = 'staff.invitation.expired'
      and outcome = 'succeeded'
  ),
  'invitation expiry is audited'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where action_key = 'staff.invitation.accepted'
      and outcome = 'succeeded'
      and target_id = (select invitation_id from _first_acceptance)
  ),
  1::bigint,
  'successful invitation acceptance is audited once'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where action_key = 'staff.role.assigned'
      and outcome = 'succeeded'
      and actor_id = '90000000-0000-4000-8000-000000000004'
  ),
  1::bigint,
  'staff role assignment is audited once'
);
select ok(
  (
    select count(*) >= 4
    from public.admin_audit_events
    where action_key = 'staff.invitation.acceptance_rejected'
      and outcome = 'failed'
  ),
  'revoked, expired, repeated, and unauthorized acceptance outcomes are audited'
);
select is(
  (
    select count(*)
    from public.admin_audit_events
    where before_summary::text ~* '(token|@bloclens)'
       or after_summary::text ~* '(token|@bloclens)'
  ),
  0::bigint,
  'audit summaries contain neither invitation tokens nor email addresses'
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
      and procedure.proname in ('create_staff_invitation', 'accept_staff_invitation')
  ),
  'invitation functions are SECURITY DEFINER with an empty search path'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.create_staff_invitation(text,public.app_role,bytea,timestamp with time zone,text)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot create staff invitations'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.accept_staff_invitation(bytea)'::regprocedure,
    'EXECUTE'
  ),
  'authenticated invite sessions may accept a staff invitation'
);

-- Possession of a token is not proof that an unconfirmed email is owned.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select * from public.create_staff_invitation(
  'fixture-climber-3@bloclens.invalid', 'moderator', decode(repeat('19', 32), 'hex'),
  now() + interval '24 hours', 'Verify confirmed recipient identity'
);
reset role;
update auth.users set email_confirmed_at = null
where id = '90000000-0000-4000-8000-000000000003';
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000003';
select is((select invitation_accepted from public.accept_staff_invitation(decode(repeat('19', 32), 'hex'))),
  false, 'unconfirmed email cannot accept an invitation');
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select throws_ok($$select * from public.create_staff_invitation(
  'null-input@bloclens.invalid', 'moderator', null, now() + interval '24 hours', 'Null digest test'
)$$, '22023', 'invalid staff invitation input', 'null inputs fail at the protected validation boundary');
reset role;

select * from finish();
rollback;
