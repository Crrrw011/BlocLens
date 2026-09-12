# Administrator Web Foundation and Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a secure, tested Administrator Web shell with SSR authentication, protected staff capabilities, invitations, and append-only audit infrastructure.

**Architecture:** The Next.js server validates Supabase cookie sessions and queries protected staff records on every privileged request. A new additive migration introduces capabilities, invitations, audit events, and server-only functions without weakening existing iOS RLS.

**Tech Stack:** Next.js, TypeScript, Supabase SSR, PostgreSQL/pgTAP, Tailwind CSS, Radix, Vitest, Playwright.

**Spec:** `docs/superpowers/specs/2026-09-12-admin-web-design.md`

## Global Constraints

- Work only inside `AdminWeb/`, `supabase/`, and the listed documentation files.
- Do not expose a secret or service-role key to Client Components.
- Do not add public registration.
- UI work requires `design-taste-frontend` and the three BlocLens design documents.
- Commit after every task only when its listed checks pass.

## Shared contracts

```ts
export type StaffRole = "admin" | "moderator";

export type StaffAccess = {
  userId: string;
  role: StaffRole;
  canManageAdministrators: boolean;
};

export type ActionState =
  | { status: "idle" }
  | { status: "error"; message: string; fieldErrors?: Record<string, string[]> }
  | { status: "success" };
```

```sql
create function public.current_staff_access()
returns table (user_id uuid, role public.app_role, can_manage_administrators boolean, is_active boolean);

create function private.append_admin_audit(
  actor_id uuid, action_key text, target_type text, target_id uuid,
  reason text, outcome text, before_summary jsonb, after_summary jsonb,
  correlation_id uuid, idempotency_key uuid
) returns uuid;
```

---

### Task 1: Scaffold the isolated web application

**Files:**
- Create: `AdminWeb/package.json`, `AdminWeb/package-lock.json`, `AdminWeb/next.config.ts`, `AdminWeb/tsconfig.json`
- Create: `AdminWeb/eslint.config.mjs`, `AdminWeb/postcss.config.mjs`, `AdminWeb/vitest.config.ts`, `AdminWeb/playwright.config.ts`
- Create: `AdminWeb/src/app/layout.tsx`, `AdminWeb/src/app/page.tsx`, `AdminWeb/src/app/globals.css`
- Create: `AdminWeb/src/test/setup.ts`, `AdminWeb/tests/smoke.spec.ts`

**Interfaces:**
- Produces: scripts `dev`, `build`, `lint`, `typecheck`, `test`, `test:e2e`; alias `@/* -> ./src/*`.

- [ ] **Step 1: Write the smoke test** asserting `/` redirects to `/sign-in` with `await expect(page).toHaveURL(/\/sign-in$/)`.
- [ ] **Step 2: Create the pinned package manifest** with Next.js, React, `@supabase/ssr`, `@supabase/supabase-js`, Tailwind, Radix Dialog/Dropdown/Tooltip, TanStack Table, Phosphor Icons, Zod, Vitest, Testing Library, and Playwright; generate and commit the lockfile.
- [ ] **Step 3: Create the minimal App Router layout** with `lang="en"`, imported Geist fonts, metadata `BlocLens Operations`, and a root redirect to `/overview`.
- [ ] **Step 4: Run** `cd AdminWeb && npm run typecheck && npm run lint && npm test -- --run`; expect all commands to exit 0.
- [ ] **Step 5: Commit** `AdminWeb/` foundation as `chore(admin-web): scaffold operations portal`.

### Task 2: Add staff capabilities and audit primitives

**Files:**
- Create: `supabase/migrations/20260912010000_admin_portal_foundation.sql`
- Create: `supabase/tests/admin_portal_foundation_test.sql`

**Interfaces:**
- Produces: `staff_capabilities`, `staff_invitations`, `admin_audit_events`; functions `current_staff_access()` and `private.append_admin_audit(actor_id, action_key, target_type, target_id, reason, outcome, before_summary, after_summary, correlation_id, idempotency_key)`; capability `can_manage_administrators`.

