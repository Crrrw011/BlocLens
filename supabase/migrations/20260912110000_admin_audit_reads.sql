-- Staff-only audit browsing with bounded ranges, plus 90-day IP retention.
-- Raw source IPs never appear in any read projection or export; after the
-- retention window only a keyed non-reversible digest remains for correlation.

alter table public.admin_audit_events
  add column source_ip inet,
  add column source_ip_digest text;

comment on column public.admin_audit_events.source_ip is
  'Raw source IP, retained at most 90 days. Never exposed to reads or exports.';
comment on column public.admin_audit_events.source_ip_digest is
  'Keyed non-reversible correlation digest that survives IP redaction.';

create table private.admin_audit_ip_pepper (
  id integer primary key default 1,
  pepper text not null default extensions.gen_random_uuid()::text,
  constraint admin_audit_ip_pepper_singleton check (id = 1)
);

insert into private.admin_audit_ip_pepper (id) values (1)
on conflict (id) do nothing;

create or replace function private.redact_expired_admin_audit_ips(cutoff timestamptz)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  pepper text;
  redacted_count integer := 0;
begin
  if cutoff is null then
    raise exception using errcode = '22023', message = 'invalid redaction cutoff';
  end if;

  select admin_audit_ip_pepper.pepper into pepper
  from private.admin_audit_ip_pepper as admin_audit_ip_pepper
  where admin_audit_ip_pepper.id = 1;

  update public.admin_audit_events as events
  set source_ip_digest = 'v1:' || encode(
      extensions.digest(
        events.source_ip::text || '|' || pepper,
        'sha256'
      ),
      'hex'
    ),
      source_ip = null
  where events.created_at < cutoff
    and events.source_ip is not null;

  get diagnostics redacted_count = row_count;
  return redacted_count;
end;
$$;

revoke all on function private.redact_expired_admin_audit_ips(timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function private.redact_expired_admin_audit_ips(timestamptz)
  to service_role;

comment on function private.redact_expired_admin_audit_ips(timestamptz) is
  'Replaces raw audit source IPs older than the cutoff with keyed digests. Cron-only.';

-- Thin service-role entry point for the Vercel Cron route. PostgREST cannot
-- address private-schema routines, so the cutoff lives here, not in the caller.
create or replace function public.run_audit_ip_retention()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  return private.redact_expired_admin_audit_ips(
    statement_timestamp() - interval '90 days'
  );
end;
$$;

revoke all on function public.run_audit_ip_retention()
  from public, anon, authenticated, service_role;
grant execute on function public.run_audit_ip_retention()
  to service_role;

comment on function public.run_audit_ip_retention() is
  'Cron-only 90-day audit IP retention. No caller-controlled parameters.';

create or replace function public.admin_list_audit(
  actor_filter uuid,
  action_filter text,
  target_filter text,
  outcome_filter text,
  range_start timestamptz,
  range_end timestamptz,
  page_after text,
  page_size integer
)
returns table (
  id uuid,
  actor_id uuid,
  action_key text,
  target_type text,
  target_id uuid,
  reason text,
  outcome text,
  before_summary jsonb,
  after_summary jsonb,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  is_staff boolean := false;
  limit_count integer := least(greatest(coalesce(admin_list_audit.page_size, 20), 1), 100);
  cursor_at timestamptz := null;
  cursor_id uuid := null;
begin
  if admin_list_audit.range_start is null
    or admin_list_audit.range_end is null
    or admin_list_audit.range_start >= admin_list_audit.range_end
    or admin_list_audit.range_end - admin_list_audit.range_start > interval '366 days'
  then
    raise exception using errcode = '22023', message = 'invalid audit range';
  end if;

  if admin_list_audit.action_filter is not null
    and admin_list_audit.action_filter !~ '^[a-z0-9_.]{1,80}$'
  then
    raise exception using errcode = '22023', message = 'invalid audit action filter';
  end if;

  if admin_list_audit.outcome_filter is not null
    and admin_list_audit.outcome_filter not in (
      'succeeded', 'rejected', 'partially_failed', 'failed'
    )
  then
    raise exception using errcode = '22023', message = 'invalid audit outcome filter';
  end if;

  if admin_list_audit.page_after is not null then
    begin
      cursor_at := split_part(admin_list_audit.page_after, '|', 1)::timestamptz;
      cursor_id := split_part(admin_list_audit.page_after, '|', 2)::uuid;
    exception when others then
      raise exception using errcode = '22023', message = 'invalid audit page cursor';
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
    events.id,
    events.actor_id,
    events.action_key,
    events.target_type,
    events.target_id,
    events.reason,
    events.outcome,
    events.before_summary,
    events.after_summary,
    events.created_at
  from public.admin_audit_events as events
  where events.created_at >= admin_list_audit.range_start
    and events.created_at < admin_list_audit.range_end
    and (admin_list_audit.actor_filter is null or events.actor_id = admin_list_audit.actor_filter)
    and (admin_list_audit.action_filter is null or events.action_key = admin_list_audit.action_filter)
    and (admin_list_audit.target_filter is null or events.target_type = admin_list_audit.target_filter)
    and (admin_list_audit.outcome_filter is null or events.outcome = admin_list_audit.outcome_filter)
    and (
      cursor_at is null
      or events.created_at < cursor_at
      or (events.created_at = cursor_at and events.id < cursor_id)
    )
  order by events.created_at desc, events.id desc
  limit limit_count + 1;
end;
$$;

revoke all on function public.admin_list_audit(uuid, text, text, text, timestamptz, timestamptz, text, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_list_audit(uuid, text, text, text, timestamptz, timestamptz, text, integer)
  to authenticated;

comment on function public.admin_list_audit(uuid, text, text, text, timestamptz, timestamptz, text, integer) is
  'Staff-only audit browsing with filters and stable cursor pagination. Raw IPs are never returned.';
