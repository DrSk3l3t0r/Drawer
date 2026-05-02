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
                                  group: "main_tray", groupOrder: 1),
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
                                  group: "catchall", groupOrder: 1),
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
                                  group: "accessories", groupOrder: 1),
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
                                  group: "tools", groupOrder: 3),
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
                                  group: "large_bins", groupOrder: 1),
                OrganizerTemplate(id: "custom.wide", name: "Wide Tray",
                                  width: 8.0, height: 3.0, hue: 0.42, priority: 7,
                                  group: "large_bins", groupOrder: 2),
                OrganizerTemplate(id: "custom.medium", name: "Medium Bin",
                                  width: 5.0, height: 5.0, hue: 0.50, priority: 8,
                                  group: "medium_bins", groupOrder: 1),
                OrganizerTemplate(id: "custom.narrow", name: "Narrow Slot",
                                  width: 2.0, height: 8.0, hue: 0.60, priority: 5,
                                  group: "medium_bins", groupOrder: 2),
                OrganizerTemplate(id: "custom.small", name: "Small Bin",
                                  width: 3.0, height: 4.0, hue: 0.55, priority: 6,
                                  group: "small_bins", groupOrder: 1),
                OrganizerTemplate(id: "custom.tiny", name: "Tiny Tray",
                                  width: 3.0, height: 3.0, hue: 0.65, priority: 4,
                                  group: "small_bins", groupOrder: 2),
            ]
        }
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

    /// Default selection for a purpose: items above the "recommended" priority bar.
    static func recommendedIds(for purpose: DrawerPurpose) -> Set<String> {
        Set(templates(for: purpose).filter { $0.isRecommended }.map { $0.id })
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

        let totalArea = drawerW * drawerD
        let usedArea = result.placed.reduce(0.0) { $0 + ($1.width * $1.height) }
        let coverage = totalArea > 0 ? (usedArea / totalArea) * 100.0 : 0

        return DrawerLayout(
            measurement: measurement,
            purpose: purpose,
            items: result.placed,
            coveragePercentage: min(coverage, 100.0),
            unplacedTemplates: result.unplaced,
            warnings: warnings,
            selectedTemplateIds: activeTemplates.map { $0.id }
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

    /// Outer gap between shelves and between distinct units on a shelf.
    private static let shelfPadding: Double = 0.25
    /// Inner gap between items in the same group block — kept tight so that
    /// fork/spoon/knife look and feel like a coherent cutlery row instead of
    /// three loose modules.
    private static let intraGroupPadding: Double = 0.1

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
}
