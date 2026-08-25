-- Trusted server rules, aggregation RPCs, merge transaction and safe read surfaces.

create or replace function public.initialise_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, 'climber_' || right(replace(new.id::text, '-', ''), 12))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger auth_user_initialise_profile
after insert on auth.users
for each row execute function public.initialise_profile_for_auth_user();

revoke all on function public.initialise_profile_for_auth_user() from public;

create or replace function public.normalise_beta_link()
returns trigger
language plpgsql
as $$
begin
  -- Preserve path case because paths may be case-sensitive. A future trusted URL
  -- service may apply platform-specific canonicalisation behind the repository.
  new.normalised_url := btrim(new.public_url);
  new.normalised_url_hash := encode(digest(new.normalised_url, 'sha256'), 'hex');
  return new;
end;
$$;

create trigger beta_links_normalise_url
before insert or update of public_url on public.beta_links
for each row execute function public.normalise_beta_link();

create or replace function public.validate_beta_helpful_vote()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.beta_links beta
    where beta.id = new.beta_link_id
      and beta.submitted_by = new.user_id
  ) then
    raise exception 'A contributor cannot mark their own beta link as Helpful';
  end if;
  return new;
end;
$$;

create trigger beta_helpful_prevent_self_vote
before insert or update on public.beta_helpful_votes
for each row execute function public.validate_beta_helpful_vote();

create or replace function public.recalculate_beta_helpful()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_beta_id uuid;
  affected_submitter uuid;
  valid_count integer;
  received_count integer;
begin
  affected_beta_id := coalesce(new.beta_link_id, old.beta_link_id);

  select beta.submitted_by
  into affected_submitter
  from public.beta_links beta
  where beta.id = affected_beta_id
  for update;

  select count(*)::integer
  into valid_count
  from public.beta_helpful_votes vote
  join public.beta_links beta on beta.id = vote.beta_link_id
  where vote.beta_link_id = affected_beta_id
    and vote.deleted_at is null
    and beta.deleted_at is null
    and beta.link_status = 'healthy'
    and beta.moderation_status = 'visible';

  update public.beta_links
  set helpful_count = valid_count
  where id = affected_beta_id;

  if affected_submitter is not null then
    perform 1
    from public.profiles profile
    where profile.id = affected_submitter
    for update;

    select coalesce(sum(beta.helpful_count), 0)::integer
    into received_count
    from public.beta_links beta
    where beta.submitted_by = affected_submitter
      and beta.deleted_at is null
      and beta.link_status = 'healthy'
      and beta.moderation_status = 'visible';

    update public.profiles
    set helpful_received_count = received_count,
        is_trusted_contributor = is_trusted_contributor or received_count >= 67,
        trusted_contributor_awarded_at = case
          when trusted_contributor_awarded_at is not null then trusted_contributor_awarded_at
          when received_count >= 67 then now()
          else null
        end
    where id = affected_submitter;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger beta_helpful_recalculate
after insert or update or delete on public.beta_helpful_votes
for each row execute function public.recalculate_beta_helpful();

create or replace function public.recalculate_beta_visibility_helpful()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  valid_count integer;
  received_count integer;
begin
  select count(*)::integer
  into valid_count
  from public.beta_helpful_votes vote
  where vote.beta_link_id = new.id
    and vote.deleted_at is null
    and new.deleted_at is null
    and new.link_status = 'healthy'
    and new.moderation_status = 'visible';

  update public.beta_links
  set helpful_count = valid_count
  where id = new.id;

  if new.submitted_by is not null then
    perform 1 from public.profiles where id = new.submitted_by for update;
    select coalesce(sum(beta.helpful_count), 0)::integer
    into received_count
    from public.beta_links beta
    where beta.submitted_by = new.submitted_by
      and beta.deleted_at is null
      and beta.link_status = 'healthy'
      and beta.moderation_status = 'visible';

    update public.profiles
    set helpful_received_count = received_count,
        is_trusted_contributor = is_trusted_contributor or received_count >= 67,
        trusted_contributor_awarded_at = case
          when trusted_contributor_awarded_at is not null then trusted_contributor_awarded_at
          when received_count >= 67 then now()
          else null
        end
    where id = new.submitted_by;
  end if;
  return new;
