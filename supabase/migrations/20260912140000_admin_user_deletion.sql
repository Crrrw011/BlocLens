-- Administrative user deletion: ban, scrub, and revoke without touching auth rows.
-- The auth.users row is retained so foreign keys never break; the profile is
-- scrubbed, app/gym roles are revoked, and a permanent ban locks the account
-- out of publishing, interaction, and reporting through existing RLS.
-- Staff accounts are protected: revoke the staff role first, then delete.

create or replace function public.admin_delete_user(
  target_user_id uuid,
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
  clean_reason text := btrim(coalesce(admin_delete_user.reason, ''));
  target_exists boolean := false;
  is_staff boolean := false;
  already_deleted boolean := false;
  action_id uuid;
  restriction_id uuid;
  audit_id uuid;
  prior_audit public.admin_audit_events%rowtype;
begin
  if admin_delete_user.target_user_id is null
    or char_length(clean_reason) not between 1 and 2000
    or admin_delete_user.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid user deletion';
  end if;

  select public.is_admin() into actor_is_admin;

  if not actor_is_admin then
    audit_id := private.append_admin_audit(
      actor_id, 'user.deleted', 'user',
      admin_delete_user.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_delete_user.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select exists (
    select 1 from auth.users as users
    where users.id = admin_delete_user.target_user_id
  ) into target_exists;

  if not target_exists then
    audit_id := private.append_admin_audit(
      actor_id, 'user.deleted', 'user',
      admin_delete_user.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_delete_user.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if admin_delete_user.target_user_id = actor_id then
    audit_id := private.append_admin_audit(
      actor_id, 'user.deleted', 'user',
      admin_delete_user.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'self_delete'),
      extensions.gen_random_uuid(), admin_delete_user.idempotency_key
    );
    return query select false, 'self_delete'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select exists (
    select 1 from public.app_user_roles as roles
    where roles.user_id = admin_delete_user.target_user_id
      and roles.revoked_at is null
  ) into is_staff;

  if is_staff then
    audit_id := private.append_admin_audit(
      actor_id, 'user.deleted', 'user',
      admin_delete_user.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'staff_protected'),
      extensions.gen_random_uuid(), admin_delete_user.idempotency_key
    );
    return query select false, 'staff_protected'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_delete_user.idempotency_key
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

  select exists (
    select 1 from public.profiles as profile
    where profile.id = admin_delete_user.target_user_id
      and profile.deleted_at is not null
  ) into already_deleted;

  if not already_deleted then
    insert into public.moderation_actions (
      action_type, target_user_id, performed_by, reason, restriction_ends_at
    ) values (
      'permanent_ban'::public.moderation_action_type,
      admin_delete_user.target_user_id, actor_id,
      left(clean_reason, 1000), null
    )
    returning public.moderation_actions.id into action_id;

    insert into public.user_restrictions (
      user_id, kind, reason, ends_at, action_id, created_by
    )
    select
      admin_delete_user.target_user_id, 'permanent_ban'::public.penalty_kind,
      left(clean_reason, 1000), null, action_id, actor_id
    where not public.has_active_penalty(
      admin_delete_user.target_user_id,
      array['permanent_ban'::public.penalty_kind]
    )
    returning public.user_restrictions.id into restriction_id;

    update public.app_user_roles as roles
    set revoked_at = statement_timestamp()
    where roles.user_id = admin_delete_user.target_user_id
      and roles.revoked_at is null;

    update public.gym_memberships as memberships
    set revoked_at = statement_timestamp()
    where memberships.user_id = admin_delete_user.target_user_id
      and memberships.revoked_at is null;

    update public.profiles as profile
    set username = ('deleted_' || substring(replace(admin_delete_user.target_user_id::text, '-', ''), 1, 8))::extensions.citext,
        avatar_path = null,
        height_cm = null,
        arm_span_cm = null,
        regular_grade = null,
        favourite_gym_id = null,
        is_trusted_contributor = false,
        trusted_contributor_awarded_at = null,
        deleted_at = statement_timestamp()
    where profile.id = admin_delete_user.target_user_id;
  end if;

  audit_id := private.append_admin_audit(
    actor_id, 'user.deleted', 'user',
    admin_delete_user.target_user_id, clean_reason, 'succeeded',
    '{}'::jsonb,
    jsonb_build_object(
      'restriction_id', restriction_id,
      'result', jsonb_build_object('deleted', true)),
    extensions.gen_random_uuid(), admin_delete_user.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('deleted', true);
end;
$$;

revoke all on function public.admin_delete_user(uuid, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_delete_user(uuid, text, uuid)
  to authenticated;

comment on function public.admin_delete_user(uuid, text, uuid) is
  'Administrator-only account removal: permanent ban, profile scrub, and role revocation. The auth row is retained; staff accounts are protected.';
