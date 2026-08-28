# BlocLens QA Coverage Matrix — Stage 8-D1

This document records which QA dimensions are **covered**, **partially covered**, or **not covered** for the MVP, and where each lives. It is a living checklist for Stage 8-D1. Each row marks a verification category; the third column names the concrete test/fixture that exercises it.

Legend: ✔ covered · ◐ partial (needs manual confirm / touches a subset) · ✘ not covered · — not applicable to MVP.

## 1. Automated test suites (as of 2028-08-28)

| Suite | Result | Tests | Where |
|---|---|---|---|
| Swift unit tests (Swift Testing, `@MainActor`) | ✔ passing | 172 / 172 | `BlocLensTests/*.swift` (16 suites) |
| pgTAP database contract tests | ✔ passing | 105 / 105 | `supabase/tests/*.sql` (4 files), run via `supabase test db` |
| Local Supabase integration tests (live DB) | ◐ skipped in unit run | 41 | `BlocLensTests/LocalSupabaseIntegrationTests.swift` — runs only when `BLOCLENS_SUPABASE_URL` is set; current unit-target run auto-skips (no live local stack) |
| Mock UI tests (fixture/mock env) | ✔ passing | 9 | `BlocLensUITests/BlocLensUITests.swift` |
| Local/Remote UI tests (real local Supabase) | ✘ failing w/o live stack | 8 | `BlocLensUITests/BlocLensLocalRemoteUITests.swift` — these require a running local Supabase + seed; fail when the stack is down (environment dependency, not a code defect) |
| Launch UI tests | ✔ passing | 16 | `BlocLensUITests/BlocLensUITestsLaunchTests.swift` |

## 2. Functional capability coverage

| Capability | Coverage | Evidence |
|---|---|---|
| Guest discovery (map, gym, route) | ✔ | `testGuestCanBrowseRouteBeforeSignInGate`, `testRouteDiscoveryAndQuickLogbookVerticalSlice` |
| Onboarding → ends on Map | ✔ | `testFirstLaunchOnboardingEndsOnMap` |
| Onboarding skip / reset | ✔ | uses `--skip-onboarding`, `--reset-onboarding` |
| Reveal beta gate (auth gate) | ✔ | `testRouteDiscovery...` (reveal → Sign In → safety ack) |
| Beta reveal safety acknowledgement | ✔ | `testRouteDiscovery...` acknowledges-beta-safety; `BetaRevealState` unit tests |
| Beta link reveal (meta only) | ✔ | `testGuestSafeBetaCountExcludesHiddenBeta`; `shareBetaLink...` unit/integration |
| External URL HTTPS-only validation | ✔ | `BetaRepositoryTests`, `RemoteBoundaryTests`, `ContributionRelationshipRoleTests` |
| Logbook status (want/project/sent/flash) + save | ✔ | `testRouteDiscovery...` saves projecting; `LogbookRepositoryTests` |
| Logbook private-by-default | ✔ | `testAnonymousCannotReadBetaLinks`; RLS unit/integration |
| Logbook offline queue + sync | ✔ | `LogbookRepositoryTests` (offline, syncNow, pendingSyncCount) |
| Map facility / beta filters | ✔ | `LowFidelityExperienceTests` (facilities, hasBeta), `MapFilterView` |
| Route filtering / grade band / sort | ✔ | `LowFidelityExperienceTests`, `RouteListPresentation` unit |
| Archived routes shown as history | ✔ | `testArchivedRouteIsPresentedAsHistoryNotCurrent` |
| Wall zone directory navigation | ✔ | `testRouteDiscovery...` (gym → zone → route) |
| Route community grade thresholds | ✔ | `testCommunityGradeThresholds`, `RemoteMappingTests` |
| Contribute route | ✔ | `testAddRouteContribution`, `testRemoteAddRouteSucceedsAndCanBeReadBack`, `ContributionRelationshipRoleTests` |
| Contribute external beta link | ✔ | `testShareExternalBetaLinkContribution`, `shareBetaLink...` |
| Contribute route photo | ✔ | `routePhotoStoresURLAndContributorCredit` |
| Submit correction | ✔ | `correctionSucceedsAndIsIdempotent`, `testSubmitCorrection` |
| Confirm reset | ✔ | `resetConfirmationSucceedsAndIsIdempotent` |
| Report content (incl. severe threshold) | ✔ | `reportContent`, `severeReportIsMarkedForImmediateThreshold` |
| **Create wall zone (new)** | ✔ | `createWallZoneSucceedsAndIsIdempotent`, `createWallZoneRejectsBlankName`, `createWallZoneRejectsUnknownGym`, pgTAP `client_access_hardening_test.sql` (+live `testCreateWallZoneContribution`) |
| Add route in a created zone | ✔ | zone preselect via `AddContributionView(preselectedWallZone:)`; route in zone covered by add-route tests |

