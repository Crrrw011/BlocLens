# Task 4 Report - Enforce Authentication and Active Staff Access

## Result

Implemented the staff-only authentication boundary for the Administrator Web portal. `/` now routes to `/overview`; unauthenticated requests route to `/sign-in`; authenticated users without an active `current_staff_access()` record route to `/access-denied`. The portal layout independently enforces the final authorisation decision on every request.

## TDD evidence

### RED

Before the production modules existed, the focused tests failed as expected:

```text
Error: Failed to resolve import "./access" from "src/lib/auth/access.test.ts".
Test Files  1 failed
Tests  no tests
```

The recovery and sign-out suites also failed with the expected missing-module errors for `password-actions.ts` and `sign-out-action.ts`.

### GREEN

After the minimal server-action and access implementation:

```text
Test Files  3 passed (3)
Tests  13 passed (13)
```

The final suite added the existing environment/localisation coverage:

```text
Test Files  5 passed (5)
Tests  19 passed (19)
```

## Security and implementation notes

- `requireStaff()` validates the Supabase user with `auth.getUser()` and then obtains the active role/capability from `current_staff_access()`. It never trusts middleware cookies as authorisation.
- Active Moderators are returned without administrator-management capability even if malformed RPC data claims otherwise. Owner capability is returned only for an active Administrator.
- Sign-in uses Zod input validation and returns `Unable to sign in with those credentials.` for both malformed and rejected credentials. There is no registration UI or `signUp` use.
- Local Supabase Auth has `enable_signup = false`. Password recovery accepts no caller-controlled redirect, always builds the fixed `/update-password` path, and the local redirect allow-list names that exact URL.
- The update page initialises the SSR browser client so Supabase can consume a recovery session from the email URL; its server action requires password confirmation and sends failures back as non-sensitive copy.
- Sign-out uses `auth.signOut({ scope: "local" })` and redirects to `/sign-in`.
- All new English UI copy is consumed from `src/localization/messages.ts`.

## Verification commands and results

| Command | Result |
| --- | --- |
| `SUPABASE_TELEMETRY_DISABLED=1 supabase db reset` | Passed; migrations and local development fixtures recreated. |
| `vitest --run` (bundled Node runtime) | Passed, 5 files and 19 tests. |
| `tsc --noEmit` (bundled Node runtime) | Passed. |
| `eslint .` (bundled Node runtime) | Passed. |
| `git diff --check` | Passed. |
| `rg -n "signUp|service_role|SUPABASE_SECRET" src` | No matches. |
| `next build` (bundled Node runtime, telemetry disabled) | Passed. `/sign-in` and `/overview` are dynamic server routes. |
| Playwright `tests/auth.spec.ts` against the clean production build | Passed, 5 of 5: session restoration, staff success, generic recovery response, local sign-out, and non-staff denial. |

The host has no `npm` executable, so checks used the already-installed bundled Node runtime. Playwright's default `webServer` command also expects `npm`; the same checked-in tests were therefore run directly against the clean local production server.

## Visual and accessibility review

- Inspected the production sign-in screen at SE-like 375x667 and Pro Max-like 430x932 widths. The title wraps without clipping, fields remain single-column, and primary/secondary controls remain reachable.
- The rendered accessibility tree exposes a heading, associated email/password labels, a button, and the recovery link. Server-action errors use `role="alert"` and contain written text rather than colour alone.
- Inputs and primary actions use at least 44px / 48px minimum height. Focus styles are explicit. Tailwind light/dark tokens are paired on each auth surface. The only pressed transition is disabled under Reduce Motion; no translucent material is used, so Reduce Transparency has no special state to test.
- The native iOS-only Dynamic Type and Simulator checks in the inherited BlocLens UI checklist do not directly apply to this Next.js admin surface. Browser layout checks covered the corresponding narrow and large phone widths; text remains intrinsically wrap-safe without fixed text heights.

## Files changed

- `AdminWeb/src/lib/auth/access.ts` and its focused unit tests.
- Server actions and form/pages for sign-in, recovery, password update, sign-out, access denial, protected portal layout, and the minimal protected overview route.
- `AdminWeb/src/middleware.ts`, root redirect, English localisation entries, Vitest alias resolution, and Playwright authentication coverage.
- `supabase/config.toml` to disable public sign-up and add the exact local password-update redirect to the allow-list.

## Self-review and concerns

- Confirmed no private/server key reaches `AdminWeb/src`, and no sign-up route or link was added.
- Confirmed no temporary `.env.local`, generated `.next`, Playwright local config, report output, or test server process is included in the commit.
- The local redirect allow-list covers local integration testing. Production deployments must separately configure their canonical HTTPS `/update-password` URL in their Supabase Auth redirect allow-list, as is standard deployment configuration.

## Fix round 1 - reviewer findings

### Result

