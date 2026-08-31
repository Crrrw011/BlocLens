-- Expose google_place_id through gym_summaries for client photo pipeline.
drop view if exists public.gym_summaries;

create view public.gym_summaries
with (security_invoker = true)
as
select
  gym.id, gym.name, gym.brand_name, gym.slug, gym.suburb, gym.state,
  gym.latitude, gym.longitude, gym.is_verified, gym.data_source,
  gym.google_place_id,
  count(distinct zone.id)::integer as wall_zone_count,
  count(distinct beta.id)::integer as beta_count,
  max(reset.reset_date) as latest_reset_date
from public.gyms gym
left join public.wall_zones zone on zone.gym_id = gym.id and zone.archived_at is null
left join public.routes route on route.gym_id = gym.id and route.deleted_at is null
left join public.beta_links beta on beta.route_id = route.id
  and beta.deleted_at is null and beta.moderation_status = 'visible'
left join public.reset_events reset on reset.gym_id = gym.id
  and reset.deleted_at is null and reset.state in ('confirmed', 'estimated')
where gym.deleted_at is null
group by gym.id, gym.google_place_id;

grant select on public.gym_summaries to anon, authenticated;
