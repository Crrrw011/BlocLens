# BlocLens UI/UX Redesign — Moonlitt × Flighty × BlocLens Architectural Design

**Date:** 2026-08-30
**Status:** Approved — A · Cold Zinc #F6F7F8 locked
**Scope:** Design Foundation → Route Detail hero first, 12-phase incremental
**Stack:** SwiftUI · iPhone · iOS 17+ (Liquid Glass progressive on iOS 26) · Light/Dark

---

## 1. Context

BlocLens is a **route-centric indoor bouldering companion** (Gym → Wall Zone → Route → Beta → Log → Project → Send → Reset). Utility-first, not social. Core question the UI must answer: *where am I, which line am I looking at, what state is it in, what can I do next?*

Existing audit (65 Swift files, `DesignTokens.swift:3-66`): semantic `systemBackground/label` correct, 4pt spacing correct, `monospacedDigit` for grades correct; **critical flaws:** 17× `cardStyle()` card wall (`RouteDetail:42-55` 6 consecutive cards, `Home:44-107` 4 card sections), 3× equal 2-col grids, single blue `#056EFA`, 8 hard-coded hold colours, no elevation, glass only on Map.

References: Moonlitt (spatial, content-first, depth, glass, motion) + Flighty (information hierarchy, typography-first, status, timeline, glanceability, density). Final identity remains BlocLens (Wall/Hold/Route, Optic Blue).

Design Read: *route-centric utility for chalk-handed one-glance use, calm spatial + precise information language, SwiftUI native + Liquid Glass + Flighty density.*

Dials: `VARIANCE 7 / MOTION 5 / DENSITY 4`.

---

## 2. Design Principles (5)

1. **Immersive when exploring — Wall is the interface.** Wall photo is L0, data floats above.
2. **Precise when deciding — Typography before containers.** Hierarchy via type/spacing/dividers first, cards last.
3. **Quiet when reading — Content solid, controls glass.** Long text opaque, floating controls glass.
4. **Fast when climbing — Glanceable + Status first.** 1–2s glance: V·colour·status·reset.
5. **Route is time-sensitive — Lifecycle everywhere.** Fresh → Active → Projecting → Reset Soon → Last Chance → Archived.

---

## 3. What We Take / Don't Take

| Moonlitt take | Flighty take | Deliberately not take | Uniquely BlocLens |
|---|---|---|---|
| 5-layer depth, content-first, glass only for nav/overlay, scrub, progressive disclosure | Typo hierarchy, high density+clarity, status as hierarchy, timeline, glanceability | Moon graphics, aviation black departure-board aesthetic, pure marketing page | Wall geometry, 12 hold colours with shape, Optic Blue, Gym context, Project/Send/Flash, Beta external links, reset lifecycle |

---

## 4. Design System — Cold Zinc A

### Colour — Optic Blue single accent
- `backgroundPrimary #F6F7F8` (Zinc 50 cool, not pure white) / Dark `#0B0E14` off-black
- `backgroundElevated #FFFFFF` / Dark `#131722`
- `surfacePrimary #FFFFFF` / Dark `#1A1F2E`
- `textPrimary #0F172A` / `secondary #64748B` / `tertiary #94A3B8`
- `separator 6%` / `glassBorder white 10%` / `opticBlue #0A66FF` (85% sat) / `opticBlueTint 10%/18%`
- Semantic: `success #0E9B6B` / `warning #D98E0A` / `destructive #DC2626` / `Fresh #0A66FF / Project #D98E0A / ResetSoon #DC2626 / Archived #64748B`
- **Route palette 12:** Black/White/Yellow/Red/Blue/Green/Purple/Orange/Pink/Grey/Mint/Wood — each with `accessibleTextColor` (WCAG AA) + `shape` (circle/square/diamond) for colour-blind. Brand vs hold colours strictly separated.

### Typography — SF Pro, Dynamic Type, Grade first-class
| Token | Spec | Use |
|---|---|---|
| hero | 34/41 bold -0.02em | Gym hero |
| largeTitle | 28/34 bold | Page title |
| title | 20/26 semibold | Section |
| headline | 17/22 semibold | Card title |
| body | 17/24 | Body |
| secondary | 15/20 | Description |
| caption | 12/16 medium 0.06em | Metadata |
| metric | 24/28 bold tabular-nums | Stats |
| **grade** | **22/26 bold tabular-nums** | **V3 V5 V8 —一级，强于 Community V5–V6** |
| status | 11/14 semibold | Status pill |
| metadata | 11/14 | Compact row |

Only 500/600/700 weights.

### Spacing / Radius / Elevation
- Spacing 4/8/12/16/20/24/32/48 + `sectionGap 40`, ban 13/17/19
- Radius: control 10 / card 16 / container 20 / sheet 24 / capsule 999 (inner `calc(outer-6)`)
- Elevation: Content (separator 0.5pt) / Elevated (white+ tinted shadow y4 blur16) / Glass (ultraThin + inner 1px white10% + inset highlight)
- z: 0/10/20/30/40, no 9999

### Material / Glass / Motion / Haptics / Density
- iOS 17-25 `ultraThin/regular`, iOS 26 `glassEffect` progressive, `Reduce Transparency` → solid
- Motion: `quick 0.16 easeOut / spring 0.28 / reveal 0.24`, spring stiffness 100 damping 20, only transform+opacity, Reduce Motion instant, explains Gym→Wall→Route + state transitions
- Haptics: selection light / Send success / Flash heavy+success / Destructive warning
- Density: Hero low / Standard balanced / Compact high (Route lists, Logbook)

