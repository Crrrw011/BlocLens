-- pgTAP: staff-only people search and owner-aware staff administration.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_list_users',
  array['text', 'text', 'integer'],
  'people search RPC exists'
);
select has_function('public', 'admin_list_staff', array[]::text[], 'staff roster RPC exists');
select has_function(
  'public',
  'admin_revoke_staff_invitation',
  array['uuid', 'text', 'uuid'],
  'invitation revocation RPC exists'
);
select has_function(
  'public',
  'admin_set_staff_active',
  array['uuid', 'boolean', 'text', 'uuid'],
  'staff activation RPC exists'
);

-- Owner capability and an ordinary administrator for the matrix.
insert into public.staff_capabilities (user_id, can_manage_administrators, granted_by) values (
  '90000000-0000-4000-8000-000000000007', true, '90000000-0000-4000-8000-000000000007'
)
on conflict (user_id) do update
set can_manage_administrators = true;

insert into public.app_user_roles (user_id, role)
values ('90000000-0000-4000-8000-000000000002', 'admin')
on conflict (user_id, role) do update set revoked_at = null;

-- Moderators search people; ordinary users see nothing.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_search as
  select * from public.admin_list_users('Fixture', null, 100);
create temp table _moderator_detail as
  select * from public.admin_list_users('Fixture Climber One', null, 100);
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_search as
  select * from public.admin_list_users('Fixture', null, 100);
reset role;

select ok((select count(*) >= 5 from _moderator_search), 'Moderator searches people');
select is(
  (select username from _moderator_detail limit 1),
  'Fixture Climber One',
  'search matches usernames'
);
select is((select count(*) from _non_staff_search), 0::bigint, 'ordinary users see no people');
select is(
  (select count(*) from _moderator_search where user_id = '90000000-0000-4000-8000-000000000007'),
  1::bigint,
  'staff themselves appear in people results'
);

-- Only Administrators read the staff roster.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _roster as
  select * from public.admin_list_staff();
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_roster as
  select * from public.admin_list_staff();
reset role;

select ok((select ok from _roster), 'Administrator reads the staff roster');
select ok(
  (select payload->'staff' is not null and payload->'invitations' is not null from _roster),
  'roster carries staff and invitations'
);
select is((select error_code from _moderator_roster), 'forbidden', 'Moderator roster read is forbidden');

-- The owner invites a Moderator; an ordinary Administrator cannot invite one twice.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _invite as
  select * from public.create_staff_invitation(
    'revocable-moderator@bloclens.invalid', 'moderator', decode(repeat('21', 32), 'hex'),
    now() + interval '24 hours', 'Revocation fixture invitation'
  );
reset role;

select ok((select invitation_created from _invite), 'owner invites a Moderator');

-- Revocation closes the invitation exactly once.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _revoke as
  select * from public.admin_revoke_staff_invitation(
    (select invitation_id from _invite),
    'Hiring freeze', '98000000-0000-4000-8000-000000000021'
  );
create temp table _re_revoke as
  select * from public.admin_revoke_staff_invitation(
    (select invitation_id from _invite),
    'Second revocation attempt', '98000000-0000-4000-8000-000000000022'
  );
reset role;

select ok((select ok from _revoke), 'revocation succeeds');
select is((select error_code from _re_revoke), 'invalid_transition', 'second revocation is rejected');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_revoke as
  select * from public.admin_revoke_staff_invitation(
    (select invitation_id from _invite),
    'Moderator attempts revocation', '98000000-0000-4000-8000-000000000023'
  );
reset role;

select is((select error_code from _moderator_revoke), 'forbidden', 'Moderator revocation is forbidden');

-- The owner deactivates the ordinary Administrator; self-changes are refused.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _deactivate as
  select * from public.admin_set_staff_active(
    '90000000-0000-4000-8000-000000000002', false,
    'Role review in progress', '98000000-0000-4000-8000-000000000024'
  );
create temp table _self_change as
  select * from public.admin_set_staff_active(
    '90000000-0000-4000-8000-000000000007', false,
    'Owner attempts self-deactivation', '98000000-0000-4000-8000-000000000025'
  );
reset role;

select ok((select ok from _deactivate), 'owner deactivates an ordinary Administrator');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000002';
create temp table _deactivated_access as
  select count(*) as row_count from public.current_staff_access() where is_active;
reset role;

select is(
  (select row_count from _deactivated_access),
  0::bigint,
  'deactivated access reads as inactive without a session change'
);
select is((select error_code from _self_change), 'invalid', 'self-deactivation is refused');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _reactivate as
  select * from public.admin_set_staff_active(
    '90000000-0000-4000-8000-000000000002', true,
    'Review complete', '98000000-0000-4000-8000-000000000026'
  );
create temp table _re_reactivate as
  select * from public.admin_set_staff_active(
    '90000000-0000-4000-8000-000000000002', true,
    'Second reactivation attempt', '98000000-0000-4000-8000-000000000027'
  );
reset role;

select ok((select ok from _reactivate), 'reactivation succeeds');
select is((select error_code from _re_reactivate), 'invalid_transition', 'second reactivation is rejected');

-- An ordinary Administrator cannot touch another Administrator.
insert into public.app_user_roles (user_id, role)
values ('90000000-0000-4000-8000-000000000005', 'admin')
on conflict (user_id, role) do update set revoked_at = null;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000002';
create temp table _ordinary_vs_admin as
  select * from public.admin_set_staff_active(
    '90000000-0000-4000-8000-000000000005', false,
    'Ordinary Administrator targets an Administrator', '98000000-0000-4000-8000-000000000028'
  );
create temp table _ordinary_vs_moderator as
  select * from public.admin_set_staff_active(
    '90000000-0000-4000-8000-000000000006', false,
    'Ordinary Administrator targets a Moderator', '98000000-0000-4000-8000-000000000029'
  );
reset role;

select is((select error_code from _ordinary_vs_admin), 'forbidden', 'ordinary Administrator cannot deactivate an Administrator');
select ok((select ok from _ordinary_vs_moderator), 'ordinary Administrator deactivates a Moderator');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
select * from public.admin_set_staff_active(
  '90000000-0000-4000-8000-000000000006', true,
  'Restore the Moderator fixture', '98000000-0000-4000-8000-000000000030'
);
reset role;

-- Every access change is audited.
select ok(
  (
    select count(*) >= 2
    from public.admin_audit_events
    where action_key in ('staff.access.deactivated', 'staff.access.reactivated')
      and outcome = 'succeeded'
  ),
  'deactivation and reactivation are audited'
);
select ok(
  (
    select count(*) >= 2
    from public.admin_audit_events
    where action_key in ('staff.access.changed', 'staff.invitation.revoked')
      and outcome = 'failed'
  ),
  'refused access changes are audited'
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
      and procedure.proname in (
        'admin_list_users', 'admin_list_staff',
        'admin_revoke_staff_invitation', 'admin_set_staff_active'
      )
  ),
  'people functions are SECURITY DEFINER with an empty search path'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_set_staff_active(uuid,boolean,text,uuid)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot change staff access'
);

select * from finish();
rollback;
