-- Closed staff invitation creation and single-use acceptance.

alter table public.staff_invitations
  add column expired_at timestamptz;

alter table public.staff_invitations
  drop constraint staff_invitations_single_terminal_state,
  add constraint staff_invitations_single_terminal_state check (
    num_nonnulls(accepted_at, revoked_at, expired_at) <= 1
  ),
  add constraint staff_invitations_expiry_terminal_consistent check (
    expired_at is null or expired_at >= expires_at
  );

drop index public.staff_invitations_one_pending_email_idx;

create unique index staff_invitations_one_pending_email_idx
  on public.staff_invitations (lower(btrim(email)))
  where accepted_at is null
    and revoked_at is null
    and expired_at is null;

grant select (expired_at) on table public.staff_invitations to authenticated;

create or replace function public.create_staff_invitation(
  email text,
  role public.app_role,
  token_digest bytea,
  expires_at timestamptz,
  reason text
)
returns table (
  invitation_id uuid,
  invitation_created boolean,
  result_status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_role public.app_user_roles%rowtype;
  actor_can_manage_administrators boolean := false;
  normalized_email text := lower(btrim(create_staff_invitation.email));
  operation_time timestamptz := statement_timestamp();
  attempted_invitation_id uuid := extensions.gen_random_uuid();
  existing_invitation public.staff_invitations%rowtype;
  expired_invitation public.staff_invitations%rowtype;
begin
  if normalized_email is null
    or create_staff_invitation.role is null
    or create_staff_invitation.token_digest is null
    or create_staff_invitation.expires_at is null
    or create_staff_invitation.reason is null
    or char_length(normalized_email) not between 3 and 320
    or position('@' in normalized_email) <= 1
    or octet_length(create_staff_invitation.token_digest) <> 32
    or create_staff_invitation.expires_at <= operation_time
    or char_length(btrim(create_staff_invitation.reason)) not between 1 and 2000
  then
    raise exception using
      errcode = '22023',
      message = 'invalid staff invitation input';
  end if;

  select roles.*
  into actor_role
  from public.app_user_roles as roles
  where roles.user_id = actor_id
    and roles.role = 'admin'::public.app_role
  for share;

  if actor_role.user_id is not null and actor_role.revoked_at is null then
    select coalesce(capabilities.can_manage_administrators, false)
    into actor_can_manage_administrators
    from public.staff_capabilities as capabilities
    where capabilities.user_id = actor_id
    for share;
  end if;

  actor_can_manage_administrators := coalesce(
    actor_can_manage_administrators,
    false
  );

  if actor_role.user_id is null
    or actor_role.revoked_at is not null
    or (
      create_staff_invitation.role = 'admin'::public.app_role
      and not actor_can_manage_administrators
    )
  then
    perform private.append_admin_audit(
      actor_id,
      'staff.invitation.create_rejected',
      'staff_invitation',
      attempted_invitation_id,
      btrim(create_staff_invitation.reason),
      'failed',
      '{}'::jsonb,
      jsonb_build_object(
        'role', create_staff_invitation.role,
        'status', 'forbidden'
      ),
      extensions.gen_random_uuid(),
      extensions.gen_random_uuid()
    );

    return query
      select attempted_invitation_id, false, 'forbidden'::text;
    return;
  end if;

  -- Serialize invitation replacement for a normalized email. The unique index
  -- predicate intentionally contains no volatile time expression.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(normalized_email, 0)
  );

  for expired_invitation in
    update public.staff_invitations as invitations
    set expired_at = operation_time
    where lower(btrim(invitations.email)) = normalized_email
      and invitations.accepted_at is null
      and invitations.revoked_at is null
      and invitations.expired_at is null
      and invitations.expires_at <= operation_time
    returning invitations.*
  loop
    perform private.append_admin_audit(
      actor_id,
      'staff.invitation.expired',
      'staff_invitation',
      expired_invitation.id,
      'Invitation expired before replacement',
      'succeeded',
      jsonb_build_object('status', 'pending'),
      jsonb_build_object(
        'role', expired_invitation.role,
        'status', 'expired'
      ),
      extensions.gen_random_uuid(),
      extensions.gen_random_uuid()
    );
  end loop;

  select invitations.*
  into existing_invitation
  from public.staff_invitations as invitations
  where lower(btrim(invitations.email)) = normalized_email
    and invitations.accepted_at is null
    and invitations.revoked_at is null
    and invitations.expired_at is null
  for update;

  if existing_invitation.id is not null then
    perform private.append_admin_audit(
      actor_id,
      'staff.invitation.create_rejected',
      'staff_invitation',
      existing_invitation.id,
      btrim(create_staff_invitation.reason),
      'failed',
      jsonb_build_object('status', 'pending'),
      jsonb_build_object(
        'role', existing_invitation.role,
        'status', 'already_pending'
      ),
      extensions.gen_random_uuid(),
      extensions.gen_random_uuid()
    );

    return query
      select existing_invitation.id, false, 'already_pending'::text;
    return;
  end if;

  insert into public.staff_invitations (
    id,
    email,
    role,
    token_digest,
    invited_by,
    created_at,
    expires_at
  ) values (
    attempted_invitation_id,
    normalized_email,
    create_staff_invitation.role,
    create_staff_invitation.token_digest,
    actor_id,
    operation_time,
    create_staff_invitation.expires_at
  );

  perform private.append_admin_audit(
    actor_id,
    'staff.invitation.created',
    'staff_invitation',
    attempted_invitation_id,
    btrim(create_staff_invitation.reason),
    'succeeded',
    '{}'::jsonb,
    jsonb_build_object(
      'role', create_staff_invitation.role,
      'status', 'pending',
      'expires_at', create_staff_invitation.expires_at
    ),
    extensions.gen_random_uuid(),
    extensions.gen_random_uuid()
  );

  return query
    select attempted_invitation_id, true, 'created'::text;