## 3. Authentication & session coverage

| Dimension | Coverage | Evidence |
|---|---|---|
| Auth state machine (guest / authenticating / signedIn / error / signedOut) | ✔ | `AuthStateMachineTests` (24 tests) |
| Restore session (Keychain) | ✔ | `AuthStateMachineTests`; integration `testAuthEstablishesRealSession` |
| Protected intent resumes after auth | ✔ | `testProtectedAddIntentResumesAfterLocalSignIn`, `LowFidelityExperienceTests` |
| Guest gate for account actions | ✔ | `requireAuthentication(for:)` unit tests |
| Sign-in gate reappearance / cancel | ✔ | `AuthStateMachineTests` |
| Email OTP sign-in | ✔ | code-level (verifyEmailOTP/sendEmailOTP); not UI-e2e | ◐ |
| Apple / Google OAuth | ◐ | implementation verified + entitlements set; no automated auth (no credential provider in CI) |
| Password change | ◐ | `ChangePasswordView`; no automated e2e |
| Profile setup / 16+ declaration | ◐ | flow tested at unit level; not a dedicated UI e2e |
| Sign-out preserves state / fails closed | ✔ | `AuthStateMachineTests`, `signOut` unit |
| Role context fail-closed | ✔ | `sessionRoleContext` fail-closed unit tests |
| Account deletion | ◐ | `deleteAccount()` unit + Edge Function deployed; hard to e2e without destroying a live account |

## 4. Offline / connectivity & errors

| Dimension | Coverage | Evidence |
|---|---|---|
| Offline w/ cache banner | ✔ | `testDebugEmptyAndOfflineStates` (`--mock-offline-cached`) |
| Offline without cache empty state | ✔ | `--mock-offline-no-cache`; `DomainAndRepositoryTests` |
| Empty state (no gyms) | ✔ | `testDebugEmptyAndOfflineStates` (`--mock-empty`) |
| Error state + retry | ◐ | error state exists (`--mock-error`); retry path unit-tested, not e2e | ◐ |
| Repository error mapping (network/timeout/forbidden/conflict) | ✔ | `RemoteErrorMapping`, `RemoteBoundaryTests` |
| Rate limiting → rateLimited error | ✔ | `RemoteRepositoryTests`, `RemoteBoundaryTests` (simulated), `isRateLimited` mapping |
| **Auth token expiry** → unauthenticated handling | ✘ | no explicit expiry test | ✘ |
| Offline auth expiry (token stale while offline) | ✘ | not covered | ✘ |

## 5. On-device UX & dynamic rendering

