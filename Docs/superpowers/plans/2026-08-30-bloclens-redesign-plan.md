# BlocLens Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Incremental Moonlitt×Flighty×BlocLens redesign — Cold Zinc A — Route Detail hero first, 12 phases, zero business-logic changes.

**Architecture:** Extend existing `DesignTokens.swift` with semantic tokens (BlocColor/Typography/Spacing/Radius/Material/Motion/Haptics). Replace universal `cardStyle` with 3-level containers (Hero/GroupedRow/ElevatedCard). Route Detail becomes hero screen proving tokens, then propagate to Gym/Wall/Home/Map/Logbook/Beta. Glass via `glassEffect` progressive (iOS 26) with `ultraThinMaterial` fallback.

**Tech Stack:** SwiftUI · iPhone · iOS 17+ · Xcode · XCTest · Supabase (unchanged)

**Spec:** `Docs/superpowers/specs/2026-08-30-bloclens-redesign-design.md`

## Global Constraints

- SwiftUI iPhone iOS 17+ — do not raise deployment target for Liquid Glass; use `#available(iOS 26, *)` fallback
- Native Apple frameworks only — no third-party UI framework
- Preserve Supabase schema, auth, business logic, data model, features — UI redesign only
- Beta external-public-link-only — no video upload/hosting/transcoding
- Wall navigation via named zone lists — no 2D clickable wall map
- Private by default — logbook/notes/projects/statistics never public without explicit contribution action
- Optic Blue single accent for selection/active/focus/intelligence only — not whole-app blue
- Light + Dark full design, not invert — both checked every phase
- Dynamic Type, VoiceOver, Reduce Motion/Transparency, Increase Contrast, 44pt touch target
- Incremental, reviewable, reversible — no `git reset --hard`, no mass rewrite
- Private previews: `preview-home-A/B.html` are reference only, not production

---

## File Structure

**Modify:**
- `BlocLens/Core/DesignSystem/DesignTokens.swift` — extend with 12 hold colours, semantic Fresh/Project/ResetSoon/Archived, typography grade/status/metadata, spacing sectionGap, radius container/sheet/capsule, elevation tokens, BlocHaptics
- `BlocLens/Core/DesignSystem/VisualComponents.swift` — replace `RouteColourSwatch` hard-coded 8 ifs with 12-colour palette + shape
- `BlocLens/Features/RouteDetail/RouteDetailView.swift` — hero first
- `BlocLens/Features/GymDetail/GymDetailView.swift`
- `BlocLens/Features/WallZone/WallZoneRouteListView.swift`
- `BlocLens/Features/Home/HomeView.swift`
- `BlocLens/Features/Map/MapView.swift`
- `BlocLens/Features/Logbook/LogbookView.swift`
- `BlocLens/Features/Beta/BetaView.swift` (if exists)
- `BlocLens/App/AppShellView.swift` — centre + 56 vs 24
- `BlocLens/Features/**/Components/*` — RouteHero, RouteRow, WallZonePreview etc. only when duplicated

**Create (only when needed):**
- `BlocLens/Core/DesignSystem/BlocHaptics.swift` (if not in DesignTokens)
- `BlocLens/Core/Components/RouteLifecycleIndicator.swift`
- `BlocLens/Core/Components/GlassAction.swift` / `FloatingControl.swift`

**Verify:**
- `BlocLensTests/` — existing auth tests must pass
- Simulator screenshots Light/Dark per phase

---

### Task 1: Phase 1 — Design Foundation

**Files:**
- Modify: `BlocLens/Core/DesignSystem/DesignTokens.swift:1-76`
- Modify: `BlocLens/Core/DesignSystem/VisualComponents.swift:139-180`
- Test: `BlocLensTests/DesignTokensTests.swift` (new, minimal)

**Interfaces:**
- Consumes: existing `DesignColour`, `DesignSpacing`, `DesignTypography`, `DesignMotion`
- Produces: `BlocColor.routePalette`, `BlocColor.statusLifecycle`, `BlocTypography.grade/status/metadata`, `BlocSpacing.sectionGap`, `BlocRadius.container/sheet/capsule`, `BlocMaterial.glass`, `BlocHaptics`

- [ ] **Step 1: Write failing test for new tokens**

```swift
// BlocLensTests/DesignTokensTests.swift
import XCTest
@testable import BlocLens
final class DesignTokensTests: XCTestCase {
  func testRoutePaletteHas12ColoursWithShape() {
    XCTAssertEqual(BlocColor.routePalette.count, 12)
    for c in BlocColor.routePalette { XCTAssertNotNil(c.shape) }
  }
  func testGradeTypographyIsBoldTabular() {
    XCTAssertTrue(String(describing: BlocTypography.grade).contains("tabular"))
  }
}
```

