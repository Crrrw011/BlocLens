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

## Guest versus beta access — pending decision

The PRD (§2.1) states that viewing beta requires login, while `AccessMatrix.md` marks beta reveal as authentication-gated. The current SQL grants `SELECT` on `beta_links` and the `beta_ranking_inputs` view to the `anon` role, and those surfaces expose `public_url`, `original_post_url`, `platform` and author metadata. A guest can therefore obtain the actual external beta URL through the Data API without signing in. This is a server-side authorisation gap to resolve before Stage 6D-2 read work; it must be fixed in SQL/RLS or an RPC, not by hiding the URL in SwiftUI. The current pgTAP contract does not assert anonymous beta-access denial.

## Block filtering direction

Blocked users' beta, comments and profile content must be excluded by a server-side security query (RPC or a filtered view), not by a Swift array filter in a view. The remote repository uses that secure query as the only normal read entry point; the Mock repository mirrors the same behaviour for tests. `user_blocks` remains private under RLS. No Block implementation ships in this stage.

## Account deletion direction

Account deletion from the app requires a controlled server-side entry point (Supabase Edge Function or equivalent). The `service_role` key must exist only in server-side secrets; the iPhone app must never contain a service-role key, database password or JWT secret. A client-callable service-role SQL function is not an acceptable workaround. Re-authentication, permanent-deletion confirmation, private-data deletion/anonymisation policy, legal review and integration tests remain before this ships.

## Search index discrepancy

`DataArchitecture.md` describes a `pg_trgm` GIN index for gym-name search, but the current migrations only create `pgcrypto` and `citext`; no `pg_trgm` extension or trigram index exists. This is a database correction candidate before Stage 6D-2, not a Swift change.

## Client secret prohibitions

The iPhone app must never contain a `service_role` key, database password, JWT secret or any server secret. Only a non-secret project URL and publishable/anon key may be configured client-side. Configuration must be supplied via a git-ignored local source and never committed.

## Next stages

- Stage 6D-2: add the Supabase Swift SDK, introduce actor-backed remote repositories behind the existing protocols, and exercise read-only Gym/Wall-Zone/Route queries against a disposable local Supabase database.
- Stage 6D-3: implement the authentication session, age gate and username setup, and private Logbook read/write with the queued/synced/failed sync states.
