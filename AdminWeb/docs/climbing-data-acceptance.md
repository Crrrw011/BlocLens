# Climbing Data Acceptance (Gate 3)

Date: 2026-09-15. Local stack only: Next.js on `http://127.0.0.1:3000`,
local Supabase (`127.0.0.1:54321`), no cloud credentials.
Gate specs seed their own fixtures through RLS sessions
(climber creates, staff edits/decides); no service key is used.
A `supabase db reset` starts every gate run because unique keys
(report targets, correction issues, logbook user+route) forbid duplicates.

Note: the plan names `AdminWeb/e2e/*.spec.ts`; the specs live in
`AdminWeb/tests/*.spec.ts` with the rest of the suite
(`climbing-data.spec.ts`, `route-merge.spec.ts`, `permanent-delete.spec.ts`).

## Command outputs

- `supabase db reset && supabase test db`
  → `Files=13, Tests=369, Result: PASS`
- `supabase db lint` → no errors
- `vitest run` → `Test Files 21 passed, Tests 110 passed`
- `tsc --noEmit` → exit 0
- `eslint .` → exit 0
- `playwright test` (chromium, `PLAYWRIGHT_TEST_HARNESS=1`,
  `PLAYWRIGHT_OUTPUT_DIR=/tmp/adminweb-results`,
  `LOCAL_SUPABASE_SERVICE_ROLE_KEY` set for the invitation suite only)
  → `53 passed, 1 skipped (local scratch probe), 0 failed` (54 total)

## Covered flows

- Entity lists for all seven kinds with kind tabs, status filters,
  gym scope, search, stable cursor pagination, and deep links;
  detail pages with identifiers, lifecycle, dependencies (linked),
  moderation history, and timestamps.
- Version-checked route edits (colour/grade/terrain) with reason and
  idempotency key; stale versions surface the conflict state.
- Archive/restore as Administrator; hide/restore as Moderator;
  Moderators see no archive, merge, or delete controls.
- Route merge preview with reference counts and per-duplicate
  acknowledgement; submit stays disabled until every duplicate is
  acknowledged. Execution migrates Logbook/photos/beta/corrections/
  reports/votes, leaves acknowledged duplicates behind, archives the
  source, points it at canonical, completes the satisfied suggestion,
  and writes one detailed audit event. Cross-gym, self, already-merged,
  and unacknowledged merges are refused without moving data.
- Two-warning permanent deletion (exact dependencies → reason plus
  case-sensitive DELETE); blocked targets withhold Continue and name
  the alternative; file cleanup runs before the database transaction
  and failures never reach it; every deletion leaves an audit tombstone.
- `route_photos.hidden_at` backfilled: the column was missing while
  sibling tables and the hide/restore paths assumed it.

## Visual checklist

- Routes workspace at 1440×1000 with reduced motion: kind tabs,
  status pills, gym scope, search, table with moderation column,
  inspector with dependency links, full record page.
- No horizontal overflow (`scrollWidth <= innerWidth` asserted);
  visible focus throughout; single accent and panel radii follow
  the approved shell tokens.

## Known environment notes (not release blockers)

- Run e2e with `PLAYWRIGHT_OUTPUT_DIR=/tmp/<dir>`: the dev server on
  `:3001` watches the worktree and recompiles `.next` while screenshots
  land in `AdminWeb/test-results`, which corrupts the production server
  under test on `:3000`.
- Browsers must target `127.0.0.1:3000` (matches `ADMIN_ORIGIN`);
  unauthenticated middleware bounces rewrite the host to `localhost`.
- Severe-report fixtures auto-hide their target through the existing
  `apply_content_report_threshold` trigger, so gate fixtures use
  normal categories only.