- [ ] **Step 2: Run — verify FAIL** `xcodebuild test -only-testing:BlocLensTests/DesignTokensTests -destination 'platform=iOS Simulator,name=iPhone 16'`
- [ ] **Step 3: Extend DesignTokens.swift** — add 12 hold colours (Black/White/Yellow/Red/Blue/Green/Purple/Orange/Pink/Grey/Mint/Wood) each `color+textColor+shape`, lifecycle semantic colours, grade/status/metadata typography, spacing 48, radius 20/24/999, glass material `#available(iOS26, *) glassEffect(.regular.tint(BlocColor.opticBlueTint)) else .ultraThinMaterial`, haptics enum
- [ ] **Step 4: Replace RouteColourSwatch 8 ifs with palette lookup** `VisualComponents.swift:162-173` → `BlocColor.routePalette.first(where: {$0.name==holdColour}) ?? .grey`
- [ ] **Step 5: Run test — PASS** + existing tests PASS
- [ ] **Step 6: Commit** `git add BlocLens/Core/DesignSystem/ BlocLensTests/DesignTokensTests.swift && git commit -m "design: tokens — Cold Zinc A, 12 hold colours, grade/status typography"`

### Task 2: Phase 2 — Core Components (only duplicated)

**Files:**
- Create: `BlocLens/Core/Components/RouteLifecycleIndicator.swift` (if needed)
- Modify: `BlocLens/Core/Components/VisualComponents.swift` — refine GradeChip/StatusChip to use new tokens

**Interfaces:**
- Produces: `RouteLifecycleIndicator(lifecycle: .fresh/.active/.resetSoon/.archived)` with colour+icon+caption

- [ ] **Step 1: Inspect duplication** — list which of `RouteHero/RouteGrade/RouteRow/WallZonePreview` appear ≥2 times (keep list)
- [ ] **Step 2: Extract only duplicated** — create component only if count ≥2, with init using `BlocTypography`/`BlocColor`
- [ ] **Step 3: Screenshot before/after** — one screen, Light+Dark
- [ ] **Step 4: Commit** `git commit -m "design: core components — lifecycle indicator, refined chips"`

### Task 3: Phase 3 — Route Detail (HERO, first production)

**Files:**
- Modify: `BlocLens/Features/RouteDetail/RouteDetailView.swift:1-450`

**Interfaces:**
- Consumes: `BlocColor`, `BlocTypography`, `RouteLifecycleIndicator`, `BetaPreview`

- [ ] **Step 1: Write failing UI test** `RouteDetailHeroTests` — asserts first viewport contains V grade, location, status, reset, beta count without scrolling (hierarchy)
- [ ] **Step 2: Implement L0 full-bleed wall photo 4:3 + 30% gradient** — remove outer `cardStyle`, photo extends to notch, `.clipped()`
- [ ] **Step 3: Add floating glass capsules** `V5` solid + `Projecting` + `Reset 3d` (only glass), `#available(iOS26, *)`
- [ ] **Step 4: Title group no card, Divider separation** — `largeTitle` + `secondary` + `caption`
- [ ] **Step 5: Compact metadata row** `Cave · Dynamic · 25° · Community V5–V6` single line with new tokens
- [ ] **Step 6: Main actions capsule** `Log Send/Project/Flash` glass segmented, BetaPreview thumbnail+domain, private note solid
- [ ] **Step 7: Fold secondary** Details/Reports/Comments collapsed behind `View all`
- [ ] **Step 8: Build → Run Simulator → Screenshot Light/Dark/Dynamic Type → Critique via `design-taste-frontend` + `ponytail-review`**
- [ ] **Step 9: Commit** `git commit -m "design: Route Detail hero — wall as interface, typo before containers"`

### Task 4: Phase 4 — Wall Zone

**Files:**
- Modify: `BlocLens/Features/WallZone/WallZoneRouteListView.swift`

- [ ] **Step 1: Wall photo + terrain/angle header** — reuse RouteDetail hero pattern
- [ ] **Step 2: Route row high-density one-line** `HoldColour·V·Status·Beta·Reset` with `BlocTypography.caption` + dot shape
- [ ] **Step 3: Screenshot + commit**

### Task 5: Phase 5 — Gym Detail

**Files:**
- Modify: `BlocLens/Features/GymDetail/GymDetailView.swift`

