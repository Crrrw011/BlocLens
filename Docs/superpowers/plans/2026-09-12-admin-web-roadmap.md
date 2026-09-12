# BlocLens Administrator Web Portal Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved BlocLens Administrator Web Portal through four independently testable implementation plans.

**Architecture:** `AdminWeb/` is a separate Next.js App Router application that uses cookie-based Supabase SSR. Caller-scoped RLS serves ordinary reads; security-definer database functions and trusted server actions perform privileged mutations and append audit events.

**Tech Stack:** Next.js App Router, TypeScript, Supabase SSR, PostgreSQL/pgTAP, Tailwind CSS, Radix Primitives, TanStack Table, Phosphor Icons, Vitest, Testing Library, Playwright, Vercel.

**Spec:** `docs/superpowers/specs/2026-09-12-admin-web-design.md`

## Global Constraints

- Portal access is limited to active BlocLens Administrators and Moderators.
- Public signup is absent; staff access is invitation-only.
- Browser code receives only the Supabase URL and publishable key; secrets remain server-only.
- Private Logbook entries and private notes must never be queried or displayed.
- Beta media remains external-public-link-only; no video upload or hosting is introduced.
- User-facing copy ships in English and is routed through a localisable message module.
- Every UI task reads `docs/design/DESIGN.md`, `docs/VisualSystem.md`, and `docs/design/UI-REVIEW-CHECKLIST.md`, and invokes `design-taste-frontend` before implementation and visual review.
- Every database change adds pgTAP coverage and passes `supabase test db`.
- Every web change passes typecheck, lint, unit tests, and the relevant Playwright project.

---

## Ordered execution

1. `docs/superpowers/plans/2026-09-12-admin-web-foundation-access.md`
   Produces the application shell, SSR authentication, staff capability model, invitation flow, audit primitive, and protected-route tests.
2. `docs/superpowers/plans/2026-09-12-admin-web-review-operations.md`
   Produces the overview dashboard, moderation queue, inspector, decision actions, and queue E2E coverage.
3. `docs/superpowers/plans/2026-09-12-admin-web-climbing-data.md`
   Produces searchable entity management, route merge, archive/restore, and guarded permanent deletion.
4. `docs/superpowers/plans/2026-09-12-admin-web-people-audit-release.md`
   Produces user penalties, staff access management, gym claims, audit export, safe configuration, and deployment readiness.

## Release gates

- [ ] **Gate 1:** A seeded Moderator and Administrator can sign in; a non-staff user cannot render protected content.
- [ ] **Gate 2:** Review decisions update queue state and append immutable audit events.
- [ ] **Gate 3:** Data management, merge, archive, restore, and eligible hard deletion preserve all declared invariants.
- [ ] **Gate 4:** Roles, penalties, claims, audit, configuration, and Vercel Preview pass the final acceptance matrix.

## Specification coverage

| Specification area | Owning plan |
| --- | --- |
| Roles, SSR sessions, sign-in, password reset, sign-out, invitations | Foundation and Access |
| Navigation shell, responsive inspector, accessibility, localisable copy | Foundation and Access |
| Overview metrics, review queues, reports, corrections, review actions | Review Operations |
| Gyms, wall zones, routes, resets, photos, beta links, comments | Climbing Data |
| Archive, restore, merge, dependency impact, permanent deletion | Climbing Data |
| User restrictions, suspensions, bans, staff access, gym claims | People, Audit, and Release |
| Immutable audit, IP retention, export, safe configuration | People, Audit, and Release |
| Local/Staging/Production separation, Vercel, final acceptance | People, Audit, and Release |
