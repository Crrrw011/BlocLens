-- pgTAP: mutual Block enforcement at the authenticated Data API boundary.
create extension if not exists pgtap;

begin;
select no_plan();

insert into public.beta_comments (id, beta_link_id, author_id, body) values
  ('81000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000001', 'Comment by A'),
  ('81000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000002', 'Comment by B');

insert into public.user_follows (follower_id, followed_id) values
  ('90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002'),
  ('90000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000001');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
insert into public.user_blocks (blocker_id, blocked_id)
values ('90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002');
create temp table _a_profile as select count(*) c from public.profiles where id = '90000000-0000-4000-8000-000000000002';
create temp table _a_profile_view as select count(*) c from public.public_profiles where id = '90000000-0000-4000-8000-000000000002';
create temp table _a_beta as select count(*) c from public.beta_links where id = '40000000-0000-4000-8000-000000000002';
create temp table _a_beta_view as select count(*) c from public.beta_ranking_inputs where id = '40000000-0000-4000-8000-000000000002';
create temp table _a_comment as select count(*) c from public.beta_comments where id = '81000000-0000-4000-8000-000000000002';
create temp table _a_beta_list as select count(*) c from public.beta_links where submitted_by = '90000000-0000-4000-8000-000000000002';
create temp table _a_count as select public.visible_beta_count_for_route('30000000-0000-4000-8000-000000000001') c;
create temp table _a_blocked_rpc as select count(*) c from public.get_my_blocked_profiles() where id = '90000000-0000-4000-8000-000000000002';
create temp table _a_logbook as select count(*) c from public.logbook_entries where user_id <> auth.uid();
reset role;

select is((select count(*) from public.user_follows where follower_id in ('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002') and followed_id in ('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002')), 0::bigint, 'block removes follow rows in both directions');
select is((select c from _a_profile), 0::bigint, 'A cannot directly read B profile');
select is((select c from _a_profile_view), 0::bigint, 'A cannot read B through public_profiles');
select is((select c from _a_beta), 0::bigint, 'A cannot directly read B beta by ID');
select is((select c from _a_beta_view), 0::bigint, 'A cannot read B beta through ranking view');
select is((select c from _a_comment), 0::bigint, 'A cannot directly read B comment');
select is((select c from _a_beta_list), 0::bigint, 'A beta list matches by-ID filtering');
select is((select c from _a_count), 2, 'authenticated beta count excludes blocked submitter');
select is((select c from _a_blocked_rpc), 1::bigint, 'blocker can manage its own blocked profile through the narrow RPC');
select is((select c from _a_logbook), 0::bigint, 'private Logbook remains owner-only');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000002';
create temp table _b_profile as select count(*) c from public.profiles where id = '90000000-0000-4000-8000-000000000001';
create temp table _b_beta as select count(*) c from public.beta_links where id = '40000000-0000-4000-8000-000000000001';
create temp table _b_comment as select count(*) c from public.beta_comments where id = '81000000-0000-4000-8000-000000000001';
create temp table _b_third_party as select count(*) c from public.profiles where id = '90000000-0000-4000-8000-000000000003';
create temp table _b_blocked_rpc as select count(*) c from public.get_my_blocked_profiles();
reset role;

select is((select c from _b_profile), 0::bigint, 'B cannot directly read blocker A profile');
select is((select c from _b_beta), 0::bigint, 'B cannot directly read blocker A beta');
select is((select c from _b_comment), 0::bigint, 'B cannot directly read blocker A comment');
select is((select c from _b_third_party), 1::bigint, 'unrelated third-party profile remains visible');
select is((select c from _b_blocked_rpc), 0::bigint, 'blocked user cannot discover who blocked them');

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
delete from public.user_blocks
where blocker_id = auth.uid() and blocked_id = '90000000-0000-4000-8000-000000000002';
create temp table _unblocked_profile as select count(*) c from public.profiles where id = '90000000-0000-4000-8000-000000000002';
create temp table _unblocked_beta as select count(*) c from public.beta_links where id = '40000000-0000-4000-8000-000000000002';
reset role;

select is((select c from _unblocked_profile), 1::bigint, 'unblock restores public profile visibility');
select is((select c from _unblocked_beta), 1::bigint, 'unblock restores beta visibility');
select is((select count(*) from public.user_follows where follower_id in ('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002') and followed_id in ('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002')), 0::bigint, 'unblock does not restore follows');

set local role anon;
create temp table _guest_route as select count(*) c from public.route_summaries where id = '30000000-0000-4000-8000-000000000001';
create temp table _guest_count as select public.visible_beta_count_for_route('30000000-0000-4000-8000-000000000001') c;
reset role;

select is((select c from _guest_route), 1::bigint, 'guest route summary remains readable');
select is((select c from _guest_count), 3, 'guest receives only the original safe beta count');
select ok(not has_table_privilege('anon', 'public.beta_links', 'SELECT'), 'guest cannot read beta URL table');
select ok(not has_function_privilege('anon', 'private.has_block_relationship(uuid)'::regprocedure, 'EXECUTE'), 'guest cannot call private block helper');
select ok(has_function_privilege('authenticated', 'private.has_block_relationship(uuid)'::regprocedure, 'EXECUTE'), 'authenticated policies can execute block helper');
select ok(exists (select 1 from pg_indexes where indexname = 'user_blocks_blocked_blocker_idx'), 'reverse block lookup has an index');

select * from finish();
rollback;