- [ ] **Step 1: Gym hero (wall as interface) + state → Fresh Sets → Wall Zones → Routes** — Gym context, Route object
- [ ] **Step 2: Screenshot + commit**

### Task 6: Phase 6 — Home (Flighty priority)

**Files:**
- Modify: `BlocLens/Features/Home/HomeView.swift`
- Modify: `BlocLens/App/AppShellView.swift:28` — centre + 56

- [ ] **Step 1: Remove card wall** — 4 sections → grouped lists with dividers
- [ ] **Step 2: Current Gym hero** (wall photo)
- [ ] **Step 3: Active Projects sorted by reset urgency** `V6 Reset 2d` first, status pill
- [ ] **Step 4: Fresh Sets horizontal capsules + Recent Climbs timeline** (Flighty)
- [ ] **Step 5: Centre + larger (56 vs 24)** with shadow + haptics
- [ ] **Step 6: Screenshot Light/Dark + commit**

### Task 7: Phase 7 — Map (Moonlitt priority)

**Files:**
- Modify: `BlocLens/Features/Map/MapView.swift`

- [ ] **Step 1: Map is interface** — floating search/filters/preview glass, progressive disclosure
- [ ] **Step 2: Gym preview compact hierarchy** (Flighty)
- [ ] **Step 3: Screenshot + commit**

### Task 8: Phase 8 — Logbook (Flighty priority)

**Files:**
- Modify: `BlocLens/Features/Logbook/LogbookView.swift`

- [ ] **Step 1: Timeline TODAY → 10:42 Purple V4 FLASH / 11:03 Blue V5 SEND 3 attempts** — Time+State+Object, not database list
- [ ] **Step 2: Screenshot + commit**

### Task 9: Phase 9 — Beta (Moonlitt priority)

**Files:**
- Modify: `BlocLens/Features/Beta/*`

- [ ] **Step 1: Content is interface** — video first, minimal floating glass controls, Flighty clarity for metadata
- [ ] **Step 2: Screenshot + commit**

### Task 10: Phase 10 — Add / Profile / Settings

**Files:**
- Modify: `BlocLens/Features/**`

- [ ] **Step 1: Apply tokens, remove remaining cardSoup, unify spacing**
- [ ] **Step 2: Screenshot + commit**

### Task 11: Phase 11 — Motion + Haptics

**Files:**
- Modify: `BlocLens/Core/DesignSystem/DesignTokens.swift` (motion), `BlocHaptics` usages

- [ ] **Step 1: Gym→Wall→Route matchedGeometryEffect + state transitions**
- [ ] **Step 2: Reduce Motion instant fallback verified**
- [ ] **Step 3: Commit**

### Task 12: Phase 12 — Accessibility + Visual QA

**Files:**
- All modified views

- [ ] **Step 1: Dynamic Type 200% / VoiceOver (grade+shape) / Reduce Motion+Transparency / Increase Contrast / 44pt**
- [ ] **Step 2: Run `ponytail-audit` + `design-taste-frontend` critique — fix generic AI UI, excessive glass/card/gradient**
- [ ] **Step 3: Final screenshots Light/Dark comparison**
- [ ] **Step 4: Commit** `git commit -m "design: a11y + visual QA — Cold Zinc A complete"`

### Task 13: Phase 9-A — Logbook, Profile, Localisation & Light Mode Fix

**Files:**
- Modify: `BlocLens/Features/Logbook/LogbookView.swift`
- Modify: `BlocLens/Features/Profile/ProfileView.swift`
- Modify: `BlocLens/Features/Profile/ProfileEditView.swift`
- Modify: `BlocLens/DesignSystem/DesignTokens.swift`
- Modify: `BlocLens/Resources/Localisation/Localizable.xcstrings`
- Modify: `BlocLens/DesignSystem/Components/StateViews.swift` (if EmptyStateView needs action button param)
- Test: `BlocLensTests/ProfileEditTests.swift` (new)
- Test: `BlocLensTests/DesignTokenTests.swift` (extend)

**Skills required:** SwiftUI Expert, systematic-debugging, test-driven-development, verification-before-completion, redesign-existing-projects, minimalist-ui, ponytail

