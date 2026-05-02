//
//  LayoutEngine.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI

// MARK: - Organizer Catalog

struct OrganizerTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let width: Double   // inches
    let height: Double  // inches (depth in the drawer)
    let hue: Double
    let priority: Int   // higher = recommended/important
    /// Semantic group — items in the same group are placed adjacent so the
    /// drawer reads logically (e.g. forks/knives/spoons all together).
    let group: String
    /// Position within the group; lower numbers are placed first.
    let groupOrder: Int
    /// Engine-internal generic gap-filler. Hidden from the user-facing catalog;
    /// only the layout engine's fill pass instantiates these. Fillers are
    /// allowed to be placed multiple times in the same drawer.
    var isFiller: Bool = false
    /// If non-nil, the template can scale uniformly within this multiplier
    /// range to fill remaining shelf space. Stretching only happens during
    /// initial generate / fill pass — never during user-driven `adding(...)`.
    var stretchable: ClosedRange<Double>? = nil

    /// Whether this template is selected by default in the recommended preset.
    var isRecommended: Bool { priority >= 5 }
}

// MARK: - Layout Engine

class LayoutEngine {

    // MARK: - Organizer Catalogs by Purpose

    static func templates(for purpose: DrawerPurpose) -> [OrganizerTemplate] {
        switch purpose {
        case .utensils:
            // Groups, in placement order:
            //   main_tray  → the centerpiece tray (placed first if used)
            //   eating     → fork, spoon, knife (classic cutlery row, adjacent)
            //   cooking    → spatula, peeler, small tools
            //   specialty  → chopsticks (rare; tucked at the end)
            return [
                OrganizerTemplate(id: "utensils.large_tray", name: "Large Utensil Tray",
                                  width: 6.0, height: 12.0, hue: 0.08, priority: 10,
                                  group: "main_tray", groupOrder: 1,
                                  stretchable: 1.0...1.35),
                OrganizerTemplate(id: "utensils.fork", name: "Fork Section",
                                  width: 3.0, height: 10.0, hue: 0.10, priority: 8,
                                  group: "eating", groupOrder: 1),
                OrganizerTemplate(id: "utensils.spoon", name: "Spoon Section",
                                  width: 3.0, height: 10.0, hue: 0.12, priority: 8,
                                  group: "eating", groupOrder: 2),
                OrganizerTemplate(id: "utensils.knife", name: "Knife Section",
                                  width: 3.0, height: 10.0, hue: 0.06, priority: 8,
                                  group: "eating", groupOrder: 3),
                OrganizerTemplate(id: "utensils.spatula", name: "Spatula Holder",
                                  width: 4.0, height: 12.0, hue: 0.15, priority: 6,
                                  group: "cooking", groupOrder: 1),
                OrganizerTemplate(id: "utensils.peeler", name: "Peeler Slot",
                                  width: 2.0, height: 6.0, hue: 0.18, priority: 2,
                                  group: "cooking", groupOrder: 2),
                OrganizerTemplate(id: "utensils.small_tools", name: "Small Tools Tray",
                                  width: 4.0, height: 6.0, hue: 0.20, priority: 5,
                                  group: "cooking", groupOrder: 3),
                OrganizerTemplate(id: "utensils.chopstick", name: "Chopstick Slot",
                                  width: 2.0, height: 10.0, hue: 0.25, priority: 3,
                                  group: "specialty", groupOrder: 1),
            ]

        case .junkDrawer:
            // Groups, in placement order:
            //   daily_use   → things you grab every day (pen, scissors, tape)
            //   power       → batteries + cables together
            //   small_parts → keys, coins, rubber bands
            //   catchall    → misc bin (always at the end so the user can sweep
            //                 stragglers in without disturbing organization)
            return [
                OrganizerTemplate(id: "junk.pen", name: "Pen & Marker Cup",
                                  width: 3.0, height: 6.0, hue: 0.52, priority: 6,
                                  group: "daily_use", groupOrder: 1),
                OrganizerTemplate(id: "junk.scissors", name: "Scissors Slot",
                                  width: 3.0, height: 8.0, hue: 0.50, priority: 7,
                                  group: "daily_use", groupOrder: 2),
                OrganizerTemplate(id: "junk.tape_glue", name: "Tape & Glue Bin",
                                  width: 5.0, height: 4.0, hue: 0.58, priority: 8,
                                  group: "daily_use", groupOrder: 3),
                OrganizerTemplate(id: "junk.battery", name: "Battery Box",
                                  width: 4.0, height: 4.0, hue: 0.55, priority: 9,
                                  group: "power", groupOrder: 1),
                OrganizerTemplate(id: "junk.cable", name: "Cable Organizer",
                                  width: 4.0, height: 5.0, hue: 0.60, priority: 5,
                                  group: "power", groupOrder: 2),
                OrganizerTemplate(id: "junk.key", name: "Key Tray",
                                  width: 3.0, height: 3.0, hue: 0.45, priority: 7,
                                  group: "small_parts", groupOrder: 1),
                OrganizerTemplate(id: "junk.coin", name: "Coin Dish",
                                  width: 3.0, height: 3.0, hue: 0.48, priority: 3,
                                  group: "small_parts", groupOrder: 2),
                OrganizerTemplate(id: "junk.rubber", name: "Rubber Band Box",
                                  width: 2.5, height: 2.5, hue: 0.53, priority: 2,
                                  group: "small_parts", groupOrder: 3),
                OrganizerTemplate(id: "junk.misc", name: "Misc Catch-All",
                                  width: 5.0, height: 5.0, hue: 0.65, priority: 4,
                                  group: "catchall", groupOrder: 1,
                                  stretchable: 1.0...1.6),
            ]

        case .spices:
            // Groups:
            //   jar_rows    → main spice jar rows (front of drawer)
            //   tall_items  → bottles + grinders (taller; grouped together)
            //   accessories → packets and measuring tools
            return [
                OrganizerTemplate(id: "spices.row1", name: "Spice Jar Row",
                                  width: 12.0, height: 3.0, hue: 0.35, priority: 10,
                                  group: "jar_rows", groupOrder: 1),
                OrganizerTemplate(id: "spices.row2", name: "Spice Jar Row",
                                  width: 12.0, height: 3.0, hue: 0.38, priority: 9,
                                  group: "jar_rows", groupOrder: 2),
                OrganizerTemplate(id: "spices.bottle", name: "Tall Bottle Slot",
                                  width: 4.0, height: 4.0, hue: 0.30, priority: 8,
                                  group: "tall_items", groupOrder: 1),
                OrganizerTemplate(id: "spices.grinder", name: "Grinder Section",
                                  width: 4.0, height: 4.0, hue: 0.42, priority: 4,
                                  group: "tall_items", groupOrder: 2),
                OrganizerTemplate(id: "spices.packet", name: "Packet Basket",
                                  width: 6.0, height: 4.0, hue: 0.40, priority: 7,
                                  group: "accessories", groupOrder: 1,
                                  stretchable: 1.0...1.3),
                OrganizerTemplate(id: "spices.measuring", name: "Measuring Spoons",
                                  width: 3.0, height: 5.0, hue: 0.32, priority: 5,
                                  group: "accessories", groupOrder: 2),
            ]

        case .bakingTools:
            // Groups:
            //   measuring   → measuring cups + thermometer (precision tools)
            //   mixing      → whisks + spatulas (used in tandem)
            //   decorating  → cookie cutters + piping tips (finishing touches)
            //   dough       → rolling pin (the long tool, lives on its own)
            return [
                OrganizerTemplate(id: "baking.measuring", name: "Measuring Cups",
                                  width: 5.0, height: 6.0, hue: 0.92, priority: 9,
                                  group: "measuring", groupOrder: 1),
                OrganizerTemplate(id: "baking.thermometer", name: "Thermometer Slot",
                                  width: 2.0, height: 8.0, hue: 0.96, priority: 4,
                                  group: "measuring", groupOrder: 2),
                OrganizerTemplate(id: "baking.whisk", name: "Whisk Holder",
                                  width: 3.0, height: 10.0, hue: 0.98, priority: 8,
                                  group: "mixing", groupOrder: 1),
                OrganizerTemplate(id: "baking.spatula", name: "Spatula Section",
                                  width: 3.0, height: 10.0, hue: 0.93, priority: 5,
                                  group: "mixing", groupOrder: 2),
                OrganizerTemplate(id: "baking.cookie", name: "Cookie Cutters",
                                  width: 5.0, height: 5.0, hue: 0.90, priority: 7,
                                  group: "decorating", groupOrder: 1),
                OrganizerTemplate(id: "baking.piping", name: "Piping Tips Box",
                                  width: 4.0, height: 4.0, hue: 0.88, priority: 6,
                                  group: "decorating", groupOrder: 2),
                OrganizerTemplate(id: "baking.rolling_pin", name: "Rolling Pin Slot",
                                  width: 4.0, height: 16.0, hue: 0.95, priority: 10,
                                  group: "dough", groupOrder: 1),
            ]

        case .officeSupplies:
            // Groups:
            //   writing     → pens + sticky notes + index cards (everything you
            //                 reach for to jot something down)
            //   fasteners   → paper clips + stapler (paper attachment)
            //   tools       → tape, eraser, USB cables (utilities)
            return [
                OrganizerTemplate(id: "office.pen", name: "Pen Tray",
                                  width: 8.0, height: 3.0, hue: 0.60, priority: 10,
                                  group: "writing", groupOrder: 1),
                OrganizerTemplate(id: "office.sticky", name: "Sticky Note Slot",
                                  width: 4.0, height: 4.0, hue: 0.62, priority: 9,
                                  group: "writing", groupOrder: 2),
                OrganizerTemplate(id: "office.index", name: "Index Card Slot",
                                  width: 5.0, height: 4.0, hue: 0.70, priority: 3,
                                  group: "writing", groupOrder: 3),
                OrganizerTemplate(id: "office.clip", name: "Paper Clip Box",
                                  width: 3.0, height: 3.0, hue: 0.58, priority: 8,
                                  group: "fasteners", groupOrder: 1),
                OrganizerTemplate(id: "office.stapler", name: "Stapler Space",
                                  width: 6.0, height: 3.0, hue: 0.55, priority: 7,
                                  group: "fasteners", groupOrder: 2),
                OrganizerTemplate(id: "office.tape", name: "Tape Dispenser",
                                  width: 4.0, height: 3.0, hue: 0.52, priority: 4,
                                  group: "tools", groupOrder: 1),
                OrganizerTemplate(id: "office.eraser", name: "Eraser & Tip Box",
                                  width: 3.0, height: 3.0, hue: 0.68, priority: 5,
                                  group: "tools", groupOrder: 2),
                OrganizerTemplate(id: "office.usb", name: "USB/Cable Tray",
                                  width: 4.0, height: 5.0, hue: 0.65, priority: 6,
                                  group: "tools", groupOrder: 3,
                                  stretchable: 1.0...1.4),
            ]

        case .linens:
            // Groups:
            //   kitchen_cloth → towels + napkins (kitchen-side cloth)
            //   table_setting → placemats, coasters, napkin rings
            return [
                OrganizerTemplate(id: "linens.towel", name: "Towel Roll Section",
                                  width: 6.0, height: 12.0, hue: 0.75, priority: 10,
                                  group: "kitchen_cloth", groupOrder: 1),
                OrganizerTemplate(id: "linens.napkin", name: "Napkin Stack",
                                  width: 6.0, height: 6.0, hue: 0.78, priority: 9,
                                  group: "kitchen_cloth", groupOrder: 2),
                OrganizerTemplate(id: "linens.placemat", name: "Placemat Fold",
                                  width: 12.0, height: 6.0, hue: 0.72, priority: 8,
                                  group: "table_setting", groupOrder: 1),
                OrganizerTemplate(id: "linens.coaster", name: "Coaster Stack",
                                  width: 4.0, height: 4.0, hue: 0.80, priority: 7,
                                  group: "table_setting", groupOrder: 2),
                OrganizerTemplate(id: "linens.ring", name: "Napkin Ring Tray",
                                  width: 5.0, height: 3.0, hue: 0.77, priority: 5,
                                  group: "table_setting", groupOrder: 3),
            ]

        case .custom:
            // Custom doesn't have a semantic story — group bins by size so
            // similar bins still cluster together visually.
            return [
                OrganizerTemplate(id: "custom.large", name: "Large Bin",
                                  width: 6.0, height: 8.0, hue: 0.45, priority: 10,
                                  group: "large_bins", groupOrder: 1,
                                  stretchable: 1.0...1.4),
                OrganizerTemplate(id: "custom.wide", name: "Wide Tray",
                                  width: 8.0, height: 3.0, hue: 0.42, priority: 7,
                                  group: "large_bins", groupOrder: 2,
                                  stretchable: 1.0...1.3),
                OrganizerTemplate(id: "custom.medium", name: "Medium Bin",
                                  width: 5.0, height: 5.0, hue: 0.50, priority: 8,
                                  group: "medium_bins", groupOrder: 1,
                                  stretchable: 1.0...1.4),
                OrganizerTemplate(id: "custom.narrow", name: "Narrow Slot",
                                  width: 2.0, height: 8.0, hue: 0.60, priority: 5,
                                  group: "medium_bins", groupOrder: 2),
                OrganizerTemplate(id: "custom.small", name: "Small Bin",
                                  width: 3.0, height: 4.0, hue: 0.55, priority: 6,
                                  group: "small_bins", groupOrder: 1,
                                  stretchable: 1.0...1.3),
                OrganizerTemplate(id: "custom.tiny", name: "Tiny Tray",
                                  width: 3.0, height: 3.0, hue: 0.65, priority: 4,
                                  group: "small_bins", groupOrder: 2),
            ]
        }
    }