- Restored the shared Supabase `[auth] enable_signup = true` setting. This preserves the iOS application's existing `auth.signUp` flow; the AdminWeb portal remains closed because it provides no registration route or link and all portal access requires an active staff role.
- Added `await requireStaff()` to `/overview` as a data/page boundary, while retaining the portal layout guard. This prevents a partial Next.js RSC request from receiving protected page data after a staff role is revoked.
- Replaced the caller-controlled `Origin` header recovery redirect with the non-public, server-only `ADMIN_ORIGIN` setting. The helper accepts only a bare HTTP(S) origin (no credentials, path, query, or fragment) and always appends `/update-password`.
- Added a local production browser test that creates a disposable Auth user, requests recovery through the UI, retrieves its own Mailpit message, follows the recovery URL/session, confirms a matching new password, signs in using that password, and deletes the disposable user in `finally`.

### TDD evidence

#### RED

1. The new canonical-origin unit test initially failed because `admin-origin.ts` did not exist:

```text
Error: Failed to resolve import "./admin-origin" from "src/lib/auth/admin-origin.test.ts".
```

2. The initial recovery action test failed when the former request-header implementation called `headers()` outside a request scope:

```text
Error: `headers` was called outside a request scope
```

3. Against a clean local production build, the new partial-RSC test revoked the Moderator role and received a Flight response containing `"Overview"` with no `/access-denied` redirect. This demonstrated that the layout-only guard did not protect the page payload. The test restored the role through its `finally` block.

#### GREEN

- `vitest run src/lib/auth/admin-origin.test.ts 'src/app/(auth)/password-actions.test.ts'`: 2 files, 11 tests passed.
- Production-mode partial-RSC revocation test: passed after adding the `/overview` boundary guard; response contains `/access-denied` and does not contain the Overview payload. The Moderator fixture is restored in `finally`.
- Full Mailpit recovery test: passed with a unique disposable local Auth user; password update and subsequent sign-in used the recovered password, and `auth.admin.deleteUser` removed the user in `finally`.

### Verification commands and results

| Command | Result |
| --- | --- |
| `SUPABASE_TELEMETRY_DISABLED=1 supabase db reset` | Passed before this round's local tests; restored the shared `enable_signup = true` fixture configuration. |
| Focused Vitest canonical-origin/password-action command | Passed, 2 files / 11 tests. |
| `playwright test tests/auth.spec.ts` against the local production server | Passed, 8/8: existing auth coverage plus no-registration UI, partial-RSC role revocation, and disposable-user Mailpit recovery. |
| `vitest run` | Passed, 6 files / 25 tests. |
| `tsc --noEmit` | Passed. |
| `eslint .` | Passed. |
| `NEXT_TELEMETRY_DISABLED=1 next build` | Passed; `/overview` remains dynamic. |
| `git diff --check` | Passed. |
| Signup source scan (`rg -i 'sign[ -]?up' AdminWeb/src`) | No matches: AdminWeb exposes no signup route/link/source text. |
| Browser/server boundary scan (`rg 'ADMIN_ORIGIN' AdminWeb/src/lib/supabase AdminWeb/src/app`) | No matches: browser and app modules do not import the server-only setting. |
| Secret scan (`rg -i 'service_role|supabase_secret|sb_secret|eyJhbGciOi' AdminWeb/src`) | No matches. |
| Local fixture cleanup queries | Passed: seeded Moderator `revoked_at is null`; disposable `recovery-%@bloclens.invalid` Auth-user count is `0`. |

### Visual and accessibility checks

This fix round changes no visual layout, interactive controls, or English copy. The existing responsive/dark-mode/focus review above remains applicable. The recovery browser test locates labelled password fields (using an exact accessible label where one label is a textual suffix of the other), submits the native form, and verifies the post-update access-denied state. Existing minimum target sizes, explicit focus styles, error alerts, and text-based generic reset acknowledgement are unchanged.

### Files changed in fix round 1

- `supabase/config.toml`
- `AdminWeb/.env.example`
- `AdminWeb/src/lib/auth/admin-origin.ts` and `admin-origin.test.ts`
- `AdminWeb/src/app/(auth)/password-actions.ts` and its focused tests
- `AdminWeb/src/app/(portal)/overview/page.tsx`
- `AdminWeb/tests/auth.spec.ts`

### Self-review and residual concerns

- The prior report's statement that shared signup was disabled is superseded: it is now explicitly enabled for iOS compatibility. Closed AdminWeb registration is verified at the UI/source level and remains protected by staff authorisation.
- The direct local database command in the partial-RSC test is deliberately scoped to the named local `supabase_db_BlocLens` Docker container because the project's service role lacks table UPDATE grants. It changes only the seeded Moderator's `revoked_at` and always restores it in `finally`.
- Mailpit messages remain in the local mailbox, but the test uses a UUID email address and deletes its Auth user; no shared login fixture or password is altered.
- Production deployment must set `ADMIN_ORIGIN` to its canonical HTTPS admin origin and allow-list the corresponding exact `/update-password` URL in Supabase Auth.
