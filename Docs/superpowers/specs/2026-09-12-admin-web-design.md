# BlocLens Administrator Web Portal Design

Status: Approved in chat on 12 September 2026

Product surface: Separate internal web application

Implementation location: AdminWeb inside the BlocLens repository

Visual reference: AdminWeb/design-preview/index.html

## 1. Purpose

BlocLens needs a separate web portal for platform administration and moderation. The portal closes operational workflows that do not belong in the iPhone application: reviewing reports and corrections, maintaining climbing data, merging duplicate routes, managing staff access, applying user penalties, and reviewing an immutable audit history.

The portal is an internal operational tool. It is not a consumer website, a replacement for the iPhone app, or a Verified Gym workspace. Only authorised BlocLens Administrators and Moderators may sign in.

## 2. Approved decisions

- Build the complete administration scope rather than a moderation-only subset.
- Restrict the portal to BlocLens platform Administrators and Moderators.
- Use email and password authentication.
- Disable public registration and use an invitation-only staff flow.
- Use Next.js App Router with TypeScript and Supabase SSR.
- Use the existing Supabase database, RLS model, migrations, and authenticated identities.
- Use caller-scoped RLS for ordinary reads and protected server operations for privileged mutations.
- Build a custom light enterprise interface based on the supplied visual reference.
- Use Tailwind CSS, Radix Primitives, TanStack Table, and Phosphor Icons.
- Apply the design-taste-frontend skill to every UI design, implementation, and visual review.
- Use a task and entity hybrid information architecture.
- Use a right-side contextual inspector for quick work and full pages for complex work.
- Allow one authorised Administrator to execute high-risk actions after confirmation and reason entry.
- Permit permanent deletion for selected content with two consecutive warnings.
- Place the independent Next.js application in AdminWeb in the current repository.
- Deploy through Vercel.
- Deliver the complete portal for one final acceptance, while verifying internal vertical slices during implementation.
- Ship the first version in English only while keeping all user-facing strings localisable.

## 3. Scope

### 3.1 Included

- Staff authentication, session restoration, password reset, and sign-out.
- Closed staff invitation, role assignment, access revocation, and staff deactivation.
- Operations dashboard.
- Moderation and correction queues.
- Gym, wall-zone, route, reset, route-photo, beta-link, and comment management.
- Route archival, restoration, duplicate review, and transactional merge.
- User contribution restrictions, suspensions, and permanent bans.
- Gym-claim review.
- Immutable administrative audit records.
- Safe operational configuration that does not rewrite frozen product rules.
- Local, Staging, and Production environment separation.
- Desktop-first responsive behaviour and keyboard accessibility.

### 3.2 Excluded

- Consumer accounts, public signup, and general user-facing web pages.
- Verified Gym access to the portal.
- Reading private Logbook records, private climbing notes, passwords, or authentication tokens.
- Direct video upload, video hosting, transcoding, caching, mirroring, or media delivery.
- A 2D wall map or floor-plan editor.
- Direct editing of community-grade aggregates or Helpful counts.
- Editing frozen MVP rules through Configuration.
- Exposing a Supabase secret key or legacy service-role key to browser code.

## 4. Roles and capabilities

### 4.1 Moderator

A Moderator may:

- View moderation queues and the public context required to make a decision.
- Dismiss or escalate a report.
- Hide and restore routes, route photos, beta links, and comments where policy permits.
- Add an internal moderation note.
- View relevant audit events.

A Moderator may not:

- Permanently delete content.
- Archive or merge routes.
- Penalise or permanently ban a user.
- Invite staff, modify roles, or deactivate staff access.
- Approve gym claims.
- Modify operational configuration.

### 4.2 Administrator

An Administrator has all Moderator capabilities and may also:

- Permanently delete eligible content using the two-warning flow.
- Archive, restore, and merge routes.
- Apply or remove user restrictions, suspensions, and permanent bans.
- Review and decide gym claims.
- Manage staff invitations and roles within the capability granted to that Administrator.
- Modify safe operational configuration.
- Export audit data.

### 4.3 Bootstrap owner capability

The first Administrator is bootstrapped outside the portal through a trusted Supabase administration path. That account receives a protected can_manage_administrators capability. It may invite Administrators and Moderators. An ordinary Administrator without that capability may invite Moderators but cannot create another Administrator or grant itself additional authority.