    /// Universal generic-shape fillers used by the fill pass to claim leftover
    /// drawer space. These are engine-internal — they never appear in the
    /// user-facing catalog (`templates(for:)`) and aren't tracked in
    /// `selectedTemplateIds`, so the same id may be placed multiple times in
    /// one drawer (each copy gets its own runtime UUID via `OrganizerItem`).
    /// All are stretchable so they can grow to claim a residual gap, and all
    /// belong to the `filler` group so they don't disturb canonical ordering.
    /// Hue is overridden at placement time to blend with neighboring items.
    static func fillerTemplates() -> [OrganizerTemplate] {
        [
            OrganizerTemplate(id: "filler.2x2", name: "Mini Bin",
                              width: 2.0, height: 2.0, hue: 0.55, priority: 1,
                              group: "filler", groupOrder: 1,
                              isFiller: true, stretchable: 1.0...1.5),
            OrganizerTemplate(id: "filler.3x3", name: "Small Compartment",
                              width: 3.0, height: 3.0, hue: 0.55, priority: 1,
                              group: "filler", groupOrder: 2,
                              isFiller: true, stretchable: 1.0...1.6),
            OrganizerTemplate(id: "filler.2x4", name: "Narrow Slot",
                              width: 2.0, height: 4.0, hue: 0.55, priority: 1,
                              group: "filler", groupOrder: 3,
                              isFiller: true, stretchable: 1.0...1.6),
            OrganizerTemplate(id: "filler.4x4", name: "Compact Bin",
                              width: 4.0, height: 4.0, hue: 0.55, priority: 1,
                              group: "filler", groupOrder: 4,
                              isFiller: true, stretchable: 1.0...1.5),
            OrganizerTemplate(id: "filler.3x6", name: "Long Slot",
                              width: 3.0, height: 6.0, hue: 0.55, priority: 1,
                              group: "filler", groupOrder: 5,
                              isFiller: true, stretchable: 1.0...1.4),
            OrganizerTemplate(id: "filler.5x5", name: "Square Bin",
                              width: 5.0, height: 5.0, hue: 0.55, priority: 1,
                              group: "filler", groupOrder: 6,
                              isFiller: true, stretchable: 1.0...1.3),
        ]
    }

    /// Per-purpose canonical group ordering. Used when sorting templates for
    /// placement so the resulting layout reads in a consistent left-to-right,
    /// top-to-bottom narrative (e.g. cutlery → cooking tools → specialty).
    static func groupOrder(for purpose: DrawerPurpose) -> [String] {
        switch purpose {
        case .utensils:
            return ["main_tray", "eating", "cooking", "specialty"]
        case .junkDrawer:
            return ["daily_use", "power", "small_parts", "catchall"]
        case .spices:
            return ["jar_rows", "tall_items", "accessories"]
        case .bakingTools:
            return ["measuring", "mixing", "decorating", "dough"]
        case .officeSupplies:
            return ["writing", "fasteners", "tools"]
        case .linens:
            return ["kitchen_cloth", "table_setting"]
        case .custom:
            return ["large_bins", "medium_bins", "small_bins"]
        }
    }

    /// Sort key for placement order: groups follow the canonical order, then
    /// `groupOrder` within a group, then higher `priority` wins ties.
    private static func placementSorted(_ templates: [OrganizerTemplate],
                                         purpose: DrawerPurpose) -> [OrganizerTemplate] {
        let order = groupOrder(for: purpose)
        let indexOf: (String) -> Int = { name in
            order.firstIndex(of: name) ?? Int.max
        }
        return templates.sorted { a, b in
            let ai = indexOf(a.group), bi = indexOf(b.group)
            if ai != bi { return ai < bi }
            if a.groupOrder != b.groupOrder { return a.groupOrder < b.groupOrder }
            return a.priority > b.priority
        }
    }

    /// Default selection for a purpose, adapted to drawer size. Larger drawers
    /// get more pre-selected items so the engine has a richer pool to pack from.
    /// User-defined templates are folded in so a custom 4×4 the user once added
    /// shows up by default in any new drawer.
    ///
    /// Buckets (drawer area in sq inches):
    /// - `< 180`: top-3 priority only (small drawer; don't overstuff)
    /// - `180–280`: priority ≥ 5 (legacy default)
    /// - `280–450`: priority ≥ 3 (medium-large; the 14×22 case)
    /// - `> 450`: full catalog + user templates
    static func recommendedIds(for purpose: DrawerPurpose,
                                drawerArea: Double,
                                userTemplates: [UserDefinedTemplate] = []) -> Set<String> {
        let catalog = templates(for: purpose)
        var ids: Set<String>
        switch drawerArea {
        case ..<180:
            let top = catalog.sorted { $0.priority > $1.priority }.prefix(3)
            ids = Set(top.map { $0.id })
        case ..<280:
            ids = Set(catalog.filter { $0.priority >= 5 }.map { $0.id })
        case ..<450:
            ids = Set(catalog.filter { $0.priority >= 3 }.map { $0.id })
        default:
            ids = Set(catalog.map { $0.id })
            // For very large drawers, include user templates by default too.
            for u in userTemplates {
                ids.insert("user.\(u.id.uuidString)")
            }
        }
        return ids
    }

    /// Zero-area shim for callers that don't yet pass drawer dimensions.
    /// Falls back to a 14×22 baseline (308 sq in) so behavior matches the
    /// historical P≥3 bucket for an "average" drawer.
    static func recommendedIds(for purpose: DrawerPurpose) -> Set<String> {
        recommendedIds(for: purpose, drawerArea: 308)
    }

    /// Minimal selection: top 3 by priority.
    static func minimalIds(for purpose: DrawerPurpose) -> Set<String> {
        let sorted = templates(for: purpose).sorted { $0.priority > $1.priority }
        return Set(sorted.prefix(3).map { $0.id })
    }

    // MARK: - Layout Generation

