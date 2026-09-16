# Final Acceptance (Gate 4)

Date: 2026-09-16. Local stack only unless noted: Next.js production
build on `http://127.0.0.1:3000` (`NEXT_DIST_DIR=.next-prod`, isolated
from the `:3001` dev watcher), local Supabase (`127.0.0.1:54321`), no
cloud credentials. Gate specs seed fixtures through RLS sessions and
`supabase db reset` starts every gate run.

Deviation from the plan: e2e specs live in `AdminWeb/tests/` with the
rest of the suite, not `AdminWeb/e2e/` (`people-access.spec.ts`,
`claims.spec.ts`, `audit-config.spec.ts`, `authorization-matrix.spec.ts`).

## Command outputs (this run)

- `supabase db reset && supabase test db`
  → `Files=18, Tests=491, Result: PASS`
- `vitest run` → `Test Files 28 passed, Tests 151 passed`
- `tsc --noEmit` → exit 0
- `eslint .` → exit 0
- `next build` (`.next-prod`) → success
- `playwright test` (chromium, `PLAYWRIGHT_TEST_HARNESS=1`,
  `PLAYWRIGHT_OUTPUT_DIR=/tmp/adminweb-results`,
  `LOCAL_SUPABASE_SERVICE_ROLE_KEY` set for the invitation suite only)
  → `69 passed, 1 skipped (local scratch probe), 0 failed` (70 total)
- `supabase db lint` → no errors
- Browser bundle scan of `.next-prod/static` for `SUPABASE_SECRET`,
  `CRON_SECRET`, `SERVICE_ROLE`, and the service-role JWT → only
  key-prefix checks inside supabase-js, no secret values

## Permission matrix (authorization-matrix.spec.ts)

- Moderator: overview, review, climbing-data, people, audit reachable;
  staff, claims, configuration redirect to access-denied.
- Administrator: every destination reachable.
- Non-staff: protected content and the audit export API denied (403).
- Deactivated staff loses access without a session change;
  reactivation restores it on next load.

## Feature gates

- Penalties and reversal, including RLS enforcement tiers
  (publish / interact / report) and expiry (people-access.spec.ts).
- Invitations, revocation, staff deactivation/reactivation with
  owner-capability gating (people-access.spec.ts).
- Claims approve/reject with membership minting; Moderators denied
  (claims.spec.ts).
- Audit lookup, CSV export download, configuration conflict surfacing;
  Moderators browse audit but never reach configuration
  (audit-config.spec.ts).
- Stale-version conflicts, idempotent replays, and audit tombstones
  covered at pgTAP, Vitest, and e2e levels per feature.

## Visual and access review

- Screenshots at 1440×1000, 1024×768, 390×844 with reduced motion for
  overview, review, climbing-data, people, staff, claims, audit, and
  configuration; no horizontal overflow (clientWidth comparison after
  content settle and font swap).
- Keyboard: rail tab order, Command-K search focus, inspector Escape
  close with trigger focus restoration, dialog focus trap, visible
  focus rings, forced-colours mode (shell.spec.ts plus feature specs).
- Table cells truncate by design (nowrap + ellipsis); the zoom test
  asserts fitting copy never clips and truncation is always indicated.

## Known test-environment behaviours (not product defects)

- The suite must start from `supabase db reset`: unique keys
  (report targets, correction issues, logbook user+route) collide on
  re-runs, and `PLAYWRIGHT_OUTPUT_DIR` must point outside the watched
  tree or artifact writes corrupt the build under test.
- Browsers must target `127.0.0.1:3000` (matches `ADMIN_ORIGIN`).
  Next.js normalises loopback hosts to `localhost` when building
  absolute middleware redirect URLs, so mixed-host navigation splits
  the session cookie jar; the suite stays on one host throughout.
- `document.fonts.ready` gates visual measurements; Geist swap
  otherwise moves subpixel assertions by a pixel at 200% zoom.
- One sign-in helper retries once: the local Auth stack occasionally
  denies a first attempt under suite burst while direct calls succeed.
  The final state is always asserted, never assumed.

## Blocked (needs human action)

- Dependency audit (`npm audit --omit=dev`, run 2026-09-16): 2 findings,
  both in transitive `postcss <=8.5.22` via `next@15.5.25`
  (GHSA-qx2v-qp2m-jg93, GHSA-6g55-p6wh-862q, GHSA-fxqj-rqcc-2cmp,
  GHSA-r28c-9q8g-f849). Fix requires `next@16` (breaking change).
  ACCEPTED RISK: these are build-time CSS toolchain issues requiring
  attacker-controlled CSS input; the portal processes only repository
  stylesheets. Revisit on the Next 16 migration, not a release blocker.
- Vercel Preview against Staging (`atmtqesdhxpgnrjedwsu`) and the
  smoke/role/destructive re-verification there: no Vercel access from
  this environment. The runbook (`docs/environment-runbook.md`) lists
  exact variables, redirects, migration promotion, and the owner
  bootstrap sequence.
- Production deployment: explicitly STOPPED per plan until the user
  authorises it.