end;
$$;

create or replace function public.accept_staff_invitation(token_digest bytea)
returns table (
  invitation_id uuid,
  invitation_accepted boolean,
  assigned_role public.app_role,
  result_status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  accepting_user_id uuid := (select auth.uid());
  accepting_email text;
  operation_time timestamptz := statement_timestamp();
  invitation public.staff_invitations%rowtype;
  inviter_role public.app_user_roles%rowtype;
  inviter_can_manage_administrators boolean := false;
  rejection_status text;
begin
  if accepting_user_id is null
    or accept_staff_invitation.token_digest is null
    or octet_length(accept_staff_invitation.token_digest) <> 32
  then
    return query
      select null::uuid, false, null::public.app_role, 'invalid'::text;
    return;
  end if;

  select lower(btrim(users.email))
  into accepting_email
  from auth.users as users
  where users.id = accepting_user_id
    and users.email_confirmed_at is not null;

  select invitations.*
  into invitation
  from public.staff_invitations as invitations
  where invitations.token_digest = accept_staff_invitation.token_digest
  for update;

  if invitation.id is null or accepting_email is null then
    return query
      select null::uuid, false, null::public.app_role, 'invalid'::text;
    return;
  end if;

  if invitation.accepted_at is not null then
    rejection_status := 'already_accepted';
  elsif invitation.revoked_at is not null then
    rejection_status := 'revoked';
  elsif invitation.expired_at is not null then
    rejection_status := 'expired';
  elsif invitation.expires_at <= operation_time then
    update public.staff_invitations as invitations
    set expired_at = operation_time
    where invitations.id = invitation.id;

    perform private.append_admin_audit(
      accepting_user_id,
      'staff.invitation.expired',
      'staff_invitation',
      invitation.id,
      'Invitation expired before acceptance',
      'succeeded',
      jsonb_build_object('status', 'pending'),
      jsonb_build_object(
        'role', invitation.role,
        'status', 'expired'
      ),
      extensions.gen_random_uuid(),
      extensions.gen_random_uuid()
    );

    rejection_status := 'expired';
  elsif lower(btrim(invitation.email)) <> accepting_email then
    rejection_status := 'email_mismatch';
  end if;

  if rejection_status is not null then
    perform private.append_admin_audit(
      accepting_user_id,
      'staff.invitation.acceptance_rejected',
      'staff_invitation',
      invitation.id,
      'Invitation could not be accepted',
      'failed',
      jsonb_build_object('status', 'pending'),
      jsonb_build_object(
        'role', invitation.role,
        'status', rejection_status
      ),
      extensions.gen_random_uuid(),
      extensions.gen_random_uuid()
    );

    return query
      select invitation.id, false, invitation.role, rejection_status;
    return;
  end if;

  -- Lock and revalidate the inviter authority that made this exact role grant
  -- permissible. A concurrent revocation cannot race the assignment.
  select roles.*
  into inviter_role
  from public.app_user_roles as roles
  where roles.user_id = invitation.invited_by
    and roles.role = 'admin'::public.app_role
  for share;

  if inviter_role.user_id is not null and inviter_role.revoked_at is null then
    select coalesce(capabilities.can_manage_administrators, false)
    into inviter_can_manage_administrators
    from public.staff_capabilities as capabilities
    where capabilities.user_id = invitation.invited_by
    for share;
  end if;

  inviter_can_manage_administrators := coalesce(
    inviter_can_manage_administrators,
    false
  );

  if inviter_role.user_id is null
    or inviter_role.revoked_at is not null
    or (
      invitation.role = 'admin'::public.app_role
      and not inviter_can_manage_administrators
    )
  then
    perform private.append_admin_audit(
      accepting_user_id,
      'staff.invitation.acceptance_rejected',
      'staff_invitation',
      invitation.id,
      'Invitation issuer is no longer authorized',
      'failed',
      jsonb_build_object('status', 'pending'),
      jsonb_build_object(
        'role', invitation.role,
        'status', 'inviter_not_authorized'
      ),
      extensions.gen_random_uuid(),
      extensions.gen_random_uuid()
    );

    return query
      select invitation.id, false, invitation.role, 'inviter_not_authorized'::text;
    return;
  end if;

  insert into public.app_user_roles (
    user_id,
    role,
    granted_by,
    granted_at,
    revoked_at
  ) values (
    accepting_user_id,
    invitation.role,
    invitation.invited_by,
    operation_time,
    null
  )
  on conflict (user_id, role) do update
  set granted_by = excluded.granted_by,
      granted_at = excluded.granted_at,
      revoked_at = null;

  update public.staff_invitations as invitations
  set accepted_at = operation_time,
      accepted_by = accepting_user_id
  where invitations.id = invitation.id;

  perform private.append_admin_audit(
    accepting_user_id,
    'staff.invitation.accepted',
    'staff_invitation',
    invitation.id,
    'Staff invitation accepted',
    'succeeded',
    jsonb_build_object('status', 'pending'),
    jsonb_build_object(
      'role', invitation.role,
      'status', 'accepted'
    ),
    extensions.gen_random_uuid(),
    extensions.gen_random_uuid()
  );

  perform private.append_admin_audit(
    accepting_user_id,
    'staff.role.assigned',
    'staff_access',
    accepting_user_id,
    'Staff role assigned from an accepted invitation',
    'succeeded',
    '{}'::jsonb,
    jsonb_build_object(
      'role', invitation.role,
      'status', 'active'
    ),
    extensions.gen_random_uuid(),
    extensions.gen_random_uuid()
  );

  return query
    select invitation.id, true, invitation.role, 'accepted'::text;
end;
$$;

revoke all on function public.create_staff_invitation(
  text, public.app_role, bytea, timestamptz, text
) from public, anon, authenticated, service_role;
grant execute on function public.create_staff_invitation(
  text, public.app_role, bytea, timestamptz, text
) to authenticated;

revoke all on function public.accept_staff_invitation(bytea)
  from public, anon, authenticated, service_role;
grant execute on function public.accept_staff_invitation(bytea)
  to authenticated;

comment on column public.staff_invitations.expired_at is
  'Stored terminal expiry marker used before replacement; time is never part of the unique-index predicate.';
comment on function public.create_staff_invitation(
  text, public.app_role, bytea, timestamptz, text
) is
  'Creates a digest-only invitation after locking and revalidating the active Administrator authority.';
comment on function public.accept_staff_invitation(bytea) is
  'Consumes one invitation and activates its permitted role after identity and inviter-authority revalidation.';