    static func generateLayout(measurement: DrawerMeasurement,
                                purpose: DrawerPurpose,
                                shuffled: Bool = false,
                                selectedIds: Set<String>? = nil,
                                userTemplates: [UserDefinedTemplate] = []) -> DrawerLayout {
        let drawerW = measurement.widthInches
        let drawerD = measurement.depthInches

        let allTemplates = templates(for: purpose) + userTemplates.map(makeTemplate(from:))
        let activeTemplates: [OrganizerTemplate] = {
            guard let ids = selectedIds else { return allTemplates }
            // If empty selection, treat as recommended fallback so we still
            // produce a useful result instead of an empty drawer.
            if ids.isEmpty {
                return allTemplates.filter { $0.isRecommended }
            }
            return allTemplates.filter { ids.contains($0.id) }
        }()

        // Sanity-check tiny / invalid dimensions.
        if drawerW < 3 || drawerD < 3 {
            return DrawerLayout(
                measurement: measurement,
                purpose: purpose,
                items: [],
                coveragePercentage: 0,
                unplacedTemplates: activeTemplates.map { $0.name },
                warnings: ["Drawer is too small to fit any organizer (\(measurement.formattedWidth) × \(measurement.formattedDepth)). Verify the measurement."]
            )
        }

        // Group-aware ordering: placement is groups (per canonical order) →
        // groupOrder within a group → priority as tiebreaker. When regenerating
        // we shuffle the *group* order, never the items inside a group, so
        // cutlery / paired items stay together.
        var catalog: [OrganizerTemplate]
        if shuffled {
            let canonical = groupOrder(for: purpose)
            let grouped = Dictionary(grouping: activeTemplates) { $0.group }
            // Shuffle, then partition: known groups (in shuffled order) first,
            // then unknown groups. `filter` is stable so the shuffle survives.
            var keys = Array(grouped.keys)
            keys.shuffle()
            let known = keys.filter { canonical.contains($0) }
            let unknown = keys.filter { !canonical.contains($0) }
            keys = known + unknown
            catalog = keys.flatMap { key in
                (grouped[key] ?? []).sorted { $0.groupOrder < $1.groupOrder }
            }
        } else {
            catalog = placementSorted(activeTemplates, purpose: purpose)
        }

        let result = packShelf(drawerW: drawerW, drawerD: drawerD,
                                catalog: catalog, purpose: purpose,
                                obstacles: measurement.obstacles)

        var warnings: [String] = []
        if result.placed.isEmpty {
            warnings.append("None of the organizers fit this drawer at the given size.")
        }
        if !measurement.obstacles.isEmpty {
            let lostNames = result.unplaced.filter { name in
                // Items unplaced specifically because of obstacle collisions.
                catalog.first { $0.name == name } != nil
            }
            if !lostNames.isEmpty {
                warnings.append("\(measurement.obstacles.count) obstacle(s) blocked some placements. Consider scanning a clear drawer area or removing the obstacles in the review screen.")
            }
        }

        // Context-aware fill pass: claim residual empty space with stretchable
        // fillers and any user-wanted templates that didn't fit in the main
        // pack. Mutates `placed` and `selectedTemplateIds` in place.
        var placed = result.placed
        var selectedTemplateIds = activeTemplates.map { $0.id }
        _ = fillRemaining(into: &placed,
                           selectedTemplateIds: &selectedTemplateIds,
                           drawerW: drawerW, drawerD: drawerD,
                           purpose: purpose,
                           activeTemplates: activeTemplates,
                           userTemplates: userTemplates,
                           obstacles: measurement.obstacles)

        let totalArea = drawerW * drawerD
        let usedArea = placed.reduce(0.0) { $0 + ($1.width * $1.height) }
        let coverage = totalArea > 0 ? (usedArea / totalArea) * 100.0 : 0

        return DrawerLayout(
            measurement: measurement,
            purpose: purpose,
            items: placed,
            coveragePercentage: min(coverage, 100.0),
            unplacedTemplates: result.unplaced,
            warnings: warnings,
            selectedTemplateIds: selectedTemplateIds
        )
    }

    /// Backwards-compatible alias.
    static func regenerateLayout(measurement: DrawerMeasurement,
                                  purpose: DrawerPurpose,
                                  selectedIds: Set<String>? = nil,
                                  userTemplates: [UserDefinedTemplate] = []) -> DrawerLayout {
        generateLayout(measurement: measurement,
                       purpose: purpose,
                       shuffled: true,
                       selectedIds: selectedIds,
                       userTemplates: userTemplates)
    }