- [ ] **Step 1: Write pgTAP failures** proving non-staff sees no capability rows, Moderator lacks administrator management, audit rows reject update/delete, and invitation tokens are not selectable by `authenticated`.
- [ ] **Step 2: Run** `supabase test db`; expect the new assertions to fail because the relations do not exist.
- [ ] **Step 3: Add tables and constraints** including unique active invitation per lower-cased email, SHA-256 token digest only, invitation expiry, actor/target/action/reason/outcome audit columns, and `jsonb` safe summaries capped by check constraints.
- [ ] **Step 4: Add secure functions** with `security definer set search_path = ''`; `current_staff_access()` returns `{role, can_manage_administrators, is_active}`, while `append_admin_audit` is callable only from other protected functions.
- [ ] **Step 5: Add RLS and grants** so active staff can read authorised audit data, ordinary users see none, and no browser role can update or delete audit events.
- [ ] **Step 6: Run** `supabase db reset && supabase test db`; expect all schema and role tests to pass.
- [ ] **Step 7: Commit** as `feat(database): add admin access and audit foundation`.

### Task 3: Implement environment validation and Supabase clients

**Files:**
- Create: `AdminWeb/src/lib/env.ts`, `AdminWeb/src/lib/supabase/browser.ts`, `AdminWeb/src/lib/supabase/server.ts`, `AdminWeb/src/lib/supabase/middleware.ts`
- Create: `AdminWeb/src/lib/env.test.ts`, `AdminWeb/.env.example`

**Interfaces:**
- Produces: `env`, `createBrowserClient()`, `createServerClient()`, `updateSession(request)`.

