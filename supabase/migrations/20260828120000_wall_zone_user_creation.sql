-- Stage 7 scope unfreeze: signed-in users may create a named wall zone for a
-- gym they can see. Zone creation takes effect immediately (no moderation step).
-- Renaming and reordering existing zones remain limited to gym officials and
-- the Administrator portal, so the public and official_manage policies are kept.

-- Attribution: record which user submitted each zone. Nullable so existing and
-- fixture/seed rows (which are not user-submitted) remain valid.
alter table public.wall_zones
  add column created_by uuid references auth.users(id) on delete set null;

create index wall_zones_created_by_idx
  on public.wall_zones (created_by)
  where created_by is not null;

-- A signed-in user can add a new zone to a visible gym, but only as their own
-- submission and only as a non-archived zone. Officials and administrators keep
-- the existing broad manage policy and may additionally create zones.
create policy wall_zones_user_insert on public.wall_zones
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and archived_at is null
    and availability = 'active'
  );

comment on table public.wall_zones is
  'Named list-based wall zones only. No 2D coordinates, polygons, hotspots or indoor geometry. Created zones take effect immediately.';
