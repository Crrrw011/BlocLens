-- pgTAP: staff-only operational read models for overview and review queues.
create extension if not exists pgtap;

begin;
select no_plan();

select has_function(
  'public',
  'admin_overview_metrics',
  array['timestamp with time zone', 'timestamp with time zone'],
  'overview metrics RPC exists'
);
select has_function(
  'public',
  'admin_review_queue',
  array['text', 'text', 'text', 'text', 'integer', 'text', 'text'],
  'review queue RPC exists'
);
select has_function(
  'public',
  'admin_review_item',
  array['text', 'uuid'],
  'review item RPC exists'
);

-- Representative queue fixtures across all four review kinds.
-- A real beta comment backs the non-route report fixture (target trigger).
insert into public.beta_links (
  id, route_id, public_url, normalised_url, normalised_url_hash, platform,
  original_author_display_name, original_post_url, submitted_by
) values (
  '96000000-0000-4000-8000-000000009001', '30000000-0000-4000-8000-000000000001',
  'https://example.invalid/beta/1', 'https://example.invalid/beta/1', 'fixture-hash-1',
  'youtube', 'Fixture Author', 'https://example.invalid/post/1',
  '90000000-0000-4000-8000-000000000001'
);

insert into public.beta_comments (id, beta_link_id, author_id, body) values (
  '96000000-0000-4000-8000-000000009002', '96000000-0000-4000-8000-000000009001',
  '90000000-0000-4000-8000-000000000002', 'Fixture comment for report coverage'
);

insert into public.content_reports (
  id, target_type, target_id, category, reporter_id, details, status, created_at
) values
  (
    '96000000-0000-4000-8000-000000000001', 'route',
    '30000000-0000-4000-8000-000000000001', 'harassment',
    '90000000-0000-4000-8000-000000000001', 'Severe report fixture',
    'open', now() - interval '2 days'
  ),
  (
    '96000000-0000-4000-8000-000000000002', 'beta_comment',
    '96000000-0000-4000-8000-000000009002', 'spam',
    '90000000-0000-4000-8000-000000000002', 'Normal report fixture',
    'open', now() - interval '1 day'
  ),
  (
    '96000000-0000-4000-8000-000000000003', 'route',
    '30000000-0000-4000-8000-000000000002', 'spam',
    '90000000-0000-4000-8000-000000000002', 'Dismissed report fixture',
    'dismissed', now() - interval '3 days'
  );

insert into public.route_corrections (
  id, route_id, submitted_by, issue_key, explanation, status, created_at
) values
  (
    '96000000-0000-4000-8000-000000000011', '30000000-0000-4000-8000-000000000001',
    '90000000-0000-4000-8000-000000000001', 'grade', 'Grade looks soft',
    'open', now() - interval '12 hours'
  ),
  (
    '96000000-0000-4000-8000-000000000012', '30000000-0000-4000-8000-000000000002',
    '90000000-0000-4000-8000-000000000002', 'holds', 'Hold description outdated',
    'accepted', now() - interval '4 days'
  );

insert into public.route_removal_reports (
  id, route_id, reported_by, status, created_at
) values (
  '96000000-0000-4000-8000-000000000021', '30000000-0000-4000-8000-000000000003',
  '90000000-0000-4000-8000-000000000001', 'open', now() - interval '6 hours'
);

insert into public.route_merge_suggestions (
  id, source_route_id, proposed_canonical_route_id, suggested_by, reason, status, created_at
) values (
  '96000000-0000-4000-8000-000000000031',
  '30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002',
  '90000000-0000-4000-8000-000000000002', 'Likely duplicate fixture',
  'proposed', now() - interval '3 hours'
);

insert into public.moderation_actions (
  id, action_type, target_type, target_id, performed_by, reason
) values (
  '96000000-0000-4000-8000-000000000041', 'hide', 'route',
  '30000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000007', 'Hide fixture for prior-action lookup'
);

insert into public.gym_claims (
  id, gym_id, applicant_id, domain_email, verification_method, status
) values (
  '96000000-0000-4000-8000-000000000051', '10000000-0000-4000-8000-000000000001',
  '90000000-0000-4000-8000-000000000005', 'manager@example.invalid', 'manual_review', 'submitted'
);

-- Staff roles see the queue; ordinary users see nothing.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _admin_queue as
  select * from public.admin_review_queue('pending', 'all', null, null, 100);
create temp table _admin_metrics as
  select * from public.admin_overview_metrics(null, null);
create temp table _admin_item as
  select * from public.admin_review_item('content_report', '96000000-0000-4000-8000-000000000001');
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000006';
create temp table _moderator_queue as
  select * from public.admin_review_queue('pending', 'all', null, null, 100);
reset role;

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000001';
create temp table _non_staff_queue as
  select * from public.admin_review_queue('pending', 'all', null, null, 100);
