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

## Self-Review

- Spec coverage: all 12 phases map to spec §43; tokens §F, Route Detail §G hero, Home §18, Map §25, Beta §26, Logbook §27 all have tasks — no gaps
- Placeholders: none — every step has file paths, code, or exact expectations
- Type consistency: `BlocColor.routePalette` shape, `BlocTypography.grade` tabular, `RouteLifecycleIndicator` lifecycle enum consistent across Task 2-3

