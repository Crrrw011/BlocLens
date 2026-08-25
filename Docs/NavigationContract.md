# BlocLens Navigation Contract

## 1. Purpose

This contract defines navigation ownership and presentation behaviour for the frozen MVP. Suggested route identifiers are documentation-level names only; this stage does not require a production router or domain model.

## 2. Primary tab boundaries

| Tab | Responsibility | Primary destinations it owns | Must not become |
|---|---|---|---|
| **Home** | Resume practical climbing activity | Current or Frequent Gym, Active Projects, Latest Resets, Recent Logbook Records, Project Detail | A social or followed-user feed |
| **Map** | Discover and evaluate gyms and routes | Nationwide Gym Map, Search, Map Filters, Gym Preview Card, Gym Detail, Wall Zone Directory, Wall Zone Detail, Route List, Route Detail | A user or comment search surface |
| **Add** | Start a creation or recording task | Add Action Menu, Publish Beta Link, Add New Route, Record Completed Route, Identify or Mark Route | A persistent blank tab or a video-file upload destination |
| **Logbook** | Track private progress | Logbook Dashboard, status lists, Projects, Record Detail, Statistics, Export Logbook | A public profile or social ranking surface |
| **Profile** | Manage identity, preferences, safety, policies and account data | Edit Profile, settings, Following, Blocked Accounts, Help, policies, Account Data, Verified Gym Tools | An Administrator dashboard |

Each tab owns an independent `NavigationPath` or an equivalent strongly typed path. Switching tabs preserves the path in every tab. No tab reaches into another tab's path directly.

## 3. Suggested route families

Suggested names are stable documentation identifiers, not a mandate for one Swift enum:

```text
HomeRoute.projectDetail(projectID)
HomeRoute.gymDetail(gymID)
HomeRoute.resetDetail(resetID)

MapRoute.search
MapRoute.gymDetail(gymID)
MapRoute.wallZoneDirectory(gymID)
MapRoute.wallZoneDetail(zoneID)
MapRoute.routeList(zoneID)
MapRoute.routeDetail(routeID)

LogbookRoute.status(status)
LogbookRoute.projectDetail(projectID)
LogbookRoute.recordDetail(recordID)
LogbookRoute.statistics

ProfileRoute.editProfile
ProfileRoute.notificationSettings
ProfileRoute.accountData
ProfileRoute.policy(document)
ProfileRoute.verifiedGymTools(gymID)
```

Opening a shared entity from a different tab is valid. For example, Home can own a `gymDetail` route reached from **Current or Frequent Gym** without mutating the Map tab's navigation path.

## 4. Push navigation

Use push navigation for destinations that represent a durable drill-down in the current task:

- Gym Detail → Wall Zone Directory → Wall Zone Detail → Route List → Route Detail.
- Search result → Gym Detail, Wall Zone Detail or Route Detail.
- Home module → Gym Detail, Latest Reset, Project Detail or Record Detail.
- Logbook Dashboard → status list, Projects, Record Detail or Statistics.
- Profile → settings, policy, account-data and verified-gym management destinations.
- Archived Route State remains a pushed Route Detail rendered in read-only historical mode; it is not a separate modal dead end.

Back navigation must return to the prior context with filters, search query, list position and tab path preserved where practical.

## 5. Sheet presentation

Use a sheet for a bounded task that should return to the current page:

- **Add Action Menu** from the central Add control.
- **Map Filters**.
- **Gym Preview Card** from a map pin.
- **Location Permission Context** before the system permission request.
- **Quick Logbook State** and its optional details.
- **Reveal Beta**, including supported inline playback or source-platform handoff.
- **Community V Grade** vote entry.
- **Corrections and Reports**.
- **Suspected Duplicate Route**.
- **Select Route** and **Select Gym and Wall Zone** when they are substeps.
- **Contribution Confirmation**, success and recoverable error feedback.
- **Optional Profile Completion**, **Frequent Gym**, **Export Logbook** and **In-App Feedback**.
- Destructive or session-ending confirmations such as **Sign Out**.

