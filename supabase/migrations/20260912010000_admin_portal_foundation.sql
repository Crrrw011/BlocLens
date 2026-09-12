-- Administrator portal staff capabilities, invitations, and append-only audit primitives.

create table public.staff_capabilities (
  user_id uuid primary key references auth.users(id) on delete cascade,
  can_manage_administrators boolean not null default false,
  granted_by uuid not null references auth.users(id) on delete restrict,
  granted_at timestamptz not null default now()
);

create index staff_capabilities_granted_by_idx
  on public.staff_capabilities (granted_by);

create table public.staff_invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  email text not null,
  role public.app_role not null,
  token_digest bytea not null unique,
  invited_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete restrict,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete restrict,
  constraint staff_invitations_email_valid check (
    char_length(btrim(email)) between 3 and 320
    and position('@' in email) > 1
  ),
  constraint staff_invitations_token_digest_sha256 check (
    octet_length(token_digest) = 32
  ),
  constraint staff_invitations_expiry_after_creation check (
    expires_at > created_at
  ),
  constraint staff_invitations_acceptance_consistent check (
    (accepted_at is null and accepted_by is null)
    or (accepted_at is not null and accepted_by is not null)
  ),
  constraint staff_invitations_revocation_consistent check (
    (revoked_at is null and revoked_by is null)
    or (revoked_at is not null and revoked_by is not null)
  ),
  constraint staff_invitations_single_terminal_state check (
    accepted_at is null or revoked_at is null
  )
);

create unique index staff_invitations_one_pending_email_idx
  on public.staff_invitations (lower(btrim(email)))
  where accepted_at is null and revoked_at is null;

create index staff_invitations_pending_expiry_idx
  on public.staff_invitations (expires_at)
  where accepted_at is null and revoked_at is null;

create index staff_invitations_invited_by_idx
  on public.staff_invitations (invited_by);

create index staff_invitations_accepted_by_idx
  on public.staff_invitations (accepted_by)
  where accepted_by is not null;

create index staff_invitations_revoked_by_idx
  on public.staff_invitations (revoked_by)
  where revoked_by is not null;

create table public.admin_audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_id uuid not null,
  action_key text not null,
  target_type text not null,
  target_id uuid not null,
  reason text not null,
  outcome text not null,
  before_summary jsonb not null default '{}'::jsonb,
  after_summary jsonb not null default '{}'::jsonb,
  correlation_id uuid not null,
  idempotency_key uuid not null unique,
  created_at timestamptz not null default now(),
  constraint admin_audit_events_action_key_valid check (
    char_length(btrim(action_key)) between 1 and 100
  ),
  constraint admin_audit_events_target_type_valid check (
    char_length(btrim(target_type)) between 1 and 100
  ),
  constraint admin_audit_events_reason_valid check (
    char_length(btrim(reason)) between 1 and 2000
  ),
  constraint admin_audit_events_outcome_valid check (
    char_length(btrim(outcome)) between 1 and 100
  ),
  constraint admin_audit_events_before_summary_object check (
    jsonb_typeof(before_summary) = 'object'
  ),
  constraint admin_audit_events_after_summary_object check (
    jsonb_typeof(after_summary) = 'object'
  ),
  constraint admin_audit_events_before_summary_size check (
    octet_length(before_summary::text) <= 16384
  ),
  constraint admin_audit_events_after_summary_size check (
    octet_length(after_summary::text) <= 16384
  )
);

-- Actor identifiers deliberately remain as immutable UUID values rather than a
-- foreign key so account deletion cannot erase or block retained audit history.
create index admin_audit_events_actor_created_idx
  on public.admin_audit_events (actor_id, created_at desc);

create index admin_audit_events_target_created_idx
  on public.admin_audit_events (target_type, target_id, created_at desc);

create index admin_audit_events_correlation_id_idx
  on public.admin_audit_events (correlation_id);

