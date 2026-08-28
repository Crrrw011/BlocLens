-- Stage 7/8 wall-zone detail: add required surface-material, surface-texture and
-- bolt-hole flags to wall_zones. Defaults are applied so existing rows and the
-- seed fixtures take the recommended values; the add-zone form supplies these too.

-- Surface material: which board/panel material the wall zone is built from.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'surface_material') then
    create type public.surface_material as enum (
      'plywood', 'fibreglass', 'concrete', 'composite', 'other'
    );
  end if;
end$$;

-- Surface texture: how rough the climbing surface is.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'surface_texture') then
    create type public.surface_texture as enum (
      'smooth', 'lightly_textured', 'textured', 'rough'
    );
  end if;
end$$;

alter table public.wall_zones
  add column surface_material public.surface_material not null default 'plywood',
  add column surface_texture public.surface_texture not null default 'lightly_textured',
  add column has_bolt_holes boolean not null default true;

comment on column public.wall_zones.surface_material is
  'Primary board/panel material of the wall zone. Defaults to plywood.';
comment on column public.wall_zones.surface_texture is
  'Texture of the climbing surface. Defaults to lightly textured.';
comment on column public.wall_zones.has_bolt_holes is
  'Whether the wall zone exposes bolt holes for the setting team. Defaults to true.';

-- Re-expose the new columns through the wall-zone summary view so the app reads
-- them. `create or replace view` cannot add a column before an aggregate, so we
-- drop and recreate. The view is re-granted to match the 0012 hardening.
-- Preserves the 0011 block-aware beta_count (visible_beta_count_for_route).
drop view if exists public.wall_zone_summaries;

create view public.wall_zone_summaries
with (security_invoker = true)
as
select
  zone.id, zone.gym_id, zone.name, zone.location_description, zone.wall_type,
  zone.display_order, zone.availability, zone.last_reset_date,
  zone.surface_material, zone.surface_texture, zone.has_bolt_holes,
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