end;
$$;

create trigger beta_visibility_helpful_recalculate
after update of link_status, moderation_status, deleted_at on public.beta_links
for each row
when (
  old.link_status is distinct from new.link_status
  or old.moderation_status is distinct from new.moderation_status
  or old.deleted_at is distinct from new.deleted_at
)
execute function public.recalculate_beta_visibility_helpful();

create or replace function public.recalculate_route_photo_helpful()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_photo_id uuid;
begin
  affected_photo_id := coalesce(new.photo_id, old.photo_id);
  update public.route_photos photo
  set helpful_count = (
    select count(*)::integer
    from public.route_photo_helpful_votes vote
    where vote.photo_id = affected_photo_id and vote.deleted_at is null
  )
  where photo.id = affected_photo_id;
  return coalesce(new, old);
end;
$$;

create trigger route_photo_helpful_recalculate
after insert or update or delete on public.route_photo_helpful_votes
for each row execute function public.recalculate_route_photo_helpful();

create or replace function public.recalculate_reset_confirmation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_reset_id uuid;
  valid_count integer;
begin
  affected_reset_id := coalesce(new.reset_event_id, old.reset_event_id);
  select count(*)::integer
  into valid_count
  from public.reset_confirmations confirmation
  where confirmation.reset_event_id = affected_reset_id
    and confirmation.revoked_at is null;

  update public.reset_events event
  set confirmation_count = valid_count,
      source = case
        when event.is_official then 'official'::public.reset_source
        when valid_count >= 3 then 'community_confirmed'::public.reset_source
        else event.source
      end,
      state = case
        when event.is_official or valid_count >= 3 then 'confirmed'::public.reset_state
        else event.state
      end,
      is_estimated = case
        when event.is_official or valid_count >= 3 then false
        else event.is_estimated
      end
  where event.id = affected_reset_id;
  return coalesce(new, old);
end;
$$;

create trigger reset_confirmation_recalculate
after insert or update or delete on public.reset_confirmations
for each row execute function public.recalculate_reset_confirmation();

create or replace function public.community_grade_summary(requested_route_id uuid)
returns table (
  route_id uuid,
  vote_count integer,
  is_display_eligible boolean,
  median_v_grade smallint
)
language sql
stable
security definer
set search_path = ''
as $$
  with valid_votes as (
    select vote.v_grade
    from public.route_grade_votes vote
    where vote.route_id = requested_route_id
      and vote.is_valid
  ),
  summary as (
    select
      count(*)::integer as vote_count,
      percentile_disc(0.5) within group (order by v_grade)::smallint as median_grade
    from valid_votes
  )
  select
    requested_route_id,
    summary.vote_count,
    summary.vote_count >= 3,
    case when summary.vote_count >= 3 then summary.median_grade else null end
  from summary
  where exists (
    select 1
    from public.routes route
    where route.id = requested_route_id
      and route.deleted_at is null
      and route.moderation_status = 'visible'
  );
$$;

revoke all on function public.community_grade_summary(uuid) from public;
grant execute on function public.community_grade_summary(uuid) to anon, authenticated;

