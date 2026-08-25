# BlocLens Visual System

## Brand direction

BlocLens is a climbing utility first. Its visual character is clear, focused, technical, calm and fast. The product name is **BlocLens** and the supporting line is **See the wall. Find your beta.** Social signals remain subordinate to gym, wall-zone, route, beta and private Logbook information.

The system uses native SwiftUI controls and platform conventions. Visual hierarchy comes from typography, spacing, surface level and semantic status, rather than decorative animation or nested card stacks.

## Optic Blue

Optic Blue is the primary action and orientation colour. It identifies selected navigation, primary actions, map selection, active filters and focused controls. It is not used as a full-page wash and does not replace semantic Success, Warning, Error, Offline or Archived colours.

## Colour tokens

The design system exposes the following adaptive semantic tokens:

- `brandPrimary`, `brandPrimaryPressed` and `brandTint`.
- `backgroundPrimary` and `backgroundSecondary`.
- `surfacePrimary` and `surfaceElevated`.
- `textPrimary`, `textSecondary` and `textTertiary`.
- `separator`.
- `success`, `warning`, `error`, `offline` and `archived`.

System dynamic colours provide Light, Dark and Increase Contrast compatibility. Major feature pages consume these semantic tokens rather than defining local RGB values. Optic Blue remains available through a compatibility alias while existing Stage 4 call sites migrate incrementally.

## Typography

BlocLens uses the system font and Dynamic Type. The supported hierarchy is:

- Large screen title: system large title, bold.
- Navigation title: the native navigation-bar title.
- Section title: headline, semibold.
- Card title: headline, semibold.
- Body: system body.
- Supporting: subheadline.
- Caption: caption.
- Grade emphasis: title level, bold and rounded.
- Numeric statistic: title level, bold and rounded.

Views avoid fixed text heights. Supporting content wraps and important controls remain reachable in larger accessibility text sizes.

## Spacing

The spacing scale is 4, 8, 12, 16, 20, 24 and 32 points. It maps to `xSmall`, `small`, `compact`, `medium`, `comfortable`, `large` and `xLarge`. Feature views use this scale for internal rhythm, section separation and touch-target padding.

## Shape

- Small control radius: 10 points.
- Chip radius: capsule.
- Card radius: 18 points.
- Sheet section radius: 24 points.

Cards use one enclosing surface where practical. Borders and restrained elevation distinguish adjacent information without adding repeated rounded containers.

## Motion and feedback

State, filter and beta-reveal transitions use short ease-in-out motion. The implementation checks Reduce Motion before applying content transitions. Logbook save, Helpful and Add selection can use native `sensoryFeedback` on iOS 17 or later; feedback is tied to a completed local state change and is not repeated continuously.

## Liquid Glass and the iOS 17 fallback

On systems where the compiled SDK provides the native Liquid Glass modifier, interactive elevated controls use the system implementation behind an availability check. iOS 17 and iOS 18 use a regular or thin Material background with a semantic separator border. Navigation bars, tab bars and sheets continue to use native platform presentation.

BlocLens does not implement a custom glass renderer. Content contrast and legibility take priority over translucency.

## Core components

The reusable visual layer includes:

- Primary, Secondary, Quiet, Compact Action and Icon button styles.
- Status, Grade and Facility chips.
- Helpful Indicator and Logbook Status Control.
- Section Header, Search Field and Filter Control patterns.
- Gym Summary Card, Wall Zone Row, Route Row, Reset Summary treatment and Metric Card.
- Contribution Prompt.
- Beta Card in hidden, revealed and broken-link states.
- Empty, Error and Offline states, Offline Banner and Skeleton Loading Placeholder.

Component APIs stay purpose-specific. Display components do not call repositories and protected interactions still pass through the typed session intent gate.

## Route colour accessibility

Route colours always include the written colour or label. The swatch provides a border so White and Yellow remain visible on light surfaces. VoiceOver receives a colour-label description, and grade, personal status, archived state and sync state also include text or symbols. No route state is communicated by colour alone.

## Light and Dark appearances

Background, surface, text, separator and status tokens adapt automatically. Map overlays use Material or native glass so controls remain legible over both light and dark map content. Users can choose System, Light or Dark in Settings; the selection updates the app colour scheme without replacing system localisation behaviour.

## Contribution Prompt hierarchy

Contribution is voluntary and visually subordinate to route discovery and logging. A page presents at most one high-visibility contribution opportunity. Every prompt:

- explains the practical climbing benefit;
- offers a clear contribution action and **Not now**;
- can be dismissed for the current session opportunity;
- does not block browsing, beta reveal or Logbook use;
- never publishes private Logbook records, notes, attempts, height or arm span.

## Formalised page states

Loading, Empty, Error, Offline with cache, Offline without cache, Archived, Broken Link and Not Enough Community Data share a consistent hierarchy. Cached content remains browsable while an Offline Banner explains its status. Recoverable conditions expose an appropriate Retry, Clear Filters or Browse Map action. Debug fixture scenarios remain compile-time isolated from the Release experience.

## Known visual limitations

- Gym opening state, contact details and location permission remain development placeholders.
- The beta player is a labelled Development Preview and does not load external media.
- Comments, reporting, corrections and contribution publication are bounded placeholders.
- Mock account state is in memory; Stage 5 does not represent server-confirmed synchronisation.
- Validation uses available Simulator runtimes; no iOS 17 runtime is installed, so iOS 17 compatibility is verified by deployment-target compilation and availability checks.

## Future brand asset replacement points

The onboarding symbols, avatar placeholder, route photo placeholder and generic beta media symbol are intentional native stand-ins. A later approved brand phase can replace them with owned assets through the asset catalogue while preserving semantic labels, Dynamic Type layouts, Light and Dark variants and the existing component contracts.
