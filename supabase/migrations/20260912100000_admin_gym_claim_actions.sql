-- Administrator-only gym claim approval and rejection.
-- Approval mints the verified gym membership in the same transaction.

create or replace function public.admin_decide_gym_claim(
  claim_id uuid,
  decision text,
  review_note text,
  expected_updated_at timestamptz,
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
  clean_note text := btrim(coalesce(admin_decide_gym_claim.review_note, ''));
  claim public.gym_claims%rowtype;
  audit_id uuid := null;
  prior_audit public.admin_audit_events%rowtype;
  new_status public.claim_status;
begin
  if admin_decide_gym_claim.claim_id is null
    or admin_decide_gym_claim.decision is null
    or admin_decide_gym_claim.decision not in ('approved', 'rejected')
    or char_length(clean_note) not between 1 and 1000
    or admin_decide_gym_claim.expected_updated_at is null
    or admin_decide_gym_claim.idempotency_key is null
  then
    raise exception using errcode = '22023', message = 'invalid gym claim decision';
  end if;

  new_status := admin_decide_gym_claim.decision::public.claim_status;

  select public.is_admin() into actor_is_admin;

  if not actor_is_admin then
    audit_id := private.append_admin_audit(
      actor_id, 'gym.claim.decided', 'gym_claim',
      admin_decide_gym_claim.claim_id, clean_note, 'failed',
      '{}'::jsonb,
      jsonb_build_object('decision', new_status, 'error_code', 'forbidden'),
      extensions.gen_random_uuid(), admin_decide_gym_claim.idempotency_key
    );
    return query select false, 'forbidden'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select claims.* into claim
  from public.gym_claims as claims
  where claims.id = admin_decide_gym_claim.claim_id
  for update;

  if claim.id is null then
    audit_id := private.append_admin_audit(
      actor_id, 'gym.claim.decided', 'gym_claim',
      admin_decide_gym_claim.claim_id, clean_note, 'failed',
      '{}'::jsonb,
      jsonb_build_object('decision', new_status, 'error_code', 'not_found'),
      extensions.gen_random_uuid(), admin_decide_gym_claim.idempotency_key
    );
    return query select false, 'not_found'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  select audit.* into prior_audit
  from public.admin_audit_events as audit
  where audit.idempotency_key = admin_decide_gym_claim.idempotency_key
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

  if claim.status <> 'submitted'::public.claim_status then
    audit_id := private.append_admin_audit(
      actor_id, 'gym.claim.decided', 'gym_claim',
      claim.id, clean_note, 'failed',
      jsonb_build_object('status', claim.status),
      jsonb_build_object('decision', new_status, 'error_code', 'invalid_transition'),
      extensions.gen_random_uuid(), admin_decide_gym_claim.idempotency_key
    );
    return query select false, 'invalid_transition'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  if claim.updated_at is distinct from admin_decide_gym_claim.expected_updated_at then
    audit_id := private.append_admin_audit(
      actor_id, 'gym.claim.decided', 'gym_claim',
      claim.id, clean_note, 'failed',
      jsonb_build_object('status', claim.status),
      jsonb_build_object('decision', new_status, 'error_code', 'conflict'),
      extensions.gen_random_uuid(), admin_decide_gym_claim.idempotency_key
    );
    return query select false, 'conflict'::text, audit_id, '{}'::jsonb;
    return;
  end if;

  update public.gym_claims
  set status = new_status,
      reviewer_id = actor_id,
      review_note = clean_note,
      reviewed_at = statement_timestamp()
  where id = claim.id;

  if new_status = 'approved'::public.claim_status then
    insert into public.gym_memberships (gym_id, user_id, role, granted_by)
    values (
      claim.gym_id, claim.applicant_id,
      'verified_representative'::public.gym_membership_role, actor_id
    )
    on conflict (gym_id, user_id, role) do update
    set granted_by = excluded.granted_by,
        granted_at = statement_timestamp(),
        revoked_at = null;
  end if;

  audit_id := private.append_admin_audit(
    actor_id, 'gym.claim.decided', 'gym_claim',
    claim.id, clean_note, 'succeeded',
    jsonb_build_object('status', 'submitted'),
    jsonb_build_object(
      'decision', new_status,
      'gym_id', claim.gym_id,
      'result', jsonb_build_object('status', new_status)),
    extensions.gen_random_uuid(), admin_decide_gym_claim.idempotency_key
  );

  return query select true, null::text, audit_id,
    jsonb_build_object('status', new_status);
end;
$$;

revoke all on function public.admin_decide_gym_claim(uuid, text, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_decide_gym_claim(uuid, text, text, timestamptz, uuid)
  to authenticated;

comment on function public.admin_decide_gym_claim(uuid, text, text, timestamptz, uuid) is
  'Administrator-only gym claim decision with version guard, membership minting, and idempotent audit.';