create or replace function public.get_my_profile()
returns table (
  id uuid,
  username citext,
  avatar_path text,
  height_cm numeric,
  arm_span_cm numeric,
  regular_grade smallint,
  favourite_gym_id uuid,
  is_trusted_contributor boolean,
  trusted_contributor_awarded_at timestamptz,
  helpful_received_count integer,
  age_confirmed_16_plus_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.id, profile.username, profile.avatar_path, profile.height_cm,
    profile.arm_span_cm, profile.regular_grade, profile.favourite_gym_id,
    profile.is_trusted_contributor, profile.trusted_contributor_awarded_at,
    profile.helpful_received_count, profile.age_confirmed_16_plus_at,
    profile.created_at, profile.updated_at
  from public.profiles profile
  where profile.id = auth.uid() and profile.deleted_at is null;
$$;

revoke all on function public.get_my_profile() from public;
grant execute on function public.get_my_profile() to authenticated;

create or replace function public.gym_hard_soft_summary(requested_gym_id uuid)
returns table (
  grade_band text,
  eligible_route_count integer,
  median_grade_delta numeric,
  assessment text
)
language sql
stable
security definer
set search_path = ''
as $$
  with eligible as (
    select
      route.gym_grade,
      grade_summary.median_v_grade,
      case
        when route.gym_grade between -1 and 2 then 'V0–V2'
        when route.gym_grade between 3 and 5 then 'V3–V5'
        else 'V6+'
      end as band
    from public.routes route
    cross join lateral public.community_grade_summary(route.id) grade_summary
    where route.gym_id = requested_gym_id
      and route.deleted_at is null
      and route.moderation_status = 'visible'
      and route.gym_grade is not null
      and grade_summary.is_display_eligible
      and exists (
        select 1 from public.gyms gym
        where gym.id = requested_gym_id and gym.deleted_at is null
      )
  ),
  banded as (
    select
      band,
      count(*)::integer as route_count,
      percentile_disc(0.5) within group (order by median_v_grade - gym_grade)::numeric as delta
    from eligible
    group by band
    union all
    select
      'Overall',
      count(*)::integer,
      percentile_disc(0.5) within group (order by median_v_grade - gym_grade)::numeric
    from eligible
  )
  select
    band,
    route_count,
    delta,
    case
      when route_count < 3 then 'not_enough_community_data'
      when delta > 0 then 'hard'
      when delta < 0 then 'soft'
      else 'balanced'
    end
  from banded
  order by case band when 'V0–V2' then 1 when 'V3–V5' then 2 when 'V6+' then 3 else 4 end;
$$;

revoke all on function public.gym_hard_soft_summary(uuid) from public;
grant execute on function public.gym_hard_soft_summary(uuid) to anon, authenticated;

create or replace function public.apply_route_correction_threshold()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  reporter_count integer;
  changed_count integer;
begin
  select count(distinct correction.submitted_by)::integer
  into reporter_count
  from public.route_corrections correction
  where correction.route_id = new.route_id
    and correction.status in ('open', 'under_review')
    and correction.submitted_by is not null;

  if reporter_count >= 3 then
    update public.routes
    set moderation_status = 'temporarily_hidden',
        lifecycle = 'temporarily_hidden',
        hidden_at = coalesce(hidden_at, now())
    where id = new.route_id
      and moderation_status = 'visible';
    get diagnostics changed_count = row_count;

    if changed_count > 0 then
      insert into public.moderation_actions (
        action_type, target_type, target_id, reason, metadata
      ) values (
        'hide', 'route', new.route_id,
        'Three distinct route corrections reached the temporary-hide threshold.',
        jsonb_build_object('distinct_reporters', reporter_count, 'automated', true)
      );
    end if;
  end if;
  return new;
end;
$$;

create trigger route_correction_threshold
after insert or update of status on public.route_corrections
for each row execute function public.apply_route_correction_threshold();

create or replace function public.apply_route_removal_threshold()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  reporter_count integer;
  changed_count integer;
begin
  select count(distinct report.reported_by)::integer
  into reporter_count
  from public.route_removal_reports report
  where report.route_id = new.route_id
    and report.status in ('open', 'under_review')
    and report.reported_by is not null;

  if reporter_count >= 3 then
    update public.routes
    set lifecycle = 'archived',
        archived_at = coalesce(archived_at, now()),
        archived_reason = coalesce(archived_reason, 'Community removal threshold reached')
    where id = new.route_id
      and lifecycle <> 'archived'
      and estimated_archive_date is not null
      and estimated_archive_date <= now();
    get diagnostics changed_count = row_count;

    if changed_count > 0 then
      insert into public.moderation_actions (
        action_type, target_type, target_id, reason, metadata
      ) values (
        'archive', 'route', new.route_id,
        'Three removal reports and the estimated date condition were satisfied.',
        jsonb_build_object('distinct_reporters', reporter_count, 'automated', true)
      );
    end if;
  end if;
  return new;
end;
$$;

create trigger route_removal_threshold
after insert or update of status on public.route_removal_reports
for each row execute function public.apply_route_removal_threshold();

create or replace function public.validate_content_report_target()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_exists boolean;
begin
  target_exists := case new.target_type
    when 'route' then exists (select 1 from public.routes where id = new.target_id)
    when 'beta_link' then exists (select 1 from public.beta_links where id = new.target_id)
    when 'beta_comment' then exists (select 1 from public.beta_comments where id = new.target_id)
    when 'route_photo' then exists (select 1 from public.route_photos where id = new.target_id)
    else false
  end;
  if not target_exists then
    raise exception 'Report target does not exist';
  end if;
  return new;
end;
$$;

create trigger content_report_validate_target
before insert or update of target_type, target_id on public.content_reports
for each row execute function public.validate_content_report_target();

create or replace function public.apply_content_report_threshold()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  distinct_reports integer;
  severe_reports integer;
  should_hide boolean;
  changed_count integer := 0;
begin
  select
    count(distinct reporter_id)::integer,
    count(distinct reporter_id) filter (where is_severe)::integer
  into distinct_reports, severe_reports
  from public.content_reports
  where target_type = new.target_type
    and target_id = new.target_id
    and status in ('open', 'under_review')
    and reporter_id is not null;

  should_hide := severe_reports >= 1 or distinct_reports >= 3;
  if should_hide then
    case new.target_type
      when 'route' then
        update public.routes
        set moderation_status = 'temporarily_hidden',
            lifecycle = 'temporarily_hidden',
            hidden_at = coalesce(hidden_at, now())
        where id = new.target_id and moderation_status = 'visible';
      when 'beta_link' then
        update public.beta_links
        set moderation_status = 'temporarily_hidden',
            hidden_at = coalesce(hidden_at, now())
        where id = new.target_id and moderation_status = 'visible';
      when 'beta_comment' then
        update public.beta_comments
        set moderation_status = 'temporarily_hidden',
            hidden_at = coalesce(hidden_at, now())
        where id = new.target_id and moderation_status = 'visible';
      when 'route_photo' then
        update public.route_photos
        set moderation_status = 'temporarily_hidden'
        where id = new.target_id and moderation_status = 'visible';
    end case;
    get diagnostics changed_count = row_count;

    if changed_count > 0 then
      insert into public.moderation_actions (
        action_type, target_type, target_id, reason, metadata
      ) values (
        'hide', new.target_type, new.target_id,
        case when severe_reports >= 1
          then 'A severe report reached the one-report temporary-hide threshold.'
          else 'Three distinct reports reached the temporary-hide threshold.'
        end,
        jsonb_build_object(
          'distinct_reporters', distinct_reports,
          'severe_reporters', severe_reports,
          'automated', true
        )
      );
    end if;
  end if;
  return new;
end;
$$;

create trigger content_report_threshold
after insert or update of status on public.content_reports
for each row execute function public.apply_content_report_threshold();

create or replace function public.restore_moderated_content(
  requested_target_type public.content_type,
  requested_target_id uuid,
  restoration_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  restored_count integer := 0;
begin
  if not public.is_admin_or_moderator() then
    raise exception 'Administrator or moderator role required';
  end if;
  if nullif(btrim(restoration_reason), '') is null then
    raise exception 'Restoration reason is required';
  end if;

  case requested_target_type
    when 'route' then
      update public.routes
      set moderation_status = 'visible',
          lifecycle = case when lifecycle = 'temporarily_hidden' then 'active' else lifecycle end,
          hidden_at = null
      where id = requested_target_id and moderation_status = 'temporarily_hidden';
    when 'beta_link' then
      update public.beta_links
      set moderation_status = 'visible', hidden_at = null
      where id = requested_target_id and moderation_status = 'temporarily_hidden';
    when 'beta_comment' then
      update public.beta_comments
      set moderation_status = 'visible', hidden_at = null
      where id = requested_target_id and moderation_status = 'temporarily_hidden';
    when 'route_photo' then
      update public.route_photos
      set moderation_status = 'visible'
      where id = requested_target_id and moderation_status = 'temporarily_hidden';
  end case;
  get diagnostics restored_count = row_count;

  if restored_count <> 1 then
    raise exception 'No temporarily hidden content matched the requested target';
  end if;

  insert into public.moderation_actions (
    action_type, target_type, target_id, performed_by, reason, metadata
  ) values (
    'restore', requested_target_type, requested_target_id, auth.uid(), restoration_reason,
    jsonb_build_object('automated', false)
  );
end;
$$;

revoke all on function public.restore_moderated_content(public.content_type, uuid, text) from public;
grant execute on function public.restore_moderated_content(public.content_type, uuid, text) to authenticated;

create or replace function public.stop_follows_after_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.user_follows follow
  where (follow.follower_id = new.blocker_id and follow.followed_id = new.blocked_id)
     or (follow.follower_id = new.blocked_id and follow.followed_id = new.blocker_id);
  return new;
end;
$$;

create trigger user_block_stop_follows
after insert on public.user_blocks
for each row execute function public.stop_follows_after_block();

create or replace function public.merge_routes(
  p_source_route_id uuid,
  p_canonical_route_id uuid,
  p_merge_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_route public.routes%rowtype;
  canonical_route public.routes%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Administrator role required';
  end if;
  if p_source_route_id = p_canonical_route_id then
    raise exception 'Source and canonical route must differ';
  end if;
  if nullif(btrim(p_merge_reason), '') is null then
    raise exception 'Merge reason is required';
  end if;

  select * into source_route from public.routes where id = p_source_route_id for update;
  select * into canonical_route from public.routes where id = p_canonical_route_id for update;
  if source_route.id is null or canonical_route.id is null then
    raise exception 'Both routes must exist';
  end if;
  if source_route.gym_id <> canonical_route.gym_id then
    raise exception 'Routes from different gyms cannot be merged';
  end if;

  update public.beta_links set route_id = p_canonical_route_id where route_id = p_source_route_id;

  update public.route_grade_votes source_vote
  set is_valid = false,
      superseded_at = now(),
      superseded_by_route_id = p_canonical_route_id
  where source_vote.route_id = p_source_route_id
    and exists (
      select 1 from public.route_grade_votes canonical_vote
      where canonical_vote.route_id = p_canonical_route_id
        and canonical_vote.user_id = source_vote.user_id
    );

  update public.route_grade_votes source_vote
  set route_id = p_canonical_route_id
  where source_vote.route_id = p_source_route_id
    and not exists (
      select 1 from public.route_grade_votes canonical_vote
      where canonical_vote.route_id = p_canonical_route_id
        and canonical_vote.user_id = source_vote.user_id
    );

  update public.logbook_entries source_entry
  set merged_into_entry_id = canonical_entry.id,
      deleted_at = coalesce(source_entry.deleted_at, now())
  from public.logbook_entries canonical_entry
  where source_entry.route_id = p_source_route_id
    and canonical_entry.route_id = p_canonical_route_id
    and canonical_entry.user_id = source_entry.user_id;

  update public.logbook_entries source_entry
  set route_id = p_canonical_route_id
  where source_entry.route_id = p_source_route_id
    and source_entry.deleted_at is null
    and not exists (
      select 1 from public.logbook_entries canonical_entry
      where canonical_entry.route_id = p_canonical_route_id
        and canonical_entry.user_id = source_entry.user_id
    );

  update public.routes
  set lifecycle = 'archived',
      archived_at = coalesce(archived_at, now()),
      archived_reason = 'Merged into canonical route',
      canonical_route_id = p_canonical_route_id
  where id = p_source_route_id;

  update public.route_merge_suggestions
  set status = 'completed',
      reviewed_by = auth.uid(),
      reviewed_at = coalesce(reviewed_at, now()),
      completed_at = now()
  where source_route_id = p_source_route_id
    and proposed_canonical_route_id = p_canonical_route_id
    and status in ('proposed', 'approved');

  insert into public.moderation_actions (
    action_type, target_type, target_id, performed_by, reason, metadata, reversible
  ) values (
    'merge', 'route', p_source_route_id, auth.uid(), p_merge_reason,
    jsonb_build_object('canonical_route_id', p_canonical_route_id), true
  );
end;
$$;

revoke all on function public.merge_routes(uuid, uuid, text) from public;
grant execute on function public.merge_routes(uuid, uuid, text) to authenticated;

-- Security-invoker views preserve underlying RLS. Aggregate grade data uses the
-- thresholded SECURITY DEFINER RPC above rather than exposing individual votes.
create view public.public_profiles
with (security_invoker = true)
as
select id, username, avatar_path, height_cm, arm_span_cm, regular_grade,
       is_trusted_contributor
from public.profiles
where deleted_at is null;

create view public.gym_summaries
with (security_invoker = true)
as
select
  gym.id, gym.name, gym.brand_name, gym.slug, gym.suburb, gym.state,
  gym.latitude, gym.longitude, gym.is_verified, gym.data_source,
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
group by gym.id;

create view public.wall_zone_summaries
with (security_invoker = true)
as
select
  zone.id, zone.gym_id, zone.name, zone.location_description, zone.wall_type,
  zone.display_order, zone.availability, zone.last_reset_date,
  count(distinct route.id) filter (where route.lifecycle = 'active')::integer as current_route_count,
  count(distinct beta.id)::integer as beta_count
from public.wall_zones zone
left join public.routes route on route.wall_zone_id = zone.id
  and route.deleted_at is null and route.moderation_status = 'visible'
left join public.beta_links beta on beta.route_id = route.id
  and beta.deleted_at is null and beta.moderation_status = 'visible'
group by zone.id;

create view public.route_summaries
with (security_invoker = true)
as
select
  route.id, route.gym_id, route.wall_zone_id, route.colour, route.label,
  route.gym_grade, route.lifecycle, route.set_date, route.estimated_archive_date,
  route.is_archive_date_estimated, route.archived_at,
  count(beta.id)::integer as beta_count
from public.routes route
left join public.beta_links beta on beta.route_id = route.id
  and beta.deleted_at is null and beta.moderation_status = 'visible'
where route.deleted_at is null and route.moderation_status = 'visible'
group by route.id;

create view public.beta_ranking_inputs
with (security_invoker = true)
as
select
  id, route_id, public_url, platform, original_author_display_name,
  original_post_url, tags, submitter_height_cm, submitter_arm_span_cm,
  helpful_count, link_status, moderation_status, embed_capability,
  is_official_source, created_at
from public.beta_links
where deleted_at is null and moderation_status = 'visible';

create view public.reset_summaries
with (security_invoker = true)
as
select
  id, gym_id, wall_zone_id, reset_date, source, state,
  confirmation_count, is_estimated, is_official
from public.reset_events
where deleted_at is null and state in ('confirmed', 'estimated');

create view public.moderation_queue
with (security_invoker = true)
as
select
  report.target_type, report.target_id, report.status,
  count(*)::integer as report_count,
  bool_or(report.is_severe) as has_severe_report,
  min(report.created_at) as first_reported_at
from public.content_reports report
where report.status in ('open', 'under_review')
  and public.is_admin_or_moderator()
group by report.target_type, report.target_id, report.status;

create view public.gym_official_scope
with (security_invoker = true)
as
select membership.user_id, membership.gym_id, gym.name, membership.granted_at
from public.gym_memberships membership
join public.gyms gym on gym.id = membership.gym_id
where membership.revoked_at is null and gym.deleted_at is null;

grant select on public.public_profiles, public.gym_summaries,
  public.wall_zone_summaries, public.route_summaries,
  public.beta_ranking_inputs, public.reset_summaries to anon, authenticated;
grant select on public.moderation_queue, public.gym_official_scope to authenticated;

comment on view public.public_profiles is
  'Safe public subset. It excludes email, provider identifiers, favourite gym, age declaration, Helpful count and all private data.';
comment on view public.moderation_queue is
  'Security-invoker view. Underlying report RLS limits results to authorised moderators and administrators.';
