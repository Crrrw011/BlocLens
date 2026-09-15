-- Transactional staff review decisions with role matrix, version guard, and audit.
-- Rejected attempts return outcome rows (ok = false) and are audited as failures.

create or replace function public.admin_decide_review(
  item_kind text,
  item_id uuid,
  decision text,
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
  clean_reason text := btrim(coalesce(admin_decide_review.reason, ''));
  current_status text := null;
  current_updated_at timestamptz := null;
  report_target_type public.content_type := null;
  report_target_id uuid := null;
  route_target_id uuid := null;
  target_moderation public.moderation_status := null;
  required_admin boolean := false;
  new_status text := null;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
begin
  if admin_decide_review.item_kind is null
    or admin_decide_review.item_kind not in (
      'content_report', 'route_correction', 'removal_report', 'merge_suggestion'
    )
    or admin_decide_review.item_id is null
    or admin_decide_review.decision is null
    or admin_decide_review.decision not in (
      'dismiss', 'escalate', 'hide', 'restore', 'accept_correction', 'reject_correction'
    )
    or char_length(clean_reason) not between 1 and 2000
    or admin_decide_review.expected_updated_at is null
    or admin_decide_review.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid review decision input';
  end if;

  select roles.role into actor_role
  from public.app_user_roles as roles
  where roles.user_id = actor_id
    and roles.revoked_at is null
    and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
  order by case roles.role when 'admin'::public.app_role then 0 else 1 end
  limit 1;

  if actor_role is null then
    audit_id := private.append_admin_audit(
      actor_id, 'review.decision', admin_decide_review.item_kind,
      admin_decide_review.item_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('decision', admin_decide_review.decision, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_decide_review.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id,
      jsonb_build_object('decision', admin_decide_review.decision);
    return;
  end if;

  -- Lock the source row and read its versioned state.
  if admin_decide_review.item_kind = 'content_report' then
    select reports.status::text, reports.updated_at,
      reports.target_type, reports.target_id
    into current_status, current_updated_at, report_target_type, report_target_id
    from public.content_reports as reports
    where reports.id = admin_decide_review.item_id
    for update;
    route_target_id := case when report_target_type = 'route'::public.content_type
      then report_target_id else null end;
  elsif admin_decide_review.item_kind = 'route_correction' then
    select corrections.status::text, corrections.updated_at
    into current_status, current_updated_at
    from public.route_corrections as corrections
    where corrections.id = admin_decide_review.item_id
    for update;
    route_target_id := null;
    select corrections.route_id into route_target_id
    from public.route_corrections as corrections
    where corrections.id = admin_decide_review.item_id;
  elsif admin_decide_review.item_kind = 'removal_report' then
    select removals.status::text, removals.updated_at, removals.route_id
    into current_status, current_updated_at, route_target_id
    from public.route_removal_reports as removals
    where removals.id = admin_decide_review.item_id
    for update;
  else
    select merges.status::text, merges.updated_at
    into current_status, current_updated_at
    from public.route_merge_suggestions as merges
    where merges.id = admin_decide_review.item_id
    for update;
  end if;

  if current_status is null then
    audit_id := private.append_admin_audit(
      actor_id, 'review.decision', admin_decide_review.item_kind,
      admin_decide_review.item_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('decision', admin_decide_review.decision, 'error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_decide_review.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id,
      jsonb_build_object('decision', admin_decide_review.decision);
    return;
  end if;

  -- A replayed key returns the stored outcome without mutating.
  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_decide_review.idempotency_key
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

  -- Role matrix and transition validity.
  if admin_decide_review.item_kind = 'content_report' then
    if admin_decide_review.decision = 'dismiss'
      and current_status in ('open', 'under_review') then
      new_status := 'dismissed';
    elsif admin_decide_review.decision = 'escalate'
      and current_status = 'open' then
      new_status := 'under_review';
    elsif admin_decide_review.decision = 'hide'
      and current_status in ('open', 'under_review') then
      new_status := 'resolved';
    elsif admin_decide_review.decision = 'restore'
      and current_status = 'resolved' then
      new_status := 'resolved';
    end if;
  elsif admin_decide_review.item_kind = 'route_correction' then
    if admin_decide_review.decision = 'escalate'
      and current_status = 'open' then
      new_status := 'under_review';
    elsif admin_decide_review.decision = 'reject_correction'
      and current_status in ('open', 'under_review') then
      new_status := 'rejected';
    elsif admin_decide_review.decision = 'accept_correction'
      and current_status in ('open', 'under_review') then
      required_admin := true;
      new_status := 'accepted';
    end if;
  elsif admin_decide_review.item_kind = 'removal_report' then
    if admin_decide_review.decision = 'dismiss'
      and current_status in ('open', 'under_review') then
      new_status := 'dismissed';
    elsif admin_decide_review.decision = 'escalate'
      and current_status = 'open' then
      new_status := 'under_review';
    end if;
  else
    if admin_decide_review.decision = 'reject_correction'
      and current_status = 'proposed' then
      new_status := 'rejected';
    elsif admin_decide_review.decision = 'accept_correction'
      and current_status = 'proposed' then
      required_admin := true;
      new_status := 'approved';
    end if;
  end if;

  if new_status is null
    or (required_admin and actor_role <> 'admin'::public.app_role)
  then
    audit_id := private.append_admin_audit(
      actor_id, 'review.decision', admin_decide_review.item_kind,
      admin_decide_review.item_id, clean_reason, 'failed',
      jsonb_build_object('status', current_status),
      jsonb_build_object(
        'decision', admin_decide_review.decision,
        'error_code', case when new_status is null then 'invalid_transition' else 'forbidden' end
      ),
      extensions.gen_random_uuid(), admin_decide_review.idempotency_key
    );
    return query select false,
      (case when new_status is null then 'invalid_transition' else 'forbidden' end)::text,
      audit_id, jsonb_build_object('decision', admin_decide_review.decision);
    return;
  end if;

  if current_updated_at is distinct from admin_decide_review.expected_updated_at then
    audit_id := private.append_admin_audit(
      actor_id, 'review.decision', admin_decide_review.item_kind,
      admin_decide_review.item_id, clean_reason, 'failed',
      jsonb_build_object('status', current_status),
      jsonb_build_object('decision', admin_decide_review.decision, 'error_code', 'conflict'),
      extensions.gen_random_uuid(), admin_decide_review.idempotency_key
    );
    return query select false, 'conflict'::text, audit_id,
      jsonb_build_object('decision', admin_decide_review.decision);
    return;
  end if;

  -- Apply the transition and any canonical target change.
  if admin_decide_review.decision in ('hide', 'restore') then
    if report_target_type is null then
      select removals.route_id into route_target_id
      from public.route_removal_reports as removals
      where removals.id = admin_decide_review.item_id;
      report_target_type := 'route'::public.content_type;
      report_target_id := route_target_id;
    end if;

    if report_target_type = 'route'::public.content_type then
      select moderation_status into target_moderation
      from public.routes where id = report_target_id for update;
    elsif report_target_type = 'beta_link'::public.content_type then
      select moderation_status into target_moderation
      from public.beta_links where id = report_target_id for update;
    elsif report_target_type = 'beta_comment'::public.content_type then
      select moderation_status into target_moderation
      from public.beta_comments where id = report_target_id for update;
    else
      select moderation_status into target_moderation
      from public.route_photos where id = report_target_id for update;
    end if;

    if target_moderation is null then
      audit_id := private.append_admin_audit(
        actor_id, 'review.decision', admin_decide_review.item_kind,
        admin_decide_review.item_id, clean_reason, 'failed',
        jsonb_build_object('status', current_status),
        jsonb_build_object('decision', admin_decide_review.decision, 'error_code', 'not_found'),
        extensions.gen_random_uuid(), admin_decide_review.idempotency_key
      );
      return query select false, 'not_found'::text, audit_id,
        jsonb_build_object('decision', admin_decide_review.decision);
      return;
    end if;

    if admin_decide_review.decision = 'hide' then
      if report_target_type = 'route'::public.content_type then
        update public.routes
        set moderation_status = 'temporarily_hidden'::public.moderation_status,
            lifecycle = 'temporarily_hidden'::public.route_lifecycle,
            hidden_at = coalesce(hidden_at, statement_timestamp())
        where id = report_target_id;
      elsif report_target_type = 'beta_link'::public.content_type then
        update public.beta_links
        set moderation_status = 'temporarily_hidden'::public.moderation_status,
            hidden_at = coalesce(hidden_at, statement_timestamp())
        where id = report_target_id;
      elsif report_target_type = 'beta_comment'::public.content_type then
        update public.beta_comments
        set moderation_status = 'temporarily_hidden'::public.moderation_status,
            hidden_at = coalesce(hidden_at, statement_timestamp())
        where id = report_target_id;
      else
        update public.route_photos
        set moderation_status = 'temporarily_hidden'::public.moderation_status,
            hidden_at = coalesce(hidden_at, statement_timestamp())
        where id = report_target_id;
      end if;
    else
      if target_moderation <> 'temporarily_hidden'::public.moderation_status then
        audit_id := private.append_admin_audit(
          actor_id, 'review.decision', admin_decide_review.item_kind,
          admin_decide_review.item_id, clean_reason, 'failed',
          jsonb_build_object('status', current_status),
          jsonb_build_object('decision', admin_decide_review.decision, 'error_code', 'invalid_transition'),
          extensions.gen_random_uuid(), admin_decide_review.idempotency_key
        );
        return query select false, 'invalid_transition'::text, audit_id,
          jsonb_build_object('decision', admin_decide_review.decision);
        return;
      end if;
      if report_target_type = 'route'::public.content_type then
        update public.routes
        set moderation_status = 'visible'::public.moderation_status,
            lifecycle = 'active'::public.route_lifecycle,
            hidden_at = null
        where id = report_target_id;
      elsif report_target_type = 'beta_link'::public.content_type then
        update public.beta_links
        set moderation_status = 'visible'::public.moderation_status,
            hidden_at = null
        where id = report_target_id;
      elsif report_target_type = 'beta_comment'::public.content_type then
        update public.beta_comments
        set moderation_status = 'visible'::public.moderation_status,
            hidden_at = null
        where id = report_target_id;
      else
        update public.route_photos
        set moderation_status = 'visible'::public.moderation_status,
            hidden_at = null
        where id = report_target_id;
      end if;
    end if;

    insert into public.moderation_actions (
      action_type, target_type, target_id, performed_by, reason
    ) values (
      admin_decide_review.decision::public.moderation_action_type,
      report_target_type, report_target_id, actor_id, left(clean_reason, 1000)
    );
  end if;

  if admin_decide_review.item_kind = 'content_report' then
    update public.content_reports
    set status = new_status::public.report_status
    where id = admin_decide_review.item_id;
  elsif admin_decide_review.item_kind = 'route_correction' then
    update public.route_corrections
    set status = new_status::public.correction_status,
        reviewed_by = case when new_status in ('accepted', 'rejected') then actor_id else reviewed_by end,
        reviewed_at = case when new_status in ('accepted', 'rejected') then statement_timestamp() else reviewed_at end
    where id = admin_decide_review.item_id;
  elsif admin_decide_review.item_kind = 'removal_report' then
    update public.route_removal_reports
    set status = new_status::public.report_status
    where id = admin_decide_review.item_id;
  else
    update public.route_merge_suggestions
    set status = new_status::public.merge_status,
        reviewed_by = case when new_status in ('approved', 'rejected') then actor_id else reviewed_by end,
        reviewed_at = case when new_status in ('approved', 'rejected') then statement_timestamp() else reviewed_at end
    where id = admin_decide_review.item_id;
  end if;

  audit_id := private.append_admin_audit(
    actor_id, 'review.decision', admin_decide_review.item_kind,
    admin_decide_review.item_id, clean_reason, 'succeeded',
    jsonb_build_object('status', current_status),
    jsonb_build_object(
      'decision', admin_decide_review.decision,
      'status', new_status,
      'result', jsonb_build_object('status', new_status)
    ),
    extensions.gen_random_uuid(), admin_decide_review.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('status', new_status);
end;
$$;

revoke all on function public.admin_decide_review(text, uuid, text, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_decide_review(text, uuid, text, text, timestamptz, uuid)
  to authenticated;

comment on function public.admin_decide_review(text, uuid, text, text, timestamptz, uuid) is
  'Transactional staff review decision with role matrix, version guard, idempotent audit, and canonical target hide/restore.';