- [ ] **Step 1: Write tests** that accept `NEXT_PUBLIC_SUPABASE_URL` plus `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, reject missing values, and ensure no server secret is exported from the browser module.
- [ ] **Step 2: Run** `cd AdminWeb && npm test -- --run src/lib/env.test.ts`; expect module-not-found failure.
- [ ] **Step 3: Implement Zod validation** and Supabase SSR cookie adapters; `.env.example` contains names and safe local values only, never a cloud credential.
- [ ] **Step 4: Run** unit tests, `npm run typecheck`, and `rg -n 'service_role|SUPABASE_SECRET' AdminWeb/src`; expect tests to pass and the scan to return no browser usage.
- [ ] **Step 5: Commit** as `feat(admin-web): add validated Supabase clients`.

### Task 4: Enforce authentication and active staff access

**Files:**
- Create: `AdminWeb/src/lib/auth/access.ts`, `AdminWeb/src/lib/auth/access.test.ts`, `AdminWeb/src/middleware.ts`
- Create: `AdminWeb/src/app/(auth)/sign-in/page.tsx`, `AdminWeb/src/app/(auth)/sign-in/actions.ts`
- Create: `AdminWeb/src/app/(auth)/forgot-password/page.tsx`, `AdminWeb/src/app/(auth)/update-password/page.tsx`
- Create: `AdminWeb/src/app/(auth)/password-actions.ts`, `AdminWeb/src/app/(portal)/sign-out-action.ts`
- Create: `AdminWeb/src/app/access-denied/page.tsx`, `AdminWeb/src/app/(portal)/layout.tsx`

**Interfaces:**
- Produces: `type StaffAccess = { userId: string; role: 'admin' | 'moderator'; canManageAdministrators: boolean }`; `requireStaff(): Promise<StaffAccess>`; `signIn(formData): Promise<ActionState>`.

- [ ] **Step 1: Write unit tests** for no session, inactive role, Moderator, Administrator, and owner capability; error copy is always `Unable to sign in with those credentials.`.
- [ ] **Step 2: Run** the focused test and confirm failure.
- [ ] **Step 3: Implement `requireStaff`** using `auth.getUser()` followed by `current_staff_access()`; redirect unauthenticated users to `/sign-in` and authenticated non-staff to `/access-denied`.
- [ ] **Step 4: Implement the sign-in Server Action** with Zod email/password validation and no account-enumerating branches; omit every signup link.
- [ ] **Step 5: Implement password recovery and sign-out** with a generic reset-request response, an allow-listed `/update-password` redirect, password confirmation validation, and `auth.signOut({ scope: 'local' })` followed by `/sign-in`.
- [ ] **Step 6: Add middleware** only for cookie refresh and protected-route routing; do not treat middleware claims as final authorisation.
- [ ] **Step 7: Run** focused tests, typecheck, lint, then Playwright checks for session restoration, staff success, password recovery, sign-out, and non-staff denial.
- [ ] **Step 8: Commit** as `feat(admin-web): enforce staff-only authentication`.

### Task 5: Build the approved portal shell and primitives

**Files:**
- Create: `AdminWeb/src/components/shell/app-shell.tsx`, `icon-rail.tsx`, `page-header.tsx`, `inspector.tsx`
- Create: `AdminWeb/src/components/ui/button.tsx`, `dialog.tsx`, `status-badge.tsx`, `data-table.tsx`, `empty-state.tsx`, `error-state.tsx`, `skeleton.tsx`
- Create: `AdminWeb/src/lib/messages/en.ts`, `AdminWeb/src/components/shell/app-shell.test.tsx`
- Modify: `AdminWeb/src/app/globals.css`, `AdminWeb/src/app/(portal)/layout.tsx`

**Interfaces:**
- Produces: `AppShell`, `Inspector`, `DataTable<TData>`, semantic tokens, and `messages` keyed English copy.

- [ ] **Step 1: Invoke `design-taste-frontend`** and read all required BlocLens design documents before editing UI.
- [ ] **Step 2: Write component tests** for six labelled destinations, bottom-rail notifications/account controls, visible keyboard focus, inspector focus restoration, and Moderator-hidden administrator controls.
- [ ] **Step 3: Implement tokens** for the cold off-white canvas, pale lavender surface, restrained blue-violet accent, 14px panels, 10px controls, 64px rail, 360px inspector, reduced motion, and WCAG-compliant focus rings.
- [ ] **Step 4: Implement responsive behaviour**: fixed inspector at 1280px+, overlay at 1024–1279px, horizontal table overflow at 768–1023px, and single-item-only narrow mode below 768px.
- [ ] **Step 5: Run** component tests and Playwright screenshots at 1440×1000, 1024×768, and 390×844 with reduced motion.
- [ ] **Step 6: Complete the visual checklist** and commit as `feat(admin-web): build operations shell`.

### Task 6: Implement closed staff invitations

**Files:**
- Create: `supabase/migrations/20260912020000_admin_staff_invitations.sql`
- Create: `supabase/tests/admin_staff_invitations_test.sql`
- Create: `AdminWeb/src/app/api/staff/invitations/route.ts`, `AdminWeb/src/app/(auth)/accept-invite/page.tsx`, `AdminWeb/src/app/(auth)/accept-invite/actions.ts`
- Create: `AdminWeb/src/lib/staff/invitations.ts`, `AdminWeb/src/lib/staff/invitations.test.ts`

**Interfaces:**
- Produces: protected functions `create_staff_invitation(email, role, token_digest, expires_at, reason)` and `accept_staff_invitation(token_digest)`; server helper `inviteStaff(input)`.

- [ ] **Step 1: Write pgTAP tests** for owner inviting either role, ordinary Administrator inviting Moderator only, Moderator rejection, revoked/expired/single-use tokens, and audited outcomes.
- [ ] **Step 2: Write Vitest tests** proving raw tokens exist only in the outgoing email link and the database receives only a digest.
- [ ] **Step 3: Implement the protected SQL functions** with transaction-level role revalidation and append-only audit events.
- [ ] **Step 4: Implement the trusted route** using the server-only Supabase administration client and a 32-byte cryptographically random token; return the same safe response whether an email already exists.
- [ ] **Step 5: Implement acceptance** to set the password, consume the invitation once, create/activate the permitted staff role, then redirect to `/overview`.
- [ ] **Step 6: Run** database, unit, and invitation Playwright tests.
- [ ] **Step 7: Commit** as `feat(admin-web): add closed staff invitations`.
