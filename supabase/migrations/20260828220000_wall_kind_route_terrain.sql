-- Stage 7/8 route & wall-zone model refresh.
-- 1. Wall-zone "wall type" becomes a wall KIND (Regular Set Wall / Spray Wall /
--    Comp Wall) instead of an angle description.
-- 2. Routes gain terrain (slab/vertical/overhang/roof/cave/mixed), a multi-select
--    style array (static/dynamic/technical/powerful/coordination), and a
--    subjective grade (VB..V17). Route label is dropped; colour remains the
--    primary identity.
-- 3. Wall zones become reportable content so users can flag an erroneous zone.

-- New enums -------------------------------------------------------------------

create type public.wall_kind as enum (
  'regular_set_wall', 'spray_wall', 'comp_wall'
);

create type public.route_terrain as enum (
  'slab', 'vertical', 'overhang', 'roof', 'cave', 'mixed'
);

create type public.route_style as enum (
  'static', 'dynamic', 'technical', 'powerful', 'coordination'
);

-- Content type: allow reporting a wall zone ----------------------------------

alter type public.content_type add value 'wall_zone';

-- Drop dependent views before altering their source columns. ------------------

drop view if exists public.route_summaries;
drop view if exists public.wall_zone_summaries;

-- wall_zones: replace wall_type with wall_kind --------------------------------

alter table public.wall_zones
  drop column wall_type,
  add column wall_kind public.wall_kind not null default 'regular_set_wall';

comment on column public.wall_zones.wall_kind is
  'Kind of wall zone: regular set wall, spray wall or competition wall.';

-- routes: drop label, add terrain/style/subjective grade ----------------------

alter table public.routes drop constraint routes_identity_required;
alter table public.routes drop constraint routes_label_length;

alter table public.routes
  drop column label;

alter table public.routes
  add column terrain public.route_terrain not null default 'slab',
  add column styles public.route_style[] not null default '{}',
  add column subjective_grade smallint;

alter table public.routes
  add constraint routes_colour_required check (nullif(btrim(colour), '') is not null);
alter table public.routes
  add constraint routes_subjective_grade_range
  check (subjective_grade is null or subjective_grade between -1 and 17);

comment on column public.routes.terrain is
  'Terrain of the route: slab, vertical, overhang, roof, cave or mixed.';
comment on column public.routes.styles is
  'Multi-select route styles (static, dynamic, technical, powerful, coordination).';
comment on column public.routes.subjective_grade is
  'Submitter''s subjective difficulty (VB..V17). Community median overrides display.';

-- Rebuild the public summary views with the new columns. ----------------------

create view public.route_summaries
with (security_invoker = true)
as
select
  route.id, route.gym_id, route.wall_zone_id, route.colour, route.terrain,
  route.styles, route.subjective_grade, route.gym_grade, route.lifecycle,
  route.set_date, route.estimated_archive_date, route.is_archive_date_estimated,
  route.archived_at,
  public.visible_beta_count_for_route(route.id)::integer as beta_count
from public.routes route
where route.deleted_at is null and route.moderation_status = 'visible';

grant select on table public.route_summaries to anon, authenticated;

create view public.wall_zone_summaries
with (security_invoker = true)
as
select
  zone.id, zone.gym_id, zone.name, zone.location_description, zone.wall_kind,
  zone.surface_material, zone.surface_texture, zone.has_bolt_holes,
  zone.created_by,
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

grant select on table public.wall_zone_summaries to anon, authenticated;

-- Creator can update their own wall zone (name, location, kind, surface,
-- texture, bolt holes). Officials/admin keep the existing broad manage policy.
create policy wall_zones_creator_update on public.wall_zones
  for update to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

-- Search index: route label is gone; colour remains searchable. ---------------

drop index if exists public.routes_label_trgm_idx;
