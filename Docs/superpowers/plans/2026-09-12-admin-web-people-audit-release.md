# Administrator People, Audit, and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete people controls, staff access, gym claims, immutable audit tools, safe configuration, and production-ready deployment.

**Architecture:** Protected functions model penalties and claims as explicit state transitions. Audit and configuration use dedicated staff-only read/write contracts. Vercel environments bind to isolated Supabase projects and final security checks prove that browser assets contain no secrets.

**Tech Stack:** PostgreSQL/pgTAP, Next.js, Supabase SSR, Radix, TanStack Table, Vitest, Playwright, Vercel.

**Spec:** `docs/superpowers/specs/2026-09-12-admin-web-design.md`

## Global Constraints

- Phase 3 release gate must pass first.
- Private Logbook entries and private notes are absent from queries, exports, fixtures, and screenshots.
- Moderator cannot penalise users, decide claims, manage staff, or change configuration.
- Ordinary Administrator may invite Moderators; only `can_manage_administrators` may create Administrators.
- UI work invokes `design-taste-frontend` and completes the visual checklist.

## Shared contracts

```ts
export type PenaltyKind = "publishing_restriction" | "timed_suspension" | "permanent_ban";
export type AuditOutcome = "succeeded" | "rejected" | "partially_failed" | "failed";

export type AuditFilter = {
  actorId?: string;
  action?: string;
  targetType?: string;
  outcome?: AuditOutcome;
  from: string;
  to: string;
  cursor?: string;
};
```

---

### Task 1: Model user restrictions and penalties

**Files:**
- Create: `supabase/migrations/20260912090000_admin_user_penalties.sql`
- Create: `supabase/tests/admin_user_penalties_test.sql`
- Create: `AdminWeb/src/features/people/types.ts`, `repository.ts`, `penalty-actions.ts`, `penalty-actions.test.ts`

**Interfaces:**
- Produces: `user_restrictions`; functions `admin_user_summary(user_id)`, `admin_apply_user_penalty(user_id, kind, ends_at, reason, idempotency_key)`, `admin_reverse_user_penalty(action_id, reason, idempotency_key)`.

- [ ] **Step 1:** Write pgTAP tests for publishing restriction, timed suspension, permanent ban, reversal, Administrator-only access, expiry constraints, idempotency, and audit linkage.
- [ ] **Step 2:** Implement canonical active restrictions while retaining the existing `moderation_actions` history; enforce restrictions through server-controlled checks used by contribution RLS/functions.
- [ ] **Step 3:** Implement typed repository/actions and test that user summary includes public profile plus contribution/moderation history but never private Logbook content.
- [ ] **Step 4:** Run database and web tests; commit as `feat(admin-web): add user penalty controls`.

### Task 2: Build People and staff access workspaces

**Files:**
- Create: `AdminWeb/src/app/(portal)/people/page.tsx`, `AdminWeb/src/app/(portal)/people/[id]/page.tsx`, `AdminWeb/src/app/(portal)/staff/page.tsx`
- Create: `AdminWeb/src/features/people/people-table.tsx`, `user-detail.tsx`, `penalty-dialog.tsx`
- Create: `AdminWeb/src/features/staff/staff-table.tsx`, `invite-dialog.tsx`, `staff-actions.ts`, `staff.test.tsx`

**Interfaces:**
- Produces: searchable People URLs and owner-aware staff invitation/revocation/deactivation controls.

- [ ] **Step 1:** Invoke the taste skill and write tests for public-only user detail, penalty confirmation, owner/ordinary-admin role options, Moderator-hidden staff navigation, and deactivation confirmation.
- [ ] **Step 2:** Implement server-paginated People and Staff tables, full user detail pages, active restriction cards, and invitation state badges.
- [ ] **Step 3:** Connect Phase 1 invitations and Task 1 penalties; revalidate access on every role/deactivation mutation.
- [ ] **Step 4:** Run tests and visual checks; commit as `feat(admin-web): build people and staff access`.

### Task 3: Implement gym-claim decisions

**Files:**
- Create: `supabase/migrations/20260912100000_admin_gym_claim_actions.sql`
- Create: `supabase/tests/admin_gym_claim_actions_test.sql`
- Create: `AdminWeb/src/app/(portal)/people/claims/page.tsx`
- Create: `AdminWeb/src/features/claims/claims-table.tsx`, `claim-inspector.tsx`, `claim-actions.ts`, `claims.test.tsx`

**Interfaces:**
- Produces: `admin_decide_gym_claim(claim_id, decision, review_note, expected_updated_at, idempotency_key)`.

- [ ] **Step 1:** Write pgTAP tests for Administrator-only approval/rejection, required note, stale conflict, membership creation on approval, no membership on rejection, and audit events.
- [ ] **Step 2:** Implement the locked transactional function and explicit approved/rejected transitions.
- [ ] **Step 3:** Build the claims table/inspector with gym context, applicant public profile, domain email, verification method, and decision dialog.
- [ ] **Step 4:** Run tests; commit as `feat(admin-web): add gym claim review`.

### Task 4: Build immutable audit browsing and export

