-- Guarded permanent deletion for eligible climbing-data records.
-- Referenced routes, gyms, and wall zones are never hard-deleted.
-- Storage cleanup runs in the trusted server workflow before this transaction;
-- this function revalidates eligibility and leaves an audit tombstone.

create or replace function public.admin_deletion_impact(
  target_type text,
  target_id uuid
)
returns table (
  eligible boolean,
  blockers text[],
  dependent_counts jsonb,
  storage_paths text[],
  alternative text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
  route public.routes%rowtype;
  photo public.route_photos%rowtype;
  link public.beta_links%rowtype;
  comment public.beta_comments%rowtype;
begin
  if admin_deletion_impact.target_type is null
    or admin_deletion_impact.target_id is null
  then
    raise exception using errcode = '22023', message = 'invalid deletion reference';
  end if;

  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = caller_id
      and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
      and roles.revoked_at is null
  ) into is_staff;

  if not is_staff then
    return query select false, array['forbidden']::text[],
      '{}'::jsonb, '{}'::text[], null::text;
    return;
  end if;

  if admin_deletion_impact.target_type = 'route' then
    select routes.* into route
    from public.routes as routes
    where routes.id = admin_deletion_impact.target_id;

    if route.id is null or route.deleted_at is not null then
      return query select false, array['not_found']::text[],
        '{}'::jsonb, '{}'::text[], null::text;
      return;
    end if;

    return query
    with counts as (
      select
        (select count(*) from public.logbook_entries as l
          where l.route_id = route.id and l.deleted_at is null)::integer as logbook_entries,
        (select count(*) from public.route_photos as photos
          where photos.route_id = route.id and photos.deleted_at is null)::integer as route_photos,
        (select count(*) from public.beta_links as links
          where links.route_id = route.id and links.deleted_at is null)::integer as beta_links,
        (select count(*) from public.route_corrections as corrections
          where corrections.route_id = route.id)::integer as route_corrections,
        (select count(*) from public.route_removal_reports as removals
          where removals.route_id = route.id)::integer as removal_reports,
        (select count(*) from public.content_reports as reports
          where reports.target_type = 'route'::public.content_type
            and reports.target_id = route.id)::integer as content_reports,
        (select count(*) from public.route_grade_votes as votes
          where votes.route_id = route.id)::integer as grade_votes,
        (select count(*) from public.route_merge_suggestions as merges
          where merges.source_route_id = route.id
            or merges.proposed_canonical_route_id = route.id)::integer as merge_suggestions,
        (select count(*) from public.routes as children
          where children.canonical_route_id = route.id)::integer as merged_children
    )
    select
      (select bool_and(value = '0') from jsonb_each_text(to_jsonb(counts)) as value),
      (select coalesce(array_agg(blocker order by blocker), '{}')
       from (
         select 'logbook_references' as blocker where counts.logbook_entries > 0
         union all select 'has_photos' where counts.route_photos > 0
         union all select 'has_beta_links' where counts.beta_links > 0
         union all select 'has_corrections' where counts.route_corrections > 0
         union all select 'has_removal_reports' where counts.removal_reports > 0
         union all select 'has_reports' where counts.content_reports > 0
         union all select 'has_grade_votes' where counts.grade_votes > 0
         union all select 'has_merge_suggestions' where counts.merge_suggestions > 0
         union all select 'has_merged_children' where counts.merged_children > 0
         union all select 'is_merged_source' where route.canonical_route_id is not null
       ) blockers),
      to_jsonb(counts),
      '{}'::text[],
      (case
        when counts.logbook_entries > 0 then 'merge'
        when (select count(*) from jsonb_each_text(to_jsonb(counts)) as v where v.value <> '0') > 0 then 'archive'
        else null
      end)::text
    from counts;
    return;
  end if;

  if admin_deletion_impact.target_type = 'route_photo' then
    select photos.* into photo
    from public.route_photos as photos
    where photos.id = admin_deletion_impact.target_id;

    if photo.id is null or photo.deleted_at is not null then
      return query select false, array['not_found']::text[],
        '{}'::jsonb, '{}'::text[], null::text;
      return;
    end if;

    return query select true, '{}'::text[],
      jsonb_build_object(
        'helpful_votes', (select count(*) from public.route_photo_helpful_votes as votes
          where votes.photo_id = photo.id)),
      array[photo.storage_path],
      null::text;
    return;
  end if;

  if admin_deletion_impact.target_type = 'beta_link' then
    select links.* into link
    from public.beta_links as links
    where links.id = admin_deletion_impact.target_id;

    if link.id is null or link.deleted_at is not null then
      return query select false, array['not_found']::text[],
        '{}'::jsonb, '{}'::text[], null::text;
      return;
    end if;

    return query
    with counts as (
      select
        (select count(*) from public.beta_comments as comments
          where comments.beta_link_id = link.id and comments.deleted_at is null)::integer as beta_comments,
        (select count(*) from public.beta_helpful_votes as votes
          where votes.beta_link_id = link.id and votes.deleted_at is null)::integer as helpful_votes
    )
    select
      (select bool_and(value = '0') from jsonb_each_text(to_jsonb(counts)) as only_votes
       where only_votes.key = 'beta_comments'),
      (select case when counts.beta_comments > 0
        then array['has_comments']::text[] else '{}'::text[] end from counts),
      to_jsonb(counts),
      '{}'::text[],
      null::text
    from counts;
    return;
  end if;

  if admin_deletion_impact.target_type = 'route_comment' then
    select comments.* into comment
    from public.beta_comments as comments
    where comments.id = admin_deletion_impact.target_id;

    if comment.id is null or comment.deleted_at is not null then
      return query select false, array['not_found']::text[],
        '{}'::jsonb, '{}'::text[], null::text;
      return;
    end if;

    return query select true, '{}'::text[], '{}'::jsonb, '{}'::text[], null::text;
    return;
  end if;

  if admin_deletion_impact.target_type in ('gym', 'wall_zone', 'reset') then
    return query select false, array['retained_relationship']::text[],
      '{}'::jsonb, '{}'::text[],
      (case when admin_deletion_impact.target_type = 'reset' then null else 'archive' end)::text;
    return;
  end if;

  return query select false, array['unsupported_type']::text[],
    '{}'::jsonb, '{}'::text[], null::text;
