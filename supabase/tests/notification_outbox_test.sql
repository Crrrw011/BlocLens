-- pgTAP: notification outbox triggers.
-- Run by `supabase test db` against the disposable local database after
-- migrations and seed.
create extension if not exists pgtap;

begin;
select no_plan();

-- Fixture identities: 1=climber-1, 2=climber-2, 3=climber-3.
-- Beta link fixture route: west-end slab r1 = 30000000-0000-4000-8000-000000000001
-- Reset fixture gym: urban-climb-west-end = 10000000-0000-4000-8000-000000000001

-- 1. new_beta_for_project: climber-2 projects r1; climber-1 submits beta on r1.
delete from public.notification_preferences where user_id in ('90000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002');
insert into public.notification_preferences (user_id, category, is_enabled) values
  ('90000000-0000-4000-8000-000000000002','new_beta_for_project', true);
insert into public.logbook_entries (id, user_id, route_id, status, climbed_at, client_created_at, client_idempotency_key) values
  ('a0000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','projecting', now(), now(), 'a0000000-0000-4000-8000-0000000000f1')
on conflict (user_id, route_id) do update set status = 'projecting';

insert into public.beta_links (id, route_id, public_url, normalised_url, normalised_url_hash, platform, original_author_display_name, original_post_url, submitted_by, is_official_source) values
  ('b0000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','https://example.com/beta/notify1','https://example.com/beta/notify1','hash-notify-1','youtube','Author','https://example.com/post/notify1','90000000-0000-4000-8000-000000000001', false);

select is(
  (select count(*) from public.notification_outbox
    where category = 'new_beta_for_project'
      and recipient_id = '90000000-0000-4000-8000-000000000002'
      and source_record_id = 'b0000000-0000-4000-8000-000000000001'),
  1::bigint,
  'new_beta_for_project enqueued for projector'
);

-- 2. followed_contributor_beta: climber-2 follows climber-1; climber-1 submits again.
insert into public.user_follows (follower_id, followed_id) values
  ('90000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000001')
on conflict do nothing;
insert into public.notification_preferences (user_id, category, is_enabled) values
  ('90000000-0000-4000-8000-000000000002','followed_contributor_beta', true)
on conflict (user_id, category) do update set is_enabled = true;

insert into public.beta_links (id, route_id, public_url, normalised_url, normalised_url_hash, platform, original_author_display_name, original_post_url, submitted_by, is_official_source) values
  ('b0000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','https://example.com/beta/notify2','https://example.com/beta/notify2','hash-notify-2','youtube','Author','https://example.com/post/notify2','90000000-0000-4000-8000-000000000001', false);

select is(
  (select count(*) from public.notification_outbox
    where category = 'followed_contributor_beta'
      and recipient_id = '90000000-0000-4000-8000-000000000002'
      and source_record_id = 'b0000000-0000-4000-8000-000000000002'),
  1::bigint,
  'followed_contributor_beta enqueued for follower'
);

-- 3. gym_reset: climber-3 favourites the gym; official reset confirmed.
insert into public.favourite_gyms (user_id, gym_id) values
  ('90000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001')
on conflict do nothing;
insert into public.notification_preferences (user_id, category, is_enabled) values
  ('90000000-0000-4000-8000-000000000003','gym_reset', true)
on conflict (user_id, category) do update set is_enabled = true;

insert into public.reset_events (id, gym_id, reset_date, source, state, is_official) values
  ('c0000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001', now(), 'official', 'confirmed', true);

select is(
  (select count(*) from public.notification_outbox
    where category = 'gym_reset'
      and recipient_id = '90000000-0000-4000-8000-000000000003'
      and source_record_id = 'c0000000-0000-4000-8000-000000000001'),
  1::bigint,
  'gym_reset enqueued for gym favourite'
);

-- 4. Preference off suppresses notifications.
insert into public.notification_preferences (user_id, category, is_enabled) values
  ('90000000-0000-4000-8000-000000000003','gym_reset', false)
on conflict (user_id, category) do update set is_enabled = false;

insert into public.reset_events (id, gym_id, reset_date, source, state, is_official) values
  ('c0000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001', now(), 'official', 'confirmed', true);

select is(
  (select count(*) from public.notification_outbox
    where category = 'gym_reset'
      and recipient_id = '90000000-0000-4000-8000-000000000003'
      and source_record_id = 'c0000000-0000-4000-8000-000000000002'),
  0::bigint,
  'disabled preference suppresses notification'
);

select * from finish();
rollback;
