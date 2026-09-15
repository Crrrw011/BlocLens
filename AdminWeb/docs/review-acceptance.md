# Review Operations Acceptance (Gate 2)

Date: 2026-09-15. Local stack only: Next.js on `http://127.0.0.1:3000`,
local Supabase (`127.0.0.1:54321`), no cloud credentials.
Gate specs seed their own fixtures through RLS sessions
(climber files, staff decides); no service key is used by the specs.
A `supabase db reset` starts every gate run because the unique
`(target, reporter)` report key forbids duplicate fixtures.

## Command outputs

- `supabase db reset && supabase test db`
  → `Files=9, Tests=250, Result: PASS`
- `vitest run` → `Test Files 16 passed, Tests 79 passed`
- `tsc --noEmit` → exit 0
- `eslint .` → exit 0
- `playwright test` (chromium, `PLAYWRIGHT_TEST_HARNESS=1`,
  `LOCAL_SUPABASE_SERVICE_ROLE_KEY` set for the invitation suite only)
  → `41 passed, 1 skipped (local scratch probe), 0 failed` (42 total)

## Covered flows

- Sign-in as Administrator and Moderator; non-staff denial unchanged.
- Queue filters (status/kind/severity/search) narrow through the URL;
  range links carry `?range=7d|30d|90d` and each window renders its trend.
- Inspector opens on `selected=kind:id`, preserves filters, closes on
  Escape, restores trigger focus; reporter identity is Administrator-only.
- Dismiss, escalate, hide, restore, correction accept/reject, merge
  approval all resolve through `admin_decide_review` with reason,
  version, and idempotency key; stale versions surface the conflict
  state instead of overwriting.
- `admin_audit_events` holds one row per decision with success and
  audited rejection outcomes and no reporter identity.

## Visual checklist

- Overview at 1440×1000, 1024×768, 390×844 with reduced motion:
  range pills, six metric cards, SVG trend with textual totals and
  screen-reader table, distribution bars with counts, priority table.
- Review workspace at 1440×1000: filters, search, column toggles,
  queue table, docked inspector with severity/status badges, evidence,
  and prior actions.
- No horizontal overflow at any width (`scrollWidth <= innerWidth`
  asserted); visible focus throughout; single accent and panel radii
  follow the approved shell tokens.

## Known environment notes (not release blockers)

- Run e2e with `--output=/tmp/<dir>`: the dev server on `:3001`
  watches the worktree and recompiles `.next` while screenshots land
  in `AdminWeb/test-results`, which corrupts the production server
  under test on `:3000`.
- Browsers must target `127.0.0.1:3000` (matches `ADMIN_ORIGIN`);
  unauthenticated middleware bounces rewrite the host to `localhost`.
- Severe-report fixtures auto-hide their target through the existing
  `apply_content_report_threshold` trigger, so gate fixtures use
  normal categories only.
