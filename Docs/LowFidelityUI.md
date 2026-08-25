# BlocLens Low-Fidelity Product Experience

## Purpose

This document records the Stage 4 SwiftUI product prototype. It refines the existing mock route-discovery vertical slice without changing the frozen MVP, domain model boundaries or external-link-only beta rule.

## Implemented pages

- **Find Climbing Gyms Onboarding**, **Find the Right Beta Onboarding** and **Track Your Climbing Onboarding**.
- **Home** with the favourite gym, Active Projects, Latest Resets and Recent Logbook Entries.
- **Nationwide Gym Map**, local Search, Map Filters and the Gym Preview Card.
- **Gym Detail** with a named Wall Zone Directory, reset information, grade-band Hard/Soft Index, operating information, facilities and contact-data state.
- **Wall Zone Route List** with current routes, a separate archived disclosure, search, grade and beta filters, and sorting.
- **Route Detail** with route identity, Photo Missing state, Quick Logbook State, protected Beta reveal, Community V Grade, Comments placeholder and accuracy actions.
- **Logbook Dashboard** with private statistics, a simple grade distribution, status/date filters, sync labels, Active Projects and Recent Entries.
- **Profile** in Guest and mock signed-in states, plus Settings and bundled placeholder destinations for Help, Safety and Privacy.
- **Add Action Menu** with Share Beta Link, Add a New Route, Log a Climb and Mark a Route from a Photo. The photo-marking entry is a Coming Later explanation and does not request camera access.

## Page hierarchy

```text
Launch
→ Onboarding when required
→ Five-tab App Shell
   → Home → Gym Detail or Route Detail
   → Map → Gym Preview Card → Gym Detail → Wall Zone Route List → Route Detail
   → Add → Sign-in Gate when required → bounded action placeholder
   → Logbook → Route Detail
   → Profile → Settings → Help, Safety or Privacy placeholder
```

Each long-lived tab keeps its own `NavigationStack`. Add remains a modal action launcher rather than a blank destination.

## Core components

- Optic Blue semantic colours with system, grouped, surface and elevated backgrounds.
- Primary, Secondary and Compact Action button styles with disabled states.
- Status, Grade and Facility chips; Helpful count; Gym Preview Card; Route Row; and Logbook Status Control.
- Shared Loading, Empty, Error and Offline states.
- A dismissible Contribution Prompt with a visible **Not now** action and explicit private-Logbook protection.
- Material-backed cards that work in Light and Dark appearances on iOS 17.

Controls use native hit targets, text labels and VoiceOver labels or values where an icon alone would be ambiguous. Route colour is always paired with its text label.

## Page states

`MockRepositoryScenario` provides Loaded, Empty, Error, Offline with cached data and Offline without cached data. Debug launch arguments are `--mock-empty`, `--mock-error`, `--mock-offline-cached` and `--mock-offline-no-cache`.

Core previews cover Onboarding, Home, Map, Gym Detail, Wall Zone Route List, Route Detail, hidden and revealed Beta, Logbook and signed-out or signed-in Profile states across Light, Dark, Empty, Error and Offline examples.

## Mock Authentication

`AuthenticationRepository` is a replaceable session boundary. `MockAuthenticationRepository` starts as Guest unless a Debug fixture requests the mock account. The local profile is **Alex**, with optional body measurements, a regular grade and a favourite gym.

Guest users can browse gyms, wall zones and basic Route Detail. Reveal Beta, Logbook writes, Helpful, Add actions and account actions call `AppSession.requireAuthentication(for:)`. The session stores a small typed `ProtectedIntent`, presents one Sign-in Gate and restores that exact action after **Continue with mock account**. Apple and Google buttons are intentionally disabled and clearly labelled as unconnected development controls.

No OAuth SDK, token, credential or remote identity service is present. Logbook records remain private by default.

## Onboarding

Onboarding contains three skippable local pages and requests neither login nor location. Completion is persisted through the injected `OnboardingStore`; the development app uses `UserDefaults`, while tests use an in-memory store. Completion selects the Map tab.

Debug launch arguments `--reset-onboarding` and `--skip-onboarding` provide deterministic entry. Debug Settings can reset onboarding without changing account data.

## Contribution Prompt principles

Prompts are contextual, dismissible and session-frequency-limited. They explain what public information would be shared and how it helps another climber identify a gym, wall or route. **Not now** always preserves the underlying task. Prompts never publish height, arm span, attempts, notes, Projects or another private Logbook field.

## Not implemented

- Supabase, database migrations, live synchronisation or any external API.
- Real Apple or Google authentication.
- Live opening data, Google Places, real location permission or navigation.
- Public contribution publication, comments, following, notifications or moderation submission.
- Camera access, photo selection, hold marking or AI recognition.
- Web, video or external-link loading inside this prototype.
- Video upload, download, caching, storage, hosting or transcoding.
- A 2D wall map, floor plan, hotspot, polygon or indoor-navigation geometry.

## Future backend replacement boundaries

A backend stage replaces implementations of `GymRepository`, `RouteRepository`, `BetaRepository`, `LogbookRepository` and `AuthenticationRepository` behind `AppEnvironment`. Persistent account state, onboarding migration, cache policy and server-confirmed writes remain behind those boundaries. Views continue to consume domain values and typed session intents rather than transport DTOs or backend client objects.

## Stage 5 visual upgrade

Stage 5 retains this page hierarchy and every Stage 4 mock boundary. It adds formal semantic colour, typography, spacing, shape and motion tokens; purpose-specific cards, rows, chips, metrics, filters and state treatments; route-colour accessibility; compact map controls; clearer Archived and estimate presentation; and responsive Onboarding and Route Detail layouts.

The interface uses native Liquid Glass only when the runtime and SDK support it. iOS 17 and iOS 18 receive a Material and semantic-border fallback. Light, Dark, small-screen, Dynamic Type and Reduce Motion behaviour are now explicit visual-system concerns. See `VisualSystem.md` for the component and compatibility contract.

The unimplemented boundaries above remain unchanged. Stage 5 adds no backend, external API, real OAuth, media loading, video path, camera access, AI recognition or 2D wall geometry.