Authorisation data must live in protected server-controlled role or capability records. It must not use user-editable metadata.

## 5. System architecture

The browser sends a secure cookie session to the Next.js App Router application. Server Components perform authenticated reads. Small Client Components handle tables, filters, dialogs, and inspectors. Server Actions or Route Handlers receive mutations. Ordinary reads use the caller JWT and existing RLS. Privileged mutations cross a protected RPC or Edge Function boundary and write an audit record.

### 5.1 Web application

- Server Components are the default.
- Client Components are limited to interactions that require browser state.
- Authenticated routes are dynamic and must not be publicly cached.
- The session is validated on the server before protected content renders.
- Each mutation validates the current user again and does not trust role information supplied by the browser.
- Package versions are pinned and lockfiles are committed.

### 5.2 Data access

Ordinary reads use the current staff member's JWT and RLS. This includes queues, public route context, gym data, and audit rows that the role is permitted to view.

High-risk actions use a protected server operation. This includes permanent deletion, route merge, staff invitation, role changes, permanent bans, and configuration changes.

The browser receives only a publishable Supabase key. Any secret key is restricted to the trusted server runtime and used only by narrowly scoped code paths that require it.

### 5.3 Administrative action contract

Every administrative mutation carries:

- Action type.
- Target type and target identifier.
- Human-readable reason.
- Optional internal note.
- Idempotency key.
- Expected current version or state.

The server:

1. Validates the session.
2. Reads the current role and capability from protected data.
3. Validates the target and allowed state transition.
4. Executes the mutation transactionally where possible.
5. Writes the audit event.
6. Returns the confirmed server result.

## 6. Authentication and staff invitation

### 6.1 Sign-in

- Email and password only.
- No signup link or public registration route.
- Generic error text prevents account enumeration.
- Rate limiting and abuse protection apply to sign-in and password reset.
- Successful authentication is not sufficient; the server must confirm an active Administrator or Moderator role.
- A user without an active staff role is signed out of the portal and shown an access-denied page.

### 6.2 Invitation

- The first staff account is bootstrapped through a trusted Supabase administration path.
- An authorised Administrator submits an email address and permitted role.
- A trusted server action creates the invitation.
- The recipient uses a single-use invitation link to set a password.
- Accepting an invitation does not bypass server-side role validation.
- Invitations can expire, be revoked, or be resent.
- Invite creation, acceptance, revocation, expiry, and role assignment are audited.

### 6.3 Session handling

- Use secure, HTTP-only cookie-based SSR sessions.
- Sign-out revokes the current session.
- Staff deactivation prevents new privileged requests even if an older access token has not yet expired.
- Sensitive mutations verify current server-side access rather than relying only on stale JWT claims.

## 7. Information architecture

The icon rail contains six primary destinations:

1. Overview.
2. Review.
3. Climbing Data.
4. People and Access.
5. Audit.
6. Configuration.

The account menu and notifications entry sit at the bottom of the rail.

### 7.1 Overview

- Pending reports.
- Severe reports.
- Pending corrections.
- Possible duplicate routes.
- Pending gym claims.
- Recently hidden content.
- Review trend.
- Queue distribution.
- Median handling time.
- Recent administrative actions.
- System failures requiring attention.

### 7.2 Review

- Route reports and corrections.
- Route-photo reports.
- Beta-link reports.
- Comment reports.
- Severe safety content.
- Hidden-content review.
- Dismiss, hide, restore, escalate, archive, delete, and penalise actions according to role.

### 7.3 Climbing Data

- Gyms.
- Wall Zones.
- Routes.
- Reset records.
- Route photos.
- Beta links.
- Comments.

All lists support search, filtering, sorting, pagination, column visibility, and stable URLs.

Route merge includes an impact preview showing affected Logbook references, photos, beta links, comments, votes, and conflicts. The operation selects a canonical route, migrates supported relationships transactionally, resolves conflicts deterministically, archives the source, and writes a detailed audit event.

### 7.4 People and Access

- Search public profile and contribution history.
- View existing restrictions and penalties.
- Apply, modify, and remove contribution restrictions.
- Suspend or permanently ban a user.
- Invite staff.
- Revoke invitations.
- Modify permitted staff roles.
- Deactivate portal access.
- Review gym claims.

Private Logbook entries and private notes are never queried or displayed.

### 7.5 Audit

