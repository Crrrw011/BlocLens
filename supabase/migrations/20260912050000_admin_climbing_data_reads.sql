-- Staff-only entity projections for climbing-data management.
-- No Logbook content, emails, or tokens are exposed; user ids appear only
-- as operational attribution already visible to staff elsewhere.

create or replace function public.admin_list_entities(
  entity_kind text,
  status_filter text,
  search_text text,
  gym_id uuid,
  page_after text,
  page_size integer
)
returns table (
  kind text,
  id uuid,
  status text,
  title text,
  subtitle text,
  moderation text,
  dependent_counts jsonb,
  updated_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
  want_status text := coalesce(nullif(btrim(admin_list_entities.status_filter), ''), 'all');
  needle text := nullif(btrim(coalesce(admin_list_entities.search_text, '')), '');
  limit_count integer := least(greatest(coalesce(admin_list_entities.page_size, 20), 1), 100);
  cursor_at timestamptz := null;
  cursor_id uuid := null;
begin
  if admin_list_entities.entity_kind is null
    or admin_list_entities.entity_kind not in (
      'gym', 'wall_zone', 'route', 'reset', 'route_photo', 'beta_link', 'route_comment'
    )
  then
    raise exception using errcode = '22023', message = 'invalid entity kind';
  end if;

  if admin_list_entities.page_after is not null then
    begin
      cursor_at := split_part(admin_list_entities.page_after, '|', 1)::timestamptz;
      cursor_id := split_part(admin_list_entities.page_after, '|', 2)::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'invalid entity page cursor';
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

  if admin_list_entities.entity_kind = 'gym' then
    if want_status not in ('all', 'active', 'deleted') then
      raise exception using errcode = '22023', message = 'invalid gym status filter';
    end if;
    return query
    select 'gym'::text, gyms.id,
      case when gyms.deleted_at is null then 'active'::text else 'deleted'::text end,
      gyms.name,
      coalesce(gyms.suburb, '') || ', ' || coalesce(gyms.state, ''),
      null::text,
      jsonb_build_object(
        'wall_zones', (select count(*) from public.wall_zones as wz where wz.gym_id = gyms.id),
        'routes', (select count(*) from public.routes as r where r.gym_id = gyms.id)
      ),
      gyms.updated_at, gyms.created_at
    from public.gyms as gyms
    where (want_status = 'all'
        or (want_status = 'active') = (gyms.deleted_at is null))
      and (needle is null
        or strpos(lower(gyms.name), lower(needle)) > 0
        or strpos(lower(coalesce(gyms.suburb, '')), lower(needle)) > 0
        or strpos(lower(coalesce(gyms.brand_name, '')), lower(needle)) > 0)
      and (cursor_at is null
        or gyms.updated_at < cursor_at
        or (gyms.updated_at = cursor_at and gyms.id < cursor_id))
    order by gyms.updated_at desc, gyms.id desc
    limit limit_count + 1;
    return;
  end if;

  if admin_list_entities.entity_kind = 'wall_zone' then
    if want_status not in ('all', 'active', 'archived') then
      raise exception using errcode = '22023', message = 'invalid wall zone status filter';
    end if;
    return query
    select 'wall_zone'::text, zones.id,
      case when zones.archived_at is null then 'active'::text else 'archived'::text end,
      zones.name, gyms.name, zones.availability::text,
      jsonb_build_object(
        'routes', (select count(*) from public.routes as r where r.wall_zone_id = zones.id)
      ),
      zones.updated_at, zones.created_at
    from public.wall_zones as zones
    join public.gyms as gyms on gyms.id = zones.gym_id
    where (want_status = 'all'
        or (want_status = 'active') = (zones.archived_at is null))
      and (admin_list_entities.gym_id is null or zones.gym_id = admin_list_entities.gym_id)
      and (needle is null or strpos(lower(zones.name), lower(needle)) > 0)
      and (cursor_at is null
        or zones.updated_at < cursor_at
        or (zones.updated_at = cursor_at and zones.id < cursor_id))
    order by zones.updated_at desc, zones.id desc
    limit limit_count + 1;
    return;
  end if;

  if admin_list_entities.entity_kind = 'route' then
    if want_status not in ('all', 'active', 'hidden', 'archived', 'deleted') then
      raise exception using errcode = '22023', message = 'invalid route status filter';
    end if;
    return query
    select 'route'::text, routes.id,
      case
        when routes.deleted_at is not null then 'deleted'
        when routes.lifecycle = 'archived'::public.route_lifecycle then 'archived'
        when routes.moderation_status = 'temporarily_hidden'::public.moderation_status then 'hidden'
        else 'active'
      end::text,
      coalesce(nullif(btrim(routes.colour), ''), 'Route ' || left(routes.id::text, 8)),
      gyms.name || ' · ' || zones.name,
      routes.moderation_status::text,
      jsonb_build_object(
        'photos', (select count(*) from public.route_photos as photos where photos.route_id = routes.id),
        'beta_links', (select count(*) from public.beta_links as links where links.route_id = routes.id),
        'corrections', (select count(*) from public.route_corrections as corrections where corrections.route_id = routes.id),
        'reports', (select count(*) from public.content_reports
          where target_type = 'route'::public.content_type and target_id = routes.id)
      ),
      routes.updated_at, routes.created_at
    from public.routes as routes
    join public.gyms as gyms on gyms.id = routes.gym_id
    join public.wall_zones as zones on zones.id = routes.wall_zone_id
    where (
        want_status = 'all'
        or (want_status = 'active' and routes.deleted_at is null
          and routes.lifecycle = 'active'::public.route_lifecycle
          and routes.moderation_status = 'visible'::public.moderation_status)
        or (want_status = 'hidden' and routes.deleted_at is null
          and routes.moderation_status = 'temporarily_hidden'::public.moderation_status)
        or (want_status = 'archived' and routes.lifecycle = 'archived'::public.route_lifecycle)
        or (want_status = 'deleted' and routes.deleted_at is not null)
      )
      and (admin_list_entities.gym_id is null or routes.gym_id = admin_list_entities.gym_id)
      and (needle is null
        or strpos(lower(routes.colour), lower(needle)) > 0
        or strpos(lower(gyms.name), lower(needle)) > 0)
      and (cursor_at is null
        or routes.updated_at < cursor_at
        or (routes.updated_at = cursor_at and routes.id < cursor_id))
    order by routes.updated_at desc, routes.id desc
    limit limit_count + 1;
    return;
  end if;

  if admin_list_entities.entity_kind = 'reset' then
    if want_status not in ('all', 'pending', 'confirmed', 'estimated') then
      raise exception using errcode = '22023', message = 'invalid reset status filter';
    end if;
    return query
    select 'reset'::text, resets.id, resets.state::text,
      gyms.name || ' · ' || coalesce(zones.name, 'whole gym'),
      resets.reset_date::date::text,
      null::text,
      jsonb_build_object(
        'confirmations', (select count(*) from public.reset_confirmations as confirmations
          where confirmations.reset_event_id = resets.id and confirmations.revoked_at is null)
      ),
      resets.updated_at, resets.created_at
    from public.reset_events as resets
    join public.gyms as gyms on gyms.id = resets.gym_id
    left join public.wall_zones as zones on zones.id = resets.wall_zone_id
    where resets.deleted_at is null
      and (want_status = 'all' or resets.state::text = want_status)
      and (admin_list_entities.gym_id is null or resets.gym_id = admin_list_entities.gym_id)
      and (needle is null or strpos(lower(gyms.name), lower(needle)) > 0)
      and (cursor_at is null
        or resets.updated_at < cursor_at
        or (resets.updated_at = cursor_at and resets.id < cursor_id))
    order by resets.updated_at desc, resets.id desc
    limit limit_count + 1;
    return;
  end if;

  if admin_list_entities.entity_kind = 'route_photo' then
    if want_status not in ('all', 'visible', 'hidden', 'deleted') then
      raise exception using errcode = '22023', message = 'invalid photo status filter';
    end if;
    return query
    select 'route_photo'::text, photos.id,
      case
        when photos.deleted_at is not null then 'deleted'
        when photos.moderation_status = 'temporarily_hidden'::public.moderation_status then 'hidden'
        else 'visible'
      end::text,
      photos.storage_path,
      coalesce(nullif(btrim(routes.colour), ''), 'Route') || ' · ' || gyms.name,
      photos.moderation_status::text,
      jsonb_build_object(
        'helpful_votes', (select count(*) from public.route_photo_helpful_votes as votes
          where votes.photo_id = photos.id)
      ),
      photos.updated_at, photos.created_at
    from public.route_photos as photos
    join public.routes as routes on routes.id = photos.route_id
    join public.gyms as gyms on gyms.id = routes.gym_id
    where (want_status = 'all'
        or (want_status = 'visible' and photos.deleted_at is null
          and photos.moderation_status = 'visible'::public.moderation_status)
        or (want_status = 'hidden' and photos.deleted_at is null
          and photos.moderation_status = 'temporarily_hidden'::public.moderation_status)
        or (want_status = 'deleted' and photos.deleted_at is not null))
      and (needle is null or strpos(lower(photos.storage_path), lower(needle)) > 0)
      and (cursor_at is null
        or photos.updated_at < cursor_at
        or (photos.updated_at = cursor_at and photos.id < cursor_id))
    order by photos.updated_at desc, photos.id desc
    limit limit_count + 1;
    return;
  end if;

  if admin_list_entities.entity_kind = 'beta_link' then
    if want_status not in ('all', 'visible', 'hidden', 'deleted') then
      raise exception using errcode = '22023', message = 'invalid beta link status filter';
    end if;
    return query
    select 'beta_link'::text, links.id,
      case
        when links.deleted_at is not null then 'deleted'
        when links.moderation_status = 'temporarily_hidden'::public.moderation_status then 'hidden'
        else 'visible'
      end::text,
      links.original_author_display_name,
      coalesce(nullif(btrim(routes.colour), ''), 'Route') || ' · ' || links.platform::text,
      links.moderation_status::text,
      jsonb_build_object(
        'comments', (select count(*) from public.beta_comments as comments where comments.beta_link_id = links.id),
        'helpful_votes', (select count(*) from public.beta_helpful_votes as votes where votes.beta_link_id = links.id)
      ),
      links.updated_at, links.created_at
    from public.beta_links as links
    join public.routes as routes on routes.id = links.route_id
    where (want_status = 'all'
        or (want_status = 'visible' and links.deleted_at is null
          and links.moderation_status = 'visible'::public.moderation_status)
        or (want_status = 'hidden' and links.deleted_at is null
          and links.moderation_status = 'temporarily_hidden'::public.moderation_status)
        or (want_status = 'deleted' and links.deleted_at is not null))
      and (needle is null
        or strpos(lower(links.original_author_display_name), lower(needle)) > 0
        or strpos(lower(links.public_url), lower(needle)) > 0)
      and (cursor_at is null
        or links.updated_at < cursor_at
        or (links.updated_at = cursor_at and links.id < cursor_id))
    order by links.updated_at desc, links.id desc
    limit limit_count + 1;
    return;
  end if;

  -- route_comment maps to public.beta_comments.
  if want_status not in ('all', 'visible', 'hidden', 'deleted') then
    raise exception using errcode = '22023', message = 'invalid comment status filter';
  end if;
  return query
  select 'route_comment'::text, comments.id,
    case
      when comments.deleted_at is not null then 'deleted'
      when comments.moderation_status = 'temporarily_hidden'::public.moderation_status then 'hidden'
      else 'visible'
    end::text,
    left(comments.body, 80),
    coalesce(nullif(btrim(routes.colour), ''), 'Route') || ' · ' || gyms.name,
    comments.moderation_status::text,
    jsonb_build_object('replies', 0),
    comments.updated_at, comments.created_at
  from public.beta_comments as comments
  join public.beta_links as links on links.id = comments.beta_link_id
  join public.routes as routes on routes.id = links.route_id
  join public.gyms as gyms on gyms.id = routes.gym_id
  where (want_status = 'all'
      or (want_status = 'visible' and comments.deleted_at is null
        and comments.moderation_status = 'visible'::public.moderation_status)
      or (want_status = 'hidden' and comments.deleted_at is null
        and comments.moderation_status = 'temporarily_hidden'::public.moderation_status)
      or (want_status = 'deleted' and comments.deleted_at is not null))
    and (needle is null or strpos(lower(comments.body), lower(needle)) > 0)
    and (cursor_at is null
      or comments.updated_at < cursor_at
      or (comments.updated_at = cursor_at and comments.id < cursor_id))
  order by comments.updated_at desc, comments.id desc
  limit limit_count + 1;
end;
$$;

create or replace function public.admin_entity_detail(
  entity_kind text,
  entity_id uuid
)
returns table (
  kind text,
  id uuid,
  status text,
  title text,
  subtitle text,
  details jsonb,
  related jsonb,
  moderation_history jsonb,
  updated_at timestamptz,
  created_at timestamptz
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
  if admin_entity_detail.entity_kind is null
    or admin_entity_detail.entity_kind not in (
      'gym', 'wall_zone', 'route', 'reset', 'route_photo', 'beta_link', 'route_comment'
    )
    or admin_entity_detail.entity_id is null
  then
    raise exception using errcode = '22023', message = 'invalid entity reference';
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

  if admin_entity_detail.entity_kind = 'gym' then
    return query
    select 'gym'::text, gyms.id,
      case when gyms.deleted_at is null then 'active'::text else 'deleted'::text end,
      gyms.name, coalesce(gyms.suburb, '') || ', ' || coalesce(gyms.state, ''),
      jsonb_build_object(
        'brand_name', gyms.brand_name, 'suburb', gyms.suburb, 'state', gyms.state,
        'postcode', gyms.postcode, 'is_claimed', gyms.is_claimed,
        'is_verified', gyms.is_verified, 'data_source', gyms.data_source::text,
        'website', gyms.website, 'deleted_at', gyms.deleted_at
      ),
      (select coalesce(jsonb_agg(zones.id order by zones.display_order), '[]'::jsonb)
       from public.wall_zones as zones where zones.gym_id = gyms.id),
      '[]'::jsonb, gyms.updated_at, gyms.created_at
    from public.gyms as gyms
    where gyms.id = admin_entity_detail.entity_id;
    return;
  end if;

  if admin_entity_detail.entity_kind = 'wall_zone' then
    return query
    select 'wall_zone'::text, zones.id,
      case when zones.archived_at is null then 'active'::text else 'archived'::text end,
      zones.name, gyms.name,
      jsonb_build_object(
        'gym_id', zones.gym_id, 'availability', zones.availability::text,
        'wall_kind', zones.wall_kind::text, 'display_order', zones.display_order,
        'last_reset_date', zones.last_reset_date, 'archived_at', zones.archived_at
      ),
      (select coalesce(jsonb_agg(routes.id order by routes.created_at), '[]'::jsonb)
       from public.routes as routes where routes.wall_zone_id = zones.id),
      '[]'::jsonb, zones.updated_at, zones.created_at
    from public.wall_zones as zones
    join public.gyms as gyms on gyms.id = zones.gym_id
    where zones.id = admin_entity_detail.entity_id;
    return;
  end if;

  if admin_entity_detail.entity_kind = 'route' then
    return query
    select 'route'::text, routes.id,
      case
        when routes.deleted_at is not null then 'deleted'
        when routes.lifecycle = 'archived'::public.route_lifecycle then 'archived'
        when routes.moderation_status = 'temporarily_hidden'::public.moderation_status then 'hidden'
        else 'active'
      end::text,
      coalesce(nullif(btrim(routes.colour), ''), 'Route ' || left(routes.id::text, 8)),
      gyms.name || ' · ' || zones.name,
      jsonb_build_object(
        'gym_id', routes.gym_id, 'wall_zone_id', routes.wall_zone_id,
        'colour', routes.colour, 'gym_grade', routes.gym_grade,
        'lifecycle', routes.lifecycle::text, 'moderation_status', routes.moderation_status::text,
        'terrain', routes.terrain::text, 'styles', routes.styles,
        'subjective_grade', routes.subjective_grade,
        'set_date', routes.set_date, 'is_official_source', routes.is_official_source,
        'canonical_route_id', routes.canonical_route_id,
        'created_by', routes.created_by, 'hidden_at', routes.hidden_at,
        'archived_at', routes.archived_at, 'deleted_at', routes.deleted_at
      ),
      jsonb_build_object(
        'photos', (select coalesce(jsonb_agg(photos.id), '[]'::jsonb)
          from public.route_photos as photos where photos.route_id = routes.id),
        'beta_links', (select coalesce(jsonb_agg(links.id), '[]'::jsonb)
          from public.beta_links as links where links.route_id = routes.id)
      ),
      (select coalesce(jsonb_agg(row_to_json(a) order by a.created_at desc), '[]'::jsonb)
       from (
         select actions.id, actions.action_type::text as action_type,
           actions.reason, actions.created_at
         from public.moderation_actions as actions
         where actions.target_type = 'route'::public.content_type
           and actions.target_id = routes.id
         order by actions.created_at desc
         limit 20
       ) a),
      routes.updated_at, routes.created_at
    from public.routes as routes
    join public.gyms as gyms on gyms.id = routes.gym_id
    join public.wall_zones as zones on zones.id = routes.wall_zone_id
    where routes.id = admin_entity_detail.entity_id;
    return;
  end if;

  if admin_entity_detail.entity_kind = 'reset' then
    return query
    select 'reset'::text, resets.id, resets.state::text,
      gyms.name || ' · ' || coalesce(zones.name, 'whole gym'),
      resets.reset_date::date::text,
      jsonb_build_object(
        'gym_id', resets.gym_id, 'wall_zone_id', resets.wall_zone_id,
        'reset_date', resets.reset_date, 'source', resets.source::text,
        'confirmation_count', resets.confirmation_count,
        'is_estimated', resets.is_estimated, 'is_official', resets.is_official,
        'created_by', resets.created_by, 'deleted_at', resets.deleted_at
      ),
      (select coalesce(jsonb_agg(confirmations.user_id), '[]'::jsonb)
       from public.reset_confirmations as confirmations
       where confirmations.reset_event_id = resets.id
         and confirmations.revoked_at is null),
      '[]'::jsonb, resets.updated_at, resets.created_at
    from public.reset_events as resets
    join public.gyms as gyms on gyms.id = resets.gym_id
    left join public.wall_zones as zones on zones.id = resets.wall_zone_id
    where resets.id = admin_entity_detail.entity_id;
    return;
  end if;

  if admin_entity_detail.entity_kind = 'route_photo' then
    return query
    select 'route_photo'::text, photos.id,
      case
        when photos.deleted_at is not null then 'deleted'
        when photos.moderation_status = 'temporarily_hidden'::public.moderation_status then 'hidden'
        else 'visible'
      end::text,
      photos.storage_path,
      coalesce(nullif(btrim(routes.colour), ''), 'Route') || ' · ' || gyms.name,
      jsonb_build_object(
        'route_id', photos.route_id, 'storage_path', photos.storage_path,
        'uploaded_by', photos.uploaded_by, 'is_official_source', photos.is_official_source,
        'helpful_count', photos.helpful_count,
        'moderation_status', photos.moderation_status::text,
        'width', photos.width, 'height', photos.height,
        'hidden_at', photos.hidden_at, 'deleted_at', photos.deleted_at
      ),
      jsonb_build_object('route_id', photos.route_id),
      (select coalesce(jsonb_agg(row_to_json(a) order by a.created_at desc), '[]'::jsonb)
       from (
         select actions.id, actions.action_type::text as action_type,
           actions.reason, actions.created_at
         from public.moderation_actions as actions
         where actions.target_type = 'route_photo'::public.content_type
           and actions.target_id = photos.id
         order by actions.created_at desc
         limit 20
       ) a),
      photos.updated_at, photos.created_at
    from public.route_photos as photos
    join public.routes as routes on routes.id = photos.route_id
    join public.gyms as gyms on gyms.id = routes.gym_id
    where photos.id = admin_entity_detail.entity_id;
    return;
  end if;

  if admin_entity_detail.entity_kind = 'beta_link' then
    return query
    select 'beta_link'::text, links.id,
      case
        when links.deleted_at is not null then 'deleted'
        when links.moderation_status = 'temporarily_hidden'::public.moderation_status then 'hidden'
        else 'visible'
      end::text,
      links.original_author_display_name,
      coalesce(nullif(btrim(routes.colour), ''), 'Route') || ' · ' || links.platform::text,
      jsonb_build_object(
        'route_id', links.route_id, 'public_url', links.public_url,
        'platform', links.platform::text,
        'original_author_display_name', links.original_author_display_name,
        'helpful_count', links.helpful_count, 'link_status', links.link_status::text,
        'moderation_status', links.moderation_status::text,
        'is_official_source', links.is_official_source,
        'submitted_by', links.submitted_by,
        'hidden_at', links.hidden_at, 'deleted_at', links.deleted_at
      ),
      (select coalesce(jsonb_agg(comments.id), '[]'::jsonb)
       from public.beta_comments as comments where comments.beta_link_id = links.id),
      (select coalesce(jsonb_agg(row_to_json(a) order by a.created_at desc), '[]'::jsonb)
       from (
         select actions.id, actions.action_type::text as action_type,
           actions.reason, actions.created_at
         from public.moderation_actions as actions
         where actions.target_type = 'beta_link'::public.content_type
           and actions.target_id = links.id
         order by actions.created_at desc
         limit 20
       ) a),
      links.updated_at, links.created_at
    from public.beta_links as links
    join public.routes as routes on routes.id = links.route_id
    where links.id = admin_entity_detail.entity_id;
    return;
  end if;

  -- route_comment maps to public.beta_comments; bodies are public community text.
  return query
  select 'route_comment'::text, comments.id,
    case
      when comments.deleted_at is not null then 'deleted'
      when comments.moderation_status = 'temporarily_hidden'::public.moderation_status then 'hidden'
      else 'visible'
    end::text,
    left(comments.body, 80),
    coalesce(nullif(btrim(routes.colour), ''), 'Route') || ' · ' || gyms.name,
    jsonb_build_object(
      'beta_link_id', comments.beta_link_id, 'body', comments.body,
      'author_id', comments.author_id,
      'moderation_status', comments.moderation_status::text,
      'hidden_at', comments.hidden_at, 'deleted_at', comments.deleted_at
    ),
    jsonb_build_object('beta_link_id', comments.beta_link_id),
    (select coalesce(jsonb_agg(row_to_json(a) order by a.created_at desc), '[]'::jsonb)
     from (
       select actions.id, actions.action_type::text as action_type,
         actions.reason, actions.created_at
       from public.moderation_actions as actions
       where actions.target_type = 'beta_comment'::public.content_type
         and actions.target_id = comments.id
       order by actions.created_at desc
       limit 20
     ) a),
    comments.updated_at, comments.created_at
  from public.beta_comments as comments
  join public.beta_links as links on links.id = comments.beta_link_id
  join public.routes as routes on routes.id = links.route_id
  join public.gyms as gyms on gyms.id = routes.gym_id
  where comments.id = admin_entity_detail.entity_id;
end;
$$;

revoke all on function public.admin_list_entities(text, text, text, uuid, text, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_list_entities(text, text, text, uuid, text, integer)
  to authenticated;

revoke all on function public.admin_entity_detail(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_entity_detail(text, uuid)
  to authenticated;

comment on function public.admin_list_entities(text, text, text, uuid, text, integer) is
  'Staff-only climbing-data entity lists with status filters and stable cursor pagination.';
comment on function public.admin_entity_detail(text, uuid) is
  'Staff-only single entity with whitelisted details, relations, and moderation history. Never reads Logbook.';
