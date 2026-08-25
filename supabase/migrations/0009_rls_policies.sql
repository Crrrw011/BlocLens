-- Row Level Security and explicit client grants.
alter table public.profiles enable row level security;
alter table public.app_user_roles enable row level security;
alter table public.gyms enable row level security;
alter table public.gym_facilities enable row level security;
alter table public.gym_memberships enable row level security;
alter table public.wall_zones enable row level security;
alter table public.routes enable row level security;
alter table public.gym_reset_patterns enable row level security;
alter table public.reset_events enable row level security;
alter table public.reset_confirmations enable row level security;
alter table public.route_photos enable row level security;
alter table public.route_photo_helpful_votes enable row level security;
alter table public.beta_links enable row level security;
alter table public.beta_helpful_votes enable row level security;
alter table public.beta_comments enable row level security;
alter table public.logbook_entries enable row level security;
alter table public.route_grade_votes enable row level security;
alter table public.route_corrections enable row level security;
alter table public.route_removal_reports enable row level security;
alter table public.route_merge_suggestions enable row level security;
alter table public.content_reports enable row level security;
alter table public.moderation_actions enable row level security;
alter table public.favourite_gyms enable row level security;
alter table public.user_follows enable row level security;
alter table public.user_blocks enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_outbox enable row level security;
alter table public.gym_claims enable row level security;
alter table public.app_feedback enable row level security;

-- Profiles: public rows are safe only through explicit column grants below.
create policy profiles_public_read on public.profiles
for select to anon, authenticated
using (deleted_at is null);
create policy profiles_owner_update on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());
create policy profiles_admin_update on public.profiles
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy roles_admin_read on public.app_user_roles
for select to authenticated
using (public.is_admin());
create policy roles_admin_insert on public.app_user_roles
for insert to authenticated
with check (public.is_admin());
create policy roles_admin_update on public.app_user_roles
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Public discovery data.
create policy gyms_public_read on public.gyms
for select to anon, authenticated
using (deleted_at is null);
create policy gyms_official_update on public.gyms
for update to authenticated
using (public.is_gym_official(id) or public.is_admin())
with check (public.is_gym_official(id) or public.is_admin());

create policy facilities_public_read on public.gym_facilities
for select to anon, authenticated
using (
  is_available
  and exists (select 1 from public.gyms gym where gym.id = gym_id and gym.deleted_at is null)
);
create policy facilities_official_manage on public.gym_facilities
for all to authenticated
using (public.is_gym_official(gym_id) or public.is_admin())
with check (public.is_gym_official(gym_id) or public.is_admin());

create policy memberships_own_or_admin_read on public.gym_memberships
for select to authenticated
using (user_id = auth.uid() or public.is_admin());
create policy memberships_admin_manage on public.gym_memberships
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy wall_zones_public_read on public.wall_zones
for select to anon, authenticated
using (archived_at is null or availability = 'archived');
create policy wall_zones_official_manage on public.wall_zones
for all to authenticated
using (public.is_gym_official(gym_id) or public.is_admin())
with check (public.is_gym_official(gym_id) or public.is_admin());

create policy routes_public_read on public.routes
for select to anon, authenticated
using (deleted_at is null and moderation_status = 'visible');
create policy routes_user_insert on public.routes
for insert to authenticated
with check (
  created_by = auth.uid()
  and lifecycle = 'active'
  and archived_at is null
  and canonical_route_id is null
  and moderation_status = 'visible'
  and hidden_at is null
  and deleted_at is null
  and (
    not is_official_source
    or public.is_gym_official(gym_id)
    or public.is_admin()
  )
);
create policy routes_official_update on public.routes
for update to authenticated
using (public.is_gym_official(gym_id) or public.is_admin())
with check (public.is_gym_official(gym_id) or public.is_admin());

create policy reset_patterns_public_read on public.gym_reset_patterns
for select to anon, authenticated
using (deleted_at is null);
create policy reset_patterns_official_manage on public.gym_reset_patterns
for all to authenticated
using (public.is_gym_official(gym_id) or public.is_admin())
with check (public.is_gym_official(gym_id) or public.is_admin());

create policy reset_events_public_read on public.reset_events
for select to anon, authenticated
using (deleted_at is null and state in ('confirmed', 'estimated'));
create policy reset_events_user_insert on public.reset_events
for insert to authenticated
with check (
  created_by = auth.uid()
  and (
    (
      not is_official
      and source = 'community_confirmed'
      and state = 'pending'
      and confirmation_count = 0
      and not is_estimated
    )
    or (
      (public.is_gym_official(gym_id) or public.is_admin())
      and is_official
      and source = 'official'
      and state = 'confirmed'
      and confirmation_count = 0
      and not is_estimated
    )
  )
);
create policy reset_events_official_update on public.reset_events
for update to authenticated
using (public.is_gym_official(gym_id) or public.is_admin())
with check (public.is_gym_official(gym_id) or public.is_admin());

