# Administrator Review Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the operations overview and end-to-end moderation workflow for reports and corrections.

**Architecture:** Add staff-only projections that expose the minimum review context, then consume them through typed server repositories. List state lives in URL parameters; row selection opens the contextual inspector; protected functions own every decision and audit write.

**Tech Stack:** Next.js, Supabase/PostgreSQL, TanStack Table, Radix, Vitest, Playwright.

**Spec:** `docs/superpowers/specs/2026-09-12-admin-web-design.md`

## Global Constraints

- Phase 1 release gate must pass before this plan begins.
- Reporter identity is visible only where policy requires it and never enters public projections.
- All UI work invokes `design-taste-frontend` and completes the BlocLens visual checklist.
- Mutations require target version, idempotency key, reason, and fresh role validation.

## Shared contracts

```ts
export type ReviewKind =
  | "content_report"
  | "route_correction"
  | "removal_report"
  | "merge_suggestion";

export type ReviewDecision =
  | "dismiss"
  | "escalate"
  | "hide"
  | "restore"
  | "accept_correction"
  | "reject_correction";

export type ReviewRef = { kind: ReviewKind; id: string };
export type CursorPage<T> = { items: T[]; nextCursor: string | null };
```

Protected database actions return an outcome row instead of raising after an expected denial, so the attempted action can be committed to audit atomically:

```sql
returns table (ok boolean, error_code text, audit_event_id uuid, result jsonb)
```

---

### Task 1: Create operational read models

**Files:**
- Create: `supabase/migrations/20260912030000_admin_review_read_models.sql`
- Create: `supabase/tests/admin_review_read_models_test.sql`

**Interfaces:**
- Produces: `admin_overview_metrics(range_start, range_end)`, `admin_review_queue(status_filter, target_filter, search_text, page_after, page_size)`, `admin_review_item(item_kind, item_id)`.

- [ ] **Step 1:** Write pgTAP tests for Moderator/Admin access, non-staff denial, stable `(created_at,id)` cursor order, severe counts, and absence of private Logbook columns.
- [ ] **Step 2:** Run `supabase test db` and confirm missing-function failures.
- [ ] **Step 3:** Implement staff-only security-definer functions with explicit return tables, `set search_path = ''`, bounded page size `1..100`, and indexed filters over existing reports/corrections.
- [ ] **Step 4:** Add only evidence-backed indexes identified by `EXPLAIN (ANALYZE, BUFFERS)` on seeded representative queries.
- [ ] **Step 5:** Run reset/tests plus Supabase database advisors; commit as `feat(database): add admin review read models`.

### Task 2: Add typed review repositories

**Files:**
- Create: `AdminWeb/src/features/review/types.ts`, `schemas.ts`, `repository.ts`, `repository.test.ts`
- Create: `AdminWeb/src/features/overview/repository.ts`, `repository.test.ts`

**Interfaces:**
- Produces: `ReviewQueueItem`, `ReviewItemDetail`, `OverviewMetrics`; `listReviewQueue(query)`, `getReviewItem(ref)`, `getOverviewMetrics(range)`.

- [ ] **Step 1:** Define Zod schemas with discriminated item kinds `content_report | route_correction | removal_report | merge_suggestion` and write fixtures that fail on missing target identifiers.
- [ ] **Step 2:** Run focused tests and confirm failure before implementation.
- [ ] **Step 3:** Implement server-only repositories, map snake_case rows to camelCase domain objects, and convert Supabase errors into `{code, traceId}` operational errors.
- [ ] **Step 4:** Test malformed rows, empty pages, cursor continuation, and permission errors; run typecheck.
- [ ] **Step 5:** Commit as `feat(admin-web): add review data repositories`.

### Task 3: Build the operations overview

**Files:**
- Create: `AdminWeb/src/app/(portal)/overview/page.tsx`, `loading.tsx`, `error.tsx`
- Create: `AdminWeb/src/features/overview/metrics-grid.tsx`, `review-trend.tsx`, `queue-distribution.tsx`, `priority-table.tsx`
- Create: `AdminWeb/src/features/overview/overview.test.tsx`

