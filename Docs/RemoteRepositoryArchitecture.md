# BlocLens Remote Repository Architecture

## Status and stage boundary

This document records the Stage 6D-1 remote boundary work. The app still launches entirely with the Mock repositories. There is no Supabase Swift SDK, no network client, no remote project, no credential, and no connection to any Supabase environment (local or cloud). Stage 6D-2 introduces the Supabase Swift SDK and local read-only queries; Stage 6D-3 introduces authentication and Logbook synchronisation.

## Mock remains the default

`AppEnvironment.development(...)` is the Mock/development factory and remains the only implementation wired into `BlocLensApp`. Previews, launch arguments and UI tests continue to use Mock repositories. No Release path switches to a remote implementation in this stage.

## Remote DTO and mapping boundary

Transport records live in `BlocLens/Persistence/Remote` and are `Codable`/`Equatable`/`Sendable`. They use snake-case coding keys, Foundation `UUID` values, and the ISO 8601 decoding strategy in `RemoteJSONCoding`. Domain values map from these records through pure functions that fail safely via `RemoteMappingError`; none force-unwrap or crash.

The established DTO set is `GymRecord`, `GymFacilityRecord`, `WallZoneRecord`, `ResetRecord`, `GymHardSoftBandRecord`, `RouteRecord`, `CommunityGradeRecord`, `BetaLinkRecord`, `LogbookEntryRecord`, `UserProfileRecord` and `PublicProfileRecord`. They are transport types, never SwiftUI state.

## Gym multi-source aggregation

A complete `Gym` is composed from several sources, never a single row:

- base summary from `gym_summaries` (`GymRecord`);
- facilities from `gym_facilities` (`GymFacilityRecord`);
- wall zones from `wall_zone_summaries` (`WallZoneRecord`);
- the overall hard/soft assessment from the `gym_hard_soft_summary(gym_id)` RPC (`GymHardSoftBandRecord`).

`GymHardSoftMapping.overallSummary(from:)` derives the overall `HardSoftSummary` from the RPC's `Overall` band row. A `not_enough_community_data` assessment maps to `.insufficientData`; a missing `Overall` row or an unknown assessment fails mapping rather than fabricating a statistic. `GymRecord` no longer carries a fictional `overall_hard_soft_summary` column.

## Route multi-source aggregation

`RouteRecord` maps from `route_summaries` and does not assume aggregate columns that the view does not expose. The community grade is supplied by `community_grade_summary(route_id)` through `CommunityGradeRecord`, and the photo reference comes separately from `route_photos`. The community median is published only at three or more distinct valid votes and always uses the median. Archived routes map to `.archived` and remain distinct from current routes. The write-side decision between `colour` and `label` for route creation is not frozen in this stage; reads preserve the existing single `colourOrTag` domain compatibility.

## Logbook soft-delete rule

`LogbookEntryRecord.domain()` rejects rows with a non-null `deleted_at`: a soft-deleted record is never presented as an active `LogbookEntry`. The remote read query must filter `deleted_at IS NULL` as part of the repository query contract; RLS alone does not hide an owner's own soft-deleted rows. There is no delete or restore implementation in this stage.

## Repository error semantics

`RepositoryError` now distinguishes not-found, unavailable, offline, unauthenticated, forbidden, network failure, timeout, rate limiting, decoding/mapping failure, invalid configuration, and unknown failure, alongside the original Mock-specific cases. Views are not required to handle every case yet; new cases are added without breaking existing call sites. No SDK error type is exposed, and no secret material is placed into user-visible errors.

## Public profile privacy boundary

