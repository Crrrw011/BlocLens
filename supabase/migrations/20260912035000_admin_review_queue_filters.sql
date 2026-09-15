-- Extend the review queue projection with kind and severity filters.
-- Both default to 'all' so existing five-argument callers keep working.

drop function if exists public.admin_review_queue(text, text, text, text, integer);

create or replace function public.admin_review_queue(
  status_filter text,
  target_filter text,
  search_text text,
  page_after text,
  page_size integer,
  kind_filter text default 'all',
  severity_filter text default 'all'
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
  want_kind text := coalesce(nullif(btrim(admin_review_queue.kind_filter), ''), 'all');
  want_severity text := coalesce(nullif(btrim(admin_review_queue.severity_filter), ''), 'all');
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
  if want_kind not in (
    'all', 'content_report', 'route_correction', 'removal_report', 'merge_suggestion'
  ) then
    raise exception using errcode = '22023', message = 'invalid review kind filter';
  end if;
  if want_severity not in ('all', 'severe', 'normal') then
    raise exception using errcode = '22023', message = 'invalid review severity filter';
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
    and (want_kind = 'all' or q.kind = want_kind)
    and (want_severity = 'all' or q.severity = want_severity)
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

revoke all on function public.admin_review_queue(text, text, text, text, integer, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_review_queue(text, text, text, text, integer, text, text)
  to authenticated;

comment on function public.admin_review_queue(text, text, text, text, integer, text, text) is
  'Staff-only union of report, correction, removal, and merge queues with kind, severity, and stable cursor pagination. No reporter identity.';