**Interfaces:**
- Consumes: `getOverviewMetrics`, `DataTable`, `Inspector`.
- Produces: `/overview?range=7d|30d|90d` and links into filtered Review URLs.

- [ ] **Step 1:** Invoke the taste skill and write tests for evidence-backed metrics, empty state, retry state, and priority-row deep links.
- [ ] **Step 2:** Implement the approved visual hierarchy using CSS/SVG charts without adding a chart dependency; every graphic has a textual value and accessible label.
- [ ] **Step 3:** Add skeletons matching final card geometry and prevent sample prototype values from entering production rendering.
- [ ] **Step 4:** Run component tests, keyboard checks, and visual snapshots at the approved widths.
- [ ] **Step 5:** Commit as `feat(admin-web): add operations overview`.

### Task 4: Build review list and contextual inspector

**Files:**
- Create: `AdminWeb/src/app/(portal)/review/page.tsx`, `loading.tsx`, `error.tsx`
- Create: `AdminWeb/src/features/review/review-table.tsx`, `review-filters.tsx`, `review-inspector.tsx`, `review-view.test.tsx`

**Interfaces:**
- Produces URL schema: `status`, `kind`, `severity`, `q`, `cursor`, `selected`; selecting a row changes only `selected` and preserves scroll/filter state.

- [ ] **Step 1:** Write tests for URL parsing, invalid-filter fallback, row selection, Escape close, focus restoration, and role-dependent actions.
- [ ] **Step 2:** Implement the TanStack table with server pagination, sortable declared columns, column visibility, persistent selection, and full loading/empty/error/denied/deleted/conflict states.
- [ ] **Step 3:** Implement the inspector with target context, evidence, contributor summary, prior actions, and no private Logbook query.
- [ ] **Step 4:** Run unit, accessibility, and responsive Playwright tests.
- [ ] **Step 5:** Commit as `feat(admin-web): build review workspace`.

### Task 5: Implement auditable review decisions

**Files:**
- Create: `supabase/migrations/20260912040000_admin_review_actions.sql`
- Create: `supabase/tests/admin_review_actions_test.sql`
- Create: `AdminWeb/src/features/review/actions.ts`, `action-dialog.tsx`, `actions.test.ts`

**Interfaces:**
- Produces: `admin_decide_review(item_kind, item_id, decision, reason, expected_updated_at, idempotency_key)`; decisions `dismiss | escalate | hide | restore | accept_correction | reject_correction`.

- [ ] **Step 1:** Write pgTAP tests for role/action matrix, stale timestamp conflict, idempotent replay, invalid transitions, audit success, and audited rejected attempts returned as `ok = false` outcome rows.
- [ ] **Step 2:** Implement one transactional function that locks the source row, validates target existence/type, changes the canonical table, closes the queue item, and appends the audit event.
- [ ] **Step 3:** Write Server Action tests for mandatory reason, UUID/timestamp validation, conflict mapping, and input retention on network failure.
- [ ] **Step 4:** Implement the Radix confirmation dialog and revalidate `/overview` plus the active `/review` URL only after confirmed success.
- [ ] **Step 5:** Run all database and focused web tests; commit as `feat(admin-web): add audited review decisions`.

### Task 6: Verify the review release gate

**Files:**
- Create: `AdminWeb/e2e/review-flow.spec.ts`, `AdminWeb/e2e/overview.spec.ts`
- Create: `AdminWeb/docs/review-acceptance.md`

**Interfaces:**
- Produces: repeatable Gate 2 acceptance record.

- [ ] **Step 1:** Seed fixed Moderator/Admin/non-staff identities and review items through Playwright setup without cloud credentials.
- [ ] **Step 2:** Test sign-in, queue filters, inspector, dismiss, hide, restore, escalation, accepted correction, stale conflict, and audit lookup.
- [ ] **Step 3:** Run `supabase db reset && supabase test db`, then `cd AdminWeb && npm run lint && npm run typecheck && npm test -- --run && npm run test:e2e`.
- [ ] **Step 4:** Record exact command outputs and visual checklist results in `review-acceptance.md`; commit as `test(admin-web): verify review operations`.