`PublicUserProfile` is a small domain type mapped from `PublicProfileRecord` (the `public_profiles` view): `username`, `avatar_path`, optional body dimensions, `regular_grade` and `is_trusted_contributor` only. It excludes email, auth provider, private note, Logbook content, the age-confirmation timestamp, and any raw role enum. `UserProfile` (the owner's full application profile) is not reused for public display.

## AppEnvironment and Mock-scenario isolation

`AppEnvironment` no longer exposes `MockRepositoryScenario`. The Mock factory still accepts a scenario, but the production struct exposes a neutral `DataAvailability` (`online`/`offlineCached`). View models derive the `.offlineWithCache` presentation from `dataAvailability` rather than inspecting the repository implementation. Mock-specific `empty`/`error`/`offline-without-cache` behaviours continue to flow through the repositories themselves (empty results or thrown `RepositoryError` values), not through a scenario flag.

## Remote configuration boundary

`RemoteConfiguration` is a small value type holding a project URL and a publishable/anon key. It fails safely with `RepositoryError.invalidConfiguration` when the URL is not HTTPS or the key is blank. It deliberately has no service-role key, database password, JWT secret or other server secret. Local, test and production environments are isolated by supplying different configuration values, never by branching inside the domain layer.

## Guest versus beta access — resolved in 6D-2A

The PRD (§2.1) states that viewing beta requires login. Stage 6D-2A enforces this in the database: migration `0011_harden_beta_access_and_search.sql` revokes `SELECT` on `beta_links` and `beta_ranking_inputs` from the `anon` role. Guests keep public discovery surfaces (`gym_summaries`, `wall_zone_summaries`, `route_summaries`) and a sanitised beta count via the `visible_beta_count_for_route(uuid)` SECURITY DEFINER helper; they can no longer read any beta URL, platform, author, tag or health metadata. The SwiftUI Reveal gate is not the security boundary. A pgTAP contract test asserts the anonymous-access denial and the preserved authenticated read path.

## Block filtering direction

Blocked users' beta, comments and profile content must be excluded by a server-side security query (RPC or a filtered view), not by a Swift array filter in a view. The remote repository uses that secure query as the only normal read entry point; the Mock repository mirrors the same behaviour for tests. `user_blocks` remains private under RLS. No Block implementation ships in this stage.

## Account deletion direction

Account deletion from the app uses a controlled server-side entry point: the `delete-account` Supabase Edge Function. The `service_role` key exists only in the function's `SERVICE_ROLE_KEY` secret; the iPhone app never contains a service-role key, database password or JWT secret. The function is `verify_jwt`-enabled and never accepts a target user id from the client — it resolves the caller from the verified JWT and deletes only that user. Deleting the auth user triggers the database cascade: private data (profile, Logbook, follows, blocks, votes, Helpful) is removed via `ON DELETE CASCADE`, and public contributions (routes, beta links, comments, photos, resets) are anonymised via `ON DELETE SET NULL`. The app presents a destructive confirmation before calling the function and drops to the guest state on success.

## Search index discrepancy — resolved in 6D-2A

`DataArchitecture.md` describes a `pg_trgm` GIN index for gym-name search. Migration `0011` installs the `pg_trgm` extension in the `extensions` schema and adds trigram GIN indexes on `lower(gyms.name)`, `lower(gyms.suburb)`, `lower(wall_zones.name)`, `lower(routes.colour)` and `lower(routes.label)`. Username is intentionally excluded because the MVP search never targets users.

## Client secret prohibitions

The iPhone app must never contain a `service_role` key, database password, JWT secret or any server secret. Only a non-secret project URL and publishable/anon key may be configured client-side. Configuration must be supplied via a git-ignored local source and never committed.

## Supabase Swift SDK (6D-2B)

The official SDK is installed as an Xcode Swift Package at `https://github.com/supabase/supabase-swift.git`, pinned to exact version `2.51.0`. Only the `Supabase` product is linked (to the app and unit-test targets); `Storage`, `Realtime`, `Functions` and `Auth` write flows are not used in this stage. The resolved dependency lock lives at `BlocLens.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. The SDK's transitive runtime dependencies are Apple's `swift-crypto`, `swift-asn1` and `swift-http-types`, plus pointfree.co's `swift-clocks`, `swift-concurrency-extras` and `xctest-dynamic-overlay`.

## Client composition root

`SupabaseClientFactory.makeClient(configuration:)` is the only place a `SupabaseClient` is created; there is no global `SupabaseClient` singleton. The client flows through `SupabaseRemoteDataSource` into the actor-backed `RemoteGymRepository` and `RemoteRouteRepository`. Domain models, view models and views never import Supabase.

## Remote data sources and repositories

- `RemoteGymDataSource` / `RemoteRouteDataSource` are small protocols implemented by `SupabaseRemoteDataSource`, which performs the SDK queries (`gym_summaries`, `gym_facilities`, `wall_zone_summaries`, `route_summaries`, and the `gym_hard_soft_summary` / `community_grade_summary` RPCs) and maps SDK errors through `RemoteErrorMapping`.
- `RemoteGymRepository` aggregates gym base data, facilities, wall-zone IDs and the overall hard/soft assessment. `RemoteRouteRepository` composes route summaries with the per-route community grade RPC and applies the shared filter/sort contract. Community grades are fetched with a bounded concurrency limit (8 in flight); this is a documented N+1 limitation to revisit after 6D-2B.
- The beta count is read from the sanitised `beta_count` column already present on the summary views; the repositories never read `beta_links` or a beta URL. Beta metadata awaits authentication in 6D-3.

## Configuration and Mock default

`RemoteConfiguration` carries an environment mode (`production`, `localDevelopment`, `integrationTest`). Production accepts HTTPS only; local/integration modes accept loopback HTTP (`127.0.0.1`, `localhost`, `::1`) and reject `.supabase.co` hosts. `LocalEnvironmentConfiguration.make()` reads `BLOCLENS_SUPABASE_URL` and `BLOCLENS_SUPABASE_ANON_KEY` from the environment and returns `nil` when absent, so a missing configuration never falls back to Cloud.

`AppEnvironment.development()` (Mock) remains the default everywhere. `AppEnvironment.localSupabase(configuration:)` and `AppEnvironment.cloudSupabase(configuration:)` both delegate to one composition root that creates exactly one `SupabaseClient` for Gym, Route, Beta, Logbook and Authentication. Debug selects the matching environment explicitly with `--local-supabase` or `--cloud-supabase`; missing or invalid configuration fails immediately instead of silently falling back to Mock. Release remains Mock-only until the production data-source switch is explicitly approved.

Local and Cloud Supabase sessions are intentionally never combined. A Cloud-issued JWT cannot authenticate against the Local project's RLS boundary because the projects have separate Auth users and signing configuration. Local mode is for deterministic integration testing. Cloud mode is the future end-to-end Auth and data path after the approved migrations are deployed.

## Authentication state machine (6D-3A)

`SupabaseAuthenticationRepository` is an actor-backed `AuthenticationRepository` that drives a local authentication state machine against the local Supabase Auth endpoint only:

```text
guest → authenticating → signedIn
                       ↘ profileSetup → signedIn
                       ↘ ageGated
                       ↘ error(RepositoryError)
```

- `guest` represents signed-out / browsing as a guest.
- `authenticating` is set while a sign-in or sign-up request is in flight.
- `profileSetup(UserProfile)` means the user is authenticated but has not completed the required public username (or the 16+ self-declaration).
- `ageGated` means the user declared they are under 16; they stay a guest and no account is used.
- `signedIn(UserProfile)` is the completed state.
- `error(RepositoryError)` carries a mapped, user-safe error.

The username and the 16+ declaration are stored on the `profiles` table (`username` and `age_confirmed_16_plus_at`), updated through the PostgREST API with the user's own JWT under the owner RLS policy. A fresh user receives an auto-generated `climber_…` placeholder username from the profile-initialisation trigger, which the repository treats as "setup not complete". Profile updates use `returning: .minimal` so the restricted column-level grants do not require a full-row select.

Session restore relies on the SDK's own Keychain-backed session storage: `restoreSession()` checks `client.auth.currentSession` and re-reads the profile. Pending-action recovery is unchanged: `AppSession` keeps the existing `ProtectedIntent` mechanism and resumes the intent when the state reaches `.signedIn`.

## Auth error mapping

`RemoteErrorMapping` additionally maps SDK `AuthError` cases: `sessionMissing` → `.unauthenticated`, `weakPassword` → `.invalidInput`, and `api` error codes `invalid_credentials`/`email_not_confirmed` → `.unauthenticated`, `user_not_found` → `.notFound`, `weak_password` → `.invalidInput`, `user_already_exists`/`email_exists` → `.conflict`. The PostgREST unique-violation code `23505` maps to `.conflict`. Real GoTrue sign-in never distinguishes an unknown user from a wrong password, so an unknown-account sign-in surfaces as `.unauthenticated` (anti-enumeration).

## Local integration tests

`LocalSupabaseIntegrationTests` is an XCTest suite that skips (`XCTSkip`) unless `BLOCLENS_SUPABASE_URL` and `BLOCLENS_SUPABASE_ANON_KEY` are set. It asserts the local read path (gyms, wall zones, routes, facilities, hard/soft, archived mapping, community-grade thresholds and the guest-safe beta count), verifies that the anonymous client cannot read `beta_links` or `beta_ranking_inputs`, and exercises the authentication and beta flows (sign-up → profile setup → username → beta metadata → reveal → Helpful → community-grade vote) using fresh local test accounts created via `signUp`. It performs no writes beyond the test account's own profile, Helpful vote, report, grade vote and test beta, and never connects to Cloud. Because the integration tests insert development rows, they must run after `supabase db reset --local` and before any seed-count pgTAP assertion.

## Authenticated beta reading and interactions (6D-3B)

`BetaRepository` was extended with authenticated methods: `betaMetadata(for:)`, `revealBeta(_:)`, `markHelpful(_:)`, `reportBeta(_:reason:)`, `communityGradeVote(routeID:grade:)`, `myGradeVote(for:)`, plus the safety-confirmation pair `hasConfirmedSafety()`/`confirmSafety()`.

`RemoteBetaRepository` is an actor backed by `RemoteBetaDataSource`/`SupabaseBetaDataSource`:

- Beta metadata reads `beta_links` with the user's JWT (migration 0011 leaves `beta_links` unreadable by `anon`), and filters out beta submitted by users the current user has blocked (fetched from `user_blocks`). The beta record decodes `submitted_by` so the block filter runs in the repository layer; `beta_links` never carries a video or image payload, only external-link metadata.
- Reveal returns the full beta record (including the external URL) only after authentication; the caller opens the URL with `UIApplication.shared.open` and never embeds a WebView or player.
- Helpful writes `beta_helpful_votes` (`(beta_link_id, user_id)` primary key enforces one vote per user; RLS plus the `validate_beta_helpful_vote` trigger prevent self-votes). A duplicate vote surfaces as `.conflict`; a self-vote is rejected by the database.
- Reports write `content_reports` with `target_type = 'beta_link'` and a category of `broken_link`, `wrong_route` or `unsafe_content`; automatic hiding remains the administrator/RLS concern, not this stage.
- Community grade votes are attempt-gated: the repository checks `has_attempted_route(route_id)` first and throws `.invalidState` when the user has no projecting/sent/flash Logbook entry. The write is an insert on first vote and an update of `v_grade` thereafter (the table grants only `UPDATE (v_grade)`, so a PostgREST upsert would fail with `42501`; insert/update is used instead). `myGradeVote` reads the user's current vote. The `< 3 votes hide the median` rule stays on the `community_grade_summary` RPC.
- Safety confirmation is stored in the Supabase user metadata (`beta_safety_confirmed_at`) because no schema change is permitted in this stage; it is read and written through `client.auth.update(user:)`.

Mock `MockBetaRepository` implements the same protocol in memory for parity.

## Private Logbook and offline queue (6D-3C)

`LogbookRepository` gained `hasAttemptedRoute(_:)`, `saveEntry(_:)`, `deleteEntry(_:)`, `pendingSyncCount()` and `syncNow()` alongside the existing read methods. `LogbookSyncState` now has `queued`, `synced` and `failed`; `RepositoryError` gained `.persistenceError` for local-store failures.

`RemoteLogbookRepository` is an actor backed by `RemoteLogbookDataSource`/`SupabaseLogbookDataSource` and a `LogbookQueue`:

- Reads query `logbook_entries` with the user's JWT and an explicit `deleted_at IS NULL` filter (the owner RLS filters by user but not by soft delete), then merge the still-pending local queue entries so offline writes remain visible.
- Writes upsert `logbook_entries` on `(user_id, route_id)` (the table grants full insert/update/delete, so the PostgREST merge-duplicates upsert is safe here). Each write carries a stable `client_idempotency_key` derived from the entry identifier, so retries of the same logical write are deduplicated by the existing `(user_id, client_idempotency_key)` unique constraint.
- Soft delete PATCHes `deleted_at` rather than removing the row.
- The attempt gate (`hasAttemptedRoute`) reuses the `has_attempted_route(route_id)` security-definer RPC.

The offline queue is a small actor (`FileBackedLogbookQueue`, with an `InMemoryLogbookQueue` for tests) that persists `PendingLogbookOperation` records as Codable JSON in Application Support. `saveEntry`/`deleteEntry` write directly when online and authenticated, and otherwise enqueue. `syncNow()` drains the queue first-in/first-out, removes successful operations, and marks failures with an incremented `retryCount` plus `lastError` for a later retry (exponential backoff is applied by the caller). Pending entries surface in `entries` with a `.queued`/`.failed` sync state.

`AppEnvironment.localSupabase` now wires `RemoteLogbookRepository` with a file-backed queue; `AppEnvironment.development()` keeps `MockLogbookRepository` as the default. A guest (no session) cannot read or write the Logbook.

## Apple and Google OAuth (6D-3D)

`AuthenticationRepository` provides Apple and Google sign-in through the same `SupabaseClient` used by the selected remote repositories. Cloud mode is constructed only in Debug from `BLOCLENS_CLOUD_URL` and `BLOCLENS_CLOUD_ANON_KEY` (never hardcoded; `Config.local.example` carries placeholders only). The `--cloud-supabase` launch argument requires both values; an absent or invalid value fails explicitly during Debug bootstrap rather than falling back to another data source.

- Apple Sign-In uses `AuthenticationServices`: `AppleSignInCoordinator` creates a per-request raw nonce, sends its SHA-256 digest to Apple, returns the identity token with the original nonce, and `SupabaseAuthDataSource.signInWithApple` passes both to `auth.signInWithIdToken`. User cancellation maps to `.userCancelled`.
- Google Sign-In calls `auth.signInWithOAuth(provider: .google, redirectTo: URL(string: "bloclens://"))`, which uses `ASWebAuthenticationSession`; the SDK intercepts the callback internally (no `application(_:open:options:)` handler is required for this flow). The `bloclens` URL scheme is registered in the app's Info.plist.
- After OAuth returns, the repository requires a real SDK session and reads the matching `profiles` row before resolving `.profileSetup` or `.signedIn`. It never fabricates a user ID or placeholder profile. Until migrations `0001`–`0011` are deployed to Cloud, OAuth may create an Auth identity but BlocLens deliberately reports a missing-profile error instead of presenting a false signed-in state.

`RemoteErrorMapping` maps `ASWebAuthenticationSessionError.canceledLogin` and `ASAuthorizationError.canceled` to `.userCancelled`. `RepositoryError` gained `.userCancelled` and `.externalServiceError`.

## Contribution writes (6D-4A)

`ContributionRepository` is the single write boundary for route contributions. `RemoteContributionRepository` and `MockContributionRepository` are actors and expose matching operations:

- `addRoute(_:)` requires a gym, wall zone, and either colour or label. The remote implementation supplies the authenticated `created_by` value, asks `is_gym_official(gym_id)` before marking an official source, and relies on the route foreign key plus RLS for the final authority check.
- `shareBetaLink(_:)` accepts public HTTPS URL metadata, original-post attribution, platform and the fixed beta-tag set. It never accepts bytes, a local path, upload state, download state, transcoding state, or a hosted video object.
- `addRoutePhoto(_:)` writes a public HTTPS reference into the existing photo metadata boundary. Contributor credit is the authenticated `uploaded_by` identity; no image bytes are sent by this repository. Arbitrary credit text is intentionally not invented because the approved schema has no such column.
- `submitCorrection(_:)`, `confirmReset(_:)`, `addComment(_:)`, and `reportContent(_:)` write the authenticated evidence rows. Comment validation enforces 1–200 characters. The existing database triggers remain authoritative for three-person correction/reset thresholds and one-severe/three-ordinary report thresholds.

Every insertable contribution entity uses the caller-generated UUID from `IdempotencyKey` as its primary key. A repeated insert resolves a unique conflict by reading that exact row. Reset confirmations and relationship tables already have composite database keys; their actor also remembers completed request keys for the current process. A retry therefore cannot fabricate an additional vote, confirmation, follow, or block.

`RoutePhotoRecord`, `RouteCorrectionRecord`, `ResetEventRecord`, `BetaCommentRecord`, and `ContentReportRecord` are transport-only records. The corresponding write DTOs encode the existing snake-case schema without leaking Supabase into views. Remote failures map to `RepositoryError`; successful UI feedback is shown only after the repository returns.

## Block and Follow (6D-4B)

`RelationshipRepository` provides public profile discovery, relationship state, Follow/Unfollow, and Block/Unblock. `RemoteRelationshipRepository` writes only the authenticated user's `user_follows` and `user_blocks` rows. The database composite keys prevent duplicates, RLS keeps Block rows private, the follow policy rejects either-direction blocks, and the existing `user_block_stop_follows` trigger removes both follow directions when a block is inserted.

The app removes accounts blocked by the current user from the public-profile list and from beta/comment repository results. This filtering lives in actor repositories rather than SwiftUI views, and the Mock implementation mirrors it. Since D-4R, the same exclusion is also enforced at the database boundary (see the D-4R section below), so a signed-in client cannot bypass a mutual Block through a direct table read, a security-invoker view, or the by-ID Data API path. The 6D-4 delivery itself changed no SQL; the database enforcement landed in migration `20260827001650_secure_block_aware_reads.sql`.

Follow exists only as a notification preference input for new beta contributions. There is no activity feed, follower-centric surface, or push implementation.

## Session role context (6D-4C)

`RoleRepository.sessionRoleContext()` returns the minimum role information needed by the iPhone session: an `appRole` capability tier and the set of managed gym IDs. `RemoteRoleRepository` composes this from `get_my_profile()`, `is_admin()`, `is_admin_or_moderator()`, and `gym_official_scope`. SwiftUI receives `SessionRoleContext`, never raw `app_user_roles` or `gym_memberships` rows.

- Trusted Contributor status comes from the server-maintained profile field. The existing Helpful triggers permanently award it at 67 valid Helpful votes; the client cannot set the field or Helpful aggregate.
- Verified gym capabilities are scoped to `managedGymIDs`. Official comments carry the managed gym ID, and official route/reset decisions still pass RLS and `is_gym_official` checks.
- Moderator and Administrator are capability flags for the few app presentation decisions that need them. Full moderation and role management remain on the separate administrator web surface.
- Gym officials do not receive an API for editing community-grade aggregates or Helpful counts. Ordinary voting operations retain their own attempt and self-vote rules.

`AppSession` refreshes this context after session restore, sign-in, and a successful Helpful action; it clears the context on sign-out. A failed role read falls back to no privileged capabilities rather than granting access.

## 6D-4 UI mapping

The central Add menu now opens functional, authenticated forms for Add Route and Share Beta Link. Route Detail provides photo metadata, correction, reset confirmation, flat beta comments, reporting, and real Helpful writes. Profile exposes a deliberately secondary contributor-management list for Follow/Block and shows only the session's minimal capability summary. Existing `ProtectedIntent` recovery reopens a pending Route Detail contribution after successful sign-in.

New hard-coded development-stage copy uses `Text(verbatim:)` and does not alter the String Catalog. Mock remains the default app environment; remote composition remains Debug-only.

## Next stages

- Add a schema-backed route-photo credit display field only if product requirements require credit text distinct from the authenticated contributor profile.
- Stage 8 (real device/TestFlight): end-to-end OAuth verification with real Apple/Google accounts against the single Cloud Auth/data boundary.
- Later: Google Places, the administrator portal, image storage policy, notification delivery, and the account-deletion Edge Function.

## D-4R authentication and Block boundary

Local email sign-up was verified to return a real Supabase session. The earlier integration failures were caused by invoking Simulator tests with code signing disabled: the SDK could not use its secure session storage in that test configuration. Simulator tests that exercise Auth therefore run with normal local signing. The repository never fabricates a session, and profile setup, the 16+ declaration, restoration and pending-intent recovery all use the authenticated SDK user.

The composition root now exposes the current Domain `UserID` through a closure backed by the single shared `SupabaseClient`. Mock mode deliberately returns the development fixture identity; Local Remote mode derives it from the current Auth session. Views do not retain a second SDK user or authenticated Boolean. Sign-out errors are propagated and preserve the existing authenticated state instead of presenting a false guest state. A role refresh failure fails closed, records an unconfirmed capability state and hides privileged UI.

Migration `20260827001650_secure_block_aware_reads.sql` separates anonymous and authenticated read policies for profiles, beta links and beta comments. Authenticated policies use `auth.uid()` through narrowly granted, fixed-search-path helpers to enforce a block in either direction. Security-invoker views inherit those policies, the guest beta-count RPC returns only a count, and authenticated counts exclude blocked contributors. Follow, Helpful and comment inserts also reject either-direction blocks. Direct table, by-ID, list, view and count paths are covered by pgTAP.

`get_my_blocked_profiles()` is the narrow owner-only exception used by the Block management screen. It returns safe profile fields only for rows where `blocker_id = auth.uid()`; it does not reveal who blocked the caller. This lets a user unblock an account without reopening ordinary public-profile, beta or comment reads. Unblock never restores Follow.

The local seed now includes deterministic email/password identities for ordinary, Trusted Contributor, Verified Gym, Moderator and Administrator test roles. They use reserved `.invalid` addresses and a local-only test password. No service-role credential enters the app or UI tests. Mock remains the default and Release remains Mock-only. Cloud behaviour and complete D-4 localisation remain separate follow-up scopes.

## D-5A account deletion and Logbook export

Account deletion ships through the `delete-account` Edge Function (see "Account deletion direction" above). `AuthenticationRepository` gained `deleteAccount()`, which `SupabaseAuthenticationRepository` implements via `client.functions.invoke("delete-account")` and the Mock repository implements as a local state reset. `AppSession.deleteAccount()` drops the session to guest and clears the pending intent and role context. The Settings screen presents a destructive confirmation dialog whose message states that private data is permanently deleted and public contributions are anonymised; a failed deletion surfaces an error alert rather than a false guest state.

Logbook export lives in `LogbookExporter`, a pure, testable component. It filters `LogbookRecordItem`s by an optional start and end date, then produces either CSV (RFC-style quoting for commas, quotes and newlines) or PDF (via `UIGraphicsPDFRenderer`) using `UIKit` — no third-party dependency. The Settings screen opens `LogbookExportView`, where the user picks a format and an optional date range, and the resulting file is written to a temporary URL and shared through `UIActivityViewController` so the user chooses where to save it; BlocLens retains no copy. Re-authentication before deletion remains a post-MVP decision: the MVP uses the confirmation dialog only.

## Email OTP sign-in and password management

The sign-in screen was restructured into a single entry that lists "Sign in with Apple", "Sign in with Google", and "Create an account" as the primary actions, with "Sign in instead" rendered as a secondary link. Email sign-in now uses a one-time-password (OTP) flow: the user enters their email, receives an 8-digit code by email, and verifies it via `verifyEmailOTP`, which `SupabaseAuthenticationRepository` implements through `client.auth.verifyOTP(type: .email)`. `sendEmailOTP` calls `client.auth.signInWithOTP(email:shouldCreateUser: true)` so a new email automatically creates an account. OTP emails are delivered through the configured SMTP (SendGrid) using the "Magic link or OTP" template containing the `{{ .Token }}` variable; a "Confirm your email address" Confirmation response only occurs for a brand-new account before confirmation, and resends deliver the OTP.

Passwords are managed only from Settings: `ChangePasswordView` collects a new password with a minimum length and confirmation, then `updatePassword` calls `client.auth.update(user: UserAttributes(password:))`. Apple and Google users are not prompted to set a password on first sign-in, but can add or change one later in Settings.

## Profile editing with two grade systems

`UserProfile` gained a `gradeSystem` (`V` or `YDS`) and `ydsGrade`. Migration `20260828090000_profile_grade_systems.sql` adds `grade_system` (text constrained to `V`/`YDS`), `yds_grade` (text matching the `5.x[a-d|+]` pattern), and a consistency constraint so only one of `regular_grade`/`yds_grade` is populated per chosen system. `ProfileEditView` lets a signed-in user edit height, arm span, grade system (V Scale vs YDS via a segmented control), and the regular grade via wheel pickers; a "Not sure yet" action clears the grade. On first registration the app presents this editor via `AppSession.shouldPresentProfileSetup`, and it is reachable any time from the Profile screen's "Edit" button.

## Stage 7 – Cloud environment (D1) and Cloud connection (D2)

The linked Cloud project (`atmtqesdhxpgnrjedwsu`) is treated as the staging/development environment alongside the local disposable database. Local and Cloud migrations are now aligned: the two migrations applied via the management API (`secure_block_aware_reads` and `profile_grade_systems`) were re-versioned to match the filenames in the repository (`20260827001650` and `20260828090000`), so `supabase migration list` reports local and remote as identical.

Cloud schema health was verified with read-only queries (no `pgtap` extension was installed on the remote, and seed-dependent cardinality assertions are intentionally excluded because the Cloud project holds no development fixtures): every client-facing table has RLS enabled and at least one policy, the four block-aware security functions exist (`private.has_block_relationship`, `private.beta_is_blocked`, `public.get_my_blocked_profiles`, `public.visible_beta_count_for_route`), and there are no video or wall-zone geometry surfaces. The repository- and data-source logic used by the Cloud path is the same code exercised by the local integration tests. Stage 7-D3 external services (Google Places, route-photo storage, notifications, feedback, crash reporting) are deferred and each requires separate authorisation; account deletion already ships as the `delete-account` Edge Function.

## User-created wall zones

Signed-in users can add a named wall zone to a gym they can see, and it takes effect immediately (scope was explicitly unfrozen for the MVP; the AccessMatrix row for "Create a wall zone" is now Allow for Signed-in User and Trusted Contributor). Migration `20260828120000_wall_zone_user_creation.sql` adds a nullable `created_by` (references `auth.users`, `on delete set null` so account deletion keeps attribution history) and an index over it, plus a `wall_zones_user_insert` RLS policy that lets an authenticated user insert a zone when `created_by = auth.uid()`, `availability = 'active'` and `archived_at is null`. Renaming and reordering existing zones remain limited to gym officials and the Administrator portal, so the existing `wall_zones_official_manage` policy is unchanged.

`ContributionRepository` gained `createWallZone(_ request: AddWallZoneRequest)`, implemented by `RemoteContributionRepository` (through `SupabaseContributionDataSource.insertWallZone`) and `MockContributionRepository`. It idempotently inserts the zone, requires an authenticated identity, trims and validates the name, and returns a `WallZone`. The Gym detail screen exposes an "Add wall zone" toolbar button that presents `AddWallZoneView`, which collects name, location description and wall type. The wall-zone route list gains an "Add route" toolbar button that opens the existing `AddContributionView` with that wall zone preselected, so a user can immediately add a route in a zone they just created. Read-side ordering and route attachment work unchanged because `routes` already accepts user inserts against an existing `wall_zone_id`.