**Root causes found during exploration:**
- Logbook `.empty` case: VStack sits at top of content area — no centering, no `Spacer`, no `frame(maxWidth: .infinity, maxHeight: .infinity)`
- `profile.edit`: Key exists in String Catalog but localizations block is **empty** — falls back to raw key string
- All 13 `profileEdit.*` keys: Same — empty localizations, display raw keys at runtime
- Height/Arm span: `State(initialValue: profile?.heightCentimetres)` defaults to `nil` — no 170cm fallback
- Regular grade: V-Scale wheel filters `.unknown`, no "Not sure yet" sentinel
- Light Mode: `DesignColour.backgroundPrimary` = `.systemBackground`, `.surfacePrimary` = `.secondarySystemBackground` — on light devices both resolve to near-identical white

---

- [ ] **Step 1: Write failing tests (TDD)**

```swift
// BlocLensTests/ProfileEditTests.swift
import XCTest
@testable import BlocLens

final class ProfileEditTests: XCTestCase {
    func testNewProfileHeightDefaultsTo170cm() {
        let state = ProfileEditState(profile: nil)
        XCTAssertEqual(state.heightCentimetres, 170)
    }
    func testNewProfileArmSpanDefaultsTo170cm() {
        let state = ProfileEditState(profile: nil)
        XCTAssertEqual(state.armSpanCentimetres, 170)
    }
    func testSavedHeightNotOverwritten() {
        let profile = ClimbingProfile.mock(heightCentimetres: 180)
        let state = ProfileEditState(profile: profile)
        XCTAssertEqual(state.heightCentimetres, 180)
    }
    func testSavedArmSpanNotOverwritten() {
        let profile = ClimbingProfile.mock(armSpanCentimetres: 175)
        let state = ProfileEditState(profile: profile)
        XCTAssertEqual(state.armSpanCentimetres, 175)
    }
    func testRegularGradeNilShowsNotSureYet() {
        let state = ProfileEditState(profile: nil)
        XCTAssertTrue(state.isNotSureYet)
    }
    func testNotSureYetSavesAsNil() {
        var state = ProfileEditState(profile: nil)
        state.isNotSureYet = true
        state.vGrade = .v5
        let saved = state.toSavedGrade()
        XCTAssertNil(saved)
    }
}
```

- [ ] **Step 2: Run — verify FAIL** `xcodebuild test -only-testing:BlocLensTests/ProfileEditTests -destination 'platform=iOS Simulator,name=iPhone 16'`

- [ ] **Step 3: Fix Logbook empty state centering**
  - In `LogbookView.swift`, the `.empty` case (line ~66): wrap VStack in a container that fills available space
  - Use `Spacer()` at top and bottom of VStack to center the group
  - Add `frame(maxWidth: .infinity, maxHeight: .infinity)` to the container
  - Keep the existing `EmptyStateView` + `Button(L10n.Logbook.findRoute)` grouping
  - Ensure background matches `DesignColour.backgroundSecondary`
  - Verify Tab Bar does not overlap — the available area automatically excludes tab bar in a tabbed NavigationStack
  - Do NOT use hardcoded offsets, UIScreen, or screen-relative positions

- [ ] **Step 4: Fix Profile localisation key leaks**
  - In `Localizable.xcstrings`, populate all empty `profile.*` and `profileEdit.*` keys with en-AU source strings:
    - `profile.edit` → `"Edit"`
    - `profileEdit.title` → `"Climbing Profile"`
    - `profileEdit.subtitle` → `"Your measurements and preferred grade"`
    - `profileEdit.height` → `"Height"`
    - `profileEdit.armSpan` → `"Arm span"`
    - `profileEdit.cm` → `"cm"`
    - `profileEdit.measurements` → `"Measurements"`
    - `profileEdit.gradeSystem` → `"Grade system"`
    - `profileEdit.vScale` → `"V-Scale"`
    - `profileEdit.yds` → `"YDS"`
    - `profileEdit.regularGrade` → `"Regular grade"`
    - `profileEdit.gradeHint` → `"Your typical grade on this system"`
    - `profileEdit.notSureYet` → `"Not sure yet"`
    - `profileEdit.saveFailed` → `"Could not save. Please try again."`
  - Preserve existing ko and zh-Hans entries (keep structure, do not fill with machine translation unless confirmed)
  - Audit all Profile views for any remaining `Text("profile.*")` or `Text(verbatim:)` that should be localized
  - Audit `ProfileView.swift` account access section — replace hardcoded `Text(verbatim: "Account access")` etc. with `L10n.Profile.*` keys or new keys in String Catalog
  - Verify no `Text("profile.")` patterns remain via grep

