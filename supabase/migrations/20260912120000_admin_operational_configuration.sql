-- Allow-listed operational configuration with optimistic versioning.
-- Product rules (grade math, trust thresholds, privacy defaults) are not
-- configurable: unknown or frozen keys raise instead of being stored.

create table public.operational_configuration (
  key text primary key,
  value jsonb not null,
  version integer not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint operational_configuration_version_positive check (version >= 1)
);

alter table public.operational_configuration enable row level security;

insert into public.operational_configuration (key, value) values
  ('review.queue.order', '"newest_first"'),
  ('overview.default_range', '"30d"'),
  ('flags.moderation_notes', 'true'),
  ('copy.reason_templates', '["Spam pattern confirmed", "Verified against the wall", "Duplicate confirmed"]')
on conflict (key) do nothing;

comment on table public.operational_configuration is
  'Allow-listed portal configuration. Only the seeded keys are writable, and only by Administrators.';

create or replace function public.admin_update_configuration(
  config_key text,
  config_value jsonb,
  reason text,
  expected_version integer,
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
  clean_reason text := btrim(coalesce(admin_update_configuration.reason, ''));
  current_version integer := null;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
begin
  if admin_update_configuration.config_key is null
    or admin_update_configuration.config_value is null
    or jsonb_typeof(admin_update_configuration.config_value) = 'null'
    or char_length(clean_reason) not between 1 and 2000
    or admin_update_configuration.expected_version is null
    or admin_update_configuration.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid configuration update';
  end if;

  -- Allow list with typed values. Everything else, including grade math,
  -- trust thresholds, and privacy defaults, is a frozen product rule.
  case admin_update_configuration.config_key
    when 'review.queue.order' then
      if jsonb_typeof(config_value) <> 'string'
        or config_value #>> '{}' not in ('newest_first', 'oldest_first', 'severity_first')
      then
        raise exception using errcode = '22023', message = 'invalid configuration value';
      end if;
    when 'overview.default_range' then
      if jsonb_typeof(config_value) <> 'string'
        or config_value #>> '{}' not in ('7d', '30d', '90d')
      then
        raise exception using errcode = '22023', message = 'invalid configuration value';
      end if;
    when 'flags.moderation_notes' then
      if jsonb_typeof(config_value) <> 'boolean' then
        raise exception using errcode = '22023', message = 'invalid configuration value';
      end if;
    when 'copy.reason_templates' then
      if jsonb_typeof(config_value) <> 'array'
        or (select count(*) from jsonb_array_elements_text(config_value)) not between 1 and 10
        or exists (
          select 1 from jsonb_array_elements_text(config_value) as template
          where jsonb_typeof(to_jsonb(template)) <> 'string'
            or char_length(template) not between 1 and 200
        )
      then
        raise exception using errcode = '22023', message = 'invalid configuration value';
      end if;
    else
      raise exception using errcode = '22023', message = 'unknown configuration key';
  end case;

  select public.is_admin() into actor_is_admin;

  if not actor_is_admin then
    audit_id := private.append_admin_audit(
      actor_id, 'config.updated', 'configuration',
      '00000000-0000-0000-0000-000000000000', clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('key', admin_update_configuration.config_key, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_update_configuration.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select configuration.version into current_version
  from public.operational_configuration as configuration
  where configuration.key = admin_update_configuration.config_key
  for update;

  if current_version is null then
    audit_id := private.append_admin_audit(
      actor_id, 'config.updated', 'configuration',
      '00000000-0000-0000-0000-000000000000', clean_reason, 'failed',
      '{}'::jsonb,
      jsonb_build_object('key', admin_update_configuration.config_key, 'error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_update_configuration.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_update_configuration.idempotency_key
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

  if current_version is distinct from admin_update_configuration.expected_version then
    audit_id := private.append_admin_audit(
      actor_id, 'config.updated', 'configuration',
      '00000000-0000-0000-0000-000000000000', clean_reason, 'failed',
      jsonb_build_object('version', current_version),
      jsonb_build_object(
        'key', admin_update_configuration.config_key, 'error_code', 'conflict'),
      extensions.gen_random_uuid(), admin_update_configuration.idempotency_key
    );
    return query select false, 'conflict'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  update public.operational_configuration
  set value = admin_update_configuration.config_value,
      version = current_version + 1,
      updated_by = actor_id,
      updated_at = statement_timestamp()
  where key = admin_update_configuration.config_key;

  audit_id := private.append_admin_audit(
    actor_id, 'config.updated', 'configuration',
    '00000000-0000-0000-0000-000000000000', clean_reason, 'succeeded',
    jsonb_build_object('version', current_version),
    jsonb_build_object(
      'key', admin_update_configuration.config_key,
      'version', current_version + 1,
      'result', jsonb_build_object('version', current_version + 1)),
    extensions.gen_random_uuid(), admin_update_configuration.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('version', current_version + 1);
end;
$$;

revoke all on function public.admin_update_configuration(text, jsonb, text, integer, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_update_configuration(text, jsonb, text, integer, uuid)
  to authenticated;

comment on function public.admin_update_configuration(text, jsonb, text, integer, uuid) is
  'Administrator-only allow-listed configuration update with version guard and idempotent audit.';
