-- Transactional route merge with impact preview and explicit conflict acknowledgement.
-- Only counts (never Logbook content, notes, or emails) leave the database.

create or replace function public.admin_route_merge_impact(
  source_id uuid,
  canonical_id uuid
)
returns table (
  ok boolean,
  error_code text,
  impact jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
  source public.routes%rowtype;
  canonical public.routes%rowtype;
  chain_id uuid;
  chain_depth integer := 0;
  counts jsonb;
  conflicts jsonb := '[]'::jsonb;
  r record;
begin
  if admin_route_merge_impact.source_id is null
    or admin_route_merge_impact.canonical_id is null
  then
    raise exception using errcode = '22023', message = 'invalid merge reference';
  end if;

  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = caller_id
      and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
      and roles.revoked_at is null
  ) into is_staff;

  if not is_staff then
    return query select false, 'forbidden'::text, null::jsonb;
    return;
  end if;

  if admin_route_merge_impact.source_id = admin_route_merge_impact.canonical_id then
    return query select false, 'invalid'::text, null::jsonb;
    return;
  end if;

  select routes.* into source
  from public.routes as routes
  where routes.id = admin_route_merge_impact.source_id;

  select routes.* into canonical
  from public.routes as routes
  where routes.id = admin_route_merge_impact.canonical_id;

  if source.id is null or canonical.id is null
    or source.deleted_at is not null or canonical.deleted_at is not null
  then
    return query select false, 'not_found'::text, null::jsonb;
    return;
  end if;

  if source.gym_id <> canonical.gym_id then
    return query select false, 'cross_gym'::text, null::jsonb;
    return;
  end if;

  if source.canonical_route_id is not null then
    return query select false, 'already_merged'::text, null::jsonb;
    return;
  end if;

  -- Walk the canonical chain: merging into a merged route, or any cycle, is refused.
  chain_id := canonical.canonical_route_id;
  while chain_id is not null and chain_depth < 10 loop
    if chain_id = source.id then
      return query select false, 'cycle'::text, null::jsonb;
      return;
    end if;
    select routes.canonical_route_id into chain_id
    from public.routes as routes where routes.id = chain_id;
    chain_depth := chain_depth + 1;
  end loop;

  if canonical.canonical_route_id is not null then
    return query select false, 'invalid'::text, null::jsonb;
    return;
  end if;

  select jsonb_build_object(
    'logbook_entries', (select count(*) from public.logbook_entries as l
      where l.route_id = source.id and l.deleted_at is null),
    'route_photos', (select count(*) from public.route_photos as photos
      where photos.route_id = source.id and photos.deleted_at is null),
    'beta_links', (select count(*) from public.beta_links as links
      where links.route_id = source.id and links.deleted_at is null),
    'route_corrections', (select count(*) from public.route_corrections as corrections
      where corrections.route_id = source.id
        and corrections.status in ('open'::public.correction_status, 'under_review'::public.correction_status)),
    'removal_reports', (select count(*) from public.route_removal_reports as removals
      where removals.route_id = source.id
        and removals.status in ('open'::public.report_status, 'under_review'::public.report_status)),
    'content_reports', (select count(*) from public.content_reports as reports
      where reports.target_type = 'route'::public.content_type and reports.target_id = source.id),
    'grade_votes', (select count(*) from public.route_grade_votes as votes
      where votes.route_id = source.id)
  ) into counts;

  -- Duplicate conflicts: rows that cannot move without violating a unique key.
  for r in
    select l.id as row_id, 'logbook_entries'::text as tbl
    from public.logbook_entries as l
    where l.route_id = source.id and l.deleted_at is null
      and exists (
        select 1 from public.logbook_entries as c
        where c.route_id = canonical.id and c.user_id = l.user_id and c.deleted_at is null
      )
  loop
    conflicts := conflicts || jsonb_build_object(
      'key', r.tbl || ':' || r.row_id::text, 'table', r.tbl, 'source_id', r.row_id);
  end loop;

  for r in
    select votes.id as row_id, 'route_grade_votes'::text as tbl
    from public.route_grade_votes as votes
    where votes.route_id = source.id
      and exists (
        select 1 from public.route_grade_votes as c
        where c.route_id = canonical.id and c.user_id = votes.user_id
      )
  loop
    conflicts := conflicts || jsonb_build_object(
      'key', r.tbl || ':' || r.row_id::text, 'table', r.tbl, 'source_id', r.row_id);
  end loop;

  for r in
    select corrections.id as row_id, 'route_corrections'::text as tbl
    from public.route_corrections as corrections
    where corrections.route_id = source.id
      and corrections.status in ('open'::public.correction_status, 'under_review'::public.correction_status)
      and exists (
        select 1 from public.route_corrections as c
        where c.route_id = canonical.id
          and c.submitted_by = corrections.submitted_by
          and c.issue_key = corrections.issue_key
          and c.status in ('open'::public.correction_status, 'under_review'::public.correction_status)
      )
  loop
    conflicts := conflicts || jsonb_build_object(
      'key', r.tbl || ':' || r.row_id::text, 'table', r.tbl, 'source_id', r.row_id);
  end loop;

  for r in
    select removals.id as row_id, 'route_removal_reports'::text as tbl
    from public.route_removal_reports as removals
    where removals.route_id = source.id
      and exists (
        select 1 from public.route_removal_reports as c
        where c.route_id = canonical.id and c.reported_by = removals.reported_by
      )
  loop
    conflicts := conflicts || jsonb_build_object(
      'key', r.tbl || ':' || r.row_id::text, 'table', r.tbl, 'source_id', r.row_id);
  end loop;

  for r in
    select reports.id as row_id, 'content_reports'::text as tbl
    from public.content_reports as reports
    where reports.target_type = 'route'::public.content_type
      and reports.target_id = source.id
      and exists (
        select 1 from public.content_reports as c
        where c.target_type = 'route'::public.content_type
          and c.target_id = canonical.id
          and c.reporter_id = reports.reporter_id
      )
  loop
    conflicts := conflicts || jsonb_build_object(
      'key', r.tbl || ':' || r.row_id::text, 'table', r.tbl, 'source_id', r.row_id);
  end loop;

  for r in
    select links.id as row_id, 'beta_links'::text as tbl
    from public.beta_links as links
    where links.route_id = source.id and links.deleted_at is null
      and exists (
        select 1 from public.beta_links as c
        where c.route_id = canonical.id
          and c.normalised_url_hash = links.normalised_url_hash
          and c.deleted_at is null
      )
  loop
    conflicts := conflicts || jsonb_build_object(
      'key', r.tbl || ':' || r.row_id::text, 'table', r.tbl, 'source_id', r.row_id);
  end loop;

  return query select true, null::text, jsonb_build_object(
    'source', jsonb_build_object(
      'id', source.id, 'colour', source.colour, 'gym_grade', source.gym_grade,
      'lifecycle', source.lifecycle, 'updated_at', source.updated_at),
    'canonical', jsonb_build_object(
      'id', canonical.id, 'colour', canonical.colour, 'gym_grade', canonical.gym_grade,
      'lifecycle', canonical.lifecycle, 'updated_at', canonical.updated_at),
    'counts', counts,
    'conflicts', conflicts
  );
