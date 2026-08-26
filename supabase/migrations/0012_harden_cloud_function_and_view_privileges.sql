-- Stage 7 D-1: reduce Cloud Data API privileges to the minimum client surface.
-- Trigger functions remain callable by PostgreSQL triggers without direct
-- EXECUTE grants to anon or authenticated clients.

create schema if not exists extensions;
alter extension citext set schema extensions;

create or replace function public.normalise_beta_link()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.normalised_url := pg_catalog.btrim(new.public_url);
  new.normalised_url_hash := pg_catalog.encode(
    extensions.digest(new.normalised_url, 'sha256'),
    'hex'
  );
  return new;
end;
$$;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Reset the
-- client roles, then explicitly expose only the RPCs required by BlocLens.
revoke execute on all functions in schema public from PUBLIC, anon, authenticated;

grant execute on function
  public.community_grade_summary(uuid),
  public.gym_hard_soft_summary(uuid),
  public.visible_beta_count_for_route(uuid)
to anon, authenticated;

grant execute on function
  public.get_my_profile(),
  public.has_app_role(public.app_role),
  public.has_attempted_route(uuid),
  public.is_admin(),
  public.is_admin_or_moderator(),
  public.is_gym_official(uuid),
  public.merge_routes(uuid, uuid, text),
  public.restore_moderated_content(public.content_type, uuid, text)
to authenticated;

-- Views also receive broad default table privileges in hosted PostgreSQL.
-- Revoke every client privilege before restoring read-only access by audience.
revoke all privileges on table
  public.public_profiles,
  public.gym_summaries,
  public.wall_zone_summaries,
  public.route_summaries,
  public.beta_ranking_inputs,
  public.reset_summaries,
  public.moderation_queue,
  public.gym_official_scope
from PUBLIC, anon, authenticated;

grant select on table
  public.public_profiles,
  public.gym_summaries,
  public.wall_zone_summaries,
  public.route_summaries,
  public.reset_summaries
to anon, authenticated;

grant select on table
  public.beta_ranking_inputs,
  public.moderation_queue,
  public.gym_official_scope
to authenticated;
