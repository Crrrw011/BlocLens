-- Stage 7/8: creators may edit their own routes; expose route created_by so the
-- app can decide whether to offer the edit affordance.

-- Expose created_by on the route summary view.
drop view if exists public.route_summaries;
create view public.route_summaries
with (security_invoker = true)
as
select
  route.id, route.gym_id, route.wall_zone_id, route.colour, route.terrain,
  route.styles, route.subjective_grade, route.gym_grade, route.lifecycle,
  route.set_date, route.estimated_archive_date, route.is_archive_date_estimated,
  route.archived_at, route.created_by,
  public.visible_beta_count_for_route(route.id)::integer as beta_count
from public.routes route
where route.deleted_at is null and route.moderation_status = 'visible';

grant select on table public.route_summaries to anon, authenticated;

-- A signed-in user can update a route they created (colour, terrain, style,
-- subjective grade). Officials/admin keep the existing broad update policy.
create policy routes_creator_update on public.routes
  for update to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());