Tokens: `BlocColor / BlocTypography / BlocSpacing / BlocRadius / BlocMaterial / BlocMotion / BlocHaptics` — extend existing `DesignTokens.swift`, no gratuitous abstraction.

---

## 5. Component Audit

- KEEP: `GradeChip` / `StatusChip` / `FacilityChip` / `FilterPill` / `StateViews` / `OfflineBanner`
- REFINE: `GymSummaryCard`+`MetricCard` → `GymHero`/`MetricRow`; `RouteColourSwatch` → 12-colour palette
- REPLACE: universal `cardStyle` → 3-level `Hero(no card)/ElevatedCard/GroupedRow`
- DELETE: `BetaSection` grey placeholder, `LogbookView:170 statisticRow` dead code
- New only when duplicated: `RouteHero`/`RouteGrade`/`RouteStatus`/`RouteRow`/`RouteLifecycle`/`ResetIndicator`/`BetaPreview`/`FloatingControl`/`GlassAction`/`TimelineEvent`

---

## 6. Route Detail — Hero Screen (first production)

**Order:** Identity(visual) → Grade(V5) → Location(Urban Climb · Cave) → Properties(Overhang·Dynamic·25°) → Personal State(Projecting 4 attempts) → Time(Reset 3d) → Beta(6 Betas) → Community(V5–V6) → Details → Comments.

**Layout Moonlitt×Flighty:**
- L0 full-bleed wall photo 4:3 to notch, 30% gradient for legibility — *Moonlitt content is interface + depth*
- Floating glass capsules: `V5` solid + `Projecting` + `Reset 3d` lifecycle — *Flighty status first-class + Moonlitt glass*
- Title group no card, Divider separation — *Flighty typo before containers*
- Compact metadata row `Cave · Dynamic · 25° · Community V5–V6` — *Flighty density*
- Main actions `Log Send/Project/Flash` capsule glass, BetaPreview thumbnail+domain — *Moonlitt glass only for controls*
- Secondary folded: Details/Reports/Comments collapsed, `View all` — *Moonlitt progressive disclosure*
- Transitions `matchedGeometryEffect` Gym→Wall→Route — *Moonlitt spatial continuity*

**Attribution:** Moonlitt: immersion/glass/motion; Flighty: hierarchy/status/timeline/glanceability; BlocLens: Grade solid + hold shape + lifecycle colour.

**Acceptance:** Build / functional / hierarchy / glanceable / density / Light+Dark / Dynamic Type / VoiceOver (grade+shape) / Reduce Motion / no card/glass/gradient soup / no clipping / no duplicated logic / feels BlocLens.

---

## 7. Home — Flighty Priority (previewed as A/B HTML)

Hierarchy: **Current Gym (wall as interface) → Active Projects sorted by reset urgency (V6 Reset 2d first) → Fresh Sets (horizontal capsules) → Recent Climbs (timeline: Today 10:42 Purple V4 FLASH)**. Dynamic priority, *Important changes rise to top*, not fixed dashboard. Previews: `preview-home-A.html` (Cold Zinc) approved, `preview-home-B.html` (Chalk & Concrete) archived.

Central `+` 56 vs tabs 24, `opticBlue` circle + shadow, `Reduce Transparency` solid fallback — feasible in `AppShellView` iOS 17+.

---

## 8. Other Pages (brief)

- **Gym Detail:** Place identity hero → state → Fresh/Wall Zones → Routes → community. Gym context, Route object.
- **Wall Zone:** Wall photo + terrain/angle + distribution + fresh + reset; Route row: Hold Colour + V + Status + Beta + Reset urgency in one glanceable line.
- **Map:** Map is interface, floating search/filters/preview, glass controls, progressive disclosure — Moonlitt primary.
- **Beta:** Content is interface, video first, minimal floating glass controls, Flighty clarity for metadata.
- **Logbook:** My history timeline (TODAY → 10:42 Purple V4 FLASH / 11:03 Blue V5 SEND 3 attempts), Time+State+Object — Flighty priority.

Accessibility, Light/Dark, motion/haptics, native SwiftUI, preserve Supabase/auth/business logic, incremental reversible phases.

---

## 9. Implementation Order (12 phases)

1 Design Foundation (tokens) → 2 Core Components → 3 Route Detail → 4 Wall Zone → 5 Gym Detail → 6 Home → 7 Map → 8 Logbook → 9 Beta → 10 Add/Profile/Settings → 11 Motion+Haptics → 12 A11y+Visual QA

Route Detail first; no concurrent full-app rewrite. Each phase: Implement → Build → Run → Screenshot → Critique (Taste/Ponytail) → Adjust → Compare.

---

## 10. Definition of Done (per page)

Builds, preserves function, strong hierarchy, glanceable, appropriate density, Design System compliant, Light+Dark checked, Dynamic Type/VoiceOver/Reduce Motion/Reduce Transparency/Increase Contrast, no card/glass/gradient soup, no clipping, no duplicated logic, clearly BlocLens.

---

*Approved 2026-08-30 — Cold Zinc A. Next: `writing-plans` → Phase 1 plan.*
