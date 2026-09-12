# Administrator Climbing Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver safe management of gyms, wall zones, routes, resets, photos, beta links, and comments, including transactional route merge and guarded permanent deletion.

**Architecture:** Staff-only cursor-based read functions support entity pages. Existing lifecycle fields remain canonical; new version-checked functions perform edits, archive/restore, merge, and eligible deletion while preserving references and audit tombstones.

**Tech Stack:** PostgreSQL/pgTAP, Next.js, TanStack Table, Radix, Zod, Vitest, Playwright.

**Spec:** `docs/superpowers/specs/2026-09-12-admin-web-design.md`

## Global Constraints

- Phase 2 release gate must pass first.
- Referenced routes, gyms, and wall zones cannot be hard-deleted.
- Hard deletion is Administrator-only and requires two warnings, a reason, and exact `DELETE` confirmation.
- No operation edits grade aggregates or Helpful counts directly.
- UI work invokes `design-taste-frontend` and completes the visual checklist.

## Shared contracts

```ts
export type EntityKind =
  | "gym"
  | "wall_zone"
  | "route"
  | "reset"
  | "route_photo"
  | "beta_link"
  | "route_comment";

export type MutationEnvelope<T> = {
  targetId: string;
  expectedUpdatedAt: string;
  idempotencyKey: string;
  reason: string;
  payload: T;
};

export type DeletionImpact = {
  eligible: boolean;
  blockers: string[];
  dependentCounts: Record<string, number>;
  storagePaths: string[];
  alternative: "archive" | "merge" | "anonymise" | null;
};
```

---

### Task 1: Add staff entity projections

**Files:**
- Create: `supabase/migrations/20260912050000_admin_climbing_data_reads.sql`
- Create: `supabase/tests/admin_climbing_data_reads_test.sql`
- Create: `AdminWeb/src/features/climbing-data/types.ts`, `repository.ts`, `repository.test.ts`

**Interfaces:**
- Produces: `admin_list_entities(entity_kind, filters, cursor, page_size)` and `admin_entity_detail(entity_kind, entity_id)` for `gym | wall_zone | route | reset | route_photo | beta_link | route_comment`.

- [ ] **Step 1:** Write pgTAP tests for active/hidden/archived filters, stable cursors, dependent counts, non-staff denial, and exclusion of private data.
- [ ] **Step 2:** Implement bounded explicit-return functions and indexes only where query plans demonstrate need.
- [ ] **Step 3:** Define discriminated TypeScript schemas and repository methods `listEntities(query)` and `getEntityDetail(ref)`; test invalid database rows and error mapping.
- [ ] **Step 4:** Run database tests, advisors, Vitest, and typecheck; commit as `feat(admin-web): add climbing data read models`.

### Task 2: Build entity lists and detail pages

**Files:**
- Create: `AdminWeb/src/app/(portal)/climbing-data/[kind]/page.tsx`, `loading.tsx`, `error.tsx`
- Create: `AdminWeb/src/app/(portal)/climbing-data/[kind]/[id]/page.tsx`
- Create: `AdminWeb/src/features/climbing-data/entity-table.tsx`, `entity-inspector.tsx`, `entity-form.tsx`, `entity-view.test.tsx`

**Interfaces:**
- Produces: stable URLs with `q`, `status`, `gym`, `zone`, `sort`, `cursor`, `selected`; complex operations open full entity URLs.

- [ ] **Step 1:** Invoke the taste skill and write tests for each entity kind, column definitions, filter restoration, inspector selection, and narrow-layout restrictions.
- [ ] **Step 2:** Implement shared table mechanics with kind-specific column modules; do not build one conditional mega-component.
- [ ] **Step 3:** Implement details with identifiers, lifecycle, source, timestamps, route Color/Tag + Style, terrain, dependencies, moderation history, and reset attribution.
- [ ] **Step 4:** Add layout-matched skeleton, empty, denied, deleted, stale, and retry states.
- [ ] **Step 5:** Run tests and visual checks; commit as `feat(admin-web): build climbing data workspace`.

### Task 3: Add version-checked edits and lifecycle actions

**Files:**
- Create: `supabase/migrations/20260912060000_admin_climbing_data_actions.sql`
- Create: `supabase/tests/admin_climbing_data_actions_test.sql`
- Create: `AdminWeb/src/features/climbing-data/actions.ts`, `lifecycle-dialog.tsx`, `actions.test.ts`