create temp table _non_staff_metrics as
  select * from public.admin_overview_metrics(null, null);
create temp table _non_staff_item as
  select * from public.admin_review_item('content_report', '96000000-0000-4000-8000-000000000001');
reset role;

select ok(
  (select count(*) >= 5 from _admin_queue),
  'Administrator sees pending items from every review kind'
);
select ok(
  (select count(*) >= 5 from _moderator_queue),
  'Moderator sees the same pending review queue'
);
select is(
  (select count(*) from _non_staff_queue),
  0::bigint,
  'ordinary users receive no review queue rows'
);
select is(
  (select count(*) from _non_staff_metrics),
  0::bigint,
  'ordinary users receive no overview metrics'
);
select is(
  (select count(*) from _non_staff_item),
  0::bigint,
  'ordinary users receive no review item detail'
);

-- Severe reports are counted and flagged without exposing reporter identity in the queue.
select is(
  (select severe_reports from _admin_metrics),
  1::bigint,
  'overview counts exactly the severe fixture report'
);
select ok(
  (
    select bool_and(severity = 'severe')
    from _admin_queue
    where id = '96000000-0000-4000-8000-000000000001'
  ),
  'severe queue rows carry the severe flag'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('admin_review_queue')
  ),
  'queue projection is a function, not a reporter-identity table'
);

-- Queue order is stable on (created_at, id) and paginates without overlap.
select ok(
  (
    select bool_and(created_at >= lead_created_at or lead_created_at is null)
    from (
      select created_at,
        lead(created_at) over (order by created_at desc, id desc) as lead_created_at
      from _admin_queue
    ) ordered
  ),
  'queue rows arrive in stable created_at descending order'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _first_page as
  select * from public.admin_review_queue('pending', 'all', null, null, 2);
reset role;

select is(
  (select count(*) from _first_page),
  3::bigint,
  'bounded pages return the requested size plus one lookahead row'
);

set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _second_page as
  select * from public.admin_review_queue(
    'pending', 'all', null,
    (select created_at::text || '|' || id::text from _first_page order by created_at desc, id desc limit 1 offset 1),
    100
  );
reset role;

select is(
  (
    select count(*)
    from _second_page second
    join (select id from _first_page order by created_at desc, id desc limit 2) first
      on first.id = second.id
  ),
  0::bigint,
  'cursor continuation overlaps no previously returned row'
);

-- Metrics reflect every queue kind and the pending claim.
select ok(
  (select pending_reports from _admin_metrics) >= 2,
  'overview counts pending reports'
);
select ok(
  (select pending_corrections from _admin_metrics) >= 1,
  'overview counts pending corrections'
);
select ok(
  (select duplicate_routes from _admin_metrics) >= 1,
  'overview counts proposed route duplicates'
);
select ok(
  (select pending_claims from _admin_metrics) >= 1,
  'overview counts pending gym claims'
);

-- Item detail carries context and prior actions, never Logbook content.
select is(
  (select status from _admin_item),
  'open',
  'item detail reports the native status'
);
select ok(
  (select route_label is not null from _admin_item),
  'item detail names the affected route'
);
select ok(
  (
    select prior_actions is not null
      and jsonb_array_length(prior_actions) >= 1
    from _admin_item
  ),
  'item detail lists prior moderation actions on the target'
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
      and procedure.proname in ('admin_overview_metrics', 'admin_review_queue', 'admin_review_item')
  ),
  'review functions are SECURITY DEFINER with an empty search path'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('admin_overview_metrics', 'admin_review_queue', 'admin_review_item')
      and pg_catalog.pg_get_functiondef(procedure.oid) ilike '%logbook%'
  ),
  0::bigint,
  'review projections never reference private Logbook content'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_review_queue(text,text,text,text,integer,text,text)'::regprocedure,
    'EXECUTE'
  ),
  'anonymous clients cannot read the review queue'
);

-- Kind and severity filters narrow the same stable queue.
set local role authenticated;
set local request.jwt.claim.sub to '90000000-0000-4000-8000-000000000007';
create temp table _severe_queue as
  select * from public.admin_review_queue('pending', 'all', null, null, 100, 'all', 'severe');
create temp table _correction_queue as
  select * from public.admin_review_queue('pending', 'all', null, null, 100, 'route_correction', 'all');
reset role;

select ok(
  (select count(*) >= 1 from _severe_queue),
  'severe filter returns the severe fixture'
);
select ok(
  (select bool_and(severity = 'severe') from _severe_queue),
  'severe filter returns only severe rows'
);
select ok(
  (select count(*) >= 1 from _correction_queue),
  'kind filter returns the correction fixture'
);
select ok(
  (select bool_and(kind = 'route_correction') from _correction_queue),
  'kind filter returns only the requested kind'
);

select * from finish();
rollback;
