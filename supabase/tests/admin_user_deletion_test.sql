-- pgTAP: administrative user deletion bans, scrubs, and revokes without
-- touching auth rows. Staff and self deletions are refused.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_delete_user',
  array['uuid', 'text', 'uuid'],
  'user deletion RPC exists'
);

-- An Administrator deletes fixture trusted contributor .004.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _deleted as
  select * from public.admin_delete_user(
    '90000000-0000-4000-8000-000000000004', 'Spam account, owner requested removal',
    '98000000-0000-4000-8000-000000000101'
  );
reset role;

select ok((select ok from _deleted), 'plain user deletion succeeds');
select ok(
  (select result ->> 'deleted' from _deleted) = 'true',
  'deletion result reports the removal'
);
select ok(
  public.has_active_penalty(
    '90000000-0000-4000-8000-000000000004', array['permanent_ban'::public.penalty_kind]
  ),
  'deleted user carries an active permanent ban'
);
select ok(
  (select deleted_at from public.profiles where id = '90000000-0000-4000-8000-000000000004') is not null,
  'deleted user profile is stamped'
);
select ok(
  (select username::text from public.profiles where id = '90000000-0000-4000-8000-000000000004')
    like 'deleted\_%',
  'deleted user profile is scrubbed'
);
select ok(
  exists (select 1 from auth.users where id = '90000000-0000-4000-8000-000000000004'),
  'auth row is retained so foreign keys never break'
);

-- Self deletion is refused.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _self as
  select * from public.admin_delete_user(
    '90000000-0000-4000-8000-000000000007', 'Trying to delete myself',
    '98000000-0000-4000-8000-000000000102'
  );
reset role;

select ok(
  (select ok from _self) = false and (select error_code from _self) = 'self_delete',
  'self deletion is refused'
);

-- Staff deletion is refused: revoke the staff role first.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _staff as
  select * from public.admin_delete_user(
    '90000000-0000-4000-8000-000000000006', 'Trying to delete a moderator',
    '98000000-0000-4000-8000-000000000103'
  );
reset role;

select ok(
  (select ok from _staff) = false and (select error_code from _staff) = 'staff_protected',
  'staff deletion is refused'
);

-- Moderators cannot delete users.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _forbidden as
  select * from public.admin_delete_user(
    '90000000-0000-4000-8000-000000000001', 'Moderator trying to delete',
    '98000000-0000-4000-8000-000000000104'
  );
reset role;

select ok(
  (select ok from _forbidden) = false and (select error_code from _forbidden) = 'forbidden',
  'moderator deletion is refused'
);

select finish();
rollback;
