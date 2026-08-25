-- Stage 6D-2A: secure beta access before client integration.
-- Blocks anonymous access to external beta URLs and login-gated metadata while
-- preserving public beta counts, and adds the pg_trgm search support that the
-- data architecture document references.

-- 1. Remove anonymous access to beta URLs and metadata. The SwiftUI Reveal gate
--    is not a security boundary; this revoke is the enforcement point.
revoke select on public.beta_links from anon;
revoke select on public.beta_ranking_inputs from anon;

-- 2. Count-only helper so guests can still learn whether a route has beta and
--    how many, without reading any URL, author, tag or health metadata. The
--    empty search_path follows the project convention for SECURITY DEFINER
--    functions; it returns an integer only.
create or replace function public.visible_beta_count_for_route(requested_route_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.beta_links beta
  where beta.route_id = requested_route_id
    and beta.deleted_at is null
    and beta.moderation_status = 'visible';
$$;

revoke all on function public.visible_beta_count_for_route(uuid) from public;
grant execute on function public.visible_beta_count_for_route(uuid) to anon, authenticated;

-- 3. Recreate the public summary views so their beta counts no longer require
--    direct beta_links read access for anonymous users. Grants on the views are
--    preserved by `create or replace`.
create or replace view public.route_summaries
with (security_invoker = true)
as
select
  route.id, route.gym_id, route.wall_zone_id, route.colour, route.label,
  route.gym_grade, route.lifecycle, route.set_date, route.estimated_archive_date,
  route.is_archive_date_estimated, route.archived_at,
  public.visible_beta_count_for_route(route.id)::integer as beta_count
from public.routes route
where route.deleted_at is null and route.moderation_status = 'visible';

create or replace view public.wall_zone_summaries
with (security_invoker = true)
as
select
  zone.id, zone.gym_id, zone.name, zone.location_description, zone.wall_type,
  zone.display_order, zone.availability, zone.last_reset_date,
  count(distinct route.id) filter (where route.lifecycle = 'active')::integer as current_route_count,
  (
    select coalesce(sum(public.visible_beta_count_for_route(r.id)), 0)::integer
    from public.routes r
    where r.wall_zone_id = zone.id
      and r.deleted_at is null
      and r.moderation_status = 'visible'
  ) as beta_count
from public.wall_zones zone
left join public.routes route on route.wall_zone_id = zone.id
  and route.deleted_at is null and route.moderation_status = 'visible'
group by zone.id;

create or replace view public.gym_summaries
with (security_invoker = true)
as
select
  gym.id, gym.name, gym.brand_name, gym.slug, gym.suburb, gym.state,
  gym.latitude, gym.longitude, gym.is_verified, gym.data_source,
  count(distinct zone.id)::integer as wall_zone_count,
  (
    select coalesce(sum(public.visible_beta_count_for_route(r.id)), 0)::integer
    from public.routes r
    where r.gym_id = gym.id and r.deleted_at is null
  ) as beta_count,
  max(reset.reset_date) as latest_reset_date
from public.gyms gym
left join public.wall_zones zone on zone.gym_id = gym.id and zone.archived_at is null
left join public.reset_events reset on reset.gym_id = gym.id
  and reset.deleted_at is null and reset.state in ('confirmed', 'estimated')
where gym.deleted_at is null
group by gym.id;

-- 4. Search support. The architecture document freezes a pg_trgm index on the
--    lowercased gym name; the client search contract also covers gym suburb,
--    wall-zone name, and route colour/label. Username is excluded because the
--    MVP search never targets users.
create extension if not exists pg_trgm with schema extensions;

create index gyms_name_trgm_idx
  on public.gyms using gin (lower(name) extensions.gin_trgm_ops)
  where deleted_at is null;
create index gyms_suburb_trgm_idx
  on public.gyms using gin (lower(suburb) extensions.gin_trgm_ops)
  where deleted_at is null;
create index wall_zones_name_trgm_idx
  on public.wall_zones using gin (lower(name) extensions.gin_trgm_ops)
  where archived_at is null;
create index routes_colour_trgm_idx
  on public.routes using gin (lower(colour) extensions.gin_trgm_ops)
  where deleted_at is null;
create index routes_label_trgm_idx
  on public.routes using gin (lower(label) extensions.gin_trgm_ops)
  where deleted_at is null;
