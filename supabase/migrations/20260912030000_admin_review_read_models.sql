-- Staff-only operational read models for the overview dashboard and review queues.
-- Reporter identity stays out of list projections; detail projections never touch Logbook.

create or replace function public.admin_overview_metrics(
  range_start timestamptz,
  range_end timestamptz
)
returns table (
  pending_reports bigint,
  severe_reports bigint,
  pending_corrections bigint,
  duplicate_routes bigint,
  pending_claims bigint,
  hidden_content bigint,
  median_handling_seconds double precision,
  trend jsonb,
  distribution jsonb,
  recent_actions jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
  window_start timestamptz := coalesce(
    admin_overview_metrics.range_start,
    statement_timestamp() - interval '30 days'
  );
  window_end timestamptz := coalesce(
    admin_overview_metrics.range_end,
    statement_timestamp()
  );
begin
  if window_start >= window_end
    or window_end - window_start > interval '366 days'
  then
    raise exception using
      errcode = '22023',
      message = 'invalid overview metrics range';
  end if;

  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = caller_id
      and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
      and roles.revoked_at is null
  ) into is_staff;

  if not is_staff then
    return;
  end if;

  return query
  select
    (select count(*) from public.content_reports
      where status in ('open'::public.report_status, 'under_review'::public.report_status)),
    (select count(*) from public.content_reports
      where status in ('open'::public.report_status, 'under_review'::public.report_status)
        and is_severe),
    (select count(*) from public.route_corrections
      where status in ('open'::public.correction_status, 'under_review'::public.correction_status))
    + (select count(*) from public.route_removal_reports
      where status in ('open'::public.report_status, 'under_review'::public.report_status)),
    (select count(*) from public.route_merge_suggestions
      where status = 'proposed'::public.merge_status),
    (select count(*) from public.gym_claims
      where status = 'submitted'::public.claim_status),
    (select count(*) from public.routes
      where moderation_status = 'temporarily_hidden'::public.moderation_status
        and deleted_at is null),
    (select percentile_cont(0.5) within group (order by handling.secs) from (
      select extract(epoch from (reports.updated_at - reports.created_at)) as secs
      from public.content_reports as reports
      where reports.status in ('resolved'::public.report_status, 'dismissed'::public.report_status)
        and reports.updated_at >= window_start
        and reports.updated_at < window_end
      union all
      select extract(epoch from (corrections.updated_at - corrections.created_at))
      from public.route_corrections as corrections
      where corrections.status in ('accepted'::public.correction_status, 'rejected'::public.correction_status)
        and corrections.updated_at >= window_start
        and corrections.updated_at < window_end
      union all
      select extract(epoch from (merges.updated_at - merges.created_at))
      from public.route_merge_suggestions as merges
      where merges.status in (
        'approved'::public.merge_status, 'rejected'::public.merge_status,
        'completed'::public.merge_status
      )
        and merges.updated_at >= window_start
        and merges.updated_at < window_end
    ) handling),
    (select coalesce(jsonb_agg(row_to_json(t) order by t.day), '[]'::jsonb) from (
      select days.day,
        (select count(*) from public.content_reports r
          where r.created_at >= days.day and r.created_at < days.day + 1) +
        (select count(*) from public.route_corrections c
          where c.created_at >= days.day and c.created_at < days.day + 1) as opened,
        (select count(*) from public.content_reports r
          where r.updated_at >= days.day and r.updated_at < days.day + 1
            and r.status in ('resolved'::public.report_status, 'dismissed'::public.report_status)) +
        (select count(*) from public.route_corrections c
          where c.updated_at >= days.day and c.updated_at < days.day + 1
            and c.status in ('accepted'::public.correction_status, 'rejected'::public.correction_status)) as resolved
      from (
        select pg_catalog.generate_series(
          date_trunc('day', window_start), date_trunc('day', window_end), interval '1 day'
        )::date as day
      ) days
    ) t),
    (select coalesce(jsonb_agg(row_to_json(d) order by d.kind, d.status), '[]'::jsonb) from (
      select 'content_report'::text as kind, status::text as status, count(*) as count
      from public.content_reports group by status
      union all
      select 'route_correction', status::text, count(*)
      from public.route_corrections group by status
      union all
      select 'removal_report', status::text, count(*)
      from public.route_removal_reports group by status
      union all
      select 'merge_suggestion', status::text, count(*)
      from public.route_merge_suggestions group by status
    ) d),
    (select coalesce(jsonb_agg(row_to_json(a) order by a.created_at desc), '[]'::jsonb) from (
      select actions.id, actions.action_type::text as action_type,
        actions.target_type::text as target_type, actions.target_id,
        actions.reason, actions.created_at
      from public.moderation_actions as actions
      order by actions.created_at desc
      limit 8
    ) a);
