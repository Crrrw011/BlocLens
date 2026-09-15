-- Canonical user restrictions with server-enforced contribution gating.
-- Expired restrictions lift automatically at read time; no cron required.

create type public.penalty_kind as enum (
  'publishing_restriction',
  'timed_suspension',
  'permanent_ban'
);

create table public.user_restrictions (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind public.penalty_kind not null,
  reason text not null,
  ends_at timestamptz,
  action_id uuid references public.moderation_actions(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  reversed_by_action_id uuid references public.moderation_actions(id) on delete set null,
  constraint user_restrictions_reason_length check (char_length(reason) between 1 and 1000),
  constraint user_restrictions_ends_consistent check (
    (kind = 'timed_suspension' and ends_at is not null)
    or (kind = 'permanent_ban' and ends_at is null)
    or (kind = 'publishing_restriction' and (ends_at is null or ends_at > created_at))
  ),
  constraint user_restrictions_revocation_consistent check (
    (revoked_at is null) = (reversed_by_action_id is null)
  )
);

create unique index user_restrictions_one_active_kind
  on public.user_restrictions (user_id, kind)
  where revoked_at is null;

alter table public.user_restrictions enable row level security;

comment on table public.user_restrictions is
  'Canonical active user restrictions. History lives in moderation_actions; enforcement reads this table only.';

create or replace function public.has_active_penalty(
  check_user_id uuid,
  check_kinds public.penalty_kind[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_restrictions as restrictions
    where restrictions.user_id = check_user_id
      and restrictions.kind = any (check_kinds)
      and restrictions.revoked_at is null
      and (restrictions.ends_at is null or restrictions.ends_at > statement_timestamp())
  );
$$;

comment on function public.has_active_penalty(uuid, public.penalty_kind[]) is
  'Server-controlled restriction check for contribution RLS. Expired restrictions read as inactive.';

create or replace function public.can_publish(check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not public.has_active_penalty(
    check_user_id,
    array[
      'publishing_restriction'::public.penalty_kind,
      'timed_suspension'::public.penalty_kind,
      'permanent_ban'::public.penalty_kind
    ]
  );
$$;

create or replace function public.can_interact(check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not public.has_active_penalty(
    check_user_id,
    array['timed_suspension'::public.penalty_kind, 'permanent_ban'::public.penalty_kind]
  );
$$;

create or replace function public.can_report(check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not public.has_active_penalty(
    check_user_id, array['permanent_ban'::public.penalty_kind]
  );
$$;

-- Enforcement: contribution inserts honour the three tiers.
-- Publishing creates content; interaction votes/confirms/follows/logs;
-- reporting stays open as a safety valve for everyone but banned users.

drop policy routes_user_insert on public.routes;
create policy routes_user_insert on public.routes
for insert to authenticated
with check (
  created_by = auth.uid()
  and public.can_publish(auth.uid())
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

drop policy reset_events_user_insert on public.reset_events;
create policy reset_events_user_insert on public.reset_events
for insert to authenticated
with check (
  created_by = auth.uid()
  and public.can_publish(auth.uid())
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

drop policy reset_confirmations_own_insert on public.reset_confirmations;
create policy reset_confirmations_own_insert on public.reset_confirmations
for insert to authenticated
with check (user_id = auth.uid() and public.can_interact(auth.uid()));

drop policy route_photos_user_insert on public.route_photos;
create policy route_photos_user_insert on public.route_photos
for insert to authenticated
with check (
  uploaded_by = auth.uid()
  and public.can_publish(auth.uid())
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

drop policy photo_helpful_own_insert on public.route_photo_helpful_votes;
create policy photo_helpful_own_insert on public.route_photo_helpful_votes
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.can_interact(auth.uid())
  and exists (
    select 1 from public.route_photos photo
    where photo.id = photo_id
      and photo.uploaded_by is distinct from auth.uid()
      and photo.deleted_at is null
      and photo.moderation_status = 'visible'
  )
);

drop policy beta_links_user_insert on public.beta_links;
create policy beta_links_user_insert on public.beta_links
for insert to authenticated
with check (
  submitted_by = auth.uid()
  and public.can_publish(auth.uid())
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

drop policy beta_helpful_own_insert on public.beta_helpful_votes;
create policy beta_helpful_own_insert on public.beta_helpful_votes
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.can_interact(auth.uid())
  and exists (
    select 1 from public.beta_links beta
    where beta.id = beta_link_id
      and beta.submitted_by is distinct from auth.uid()
      and beta.deleted_at is null
      and beta.moderation_status = 'visible'
      and beta.link_status = 'healthy'
  )
);

drop policy beta_comments_user_insert on public.beta_comments;
create policy beta_comments_user_insert on public.beta_comments
for insert to authenticated
with check (
  author_id = auth.uid()
  and public.can_publish(auth.uid())
  and moderation_status = 'visible'
  and deleted_at is null
  and (
    official_gym_id is null
    or public.is_gym_official(official_gym_id)
    or public.is_admin()
  )
);

drop policy logbook_owner_insert on public.logbook_entries;
create policy logbook_owner_insert on public.logbook_entries
for insert to authenticated
with check (user_id = auth.uid() and public.can_interact(auth.uid()));

drop policy grade_votes_attempt_insert on public.route_grade_votes;
create policy grade_votes_attempt_insert on public.route_grade_votes
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.can_interact(auth.uid())
  and is_valid
  and superseded_at is null
  and superseded_by_route_id is null
  and public.has_attempted_route(route_id)
);

drop policy corrections_user_insert on public.route_corrections;
create policy corrections_user_insert on public.route_corrections
for insert to authenticated
with check (
  submitted_by = auth.uid()
  and public.can_publish(auth.uid())
  and status = 'open'
);

drop policy removal_reports_user_insert on public.route_removal_reports;
create policy removal_reports_user_insert on public.route_removal_reports
for insert to authenticated
with check (
  reported_by = auth.uid()
  and public.can_publish(auth.uid())
  and status = 'open'
);

drop policy merge_suggestions_user_insert on public.route_merge_suggestions;
create policy merge_suggestions_user_insert on public.route_merge_suggestions
for insert to authenticated
with check (
  suggested_by = auth.uid()
  and public.can_publish(auth.uid())
  and status = 'proposed'
);

drop policy content_reports_user_insert on public.content_reports;
create policy content_reports_user_insert on public.content_reports
for insert to authenticated
with check (
  reporter_id = auth.uid()
  and public.can_report(auth.uid())
  and status = 'open'
);

drop policy follows_owner_insert on public.user_follows;
create policy follows_owner_insert on public.user_follows
for insert to authenticated
with check (
  follower_id = auth.uid()
  and public.can_interact(auth.uid())
  and not exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = auth.uid() and block.blocked_id = followed_id)
       or (block.blocker_id = followed_id and block.blocked_id = auth.uid())
  )
);

drop policy gym_claims_owner_insert on public.gym_claims;
create policy gym_claims_owner_insert on public.gym_claims
for insert to authenticated
with check (
  applicant_id = auth.uid()
  and public.can_publish(auth.uid())
  and status = 'submitted'
);

create or replace function public.admin_user_summary(target_user_id uuid)
returns table (
  user_id uuid,
  username text,
  member_since timestamptz,
  staff_role text,
  active_restrictions jsonb,
  recent_actions jsonb,
  contribution_counts jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
begin
  if admin_user_summary.target_user_id is null then
    raise exception using errcode = '22023', message = 'invalid user reference';
  end if;

  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = caller_id
      and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
      and roles.revoked_at is null
  ) into is_staff;

  if not is_staff then
    return;
  end if;

  return query
  select
    profiles.id,
    profiles.username::text,
    profiles.created_at,
    (select roles.role::text
     from public.app_user_roles as roles
     where roles.user_id = profiles.id and roles.revoked_at is null
     order by case roles.role when 'admin'::public.app_role then 0 else 1 end
     limit 1),
    (select coalesce(jsonb_agg(row_to_json(r) order by r.created_at desc), '[]'::jsonb)
     from (
       select restrictions.id, restrictions.kind::text as kind,
         restrictions.reason, restrictions.ends_at, restrictions.created_at
       from public.user_restrictions as restrictions
       where restrictions.user_id = profiles.id
         and restrictions.revoked_at is null
         and (restrictions.ends_at is null or restrictions.ends_at > statement_timestamp())
     ) r),
    (select coalesce(jsonb_agg(row_to_json(a) order by a.created_at desc), '[]'::jsonb)
     from (
       select actions.id, actions.action_type::text as action_type,
         actions.reason, actions.created_at
       from public.moderation_actions as actions
       where actions.target_user_id = profiles.id
       order by actions.created_at desc
       limit 20
     ) a),
    (select jsonb_build_object(
      'routes', (select count(*) from public.routes where created_by = profiles.id),
      'route_photos', (select count(*) from public.route_photos where uploaded_by = profiles.id),
      'beta_links', (select count(*) from public.beta_links where submitted_by = profiles.id),
      'reports', (select count(*) from public.content_reports where reporter_id = profiles.id),
      'corrections', (select count(*) from public.route_corrections where submitted_by = profiles.id)
    ))
  from public.profiles as profiles
  where profiles.id = admin_user_summary.target_user_id;
end;
$$;

create or replace function public.admin_apply_user_penalty(
  target_user_id uuid,
  penalty_kind text,
  ends_at timestamptz,
  reason text,
  idempotency_key uuid
)
returns table (
  ok boolean,
  error_code text,
  audit_event_id uuid,
  result jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_is_admin boolean := false;
  clean_reason text := btrim(coalesce(admin_apply_user_penalty.reason, ''));
  penalty public.penalty_kind;
  target_exists boolean := false;
  action_kind public.moderation_action_type;
  action_id uuid;
  restriction_id uuid;
  audit_id uuid;
  prior_audit public.admin_audit_events%rowtype;
begin
  if admin_apply_user_penalty.target_user_id is null
    or admin_apply_user_penalty.penalty_kind is null
    or admin_apply_user_penalty.penalty_kind not in (
      'publishing_restriction', 'timed_suspension', 'permanent_ban'
    )
    or char_length(clean_reason) not between 1 and 2000
    or admin_apply_user_penalty.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid penalty input';
  end if;

  penalty := admin_apply_user_penalty.penalty_kind::public.penalty_kind;

  if penalty = 'timed_suspension'
    and (admin_apply_user_penalty.ends_at is null
      or admin_apply_user_penalty.ends_at <= statement_timestamp())
  then
    raise exception using errcode = '22023', message = 'invalid penalty expiry';
  end if;
  if penalty = 'permanent_ban' and admin_apply_user_penalty.ends_at is not null then
    raise exception using errcode = '22023', message = 'invalid penalty expiry';
  end if;
  if penalty = 'publishing_restriction'
    and admin_apply_user_penalty.ends_at is not null
    and admin_apply_user_penalty.ends_at <= statement_timestamp()
  then
    raise exception using errcode = '22023', message = 'invalid penalty expiry';
  end if;

  select public.is_admin() into actor_is_admin;

  if not actor_is_admin then
    audit_id := private.append_admin_audit(
      actor_id, 'user.penalty.applied', 'user',
      admin_apply_user_penalty.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('kind', penalty, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_apply_user_penalty.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select exists (
    select 1 from auth.users as users
    where users.id = admin_apply_user_penalty.target_user_id
  ) into target_exists;

  if not target_exists then
    audit_id := private.append_admin_audit(
      actor_id, 'user.penalty.applied', 'user',
      admin_apply_user_penalty.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('kind', penalty, 'error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_apply_user_penalty.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_apply_user_penalty.idempotency_key
  order by audit.created_at desc
  limit 1;

  if prior_audit.id is not null then
    return query select
      prior_audit.outcome = 'succeeded',
      (prior_audit.after_summary ->> 'error_code'),
      prior_audit.id,
      coalesce(prior_audit.after_summary -> 'result', '{}'::jsonb);
    return;
  end if;

  if exists (
    select 1 from public.user_restrictions as restrictions
    where restrictions.user_id = admin_apply_user_penalty.target_user_id
      and restrictions.kind = penalty
      and restrictions.revoked_at is null
      and (restrictions.ends_at is null or restrictions.ends_at > statement_timestamp())
  ) then
    audit_id := private.append_admin_audit(
      actor_id, 'user.penalty.applied', 'user',
      admin_apply_user_penalty.target_user_id, clean_reason, 'failed',
      jsonb_build_object('kind', penalty),
      jsonb_build_object('kind', penalty, 'error_code', 'already_active'),
      extensions.gen_random_uuid(), admin_apply_user_penalty.idempotency_key
    );
    return query select false, 'already_active'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  action_kind := case penalty
    when 'publishing_restriction'::public.penalty_kind then 'publishing_restriction'::public.moderation_action_type
    when 'timed_suspension'::public.penalty_kind then 'timed_restriction'::public.moderation_action_type
    else 'permanent_ban'::public.moderation_action_type
  end;

  insert into public.moderation_actions (
    action_type, target_user_id, performed_by, reason, restriction_ends_at
  ) values (
    action_kind, admin_apply_user_penalty.target_user_id, actor_id,
    left(clean_reason, 1000), admin_apply_user_penalty.ends_at
  )
  returning public.moderation_actions.id into action_id;

  insert into public.user_restrictions (
    user_id, kind, reason, ends_at, action_id, created_by
  ) values (
    admin_apply_user_penalty.target_user_id, penalty, left(clean_reason, 1000),
    admin_apply_user_penalty.ends_at, action_id, actor_id
  )
  returning public.user_restrictions.id into restriction_id;

  audit_id := private.append_admin_audit(
    actor_id, 'user.penalty.applied', 'user',
    admin_apply_user_penalty.target_user_id, clean_reason, 'succeeded',
    '{}'::jsonb,
    jsonb_build_object(
      'kind', penalty, 'ends_at', admin_apply_user_penalty.ends_at,
      'restriction_id', restriction_id,
      'result', jsonb_build_object('restriction_id', restriction_id)),
    extensions.gen_random_uuid(), admin_apply_user_penalty.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('restriction_id', restriction_id);
end;
$$;

create or replace function public.admin_reverse_user_penalty(
  penalty_action_id uuid,
  reason text,
  idempotency_key uuid
)
returns table (
  ok boolean,
  error_code text,
  audit_event_id uuid,
  result jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_is_admin boolean := false;
  clean_reason text := btrim(coalesce(admin_reverse_user_penalty.reason, ''));
  original public.moderation_actions%rowtype;
  restriction public.user_restrictions%rowtype;
  reversal_id uuid;
  audit_id uuid;
  prior_audit public.admin_audit_events%rowtype;
begin
  if admin_reverse_user_penalty.penalty_action_id is null
    or char_length(clean_reason) not between 1 and 2000
    or admin_reverse_user_penalty.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid penalty reversal';
  end if;

  select public.is_admin() into actor_is_admin;

  if not actor_is_admin then
    audit_id := private.append_admin_audit(
      actor_id, 'user.penalty.reversed', 'moderation_action',
      admin_reverse_user_penalty.penalty_action_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_reverse_user_penalty.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select actions.* into original
  from public.moderation_actions as actions
  where actions.id = admin_reverse_user_penalty.penalty_action_id
  for update;

  if original.id is null
    or original.action_type not in (
      'publishing_restriction'::public.moderation_action_type,
      'timed_restriction'::public.moderation_action_type,
      'permanent_ban'::public.moderation_action_type
    )
    or not original.reversible
    or original.reversed_by_action_id is not null
  then
    audit_id := private.append_admin_audit(
      actor_id, 'user.penalty.reversed', 'moderation_action',
      admin_reverse_user_penalty.penalty_action_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'invalid_transition'),
      extensions.gen_random_uuid(), admin_reverse_user_penalty.idempotency_key
    );
    return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_reverse_user_penalty.idempotency_key
  order by audit.created_at desc
  limit 1;

  if prior_audit.id is not null then
    return query select
      prior_audit.outcome = 'succeeded',
      (prior_audit.after_summary ->> 'error_code'),
      prior_audit.id,
      coalesce(prior_audit.after_summary -> 'result', '{}'::jsonb);
    return;
  end if;

  select restrictions.* into restriction
  from public.user_restrictions as restrictions
  where restrictions.action_id = original.id
    and restrictions.revoked_at is null
  for update;

  if restriction.id is null then
    audit_id := private.append_admin_audit(
      actor_id, 'user.penalty.reversed', 'moderation_action',
      original.id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'invalid_transition'),
      extensions.gen_random_uuid(), admin_reverse_user_penalty.idempotency_key
    );
    return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  insert into public.moderation_actions (
    action_type, target_user_id, performed_by, reason, reversible,
    metadata
  ) values (
    original.action_type, original.target_user_id, actor_id,
    left(clean_reason, 1000), false,
    jsonb_build_object('reversal_of', original.id)
  )
  returning public.moderation_actions.id into reversal_id;

  update public.moderation_actions
  set reversed_by_action_id = reversal_id
  where id = original.id;

  update public.user_restrictions
  set revoked_at = statement_timestamp(),
      reversed_by_action_id = reversal_id
  where id = restriction.id;

  audit_id := private.append_admin_audit(
    actor_id, 'user.penalty.reversed', 'moderation_action',
    original.id, clean_reason, 'succeeded',
    jsonb_build_object('kind', restriction.kind),
    jsonb_build_object(
      'restriction_id', restriction.id,
      'result', jsonb_build_object('revoked', true)),
    extensions.gen_random_uuid(), admin_reverse_user_penalty.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('restriction_id', restriction.id, 'revoked', true);
end;
$$;

revoke all on function public.has_active_penalty(uuid, public.penalty_kind[]) from public, anon, authenticated, service_role;
revoke all on function public.can_publish(uuid) from public, anon, authenticated, service_role;
grant execute on function public.can_publish(uuid) to authenticated;
revoke all on function public.can_interact(uuid) from public, anon, authenticated, service_role;
grant execute on function public.can_interact(uuid) to authenticated;
revoke all on function public.can_report(uuid) from public, anon, authenticated, service_role;
grant execute on function public.can_report(uuid) to authenticated;

revoke all on function public.admin_user_summary(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_user_summary(uuid)
  to authenticated;

revoke all on function public.admin_apply_user_penalty(uuid, text, timestamptz, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_apply_user_penalty(uuid, text, timestamptz, text, uuid)
  to authenticated;

revoke all on function public.admin_reverse_user_penalty(uuid, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_reverse_user_penalty(uuid, text, uuid)
  to authenticated;

comment on function public.admin_user_summary(uuid) is
  'Staff-only public user summary with active restrictions and moderation history. Never exposes Logbook or emails.';
comment on function public.admin_apply_user_penalty(uuid, text, timestamptz, text, uuid) is
  'Administrator-only penalty application with expiry rules, idempotent audit, and RLS-enforced effect.';
comment on function public.admin_reverse_user_penalty(uuid, text, uuid) is
  'Administrator-only penalty reversal that revokes the canonical restriction and links the history.';