create policy reset_confirmations_own_read on public.reset_confirmations
for select to authenticated
using (user_id = auth.uid() or public.is_admin_or_moderator());
create policy reset_confirmations_own_insert on public.reset_confirmations
for insert to authenticated
with check (user_id = auth.uid());
create policy reset_confirmations_own_delete on public.reset_confirmations
for delete to authenticated
using (user_id = auth.uid());

create policy route_photos_public_read on public.route_photos
for select to anon, authenticated
using (deleted_at is null and moderation_status = 'visible');
create policy route_photos_user_insert on public.route_photos
for insert to authenticated
with check (
  uploaded_by = auth.uid()
  and moderation_status = 'visible'
  and helpful_count = 0
  and (
    not is_official_source
    or exists (
      select 1 from public.routes route
      where route.id = route_id
        and (public.is_gym_official(route.gym_id) or public.is_admin())
    )
  )
);
create policy route_photos_owner_update on public.route_photos
for update to authenticated
using (uploaded_by = auth.uid() or public.is_admin_or_moderator())
with check (uploaded_by = auth.uid() or public.is_admin_or_moderator());

create policy photo_helpful_own_read on public.route_photo_helpful_votes
for select to authenticated
using (user_id = auth.uid());
create policy photo_helpful_own_insert on public.route_photo_helpful_votes
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.route_photos photo
    where photo.id = photo_id
      and photo.uploaded_by is distinct from auth.uid()
      and photo.deleted_at is null
      and photo.moderation_status = 'visible'
  )
);
create policy photo_helpful_own_delete on public.route_photo_helpful_votes
for delete to authenticated
using (user_id = auth.uid());

-- External beta metadata and flat comments.
create policy beta_links_public_read on public.beta_links
for select to anon, authenticated
using (deleted_at is null and moderation_status = 'visible');
create policy beta_links_user_insert on public.beta_links
for insert to authenticated
with check (
  submitted_by = auth.uid()
  and helpful_count = 0
  and moderation_status = 'visible'
  and hidden_at is null
  and deleted_at is null
  and (
    not is_official_source
    or exists (
      select 1 from public.routes route
      where route.id = route_id
        and (public.is_gym_official(route.gym_id) or public.is_admin())
    )
  )
);
create policy beta_links_owner_update on public.beta_links
for update to authenticated
using (submitted_by = auth.uid() or public.is_admin_or_moderator())
with check (submitted_by = auth.uid() or public.is_admin_or_moderator());

create policy beta_helpful_own_read on public.beta_helpful_votes
for select to authenticated
using (user_id = auth.uid());
create policy beta_helpful_own_insert on public.beta_helpful_votes
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.beta_links beta
    where beta.id = beta_link_id
      and beta.submitted_by is distinct from auth.uid()
      and beta.deleted_at is null
      and beta.moderation_status = 'visible'
      and beta.link_status = 'healthy'
  )
);
create policy beta_helpful_own_delete on public.beta_helpful_votes
for delete to authenticated
using (user_id = auth.uid());

create policy beta_comments_public_read on public.beta_comments
for select to anon, authenticated
using (deleted_at is null and moderation_status = 'visible');
create policy beta_comments_user_insert on public.beta_comments
for insert to authenticated
with check (
  author_id = auth.uid()
  and moderation_status = 'visible'
  and deleted_at is null
  and (
    official_gym_id is null
    or public.is_gym_official(official_gym_id)
    or public.is_admin()
  )
);

-- Logbook and grade votes.
create policy logbook_owner_read on public.logbook_entries
for select to authenticated
using (user_id = auth.uid());
create policy logbook_owner_insert on public.logbook_entries
for insert to authenticated
with check (user_id = auth.uid());
create policy logbook_owner_update on public.logbook_entries
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
create policy logbook_owner_delete on public.logbook_entries
for delete to authenticated
using (user_id = auth.uid());

create policy grade_votes_own_read on public.route_grade_votes
for select to authenticated
using (user_id = auth.uid() or public.is_admin_or_moderator());
create policy grade_votes_attempt_insert on public.route_grade_votes
for insert to authenticated
with check (
  user_id = auth.uid()
  and is_valid
  and superseded_at is null
  and superseded_by_route_id is null
  and public.has_attempted_route(route_id)
);
create policy grade_votes_attempt_update on public.route_grade_votes
for update to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and public.has_attempted_route(route_id)
);

-- Corrections, reports and moderation.
create policy corrections_own_or_admin_read on public.route_corrections
for select to authenticated
using (submitted_by = auth.uid() or public.is_admin_or_moderator());
create policy corrections_user_insert on public.route_corrections
for insert to authenticated
with check (submitted_by = auth.uid() and status = 'open');
create policy corrections_admin_update on public.route_corrections
for update to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

create policy removal_reports_own_or_admin_read on public.route_removal_reports
for select to authenticated
using (reported_by = auth.uid() or public.is_admin_or_moderator());
create policy removal_reports_user_insert on public.route_removal_reports
for insert to authenticated
with check (reported_by = auth.uid() and status = 'open');
create policy removal_reports_admin_update on public.route_removal_reports
for update to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