**Interfaces:**
- Produces: `admin_update_entity(entity_kind, entity_id, patch, reason, expected_updated_at, idempotency_key)` and `admin_change_lifecycle(route_id, action, reason, expected_updated_at, idempotency_key)`.

- [ ] **Step 1:** Write pgTAP tests for allowed field whitelists, Moderator denial for archive, stale conflict, invalid state transitions, idempotency, and audit rows.
- [ ] **Step 2:** Implement locked transactional functions; reject unknown JSON patch keys instead of silently ignoring them.
- [ ] **Step 3:** Implement Zod action schemas and dialogs that retain input after recoverable failure.
- [ ] **Step 4:** Run database/unit tests and commit as `feat(admin-web): add climbing data actions`.

### Task 4: Harden transactional route merge

**Files:**
- Create: `supabase/migrations/20260912070000_admin_route_merge.sql`
- Create: `supabase/tests/admin_route_merge_test.sql`
- Create: `AdminWeb/src/app/(portal)/climbing-data/routes/[id]/merge/page.tsx`
- Create: `AdminWeb/src/features/routes/merge-preview.tsx`, `merge-action.ts`, `merge.test.tsx`

**Interfaces:**
- Produces: `admin_route_merge_impact(source_id, canonical_id)` and `admin_merge_routes(source_id, canonical_id, resolutions, reason, expected_versions, idempotency_key)`.

- [ ] **Step 1:** Write pgTAP tests covering Logbook references, photos, beta links, comments, votes, duplicate conflicts, cross-gym rejection, self/cycle rejection, rollback, and idempotent replay.
- [ ] **Step 2:** Implement impact preview counts and conflict rows without exposing private Logbook content.
- [ ] **Step 3:** Implement a transaction that locks both routes, applies explicit conflict resolutions, migrates supported foreign keys, points source to canonical, archives source, and appends one detailed audit event.
- [ ] **Step 4:** Build the full-page preview with canonical/source comparison and disabled submit until all conflicts are resolved.
- [ ] **Step 5:** Run tests and commit as `feat(admin-web): add transactional route merge`.

### Task 5: Implement eligible permanent deletion

**Files:**
- Create: `supabase/migrations/20260912080000_admin_permanent_deletion.sql`
- Create: `supabase/tests/admin_permanent_deletion_test.sql`
- Create: `AdminWeb/src/features/destructive/deletion-impact.ts`, `delete-dialog.tsx`, `delete-action.ts`, `delete-dialog.test.tsx`

**Interfaces:**
- Produces: `admin_deletion_impact(target_type, target_id)` and `admin_permanently_delete(target_type, target_id, reason, expected_updated_at, idempotency_key)`.

- [ ] **Step 1:** Write pgTAP tests denying Moderator, routes with Logbook references, retained gym/zone relationships, unsupported types, stale state, and missing reason; verify eligible media/comment deletion leaves an audit tombstone.
- [ ] **Step 2:** Implement impact output `{eligible, blockers, dependentCounts, storagePaths, alternative}` and revalidate it inside the deletion transaction.
- [ ] **Step 3:** Implement warning one with exact dependencies and warning two with mandatory reason plus case-sensitive `DELETE`; test back navigation resets the typed phrase.
- [ ] **Step 4:** Delete Storage objects through a trusted ordered server workflow, record partial failure, and never claim database success when storage cleanup failed.
- [ ] **Step 5:** Run tests and commit as `feat(admin-web): add guarded permanent deletion`.

### Task 6: Verify the climbing-data release gate

**Files:**
- Create: `AdminWeb/e2e/climbing-data.spec.ts`, `AdminWeb/e2e/route-merge.spec.ts`, `AdminWeb/e2e/permanent-delete.spec.ts`
- Create: `AdminWeb/docs/climbing-data-acceptance.md`

**Interfaces:**
- Produces: repeatable Gate 3 acceptance record.

- [ ] **Step 1:** Add deterministic fixtures for editable, archived, merge-conflicted, deletion-blocked, and deletion-eligible records.
- [ ] **Step 2:** Test search/filter/deep link, edit, archive/restore, merge preview/execution, both deletion warnings, stale conflict, and partial storage failure.
- [ ] **Step 3:** Run full database and web verification suites plus database advisors.
- [ ] **Step 4:** Record results and visual review in the acceptance file; commit as `test(admin-web): verify climbing data operations`.