end;
$$;

create or replace function public.admin_review_queue(
  status_filter text,
  target_filter text,
  search_text text,
  page_after text,
  page_size integer
)
returns table (
  kind text,
  id uuid,
  status text,
  severity text,
  route_id uuid,
  route_label text,
  gym_name text,
  target_type text,
  target_id uuid,
  title text,
  summary text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
  want_pending boolean := false;
  want_resolved boolean := false;
  want_target text := coalesce(nullif(btrim(admin_review_queue.target_filter), ''), 'all');
  needle text := nullif(btrim(coalesce(admin_review_queue.search_text, '')), '');
  limit_count integer := least(greatest(coalesce(admin_review_queue.page_size, 20), 1), 100);
  cursor_at timestamptz := null;
  cursor_id uuid := null;
begin
  if admin_review_queue.status_filter is null
    or admin_review_queue.status_filter not in ('pending', 'resolved', 'all')
  then
    raise exception using errcode = '22023', message = 'invalid review status filter';
  end if;
  if want_target not in ('all', 'route', 'beta_link', 'beta_comment', 'route_photo') then
    raise exception using errcode = '22023', message = 'invalid review target filter';
  end if;
  want_pending := admin_review_queue.status_filter in ('pending', 'all');
  want_resolved := admin_review_queue.status_filter in ('resolved', 'all');

  if admin_review_queue.page_after is not null then
    begin
      cursor_at := split_part(admin_review_queue.page_after, '|', 1)::timestamptz;
      cursor_id := split_part(admin_review_queue.page_after, '|', 2)::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'invalid review page cursor';
    end;
  end if;

  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = caller_id
      and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
      and roles.revoked_at is null
  ) into is_staff;

  if not is_staff then
    return;
  end if;

  return query
  with queue as (
    select
      'content_report'::text as kind,
      reports.id as id,
      reports.status::text as status,
      case when reports.is_severe then 'severe'::text else 'normal'::text end as severity,
      routes.id as route_id,
      case
        when routes.id is null then null
        else coalesce(
          nullif(btrim(coalesce(routes.colour, '')), ''),
          'Route ' || left(routes.id::text, 8)
        )
      end as route_label,
      gyms.name as gym_name,
      reports.target_type::text as target_type,
      reports.target_id as target_id,
      reports.category::text as title,
      left(coalesce(reports.details, ''), 160) as summary,
      reports.created_at as created_at,
      reports.updated_at as updated_at
    from public.content_reports as reports
    left join public.routes as routes
      on routes.id = reports.target_id and reports.target_type = 'route'::public.content_type
    left join public.gyms as gyms on gyms.id = routes.gym_id
    where (want_pending and reports.status in ('open'::public.report_status, 'under_review'::public.report_status))
       or (want_resolved and reports.status in ('resolved'::public.report_status, 'dismissed'::public.report_status))
    union all
    select
      'route_correction',
      corrections.id,
      corrections.status::text,
      'normal',
      routes.id,
      coalesce(
        nullif(btrim(coalesce(routes.colour, '')), ''),
        'Route ' || left(routes.id::text, 8)
      ),
      gyms.name,
      'route',
      corrections.route_id,
      corrections.issue_key,
      left(coalesce(corrections.explanation, ''), 160),
      corrections.created_at,
      corrections.updated_at
    from public.route_corrections as corrections
    join public.routes as routes on routes.id = corrections.route_id
    left join public.gyms as gyms on gyms.id = routes.gym_id
    where (want_pending and corrections.status in ('open'::public.correction_status, 'under_review'::public.correction_status))
       or (want_resolved and corrections.status in ('accepted'::public.correction_status, 'rejected'::public.correction_status))
    union all
    select
      'removal_report',
      removals.id,
      removals.status::text,
      'normal',
      routes.id,
      coalesce(
        nullif(btrim(coalesce(routes.colour, '')), ''),
        'Route ' || left(routes.id::text, 8)
      ),
      gyms.name,
      'route',
      removals.route_id,
      'Removal reported',
      case when removals.observed_removed_at is null then ''
        else 'Observed removed ' || removals.observed_removed_at::date::text end,
      removals.created_at,
      removals.updated_at
    from public.route_removal_reports as removals
    join public.routes as routes on routes.id = removals.route_id
    left join public.gyms as gyms on gyms.id = routes.gym_id
    where (want_pending and removals.status in ('open'::public.report_status, 'under_review'::public.report_status))
       or (want_resolved and removals.status in ('resolved'::public.report_status, 'dismissed'::public.report_status))
    union all
    select
      'merge_suggestion',
      merges.id,
      merges.status::text,
      'normal',
      source.id,
      coalesce(
        nullif(btrim(coalesce(source.colour, '')), ''),
        'Route ' || left(source.id::text, 8)
      ),
      gyms.name,
      'route',
      merges.source_route_id,
      'Merge suggested',
      left(coalesce(merges.reason, ''), 160),
      merges.created_at,
      merges.updated_at
    from public.route_merge_suggestions as merges
    join public.routes as source on source.id = merges.source_route_id
    left join public.gyms as gyms on gyms.id = source.gym_id
    where (want_pending and merges.status = 'proposed'::public.merge_status)
       or (want_resolved and merges.status in (
         'approved'::public.merge_status, 'rejected'::public.merge_status,
         'completed'::public.merge_status))
  )
  select q.kind, q.id, q.status, q.severity, q.route_id, q.route_label, q.gym_name,
    q.target_type, q.target_id, q.title, q.summary, q.created_at, q.updated_at
  from queue as q
  where (want_target = 'all' or q.target_type = want_target)
    and (
      needle is null
      or strpos(lower(coalesce(q.route_label, '')), lower(needle)) > 0
      or strpos(lower(coalesce(q.gym_name, '')), lower(needle)) > 0
      or strpos(lower(coalesce(q.title, '')), lower(needle)) > 0
      or strpos(lower(coalesce(q.summary, '')), lower(needle)) > 0
    )
    and (
      cursor_at is null
      or q.created_at < cursor_at
      or (q.created_at = cursor_at and q.id < cursor_id)
    )
  order by q.created_at desc, q.id desc
  limit limit_count + 1;