Sheets must expose a clear dismissal path. A voluntary contribution sheet always provides a visible **Not Now** action and never blocks the underlying climbing task.

## 6. Full-screen cover presentation

Use a full-screen cover only when the presented journey temporarily owns the entire interaction:

- First-launch three-page onboarding.
- **Authentication Gate** and provider flow when required by a protected intent.
- **Delete Account**, because identity confirmation, consequence explanation and explicit confirmation form one sensitive sequence.
- Camera capture may use the system full-screen experience when invoked by **Identify or Mark Route**.

Safety acknowledgements may be a focused sheet within the protected flow. They must not be shown on every reveal or publish after the corresponding first-use acknowledgement is stored.

## 7. Central Add behaviour

The centre control is an action launcher:

1. Selecting **Add** presents **Add Action Menu** over the currently selected tab.
2. The previously selected tab remains the active long-lived destination.
3. Selecting an action opens its bounded sheet or task flow.
4. Dismissal returns to the original tab and path.
5. Successful public contribution may offer **View Contribution**, opening the relevant entity in the originating tab context or a clearly chosen entity route.

The Add control never leaves the user on an empty placeholder tab. The menu contains only **Publish Beta Link**, **Add New Route**, **Record Completed Route**, and **Identify or Mark Route**.

## 8. Authentication gate and intent restoration

A protected intent is a small value describing what the user attempted, not a global navigation singleton. It should contain only the identifiers required to resume safely, for example:

```text
ProtectedIntent.revealBeta(routeID, betaLinkID)
ProtectedIntent.addRoute(prefilledGymID, prefilledZoneID)
ProtectedIntent.publishBetaLink(routeID)
ProtectedIntent.saveLogbook(routeID, desiredStatus)
ProtectedIntent.followUser(userID)
```

The owning flow stores the pending intent before presenting **Authentication Gate**. After Apple or Google authentication, 16+ self-declaration, username setup and any required first-use acknowledgement, the gate dismisses and asks the owning flow to restore the exact destination. Cancellation clears the pending intent and returns to the unchanged underlying page. Authentication failure retains a safe retry path without duplicating a write.

## 9. Reserved deep-link format

Universal Links are not implemented in this stage. Reserve stable application-level paths so future links can map to typed destinations:

```text
bloclens://gym/{gymID}
bloclens://gym/{gymID}/zone/{zoneID}
bloclens://route/{routeID}
bloclens://route/{routeID}/beta/{betaLinkID}
bloclens://logbook/record/{recordID}
bloclens://profile/{username}
```

Rules:

- A public gym, zone or route link can open for a Guest.
- A beta link resolves Route Detail first, then applies **Authentication Gate** before reveal.
- A private Logbook link requires the owning signed-in account and never exposes data to another account.
- Unknown, removed or malformed identifiers resolve to a localised unavailable state with a safe return path.
- The reserved custom scheme does not imply Universal Link entitlement or implementation.

## 10. Archived and unavailable content

- Archived Route Detail keeps the route, beta-link metadata, community grades, comments and historical Logbook references available in read-only historical form.
- An archive banner explains whether the date or state was estimated.
- Current-route actions that would imply availability are disabled or replaced with an explanation.
- Private Logbook records remain editable as historical personal records where the PRD permits.
- A restored route updates in place without discarding the user's navigation context.
- Moderation-hidden content uses a distinct unavailable state and does not reveal hidden content while review is pending.

## 11. Offline navigation

- Navigation to cached saved gyms, Projects and recently viewed routes remains available.
- Full offline map browsing is not available. Map displays an offline state plus cached saved-gym entry points where present.
- Route Detail may show a cached shell and metadata, but external beta reveal and playback require connectivity.
- Private Logbook writes can be created or edited offline and display a queued-sync state.
- Public contributions, authentication, comments, votes, reports, following and verified-gym management require connectivity. Their entry points may remain visible but must explain the requirement without discarding entered drafts.
- Returning online refreshes the current destination rather than resetting the tab path.

## 12. Router ownership

