-- Allow anon (guest) to read gym summaries via the view's underlying tables.
-- The view is security_invoker, so anon needs direct SELECT on all joined tables.
grant select on public.beta_links to anon;
grant select on public.routes to anon;
grant select on public.wall_zones to anon;
grant select on public.reset_events to anon;
grant select on public.gyms to anon;
grant select on public.gym_summaries to anon, authenticated;
