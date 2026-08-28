-- Stage 7-D3: notification outbox population.
-- When beta, reset, or route-archive events happen, populate notification_outbox
-- for opted-in users who are affected and who are not the actor. Preferences are
-- honoured at write time; delivery (APNs/email) is a later stage.

-- Helper: enqueue an outbox row for each opted-in recipient in p_recipients,
-- excluding the actor and any user blocked by or blocking the actor.
create or replace function private.enqueue_notifications(
  p_category public.notification_category,
  p_source_record_id uuid,
  p_actor_id uuid,
  p_recipients uuid[],
  p_payload jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r uuid;
begin
  if p_recipients is null then
    return;
  end if;

  foreach r in array p_recipients loop
    -- Opted in?
    if not exists (
      select 1 from public.notification_preferences np
      where np.user_id = r and np.category = p_category and np.is_enabled
    ) then
      continue;
    end if;

    -- Skip the actor.
    if p_actor_id is not null and r = p_actor_id then
      continue;
    end if;

    -- Skip blocked relationships in either direction.
    if p_actor_id is not null and exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = p_actor_id and b.blocked_id = r)
         or (b.blocker_id = r and b.blocked_id = p_actor_id)
    ) then
      continue;
    end if;

    insert into public.notification_outbox
      (recipient_id, category, source_record_id, payload)
    values
      (r, p_category, p_source_record_id, p_payload)
    on conflict do nothing;
  end loop;
end;
$$;

-- Beta: notify users who project the route, and followers of the submitter.
create or replace function private.enqueue_beta_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := new.submitted_by;
  v_route uuid := new.route_id;
  v_projectors uuid[];
  v_followers uuid[];
begin
  if v_actor is null then
    return new;
  end if;

  select array_agg(user_id)
    into v_projectors
    from public.logbook_entries
    where route_id = v_route and status = 'projecting' and deleted_at is null;

  select array_agg(follower_id)
    into v_followers
    from public.user_follows
    where followed_id = v_actor;

  perform private.enqueue_notifications(
    'new_beta_for_project', new.id, v_actor, v_projectors,
    jsonb_build_object('route_id', v_route)
  );

  perform private.enqueue_notifications(
    'followed_contributor_beta', new.id, v_actor, v_followers,
    jsonb_build_object('route_id', v_route, 'submitted_by', v_actor)
  );

  return new;
end;
$$;

drop trigger if exists beta_links_notify on public.beta_links;
create trigger beta_links_notify
  after insert on public.beta_links
  for each row execute function private.enqueue_beta_notifications();

-- Gym reset: notify users who favourite the gym when a reset transitions into a
-- confirmed/estimated state.
create or replace function private.enqueue_reset_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_favourites uuid[];
begin
  if new.state in ('confirmed', 'estimated')
     and (old is null or old.state not in ('confirmed', 'estimated')) then
    select array_agg(user_id)
      into v_favourites
      from public.favourite_gyms
      where gym_id = new.gym_id;

    perform private.enqueue_notifications(
      'gym_reset', new.id, new.created_by, v_favourites,
      jsonb_build_object('gym_id', new.gym_id, 'wall_zone_id', new.wall_zone_id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists reset_events_notify on public.reset_events;
create trigger reset_events_notify
  after insert or update of state on public.reset_events
  for each row execute function private.enqueue_reset_notifications();

-- Project removal: notify users who project a route when it becomes archived.
create or replace function private.enqueue_project_removal_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_projectors uuid[];
begin
  if new.lifecycle = 'archived'
     and (old is null or old.lifecycle <> 'archived') then
    select array_agg(user_id)
      into v_projectors
      from public.logbook_entries
      where route_id = new.id and status = 'projecting' and deleted_at is null;

    perform private.enqueue_notifications(
      'project_removal', new.id, null, v_projectors,
      jsonb_build_object('route_id', new.id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists routes_project_removal_notify on public.routes;
create trigger routes_project_removal_notify
  after update of lifecycle on public.routes
  for each row execute function private.enqueue_project_removal_notifications();

revoke all on function private.enqueue_notifications(public.notification_category, uuid, uuid, uuid[], jsonb) from PUBLIC, anon, authenticated;
revoke all on function private.enqueue_beta_notifications() from PUBLIC, anon, authenticated;
revoke all on function private.enqueue_reset_notifications() from PUBLIC, anon, authenticated;
revoke all on function private.enqueue_project_removal_notifications() from PUBLIC, anon, authenticated;
