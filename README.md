<div align="center">

# Drawer

### Scan a kitchen drawer. Get a custom 3D-printable organizer. Slice it natively for a Bambu Lab A1.

<br>

![Platform](https://img.shields.io/badge/platform-iOS%2026.2%2B-blue)
![Language](https://img.shields.io/badge/Swift-5.0-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20Liquid%20Glass-purple)
![Slicer](https://img.shields.io/badge/Slicer-Bambu%20A1%20native-green)
![3D](https://img.shields.io/badge/3D-SceneKit%20preview-lightgrey)
![Measurement](https://img.shields.io/badge/Measure-LiDAR%20%2B%20Vision-yellow)

<br>

*An iOS app that turns a photo of an empty kitchen drawer into a printer-ready `.gcode.3mf` file with custom-fitted, color-coded organizer modules — all on-device.*

</div>

---

## Table of Contents

1. [What is Drawer?](#1-what-is-drawer)
2. [Demo & Screenshots](#2-demo--screenshots)
3. [Features at a Glance](#3-features-at-a-glance)
4. [Install](#4-install)
5. [System Architecture](#5-system-architecture)
6. [The User Journey](#6-the-user-journey)
7. [Codebase Tour](#7-codebase-tour)
8. [Subsystem Deep-Dives](#8-subsystem-deep-dives)
   - [8.1 The Measurement Pipeline](#81-the-measurement-pipeline)
   - [8.2 The Layout Engine](#82-the-layout-engine-the-heart-of-the-app)
   - [8.3 3D Mesh Generation](#83-3d-mesh-generation)
   - [8.4 The Bambu A1 Slicer](#84-the-bambu-a1-slicer)
   - [8.5 3D Previews](#85-3d-previews)
   - [8.6 AR Drawer Preview](#86-ar-drawer-preview-v02)
   - [8.7 Kitchen Planning](#87-kitchen-planning-v02)
   - [8.8 Live Activity for Print Progress](#88-live-activity-for-print-progress-v02)
   - [8.9 Liquid Glass UI](#89-liquid-glass-ui)
9. [Data Model](#9-data-model)
10. [Persistence](#10-persistence)
11. [Glossary for Non-Coders](#11-glossary-for-non-coders)
12. [Build & Run](#12-build--run)
13. [License](#13-license)

---

## 1. What is Drawer?

### The Problem

Kitchen drawers are chaotic. Cutlery slides, spices roll, batteries mingle with rubber bands. Off-the-shelf organizers are sized for *some* drawer — never *yours*. Custom inserts cost a fortune; designing your own takes CAD skills most people don't have.

### The Solution

**Drawer** turns your iPhone into an end-to-end drawer-organization studio:

1. **Scan** an empty drawer with your phone's camera (LiDAR if your device has it; otherwise a credit-card reference for scale).
2. **Mark obstacles** — rails, raised areas, drain holes, dishwasher screws — that the layout should avoid.
3. **Confirm** the auto-detected dimensions on a live overlay.
4. **Pick a category** — Utensils, Spices, Office Supplies, etc., plus your own custom-defined modules.
5. **The layout engine** generates a custom layout where related items end up *physically adjacent* (forks/spoons/knives in a tight row, spice rows stacked, pen-tray + sticky notes + index cards as a writing zone) and routes around any obstacles you marked.
6. **Add stacked tiers** if you want a 2-level organizer; the engine emits real locating-lip geometry so the top tier doesn't slide.
7. **Preview** the result in an interactive 3D viewer with an explode toggle, *or* in an AR overlay positioned in your real drawer at real scale.
8. **Group** related drawers into a kitchen plan and design your whole kitchen as one project.
9. **Export** a printer-ready `.gcode.3mf` for the **Bambu Lab A1** with on-device slicing, **track print progress** with a Live Activity, and see filament cost computed from your $/kg setting. Modules bigger than the printer bed automatically split into snap-together pieces.

Everything happens on your phone. No cloud. No subscription.

### Why This Is Hard (And Interesting)

The core technical challenges:

- **Accurate measurement from a photo.** Mixing ARKit LiDAR depth, Vision rectangle detection, and a credit-card scale reference fallback.
- **Context-aware layout.** Bin-packing is NP-hard and naive solvers will scatter related items. Drawer treats each semantic group as a *cohesive block*, chooses the arrangement (row / column / wrapped grid) that matches the items' natural shape, and respects user-marked keep-out zones.
- **A real on-device slicer for Bambu A1.** Not a third-party plugin — actual G-code generation, AMS lite tool-change planning, and the 16-file `.gcode.3mf` package format Bambu Studio expects.
- **AR at real scale, on a real drawer.** ARKit world tracking + plane detection + the same mesh data the print pipeline uses, so the overlay is exactly what will print.
- **Mechanical interlocks for stacking.** Tier-2 modules carry a smaller-footprint locating lip that drops into the tier-1 cavity — a real, physical, geometric solution to the "top tray slides around" problem.
- **Auto-split for oversize.** When a tray exceeds the printer bed, automatic bisection produces snap-together pieces with proper labeling so the user can assemble them in the drawer.

---

## 2. Demo & Screenshots

> *Add captured GIFs / screenshots here when ready. Suggested clips:*
> - Home screen with the Liquid Glass tab bar in motion
> - LiDAR scan locking onto the drawer rim with the live quad overlay
> - The blueprint view animating items in after layout generation
> - The 3D preview spinning, showing per-tray colors
> - A `.gcode.3mf` opening in Bambu Studio with the slice intact

---

## 3. Features at a Glance

| Area | What It Does |
|---|---|
| **Measurement** | LiDAR depth scanning with stability-locked capture; falls back to a credit-card reference scale when LiDAR is unavailable; manual override always available. |
| **Obstacle marking** | Tag rails, drain holes, dishwasher screws, and raised areas as keep-out zones. The packer routes around them. |
| **Categories** | 7 built-in purposes (Utensils, Junk Drawer, Spices, Baking Tools, Office Supplies, Linens, Custom) with curated organizer catalogs per category. |
| **Custom modules** | Define your own modules (width × depth × name × color), persisted across drawers via the user-template store. |
| **Smart Layout** | Group-aware shelf packer that places related items as cohesive blocks — cutlery in tight rows, spices stacked, writing-zone items in a 2-row grid. Honors marked obstacles. |
| **Multi-tier stacking** | Add a tier-2 organizer above any tray. Visual drawer-map picker shows where you're stacking; side-view preview shows fit. Real locating-lip geometry keeps the top tray from sliding. |
| **Edit Organizers** | Add or remove individual organizers post-generation; the engine lays them out with the same context-aware logic. |
| **AR Drawer Preview** | ARKit-based pass-through. Tap to drop the layout on the detected floor at real scale. Tap modules to inspect dimensions, pinch to scale, twist to rotate, long-press to drag. |
| **3D View with Explode** | Dedicated SceneKit 3D viewer for inspecting layouts. Tap "Explode stack" to lift tier-2 modules + their locating lips so you can see how they interlock. |
| **3D Print Preview** | Interactive SceneKit viewer with auto-rotate, drag-to-rotate, pinch-to-zoom, color-coded per AMS lite slot. |
| **Auto-split** | Modules bigger than the printer bed automatically split into "Foo (1/2)" + "Foo (2/2)" pieces that print fine and snap together in the drawer. |
| **Slicing** | Native Bambu Lab A1 G-code generation: per-layer toolpaths, AMS lite color ranges, real `.gcode.3mf` Bambu Studio recognizes. Other printers fall back to a clean `.3mf` for external slicers. |
| **AMS Lite** | 4-slot plate, 4 coloring policies (mono, per-module, per-feature, custom), automatic per-layer filament-list computation. Real-color picker (not a Menu of black SF Symbols). |
| **Filament cost** | Set $/kg once, every print prep shows total cost, per-gram cost, and grams. |
| **Live Activity / Print tracker** | After exporting, start an in-app countdown. ActivityKit infrastructure ready for Lock Screen / Dynamic Island once a Widget Extension target is added. |
| **Kitchen Plans** | Group multiple drawers into a single kitchen project with per-drawer location labels. Design your entire kitchen as one design. |
| **Persistence** | Saved drawers, custom templates, kitchen plans, and cost setting stored in `UserDefaults`. Photo thumbnails included. |
| **Liquid Glass UI** | Real iOS 26 `.glassEffect()` material on the bottom tab bar, AR controls, and 3D viewer chips — not a custom approximation. |
| **Animations** | Symbol effects, phase animators, matched geometry, sensory feedback, staggered entry — every interaction has a small physics-based response. |

---

## 4. Install

> ⚠️ **iOS doesn't allow installing arbitrary `.ipa` files by direct download.** This release ships through the open-source iOS sideloading pattern: download the IPA from the Releases page, then have a sideloader re-sign it with your own Apple ID. Below are the realistic steps.

### Requirements

| Requirement | Detail |
|---|---|
| **iOS version** | 26.2 or later — Drawer uses Liquid Glass APIs that don't exist on earlier iOS |
| **Device** | iPhone or iPad. LiDAR-equipped models (iPhone 12 Pro and newer Pro models, iPad Pro M-series) get the best measurement experience; non-LiDAR devices fall back to a credit-card reference scan |
| **Apple ID** | Any Apple ID — used by the sideloader to re-sign the IPA |
| **A computer** | Mac or Windows PC, used once to set up the sideloader |

### Step-by-step (using AltStore — the most common path)

[AltStore](https://altstore.io) is a free, open-source app installer that re-signs IPAs with your Apple ID and pushes them to your iPhone. It's how most open-source iOS apps are distributed.

1. **Install AltStore on your computer**
   - Mac: download AltServer from [altstore.io](https://altstore.io), drag to Applications, launch
   - Windows: download AltServer for Windows, run the installer, install iTunes + iCloud (required for the WiFi sync layer)

2. **Install AltStore on your iPhone**
   - Plug your iPhone into your computer via USB
   - In the menu bar (Mac) or system tray (Windows), click the AltServer icon → "Install AltStore" → pick your iPhone
   - Sign in with your Apple ID when prompted (this is what re-signs the IPA later)

3. **Trust the developer profile**
   - On your iPhone: **Settings → General → VPN & Device Management** → tap your Apple ID under "Developer App" → **Trust**
   - You should now see the AltStore app on your home screen

4. **Download the IPA**
   - Go to [Releases](https://github.com/DrSk3l3t0r/Drawer/releases/latest) on this repo
   - Tap the `Drawer-vX.Y.Z.ipa` link to download it to your iPhone
   - Tap **Open in AltStore** when iOS asks where to send the file

5. **AltStore re-signs and installs Drawer**
   - AltStore takes ~1-2 minutes to re-sign the IPA with your Apple ID and push it to the phone
   - When done, Drawer appears on your home screen

### Alternative sideloaders

- **[Sideloadly](https://sideloadly.io)** — Mac/Windows GUI tool that's a one-shot install (no AltServer running in the background). Same Apple-ID-based re-signing, same 7-day expiry on free accounts.
- **[TrollStore](https://github.com/opa334/TrollStore)** — works only on specific iOS versions with a particular CoreTrust bug. **Permanent install, no expiry, no Apple ID required.** Check the TrollStore compatibility list to see if your iOS version is supported.
- **AltStore PAL (EU only)** — Apple-sanctioned third-party marketplace, available in the EU under the Digital Markets Act.

### Building from source instead

If you'd rather build the app yourself in Xcode (avoids the IPA + sideloader dance entirely — Xcode signs and installs directly to your phone), see [Section 12 — Build & Run](#12-build--run). You'll need an Apple ID and Xcode 26+.

### Honest disclaimers

- **This is pre-release software.** UI is polished but you should expect rough edges in measurement accuracy and slicer edge cases. Don't run a 30-hour print without first verifying the `.gcode.3mf` in Bambu Studio.
- **No warranty, no support contract.** See the MIT [`LICENSE`](LICENSE).
- **Sideloading uses your personal Apple ID.** AltStore and Sideloadly are reputable open-source tools that don't expose your credentials, but you're trusting them with your Apple ID for the duration of the install.
- **Apple may change sideloading rules.** This install method has worked since 2019 but Apple controls iOS — future iOS versions could tighten or loosen sideloading. Check the AltStore project for current status.

---

## 5. System Architecture

The app is layered: SwiftUI views at the top, stateless engines and services below them, and a single persistent store at the bottom.

![System architecture diagram](docs/diagrams/01-architecture.svg)

### What Each Layer Does

- **Views** *(blue)* — SwiftUI screens. They own UI state but delegate all logic to engines.
- **Engines** *(purple)* — pure functions / classes that take inputs and return outputs. No UI dependencies.
- **Slicers** *(green)* — pluggable through the `SlicerEngine` protocol.
- **Bambu pipeline** *(orange)* — specialized modules that together produce a real `.gcode.3mf`.
- **Persistence** *(magenta)* — `DrawerStore`, an `ObservableObject` that loads/saves to `UserDefaults`.

---

## 6. The User Journey

This is what happens when a user goes from a messy drawer to a printable file.

![Sequence diagram of the full user journey](docs/diagrams/02-user-journey.svg)

Each step gates the next: you can't pick a purpose before confirming a measurement, and you can't slice before a layout exists.

---

## 7. Codebase Tour

The project is ~14,000 lines of Swift across 32 files (v0.2.0 added 5 files for the new features). Every file has one job.

```text
Drawer/
├── DrawerApp.swift              ← App entry point (17 lines, just hosts ContentView)
├── ContentView.swift            ← Root UI: home tab, page TabView, Liquid Glass bar
├── DesignSystem.swift           ← Shared tokens: GlassCard, PressableStyle, accent colors
│
├── CaptureView.swift            ← Camera + scan UI, overlay, capture flow
├── CameraService.swift          ← AVFoundation session + ARKit LiDAR scan service
├── MeasurementEngine.swift      ← Vision rectangle detection + credit-card scaling
├── MeasurementReviewView.swift  ← Adjust the auto-detected quad and dimensions
├── ObstacleMarkingView.swift    ← Mark forbidden zones in the drawer (rails, drains, …)   [v0.2]
│
├── DrawerModels.swift           ← Core data types: measurement, layout, obstacles,
│                                  user templates, kitchen plans, saved drawer
│
├── PurposeSelectionView.swift   ← Pick a category (utensils, spices, …)
├── LayoutEngine.swift           ← Catalogs + group-aware packing algorithm
│                                  (now obstacle- and user-template-aware)
├── LayoutResultView.swift       ← Blueprint + share/save/print/AR/3D actions
├── Layout3DView.swift           ← Standalone 3D viewer with explode for tier stacks   [v0.2]
├── SavedDrawersView.swift       ← Persisted-drawers list + Kitchen Plans entry
├── KitchenPlanView.swift        ← Multi-drawer kitchen project list + detail view   [v0.2]
├── EditOrganizersSheet.swift    ← Add/remove organizers, custom dimensions, tier stacking
│
├── PrintModels.swift            ← Print-pipeline types: filament, printer, settings,
│                                  modules (with tier, lip, split-part metadata)
├── PrintModelGenerator.swift    ← Layout → printable modules + meshes
│                                  (auto-split + tier-2 locating-lip generation)
├── Print3DPreview.swift         ← SceneKit viewer (drag-rotate, auto-spin, AMS colors)
├── PrintPrepView.swift          ← Print prep UI: AMS slots, materials, cost calculator,
│                                  slice & export, color picker, print tracker
├── PrintActivity.swift          ← Live Activity + in-app PrintTrackerView   [v0.2]
├── ARDrawerPreviewView.swift    ← ARKit pass-through preview at real scale   [v0.2]
│
├── SlicerEngine.swift           ← Slicer protocol + DiagnosticSlicerEngine fallback
├── ThreeMFExporter.swift        ← Generic .3mf for non-Bambu printers (incl. ZipWriter)
│
├── BambuA1SlicerEngine.swift    ← Native A1 slicer: orchestrates layers → gcode → package
├── TrayLayerPlanner.swift       ← Per-layer rectangular toolpaths + zigzag bottom infill
├── AMSLiteColorPlanner.swift    ← Slot assignment + per-layer filament-list ranges
├── BambuA1GcodeEmitter.swift    ← Renders HEADER_BLOCK / CONFIG_BLOCK / EXECUTABLE_BLOCK
├── BambuGcode3MFPackager.swift  ← Assembles the 16-file Bambu OPC ZIP
├── BambuPackageMetadata.swift   ← XML/JSON payloads (3dmodel.model, plate_1.json, etc.)
├── BambuReferenceAssets.swift   ← Bambu A1 identifiers + filament catalog (PLA/PETG/…)
└── BambuThumbnailRenderer.swift ← PNG thumbnails Bambu Studio shows in the file picker
```

---

## 8. Subsystem Deep-Dives

### 8.1 The Measurement Pipeline

#### What it does, in plain English

Drawer needs to know how big your drawer is, in inches. There are two ways:

1. **LiDAR** — modern iPhones (Pro models since the 12 Pro) have a real depth sensor. Drawer projects four "rays" through the corners of the on-screen rectangle, reads the depth at each, converts those depths to 3D world points, and measures the distances between them.
2. **Camera + credit card** — devices without LiDAR can't measure depth, so the user places a credit card flat in the drawer. The card is exactly **3.370″ × 2.125″** (ISO/IEC 7810 ID-1, the international standard). Drawer detects both rectangles, divides the card's pixel size by its real size to get a "pixels per inch" ratio, and applies that to the drawer rectangle.

Both paths can be overridden manually on the review screen.

#### Path selection

![Measurement path-selection flowchart](docs/diagrams/03-measurement-path.svg)

#### LiDAR state machine

`LiDARScanService.ScanState`:

```text
.initializing  →  .searching  →  .tracking  →  .stable  ─┐
                                                          ├→ user can capture
                                       .failed(reason)  ──┘
```

The shutter is **only** enabled when `scanState == .stable`. To reach `.stable`:
- ARKit tracking quality > 0.6
- Scene-depth confidence > 0.65 at all four corners
- ≥ 6 measurements collected, with width/depth standard deviation small enough
- Detected rectangle quad is geometrically valid (positive area, all four corners visible)

The history buffer holds 12 samples; once stable, the final measurement is the **average of the most recent stable samples**. This kills jitter from hand shake.

#### Frameworks involved

| Framework | What it's used for |
|---|---|
| **ARKit** | `ARWorldTrackingConfiguration` with `.sceneDepth` semantics; `ARFrame.smoothedSceneDepth` for the depth map; `ARPlaneAnchor` for the floor plane (used by the height estimate) |
| **Vision** | `VNDetectRectanglesRequest` finds the drawer rim quad in the camera frame, throttled to 4 Hz; same request type with different parameters detects the credit card on the non-LiDAR path |
| **AVFoundation** | Photo capture + camera permission on the non-LiDAR path |
| **simd** | Camera-intrinsics matrix math for unprojecting 2D corners into 3D world space |

#### The credit-card math

```
realCardWidthInches  = 3.370   ← ISO/IEC 7810 ID-1
realCardHeightInches = 2.125

scaleLong  = refPixelLong  / 3.370
scaleShort = refPixelShort / 2.125
scale      = (scaleLong + scaleShort) / 2     ← average of both axes

drawerWidthInches = drawerPixelWidth / scale
drawerDepthInches = drawerPixelHeight / scale
```

The `MeasurementEngine` enforces sanity bounds (3″–60″ width, 3″–40″ depth) and falls back to a default 15″ × 20″ × 4″ measurement on failure, surfacing an error banner so the user knows to type values in.

---

### 8.2 The Layout Engine (the heart of the app)

This is where the app earns its keep. Every other subsystem feeds in or out of `LayoutEngine`.

#### What it does, in plain English

You have a drawer. You have a list of organizer modules to fit in it. The layout engine has to figure out **where to put each one** so that:

1. They actually fit (basic geometry).
2. **Items that semantically belong together end up touching, in a layout that looks like how a real organizer would arrange them.** Forks, spoons, and knives become a tight row of slots — *not* fork in one corner, knives in another.

A naive bin-packer optimizes only for area. Drawer optimizes for *organization sense*.

#### Step 1: The catalog

Each `DrawerPurpose` has a hand-curated list of `OrganizerTemplate`s. Every template has six fields:

| Field | Purpose |
|---|---|
| `id` | Stable identifier (e.g. `utensils.fork`) |
| `name` | Human label (e.g. "Fork Section") |
| `width`, `height` | Physical size in inches (height = depth in the drawer) |
| `hue` | Visual tint on the blueprint (cosmetic) |
| `priority` | Used to mark "recommended" defaults (`priority >= 5`) |
| **`group`** | **Semantic category — items in the same group are placed adjacent** |
| **`groupOrder`** | **Reading order within the group (1 = leftmost / topmost)** |

For example, the **Utensils** catalog has these groups:

```text
main_tray   →  large_tray (groupOrder 1)
eating      →  fork (1) → spoon (2) → knife (3)
cooking     →  spatula (1) → peeler (2) → small_tools (3)
specialty   →  chopstick (1)
```

A canonical group order is defined per purpose:

```swift
case .utensils:
    return ["main_tray", "eating", "cooking", "specialty"]
```

That ordering is what makes the drawer "read" left-to-right, top-to-bottom in a way humans expect.

#### Step 2: Placement units (the key idea)

Instead of packing one template at a time, the engine builds a **placement unit** for each group — a single rectangle that contains all the group's items in pre-arranged relative positions. The unit is then placed on the drawer floor as one cohesive block.

For a group, the engine generates **six candidate arrangements**:

![Placement-unit candidate generation](docs/diagrams/04-placement-units.svg)

Each arrangement uses a **0.1″ intra-group padding** (vs. 0.25″ between groups). That tight inner gap is what makes a fork section look *part of the same tray* instead of three separate parts.

#### Step 3: The score function

Compactness alone isn't enough. The most-compact arrangement for cutlery (3″×10″ each) is actually a vertical column at 3″ × 30.2″ (90.6 sq in) — but real cutlery trays use rows. So we score with two preferences:

```text
score = totalW × totalH × factor
   factor *= 0.75   if arrangement matches the preferred axis
   factor *= 1.50   if items are rotated from their natural orientation
```

The **preferred axis** is computed from the median item shape:
- Tall-narrow items (cutlery slots, narrow holders) → prefer **row** so each item points back-to-front.
- Wide-short items (spice rows, pen trays) → prefer **column** so they stack like real spice racks.

#### Step 4: The packer

Once each group has a winning unit, the packer treats them just like a regular shelf packer treats single items:

![Packer 3-strategy decision flow](docs/diagrams/05-packer-strategies.svg)

Each shelf is tagged with a `primaryGroup` — the group of the first unit dropped on it. This is what enforces "groups don't share shelves with other groups when there's room."

#### Concrete example: Utensils in a 14″ × 22″ drawer

Recommended preset places `[large_tray, fork, spoon, knife, …]`. Drawer dimensions: usable area 13.5″ × 21.5″ after the 0.25″ outer padding.

![Concrete layout example: utensils in 14 by 22 drawer](docs/diagrams/06-concrete-example.svg)

Result: large_tray on shelf 1, the eating group as a tight stacked column on shelf 2 — fork directly above spoon directly above knife, separated only by 0.1″ gaps. Cutlery stays together; you'd never get fork in one row and knife in another. In a wider drawer where Row(false) fits, the same algorithm produces the canonical side-by-side cutlery arrangement instead.

#### Real arrangements at typical drawer sizes

| Group | Items | Drawer | Best Arrangement | Block Size |
|---|---|---|---|---|
| **Eating** | fork, spoon, knife | 14″ × 22″ | Row, original | 9.2″ × 10″ — *real cutlery row* |
| **Eating** (shallow) | fork, spoon, knife | 14″ × 14″ | Column, rotated | 10″ × 9.2″ — *stacked rotated cutlery* |
| **Spice rows** | row1, row2 | 16″ × 12″ | Column, original | 12″ × 6.1″ — *stacked spice rack* |
| **Writing** | pen, sticky, index | 12″ × 18″ | Wrap, original | 9.1″ × 7.1″ — *pen on top, sticky + index below* |
| **Fasteners** | clip, stapler | 12″ × 18″ | Row, original | 9.1″ × 3″ — *side-by-side* |

#### Manual additions stay smart

`LayoutEngine.adding(_:to:)` checks whether a same-group peer is already in the drawer:

- **Peer present** → full re-pack (so the new fork lands next to existing knife).
- **No peer** → cheap `previewAdding` slot-finder, which is *also* group-aware (prefers a fresh shelf rather than slotting into a different group's zone).

#### Regenerate gives variety without breaking groups

`regenerateLayout` shuffles the *group order* but never the items inside a group. So:
- Sometimes the cutlery zone is above the cooking zone, sometimes below
- But fork/spoon/knife are *always* a tight row

#### Obstacles → keep-out zones *(v0.2)*

Every shelf-placement decision passes through `collidesWithObstacles(_:x:y:w:h:)`, which checks the placement rectangle against the `DrawerMeasurement.obstacles` list (with a 0.15″ safety pad). All four placement strategies — same-group, new shelf, cross-group, individual fallback — honor the keep-out zones, so you can mark a dishwasher screw or a raised plastic foot in `ObstacleMarkingView` and the engine will route around it.

#### Custom user templates *(v0.2)*

`UserDefinedTemplate` instances live in `DrawerStore.userTemplates`. The layout engine pulls them into the catalog via `LayoutEngine.makeTemplate(from:)` and treats them as members of a `user_custom` group, so they cluster together visually and don't disrupt the curated catalogs.

---

### 8.3 3D Mesh Generation

#### What it does, in plain English

Once the layout is set, every organizer item becomes a hollow box (an open-top tray) in 3D. The mesh-generator `PrintModelGenerator` walks the layout and produces a triangle mesh for each module, plus combined meshes for export.

A tray module is six surfaces:

```text
                   ┌────────────────┐  ← open top (no triangles)
                   │                │
                   │  (cavity)      │
        outer wall │                │ outer wall
                   │                │
                   │     ┌────┐     │
                   │     │  ▒ │←── inner cavity floor
                   │     ├────┤     │
                   │  ▒  │ ▒  │  ▒  │
                   │     │    │     │
                   └─────┴────┴─────┘
                         ↑
                   bottom solid band (~1.2 mm thick)
```

The generator emits:
1. The **outer box surface** without a top
2. The **inverted inner cavity surface** without a top (normals pointing inward)
3. A **flat top rim** connecting the outer top edge to the inner top edge
4. (Implicit closed bottom from the bottom band)

#### Module geometry

![3D mesh generation pipeline](docs/diagrams/07-mesh-generation.svg)

A `PrintableModule` is fully parametric:

```swift
struct PrintableModule {
    var outerWidthMm, outerDepthMm, heightMm
    var originXMm, originYMm        // position in the drawer
    var wallThicknessMm             // 1.6 mm default
    var bottomThicknessMm           // 1.2 mm default
    var cornerRadiusMm              // 2.0 mm
    var tintHex                     // color from layout
    var tier: Int                   // 1 = base, 2 = stacked on top
    var zOffsetMm                   // vertical offset (tier-2 sits at baseHeight)
    var splitPartIndex, splitPartCount     // for auto-split modules
    var originalModuleId            // groups split / stacked pieces
    var isLocatingLip               // tier-2 anti-slide protrusion
}
```

It also carries methods like `fitsBed(_ printer)` (bed-size check) and `gramsForFilament(_:infillPercent:)` (filament estimate using wall surface area + bottom area + cavity infill).

#### Auto-split for oversize *(v0.2)*

If a module's footprint exceeds the printer bed and `settings.autoSplitOversized` is enabled, `PrintModelGenerator.splitOversized(_:printer:)` bisects the module along its longest axis into 2+ pieces sized to fit. Each piece is labeled `"Foo (1/2)"`, `"Foo (2/2)"`, etc., and carries its `splitPartIndex` / `splitPartCount` / `originalModuleId` so the export reports them as parts of the same original tray. The split runs recursively if a single bisection isn't enough.

#### Tier-2 locating lip *(v0.2)*

A tier-2 module that just sits flat on tier-1's rim would slide around. Drawer ships a real mechanical interlock: when generating modules for a tier-2 layout item, `PrintModelGenerator.makeTier2Lip(...)` emits a *second* `PrintableModule` directly underneath:

- **Footprint inset** by 2.6 mm per side from the parent's outer (clears tier-1's 1.6 mm wall + 1 mm slip-fit clearance)
- **Depth** of 6 mm — long enough to locate, short enough to leave the bottom 28 mm of tier-1's cavity usable for storage
- **Same XY position** as the tier-2 body, so during printing the two parts fuse into one continuous plastic piece

The lip is marked `isLocatingLip = true` so user-facing module counts (estimate summary, export-result count, 3D preview badge) skip it — it's a print-mechanism detail, not a separate object the user thinks about.

---

### 8.4 The Bambu A1 Slicer

This is the most ambitious subsystem in the app. It produces a real `.gcode.3mf` for the **Bambu Lab A1** that opens directly in Bambu Studio with a live print preview, calibration block, AMS lite tool changes, and an end-of-print ramp.

#### Why a custom slicer?

Real general-purpose slicers (PrusaSlicer, CuraEngine) are massive C++ codebases — embedding one in an iOS app means a separate native target, build system work, licensing review, and serious binary size. So Drawer ships **a specialized slicer** that only knows how to slice axis-aligned hollow rectangular trays — exactly the geometry the layout engine produces. Within that domain, every step is correct: real perimeter loops, real zigzag bottom infill, real per-layer filament-list ranges, real Bambu OPC package.

`SlicerProvider.engine(for:)` routes both **Bambu Lab A1** and **Bambu Lab A1 mini** to the native engine; every other printer profile (Bambu P1S / X1C / H2D, generic 220 mm) falls back to `DiagnosticSlicerEngine` (estimates only) + `ThreeMFExporter` (generic 3MF you can drop into any other slicer).

#### The pipeline

![Bambu A1 slicer pipeline](docs/diagrams/08-slicer-pipeline.svg)

#### Per-layer planning (`TrayLayerPlanner`)

For each module, for each Z step, the planner emits:

| Layer Region | Contents |
|---|---|
| **All layers** | Outer-wall perimeter loops (rect inset by `(loop + 0.5) × lineWidth`); inner-cavity perimeters (only above the bottom band) |
| **Bottom band** (z ≤ 1.2 mm) | Solid zigzag infill spanning the inner cavity, lines alternating axis per layer for cross-strength |
| **Layer 0 only** | Skirt loops around the union bounding box of all modules, 3 mm offset, 1 loop |

Every emitted path is a `ToolPath` carrying a `feature: FeatureKind` (`.outerWall`, `.innerWall`, `.bottomSurface`, `.skirt`) and a `colorSlot: Int`. The slot is what feeds the AMS lite tool-change logic later.

#### AMS lite color planning

Bambu's A1 with the AMS lite has 4 filament slots. The planner supports four **coloring policies**:

| Policy | Behavior |
|---|---|
| `monoPlate` | Whole plate prints in slot 0 |
| `perModule` | Each module rotates through `actives` (round-robin) |
| `perFeature` | Outer walls = slot 0, inner walls = slot 1, bottom = slot 2 (when available) |
| `custom` | User-driven `(module, feature) → slot` overrides |

For the G-code, the planner computes:

- **`computeLayerFilamentRanges`** — collapses contiguous layer ranges where the filament-slot set is identical, producing the `<layer_filament_lists>` Bambu Studio expects.
- **`computeFilamentUsage`** — sums extrusion volume per slot using the formula `volume = pathLength × lineWidth × layerHeight`, then converts to filament length and grams via the material density (PLA=1.24, PETG=1.27, etc. from `BambuFilamentCatalog`).

#### G-code emission (`BambuA1GcodeEmitter`)

Bambu A1 G-code has three major blocks:

```text
; HEADER_BLOCK_START   ←  filament length/weight, max Z, time prediction, density
; HEADER_BLOCK_END
; CONFIG_BLOCK_START   ←  bed temp, nozzle temp, layer height, AMS enable
; CONFIG_BLOCK_END
; EXECUTABLE_BLOCK_START
M73 P0 R<minutes>      ←  progress prediction
M201 X12000 Y12000 …   ←  acceleration limits
…calibration + heat-up + wipe-tower-free flush prep…
G1 X… Y… Z… E…         ←  every move, with relative E (M83)
…end-of-print ramp…
; EXECUTABLE_BLOCK_END
```

All extrusion is **relative** (`M83`) to avoid floating-point drift across thousands of moves. The emitter accumulates extrusion per move:

```text
E = pathLength × lineWidth × layerHeight / filamentCrossSection
filamentCrossSection = π × (1.75 / 2)²
```

The whole gcode is hashed (MD5 via `CryptoKit`) and the digest goes into `Metadata/plate_1.gcode.md5`, which Bambu Studio verifies on load.

#### The package (`BambuGcode3MFPackager`)

A `.gcode.3mf` is **a ZIP archive of 16 OPC files** in a specific order. Drawer writes them all using its own `ZipWriter` (a STORE-method ZIP, no compression, defined in `ThreeMFExporter.swift`):

```text
[Content_Types].xml                 ← MIME map
Metadata/plate_1.png                ← large thumbnail
Metadata/plate_1_small.png          ← small thumbnail
Metadata/plate_no_light_1.png       ← no-light variant
Metadata/top_1.png                  ← top-down thumbnail
Metadata/pick_1.png                 ← pick-list thumbnail
Metadata/plate_1.json               ← per-plate JSON config
3D/3dmodel.model                    ← 3MF mesh
Metadata/project_settings.config    ← printer + filament profile
Metadata/plate_1.gcode.md5          ← MD5 hash of the gcode
Metadata/plate_1.gcode              ← the actual gcode
Metadata/_rels/model_settings.config.rels
Metadata/model_settings.config
Metadata/cut_information.xml
Metadata/slice_info.config          ← layer ranges + filament usage
_rels/.rels                         ← root relationship file
```

Constants like `BambuA1Identifiers.printerModelId = "N2S"` and the per-material `trayInfoIdx` codes (`GFA00` for Bambu PLA Basic, `GFG00` for PETG HF, etc.) are reverse-engineered from real Bambu Studio exports so the file loads cleanly.

#### Filament catalog

`BambuReferenceAssets.swift` ships a per-material profile that mirrors Bambu Studio's defaults:

| Material | Nozzle °C | Bed °C | Density g/cm³ | Max Vol Speed | Bambu Profile |
|---|---|---|---|---|---|
| PLA  | 220 | 65 | 1.24 | 21 | `Bambu PLA Basic @BBL A1` |
| PETG | 250 | 70 | 1.27 | 16 | `Bambu PETG HF @BBL A1`   |
| ABS  | 250 | 90 | 1.04 | 18 | `Generic ABS @BBL A1`     |
| ASA  | 260 | 95 | 1.07 | 16 | `Generic ASA @BBL A1`     |
| TPU  | 230 | 45 | 1.21 |  8 | `Bambu TPU 95A @BBL A1`   |

These flow into both the G-code (`CONFIG_BLOCK`) and the `project_settings.config` XML.

---

### 8.5 3D Previews

Drawer ships **two** SceneKit-based 3D viewers, each tuned for a different question.

#### 8.5.a `Print3DPreview` — "what will my slicer see?"

Lives inside Print Prep. Renders modules colored by their resolved AMS lite slot so the user sees the actual physical print outcome (including auto-split parts and tier-2 locating lips at reduced opacity).

`Print3DPreview` is a SwiftUI view wrapping SceneKit (`SceneView`). On every `organizer` / `plate` / `assignment` change, it rebuilds the scene:

![3D preview scene-rebuild flow](docs/diagrams/09-preview-rebuild.svg)

The user can:
- **Drag** to rotate (`SceneView` `.allowsCameraControl` does this for free)
- **Pinch** to zoom
- **Tap "Pause"** to stop the auto-rotate animation (a `SCNAction.repeatForever(rotateBy y: 2π over 22s)`)
- **Tap "Reset"** to rebuild the scene (snaps the camera back to the iso angle)

The Pause / Reset chips themselves use `.glassEffect(.regular.interactive(), in: Capsule())` — real iOS 26 Liquid Glass that physically reacts to touch, sitting over the rendered scene.

#### 8.5.b `Layout3DView` — "show me the stack" *(v0.2)*

Lives behind the **3D View** button on the layout result screen. Purpose-built for *understanding* the layout — particularly when tier-2 organizers stack on tier-1 ones and the top-down blueprint can't show them clearly.

Killer feature: an **Explode toggle** that animates tier-2 bodies + their locating lips upward in lockstep, separating them from their tier-1 parents so you can see the interlock geometry:

- Tier-1 stays on the floor
- Tier-2 body lifts to `baseHeightMm + 60 mm`
- Tier-2 lip lifts to `baseHeightMm − 6 mm + 60 mm` (preserving the 6 mm gap between body and lip)
- A tier legend appears at the top whenever there's a tier-2 module — no clutter when not needed

The view goes through `PrintModelGenerator.makeOrganizer` so the geometry it shows is identical to what the print pipeline produces — including the auto-split pieces and locating lips.

#### Coordinate-system note (applies to both viewers)

The mesh uses `+Z up`, but SceneKit prefers `+Y up`. The conversion is baked into `makeGeometry`:

```swift
// vertex (x, y, z) ─→ SceneKit (x, z, y)
// triangle index order also flipped to keep winding consistent
```

The result: drawer floor stays flat (XZ plane), modules stand up correctly along Y, and `node.look(at:)` from the camera works without surprises.

---

### 8.6 AR Drawer Preview *(v0.2)*

#### What it does, in plain English

You hold your phone over your actual drawer. Drawer detects the floor of the drawer as a horizontal plane. You tap once and the proposed layout drops into the drawer at real scale, so you can see what each tray looks like and where it'll sit.

#### How it works

`ARDrawerPreviewView` wraps an `ARSCNView` (SceneKit + ARKit) and runs an `ARWorldTrackingConfiguration` with `.horizontal` plane detection. As tracking improves, the SwiftUI hint banner updates ("Move the phone slowly over the drawer floor" → "Floor detected — tap to drop your layout"). The first tap raycasts to the detected plane and anchors the layout there.

Once placed, the user has **four manipulation gestures**, all wired through `ARCoordinator`:

| Gesture | Effect | API |
|---|---|---|
| **Tap a module** | Highlight with cyan emission glow + slide up a glass info card with the module's name, tier, and dimensions | `ARSCNView.hitTest` + walk parent chain to find the registered `nodeToItem` mapping |
| **Pinch** | Uniformly scale the entire layout — recalibrates if ARKit's plane scale is slightly off | `UIPinchGestureRecognizer` |
| **Two-finger twist** | Rotate the entire layout around its vertical (Y) axis | `UIRotationGestureRecognizer` → `parent.eulerAngles.y -= rotation` |
| **Long-press + drag** | Lift the layout off its anchor and slide it across the plane | `UILongPressGestureRecognizer` + `view.session.raycast` per `.changed` event |

The modules use the layout item's actual color (vibrant HSV) at 0.85 opacity — solid enough to read against busy backgrounds, translucent enough to feel like an overlay on the real-world camera feed. `castsShadow = true` gives each module a contact shadow on the floor plane so they don't look like they're floating.

> **One bug worth knowing about:** `ARSCNView.scene.background.contents` controls the camera pass-through. Setting it (even to `UIColor.clear`) replaces the camera with whatever you set — leading to a black void instead of the real world behind the modules. Don't touch that property.

---

### 8.7 Kitchen Planning *(v0.2)*

#### What it does, in plain English

A kitchen has many drawers. Designing them in isolation misses the bigger picture — "where do my baking supplies go relative to where I cook?". `KitchenPlan` lets you group multiple saved drawers into a single project, label each one with a location, and treat the whole kitchen as one design.

#### Data shape

```swift
struct KitchenPlan {
    var id: UUID
    var name: String                  // "Main Kitchen", "Cabin Kitchen", …
    var date: Date
    var drawerEntries: [Entry]

    struct Entry {
        var id: UUID
        var drawerId: UUID            // SavedDrawer.id reference
        var location: String          // "Top drawer left of sink"
        var order: Int
    }
}
```

Plans live in `DrawerStore.kitchenPlans`, persisted to `UserDefaults`. Each entry references a saved drawer by id and adds a free-form location label.

#### Navigation

Plans don't need their own tab — there's a banner at the top of the **Saved** tab that shows the plan count and opens `KitchenPlansListView`. From there:

```text
KitchenPlansListView ── tap plan ──▶ KitchenPlanDetailView
                                       ├── header (drawer count + total slot count)
                                       ├── per-drawer rows (thumbnail + location)
                                       │   └── tap row ──▶ LayoutResultView
                                       └── "Add drawer to this plan"
                                              └── AddDrawerToPlanSheet
                                                     (only shows drawers
                                                      not already in plan)
```

Renaming and deleting plans live in the toolbar `ellipsis.circle` menu on the detail view.

---

### 8.8 Live Activity for Print Progress *(v0.2)*

#### What it does, in plain English

After exporting a `.gcode.3mf` and starting the actual print on your Bambu A1, tap **Track print** in the print prep view to start an in-app countdown. The tracker shows current phase ("Heating bed" → "Calibrating" → "Printing" → "Finishing"), grams of filament, time remaining, and a progress bar.

#### The architecture

```text
PrintPrepView
  ↓ user taps "Track print"
PrintProgressManager.shared.start(attributes:)
  ├── stores PrintActivityAttributes (drawer name, printer, total grams,
  │                                   total seconds)
  ├── creates ContentState (progress 0..1, remainingSeconds, statusLabel,
  │                         isComplete)
  ├── if iOS 16.1+ and Activities enabled:
  │      Activity<PrintActivityAttributes>.request(...)  ← Lock Screen
  └── starts a 1-second Timer that ticks `tick()`
                ↓
              tick() updates progress + statusLabel based on elapsed time;
              push the new ContentState to the activity (if any) and
              publish the @Published state for the SwiftUI view
                ↓
PrintTrackerView (in-app fallback) renders progress bar + stats + actions
```

#### Lock Screen / Dynamic Island

To get the Live Activity rendering on the Lock Screen and Dynamic Island, add a Widget Extension target ("DrawerWidgets") in Xcode and reference `PrintActivityAttributes` from a shared file. Step-by-step instructions live in the header comment of `Drawer/PrintActivity.swift`. Until that target exists, the in-app `PrintTrackerView` provides equivalent visual feedback.

The `Activity.request(...)` call is wrapped in `#if canImport(ActivityKit)` and gracefully no-ops if the framework isn't available or the user has Activities disabled.

---

### 8.9 Liquid Glass UI

iOS 26 introduced the **Liquid Glass** material — a dynamic, refractive, content-aware glass effect. Drawer uses the *real* APIs (not a custom approximation):

#### The bottom bar

```swift
HStack(spacing: 0) {
    barTab(icon: "house.fill", label: "Home", index: 0)
    Spacer().frame(width: 78)        // cut-out for the floating FAB
    barTab(icon: "archivebox.fill", label: "Saved", index: 1)
}
.padding(.horizontal, 8).padding(.vertical, 8)
.glassEffect(.regular, in: Capsule())     // ← real Liquid Glass

Button { onScan(); scanBounce += 1 } label: {
    Image(systemName: "camera.viewfinder")
        .symbolEffect(.bounce, value: scanBounce)
}
.glassEffect(
    .regular
        .tint(Color(hue: 0.6, saturation: 0.8, brightness: 0.9).opacity(0.6))
        .interactive(),                    // ← physically reacts to touch
    in: Circle()
)
```

`.glassEffect(_:in:)` is the iOS 26 API. `Glass.regular.interactive()` adds the touch-deformation behavior (the FAB visibly squishes when pressed). `matchedGeometryEffect` slides the selection pill between Home and Saved tabs.

#### Polish details across the app

| Polish | Where | API |
|---|---|---|
| Bouncy SF Symbols on tab switch | `LiquidGlassBottomBar` | `.symbolEffect(.bounce, value: …)` |
| Continuous breathing logo | `appHeader` | `.phaseAnimator` + `.symbolEffect(.pulse.byLayer, options: .repeat(.continuous))` |
| Press squash on every button | `DesignSystem.PressableStyle` | tighter spring on press, gentler spring on release |
| Selection haptics | tab change, FAB tap | `.sensoryFeedback(.selection / .impact, trigger: …)` |
| Success haptic on export | `PrintPrepView` | `.sensoryFeedback(.success, trigger: exportResult)` |
| Staggered entry for rows | tips, purpose grid, saved drawers | per-index `.animation(...delay: idx × 0.04)` |
| Smooth tab page swipes | `ContentView` | `.animation(.spring(response: 0.5, dampingFraction: 0.85), value: selectedTab)` |
| Spinner for regenerate | `LayoutResultView` | `.symbolEffect(.rotate, options: .speed(1.4), value: isRegenerating)` |
| Auto-rotate 3D preview | `Print3DPreview` | `SCNAction.repeatForever(rotateBy y: 2π duration: 22)` |

---

## 9. Data Model

The full type graph that flows through the app:

![Data model class diagram](docs/diagrams/10-data-model.svg)

Two distinct units live side by side in the type system:
- **Inches** are used everywhere on the layout side (`DrawerMeasurement`, `OrganizerItem`).
- **Millimeters** are used throughout the print pipeline (`PrintableModule`, `PrintSettings`).

The conversion happens exactly once, in `PrintModelGenerator.makeOrganizer`, using `PrintConstants.inchToMm = 25.4`.

---

## 10. Persistence

`DrawerStore` is an `ObservableObject` injected into the SwiftUI environment. It owns four persisted collections, each backed by its own `UserDefaults` key:

```swift
class DrawerStore: ObservableObject {
    @Published var savedDrawers: [SavedDrawer]                  // every saved drawer
    @Published var userTemplates: [UserDefinedTemplate]         // custom-dimension modules (v0.2)
    @Published var kitchenPlans: [KitchenPlan]                  // multi-drawer projects (v0.2)
    @Published var costPerKg: Double = 25.0                     // filament price (v0.2)

    func save(_ drawer: SavedDrawer)            // persistDrawers()
    func addTemplate(_ template: UserDefinedTemplate)   // persistTemplates()
    func savePlan(_ plan: KitchenPlan)          // persistPlans()
    // costPerKg uses a property observer to write directly to UserDefaults
}
```

Why `UserDefaults` and not Core Data / SwiftData?

- The dataset is small — a few KB per drawer plus an optional JPEG thumbnail. Even a heavy user with 50 drawers, 20 custom templates, and 5 kitchen plans stays well under 1 MB.
- Schema is flat — no relationships to traverse. Kitchen plans reference drawers by `UUID`, but that's a manual lookup, not a foreign-key constraint.
- `Codable` handles backward-compatibility cleanly. `DrawerMeasurement` recognizes the legacy `usedLiDAR: Bool` field from v0.0 saves and migrates it to the new `source: MeasurementSource` enum. `OrganizerItem`'s tier/`stacksOn` fields and `PrintableModule`'s `tier`/`zOffset`/`splitPart*`/`isLocatingLip` fields all default cleanly when missing, so v0.1.x saves still load on v0.2.0.

If the data ever outgrows this approach, swapping in SwiftData would only touch this one file.

---

## 11. Glossary for Non-Coders

| Term | Plain English |
|---|---|
| **SwiftUI** | Apple's modern framework for building iOS UIs by describing what the screen *should look like* given some state, instead of imperatively changing pixels. |
| **iOS 26.2** | The version of iOS this app needs. It's required because Drawer uses Liquid Glass, which is iOS 26+. |
| **Liquid Glass** | The new translucent, refractive material Apple introduced in iOS 26. The bottom tab bar uses it. It "knows" what's behind it and reacts to touch. |
| **ARKit** | Apple's framework for augmented reality and depth sensing. Drawer uses it for LiDAR scans. |
| **LiDAR** | A laser-based depth sensor in newer iPhones. Lets the phone measure how far away things are with high accuracy. |
| **Vision framework** | Apple's image-analysis framework. Drawer uses it to find rectangles (the drawer rim, the credit-card reference) in photos. |
| **SceneKit** | Apple's older 3D graphics framework. Drawer uses it for the 3D preview, the 3D layout viewer, and the AR overlay because it has free camera controls (drag/pinch). |
| **AR / ARKit** | Augmented Reality — overlaying virtual content on the live camera feed. ARKit provides world tracking and plane detection so Drawer can find the floor of your drawer and anchor the virtual layout to it. |
| **Plane detection** | ARKit's ability to find flat horizontal or vertical surfaces in the camera feed (table tops, drawer floors, walls). Drawer's AR view waits for a horizontal plane before letting you tap to place. |
| **ActivityKit** | Apple framework introduced in iOS 16.1 for Live Activities — small persistent UI elements that show on the Lock Screen and in the Dynamic Island while a long-running task is in progress. Drawer uses it to track print progress. |
| **Live Activity** | An interactive widget that survives outside the app — visible on Lock Screen and Dynamic Island. Requires a Widget Extension target to render the actual UI. |
| **Mesh** | A 3D shape made of triangles. Each tray module is a mesh. |
| **Locating lip** | The small downward protrusion on the bottom of a tier-2 organizer that drops into the tier-1 cavity to keep the stack from sliding. Generated automatically and printed as a separate-but-fused piece. |
| **Auto-split** | When a tray's footprint is bigger than the printer bed, Drawer bisects it into two or more snap-together pieces with a labelled "(1/2)" / "(2/2)" suffix. |
| **G-code** | The language 3D printers speak. Every printer move (`G1 X100 Y50 E0.5`) is a line of G-code. |
| **3MF** | The modern, ZIP-based file format that holds a 3D model + slicing settings + thumbnails, all in one file. Bambu Studio's `.gcode.3mf` is a 3MF with extra parts. |
| **Slicer** | Software that takes a 3D model and converts it into G-code by computing layer-by-layer toolpaths. |
| **AMS Lite** | Bambu's filament-feeding system on the A1 with up to 4 spools, allowing multi-color prints. |
| **Toolpath** | A sequence of points the printer's nozzle should follow, plus how much filament to extrude along the way. |
| **Infill** | The pattern of plastic used inside a part to give it strength without filling it solid. The trays here only have infill in the bottom band. |
| **Skirt** | A loose loop of plastic printed around the part(s) on layer 0 to prime the nozzle. |
| **Bin packing** | The classic computer-science problem of fitting rectangles into a bigger rectangle. Drawer's layout engine is a specialized variant that also respects keep-out zones (obstacles) and groups items by semantic category. |
| **`@Published` / `ObservableObject`** | SwiftUI's pattern for state that views automatically re-render when it changes. `DrawerStore` is an example. |
| **`UserDefaults`** | A built-in iOS key/value store, originally for app preferences. Small data lives here. |

---

## 12. Build & Run

### Requirements

- **Xcode 26 or newer** (ships with the iOS 26.2 SDK)
- **iOS 26.2+ device or simulator** (Liquid Glass APIs require it)
- A device with **LiDAR** (iPhone 12 Pro or later) for the best measurement experience — the app gracefully falls back to camera-only on devices without it

### Build

```bash
cd "Drawer"
xcodebuild \
  -project Drawer.xcodeproj \
  -scheme Drawer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Or just open `Drawer.xcodeproj` in Xcode and hit **Cmd+R**.

### Project Structure

The project uses Xcode's **synchronized file groups** (`PBXFileSystemSynchronizedRootGroup`) — every `.swift` file under the `Drawer/` folder is automatically part of the build target. Drop a new file in and it compiles, no `.pbxproj` edit needed.

### Tests

Unit tests live in `DrawerTests/`. UI tests live in `DrawerUITests/`. Both run with **Cmd+U**.

---

## 13. License

This project is released under the **MIT License** — see [`LICENSE`](LICENSE) for the full text.

> ⚠️ **Heads-up:** the Bambu Studio reference assets in `BambuReferenceAssets.swift` (filament identifiers like `GFA00`, the printer model id `N2S`, the G-code header format) are derived from inspecting Bambu's own exported files. The MIT license covers *this* code, not those underlying conventions — if you ship this commercially, audit those constants against Bambu's terms.

---

<div align="center">

*Built with SwiftUI, ARKit, Vision, SceneKit, and a lot of bin-packing math.*

</div>
