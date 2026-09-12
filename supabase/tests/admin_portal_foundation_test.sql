-- pgTAP: administrator portal staff access, invitation secrecy, and audit immutability.
create extension if not exists pgtap;

begin;
select no_plan();

select has_table('public', 'staff_capabilities', 'staff capabilities table exists');
select has_table('public', 'staff_invitations', 'staff invitations table exists');
select has_table('public', 'admin_audit_events', 'administrator audit table exists');

select has_function(
  'public',
  'current_staff_access',
  array[]::text[],
  'current staff access RPC exists'
);
select has_function(
  'private',
  'append_admin_audit',
  array['uuid', 'text', 'text', 'uuid', 'text', 'text', 'jsonb', 'jsonb', 'uuid', 'uuid'],
  'protected audit append helper exists'
);

-- The capability is server-controlled and cannot elevate a Moderator.
insert into public.staff_capabilities (
  user_id, can_manage_administrators, granted_by
) values
  (
    '90000000-0000-4000-8000-000000000006',
    true,
    '90000000-0000-4000-8000-000000000007'
  ),
  (
    '90000000-0000-4000-8000-000000000007',
    true,
    '90000000-0000-4000-8000-000000000007'
  );

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_capabilities as
  select count(*) as row_count from public.staff_capabilities;
create temp table _non_staff_access as
  select count(*) as row_count from public.current_staff_access();
reset role;

select is(
  (select row_count from _non_staff_capabilities),
  0::bigint,
  'ordinary authenticated users see no staff capability rows'
);
select is(
  (select row_count from _non_staff_access),
  0::bigint,
  'ordinary authenticated users receive no staff access row'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_access as
  select * from public.current_staff_access();
reset role;

select is(
  (select role from _moderator_access),
  'moderator'::public.app_role,
  'Moderator role comes from the existing server-owned role table'
);
select ok(
  not (select can_manage_administrators from _moderator_access),
  'Moderator cannot manage administrators even if a capability row is malformed'
);
select ok(
  (select is_active from _moderator_access),
  'unrevoked Moderator access is active'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _administrator_access as
  select * from public.current_staff_access();
reset role;

select ok(
  (select can_manage_administrators from _administrator_access),
  'bootstrap Administrator receives the protected administrator-management capability'
);

-- Invitation records store a fixed-width digest, never a raw invitation token.
insert into public.staff_invitations (
  id, email, role, token_digest, invited_by, expires_at
) values (
  '92000000-0000-4000-8000-000000000001',
  'Staff.Invite@BlocLens.invalid',
  'moderator',
  decode(repeat('ab', 32), 'hex'),
  '90000000-0000-4000-8000-000000000007',
  now() + interval '24 hours'
);

select throws_ok(
  $$insert into public.staff_invitations (
      email, role, token_digest, invited_by, expires_at
    ) values (
      'staff.invite@bloclens.invalid',
      'moderator',
      decode(repeat('cd', 32), 'hex'),
      '90000000-0000-4000-8000-000000000007',
      now() + interval '24 hours'
    )$$,
  '23505',
  null,
  'only one active invitation exists per lower-cased email'
);

select throws_ok(
  $$insert into public.staff_invitations (
      email, role, token_digest, invited_by, expires_at
    ) values (
      'short-digest@bloclens.invalid',
      'moderator',
      decode('abcd', 'hex'),
      '90000000-0000-4000-8000-000000000007',
      now() + interval '24 hours'
    )$$,
  '23514',
  null,
  'invitation token digests must be SHA-256 width'
);

select throws_ok(
  $$insert into public.staff_invitations (
      email, role, token_digest, invited_by, expires_at
    ) values (
      'expired-at-creation@bloclens.invalid',
      'moderator',
      decode(repeat('ef', 32), 'hex'),
      '90000000-0000-4000-8000-000000000007',
      now() - interval '1 minute'
    )$$,
  '23514',
  null,
  'new invitations must expire after creation'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.staff_invitations',
    'token_digest',
    'SELECT'
  ),
  'authenticated clients cannot select invitation token digests'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'staff_invitations'
      and column_name in ('token', 'raw_token', 'invitation_token')
  ),
  0::bigint,
  'staff invitations have no raw-token column'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
do $$
begin
  perform token_digest
  from public.staff_invitations
  where id = '92000000-0000-4000-8000-000000000001';
  raise exception 'expected invitation digest selection to be rejected';
exception
  when insufficient_privilege then null;
end;
$$;
reset role;
select ok(true, 'even an authenticated Administrator cannot read invitation digests');

-- Audit rows are append-only to browser roles and summaries are size-bounded.
select private.append_admin_audit(
  '90000000-0000-4000-8000-000000000007',
  'staff.invitation.created',
  'staff_invitation',
  '92000000-0000-4000-8000-000000000001',
  'Invite a Moderator for local verification',
  'succeeded',
  '{}'::jsonb,
  '{"role":"moderator"}'::jsonb,
  '93000000-0000-4000-8000-000000000001',
  '94000000-0000-4000-8000-000000000001'
);

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
    'authenticated',
    'private.append_admin_audit(uuid,text,text,uuid,text,text,jsonb,jsonb,uuid,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'authenticated clients cannot call the protected audit append helper'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
do $$
begin
  update public.admin_audit_events
  set reason = 'tampered';
  raise exception 'expected audit update to be rejected';
exception
  when insufficient_privilege then null;
end;
$$;
do $$
begin
  delete from public.admin_audit_events;
  raise exception 'expected audit delete to be rejected';
exception
  when insufficient_privilege then null;
end;
$$;
create temp table _active_staff_audit as
  select count(*) as row_count from public.admin_audit_events;
reset role;

select is(
  (select row_count from _active_staff_audit),
  1::bigint,
  'active staff can read authorised audit events'
);
select is(
  (select reason from public.admin_audit_events limit 1),
  'Invite a Moderator for local verification',
  'audit update rejection leaves the immutable row unchanged'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _ordinary_user_audit as
  select count(*) as row_count from public.admin_audit_events;
reset role;

select is(
  (select row_count from _ordinary_user_audit),
  0::bigint,
  'ordinary authenticated users see no audit events'
);

select throws_ok(
  $$select private.append_admin_audit(
      '90000000-0000-4000-8000-000000000007',
      'oversized.summary',
      'staff_invitation',
      '92000000-0000-4000-8000-000000000001',
      'Verify summary limit',
      'failed',
      jsonb_build_object('payload', repeat('x', 17000)),
      '{}'::jsonb,
      '93000000-0000-4000-8000-000000000002',
      '94000000-0000-4000-8000-000000000002'
    )$$,
  '23514',
  null,
  'audit safe summaries are capped by a database check constraint'
);

select ok(
  (
    select procedure.prosecdef
      and procedure.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'current_staff_access'
  ),
  'current staff access is SECURITY DEFINER with an empty search path'
);
select ok(
  (
    select procedure.prosecdef
      and procedure.proconfig @> array['search_path=""']::text[]
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'private'
      and procedure.proname = 'append_admin_audit'
  ),
  'audit append helper is SECURITY DEFINER with an empty search path'
);

select * from finish();
rollback;