end;
$$;

create or replace function public.admin_permanently_delete(
  target_type text,
  target_id uuid,
  reason text,
  expected_updated_at timestamptz,
  idempotency_key uuid
)
returns table (
  ok boolean,
  error_code text,
  audit_event_id uuid,
  result jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_role public.app_role := null;
  clean_reason text := btrim(coalesce(admin_permanently_delete.reason, ''));
  current_updated_at timestamptz := null;
  tombstone jsonb := '{}'::jsonb;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
  impact_eligible boolean := false;
  impact_blockers text[] := '{}';
  impact_storage text[] := '{}';
begin
  if admin_permanently_delete.target_type is null
    or admin_permanently_delete.target_type not in (
      'route', 'route_photo', 'beta_link', 'route_comment'
    )
    or admin_permanently_delete.target_id is null
    or char_length(clean_reason) not between 1 and 2000
    or admin_permanently_delete.expected_updated_at is null
    or admin_permanently_delete.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid deletion input';
  end if;

  select roles.role into actor_role
  from public.app_user_roles as roles
  where roles.user_id = actor_id
    and roles.revoked_at is null
    and roles.role = 'admin'::public.app_role
  limit 1;

  if actor_role is null then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.deleted', admin_permanently_delete.target_type,
      admin_permanently_delete.target_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_permanently_delete.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_permanently_delete.idempotency_key
  order by audit.created_at desc
  limit 1;

  if prior_audit.id is not null then
    return query select
      prior_audit.outcome = 'succeeded',
      (prior_audit.after_summary ->> 'error_code'),
      prior_audit.id,
      coalesce(prior_audit.after_summary -> 'result', '{}'::jsonb);
    return;
  end if;

  -- Lock the target and build its tombstone.
  case admin_permanently_delete.target_type
    when 'route' then
      select jsonb_build_object(
          'colour', routes.colour, 'gym_id', routes.gym_id,
          'wall_zone_id', routes.wall_zone_id, 'lifecycle', routes.lifecycle),
        routes.updated_at
      into tombstone, current_updated_at
      from public.routes as routes
      where routes.id = admin_permanently_delete.target_id for update;
    when 'route_photo' then
      select jsonb_build_object(
          'route_id', photos.route_id, 'storage_path', photos.storage_path),
        photos.updated_at
      into tombstone, current_updated_at
      from public.route_photos as photos
      where photos.id = admin_permanently_delete.target_id for update;
    when 'beta_link' then
      select jsonb_build_object(
          'route_id', links.route_id, 'platform', links.platform,
          'author', links.original_author_display_name),
        links.updated_at
      into tombstone, current_updated_at
      from public.beta_links as links
      where links.id = admin_permanently_delete.target_id for update;
    else
      select jsonb_build_object(
          'beta_link_id', comments.beta_link_id,
          'excerpt', left(comments.body, 80)),
        comments.updated_at
      into tombstone, current_updated_at
      from public.beta_comments as comments
      where comments.id = admin_permanently_delete.target_id for update;
  end case;

  if current_updated_at is null then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.deleted', admin_permanently_delete.target_type,
      admin_permanently_delete.target_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_permanently_delete.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  -- Revalidate eligibility inside the deletion transaction.
  select row.eligible, row.blockers, row.storage_paths
  into impact_eligible, impact_blockers, impact_storage
  from public.admin_deletion_impact(
    admin_permanently_delete.target_type, admin_permanently_delete.target_id
  ) as row;

  if not impact_eligible then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.deleted', admin_permanently_delete.target_type,
      admin_permanently_delete.target_id, clean_reason, 'failed',
      tombstone,
      jsonb_build_object('error_code', 'blocked', 'blockers', impact_blockers),
      extensions.gen_random_uuid(), admin_permanently_delete.idempotency_key
    );
    return query select false, 'blocked'::text, audit_id,
      jsonb_build_object('blockers', impact_blockers);
    return;
  end if;

  if current_updated_at is distinct from admin_permanently_delete.expected_updated_at then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.deleted', admin_permanently_delete.target_type,
      admin_permanently_delete.target_id, clean_reason, 'failed',
      tombstone,
      jsonb_build_object('error_code', 'conflict'),
      extensions.gen_random_uuid(), admin_permanently_delete.idempotency_key
    );
    return query select false, 'conflict'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  case admin_permanently_delete.target_type
    when 'route' then
      delete from public.routes as routes
      where routes.id = admin_permanently_delete.target_id;
    when 'route_photo' then
      delete from public.route_photos as photos
      where photos.id = admin_permanently_delete.target_id;
    when 'beta_link' then
      delete from public.beta_links as links
      where links.id = admin_permanently_delete.target_id;
    else
      delete from public.beta_comments as comments
      where comments.id = admin_permanently_delete.target_id;
  end case;

  tombstone := tombstone || jsonb_build_object(
    'target_type', admin_permanently_delete.target_type,
    'target_id', admin_permanently_delete.target_id,
    'deleted_at', statement_timestamp());

  audit_id := private.append_admin_audit(
    actor_id, 'entity.deleted', admin_permanently_delete.target_type,
    admin_permanently_delete.target_id, clean_reason, 'succeeded',
    tombstone,
    jsonb_build_object(
      'storage_paths', to_jsonb(impact_storage),
      'result', jsonb_build_object('deleted', true)),
    extensions.gen_random_uuid(), admin_permanently_delete.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('deleted', true);
end;
$$;

revoke all on function public.admin_deletion_impact(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_deletion_impact(text, uuid)
  to authenticated;

revoke all on function public.admin_permanently_delete(text, uuid, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_permanently_delete(text, uuid, text, timestamptz, uuid)
  to authenticated;

comment on function public.admin_deletion_impact(text, uuid) is
  'Eligibility, blockers, dependent counts, and storage paths for a deletion target. Staff-only.';
comment on function public.admin_permanently_delete(text, uuid, text, timestamptz, uuid) is
  'Administrator-only hard deletion with revalidated eligibility, version guard, and audit tombstone.';
