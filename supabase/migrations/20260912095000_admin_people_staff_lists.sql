-- Staff-only people search and owner-aware staff administration.
-- Browser roles hold no write grants here; every mutation is a protected
-- function with role revalidation, version checks, and audit events.

create or replace function public.admin_list_users(
  search_text text,
  page_after text,
  page_size integer
)
returns table (
  user_id uuid,
  username text,
  member_since timestamptz,
  staff_role text,
  restriction_kinds text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
  needle text := nullif(btrim(coalesce(admin_list_users.search_text, '')), '');
  limit_count integer := least(greatest(coalesce(admin_list_users.page_size, 20), 1), 100);
  cursor_at timestamptz := null;
  cursor_id uuid := null;
begin
  if admin_list_users.page_after is not null then
    begin
      cursor_at := split_part(admin_list_users.page_after, '|', 1)::timestamptz;
      cursor_id := split_part(admin_list_users.page_after, '|', 2)::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'invalid user page cursor';
    end;
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
    (
      select roles.role::text
      from public.app_user_roles as roles
      where roles.user_id = profiles.id and roles.revoked_at is null
      order by case roles.role when 'admin'::public.app_role then 0 else 1 end
      limit 1
    ),
    coalesce(
      (
        select array_agg(restrictions.kind::text)
        from public.user_restrictions as restrictions
        where restrictions.user_id = profiles.id
          and restrictions.revoked_at is null
          and (restrictions.ends_at is null or restrictions.ends_at > statement_timestamp())
      ),
      '{}'::text[]
    )
  from public.profiles as profiles
  where (needle is null or profiles.username ilike '%' || needle || '%')
    and (cursor_at is null
      or profiles.created_at < cursor_at
      or (profiles.created_at = cursor_at and profiles.id < cursor_id))
  order by profiles.created_at desc, profiles.id desc
  limit limit_count + 1;
end;
$$;

create or replace function public.admin_list_staff()
returns table (
  ok boolean,
  error_code text,
  payload jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_is_admin boolean := false;
begin
  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = caller_id
      and roles.role = 'admin'::public.app_role
      and roles.revoked_at is null
  ) into caller_is_admin;

  if not caller_is_admin then
    return query select false, 'forbidden'::text, null::jsonb;
    return;
  end if;

  return query select true, null::text, jsonb_build_object(
    'staff', (
      select coalesce(jsonb_agg(row_to_json(s) order by s.active desc, s.role, s.username), '[]'::jsonb)
      from (
        select
          roles.user_id,
          profiles.username::text as username,
          roles.role::text as role,
          (roles.revoked_at is null) as active,
          coalesce(capabilities.can_manage_administrators, false) as can_manage_administrators,
          roles.granted_at as since
        from public.app_user_roles as roles
        join public.profiles as profiles on profiles.id = roles.user_id
        left join public.staff_capabilities as capabilities
          on capabilities.user_id = roles.user_id
        where roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
      ) s
    ),
    'invitations', (
      select coalesce(jsonb_agg(row_to_json(i) order by i.created_at desc), '[]'::jsonb)
      from (
        select
          invitations.id,
          invitations.email,
          invitations.role::text as role,
          case
            when invitations.accepted_at is not null then 'accepted'
            when invitations.revoked_at is not null then 'revoked'
            when invitations.expired_at is not null or invitations.expires_at <= statement_timestamp() then 'expired'
            else 'pending'
          end as status,
          invitations.expires_at,
          invitations.invited_by,
          invitations.created_at
        from public.staff_invitations as invitations
      ) i
    )
  );
end;
$$;

create or replace function public.admin_revoke_staff_invitation(
  invitation_id uuid,
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
  clean_reason text := btrim(coalesce(admin_revoke_staff_invitation.reason, ''));
  invitation public.staff_invitations%rowtype;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
begin
  if admin_revoke_staff_invitation.invitation_id is null
    or char_length(clean_reason) not between 1 and 2000
    or admin_revoke_staff_invitation.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid invitation revocation';
  end if;

  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = actor_id
      and roles.role = 'admin'::public.app_role
      and roles.revoked_at is null
  ) into actor_is_admin;

  if not actor_is_admin then
    audit_id := private.append_admin_audit(
      actor_id, 'staff.invitation.revoked', 'staff_invitation',
      admin_revoke_staff_invitation.invitation_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_revoke_staff_invitation.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select invitations.* into invitation
  from public.staff_invitations as invitations
  where invitations.id = admin_revoke_staff_invitation.invitation_id
  for update;

  if invitation.id is null then
    audit_id := private.append_admin_audit(
      actor_id, 'staff.invitation.revoked', 'staff_invitation',
      admin_revoke_staff_invitation.invitation_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_revoke_staff_invitation.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_revoke_staff_invitation.idempotency_key
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

  if invitation.accepted_at is not null
    or invitation.revoked_at is not null
    or invitation.expired_at is not null
    or invitation.expires_at <= statement_timestamp()
  then
    audit_id := private.append_admin_audit(
      actor_id, 'staff.invitation.revoked', 'staff_invitation',
      invitation.id, clean_reason, 'failed',
      jsonb_build_object('status', 'pending'),
      jsonb_build_object('error_code', 'invalid_transition'),
      extensions.gen_random_uuid(), admin_revoke_staff_invitation.idempotency_key
    );
    return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  update public.staff_invitations
  set revoked_at = statement_timestamp(),
      revoked_by = actor_id
  where id = invitation.id;

  audit_id := private.append_admin_audit(
    actor_id, 'staff.invitation.revoked', 'staff_invitation',
    invitation.id, clean_reason, 'succeeded',
    jsonb_build_object('status', 'pending'),
    jsonb_build_object(
      'status', 'revoked',
      'result', jsonb_build_object('status', 'revoked')),
    extensions.gen_random_uuid(), admin_revoke_staff_invitation.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('status', 'revoked');
end;
$$;

create or replace function public.admin_set_staff_active(
  target_user_id uuid,
  make_active boolean,
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
  actor_can_manage boolean := false;
  clean_reason text := btrim(coalesce(admin_set_staff_active.reason, ''));
  target_roles public.app_user_roles[] := '{}';
  target_is_admin boolean := false;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
  action_key text;
begin
  if admin_set_staff_active.target_user_id is null
    or admin_set_staff_active.make_active is null
    or char_length(clean_reason) not between 1 and 2000
    or admin_set_staff_active.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid staff access change';
  end if;

  select exists (
    select 1
    from public.app_user_roles as roles
    where roles.user_id = actor_id
      and roles.role = 'admin'::public.app_role
      and roles.revoked_at is null
  ) into actor_is_admin;

  if not actor_is_admin then
    audit_id := private.append_admin_audit(
      actor_id, 'staff.access.changed', 'staff_access',
      admin_set_staff_active.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_set_staff_active.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if admin_set_staff_active.target_user_id = actor_id then
    audit_id := private.append_admin_audit(
      actor_id, 'staff.access.changed', 'staff_access',
      admin_set_staff_active.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'invalid'),
      extensions.gen_random_uuid(), admin_set_staff_active.idempotency_key
    );
    return query select false, 'invalid'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  -- Lock the target rows first, then snapshot them (no aggregates with FOR UPDATE).
  perform 1
  from public.app_user_roles as roles
  where roles.user_id = admin_set_staff_active.target_user_id
    and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role)
  for update;

  select array_agg(roles) into target_roles
  from public.app_user_roles as roles
  where roles.user_id = admin_set_staff_active.target_user_id
    and roles.role in ('admin'::public.app_role, 'moderator'::public.app_role);

  if target_roles is null or coalesce(array_length(target_roles, 1), 0) = 0 then
    audit_id := private.append_admin_audit(
      actor_id, 'staff.access.changed', 'staff_access',
      admin_set_staff_active.target_user_id, clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_set_staff_active.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select bool_or((r).role = 'admin'::public.app_role) into target_is_admin
  from unnest(target_roles) as r;

  if target_is_admin then
    select coalesce(capabilities.can_manage_administrators, false)
    into actor_can_manage
    from public.staff_capabilities as capabilities
    where capabilities.user_id = actor_id;

    if not coalesce(actor_can_manage, false) then
      audit_id := private.append_admin_audit(
        actor_id, 'staff.access.changed', 'staff_access',
        admin_set_staff_active.target_user_id, clean_reason, 'failed',
        '{}'::jsonb,
        jsonb_build_object('error_code', 'forbidden'),
        extensions.gen_random_uuid(), admin_set_staff_active.idempotency_key
      );
      return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
      return;
    end if;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_set_staff_active.idempotency_key
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

  action_key := case when admin_set_staff_active.make_active
    then 'staff.access.reactivated' else 'staff.access.deactivated' end;

  if admin_set_staff_active.make_active then
    if not exists (
      select 1 from unnest(target_roles) as r where (r).revoked_at is not null
    ) then
      audit_id := private.append_admin_audit(
        actor_id, action_key, 'staff_access',
        admin_set_staff_active.target_user_id, clean_reason, 'failed',
        jsonb_build_object('status', 'active'),
        jsonb_build_object('error_code', 'invalid_transition'),
        extensions.gen_random_uuid(), admin_set_staff_active.idempotency_key
      );
      return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
      return;
    end if;

    update public.app_user_roles
    set revoked_at = null
    where user_id = admin_set_staff_active.target_user_id
      and role in ('admin'::public.app_role, 'moderator'::public.app_role)
      and revoked_at is not null;
  else
    if not exists (
      select 1 from unnest(target_roles) as r where (r).revoked_at is null
    ) then
      audit_id := private.append_admin_audit(
        actor_id, action_key, 'staff_access',
        admin_set_staff_active.target_user_id, clean_reason, 'failed',
        jsonb_build_object('status', 'inactive'),
        jsonb_build_object('error_code', 'invalid_transition'),
        extensions.gen_random_uuid(), admin_set_staff_active.idempotency_key
      );
      return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
      return;
    end if;

    update public.app_user_roles
    set revoked_at = statement_timestamp()
    where user_id = admin_set_staff_active.target_user_id
      and role in ('admin'::public.app_role, 'moderator'::public.app_role)
      and revoked_at is null;
  end if;

  audit_id := private.append_admin_audit(
    actor_id, action_key, 'staff_access',
    admin_set_staff_active.target_user_id, clean_reason, 'succeeded',
    '{}'::jsonb,
    jsonb_build_object(
      'active', admin_set_staff_active.make_active,
      'result', jsonb_build_object('active', admin_set_staff_active.make_active)),
    extensions.gen_random_uuid(), admin_set_staff_active.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('active', admin_set_staff_active.make_active);
end;
$$;

revoke all on function public.admin_list_users(text, text, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_list_users(text, text, integer)
  to authenticated;

revoke all on function public.admin_list_staff()
  from public, anon, authenticated, service_role;
grant execute on function public.admin_list_staff()
  to authenticated;

revoke all on function public.admin_revoke_staff_invitation(uuid, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_revoke_staff_invitation(uuid, text, uuid)
  to authenticated;

revoke all on function public.admin_set_staff_active(uuid, boolean, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_set_staff_active(uuid, boolean, text, uuid)
  to authenticated;

comment on function public.admin_list_users(text, text, integer) is
  'Staff-only paginated people search with roles and active restriction kinds. No emails or Logbook.';
comment on function public.admin_list_staff() is
  'Administrator-only staff roster with capabilities and invitation states. Digests never leave the database.';
comment on function public.admin_revoke_staff_invitation(uuid, text, uuid) is
  'Administrator-only invitation revocation with idempotent audit.';
comment on function public.admin_set_staff_active(uuid, boolean, text, uuid) is
  'Owner-aware staff deactivation and reactivation. Self-changes are refused.';
