-- BlocLens foundation types and shared database utilities.
create extension if not exists pgcrypto;
create extension if not exists citext;

create type public.app_role as enum ('admin', 'moderator');
create type public.gym_membership_role as enum ('verified_representative');
create type public.claim_status as enum ('submitted', 'approved', 'rejected');
create type public.verification_method as enum ('domain_email', 'manual_review');
create type public.gym_data_source as enum ('public_source', 'google_places', 'community', 'official', 'development_fixture');
create type public.facility_code as enum ('parking', 'showers', 'training_board', 'cafe', 'lockers', 'accessible_entry');
create type public.wall_type as enum ('slab', 'vertical', 'overhang', 'cave', 'mixed', 'training_area');
create type public.wall_zone_availability as enum ('active', 'temporarily_unavailable', 'archived');
create type public.route_lifecycle as enum ('active', 'temporarily_hidden', 'archived');
create type public.moderation_status as enum ('visible', 'temporarily_hidden', 'removed');
create type public.reset_source as enum ('official', 'community_confirmed', 'estimated');
create type public.reset_state as enum ('pending', 'confirmed', 'estimated');
create type public.beta_platform as enum ('youtube', 'instagram', 'tiktok', 'vimeo', 'other');
create type public.beta_tag as enum ('full_solution', 'crux', 'static', 'dynamic', 'short_climber', 'tall_climber');
create type public.beta_link_status as enum ('healthy', 'broken', 'removed_by_source');
create type public.embed_capability as enum ('supported', 'source_platform_only');
create type public.logbook_status as enum ('want_to_try', 'projecting', 'sent', 'flash');
create type public.report_category as enum ('wrong_route', 'broken_link', 'unsafe_content', 'nudity', 'harassment', 'violence', 'minor_privacy', 'spam', 'other');
create type public.report_status as enum ('open', 'under_review', 'resolved', 'dismissed');
create type public.correction_status as enum ('open', 'under_review', 'accepted', 'rejected');
create type public.merge_status as enum ('proposed', 'approved', 'rejected', 'completed');
create type public.moderation_action_type as enum ('hide', 'restore', 'archive', 'merge', 'warning', 'timed_restriction', 'publishing_restriction', 'permanent_ban');
create type public.notification_category as enum ('project_removal', 'gym_reset', 'new_beta_for_project', 'followed_contributor_beta');
create type public.feedback_category as enum ('issue', 'suggestion', 'safety', 'data_correction', 'other');
create type public.feedback_status as enum ('received', 'reviewing', 'resolved', 'closed');
create type public.content_type as enum ('route', 'beta_link', 'beta_comment', 'route_photo');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Shared trigger function. The empty search_path prevents object shadowing.';