- Filter by actor, action, target, date, and outcome.
- View before and after summaries.
- View failure reason where an action failed.
- Export allowed audit fields.
- No portal action can update or delete an audit row.

### 7.6 Configuration

Editable operational settings include review reason templates, penalty reason templates, queue ordering, dashboard date range, and approved non-core feature flags.

Frozen product rules are read-only. This includes reporting thresholds, the Trusted Contributor threshold, grade calculations, and private-by-default behaviour.

## 8. Permanent deletion

Permanent deletion is limited to an Administrator and to content types with an explicitly implemented deletion policy.

### 8.1 Two-warning flow

The first warning shows:

- Exact target.
- Current status.
- Number and type of dependent records.
- Storage objects affected.
- What will remain in audit history.
- Whether archival or anonymisation is available instead.

The second warning requires:

- A mandatory reason.
- Typing DELETE exactly.
- A final irreversible-action button.

The server then revalidates the role and current target state.

### 8.2 Restrictions

- A route referenced by Logbook history cannot be permanently deleted. It must be archived or merged.
- A gym or wall zone with retained historical relationships cannot be permanently deleted.
- User account deletion follows the existing account-deletion and contribution-anonymisation policy.
- Eligible media or comments may be permanently deleted only when dependent references are handled safely.
- Deleting Storage bytes and database metadata must use a recoverable ordered workflow with explicit failure reporting.

The permanent audit tombstone retains target type, former target identifier, actor, reason, timestamp, outcome, and a safe change summary. It does not retain prohibited private content.

## 9. Visual and interaction design

### 9.1 Design read

This is a desktop internal operations dashboard for BlocLens administrators, with a light editorial enterprise language, low motion, and medium-high information density.

- Design variance: 4.
- Motion intensity: 2.
- Visual density: 7.

### 9.2 Layout

- A 64-pixel icon rail.
- A flexible central workspace.
- A 360-pixel contextual inspector on wide screens.
- At 1024 to 1279 pixels, the inspector becomes an overlay drawer.
- At 768 to 1023 pixels, tables may scroll horizontally.
- Below 768 pixels, single-item review remains available but complex merge and batch work are disabled.

### 9.3 Visual language

- Cold off-white canvas.
- White and pale lavender surfaces.
- Near-black primary text and cool-grey secondary text.
- One restrained blue-violet brand accent.
- Semantic red, amber, and green appear only for real states.
- No decorative gradients, neon glows, broad glass effects, or heavy shadows.
- Panels use 14-pixel radii.
- Inputs and table controls use 10-pixel radii.
- Standalone actions use pill shapes.
- Icon-only actions use circular targets.
- Geist is the primary typeface; Geist Mono is reserved for identifiers and numeric data.
- Phosphor is the only icon family.

### 9.4 Interaction

- Selecting a row opens the right inspector without losing list position.
- Complex work opens a stable full-page URL.
- Closing a detail view preserves filters, page, selection, and scroll position.
- Keyboard focus is always visible.
- Dialogs trap and restore focus correctly.
- Command-K focuses global search.
- Escape closes the topmost dismissible layer.
- Motion communicates state changes only and respects reduced-motion preferences.

### 9.5 Page states

Every module includes:

- Layout-matched skeleton loading.
- Empty state with a relevant next action.
- Inline validation errors.
- Recoverable server error with retry.
- Access denied.
- Session expired.
- Deleted or unavailable target.
- Stale-data conflict.
- Partial-operation failure where applicable.

Production views never display invented metrics. Fixtures and visual prototypes must label sample data clearly.

## 10. Data flow and concurrency

### 10.1 Read flow

1. A protected route validates the cookie session.
2. The server confirms an active staff role.
3. The server queries using the caller-scoped Supabase client.
4. RLS returns only authorised data.
5. The page renders server-side.
6. Client-side filtering state is reflected in URL query parameters where sharing or restoration matters.

### 10.2 Mutation flow

1. The browser submits a typed action with target version and idempotency key.
2. The server validates the input.
3. The server revalidates session, role, and capability.
4. The server checks the current target version.
5. The operation runs.
6. The audit record is written.
7. Relevant pages are revalidated.
8. The UI presents the confirmed result.

If the target changed after it was loaded, the operation stops and shows a conflict comparison. The administrator must review fresh data before resubmitting.

### 10.3 Long operations