end;
$$;

create or replace function public.admin_merge_routes(
  source_id uuid,
  canonical_id uuid,
  resolutions jsonb,
  reason text,
  expected_versions jsonb,
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
  clean_reason text := btrim(coalesce(admin_merge_routes.reason, ''));
  source public.routes%rowtype;
  canonical public.routes%rowtype;
  chain_id uuid;
  chain_depth integer := 0;
  source_version timestamptz := null;
  canonical_version timestamptz := null;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
  preview jsonb := null;
  preview_error text := null;
  conflict_keys text[] := '{}';
  conflict_key text;
  skipped uuid[] := '{}';
  key text;
  value jsonb;
  r record;
  moved integer := 0;
  migrated jsonb := '{}'::jsonb;
  auto_skipped integer := 0;
begin
  if admin_merge_routes.source_id is null
    or admin_merge_routes.canonical_id is null
    or admin_merge_routes.source_id = admin_merge_routes.canonical_id
    or admin_merge_routes.resolutions is null
    or jsonb_typeof(admin_merge_routes.resolutions) <> 'object'
    or char_length(clean_reason) not between 1 and 2000
    or admin_merge_routes.expected_versions is null
    or jsonb_typeof(admin_merge_routes.expected_versions) <> 'object'
    or admin_merge_routes.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid merge input';
  end if;

  begin
    source_version := (admin_merge_routes.expected_versions ->> 'source')::timestamptz;
    canonical_version := (admin_merge_routes.expected_versions ->> 'canonical')::timestamptz;
  exception when others then
    raise exception using errcode = '22023', message = 'invalid merge input';
  end;
  if source_version is null or canonical_version is null then
    raise exception using errcode = '22023', message = 'invalid merge input';
  end if;

  for key, value in select * from jsonb_each(admin_merge_routes.resolutions) loop
    if jsonb_typeof(value) <> 'string' or value #>> '{}' <> 'skip' then
      raise exception using errcode = '22023', message = 'invalid merge resolutions';
    end if;
  end loop;

  select roles.role into actor_role
  from public.app_user_roles as roles
  where roles.user_id = actor_id
    and roles.revoked_at is null
    and roles.role = 'admin'::public.app_role
  limit 1;

  if actor_role is null then
    audit_id := private.append_admin_audit(
      actor_id, 'route.merge', 'route',
      admin_merge_routes.source_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('canonical_id', admin_merge_routes.canonical_id, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_merge_routes.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_merge_routes.idempotency_key
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

  -- Lock both routes in id order to avoid deadlocks.
  if admin_merge_routes.source_id < admin_merge_routes.canonical_id then
    select routes.* into source from public.routes as routes
    where routes.id = admin_merge_routes.source_id for update;
    select routes.* into canonical from public.routes as routes
    where routes.id = admin_merge_routes.canonical_id for update;
  else
    select routes.* into canonical from public.routes as routes
    where routes.id = admin_merge_routes.canonical_id for update;
    select routes.* into source from public.routes as routes
    where routes.id = admin_merge_routes.source_id for update;
  end if;

  if source.id is null or canonical.id is null
    or source.deleted_at is not null or canonical.deleted_at is not null
  then
    audit_id := private.append_admin_audit(
      actor_id, 'route.merge', 'route', admin_merge_routes.source_id,
      clean_reason, 'failed', '{}'::jsonb,
      jsonb_build_object('canonical_id', admin_merge_routes.canonical_id, 'error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_merge_routes.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if source.gym_id <> canonical.gym_id then
    preview_error := 'cross_gym';
  elsif source.canonical_route_id is not null then
    preview_error := 'already_merged';
  else
    chain_id := canonical.canonical_route_id;
    while chain_id is not null and chain_depth < 10 loop
      if chain_id = source.id then
        preview_error := 'cycle';
        exit;
      end if;
      select routes.canonical_route_id into chain_id
      from public.routes as routes where routes.id = chain_id;
      chain_depth := chain_depth + 1;
    end loop;
    if preview_error is null and canonical.canonical_route_id is not null then
      preview_error := 'invalid';
    end if;
  end if;

  if preview_error is not null then
    audit_id := private.append_admin_audit(
      actor_id, 'route.merge', 'route', source.id,
      clean_reason, 'failed',
      jsonb_build_object('lifecycle', source.lifecycle),
      jsonb_build_object('canonical_id', canonical.id, 'error_code', preview_error),
      extensions.gen_random_uuid(), admin_merge_routes.idempotency_key
    );
    return query select false, preview_error, audit_id, '{}'::jsonb;
    return;
  end if;

  -- Recompute conflicts inside the same transaction (preview may be stale).
  select i.impact into preview
  from public.admin_route_merge_impact(
    admin_merge_routes.source_id, admin_merge_routes.canonical_id
  ) as i where i.ok;

  if preview is null then
    audit_id := private.append_admin_audit(
      actor_id, 'route.merge', 'route', source.id,
      clean_reason, 'failed',
      jsonb_build_object('lifecycle', source.lifecycle),
      jsonb_build_object('canonical_id', canonical.id, 'error_code', 'invalid'),
      extensions.gen_random_uuid(), admin_merge_routes.idempotency_key
    );
    return query select false, 'invalid'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select array_agg(conflict ->> 'key') into conflict_keys
  from jsonb_array_elements(preview -> 'conflicts') as conflict;

  if conflict_keys is not null then
    foreach conflict_key in array conflict_keys loop
      if (admin_merge_routes.resolutions ->> conflict_key) is distinct from 'skip' then
        audit_id := private.append_admin_audit(
          actor_id, 'route.merge', 'route', source.id,
          clean_reason, 'failed',
          jsonb_build_object('lifecycle', source.lifecycle),
          jsonb_build_object(
            'canonical_id', canonical.id, 'error_code', 'unresolved_conflicts',
            'missing', conflict_key),
          extensions.gen_random_uuid(), admin_merge_routes.idempotency_key
        );
        return query select false, 'unresolved_conflicts'::text, audit_id, '{}'::jsonb;
        return;
      end if;
      skipped := skipped || (split_part(conflict_key, ':', 2))::uuid;
    end loop;
  end if;

  if source.updated_at is distinct from source_version
    or canonical.updated_at is distinct from canonical_version
  then
    audit_id := private.append_admin_audit(
      actor_id, 'route.merge', 'route', source.id,
      clean_reason, 'failed',
      jsonb_build_object('lifecycle', source.lifecycle),
      jsonb_build_object('canonical_id', canonical.id, 'error_code', 'conflict'),
      extensions.gen_random_uuid(), admin_merge_routes.idempotency_key
    );
    return query select false, 'conflict'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  -- Migrate every supported relationship; acknowledged conflicts stay behind.
  update public.logbook_entries as l set route_id = canonical.id
  where l.route_id = source.id and l.deleted_at is null and not (l.id = any (skipped));
  get diagnostics moved = row_count;
  migrated := migrated || jsonb_build_object('logbook_entries', moved);

  update public.route_grade_votes as votes set route_id = canonical.id
  where votes.route_id = source.id and not (votes.id = any (skipped));
  get diagnostics moved = row_count;
  migrated := migrated || jsonb_build_object('grade_votes', moved);

  update public.route_photos as photos set route_id = canonical.id
  where photos.route_id = source.id and photos.deleted_at is null;
  get diagnostics moved = row_count;
  migrated := migrated || jsonb_build_object('photos', moved);

  update public.beta_links as links set route_id = canonical.id
  where links.route_id = source.id and links.deleted_at is null
    and not (links.id = any (skipped));
  get diagnostics moved = row_count;
  migrated := migrated || jsonb_build_object('beta_links', moved);

  update public.route_corrections as corrections set route_id = canonical.id
  where corrections.route_id = source.id and not (corrections.id = any (skipped));
  get diagnostics moved = row_count;
  migrated := migrated || jsonb_build_object('corrections', moved);

  update public.route_removal_reports as removals set route_id = canonical.id
  where removals.route_id = source.id and not (removals.id = any (skipped));
  get diagnostics moved = row_count;
  migrated := migrated || jsonb_build_object('removal_reports', moved);

  update public.content_reports as reports set target_id = canonical.id
  where reports.target_type = 'route'::public.content_type
    and reports.target_id = source.id and not (reports.id = any (skipped));
  get diagnostics moved = row_count;
  migrated := migrated || jsonb_build_object('content_reports', moved);

  -- Merge suggestions: satisfied ones complete; unsafe repoints stay behind.
  for r in
    select suggestions.* from public.route_merge_suggestions as suggestions
    where suggestions.source_route_id = source.id
  loop
    if r.proposed_canonical_route_id = canonical.id then
      update public.route_merge_suggestions
      set status = 'completed'::public.merge_status,
          reviewed_by = actor_id, reviewed_at = statement_timestamp(),
          completed_at = statement_timestamp()
      where id = r.id;
    elsif exists (
      select 1 from public.route_merge_suggestions as existing
      where existing.source_route_id = canonical.id
        and existing.proposed_canonical_route_id = r.proposed_canonical_route_id
        and existing.suggested_by = r.suggested_by
        and existing.id <> r.id
    ) then
      auto_skipped := auto_skipped + 1;
    else
      update public.route_merge_suggestions
      set source_route_id = canonical.id where id = r.id;
    end if;
  end loop;

  for r in
    select suggestions.* from public.route_merge_suggestions as suggestions
    where suggestions.proposed_canonical_route_id = source.id
  loop
    if r.source_route_id = canonical.id then
      auto_skipped := auto_skipped + 1;
    elsif exists (
      select 1 from public.route_merge_suggestions as existing
      where existing.source_route_id = r.source_route_id
        and existing.proposed_canonical_route_id = canonical.id
        and existing.suggested_by = r.suggested_by
        and existing.id <> r.id
    ) then
      auto_skipped := auto_skipped + 1;
    else
      update public.route_merge_suggestions
      set proposed_canonical_route_id = canonical.id where id = r.id;
    end if;
  end loop;

  update public.routes
  set lifecycle = 'archived'::public.route_lifecycle,
      archived_at = statement_timestamp(),
      canonical_route_id = canonical.id
  where id = source.id;

  insert into public.moderation_actions (
    action_type, target_type, target_id, performed_by, reason
  ) values (
    'merge'::public.moderation_action_type, 'route'::public.content_type,
    source.id, actor_id, left(clean_reason, 1000)
  );

  audit_id := private.append_admin_audit(
    actor_id, 'route.merge', 'route', source.id,
    clean_reason, 'succeeded',
    jsonb_build_object('lifecycle', source.lifecycle),
    jsonb_build_object(
      'canonical_id', canonical.id,
      'migrated', migrated,
      'skipped_conflicts', (select coalesce(array_to_json(skipped)::jsonb, '[]'::jsonb)),
      'auto_skipped_suggestions', auto_skipped,
      'result', jsonb_build_object('canonical_id', canonical.id, 'lifecycle', 'archived')
    ),
    extensions.gen_random_uuid(), admin_merge_routes.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('canonical_id', canonical.id, 'migrated', migrated);
end;
$$;

revoke all on function public.admin_route_merge_impact(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_route_merge_impact(uuid, uuid)
  to authenticated;

revoke all on function public.admin_merge_routes(uuid, uuid, jsonb, text, jsonb, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_merge_routes(uuid, uuid, jsonb, text, jsonb, uuid)
  to authenticated;

comment on function public.admin_route_merge_impact(uuid, uuid) is
  'Staff-only duplicate impact preview: counts (never Logbook content) plus unique-key conflicts requiring acknowledgement.';
comment on function public.admin_merge_routes(uuid, uuid, jsonb, text, jsonb, uuid) is
  'Administrator-only transactional route merge with conflict acknowledgement, version guard, and idempotent audit.';
