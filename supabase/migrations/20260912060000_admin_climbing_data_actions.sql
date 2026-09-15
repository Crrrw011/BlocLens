-- Version-checked climbing-data edits and route lifecycle actions.
-- Patch keys are whitelisted per entity; unknown keys raise instead of
-- being silently ignored. Grade aggregates and Helpful counts are never writable.

create or replace function public.admin_update_entity(
  entity_kind text,
  entity_id uuid,
  patch jsonb,
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
  clean_reason text := btrim(coalesce(admin_update_entity.reason, ''));
  current_updated_at timestamptz := null;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
  patch_keys text[] := '{}';
  key text;
  applied jsonb := '{}'::jsonb;
begin
  if admin_update_entity.entity_kind is null
    or admin_update_entity.entity_kind not in (
      'gym', 'wall_zone', 'route', 'reset', 'route_photo', 'beta_link', 'route_comment'
    )
    or admin_update_entity.entity_id is null
    or admin_update_entity.patch is null
    or jsonb_typeof(admin_update_entity.patch) <> 'object'
    or admin_update_entity.patch = '{}'::jsonb
    or char_length(clean_reason) not between 1 and 2000
    or admin_update_entity.expected_updated_at is null
    or admin_update_entity.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid entity patch';
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
      actor_id, 'climbing.entity_updated', admin_update_entity.entity_kind,
      admin_update_entity.entity_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_update_entity.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  -- Lock the row and read its version.
  case admin_update_entity.entity_kind
    when 'gym' then
      select gyms.updated_at into current_updated_at
      from public.gyms as gyms where gyms.id = admin_update_entity.entity_id for update;
    when 'wall_zone' then
      select zones.updated_at into current_updated_at
      from public.wall_zones as zones where zones.id = admin_update_entity.entity_id for update;
    when 'route' then
      select routes.updated_at into current_updated_at
      from public.routes as routes where routes.id = admin_update_entity.entity_id for update;
    when 'reset' then
      select resets.updated_at into current_updated_at
      from public.reset_events as resets where resets.id = admin_update_entity.entity_id for update;
    when 'route_photo' then
      select photos.updated_at into current_updated_at
      from public.route_photos as photos where photos.id = admin_update_entity.entity_id for update;
    when 'beta_link' then
      select links.updated_at into current_updated_at
      from public.beta_links as links where links.id = admin_update_entity.entity_id for update;
    else
      select comments.updated_at into current_updated_at
      from public.beta_comments as comments where comments.id = admin_update_entity.entity_id for update;
  end case;

  if current_updated_at is null then
    audit_id := private.append_admin_audit(
      actor_id, 'climbing.entity_updated', admin_update_entity.entity_kind,
      admin_update_entity.entity_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_update_entity.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_update_entity.idempotency_key
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

  select array_agg(k) into patch_keys
  from jsonb_object_keys(admin_update_entity.patch) as k;

  -- Whitelist and shape validation per entity. Anything else raises.
  if admin_update_entity.entity_kind = 'gym' then
    foreach key in array patch_keys loop
      if key not in ('name', 'description', 'suburb', 'state', 'postcode', 'website') then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
    end loop;
    if patch ? 'name' and char_length(btrim(patch ->> 'name')) not between 1 and 120 then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'description'
      and (jsonb_typeof(patch -> 'description') not in ('string', 'null')
        or char_length(coalesce(patch ->> 'description', '')) > 2000) then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'postcode'
      and (patch ->> 'postcode') is not null
      and (patch ->> 'postcode') <> ''
      and (patch ->> 'postcode') !~ '^[0-9]{4}$' then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'website'
      and (patch ->> 'website') is not null
      and (patch ->> 'website') <> ''
      and (patch ->> 'website') !~* '^https://' then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
  elsif admin_update_entity.entity_kind = 'wall_zone' then
    foreach key in array patch_keys loop
      if key not in ('name', 'location_description', 'display_order') then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
    end loop;
    if patch ? 'name' and char_length(btrim(patch ->> 'name')) not between 1 and 100 then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'display_order'
      and (jsonb_typeof(patch -> 'display_order') <> 'number'
        or (patch ->> 'display_order')::numeric <> trunc((patch ->> 'display_order')::numeric)
        or (patch ->> 'display_order')::integer < 0) then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
  elsif admin_update_entity.entity_kind = 'route' then
    foreach key in array patch_keys loop
      if key not in ('colour', 'gym_grade', 'terrain', 'styles', 'subjective_grade', 'set_date') then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
    end loop;
    if patch ? 'colour' and char_length(btrim(coalesce(patch ->> 'colour', ''))) < 1 then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'gym_grade'
      and (jsonb_typeof(patch -> 'gym_grade') <> 'number'
        or (patch ->> 'gym_grade')::numeric <> trunc((patch ->> 'gym_grade')::numeric)
        or (patch ->> 'gym_grade')::integer not between -1 and 17) then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'terrain'
      and (patch ->> 'terrain') not in ('slab', 'vertical', 'overhang', 'roof', 'cave', 'mixed') then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'styles' then
      if jsonb_typeof(patch -> 'styles') <> 'array' then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
      if exists (
        select 1 from jsonb_array_elements_text(patch -> 'styles') as style
        where style not in ('static', 'dynamic', 'technical', 'powerful', 'coordination')
      ) then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
    end if;
    if patch ? 'subjective_grade'
      and (patch ->> 'subjective_grade') is not null
      and ((patch -> 'subjective_grade') is not null and jsonb_typeof(patch -> 'subjective_grade') <> 'number'
        or (patch ->> 'subjective_grade')::numeric <> trunc((patch ->> 'subjective_grade')::numeric)
        or (patch ->> 'subjective_grade')::integer not between -1 and 17) then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'set_date'
      and (patch ->> 'set_date') is not null
      and (patch ->> 'set_date') <> '' then
      begin
        perform (patch ->> 'set_date')::timestamptz;
      exception when others then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end;
    end if;
  elsif admin_update_entity.entity_kind = 'reset' then
    foreach key in array patch_keys loop
      if key not in ('reset_date') then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
    end loop;
    begin
      perform (patch ->> 'reset_date')::timestamptz;
    exception when others then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end;
  elsif admin_update_entity.entity_kind = 'route_photo' then
    foreach key in array patch_keys loop
      if key not in ('is_official_source') then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
    end loop;
    if jsonb_typeof(patch -> 'is_official_source') <> 'boolean' then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
  elsif admin_update_entity.entity_kind = 'beta_link' then
    foreach key in array patch_keys loop
      if key not in ('link_status', 'is_official_source') then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
    end loop;
    if patch ? 'link_status'
      and (patch ->> 'link_status') not in ('healthy', 'broken', 'removed_by_source') then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
    if patch ? 'is_official_source'
      and jsonb_typeof(patch -> 'is_official_source') <> 'boolean' then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
  else
    foreach key in array patch_keys loop
      if key not in ('body') then
        raise exception using errcode = '22023', message = 'invalid entity patch';
      end if;
    end loop;
    if char_length(btrim(coalesce(patch ->> 'body', ''))) not between 1 and 200 then
      raise exception using errcode = '22023', message = 'invalid entity patch';
    end if;
  end if;

  if current_updated_at is distinct from admin_update_entity.expected_updated_at then
    audit_id := private.append_admin_audit(
      actor_id, 'climbing.entity_updated', admin_update_entity.entity_kind,
      admin_update_entity.entity_id, clean_reason, 'failed',
      jsonb_build_object('updated_at', current_updated_at),
      jsonb_build_object('error_code', 'conflict'),
      extensions.gen_random_uuid(), admin_update_entity.idempotency_key
    );
    return query select false, 'conflict'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  -- Apply the validated patch. Column CHECKs remain the final guard.
  case admin_update_entity.entity_kind
    when 'gym' then
      update public.gyms as gyms set
        name = case when patch ? 'name' then btrim(patch ->> 'name') else gyms.name end,
        description = case when patch ? 'description'
          then nullif(patch ->> 'description', '') else gyms.description end,
        suburb = case when patch ? 'suburb' then patch ->> 'suburb' else gyms.suburb end,
        state = case when patch ? 'state' then patch ->> 'state' else gyms.state end,
        postcode = case when patch ? 'postcode'
          then nullif(patch ->> 'postcode', '') else gyms.postcode end,
        website = case when patch ? 'website'
          then nullif(patch ->> 'website', '') else gyms.website end
      where gyms.id = admin_update_entity.entity_id;
    when 'wall_zone' then
      update public.wall_zones as zones set
        name = case when patch ? 'name' then btrim(patch ->> 'name') else zones.name end,
        location_description = case when patch ? 'location_description'
          then nullif(patch ->> 'location_description', '') else zones.location_description end,
        display_order = case when patch ? 'display_order'
          then (patch ->> 'display_order')::integer else zones.display_order end
      where zones.id = admin_update_entity.entity_id;
    when 'route' then
      update public.routes as routes set
        colour = case when patch ? 'colour'
          then btrim(patch ->> 'colour') else routes.colour end,
        gym_grade = case when patch ? 'gym_grade'
          then (patch ->> 'gym_grade')::smallint else routes.gym_grade end,
        terrain = case when patch ? 'terrain'
          then (patch ->> 'terrain')::public.route_terrain else routes.terrain end,
        styles = case when patch ? 'styles'
          then (select coalesce(array_agg(style::public.route_style), '{}')
                from jsonb_array_elements_text(patch -> 'styles') as style)
          else routes.styles end,
        subjective_grade = case when patch ? 'subjective_grade'
          then case when (patch ->> 'subjective_grade') is null then null
            else (patch ->> 'subjective_grade')::smallint end
          else routes.subjective_grade end,
        set_date = case when patch ? 'set_date'
          then case when (patch ->> 'set_date') is null or (patch ->> 'set_date') = '' then null
            else (patch ->> 'set_date')::timestamptz end
          else routes.set_date end
      where routes.id = admin_update_entity.entity_id;
    when 'reset' then
      update public.reset_events as resets set
        reset_date = (patch ->> 'reset_date')::timestamptz
      where resets.id = admin_update_entity.entity_id;
    when 'route_photo' then
      update public.route_photos as photos set
        is_official_source = (patch ->> 'is_official_source')::boolean
      where photos.id = admin_update_entity.entity_id;
    when 'beta_link' then
      update public.beta_links as links set
        link_status = case when patch ? 'link_status'
          then (patch ->> 'link_status')::public.beta_link_status else links.link_status end,
        is_official_source = case when patch ? 'is_official_source'
          then (patch ->> 'is_official_source')::boolean else links.is_official_source end
      where links.id = admin_update_entity.entity_id;
    else
      update public.beta_comments as comments set
        body = btrim(patch ->> 'body')
      where comments.id = admin_update_entity.entity_id;
  end case;

  applied := (select coalesce(jsonb_object_agg(k, patch -> k), '{}'::jsonb)
              from unnest(patch_keys) as k);

  audit_id := private.append_admin_audit(
    actor_id, 'climbing.entity_updated', admin_update_entity.entity_kind,
    admin_update_entity.entity_id, clean_reason, 'succeeded',
    jsonb_build_object('updated_at', current_updated_at),
    jsonb_build_object('patch', applied,
      'result', jsonb_build_object('updated', true)),
    extensions.gen_random_uuid(), admin_update_entity.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('updated', true);
end;
$$;

create or replace function public.admin_change_lifecycle(
  route_id uuid,
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
  clean_reason text := btrim(coalesce(admin_change_lifecycle.reason, ''));
  current_lifecycle public.route_lifecycle := null;
  current_moderation public.moderation_status := null;
  current_updated_at timestamptz := null;
  is_deleted boolean := false;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
  new_lifecycle public.route_lifecycle := null;
  new_moderation public.moderation_status := null;
begin
  if admin_change_lifecycle.route_id is null
    or admin_change_lifecycle.action is null
    or admin_change_lifecycle.action not in ('archive', 'unarchive', 'hide', 'unhide')
    or char_length(clean_reason) not between 1 and 2000
    or admin_change_lifecycle.expected_updated_at is null
    or admin_change_lifecycle.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid lifecycle action';
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
      actor_id, 'climbing.lifecycle', 'route',
      admin_change_lifecycle.route_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('action', admin_change_lifecycle.action, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if admin_change_lifecycle.action in ('archive', 'unarchive')
    and actor_role <> 'admin'::public.app_role
  then
    audit_id := private.append_admin_audit(
      actor_id, 'climbing.lifecycle', 'route',
      admin_change_lifecycle.route_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('action', admin_change_lifecycle.action, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select routes.lifecycle, routes.moderation_status,
    routes.updated_at, routes.deleted_at is not null
  into current_lifecycle, current_moderation, current_updated_at, is_deleted
  from public.routes as routes
  where routes.id = admin_change_lifecycle.route_id
  for update;

  if current_lifecycle is null then
    audit_id := private.append_admin_audit(
      actor_id, 'climbing.lifecycle', 'route',
      admin_change_lifecycle.route_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('action', admin_change_lifecycle.action, 'error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_change_lifecycle.idempotency_key
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

  if admin_change_lifecycle.action = 'archive' then
    if is_deleted or current_lifecycle <> 'active'::public.route_lifecycle then
      audit_id := private.append_admin_audit(
        actor_id, 'climbing.lifecycle', 'route',
        admin_change_lifecycle.route_id, clean_reason, 'failed',
        jsonb_build_object('lifecycle', current_lifecycle),
        jsonb_build_object('action', 'archive', 'error_code', 'invalid_transition'),
        extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
      );
      return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
      return;
    end if;
    new_lifecycle := 'archived'::public.route_lifecycle;
  elsif admin_change_lifecycle.action = 'unarchive' then
    if current_lifecycle <> 'archived'::public.route_lifecycle then
      audit_id := private.append_admin_audit(
        actor_id, 'climbing.lifecycle', 'route',
        admin_change_lifecycle.route_id, clean_reason, 'failed',
        jsonb_build_object('lifecycle', current_lifecycle),
        jsonb_build_object('action', 'unarchive', 'error_code', 'invalid_transition'),
        extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
      );
      return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
      return;
    end if;
    new_lifecycle := 'active'::public.route_lifecycle;
  elsif admin_change_lifecycle.action = 'hide' then
    if is_deleted or current_moderation <> 'visible'::public.moderation_status then
      audit_id := private.append_admin_audit(
        actor_id, 'climbing.lifecycle', 'route',
        admin_change_lifecycle.route_id, clean_reason, 'failed',
        jsonb_build_object('moderation_status', current_moderation),
        jsonb_build_object('action', 'hide', 'error_code', 'invalid_transition'),
        extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
      );
      return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
      return;
    end if;
    new_moderation := 'temporarily_hidden'::public.moderation_status;
    -- Archived state survives a hide: only active lifecycles flip.
    if current_lifecycle = 'active'::public.route_lifecycle then
      new_lifecycle := 'temporarily_hidden'::public.route_lifecycle;
    else
      new_lifecycle := current_lifecycle;
    end if;
  else
    if current_moderation <> 'temporarily_hidden'::public.moderation_status then
      audit_id := private.append_admin_audit(
        actor_id, 'climbing.lifecycle', 'route',
        admin_change_lifecycle.route_id, clean_reason, 'failed',
        jsonb_build_object('moderation_status', current_moderation),
        jsonb_build_object('action', 'unhide', 'error_code', 'invalid_transition'),
        extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
      );
      return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
      return;
    end if;
    new_moderation := 'visible'::public.moderation_status;
    if current_lifecycle = 'temporarily_hidden'::public.route_lifecycle then
      new_lifecycle := 'active'::public.route_lifecycle;
    else
      new_lifecycle := current_lifecycle;
    end if;
  end if;

  if current_updated_at is distinct from admin_change_lifecycle.expected_updated_at then
    audit_id := private.append_admin_audit(
      actor_id, 'climbing.lifecycle', 'route',
      admin_change_lifecycle.route_id, clean_reason, 'failed',
      jsonb_build_object('lifecycle', current_lifecycle),
      jsonb_build_object('action', admin_change_lifecycle.action, 'error_code', 'conflict'),
      extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
    );
    return query select false, 'conflict'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if admin_change_lifecycle.action = 'archive' then
    update public.routes
    set lifecycle = 'archived'::public.route_lifecycle,
        archived_at = statement_timestamp()
    where id = admin_change_lifecycle.route_id;
  elsif admin_change_lifecycle.action = 'unarchive' then
    update public.routes
    set lifecycle = 'active'::public.route_lifecycle,
        archived_at = null
    where id = admin_change_lifecycle.route_id;
  elsif admin_change_lifecycle.action = 'hide' then
    update public.routes
    set moderation_status = 'temporarily_hidden'::public.moderation_status,
        lifecycle = new_lifecycle,
        hidden_at = coalesce(hidden_at, statement_timestamp())
    where id = admin_change_lifecycle.route_id;
    insert into public.moderation_actions (
      action_type, target_type, target_id, performed_by, reason
    ) values (
      'hide'::public.moderation_action_type, 'route'::public.content_type,
      admin_change_lifecycle.route_id, actor_id, left(clean_reason, 1000)
    );
  else
    update public.routes
    set moderation_status = 'visible'::public.moderation_status,
        lifecycle = new_lifecycle,
        hidden_at = null
    where id = admin_change_lifecycle.route_id;
    insert into public.moderation_actions (
      action_type, target_type, target_id, performed_by, reason
    ) values (
      'restore'::public.moderation_action_type, 'route'::public.content_type,
      admin_change_lifecycle.route_id, actor_id, left(clean_reason, 1000)
    );
  end if;

  audit_id := private.append_admin_audit(
    actor_id, 'climbing.lifecycle', 'route',
    admin_change_lifecycle.route_id, clean_reason, 'succeeded',
    jsonb_build_object('lifecycle', current_lifecycle, 'moderation_status', current_moderation),
    jsonb_build_object(
      'action', admin_change_lifecycle.action,
      'lifecycle', new_lifecycle, 'moderation_status', new_moderation,
      'result', jsonb_build_object('lifecycle', new_lifecycle)
    ),
    extensions.gen_random_uuid(), admin_change_lifecycle.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('lifecycle', new_lifecycle);
end;
$$;

revoke all on function public.admin_update_entity(text, uuid, jsonb, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_update_entity(text, uuid, jsonb, text, timestamptz, uuid)
  to authenticated;

revoke all on function public.admin_change_lifecycle(uuid, text, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_change_lifecycle(uuid, text, text, timestamptz, uuid)
  to authenticated;

comment on function public.admin_update_entity(text, uuid, jsonb, text, timestamptz, uuid) is
  'Whitelisted climbing-data edits with version guard and idempotent audit. Unknown patch keys raise.';
comment on function public.admin_change_lifecycle(uuid, text, text, timestamptz, uuid) is
  'Route archive/restore (Administrator-only) and hide/restore with version guard and idempotent audit.';
