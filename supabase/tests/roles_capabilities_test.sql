-- pgTAP: server-owned roles, trusted contributor threshold and gym scope.
create extension if not exists pgtap;

begin;
select no_plan();

insert into auth.users (
  id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
)
select
  ('a0000000-0000-4000-8000-' || lpad(number::text, 12, '0'))::uuid,
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'helpful-voter-' || number || '@bloclens.invalid', now(), now(), now()
from generate_series(1, 67) number;

insert into public.beta_helpful_votes (beta_link_id, user_id)
select
  '40000000-0000-4000-8000-000000000001',
  ('a0000000-0000-4000-8000-' || lpad(number::text, 12, '0'))::uuid
from generate_series(1, 67) number;

select is(
  (select helpful_received_count from public.profiles where id = '90000000-0000-4000-8000-000000000001'),
  67,
  '67 valid Helpful votes are counted by the database'
);
select ok(
  (select is_trusted_contributor from public.profiles where id = '90000000-0000-4000-8000-000000000001'),
  '67 valid Helpful votes permanently award trusted contributor'
);
select ok(
  (select trusted_contributor_awarded_at is not null from public.profiles where id = '90000000-0000-4000-8000-000000000001'),
  'trusted contributor award time is recorded'
);

update public.beta_links
set moderation_status = 'temporarily_hidden', hidden_at = now()
where id = '40000000-0000-4000-8000-000000000001';

select is(
  (select helpful_received_count from public.profiles where id = '90000000-0000-4000-8000-000000000001'),
  0,
  'hidden beta Helpful votes stop contributing to the live count'
);
select ok(
  (select is_trusted_contributor from public.profiles where id = '90000000-0000-4000-8000-000000000001'),
  'trusted contributor remains awarded after valid count later falls'
);

select throws_ok(
  $$insert into public.beta_helpful_votes (beta_link_id, user_id)
    values ('40000000-0000-4000-8000-000000000005', '90000000-0000-4000-8000-000000000001')$$,
  'A contributor cannot mark their own beta link as Helpful',
  'self Helpful is rejected by a server trigger'
);

select ok(
  not has_column_privilege('authenticated', 'public.profiles', 'is_trusted_contributor', 'UPDATE'),
  'authenticated clients cannot grant themselves trusted contributor'
);
select ok(
  not has_table_privilege('authenticated', 'public.app_user_roles', 'DELETE'),
  'authenticated clients cannot delete role rows'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000005';
create temp table _official_own as select public.is_gym_official('10000000-0000-4000-8000-000000000001') value;
create temp table _official_other as select public.is_gym_official('10000000-0000-4000-8000-000000000002') value;
reset role;

select ok((select value from _official_own), 'verified representative manages only its assigned gym');
select ok(not (select value from _official_other), 'verified representative cannot manage another gym');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator as select public.is_admin_or_moderator() privileged, public.is_admin() administrator;
reset role;
select ok((select privileged from _moderator), 'moderator receives moderation capability');
select ok(not (select administrator from _moderator), 'moderator is not an administrator');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _administrator as select public.is_admin() value;
reset role;
select ok((select value from _administrator), 'administrator capability comes from server role data');

select * from finish();
rollback;
