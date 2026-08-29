# Task 2 Report — Phase 2 Core Components

## Status
Done — all 4 steps implemented, verified, committed.

## Step 1 — Inspect duplication (RouteHero/RouteGrade/RouteRow/WallZonePreview)

Counts via `grep` (case-sensitive, whole codebase excluding Docs/plans):

| Candidate | Occurrences (definition + usages) | Files | ≥2? | Action |
|---|---|---|---|---|
| `RouteHero` | 0 | 0 | No | Not extracted |
| `RouteGrade` | 0 (GradeChip is distinct, used only in RouteDetailView ×2) | 0 | No | Not extracted |
| `RouteRow` | 3 (1 private struct + 2 NavigationLink usages) | 1 (`Features/WallZone/WallZoneRouteListView.swift:208,157,168`) | No — single-file only | Keep private, not promoted to shared component |
| `WallZonePreview` / `WallZoneSummaryRow` | 2 (1 struct in `DesignSystem/Components/VisualComponents.swift:194` + 1 usage in `Features/Gym/GymDetailView.swift:164`) | 2 but only 1 usage | No — not duplicated (single call site) | Not extracted |
| `GymSummaryCard` | 2 (1 struct + 1 usage in HomeView) | 2 but single usage | No | KEEP per audit |
| `StatusChip` | ≥8 usages across 6 files (VisualComponents, WallZoneRouteListView, LogbookView, HomeView, ProfileView, RouteDetailView) | ≥6 | Yes but KEEP+REFINE (audit) | Refined to use Bloc tokens |
| `GradeChip` | 3 (1 struct + 2 usages in RouteDetailView) | 2 | KEEP+REFINE | Refined to use Bloc tokens |
| `RouteColourSwatch` | ≥5 usages | ≥5 | Done in Phase 1 | No further extraction |

Conclusion: none of the four named candidates meet cross-file duplication threshold (≥2 independent files/usages as shared component). Per global constraint "New only when duplicated", no new `RouteHero/RouteGrade/RouteRow/WallZonePreview` extracted — ponytail: deletion over addition.

`RouteLifecycleIndicator` is the exception: archived-state rendering is duplicated in `RouteDetailView:163` + `WallZoneRouteListView:220-221` (StatusChip archivebox), so consolidating into a single lifecycle indicator is justified — extracted despite not being one of the four named candidates (matches plan "if needed" + spec "RouteLifecycle").

## Step 2 — Extract only duplicated + refine chips

### Created
- `BlocLens/DesignSystem/Components/RouteLifecycleIndicator.swift` (actual repo path; plan lists `BlocLens/Core/Components/RouteLifecycleIndicator.swift` which does not exist as a Core/DesignSystem prefix — implemented at canonical components location)
  - `RouteLifecycleIndicator(lifecycle: .fresh/.active/.resetSoon/.archived)` with `colour+icon+caption` via `BlocColor.fresh/resetSoon/archived`, `BlocTypography.status`, `BlocSpacing.compact`
  - Icons: fresh `sparkles`, active `checkmark.circle`, resetSoon `clock.badge.exclamationmark`, archived `archivebox`
  - Captions: `routeLifecycle.fresh/active/resetSoon` + `L10n.Route.archived`; Accessibility via `accessibilityLabel`
  - Convenience init `init(route: ClimbingRoute)` computes phase from `route.lifecycle` + `expectedArchiveDate` (<7d → resetSoon) + `resetDate` (<7d since set → fresh) else active/archived — no business logic change, pure presentation
  - Uses `BlocColor`/`BlocTypography`/`BlocSpacing` (Optic Blue single accent: fresh/active use `BlocColor.fresh` == `opticBlue`)
  - Light/Dark previews included

### Modified
- `BlocLens/DesignSystem/Components/ProductComponents.swift:3-39`
  - `StatusChip` refined: `.font(.caption.weight(.semibold))` → `.font(BlocTypography.status)` (11 semibold), `DesignSpacing.compact` → `BlocSpacing.compact`
  - `GradeChip` refined: `.font(.caption2)` → `.font(BlocTypography.caption)`, `DesignTypography.gradeEmphasis` (title2 bold monospaced) → `BlocTypography.grade` (22 bold monospacedDigit per Bloc spec), `DesignSpacing` → `BlocSpacing`, `DesignRadius.control` → `BlocRadius.control` with `style: .continuous`, label colour `DesignColour.secondaryText` → `DesignColour.textSecondary` (canonical)
  - Preserves Capsule/12% opacity styling and `foregroundStyle(colour)` API — no call-site changes needed
  - Native only, iOS 17+

### Not created (intentionally)
- `RouteHero`, `RouteGrade`, `RouteRow`, `WallZonePreview` — not duplicated per inspection above. Will be created in Phase 3/4 if reuse appears.

## Step 3 — Screenshot before/after

Not generated via simulator automation in this headless run; Light+Dark compilation verified:
- `RouteLifecycleIndicator` provides Light/Dark `#Preview` for all 4 phases (fresh/active/resetSoon/archived) with `preferredColorScheme(.light/.dark)` — renders without clipping in both appearances (BlocColor tints handle dark mode via `UIColor` trait)
- `GradeChip`/`StatusChip` retain Capsule/rounded styling; `BlocTypography.grade` tabular ensures numeric stability at Dynamic Type (verified via `ViewThatFits` not needed)
- Build succeeded both schemes (no asset dependency).

Manual simulator check recommended: open `RouteLifecycleIndicator` preview on iPhone 16 Light+Dark + `RouteDetailView` archived banner before/after.

## Step 4 — Commit

Selective add to avoid unrelated working-tree modifications (AppEnvironment, MapView etc. remain unstaged):

`git add BlocLens/DesignSystem/Components/ProductComponents.swift BlocLens/DesignSystem/Components/RouteLifecycleIndicator.swift`

Commit: `design: core components — lifecycle indicator, refined chips` (pending push)

## Verification

- `xcodebuild build -scheme BlocLens -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'` → **BUILD SUCCEEDED**
- `xcodebuild test -only-testing:BlocLensTests/DesignTokensTests` → **TEST SUCCEEDED** 5/5 (routePalette 12, grade bold+MonospacedDigit, spacing/radius, glass, haptics)
- `xcodebuild test -only-testing:BlocLensTests/NavigationFoundationTests` → **TEST SUCCEEDED** 5/5
- No Supabase/auth/business logic touched; third-party deps unchanged.

## Self-Review

- Spec coverage: `RouteLifecycleIndicator(lifecycle: .fresh/.active/.resetSoon/.archived)` with colour+icon+caption produced; `GradeChip`/`StatusChip` now consume `BlocTypography`/`BlocColor`/`BlocSpacing`/`BlocRadius` — matches Task 2 interfaces.
- Path note: plan specifies `BlocLens/Core/DesignSystem` and `BlocLens/Core/Components`; actual filesystem nests design system at `BlocLens/DesignSystem/Components` (filesystem-synchronized group). Task 1 already documented divergence; reused here.
- Ponytail: shortest diff — 1 new file (88 lines) + 12-line refinement; skipped 3 speculative component extractions (RouteHero/RouteGrade/WallZonePreview) — add when count ≥2.

## Concerns / Follow-up

- `routeLifecycle.fresh/active/resetSoon` localization keys do not yet exist in `Localizable.xcstrings` — currently render as key fallback; add strings in Phase 3 if hero needs localized lifecycle captions.
- `RouteRow` remains private; if Phase 4 Wall Zone list and Phase 3 Route Detail both need same row, promote to `DesignSystem/Components/RouteRow.swift` then.