create or replace function public.current_staff_access()
returns table (
  user_id uuid,
  role public.app_role,
  can_manage_administrators boolean,
  is_active boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    selected_role.user_id,
    selected_role.role,
    (
      selected_role.role = 'admin'::public.app_role
      and selected_role.revoked_at is null
      and coalesce(capability.can_manage_administrators, false)
    ) as can_manage_administrators,
    selected_role.revoked_at is null as is_active
  from (
    select roles.user_id, roles.role, roles.revoked_at
    from public.app_user_roles as roles
    where roles.user_id = (select auth.uid())
    order by
      (roles.revoked_at is null) desc,
      case roles.role
        when 'admin'::public.app_role then 0
        else 1
      end,
      roles.granted_at desc
    limit 1
  ) as selected_role
  left join public.staff_capabilities as capability
    on capability.user_id = selected_role.user_id;
$$;

create or replace function private.append_admin_audit(
  actor_id uuid,
  action_key text,
  target_type text,
  target_id uuid,
  reason text,
  outcome text,
  before_summary jsonb,
  after_summary jsonb,
  correlation_id uuid,
  idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_id uuid;
begin
  insert into public.admin_audit_events (
    actor_id,
    action_key,
    target_type,
    target_id,
    reason,
    outcome,
    before_summary,
    after_summary,
    correlation_id,
    idempotency_key
  ) values (
    actor_id,
    action_key,
    target_type,
    target_id,
    reason,
    outcome,
    coalesce(before_summary, '{}'::jsonb),
    coalesce(after_summary, '{}'::jsonb),
    correlation_id,
    idempotency_key
  )
  on conflict on constraint admin_audit_events_idempotency_key_key do nothing
  returning id into event_id;

  if event_id is null then
    select audit.id
    into event_id
    from public.admin_audit_events as audit
    where audit.idempotency_key = append_admin_audit.idempotency_key;
  end if;

  return event_id;
end;
$$;

alter table public.staff_capabilities enable row level security;
alter table public.staff_invitations enable row level security;
alter table public.admin_audit_events enable row level security;

create policy staff_capabilities_own_active_read
on public.staff_capabilities
for select
to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_admin_or_moderator())
);

create policy staff_invitations_active_admin_read
on public.staff_invitations
for select
to authenticated
using ((select public.is_admin()));

create policy admin_audit_events_active_staff_read
on public.admin_audit_events
for select
to authenticated
using ((select public.is_admin_or_moderator()));

revoke all on table public.staff_capabilities from public, anon, authenticated;
revoke all on table public.staff_invitations from public, anon, authenticated;
revoke all on table public.admin_audit_events from public, anon, authenticated;

grant select on table public.staff_capabilities to authenticated;
grant select (
  id,
  email,
  role,
  invited_by,
  created_at,
  expires_at,
  accepted_at,
  accepted_by,
  revoked_at,
  revoked_by
) on table public.staff_invitations to authenticated;
grant select on table public.admin_audit_events to authenticated;

revoke all on function public.current_staff_access() from public, anon, authenticated, service_role;
grant execute on function public.current_staff_access() to authenticated;

revoke all on function private.append_admin_audit(
  uuid, text, text, uuid, text, text, jsonb, jsonb, uuid, uuid
) from public, anon, authenticated, service_role;

comment on table public.staff_capabilities is
  'Server-controlled staff capabilities that extend, but never replace, app_user_roles.';
comment on column public.staff_invitations.token_digest is
  'A 32-byte SHA-256 digest. Raw invitation tokens must never be stored.';
comment on table public.admin_audit_events is
  'Append-only portal audit history. Browser roles receive SELECT only through staff RLS.';
comment on function public.current_staff_access() is
  'Returns the caller staff role, owner capability, and current revocation state.';
comment on function private.append_admin_audit(
  uuid, text, text, uuid, text, text, jsonb, jsonb, uuid, uuid
) is
  'Protected idempotent audit append helper callable only inside trusted database functions.';