Route merges, bulk actions, exports, and storage deletion may become asynchronous jobs. The UI shows queued, running, completed, partially failed, and failed states. Retrying uses the original idempotency key or a server-issued retry token so the same operation is not duplicated.

## 11. Error handling

- Authentication errors never disclose whether an email is registered or privileged.
- Authorisation errors produce a dedicated access-denied state and no protected payload.
- Validation errors appear beside the responsible field.
- Network and server errors retain unsent form input.
- Stale data produces a conflict state, not a silent overwrite.
- A failed mutation never presents success.
- Partial bulk failures identify successful and failed targets without requiring the whole batch to be guessed.
- Destructive operation failures preserve the audit attempt and show whether any data changed.
- Unexpected errors receive a trace identifier that can be correlated with server logs without exposing secrets.

## 12. Audit and privacy

Audit records are append-only from the portal's perspective. Each event records actor, action, target, reason, safe before and after summaries, timestamp, request correlation identifier, outcome, and failure category.

Source IP may be retained for security investigation for 90 days, then reduced to a non-reversible correlation value. Permanent audit history does not retain raw IP indefinitely. Audit exports exclude secrets, tokens, passwords, private Logbook content, and private notes.

## 13. Environments and deployment

### 13.1 Local

- Local Next.js development server.
- Local Supabase stack and seed identities.
- Safe deterministic fixture data.

### 13.2 Staging

- Vercel Preview deployments.
- Existing Supabase project atmtqesdhxpgnrjedwsu.
- Test staff accounts and non-production data only.

### 13.3 Production

- Vercel Production deployment.
- A new separate Supabase project.
- No development seed.
- Separate environment variables, staff accounts, Auth redirects, Storage, functions, and monitoring.

All environments apply the same migration sequence. Production promotion requires a migration review, database advisor review, automated tests, and a verified Staging deployment.

## 14. Project structure

AdminWeb contains the independent Next.js application, its source code, component tests, end-to-end tests, package manifest, lockfile, and deployment configuration. The existing root-level supabase directory remains the single source of database migrations and Edge Functions used by iOS and Web.

The AdminWeb application is not added to the Xcode project and does not import Swift code.

## 15. Testing

### 15.1 Unit and component

- Input schemas and permission decisions.
- Queue filtering and sorting.
- Destructive confirmation state machine.
- Route-merge impact presentation.
- Error and empty states.
- Design-token and accessibility checks where deterministic.

### 15.2 Integration

- Password sign-in and role rejection.
- Invitation, expiry, revocation, and acceptance.
- RLS coverage for Moderator and Administrator.
- Protected mutation capability checks.
- Audit creation for success and failure.
- Idempotency and stale-version conflict.
- Route merge and dependent-record preservation.
- Permanent deletion restrictions.

### 15.3 End to end

- Sign in, session restoration, and sign-out.
- Moderator review flow.
- Administrator archive and restore flow.
- Route merge impact review and execution.
- User restriction and reversal.
- Staff invitation and deactivation.
- Two-warning permanent deletion.
- Audit lookup and export.
- Keyboard navigation and focus restoration.
- Desktop and supported narrow layouts.

### 15.4 Visual review

Every UI milestone invokes design-taste-frontend and checks:

- Reference fidelity.
- Visual hierarchy and data density.
- Consistent radius and colour roles.
- Light-theme contrast.
- Keyboard focus.
- Reduced motion.
- Loading, empty, error, and denied states.
- No default-template appearance.

## 16. Delivery and acceptance

Although implementation is validated internally by vertical slice, the user receives one complete acceptance build.

Acceptance requires:

- All approved modules are functional.
- Automated tests pass.
- Staging migrations and security checks pass.
- No secret appears in browser assets or repository history.
- Moderator and Administrator permissions match this specification.
- Permanent deletion uses both warnings.
- Private Logbook and note data are absent from portal queries and screens.
- The supplied HTML preview remains the visual baseline unless a later approved design revision replaces it.
- The Vercel Preview deployment works against Staging.
- A production-readiness report lists the exact manual steps needed to create and verify the new Production Supabase project.

## 17. Reference prototype

The approved visual prototype is AdminWeb/design-preview/index.html. It demonstrates the navigation rail, operations overview, charts, priority queue, search, urgent filtering, responsive layout, and contextual inspector. Its values are labelled preview data and are not production fixtures.
