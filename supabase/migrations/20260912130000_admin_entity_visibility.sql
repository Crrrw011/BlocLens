-- Visibility transitions for non-route entities (archive/restore/hide/unhide).
-- Routes keep using admin_change_lifecycle. Gyms and resets expose no
-- archive affordance (no equivalent hidden state exists for them).
-- Wall zones archive via availability + archived_at; photos, beta links and
-- comments hide via moderation_status + hidden_at. No tables are altered.

create or replace function public.admin_set_visibility(
  entity_kind text,
  entity_id uuid,
  action text,
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
  clean_reason text := btrim(coalesce(admin_set_visibility.reason, ''));
  current_updated_at timestamptz := null;
  current_state text := null;
  new_state text := null;
  audit_key text := null;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
  target_content public.content_type := null;
begin
  if admin_set_visibility.entity_kind is null
    or admin_set_visibility.entity_kind not in (
      'wall_zone', 'route_photo', 'beta_link', 'route_comment'
    )
    or admin_set_visibility.entity_id is null
    or admin_set_visibility.action is null
    or admin_set_visibility.action not in ('archive', 'unarchive', 'hide', 'unhide')
    or char_length(clean_reason) not between 1 and 2000
    or admin_set_visibility.expected_updated_at is null
    or admin_set_visibility.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid visibility action';
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
      actor_id, 'entity.visibility', admin_set_visibility.entity_kind,
      admin_set_visibility.entity_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('action', admin_set_visibility.action, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_set_visibility.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if admin_set_visibility.action in ('archive', 'unarchive')
    and actor_role <> 'admin'::public.app_role
  then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.visibility', admin_set_visibility.entity_kind,
      admin_set_visibility.entity_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('action', admin_set_visibility.action, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_set_visibility.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if admin_set_visibility.entity_kind = 'wall_zone'
    and admin_set_visibility.action in ('hide', 'unhide')
  then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.visibility', admin_set_visibility.entity_kind,
      admin_set_visibility.entity_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('action', admin_set_visibility.action, 'error_code', 'invalid_transition'),
      extensions.gen_random_uuid(), admin_set_visibility.idempotency_key
    );
    return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  -- Lock the row and read its versioned state.
  if admin_set_visibility.entity_kind = 'wall_zone' then
    select zones.updated_at,
      case when zones.archived_at is null then 'active' else 'archived' end
    into current_updated_at, current_state
    from public.wall_zones as zones
    where zones.id = admin_set_visibility.entity_id
    for update;
  elsif admin_set_visibility.entity_kind = 'route_photo' then
    select photos.updated_at, photos.moderation_status::text
    into current_updated_at, current_state
    from public.route_photos as photos
    where photos.id = admin_set_visibility.entity_id
    for update;
    target_content := 'route_photo'::public.content_type;
  elsif admin_set_visibility.entity_kind = 'beta_link' then
    select links.updated_at, links.moderation_status::text
    into current_updated_at, current_state
    from public.beta_links as links
    where links.id = admin_set_visibility.entity_id
    for update;
    target_content := 'beta_link'::public.content_type;
  else
    select comments.updated_at, comments.moderation_status::text
    into current_updated_at, current_state
    from public.beta_comments as comments
    where comments.id = admin_set_visibility.entity_id
    for update;
    target_content := 'beta_comment'::public.content_type;
  end if;

  if current_updated_at is null then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.visibility', admin_set_visibility.entity_kind,
      admin_set_visibility.entity_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('action', admin_set_visibility.action, 'error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_set_visibility.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_set_visibility.idempotency_key
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

  -- Resolve the transition; anything else is invalid.
  if admin_set_visibility.entity_kind = 'wall_zone' then
    if admin_set_visibility.action = 'archive' and current_state = 'active' then
      new_state := 'archived';
      audit_key := 'entity.archived';
    elsif admin_set_visibility.action = 'unarchive' and current_state = 'archived' then
      new_state := 'active';
      audit_key := 'entity.restored';
    end if;
  else
    if admin_set_visibility.action in ('archive', 'hide') and current_state = 'visible' then
      new_state := 'temporarily_hidden';
      audit_key := case when admin_set_visibility.action = 'archive'
        then 'entity.archived' else 'entity.hidden' end;
    elsif admin_set_visibility.action in ('unarchive', 'unhide')
      and current_state = 'temporarily_hidden' then
      new_state := 'visible';
      audit_key := 'entity.restored';
    end if;
  end if;

  if new_state is null then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.visibility', admin_set_visibility.entity_kind,
      admin_set_visibility.entity_id, clean_reason, 'failed',
      jsonb_build_object('state', current_state),
      jsonb_build_object('action', admin_set_visibility.action, 'error_code', 'invalid_transition'),
      extensions.gen_random_uuid(), admin_set_visibility.idempotency_key
    );
    return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if current_updated_at is distinct from admin_set_visibility.expected_updated_at then
    audit_id := private.append_admin_audit(
      actor_id, 'entity.visibility', admin_set_visibility.entity_kind,
      admin_set_visibility.entity_id, clean_reason, 'failed',
      jsonb_build_object('state', current_state),
      jsonb_build_object('action', admin_set_visibility.action, 'error_code', 'conflict'),
      extensions.gen_random_uuid(), admin_set_visibility.idempotency_key
    );
    return query select false, 'conflict'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if admin_set_visibility.entity_kind = 'wall_zone' then
    update public.wall_zones
    set availability = case when new_state = 'archived'
        then 'archived'::public.wall_zone_availability
        else 'active'::public.wall_zone_availability end,
      archived_at = case when new_state = 'archived'
        then statement_timestamp() else null end
    where id = admin_set_visibility.entity_id;
  elsif admin_set_visibility.entity_kind = 'route_photo' then
    update public.route_photos
    set moderation_status = new_state::public.moderation_status,
      hidden_at = case when new_state = 'temporarily_hidden'
        then coalesce(hidden_at, statement_timestamp()) else null end
    where id = admin_set_visibility.entity_id;
  elsif admin_set_visibility.entity_kind = 'beta_link' then
    update public.beta_links
    set moderation_status = new_state::public.moderation_status,
      hidden_at = case when new_state = 'temporarily_hidden'
        then coalesce(hidden_at, statement_timestamp()) else null end
    where id = admin_set_visibility.entity_id;
  else
    update public.beta_comments
    set moderation_status = new_state::public.moderation_status,
      hidden_at = case when new_state = 'temporarily_hidden'
        then coalesce(hidden_at, statement_timestamp()) else null end
    where id = admin_set_visibility.entity_id;
  end if;

  -- Media kinds keep a moderation history row; wall zones have no content type.
  if target_content is not null then
    insert into public.moderation_actions (
      action_type, target_type, target_id, performed_by, reason
    ) values (
      case when new_state = 'visible' then 'restore'::public.moderation_action_type
        else 'hide'::public.moderation_action_type end,
      target_content, admin_set_visibility.entity_id, actor_id, left(clean_reason, 1000)
    );
  end if;

  audit_id := private.append_admin_audit(
    actor_id, audit_key, admin_set_visibility.entity_kind,
    admin_set_visibility.entity_id, clean_reason, 'succeeded',
    jsonb_build_object('state', current_state),
    jsonb_build_object(
      'action', admin_set_visibility.action,
      'state', new_state,
      'result', jsonb_build_object('state', new_state)),
    extensions.gen_random_uuid(), admin_set_visibility.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('state', new_state);
end;
$$;

revoke all on function public.admin_set_visibility(text, uuid, text, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_set_visibility(text, uuid, text, text, timestamptz, uuid)
  to authenticated;

comment on function public.admin_set_visibility(text, uuid, text, text, timestamptz, uuid) is
  'Archive/restore (Administrator-only) and hide/unhide for wall zones, photos, beta links and comments. Version-guarded, idempotent, audited.';
