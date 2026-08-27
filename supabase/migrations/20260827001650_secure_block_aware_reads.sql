-- Stage 6 D-4R: make authenticated public-content reads block-aware at the
-- database boundary. Anonymous discovery remains unchanged; a signed-in user
-- cannot bypass a mutual block through a table, security-invoker view or RPC.

create schema if not exists private;

create index if not exists user_blocks_blocked_blocker_idx
  on public.user_blocks (blocked_id, blocker_id);

create or replace function private.has_block_relationship(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and other_user_id is not null
    and exists (
      select 1
      from public.user_blocks block
      where (block.blocker_id = auth.uid() and block.blocked_id = other_user_id)
         or (block.blocker_id = other_user_id and block.blocked_id = auth.uid())
    );
$$;

create or replace function private.beta_is_blocked(requested_beta_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select private.has_block_relationship(beta.submitted_by)
      from public.beta_links beta
      where beta.id = requested_beta_id
    ),
    false
  );
$$;

create or replace function public.get_my_blocked_profiles()
returns table (
  id uuid,
  username extensions.citext,
  avatar_path text,
  height_cm numeric,
  arm_span_cm numeric,
  regular_grade smallint,
  is_trusted_contributor boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select profile.id, profile.username, profile.avatar_path, profile.height_cm,
         profile.arm_span_cm, profile.regular_grade, profile.is_trusted_contributor
  from public.user_blocks block
  join public.profiles profile on profile.id = block.blocked_id
  where block.blocker_id = auth.uid()
    and profile.deleted_at is null;
$$;

revoke all on function public.get_my_blocked_profiles() from PUBLIC, anon;
grant execute on function public.get_my_blocked_profiles() to authenticated;

revoke all on schema private from PUBLIC, anon, authenticated;
grant usage on schema private to authenticated;
revoke all on function private.has_block_relationship(uuid) from PUBLIC, anon;
revoke all on function private.beta_is_blocked(uuid) from PUBLIC, anon;
grant execute on function private.has_block_relationship(uuid) to authenticated;
grant execute on function private.beta_is_blocked(uuid) to authenticated;

drop policy profiles_public_read on public.profiles;
create policy profiles_anon_read on public.profiles
for select to anon
using (deleted_at is null);
create policy profiles_authenticated_read on public.profiles
for select to authenticated
using (
  deleted_at is null
  and (
    public.is_admin_or_moderator()
    or not private.has_block_relationship(id)
  )
);

drop policy beta_links_public_read on public.beta_links;
create policy beta_links_anon_read on public.beta_links
for select to anon
using (deleted_at is null and moderation_status = 'visible');
create policy beta_links_authenticated_read on public.beta_links
for select to authenticated
using (
  deleted_at is null
  and moderation_status = 'visible'
  and (
    public.is_admin_or_moderator()
    or not private.has_block_relationship(submitted_by)
  )
);

drop policy beta_comments_public_read on public.beta_comments;
create policy beta_comments_anon_read on public.beta_comments
for select to anon
using (deleted_at is null and moderation_status = 'visible');
create policy beta_comments_authenticated_read on public.beta_comments
for select to authenticated
using (
  deleted_at is null
  and moderation_status = 'visible'
  and (
    public.is_admin_or_moderator()
    or (
      not private.has_block_relationship(author_id)
      and not private.beta_is_blocked(beta_link_id)
    )
  )
);

-- A community reset remains private to its submitter while pending. Public
-- discovery continues to expose only confirmed or estimated reset events.
create policy reset_events_owner_pending_read on public.reset_events
for select to authenticated
using (
  deleted_at is null
  and created_by = auth.uid()
);

-- A block in either direction prevents new relationship and interaction rows.
drop policy follows_owner_insert on public.user_follows;
create policy follows_owner_insert on public.user_follows
for insert to authenticated
with check (
  follower_id = auth.uid()
  and follower_id <> followed_id
  and not private.has_block_relationship(followed_id)
);

drop policy beta_helpful_own_insert on public.beta_helpful_votes;
create policy beta_helpful_own_insert on public.beta_helpful_votes
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.beta_links beta
    where beta.id = beta_link_id
      and beta.submitted_by is distinct from auth.uid()
      and not private.has_block_relationship(beta.submitted_by)
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
  and moderation_status = 'visible'
  and deleted_at is null
  and not private.beta_is_blocked(beta_link_id)
  and (
    official_gym_id is null
    or public.is_gym_official(official_gym_id)
    or public.is_admin()
  )
);

create or replace function public.visible_beta_count_for_route(requested_route_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.beta_links beta
  where beta.route_id = requested_route_id
    and beta.deleted_at is null
    and beta.moderation_status = 'visible'
    and (
      auth.uid() is null
      or public.is_admin_or_moderator()
      or not private.has_block_relationship(beta.submitted_by)
    );
$$;

revoke all on function public.visible_beta_count_for_route(uuid) from PUBLIC;
grant execute on function public.visible_beta_count_for_route(uuid) to anon, authenticated;

-- Reassert the intended Data API surface independently from RLS.
revoke all on all functions in schema private from PUBLIC, anon;
grant usage on schema private to authenticated;
grant execute on function private.has_block_relationship(uuid) to authenticated;
grant execute on function private.beta_is_blocked(uuid) to authenticated;

revoke select on public.beta_links from anon;
revoke select on public.beta_ranking_inputs from anon;
grant select on public.profiles, public.beta_links, public.beta_comments to authenticated;
grant select on public.public_profiles, public.beta_ranking_inputs to authenticated;
grant execute on function public.get_my_blocked_profiles() to authenticated;