    /// Convert a user-defined template into the engine's canonical template
    /// type so it flows through the same placement pipeline. User-custom
    /// items live in their own `user_custom` group so they cluster together
    /// at the end of the layout (after the curated catalogs).
    static func makeTemplate(from u: UserDefinedTemplate) -> OrganizerTemplate {
        OrganizerTemplate(
            id: "user.\(u.id.uuidString)",
            name: u.name,
            width: u.widthInches,
            height: u.heightInches,
            hue: u.hue,
            priority: 5,
            group: "user_custom",
            groupOrder: max(0, Int(u.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1_000_000)))
        )
    }

    // MARK: - Fit-aware editing

    enum FitResult: Equatable {
        case fits                    // can be placed in current layout
        case fitsAfterRegenerate     // wouldn't fit alongside current items but could fit alone
        case doesNotFit(reason: String)

        var canAdd: Bool {
            switch self {
            case .fits, .fitsAfterRegenerate: return true
            case .doesNotFit: return false
            }
        }
    }

    /// Whether a template can be added to the existing layout.
    static func canAdd(_ template: OrganizerTemplate,
                        to layout: DrawerLayout) -> FitResult {
        let drawerW = layout.measurement.widthInches
        let drawerD = layout.measurement.depthInches
        let padding = 0.25

        // Smallest dimension test — if both orientations exceed drawer extents,
        // it can never fit.
        let smallestDim = min(template.width, template.height)
        let largestDim = max(template.width, template.height)
        if largestDim > max(drawerW, drawerD) - 2 * padding {
            let need = largestDim - (max(drawerW, drawerD) - 2 * padding)
            return .doesNotFit(reason: String(format: "Too large by %.1f\" — won't fit in any orientation.", need))
        }
        if smallestDim > min(drawerW, drawerD) - 2 * padding {
            return .doesNotFit(reason: "Too wide for the drawer in either orientation.")
        }

        // Try inserting it without changing existing items.
        if previewAdding(template, to: layout) != nil {
            return .fits
        }

        // Try regenerating from scratch with all current templates + this one.
        // If the full set still fits, the user just needs to regenerate.
        let combinedIds = Set(layout.selectedTemplateIds + [template.id])
        let regenerated = generateLayout(
            measurement: layout.measurement,
            purpose: layout.purpose,
            selectedIds: combinedIds
        )
        if regenerated.unplacedTemplates.isEmpty || !regenerated.unplacedTemplates.contains(template.name) {
            // The regenerated layout placed this template — call that out.
            return .fitsAfterRegenerate
        }

        return .doesNotFit(reason: "Not enough free space for this organizer.")
    }

    /// Try placing a template into the existing shelf layout without disturbing
    /// other items. Returns the new layout if it fits; `nil` otherwise.
    ///
    /// Group-aware: prefers (1) same-group shelves, then (2) opening a fresh
    /// shelf for this group, and only then (3) any cross-group shelf with
    /// room. That way adding a chopstick to a drawer of forks/spoons lands
    /// in its own zone instead of slotting in between cutlery.
    static func previewAdding(_ template: OrganizerTemplate,
                               to layout: DrawerLayout) -> DrawerLayout? {
        let drawerW = layout.measurement.widthInches
        let drawerD = layout.measurement.depthInches
        let padding = shelfPadding
        let obstacles = layout.measurement.obstacles

        var shelves = reconstructShelves(items: layout.items,
                                          padding: padding,
                                          purpose: layout.purpose)
        var placed = layout.items

        let orientations: [(w: Double, h: Double)] = [
            (template.width, template.height),
            (template.height, template.width)
        ]

        let commit: (Double, Double, Double, Double) -> DrawerLayout = { x, y, w, h in
            let item = OrganizerItem(
                name: template.name,
                x: x, y: y,
                width: w, height: h,
                hue: template.hue,
                saturation: 0.55,
                brightness: 0.9
            )
            placed.append(item)
            return rebuildLayout(layout: layout,
                                 items: placed,
                                 addingTemplateId: template.id)
        }

        // Strategy 1: same-group existing shelf.
        for orient in orientations {
            let (w, h) = (orient.w, orient.h)
            if w > drawerW - 2 * padding || h > drawerD - 2 * padding { continue }
            for i in 0..<shelves.count where shelves[i].primaryGroup == template.group {
                let shelf = shelves[i]
                let availW = drawerW - shelf.xCursor - padding
                if w <= availW + 0.01 && h <= shelf.height + 0.01
                    && !collidesWithObstacles(obstacles,
                                                x: shelf.xCursor, y: shelf.y,
                                                w: w, h: h) {
                    shelves[i].xCursor += w + padding
                    return commit(shelf.xCursor, shelf.y, w, h)
                }
            }
        }

        // Strategy 2: open a fresh shelf for this template's group.
        for orient in orientations {
            let (w, h) = (orient.w, orient.h)
            if w > drawerW - 2 * padding { continue }
            let nextY = shelves.last.map { $0.y + $0.height + padding } ?? padding
            if nextY + h <= drawerD - padding
                && !collidesWithObstacles(obstacles, x: padding, y: nextY, w: w, h: h) {
                return commit(padding, nextY, w, h)
            }
        }

        // Strategy 3: cross-group fallback — better than rejecting the add.
        for orient in orientations {
            let (w, h) = (orient.w, orient.h)
            if w > drawerW - 2 * padding || h > drawerD - 2 * padding { continue }
            for i in 0..<shelves.count {
                let shelf = shelves[i]
                let availW = drawerW - shelf.xCursor - padding
                if w <= availW + 0.01 && h <= shelf.height + 0.01
                    && !collidesWithObstacles(obstacles,
                                                x: shelf.xCursor, y: shelf.y,
                                                w: w, h: h) {
                    shelves[i].xCursor += w + padding
                    return commit(shelf.xCursor, shelf.y, w, h)
                }
            }
        }

        return nil
    }

    /// Add a template; returns updated layout, or `nil` if it cannot fit even
    /// with regeneration.
    ///
    /// If the layout already contains another item from the same semantic
    /// group (e.g. adding a Spoon Section when a Fork Section is placed),
    /// we regenerate the whole layout so the new item lands adjacent to its
    /// group peers. Cross-group additions use the cheaper preview-insert
    /// path so existing items don't shift unnecessarily.
    static func adding(_ template: OrganizerTemplate,
                        to layout: DrawerLayout) -> DrawerLayout? {
        let purposeTemplates = templates(for: layout.purpose)
        let placedNames = Set(layout.items.map { $0.name })
        // A "peer" is a different template in the same group whose name is
        // already in the drawer. Names like "Spice Jar Row" can repeat, but
        // that still means the group is present.
        let hasGroupPeer = purposeTemplates.contains { other in
            other.id != template.id
                && other.group == template.group
                && placedNames.contains(other.name)
        }

        if hasGroupPeer {
            let combinedIds = Set(layout.selectedTemplateIds + [template.id])
            let regenerated = generateLayout(
                measurement: layout.measurement,
                purpose: layout.purpose,
                selectedIds: combinedIds
            )
            if regenerated.items.contains(where: { $0.name == template.name }) {
                return regenerated
            }
            // Fall through to preview if regen somehow couldn't place it.
        }

        if let preview = previewAdding(template, to: layout) {
            return preview
        }
        let combinedIds = Set(layout.selectedTemplateIds + [template.id])
        let regenerated = generateLayout(
            measurement: layout.measurement,
            purpose: layout.purpose,
            selectedIds: combinedIds
        )
        if regenerated.items.contains(where: { $0.name == template.name }) {
            return regenerated
        }
        return nil
    }

    /// Remove an item by id. Repacks the remaining items so they reflow
    /// cleanly into the drawer instead of leaving a gap. Drops the item's
    /// template id from the selection.
    static func removingItem(_ id: OrganizerItem.ID,
                              from layout: DrawerLayout) -> DrawerLayout {
        guard let removed = layout.items.first(where: { $0.id == id }) else {
            return layout
        }
        // Find the template id matching the removed item's name in the
        // current selection. Names can repeat (e.g. spice rows) so only drop
        // the first matching id.
        let purposeTemplates = templates(for: layout.purpose)
        var newIds = layout.selectedTemplateIds
        if let match = purposeTemplates.first(where: { $0.name == removed.name && newIds.contains($0.id) }),
           let idx = newIds.firstIndex(of: match.id) {
            newIds.remove(at: idx)
        }

        return generateLayout(
            measurement: layout.measurement,
            purpose: layout.purpose,
            selectedIds: Set(newIds)
        )
    }

    /// Lightweight summary for the editor — area used vs free, count of items.
    struct FitSummary {
        let usedAreaSqInches: Double
        let totalAreaSqInches: Double
        let freeAreaSqInches: Double
        let coverage: Double // 0..1
        let placedCount: Int
    }

    static func fitSummary(for layout: DrawerLayout) -> FitSummary {
        let total = layout.totalDrawerArea
        let used = layout.usedArea
        return FitSummary(
            usedAreaSqInches: used,
            totalAreaSqInches: total,
            freeAreaSqInches: max(0, total - used),
            coverage: total > 0 ? min(1, used / total) : 0,
            placedCount: layout.items.count
        )
    }

    // MARK: Shelf reconstruction helpers

    /// Rebuild shelf records from the existing items in a layout. Each shelf
    /// is tagged with the group of its first (left-most) item, so callers
    /// can preserve group purity when slotting in new items.
    private static func reconstructShelves(items: [OrganizerItem],
                                            padding: Double,
                                            purpose: DrawerPurpose) -> [PackShelf] {
        // Build a name → group lookup from the catalog. Names like
        // "Spice Jar Row" can repeat, but they map to the same group.
        let catalog = templates(for: purpose)
        var groupByName: [String: String] = [:]
        for t in catalog { groupByName[t.name] = t.group }

        var shelves: [PackShelf] = []
        // Sort by y, then by x — so the *first* item we see on a shelf is
        // its left-most one, which gives us the shelf's primary group.
        let ordered = items.sorted {
            if abs($0.y - $1.y) < 0.5 { return $0.x < $1.x }
            return $0.y < $1.y
        }
        for item in ordered {
            let group = groupByName[item.name] ?? "_unknown"
            if let idx = shelves.firstIndex(where: { abs($0.y - item.y) < 0.5 }) {
                let g = shelves[idx]
                shelves[idx] = PackShelf(
                    y: g.y,
                    height: max(g.height, item.height),
                    xCursor: max(g.xCursor, item.x + item.width + padding),
                    primaryGroup: g.primaryGroup
                )
            } else {
                shelves.append(PackShelf(
                    y: item.y,
                    height: item.height,
                    xCursor: item.x + item.width + padding,
                    primaryGroup: group
                ))
            }
        }
        return shelves
    }

    private static func rebuildLayout(layout: DrawerLayout,
                                       items: [OrganizerItem],
                                       addingTemplateId: String) -> DrawerLayout {
        let total = layout.measurement.widthInches * layout.measurement.depthInches
        let used = items.reduce(0.0) { $0 + ($1.width * $1.height) }
        let coverage = total > 0 ? min(100.0, (used / total) * 100.0) : 0

        var newSelected = layout.selectedTemplateIds
        if !newSelected.contains(addingTemplateId) {
            newSelected.append(addingTemplateId)
        }

        return DrawerLayout(
            measurement: layout.measurement,
            purpose: layout.purpose,
            items: items,
            coveragePercentage: coverage,
            unplacedTemplates: layout.unplacedTemplates,
            warnings: layout.warnings,
            selectedTemplateIds: newSelected
        )
    }

    // MARK: - Shelf Packing

    private struct PackResult {
        let placed: [OrganizerItem]
        let unplaced: [String]
    }

    /// Mutable shelf record used during packing. Each shelf is tagged with
    /// the "primary group" — the group of the first unit placed onto it —
    /// so subsequent items/units prefer landing on a shelf that matches
    /// their group, keeping semantic clusters physically together.
    private struct PackShelf {
        var y: Double
        var height: Double
        var xCursor: Double
        var primaryGroup: String
    }

    /// A composed placement of one or more templates that should be placed
    /// together as a single rectangle on the drawer floor. Groups with
    /// multiple items become block units (e.g. fork|spoon|knife in a tight
    /// row); single-item groups become trivial units. Each `InternalItem`
    /// is positioned relative to the unit's local origin (0,0).
    private struct PlacementUnit {
        enum Arrangement { case single, row, column, wrap }

        let group: String
        let arrangement: Arrangement
        let rotated: Bool
        let internalItems: [InternalItem]
        let totalW: Double
        let totalH: Double

        struct InternalItem {
            let template: OrganizerTemplate
            let dx: Double
            let dy: Double
            let w: Double
            let h: Double
        }
    }

    /// Outer gap between shelves, between distinct units on a shelf, and
    /// to drawer walls — slip-fit clearance only. After PrintModelGenerator's
    /// per-side `tolerance` shrink (default 0.5 mm), printed modules end up
    /// ~2 mm apart and ~1.5 mm from drawer walls. Tight tessellation makes
    /// the layout self-locking: every module is pinned by its neighbors and
    /// the drawer walls, with no empty space to slide into.
    private static let shelfPadding: Double = 0.04
    /// Inner gap between items in the same group block. Same value as
    /// `shelfPadding` so the visual spacing reads uniformly across the
    /// whole drawer — the layout looks like one tessellated grid rather
    /// than nested clusters with different gap widths.
    private static let intraGroupPadding: Double = 0.04

    // MARK: - Group block builders

    /// Produce candidate `PlacementUnit`s for a group's templates, ordered by
    /// preference. The ranking is shape-aware: items that are taller than
    /// they are wide (cutlery sections, narrow slots) prefer to line up in a
    /// row so each item keeps its long axis pointing toward the back of the
    /// drawer. Items wider than they are tall (spice rows, pen trays) prefer
    /// to stack in a column. Both preferences match how physical drawer
    /// organizers are conventionally laid out.
    private static func candidateUnits(for templates: [OrganizerTemplate],
                                        maxW: Double,
                                        maxH: Double) -> [PlacementUnit] {
        guard let first = templates.first else { return [] }
        let group = first.group
        let sorted = templates.sorted { $0.groupOrder < $1.groupOrder }

        // Single-item group: just emit both orientations.
        if sorted.count == 1 {
            let t = sorted[0]
            var out: [PlacementUnit] = []
            if t.width <= maxW + 0.01 && t.height <= maxH + 0.01 {
                out.append(PlacementUnit(
                    group: group, arrangement: .single, rotated: false,
                    internalItems: [.init(template: t, dx: 0, dy: 0,
                                          w: t.width, h: t.height)],
                    totalW: t.width, totalH: t.height
                ))
            }
            if t.height <= maxW + 0.01 && t.width <= maxH + 0.01 {
                out.append(PlacementUnit(
                    group: group, arrangement: .single, rotated: true,
                    internalItems: [.init(template: t, dx: 0, dy: 0,
                                          w: t.height, h: t.width)],
                    totalW: t.height, totalH: t.width
                ))
            }
            return out
        }

        // Multi-item group: enumerate row / column / wrap, both rotations.
        var candidates: [PlacementUnit] = []
        for rotated in [false, true] {
            if let row = arrangeRow(sorted, group: group, rotated: rotated,
                                     maxW: maxW, maxH: maxH) {
                candidates.append(row)
            }
            if let col = arrangeColumn(sorted, group: group, rotated: rotated,
                                        maxW: maxW, maxH: maxH) {
                candidates.append(col)
            }
            if let wrap = arrangeWrap(sorted, group: group, rotated: rotated,
                                       maxW: maxW, maxH: maxH) {
                candidates.append(wrap)
            }
        }

        // Pick the natural arrangement based on the dominant item shape:
        // tall-narrow items (cutlery slots) want to line up in a row so each
        // item keeps its long axis pointing back; wide-short items (spice
        // rows, pen trays) want to stack in a column. We pick by median to
        // be robust against one odd-shaped item in the group.
        let medianW = sorted.map { $0.width }.sorted()[sorted.count / 2]
        let medianH = sorted.map { $0.height }.sorted()[sorted.count / 2]
        let itemsAreTall = medianH > medianW
        let preferred: PlacementUnit.Arrangement = itemsAreTall ? .row : .column

        // Score each candidate as `area * factor`:
        //  - 25% discount when arrangement matches the preferred axis
        //    (rows for tall items, columns for wide items)
        //  - 50% penalty when items are rotated away from their natural
        //    orientation (template author's intended look)
        // The discounts/penalties are calibrated so a clearly more compact
        // arrangement still wins (e.g. wrapping a writing zone into a 9×7
        // grid beats an 8×11 column even though column is "preferred"),
        // while rotated arrangements only win when nothing else fits.
        func score(_ u: PlacementUnit) -> Double {
            var factor = 1.0
            if u.arrangement == preferred { factor *= 0.75 }
            if u.rotated { factor *= 1.5 }
            return u.totalW * u.totalH * factor
        }
        return candidates.sorted { a, b in
            let sa = score(a), sb = score(b)
            if abs(sa - sb) > 0.01 { return sa < sb }
            // Tiebreak: closer-to-square is visually more balanced.
            let aAspect = max(a.totalW, a.totalH) / max(0.01, min(a.totalW, a.totalH))
            let bAspect = max(b.totalW, b.totalH) / max(0.01, min(b.totalW, b.totalH))
            return aAspect < bAspect
        }
    }

    /// All items side-by-side along X, in groupOrder. Heights line up vertically
    /// — the row's height is the tallest item's height.
    private static func arrangeRow(_ sorted: [OrganizerTemplate],
                                    group: String,
                                    rotated: Bool,
                                    maxW: Double,
                                    maxH: Double) -> PlacementUnit? {
        let p = intraGroupPadding
        var x: Double = 0
        var maxItemH: Double = 0
        var items: [PlacementUnit.InternalItem] = []
        for (i, t) in sorted.enumerated() {
            let (w, h) = rotated ? (t.height, t.width) : (t.width, t.height)
            if i > 0 { x += p }
            items.append(.init(template: t, dx: x, dy: 0, w: w, h: h))
            x += w
            maxItemH = max(maxItemH, h)
        }
        let unit = PlacementUnit(group: group, arrangement: .row, rotated: rotated,
                                  internalItems: items,
                                  totalW: x, totalH: maxItemH)
        return (unit.totalW <= maxW + 0.01 && unit.totalH <= maxH + 0.01) ? unit : nil
    }

    /// All items stacked top-to-bottom along Y, in groupOrder.
    private static func arrangeColumn(_ sorted: [OrganizerTemplate],
                                       group: String,
                                       rotated: Bool,
                                       maxW: Double,
                                       maxH: Double) -> PlacementUnit? {
        let p = intraGroupPadding
        var y: Double = 0
        var maxItemW: Double = 0
        var items: [PlacementUnit.InternalItem] = []
        for (i, t) in sorted.enumerated() {
            let (w, h) = rotated ? (t.height, t.width) : (t.width, t.height)
            if i > 0 { y += p }
            items.append(.init(template: t, dx: 0, dy: y, w: w, h: h))
            y += h
            maxItemW = max(maxItemW, w)
        }
        let unit = PlacementUnit(group: group, arrangement: .column, rotated: rotated,
                                  internalItems: items,
                                  totalW: maxItemW, totalH: y)
        return (unit.totalW <= maxW + 0.01 && unit.totalH <= maxH + 0.01) ? unit : nil
    }

    /// Greedy left-to-right wrap. When the next item would exceed `maxW`,
    /// start a new row directly below. Keeps groupOrder reading order intact.
    private static func arrangeWrap(_ sorted: [OrganizerTemplate],
                                     group: String,
                                     rotated: Bool,
                                     maxW: Double,
                                     maxH: Double) -> PlacementUnit? {
        let p = intraGroupPadding
        var x: Double = 0
        var rowY: Double = 0
        var rowH: Double = 0
        var items: [PlacementUnit.InternalItem] = []
        var totalW: Double = 0

        for t in sorted {
            let (w, h) = rotated ? (t.height, t.width) : (t.width, t.height)
            // Quick reject: the item itself can't fit width-wise even on a fresh row.
            if w > maxW + 0.01 { return nil }

            let needsX = (x == 0) ? w : (x + p + w)
            if needsX > maxW + 0.01 && x > 0 {
                rowY += rowH + p
                x = 0
                rowH = 0
            }
            if x > 0 { x += p }
            items.append(.init(template: t, dx: x, dy: rowY, w: w, h: h))
            x += w
            rowH = max(rowH, h)
            totalW = max(totalW, x)
            if rowY + rowH > maxH + 0.01 { return nil }
        }

        // Cull arrangements that didn't actually use multiple rows — those
        // duplicate the single-row arrangement.
        let rowsUsed = items.contains { $0.dy > 0.01 }
        guard rowsUsed else { return nil }

        let unit = PlacementUnit(group: group, arrangement: .wrap, rotated: rotated,
                                  internalItems: items,
                                  totalW: totalW, totalH: rowY + rowH)
        return (unit.totalW <= maxW + 0.01 && unit.totalH <= maxH + 0.01) ? unit : nil
    }

    // MARK: - Packing

    private static func packShelf(drawerW: Double,
                                   drawerD: Double,
                                   catalog: [OrganizerTemplate],
                                   purpose: DrawerPurpose,
                                   obstacles: [DrawerObstacle] = []) -> PackResult {
        let pad = shelfPadding
        let usableW = drawerW - 2 * pad
        let usableH = drawerD - 2 * pad

        var placedItems: [OrganizerItem] = []
        var shelves: [PackShelf] = []
        var unplaced: [String] = []

        // Preserve the input ordering of groups (the caller already sorted
        // catalog by canonical/shuffled group order, then by groupOrder).
        var groupKeys: [String] = []
        var grouped: [String: [OrganizerTemplate]] = [:]
        for t in catalog {
            if grouped[t.group] == nil { groupKeys.append(t.group) }
            grouped[t.group, default: []].append(t)
        }

        for key in groupKeys {
            let templates = grouped[key] ?? []
            if templates.isEmpty { continue }

            // 1) Try to place the entire group as a cohesive block.
            let units = candidateUnits(for: templates,
                                        maxW: usableW,
                                        maxH: usableH)

            var didPlace = false

            for unit in units where !didPlace {
                // Strategy A: same-group existing shelf (rare for groups,
                // but possible if part of a group was placed earlier via
                // fallback or the user is iterating).
                for i in 0..<shelves.count
                    where shelves[i].primaryGroup == unit.group {
                    if tryCommitUnit(unit, onShelf: i, shelves: &shelves,
                                      drawerW: drawerW,
                                      pad: pad,
                                      obstacles: obstacles,
                                      placedItems: &placedItems) {
                        didPlace = true
                        break
                    }
                }
                if didPlace { break }

                // Strategy B: open a fresh shelf for this group.
                let nextY = shelves.last.map { $0.y + $0.height + pad } ?? pad
                if nextY + unit.totalH <= drawerD - pad + 0.01
                    && unit.totalW <= usableW + 0.01
                    && !unitCollidesWithObstacles(unit, atX: pad, y: nextY,
                                                   obstacles: obstacles) {
                    commitUnit(unit, atX: pad, y: nextY,
                               into: &placedItems)
                    shelves.append(PackShelf(
                        y: nextY,
                        height: unit.totalH,
                        xCursor: pad + unit.totalW + pad,
                        primaryGroup: unit.group
                    ))
                    didPlace = true
                    break
                }

                // Strategy C: any existing shelf (cross-group).
                for i in 0..<shelves.count {
                    if tryCommitUnit(unit, onShelf: i, shelves: &shelves,
                                      drawerW: drawerW,
                                      pad: pad,
                                      obstacles: obstacles,
                                      placedItems: &placedItems) {
                        didPlace = true
                        break
                    }
                }
            }

            if didPlace { continue }

            // 2) No unit form fit — fall back to placing each template
            // individually, still preferring same-group shelves so any items
            // we *can* place stay clustered.
            for template in templates {
                if !placeIndividualTemplate(template,
                                             drawerW: drawerW,
                                             drawerD: drawerD,
                                             pad: pad,
                                             obstacles: obstacles,
                                             shelves: &shelves,
                                             placedItems: &placedItems) {
                    unplaced.append(template.name)
                }
            }
        }

        _ = purpose
        return PackResult(placed: placedItems, unplaced: unplaced)
    }

    /// Returns true if any obstacle overlaps the rectangle (x, y, w, h).
    /// Used by the packer to skip placements that would land on a raised
    /// area / rail / drain hole / dishwasher screw inside the drawer.
    private static func collidesWithObstacles(_ obstacles: [DrawerObstacle],
                                                x: Double, y: Double,
                                                w: Double, h: Double) -> Bool {
        guard !obstacles.isEmpty else { return false }
        for o in obstacles {
            if o.overlaps(x: x, y: y, width: w, height: h) {
                return true
            }
        }
        return false
    }

    /// Returns true if any of a unit's internal items would overlap an
    /// obstacle when placed at (baseX, baseY).
    private static func unitCollidesWithObstacles(_ unit: PlacementUnit,
                                                    atX baseX: Double,
                                                    y baseY: Double,
                                                    obstacles: [DrawerObstacle]) -> Bool {
        guard !obstacles.isEmpty else { return false }
        for item in unit.internalItems {
            if collidesWithObstacles(obstacles,
                                      x: baseX + item.dx,
                                      y: baseY + item.dy,
                                      w: item.w, h: item.h) {
                return true
            }
        }
        return false
    }

    /// Try to place a `PlacementUnit` onto an existing shelf. Returns true on
    /// success and mutates the shelf cursor / placed items in place.
    private static func tryCommitUnit(_ unit: PlacementUnit,
                                       onShelf i: Int,
                                       shelves: inout [PackShelf],
                                       drawerW: Double,
                                       pad: Double,
                                       obstacles: [DrawerObstacle] = [],
                                       placedItems: inout [OrganizerItem]) -> Bool {
        let shelf = shelves[i]
        let availW = drawerW - shelf.xCursor - pad
        if unit.totalW <= availW + 0.01 && unit.totalH <= shelf.height + 0.01
            && !unitCollidesWithObstacles(unit, atX: shelf.xCursor, y: shelf.y,
                                           obstacles: obstacles) {
            commitUnit(unit, atX: shelf.xCursor, y: shelf.y, into: &placedItems)
            shelves[i].xCursor += unit.totalW + pad
            return true
        }
        return false
    }

    /// Append every internal item of a unit to the placed-items array,
    /// translating each item's relative position into absolute drawer
    /// coordinates.
    private static func commitUnit(_ unit: PlacementUnit,
                                    atX baseX: Double, y baseY: Double,
                                    into placed: inout [OrganizerItem]) {
        for item in unit.internalItems {
            let org = OrganizerItem(
                name: item.template.name,
                x: baseX + item.dx,
                y: baseY + item.dy,
                width: item.w,
                height: item.h,
                hue: item.template.hue,
                saturation: 0.55,
                brightness: 0.9
            )
            placed.append(org)
        }
    }

    /// Per-item fallback placement when the whole-group block didn't fit.
    /// Same 3-strategy preference as the unit placer (same-group shelf →
    /// new shelf → cross-group shelf). Skips placements that overlap any
    /// drawer obstacle.
    private static func placeIndividualTemplate(
        _ template: OrganizerTemplate,
        drawerW: Double,
        drawerD: Double,
        pad: Double,
        obstacles: [DrawerObstacle] = [],
        shelves: inout [PackShelf],
        placedItems: inout [OrganizerItem]
    ) -> Bool {
        let orientations: [(Double, Double)] = [
            (template.width, template.height),
            (template.height, template.width)
        ]

        let commit: (Double, Double, Double, Double) -> OrganizerItem = { x, y, w, h in
            OrganizerItem(
                name: template.name, x: x, y: y, width: w, height: h,
                hue: template.hue, saturation: 0.55, brightness: 0.9
            )
        }

        // Same-group shelf.
        for (w, h) in orientations {
            if w > drawerW - 2 * pad || h > drawerD - 2 * pad { continue }
            for i in 0..<shelves.count where shelves[i].primaryGroup == template.group {
                let shelf = shelves[i]
                let availW = drawerW - shelf.xCursor - pad
                if w <= availW + 0.01 && h <= shelf.height + 0.01
                    && !collidesWithObstacles(obstacles,
                                                x: shelf.xCursor, y: shelf.y,
                                                w: w, h: h) {
                    placedItems.append(commit(shelf.xCursor, shelf.y, w, h))
                    shelves[i].xCursor += w + pad
                    return true
                }
            }
        }

        // New shelf.
        for (w, h) in orientations {
            if w > drawerW - 2 * pad { continue }
            let nextY = shelves.last.map { $0.y + $0.height + pad } ?? pad
            if nextY + h <= drawerD - pad + 0.01
                && !collidesWithObstacles(obstacles, x: pad, y: nextY, w: w, h: h) {
                placedItems.append(commit(pad, nextY, w, h))
                shelves.append(PackShelf(
                    y: nextY, height: h,
                    xCursor: pad + w + pad,
                    primaryGroup: template.group
                ))
                return true
            }
        }

        // Cross-group shelf.
        for (w, h) in orientations {
            if w > drawerW - 2 * pad || h > drawerD - 2 * pad { continue }
            for i in 0..<shelves.count {
                let shelf = shelves[i]
                let availW = drawerW - shelf.xCursor - pad
                if w <= availW + 0.01 && h <= shelf.height + 0.01
                    && !collidesWithObstacles(obstacles,
                                                x: shelf.xCursor, y: shelf.y,
                                                w: w, h: h) {
                    placedItems.append(commit(shelf.xCursor, shelf.y, w, h))
                    shelves[i].xCursor += w + pad
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Fill Pass
    //
    // After the main shelf packer commits the user-selected templates, large
    // chunks of the drawer often remain empty. The fill pass scans for those
    // empty rectangles and drops in (a) low-priority items the user already
    // wanted but didn't fit, and (b) generic stretchable fillers — colored to
    // match neighboring items so the drawer reads as one coherent design.
    //
    // Pure post-process: doesn't touch existing placed items, doesn't rerun
    // shelf packing, just claims residual area.

    /// Empty rectangle inside the drawer interior. Coordinates are in inches
    /// from the drawer's top-left corner (same convention as `OrganizerItem`).
    fileprivate struct FreeRect {
        var x: Double
        var y: Double
        var w: Double
        var h: Double
        var area: Double { w * h }
    }

    /// Snapshot of the placed items immediately neighboring a free rect, used
    /// to bias the fill-pass scoring toward contextually appropriate
    /// candidates and to source a tinted color for fillers.
    fileprivate struct PlacementContext {
        let neighborGroups: [String]
        let dominantGroup: String?
        /// Color of the dominant neighbor — used to tint fillers so they look
        /// like part of the same zone instead of a generic gray bin.
        let dominantHue: Double?
    }

    /// Compute empty rectangles inside the drawer interior, given the items
    /// currently placed and any obstacles. Uses a Y-event sweep: sort all
    /// distinct top/bottom edges, then for each horizontal strip between two
    /// consecutive edges, find the X-spans not covered by any active occupant.
    /// Strips below `minDimension` in either axis are dropped.
    ///
    /// Tier-2 modules overlap their parent's footprint and contribute no extra
    /// area, so they're filtered out of the occupant set.
    fileprivate static func freeRectangles(drawerW: Double,
                                            drawerD: Double,
                                            placed: [OrganizerItem],
                                            obstacles: [DrawerObstacle],
                                            minDimension: Double = 1.5) -> [FreeRect] {
        let pad = shelfPadding
        let usableX0 = pad
        let usableY0 = pad
        let usableX1 = drawerW - pad
        let usableY1 = drawerD - pad
        if usableX1 - usableX0 < minDimension || usableY1 - usableY0 < minDimension {
            return []
        }

        struct Box { let x0, y0, x1, y1: Double }
        var occupants: [Box] = []
        for item in placed where item.tier == 1 {
            occupants.append(Box(x0: item.x, y0: item.y,
                                 x1: item.x + item.width,
                                 y1: item.y + item.height))
        }
        for o in obstacles {
            let r = o.rect
            occupants.append(Box(x0: r.minX, y0: r.minY, x1: r.maxX, y1: r.maxY))
        }

        // Distinct Y-events inside the usable region.
        var yEvents: Set<Double> = [usableY0, usableY1]
        for o in occupants {
            if o.y0 > usableY0 + 0.001 && o.y0 < usableY1 - 0.001 { yEvents.insert(o.y0) }
            if o.y1 > usableY0 + 0.001 && o.y1 < usableY1 - 0.001 { yEvents.insert(o.y1) }
        }
        let sortedY = yEvents.sorted()

        var rects: [FreeRect] = []
        for i in 0 ..< (sortedY.count - 1) {
            let y0 = sortedY[i]
            let y1 = sortedY[i + 1]
            let stripH = y1 - y0
            if stripH < minDimension { continue }

            // Active occupants for this strip — anything whose Y-span overlaps
            // (y0, y1).
            let active = occupants.filter { o in
                o.y0 < y1 - 0.01 && o.y1 > y0 + 0.01
            }

            // Merged X-spans (so overlapping items collapse into one blocker).
            let raw = active.map { (start: $0.x0, end: $0.x1) }
                .sorted { $0.start < $1.start }
            var merged: [(start: Double, end: Double)] = []
            for b in raw {
                if let last = merged.last, b.start <= last.end + 0.01 {
                    merged[merged.count - 1] = (last.start, max(last.end, b.end))
                } else {
                    merged.append(b)
                }
            }

            // Free spans inside the usable X range, between consecutive
            // blockers.
            var cursor = usableX0
            for b in merged {
                if b.start > cursor + 0.01 {
                    let w = min(b.start, usableX1) - cursor
                    if w >= minDimension {
                        rects.append(FreeRect(x: cursor, y: y0, w: w, h: stripH))
                    }
                }
                cursor = max(cursor, b.end)
                if cursor >= usableX1 { break }
            }
            if usableX1 > cursor + 0.01 {
                let w = usableX1 - cursor
                if w >= minDimension {
                    rects.append(FreeRect(x: cursor, y: y0, w: w, h: stripH))
                }
            }
        }
        // Merge adjacent strips into maximal rectangles. The Y-event sweep
        // above produces narrow horizontal strips wherever items at varying
        // Y positions create event boundaries — without merging, a tall
        // empty area at the bottom of the drawer would surface as 3+ thin
        // strips instead of one big rect, and the fill pass would drop a
        // separate item into each strip.
        return mergeAdjacentRects(rects)
    }

    /// Greedy merge of adjacent free rectangles. Two rects merge if their
    /// non-shared dimension matches and they share an edge (vertically or
    /// horizontally adjacent with no gap). Loops until no more merges
    /// happen — typically converges in 2-3 passes for n ≤ 30 items.
    fileprivate static func mergeAdjacentRects(_ rects: [FreeRect]) -> [FreeRect] {
        var result = rects
        let tol = 0.05
        var didMerge = true
        while didMerge {
            didMerge = false
            outer: for i in 0 ..< result.count {
                for j in (i + 1) ..< result.count {
                    let a = result[i]
                    let b = result[j]

                    // Vertical merge: same X span, vertically adjacent.
                    if abs(a.x - b.x) < tol && abs(a.w - b.w) < tol {
                        if abs(a.y + a.h - b.y) < tol {
                            result[i] = FreeRect(x: a.x, y: a.y,
                                                  w: a.w, h: a.h + b.h)
                            result.remove(at: j)
                            didMerge = true
                            break outer
                        }
                        if abs(b.y + b.h - a.y) < tol {
                            result[i] = FreeRect(x: b.x, y: b.y,
                                                  w: b.w, h: a.h + b.h)
                            result.remove(at: j)
                            didMerge = true
                            break outer
                        }
                    }

                    // Horizontal merge: same Y span, horizontally adjacent.
                    if abs(a.y - b.y) < tol && abs(a.h - b.h) < tol {
                        if abs(a.x + a.w - b.x) < tol {
                            result[i] = FreeRect(x: a.x, y: a.y,
                                                  w: a.w + b.w, h: a.h)
                            result.remove(at: j)
                            didMerge = true
                            break outer
                        }
                        if abs(b.x + b.w - a.x) < tol {
                            result[i] = FreeRect(x: b.x, y: b.y,
                                                  w: a.w + b.w, h: b.h)
                            result.remove(at: j)
                            didMerge = true
                            break outer
                        }
                    }
                }
            }
        }
        return result
    }

    /// Score how related two groups are within a purpose. Same group → 1.0.
    /// Otherwise use the canonical `groupOrder(for:)` array as the implicit
    /// affinity signal: groups adjacent in the array are semantically related
    /// (the canonical order encodes intent like "eating → cooking → specialty"),
    /// distance encodes diminishing relatedness. Returns 0 if either group is
    /// outside the canonical order (e.g. `"filler"`, `"user_custom"`).
    fileprivate static func groupAffinity(_ a: String, _ b: String,
                                           purpose: DrawerPurpose) -> Double {
        if a == b { return 1.0 }
        let order = groupOrder(for: purpose)
        guard let i = order.firstIndex(of: a),
              let j = order.firstIndex(of: b) else { return 0.0 }
        return 1.0 / (1.0 + Double(abs(i - j)))
    }

    /// Find items whose bounding boxes are within `proximityInches` of the
    /// rect, then summarize their dominant group + a color tint.
    fileprivate static func placementContext(for rect: FreeRect,
                                              among placed: [OrganizerItem],
                                              groupByName: [String: String],
                                              proximityInches: Double = 1.75) -> PlacementContext {
        let rx1 = rect.x + rect.w
        let ry1 = rect.y + rect.h
        let neighbors: [OrganizerItem] = placed.filter { item in
            let ix1 = item.x + item.width
            let iy1 = item.y + item.height
            let dx = max(0, max(rect.x - ix1, item.x - rx1))
            let dy = max(0, max(rect.y - iy1, item.y - ry1))
            return hypot(dx, dy) <= proximityInches
        }

        let groups = neighbors.compactMap { groupByName[$0.name] }
        var counts: [String: Int] = [:]
        for g in groups { counts[g, default: 0] += 1 }
        let dominant = counts.max { $0.value < $1.value }?.key

        let dominantHue: Double? = dominant.flatMap { d in
            neighbors.first { groupByName[$0.name] == d }?.colorHue
        }

        return PlacementContext(neighborGroups: groups,
                                 dominantGroup: dominant,
                                 dominantHue: dominantHue)
    }

    /// Score a candidate template for placing in a free rect. Higher is better.
    /// Combines area-fit (claim the rect well), context bonus (group affinity
    /// with the rect's neighbors), priority bonus (catalog-important items
    /// first), and a small filler penalty so real catalog items beat generic
    /// fillers when affinity is similar.
    fileprivate static func scoreCandidate(_ template: OrganizerTemplate,
                                            fittedW: Double,
                                            fittedH: Double,
                                            in rect: FreeRect,
                                            context: PlacementContext,
                                            purpose: DrawerPurpose) -> Double {
        let templateArea = fittedW * fittedH
        let rectArea = max(0.01, rect.area)
        let areaFit = min(1.0, templateArea / rectArea)

        let affinity: Double = context.dominantGroup.map {
            groupAffinity(template.group, $0, purpose: purpose)
        } ?? 0.0

        let priorityNorm = Double(template.priority) / 10.0
        let fillerPenalty: Double = template.isFiller ? -0.15 : 0

        return areaFit * 1.0
            + affinity * 0.4
            + priorityNorm * 0.2
            + fillerPenalty
    }

    /// Compute placed dimensions for a template fitted into a free rect.
    /// Uniformly scales (preserving aspect ratio) up to the template's
    /// `stretchable.upperBound`, capped by the rect's available space minus
    /// padding on each side. Tries both orientations, picks the larger area.
    /// Returns nil if even the template's base size doesn't fit.
    fileprivate static func stretchTemplate(_ t: OrganizerTemplate,
                                             toFill rect: FreeRect,
                                             padding: Double) -> (w: Double, h: Double)? {
        let availW = rect.w - padding * 2
        let availH = rect.h - padding * 2
        if availW <= 0 || availH <= 0 { return nil }

        func fit(origW: Double, origH: Double) -> (w: Double, h: Double)? {
            if origW > availW + 0.01 || origH > availH + 0.01 { return nil }
            guard let range = t.stretchable else { return (origW, origH) }
            let scaleW = availW / origW
            let scaleH = availH / origH
            let cap = min(scaleW, scaleH, range.upperBound)
            let scale = max(range.lowerBound, cap)
            return (origW * scale, origH * scale)
        }

        let a = fit(origW: t.width, origH: t.height)
        let b = fit(origW: t.height, origH: t.width)
        switch (a, b) {
        case let (.some(aa), .some(bb)):
            return (aa.w * aa.h >= bb.w * bb.h) ? aa : bb
        case let (.some(aa), .none): return aa
        case let (.none, .some(bb)): return bb
        case (.none, .none): return nil
        }
    }

    /// Greedy context-aware fill of remaining space after the main pack.
    /// Mutates `placed` in place; appends to `selectedTemplateIds` for any
    /// non-filler templates dropped in (so the user can later remove them via
    /// the editor without them auto-respawning). Filler ids are intentionally
    /// not tracked — they're recomputed on every regenerate.
    ///
    /// Capped at `min(8, originalPlacedCount + 4)` total fill placements to
    /// avoid the visual noise of a drawer full of tiny generic bins.
    fileprivate static func fillRemaining(into placed: inout [OrganizerItem],
                                           selectedTemplateIds: inout [String],
                                           drawerW: Double,
                                           drawerD: Double,
                                           purpose: DrawerPurpose,
                                           activeTemplates: [OrganizerTemplate],
                                           userTemplates: [UserDefinedTemplate],
                                           obstacles: [DrawerObstacle]) -> Int {
        let originalCount = placed.count
        let maxFills = min(8, originalCount + 4)
        if maxFills <= 0 { return 0 }

        // Group lookup for context inference. Catalog + user templates only —
        // filler items don't need a known group (they're unscored as neighbors).
        let catalog = templates(for: purpose)
        var groupByName: [String: String] = [:]
        for t in catalog { groupByName[t.name] = t.group }
        for u in userTemplates { groupByName[u.name] = "user_custom" }

        // Templates already in the drawer, so we don't double-place a
        // non-filler. Walk `placed` in order and consume one matching catalog
        // (or user) template per item — this correctly handles the case where
        // two distinct templates share a display name (spice rows: row1 + row2
        // are both "Spice Jar Row" but have different ids).
        var alreadyUsedIds = Set<String>()
        var availableCatalog = catalog
        var availableUser: [(UserDefinedTemplate, String)] = userTemplates.map {
            ($0, "user.\($0.id.uuidString)")
        }
        for item in placed {
            if let idx = availableCatalog.firstIndex(where: { $0.name == item.name }) {
                alreadyUsedIds.insert(availableCatalog[idx].id)
                availableCatalog.remove(at: idx)
            } else if let idx = availableUser.firstIndex(where: { $0.0.name == item.name }) {
                alreadyUsedIds.insert(availableUser[idx].1)
                availableUser.remove(at: idx)
            }
            // Otherwise it's a filler from a prior pass — no id to track.
        }

        // Candidate pool: user-wanted-but-unfitted + always-allowed fillers.
        let unplacedActive = activeTemplates.filter { !alreadyUsedIds.contains($0.id) }
        let fillers = fillerTemplates()
        let candidates = unplacedActive + fillers

        // Initial free-rect set, sorted largest-first.
        var rects = freeRectangles(drawerW: drawerW, drawerD: drawerD,
                                    placed: placed, obstacles: obstacles)
            .sorted { $0.area > $1.area }

        let fillPad = intraGroupPadding   // slip-fit inset around each filler

        var fillsPlaced = 0
        while fillsPlaced < maxFills,
              let rectIdx = rects.firstIndex(where: { $0.w >= 1.5 && $0.h >= 1.5 }) {
            let rect = rects.remove(at: rectIdx)

            let context = placementContext(for: rect,
                                            among: placed,
                                            groupByName: groupByName)

            // Pick the best-scoring candidate that fits.
            struct Pick { let template: OrganizerTemplate; let w, h: Double; let score: Double }
            var best: Pick? = nil
            for template in candidates {
                // Skip non-filler dupes.
                if !template.isFiller && alreadyUsedIds.contains(template.id) { continue }
                guard let (fittedW, fittedH) = stretchTemplate(template,
                                                                toFill: rect,
                                                                padding: fillPad) else { continue }
                let placeX = rect.x + fillPad
                let placeY = rect.y + fillPad
                if collidesWithObstacles(obstacles,
                                          x: placeX, y: placeY,
                                          w: fittedW, h: fittedH) { continue }
                let s = scoreCandidate(template,
                                        fittedW: fittedW, fittedH: fittedH,
                                        in: rect, context: context,
                                        purpose: purpose)
                if best == nil || s > best!.score {
                    best = Pick(template: template, w: fittedW, h: fittedH, score: s)
                }
            }

            guard let pick = best else { continue }

            // Tint: fillers blend with the dominant neighbor's color (with
            // reduced saturation so they read as auxiliary), real items keep
            // their template hue.
            let hue = (pick.template.isFiller && context.dominantHue != nil)
                ? context.dominantHue!
                : pick.template.hue
            let saturation = pick.template.isFiller ? 0.32 : 0.55
            let brightness = 0.85

            let placeX = rect.x + fillPad
            let placeY = rect.y + fillPad

            placed.append(OrganizerItem(
                name: pick.template.name,
                x: placeX, y: placeY,
                width: pick.w, height: pick.h,
                hue: hue, saturation: saturation, brightness: brightness
            ))
            fillsPlaced += 1

            // Track non-filler additions in selectedTemplateIds so they're
            // sticky across regenerates and can be cleanly removed via the
            // editor sheet. Fillers are recomputed each generate.
            if !pick.template.isFiller {
                alreadyUsedIds.insert(pick.template.id)
                if !selectedTemplateIds.contains(pick.template.id) {
                    selectedTemplateIds.append(pick.template.id)
                }
            }

            // Carve the consumed area out of the rect, leaving up to two
            // residual rectangles. Heuristic: keep the longer strip whole so
            // subsequent placements have more usable area.
            let usedW = pick.w + 2 * fillPad
            let usedH = pick.h + 2 * fillPad
            let remainW = rect.w - usedW
            let remainH = rect.h - usedH
            if remainW >= remainH {
                if remainW >= 1.5 {
                    rects.append(FreeRect(x: rect.x + usedW, y: rect.y,
                                           w: remainW, h: rect.h))
                }
                if remainH >= 1.5 {
                    rects.append(FreeRect(x: rect.x, y: rect.y + usedH,
                                           w: usedW, h: remainH))
                }
            } else {
                if remainH >= 1.5 {
                    rects.append(FreeRect(x: rect.x, y: rect.y + usedH,
                                           w: rect.w, h: remainH))
                }
                if remainW >= 1.5 {
                    rects.append(FreeRect(x: rect.x + usedW, y: rect.y,
                                           w: remainW, h: usedH))
                }
            }
            rects.sort { $0.area > $1.area }
        }

        // Tessellation pass — recompute free rectangles from scratch using
        // the current placed list (templates from main pack + fillers from
        // the loop above). The working `rects` accumulated residuals from
        // each placement and may have fragmented tall gaps into unusable
        // strips; a fresh sweep + merge surfaces the actual maximal empty
        // rectangles. Each remaining gap ≥ 1.5×1.5 in gets a single custom-
        // sized OrganizerItem sized exactly to the rect, so the user sees
        // ONE big filler per region instead of N narrow slots.
        let finalRects = freeRectangles(
            drawerW: drawerW, drawerD: drawerD,
            placed: placed, obstacles: obstacles,
            minDimension: 1.5
        ).sorted { $0.area > $1.area }

        let customMinDim = 1.5
        for rect in finalRects where rect.w >= customMinDim && rect.h >= customMinDim {
            let w = rect.w - 2 * fillPad
            let h = rect.h - 2 * fillPad
            if w < customMinDim || h < customMinDim { continue }
            let placeX = rect.x + fillPad
            let placeY = rect.y + fillPad
            // Don't place if it would overlap an obstacle.
            if collidesWithObstacles(obstacles,
                                      x: placeX, y: placeY,
                                      w: w, h: h) { continue }

            // Tint to the dominant neighbor's hue (subtle, low saturation)
            // so the filler reads as part of the surrounding zone.
            let context = placementContext(for: rect,
                                            among: placed,
                                            groupByName: groupByName)
            let hue = context.dominantHue ?? 0.55
            placed.append(OrganizerItem(
                name: "Filler",
                x: placeX, y: placeY,
                width: w, height: h,
                hue: hue, saturation: 0.25, brightness: 0.85
            ))
            fillsPlaced += 1
        }

        return fillsPlaced
    }

    // MARK: - Debug Self-Test
    //
    // Sanity harness for the fill-pass redesign. Call from a debug build to
    // verify coverage thresholds, item-overlap freedom, and group cohesion
    // across representative drawer scenarios.

    #if DEBUG
    /// Runs `generateLayout` for several canonical drawer/purpose pairs and
    /// prints a pass/fail report to the console. Returns true if all
    /// scenarios pass their coverage threshold AND have no item overlaps.
    @discardableResult
    static func selfTest(verbose: Bool = true) -> Bool {
        struct Scenario {
            let w: Double
            let d: Double
            let purpose: DrawerPurpose
            let minCoverage: Double
            let label: String
        }
        let scenarios: [Scenario] = [
            .init(w: 14, d: 22, purpose: .utensils,        minCoverage: 75, label: "Utensils 14×22"),
            .init(w: 12, d: 18, purpose: .junkDrawer,      minCoverage: 60, label: "Junk 12×18"),
            .init(w: 16, d: 10, purpose: .spices,          minCoverage: 75, label: "Spices 16×10"),
            .init(w: 14, d: 22, purpose: .officeSupplies,  minCoverage: 75, label: "Office 14×22"),
            .init(w: 10, d: 14, purpose: .bakingTools,     minCoverage: 60, label: "Baking 10×14 (small)"),
            .init(w: 24, d: 30, purpose: .utensils,        minCoverage: 70, label: "Utensils 24×30 (large)"),
            .init(w: 14, d: 22, purpose: .linens,          minCoverage: 75, label: "Linens 14×22"),
            .init(w: 12, d: 18, purpose: .custom,          minCoverage: 65, label: "Custom 12×18"),
        ]

        var allPassed = true
        for s in scenarios {
            let m = DrawerMeasurement(
                widthInches: s.w, depthInches: s.d, heightInches: 4,
                source: .manual, confidenceScore: 1.0, heightMeasured: true
            )
            let area = s.w * s.d
            let layout = generateLayout(
                measurement: m,
                purpose: s.purpose,
                selectedIds: recommendedIds(for: s.purpose, drawerArea: area)
            )

            let coverageOK = layout.coveragePercentage >= s.minCoverage
            let overlapOK = !hasOverlaps(layout.items)
            let groupsOK = sameGroupItemsAreClustered(
                layout.items, purpose: s.purpose,
                diagonal: hypot(s.w, s.d)
            )

            let passed = coverageOK && overlapOK && groupsOK
            allPassed = allPassed && passed
            if verbose {
                let icon = passed ? "✅" : "❌"
                let cov = String(format: "%.1f%%", layout.coveragePercentage)
                print("\(icon) \(s.label): coverage=\(cov) (≥\(Int(s.minCoverage))%), items=\(layout.items.count), overlap=\(overlapOK ? "ok" : "FAIL"), groups=\(groupsOK ? "ok" : "FAIL")")
            }
        }
        if verbose {
            print(allPassed ? "All scenarios passed." : "One or more scenarios failed.")
        }
        return allPassed
    }

    /// O(n²) sweep — fine for n < 30. Returns true if any two items'
    /// rectangles overlap (more than a hair, accounting for floating-point).
    private static func hasOverlaps(_ items: [OrganizerItem]) -> Bool {
        // Tier-2 items legitimately overlap their tier-1 parent's footprint.
        let tier1 = items.filter { $0.tier == 1 }
        for i in 0 ..< tier1.count {
            for j in (i + 1) ..< tier1.count {
                let a = tier1[i], b = tier1[j]
                let aX1 = a.x + a.width, aY1 = a.y + a.height
                let bX1 = b.x + b.width, bY1 = b.y + b.height
                let overlapX = a.x < bX1 - 0.02 && b.x < aX1 - 0.02
                let overlapY = a.y < bY1 - 0.02 && b.y < aY1 - 0.02
                if overlapX && overlapY { return true }
            }
        }
        return false
    }

    /// Verifies that items belonging to the same semantic group are
    /// spatially adjacent — max pairwise center distance ≤ a fraction of the
    /// drawer diagonal. Catches regressions where fork/knife/spoon get
    /// scattered. Threshold is `diagonal / 1.6` (≈62%): generous enough to
    /// allow normal multi-shelf group splits, tight enough to catch true
    /// scatter. Logs the offending group + distance on failure.
    private static func sameGroupItemsAreClustered(_ items: [OrganizerItem],
                                                    purpose: DrawerPurpose,
                                                    diagonal: Double) -> Bool {
        let catalog = templates(for: purpose)
        var groupByName: [String: String] = [:]
        for t in catalog { groupByName[t.name] = t.group }

        var byGroup: [String: [OrganizerItem]] = [:]
        for item in items {
            guard let g = groupByName[item.name], g != "filler" else { continue }
            byGroup[g, default: []].append(item)
        }
        let threshold = diagonal / 1.6
        for (group, members) in byGroup where members.count > 1 {
            for i in 0 ..< members.count {
                for j in (i + 1) ..< members.count {
                    let a = members[i], b = members[j]
                    let cx = abs((a.x + a.width / 2) - (b.x + b.width / 2))
                    let cy = abs((a.y + a.height / 2) - (b.y + b.height / 2))
                    let d = hypot(cx, cy)
                    if d > threshold {
                        print("    [groups] \(group): \(a.name) at (\(format1(a.x)),\(format1(a.y))) and \(b.name) at (\(format1(b.x)),\(format1(b.y))) distance=\(format1(d)) > \(format1(threshold))")
                        return false
                    }
                }
            }
        }
        return true
    }

    private static func format1(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
    #endif
}