- Do not use a global singleton router.
- The root shell owns selected-tab state and modal coordination only.
- Each tab owns its navigation path.
- Feature flows own their sheets, temporary drafts and protected intents.
- Shared destination construction may be injected through lightweight factories or closures later, but it must not centralise mutable navigation state globally.

## 13. Separate Administrator surface

The Administrator web portal is a separate product surface built outside this Xcode project. Moderation queues, route merges, restoration, claims, penalties, audit records, localisation configuration and operational metrics are not iPhone tab destinations. The iPhone app may submit reports, corrections and claims, but it does not expose the Administrator portal inside its navigation hierarchy.

## 14. Stage 3 implementation mapping

The current Swift implementation uses the following concrete navigation types while preserving this contract:

| Contract destination | Swift implementation | Presentation |
|---|---|---|
| **Nationwide Gym Map** development slice | `MapView` | Root of the Map tab `NavigationStack` |
| **Gym Preview Card** | `GymPreviewCard` | Map bottom safe-area inset; transient selection |
| **Gym Detail** and **Wall Zone Directory** | `GymDetailView` | Typed push using `Gym` |
| **Wall Zone Route List** | `WallZoneRouteListView` | Typed push using `WallZone` |
| **Route Detail** | `RouteDetailView` | Typed push using `ClimbingRoute` |
| Local **Search** | `LocalSearchView` | Sheet owned by `MapView` |
| **Quick Logbook State** | Route Detail section | Immediate repository write in place |
| Optional Logbook details | `LogbookDetailsSheet` | Sheet owned by `RouteDetailView` |
| First **Reveal Beta** safety acknowledgement | Route Detail alert | Session-scoped alert before metadata reveal |
| **Home** data summary | `HomeView` | Independent Home tab `NavigationStack` |
| **Logbook Dashboard** | `LogbookView` | Independent Logbook tab `NavigationStack` |

`MapView` owns a local `NavigationPath`; no singleton router is introduced. `AppShellView` owns selected-tab and Add-menu presentation only. The centre Add control continues to present a menu over the previously selected tab rather than becoming a long-lived destination.

In this development slice, `GymDetailView` combines **Gym Detail** and the named **Wall Zone Directory** section. `WallZoneRouteListView` combines the selected wall-zone header and its route list. These implementation compositions do not introduce a two-dimensional wall surface, floor plan, hotspot or indoor geometry.

Archived `ClimbingRoute` values push to the same `RouteDetailView` and render a read-only historical banner. `MockRepositoryScenario` maps Loading, Empty, Error and offline states without replacing or resetting a tab path. External beta metadata requires a loaded or cached repository state; no video player or media transfer is part of navigation.

## 15. Stage 4 low-fidelity implementation mapping

`AppRootView` resolves the injected local onboarding state before presenting `AppShellView`. `OnboardingView` is a three-page full-screen root experience; completion selects `AppTab.map`. The `--reset-onboarding` and `--skip-onboarding` Debug launch arguments provide deterministic test entry without changing release navigation.

`AppSession` owns selected-tab state, appearance preference, first-reveal safety acknowledgement and a single optional `ProtectedIntent`. It is an injected observable session, not a global singleton router. `AuthenticationRepository` supplies Guest or mock signed-in state. `SignInGateView` is presented as a sheet from the root shell. After local mock sign-in, the owning Route or Add flow consumes the restored intent and continues the exact requested action.

Concrete protected mappings are:

```text
ProtectedIntent.revealBeta(routeID)
ProtectedIntent.saveLogbook(routeID, status)
ProtectedIntent.add(action)
ProtectedIntent.helpful(betaID)
ProtectedIntent.account
```

`MapFilterView`, local Search and the Add Action Menu are sheets. Optional Logbook details remain a Route-owned sheet. Beta safety is a focused first-use alert after authentication. Unsupported external beta presents a local handoff explanation in this prototype and does not open a URL.

`WallZoneRouteListView` shows current routes as the primary list and archived routes in a separate disclosure. Archived Route Detail continues to use the same typed push destination with historical messaging. The iPhone navigation still has no administrator destination, 2D wall surface or general social feed.