| Dimension | Coverage | Evidence |
|---|---|---|
| Light appearance | ✔ | `testLightAndDarkAppearancesLaunch` (Light) |
| Dark appearance | ✔ | `testLightAndDarkAppearancesLaunch` (Dark); design tokens |
| Dynamic Type — onboarding | ✔ | `testOnboardingActionsRemainUsableAtAccessibilityTextSize` (AccessibilityXXXL) |
| Dynamic Type — route detail | ✔ | `testRouteDetailRemainsScrollableAtAccessibilityTextSize` (AccessibilityXXXL) |
| VoiceOver / accessibility labels | ◐ | `accessibilityLabel`/`accessibilityIdentifier` set across views; route colour accessibility name unit-tested; no full VoiceOver-driven UI test | ◐ |
| Reduce Motion | ✘ | not covered | ✘ |
| Increase Contrast | ✘ | not covered | ✘ |
| Localisation (English / Korean / Simplified Chinese) | ◐ | `testInAppLanguageSelectionUpdatesAndCanReturnToSystem` (ko); zh-Hans present but no e2e | ◐ |
| Media + Spatial / 100% zoom | ✘ | not covered (no media surfaces in MVP) | ✘ |

## 6. Device & OS matrix

| Dimension | Coverage | Evidence |
|---|---|---|
| Deployment target | ✔ | `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `TARGETED_DEVICE_FAMILY = 1` (iPhone-only) |
| Small iPhone (SE / mini logical width) | ✘ | unit/UI tests run on iPhone 16 Pro simulator only | ✘ |
| Large iPhone (Pro Max) | ✘ | not exercised | ✘ |
| iOS 17 (min) | ◐ | target is 17.0 but tests run on iOS 18.4 simulator; iOS 17 not booted | ◐ |
| Current iOS (18.4) | ✔ | simulator id `F0A02308-...` (iOS 18.4) |
| **Physical device (real iPhone)** | ✘ | dashboard/real-device pass not yet automated; requires manual | ✘ |

## 7. Security & data governance

| Dimension | Coverage | Evidence |
|---|---|---|
| RLS on all client tables | ✔ | pgTAP `schema_contract.sql`, `client_access_hardening_test.sql` |
| Anonymous read boundary | ✔ | `client_access_hardening_test.sql`, `RemoteBoundaryTests`, `testAnonymousCannotReadBetaLinks` |
| Block boundary (both directions) | ✔ | pgTAP `block_boundaries_test.sql` |
| Role capabilities (gym official / admin / trusted) | ✔ | pgTAP `roles_capabilities_test.sql` |
| SECURITY DEFINER exposure review | ✔ | known/intentional; documented in `DataArchitecture.md`; Supabase advisor reviewed |
| Leaked password protection | ◐ | Supabase advisor reports this not yet enabled (auth-level, config, not code) | ◐ |
| Secrets not committed | ✔ | `.env*`, `opencode.json` (gitignored); keys injected at runtime |

## 8. Gaps summary (highest priority → lowest)

1. **Physical device (真机) pass** — not automated; the reason Map shows "No Gyms Available" on-device is empty Cloud data, not a defect (see `DataArchitecture.md` Stage 7 note). A device smoke pass is still required for QA.
2. **Auth token expiry** — no explicit expiry / stale-token handling test (both online & offline).
3. **Device matrix** — only iPhone 16 Pro (iOS 18.4) simulator; no small/large iPhone, no iOS 17 boot.
4. **Accessibility depth** — VoiceOver-driven UI test, Reduce Motion, Increase Contrast.
5. **Live local Supabase UI tests** — currently require a running stack to not fail (an environment prerequisite, not a code bug).
6. **Empty-map copy on real Cloud** — `map.emptyFixture.title` "No Gyms Available" text assumes fixtures; on real (empty) Cloud it reads as a fixture-implication. Could be softened.

## 9. Key verification commands

```bash
supabase test db                      # pgTAP (105)
supabase db lint                      # schema lint
xcodebuild test -only-testing:BlocLensTests   # unit (172)
# UI (mock):    BlocLensUITests
# UI (local):   BlocLensLocalRemoteUITests   requires running local Supabase + seed
```

## 10. Notes

- Mock remains the default scheme; prod data source switch is still a separate approved step.
- The push of migration `20260828120000` (wall-zone user creation) brought Cloud to 15 migrations, aligned with local.
- This matrix should be re-run/kept current as Stage 8-D1 proceeds; row statuses reflect the state on 2028-08-28.