**Files:**
- Create: `supabase/migrations/20260912110000_admin_audit_reads.sql`
- Create: `supabase/tests/admin_audit_reads_test.sql`
- Create: `AdminWeb/src/app/(portal)/audit/page.tsx`, `AdminWeb/src/app/api/audit/export/route.ts`, `AdminWeb/src/app/api/cron/audit-ip-retention/route.ts`
- Create: `AdminWeb/src/features/audit/audit-table.tsx`, `audit-inspector.tsx`, `export.ts`, `audit.test.tsx`

**Interfaces:**
- Produces: `admin_list_audit(actor, action, target, outcome, from_at, to_at, cursor, page_size)` and streamed UTF-8 CSV export with formula-safe cells.

- [ ] **Step 1:** Write tests for filters, cursor stability, before/after summary display, prohibited private fields, no update/delete grants, CSV escaping, and spreadsheet-formula prefix neutralisation.
- [ ] **Step 2:** Implement bounded staff-only reads plus `private.redact_expired_admin_audit_ips(cutoff)`; replace raw IP older than 90 days with a keyed non-reversible correlation digest and never export raw IP.
- [ ] **Step 3:** Implement table, inspector, and a server-streamed export with explicit columns and maximum date range.
- [ ] **Step 4:** Implement a Vercel Cron route protected by `CRON_SECRET` that calls the retention function once daily; test missing/invalid secrets and idempotent repeated runs.
- [ ] **Step 5:** Run tests; commit as `feat(admin-web): add immutable audit tools`.

### Task 5: Implement safe operational configuration

**Files:**
- Create: `supabase/migrations/20260912120000_admin_operational_configuration.sql`
- Create: `supabase/tests/admin_operational_configuration_test.sql`
- Create: `AdminWeb/src/app/(portal)/configuration/page.tsx`
- Create: `AdminWeb/src/features/configuration/config-form.tsx`, `actions.ts`, `configuration.test.tsx`

**Interfaces:**
- Produces: `operational_configuration`; `admin_update_configuration(key, value, reason, expected_version, idempotency_key)` with allow-listed keys only.

- [ ] **Step 1:** Write pgTAP tests allowing reason templates, queue ordering, dashboard range, and approved feature flags while rejecting grade calculations, trusted threshold, privacy defaults, unknown keys, and Moderator calls.
- [ ] **Step 2:** Implement typed key/value constraints, optimistic versioning, and audit writes.
- [ ] **Step 3:** Build grouped forms with frozen product rules shown read-only and sourced from English message keys.
- [ ] **Step 4:** Run tests; commit as `feat(admin-web): add safe operations configuration`.

### Task 6: Add observability and deployment configuration

**Files:**
- Create: `AdminWeb/vercel.json`, `AdminWeb/src/instrumentation.ts`, `AdminWeb/src/lib/observability.ts`, `AdminWeb/src/lib/observability.test.ts`
- Create: `AdminWeb/docs/environment-runbook.md`, `AdminWeb/docs/production-readiness.md`
- Modify: `supabase/config.toml`, `AdminWeb/.env.example`

**Interfaces:**
- Produces: correlation IDs, structured redacted server logs, security headers, and exact Local/Staging/Production runbooks.

- [ ] **Step 1:** Write tests proving token/password/cookie/email redaction and stable correlation ID propagation.
- [ ] **Step 2:** Add CSP, frame denial, referrer policy, nosniff, permissions policy, and authenticated no-store headers in Next/Vercel configuration.
- [ ] **Step 3:** Document Local ports, Staging project `atmtqesdhxpgnrjedwsu`, new Production project creation, Auth redirects, environment variables, migration promotion, rollback boundaries, and owner bootstrap commands without embedding credentials.
- [ ] **Step 4:** Configure local auth redirect URLs and password policy consistently with the runbook; keep public app signup requirements separate from the portal UI.
- [ ] **Step 5:** Run tests, production build, and scan `AdminWeb/.next/static` for secret variable names; commit as `chore(admin-web): add secure deployment configuration`.

### Task 7: Run final acceptance and prepare release

**Files:**
- Create: `AdminWeb/e2e/people-access.spec.ts`, `claims.spec.ts`, `audit-config.spec.ts`, `authorization-matrix.spec.ts`
- Create: `AdminWeb/docs/final-acceptance.md`

**Interfaces:**
- Produces: Gate 4 evidence and the single complete acceptance build requested by the user.

- [ ] **Step 1:** Test the complete Moderator, ordinary Administrator, owner Administrator, inactive staff, and non-staff permission matrix.
- [ ] **Step 2:** Test penalties/reversal, invitations/revocation/expiry, claims, audit lookup/export, configuration conflicts, session expiry, and direct URL denial.
- [ ] **Step 3:** Run `supabase db reset && supabase test db`; expect every pgTAP suite to pass.
- [ ] **Step 4:** Run `cd AdminWeb && npm ci && npm run lint && npm run typecheck && npm test -- --run && npm run build && npm run test:e2e`; expect all commands to exit 0.
- [ ] **Step 5:** Run database advisors, dependency audit, browser secret scan, keyboard-only pass, reduced-motion pass, and responsive visual review at 1440, 1024, 768, and 390 pixels.
- [ ] **Step 6:** Deploy a Vercel Preview against Staging, rerun the smoke/role/destructive flows, and record URLs plus non-secret evidence in `final-acceptance.md`.
- [ ] **Step 7:** Commit acceptance evidence as `test(admin-web): complete portal acceptance` and stop before Production deployment until the user explicitly authorises it.
