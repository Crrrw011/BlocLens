# BlocLens Mock Architecture

## Purpose

This stage provides a replaceable, in-memory implementation of the first climbing-tool vertical slice. It supports development, previews, deterministic tests and Simulator validation without connecting Supabase, an external API, a sign-in provider or live location services.

All fixture names, dates, operating summaries and route relationships are development data. Gym names identify the three Brisbane pilot locations requested by the product specification, but the fixture does not claim live accuracy.

## Domain model boundaries

Pure domain types live under `BlocLens/Core/Models` and do not import SwiftUI, MapKit or a backend SDK.

- `EntityID` supplies stable typed identifiers for gyms, wall zones, climbing routes, beta links, Logbook entries and users.
- `Gym`, `GymFacility`, `HardSoftSummary`, `OperatingSummary` and `DataSourceState` describe discoverable gym information without live trading claims.
- `WallZone`, `WallType` and `WallZoneAvailability` describe named, ordered wall-zone lists. They contain no floor-plan coordinate, polygon, hotspot or indoor-navigation geometry.
- `ClimbingRoute`, `RouteLifecycle` and `RoutePhotoReference` describe a bouldering problem and its historical availability. `ClimbingRoute` is deliberately distinct from navigation-route terminology.
- `VGrade` is a validated, sortable value from `VB` through `V17`, plus `Unknown`.
- `CommunityGradeSummary` exposes a median only after at least three valid votes.
- `BetaLink` stores public external-link metadata only. It contains no media bytes, upload state, file size, resolution, frame rate, transcode state or cache state.
- `LogbookEntry` explicitly carries `privateByDefault` privacy and `synced` or `queued` state. There is no automatic public option.
- `ResetSummary` distinguishes official, community-confirmed and estimated reset information.

Pure domain services own rules that should not be duplicated in views:

- `BetaRanker` filters broken or moderation-hidden links, then orders by body-dimension proximity, Helpful count and stable identifier.
- `LogbookStatistics` calculates completion counts, highest completed grade and grade distribution.

## Repository responsibilities

Four protocols form the data boundary:

- `GymRepository` retrieves and searches gyms and returns their named wall zones.
- `RouteRepository` retrieves, searches and filters climbing routes and provides a suspected-duplicate query seam.
- `BetaRepository` validates public HTTP or HTTPS URLs and returns ranked external beta metadata. It never receives or returns a video file.
- `LogbookRepository` saves private state immediately, updates optional details, retrieves Projects and models queued offline writes and later synchronisation.

The protocols use domain values and Foundation types only. They contain no Supabase schema names, transport response objects or database implementation details.

## Dependency injection

`AppEnvironment` contains the four repository dependencies, the development user identifier and the fixture scenario. `BlocLensApp` creates one environment for the application session and passes it to `AppShellView`. Views do not create repositories, and there is no global singleton or `static let shared` router or service.

Feature view models receive repositories or the environment through initialisers. UI-observable state remains Main Actor isolated. Repository mocks are actors so mutable in-memory Logbook state is safe across asynchronous calls. Previews and tests can create independent environments or repository actors.

`AppSession` holds only session-scoped UI acknowledgement state, including the first beta-reveal safety acknowledgement. It is injected into the Map navigation branch rather than obtained globally.

## Development fixture relationships

`DevelopmentFixtures` is deterministic and uses stable identifiers:

- 3 Brisbane pilot gyms;
- 9 named wall zones, three per gym;
- 27 climbing routes, three per wall zone;
- 6 external beta-link metadata records;
- 3 private Logbook entries covering Projecting, Sent and Flash;
- 3 reset summaries covering official, community-confirmed and estimated sources.

Relationships are explicit through typed identifiers. Tests verify that every wall zone belongs to its declared gym and every climbing route belongs to a wall zone in the same gym. The data includes active, temporarily hidden and archived routes; an approximate upcoming archive date; zero-beta and multi-beta routes; broken, moderation-hidden and source-platform-only beta links; and community grades below and above the three-vote display threshold.

No fixture represents a real user profile. Author labels are explicitly marked as development fixtures.

## Online and offline simulation

`MockRepositoryScenario` supplies `loaded`, `empty`, `error`, `offlineWithCache` and `offlineWithoutCache` read states. Debug-only launch arguments map to these scenarios:

```text
--mock-empty
--mock-error
--mock-offline-cached
--mock-offline-no-cache
```

These switches are compiled only in Debug builds. They do not add permanent controls to the release experience.

`MockLogbookRepository` independently tracks online state. An offline save is accepted immediately into the current session with `queued` sync state. Calling `setOnline(true)` followed by `synchroniseQueuedEntries()` moves queued records to `synced`; no real network operation occurs.

## Navigation implementation mapping

The implemented discovery branch is:

```text
MapView
→ GymPreviewCard
→ GymDetailView
→ WallZoneRouteListView
→ RouteDetailView
```

`MapView` owns its own `NavigationPath`. `Gym`, `WallZone` and `ClimbingRoute` are typed push destinations in that path. Local Search is a sheet and can reconstruct the appropriate typed destination chain. Optional Logbook details are a sheet owned by Route Detail. Beta safety is a first-use alert stored only for the current application session.

Home and Logbook use the same injected in-memory repositories, so Quick Logbook changes remain visible when the user changes tabs.

## Future Supabase replacement points

A future backend stage can provide actor-backed implementations of the four existing repository protocols and inject them through `AppEnvironment`. Transport DTOs, authentication tokens, retry policy, cache persistence and database mapping belong behind that boundary. The domain models and views must not depend directly on a Supabase client.

This document identifies replacement points only. No Supabase package, client, migration, credential or network request exists in this stage.

## Explicitly excluded media upload path

BlocLens beta media is external-link-only. The application records validated public HTTP or HTTPS metadata and may hand off to the original source platform. It does not accept media files and does not upload, download, cache, host, compress, transcode or proxy video. There is no media-upload repository, action, screen or state machine in the iPhone application.