create policy merge_suggestions_own_or_admin_read on public.route_merge_suggestions
for select to authenticated
using (suggested_by = auth.uid() or public.is_admin());
create policy merge_suggestions_user_insert on public.route_merge_suggestions
for insert to authenticated
with check (suggested_by = auth.uid() and status = 'proposed');
create policy merge_suggestions_admin_update on public.route_merge_suggestions
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy content_reports_own_or_admin_read on public.content_reports
for select to authenticated
using (reporter_id = auth.uid() or public.is_admin_or_moderator());
create policy content_reports_user_insert on public.content_reports
for insert to authenticated
with check (reporter_id = auth.uid() and status = 'open');
create policy content_reports_admin_update on public.content_reports
for update to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

create policy moderation_actions_admin_read on public.moderation_actions
for select to authenticated
using (public.is_admin_or_moderator());
create policy moderation_actions_admin_insert on public.moderation_actions
for insert to authenticated
with check (public.is_admin_or_moderator() and performed_by = auth.uid());

-- Private personal relationships and preferences.
create policy favourites_owner_manage on public.favourite_gyms
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy follows_participant_read on public.user_follows
for select to authenticated
using (follower_id = auth.uid() or followed_id = auth.uid());
create policy follows_owner_insert on public.user_follows
for insert to authenticated
with check (
  follower_id = auth.uid()
  and not exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = auth.uid() and block.blocked_id = followed_id)
       or (block.blocker_id = followed_id and block.blocked_id = auth.uid())
  )
);
create policy follows_owner_delete on public.user_follows
for delete to authenticated
using (follower_id = auth.uid());

create policy blocks_owner_read on public.user_blocks
for select to authenticated
using (blocker_id = auth.uid());
create policy blocks_owner_insert on public.user_blocks
for insert to authenticated
with check (blocker_id = auth.uid());
create policy blocks_owner_delete on public.user_blocks
for delete to authenticated
using (blocker_id = auth.uid());

create policy notification_preferences_owner_manage on public.notification_preferences
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
create policy notification_outbox_server_only on public.notification_outbox
for select to authenticated
using (false);

create policy gym_claims_owner_or_admin_read on public.gym_claims
for select to authenticated
using (applicant_id = auth.uid() or public.is_admin());
create policy gym_claims_owner_insert on public.gym_claims
for insert to authenticated
with check (applicant_id = auth.uid() and status = 'submitted');
create policy gym_claims_admin_update on public.gym_claims
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy feedback_owner_or_admin_read on public.app_feedback
for select to authenticated
using (user_id = auth.uid() or public.is_admin_or_moderator());
create policy feedback_guest_insert on public.app_feedback
for insert to anon
with check (user_id is null and status = 'received');
create policy feedback_user_insert on public.app_feedback
for insert to authenticated
with check ((user_id = auth.uid() or user_id is null) and status = 'received');
create policy feedback_admin_update on public.app_feedback
for update to authenticated
using (public.is_admin_or_moderator())
with check (public.is_admin_or_moderator());

-- Explicit grants keep server-controlled columns away from ordinary clients.
revoke all on all tables in schema public from anon, authenticated;

grant select (id, username, avatar_path, height_cm, arm_span_cm, regular_grade, is_trusted_contributor, deleted_at)
  on public.profiles to anon, authenticated;
grant update (username, avatar_path, height_cm, arm_span_cm, regular_grade, favourite_gym_id, age_confirmed_16_plus_at)
  on public.profiles to authenticated;

grant select on public.gyms, public.gym_facilities, public.wall_zones, public.routes,
  public.gym_reset_patterns, public.reset_events, public.route_photos,
  public.beta_links, public.beta_comments to anon, authenticated;

grant select, insert, update on public.routes, public.reset_events, public.beta_comments to authenticated;
grant select, insert on public.route_photos, public.beta_links to authenticated;
grant update (storage_path, width, height, deleted_at)
  on public.route_photos to authenticated;
grant update (
  public_url, platform, original_author_display_name, original_post_url,
  tags, submitter_height_cm, submitter_arm_span_cm, embed_capability,
  author_removal_requested_at, deleted_at
) on public.beta_links to authenticated;
grant select, insert, update, delete on public.gym_facilities, public.wall_zones,
  public.gym_reset_patterns to authenticated;
grant select, insert, delete on public.reset_confirmations,
  public.route_photo_helpful_votes, public.beta_helpful_votes to authenticated;
grant select, insert, update, delete on public.logbook_entries to authenticated;
grant select, insert on public.route_grade_votes to authenticated;
grant update (v_grade) on public.route_grade_votes to authenticated;
grant select, insert, update on public.route_corrections, public.route_removal_reports,
  public.route_merge_suggestions, public.content_reports to authenticated;
grant select, insert on public.moderation_actions to authenticated;
grant select, insert, delete on public.favourite_gyms, public.user_follows, public.user_blocks to authenticated;
grant select, insert, update, delete on public.notification_preferences to authenticated;
grant select, insert, update on public.gym_claims to authenticated;
grant select, insert, update on public.app_feedback to authenticated;
grant insert on public.app_feedback to anon;
grant select, insert, update on public.app_user_roles, public.gym_memberships to authenticated;

grant usage on schema public to anon, authenticated;