end;
$$;

create or replace function public.admin_review_item(
  item_kind text,
  item_id uuid
)
returns table (
  kind text,
  id uuid,
  status text,
  severity text,
  route_id uuid,
  route_label text,
  gym_name text,
  target_type text,
  target_id uuid,
  title text,
  summary text,
  details jsonb,
  reporter_id uuid,
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  prior_actions jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
begin
  if admin_review_item.item_kind is null
    or admin_review_item.item_kind not in (
      'content_report', 'route_correction', 'removal_report', 'merge_suggestion'
    )
    or admin_review_item.item_id is null
  then
    raise exception using errcode = '22023', message = 'invalid review item reference';
  end if;

  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = caller_id
      and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
      and roles.revoked_at is null
  ) into is_staff;

  if not is_staff then
    return;
  end if;

  return query
  with item as (
    select
      'content_report'::text as kind,
      reports.id as id,
      reports.status::text as status,
      case when reports.is_severe then 'severe'::text else 'normal'::text end as severity,
      routes.id as route_id,
      case
        when routes.id is null then null
        else coalesce(
          nullif(btrim(coalesce(routes.colour, '')), ''),
          'Route ' || left(routes.id::text, 8)
        )
      end as route_label,
      gyms.name as gym_name,
      reports.target_type::text as target_type,
      reports.target_id as target_id,
      reports.category::text as title,
      left(coalesce(reports.details, ''), 500) as summary,
      jsonb_build_object(
        'category', reports.category::text,
        'details', reports.details,
        'is_severe', reports.is_severe
      ) as details,
      reports.reporter_id as reporter_id,
      null::uuid as reviewed_by,
      null::timestamptz as reviewed_at,
      reports.created_at as created_at,
      reports.updated_at as updated_at
    from public.content_reports as reports
    left join public.routes as routes
      on routes.id = reports.target_id and reports.target_type = 'route'::public.content_type
    left join public.gyms as gyms on gyms.id = routes.gym_id
    where admin_review_item.item_kind = 'content_report'
      and reports.id = admin_review_item.item_id
    union all
    select
      'route_correction',
      corrections.id,
      corrections.status::text,
      'normal',
      routes.id,
      coalesce(
        nullif(btrim(coalesce(routes.colour, '')), ''),
        'Route ' || left(routes.id::text, 8)
      ),
      gyms.name,
      'route',
      corrections.route_id,
      corrections.issue_key,
      left(coalesce(corrections.explanation, ''), 500),
      jsonb_build_object(
        'issue_key', corrections.issue_key,
        'proposed_value', corrections.proposed_value,
        'explanation', corrections.explanation
      ),
      corrections.submitted_by,
      corrections.reviewed_by,
      corrections.reviewed_at,
      corrections.created_at,
      corrections.updated_at
    from public.route_corrections as corrections
    join public.routes as routes on routes.id = corrections.route_id
    left join public.gyms as gyms on gyms.id = routes.gym_id
    where admin_review_item.item_kind = 'route_correction'
      and corrections.id = admin_review_item.item_id
    union all
    select
      'removal_report',
      removals.id,
      removals.status::text,
      'normal',
      routes.id,
      coalesce(
        nullif(btrim(coalesce(routes.colour, '')), ''),
        'Route ' || left(routes.id::text, 8)
      ),
      gyms.name,
      'route',
      removals.route_id,
      'Removal reported',
      case when removals.observed_removed_at is null then ''
        else 'Observed removed ' || removals.observed_removed_at::date::text end,
      jsonb_build_object('observed_removed_at', removals.observed_removed_at),
      removals.reported_by,
      null::uuid,
      null::timestamptz,
      removals.created_at,
      removals.updated_at
    from public.route_removal_reports as removals
    join public.routes as routes on routes.id = removals.route_id
    left join public.gyms as gyms on gyms.id = routes.gym_id
    where admin_review_item.item_kind = 'removal_report'
      and removals.id = admin_review_item.item_id
    union all
    select
      'merge_suggestion',
      merges.id,
      merges.status::text,
      'normal',
      source.id,
      coalesce(
        nullif(btrim(coalesce(source.colour, '')), ''),
        'Route ' || left(source.id::text, 8)
      ),
      gyms.name,
      'route',
      merges.source_route_id,
      'Merge suggested',
      left(coalesce(merges.reason, ''), 500),
      jsonb_build_object(
        'source_route_id', merges.source_route_id,
        'proposed_canonical_route_id', merges.proposed_canonical_route_id,
        'reason', merges.reason,
        'completed_at', merges.completed_at
      ),
      merges.suggested_by,
      merges.reviewed_by,
      merges.reviewed_at,
      merges.created_at,
      merges.updated_at
    from public.route_merge_suggestions as merges
    join public.routes as source on source.id = merges.source_route_id
    left join public.gyms as gyms on gyms.id = source.gym_id
    where admin_review_item.item_kind = 'merge_suggestion'
      and merges.id = admin_review_item.item_id
  )
  select i.kind, i.id, i.status, i.severity, i.route_id, i.route_label, i.gym_name,
    i.target_type, i.target_id, i.title, i.summary, i.details, i.reporter_id,
    i.reviewed_by, i.reviewed_at, i.created_at, i.updated_at,
    (
      select coalesce(jsonb_agg(row_to_json(a) order by a.created_at desc), '[]'::jsonb)
      from (
        select actions.id, actions.action_type::text as action_type,
          actions.reason, actions.created_at
        from public.moderation_actions as actions
        where actions.target_type::text = i.target_type
          and actions.target_id = i.target_id
        order by actions.created_at desc
        limit 10
      ) a
    ) as prior_actions
  from item as i;
end;
$$;

revoke all on function public.admin_overview_metrics(timestamptz, timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_overview_metrics(timestamptz, timestamptz)
  to authenticated;

revoke all on function public.admin_review_queue(text, text, text, text, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_review_queue(text, text, text, text, integer)
  to authenticated;

revoke all on function public.admin_review_item(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_review_item(text, uuid)
  to authenticated;

comment on function public.admin_overview_metrics(timestamptz, timestamptz) is
  'Staff-only overview counts, trend, distribution, and recent moderation actions. Empty for non-staff.';
comment on function public.admin_review_queue(text, text, text, text, integer) is
  'Staff-only union of report, correction, removal, and merge queues with stable cursor pagination. No reporter identity.';
comment on function public.admin_review_item(text, uuid) is
  'Staff-only single review item with target context and prior moderation actions. Never reads Logbook.';