- [ ] **Step 5: Fix Height & Arm span defaults**
  - In `ProfileEditView.swift`, when `profile?.heightCentimetres` is nil, default `State` to `170`
  - When `profile?.armSpanCentimetres` is nil, default `State` to `170`
  - Toggle `_hasHeight` defaults to `true` when height is nil (new user should see the picker with 170 pre-selected)
  - Toggle `_hasArmSpan` defaults to `true` when arm span is nil
  - Ensure Cancel discards defaults without writing to profile
  - Ensure Save only persists when user has interacted
  - VoiceOver: verify "170 centimetres" reads correctly
  - No new Service or ViewModel needed — edit the existing State initializers

- [ ] **Step 6: Add "Not sure yet" to Regular grade picker**
  - In the V-Scale wheel, add a leading `"Not sure yet"` option that maps to `nil` grade
  - In the YDS wheel, add the same
  - When "Not sure yet" is selected: `isNotSureYet = true`, grade fields = nil
  - When a specific grade is selected: `isNotSureYet = false`
  - "Not sure yet" must NOT participate in grade sorting, highest grade, distribution, or filter
  - New users with no saved grade default to "Not sure yet" selected
  - Add `profileEdit.notSureYet` to String Catalog with en-AU value `"Not sure yet"`

- [ ] **Step 7: Fix Light Mode visual hierarchy**
  - Audit DesignTokens.swift light mode values:
    - `backgroundPrimary` (.systemBackground): on light = pure white — too uniform with cards
    - `surfacePrimary` (.secondarySystemBackground): on light = very light grey — minimal contrast
    - `surfaceElevated` (.tertiarySystemBackground): on light = slightly different grey
  - Replace system colors with explicit palette for light mode:
    - `backgroundPrimary`: `Color(white: 0.96)` — soft off-white grouped background
    - `surfacePrimary`: `.white` — clean card/surface
    - `surfaceElevated`: `Color(white: 0.98)` — slightly elevated
    - `separator`: `Color(white: 0.88)` — visible but subtle
  - Keep Dark Mode values unchanged (`.systemBackground` etc. work well in dark)
  - Check all pages listed in spec: Home, Map, Gym Detail, Wall Zone, Route Detail, Beta, Logbook, Profile, Settings, Empty/Offline/Error states
  - Do NOT hardcode colors per page — fix at the token level
  - Do NOT use shadows, heavy borders, or gradients for hierarchy — use subtle background differentiation only
  - Ensure text contrast ratios remain accessible

- [ ] **Step 8: Run tests — verify PASS**

- [ ] **Step 9: Simulator verification**
  - Device 1: iPhone 16 Pro (regular size)
  - Device 2: iPhone SE or iPhone 13 mini (small size)
  - Modes: Light + Dark
  - Dynamic Type: Large
  - Verification path:
    1. Logbook empty state — button centered, not clipped by tab bar
    2. Tap "Find a route" — navigates to map tab
    3. Return to Logbook
    4. Profile — "Climbing profile" section, Edit button shows "Edit"
    5. Tap Edit — no raw `profile.*` keys visible
    6. Height shows 170cm for new profile
    7. Arm span shows 170cm for new profile
    8. Regular grade shows "Not sure yet"
    9. Select a grade, Cancel — grade reverts
    10. Select "Not sure yet", Save — persists nil
    11. Reopen — still shows "Not sure yet"
    12. Toggle Light/Dark — backgrounds have visible hierarchy
    13. Check Home, Gym Detail, Route Detail in Light Mode
  - Screenshots to `/private/tmp/`

- [ ] **Step 10: Accessibility check**
  - VoiceOver reads all profile labels correctly
  - Dynamic Type scales empty state and profile edit
  - 44pt touch targets on buttons
  - No raw localization keys in accessibility labels

- [ ] **Step 11: Ponytail review**
  - No new Service created for defaults
  - No duplicate EmptyStateView component
  - No new Design Token for a single color — fixed at existing token level
  - No complex grade system for nil — simple boolean + nil
  - No per-page color hardcoding
  - No unnecessary包装层

- [ ] **Step 12: Commit** `git commit -m "fix: polish logbook profile and light mode states"`

---

## Self-Review

- Spec coverage: all 12 phases map to spec §43; tokens §F, Route Detail §G hero, Home §18, Map §25, Beta §26, Logbook §27 all have tasks — no gaps
- Task 13 adds: Logbook empty state layout, Profile localisation, Height/Arm span defaults, Regular grade "Not sure yet", Light Mode hierarchy
- Placeholders: none — every step has file paths, code, or exact expectations
- Type consistency: `BlocColor.routePalette` shape, `BlocTypography.grade` tabular, `RouteLifecycleIndicator` lifecycle enum consistent across Task 2-3

