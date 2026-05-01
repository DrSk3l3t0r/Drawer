//
//  AMSLiteColorPlanner.swift
//  Drawer
//
//  Resolves per-module + per-feature color assignments into a concrete
//  AMS lite plate and computes the per-layer filament usage ranges that
//  Bambu Studio expects. The Bambu A1 with AMS lite flushes filament off
//  the side of the bed, so we don't need a prime tower — the change_filament
//  gcode block handles the flush automatically.
//

import Foundation

// MARK: - Coloring policy + assignment

enum ColoringPolicy: String, Codable, CaseIterable, Identifiable {
    case monoPlate
    case perModule
    case perFeature
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monoPlate: return "Single Color"
        case .perModule: return "Per Tray"
        case .perFeature: return "Per Feature"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .monoPlate: return "Print the entire plate in one color."
        case .perModule: return "Each tray uses the next AMS slot in rotation."
        case .perFeature: return "Walls and bottom use different colors."
        case .custom: return "Manually assign colors per tray and feature."
        }
    }
}

/// AMS lite has 4 slots. Each slot is a `FilamentProfile`. The plate must
/// contain at least one slot.
struct AMSLitePlate: Codable, Equatable {
    /// 1–4 filament profiles, one per slot. `nil` means slot empty/unused.
    var slots: [FilamentProfile?]

    static let single = AMSLitePlate(slots: [.default, nil, nil, nil])

    /// Resolved active filaments in slot order, ignoring empty slots but
    /// preserving their slot index.
    var activeFilaments: [(slot: Int, profile: FilamentProfile)] {
        slots.enumerated().compactMap { idx, p in
            p.map { (idx, $0) }
        }
    }
}

/// Resolved (module, feature) → slot mapping. Built from a `ColoringPolicy`.
struct AMSLiteAssignment: Equatable {
    /// Default slot when no specific override matches. Always points to a
    /// non-empty slot.
    var defaultSlot: Int
    /// Per-module override (e.g. perModule policy maps each tray to a slot).
    var moduleSlot: [UUID: Int]
    /// Per-feature override that overrides moduleSlot when the feature kind
    /// matches (e.g. bottoms in slot 1, walls in slot 0).
    var featureSlot: [FeatureKind: Int]
    /// Per-(module, feature) override that wins over both above (custom mode).
    var moduleFeatureSlot: [ModuleFeatureKey: Int]

    struct ModuleFeatureKey: Hashable {
        let module: UUID
        let feature: FeatureKind
    }

    static let mono = AMSLiteAssignment(
        defaultSlot: 0,
        moduleSlot: [:],
        featureSlot: [:],
        moduleFeatureSlot: [:]
    )

    func slot(for moduleId: UUID, feature: FeatureKind) -> Int {
        if let s = moduleFeatureSlot[ModuleFeatureKey(module: moduleId, feature: feature)] {
            return s
        }
        if let s = featureSlot[feature] {
            return s
        }
        if let s = moduleSlot[moduleId] {
            return s
        }
        return defaultSlot
    }
}

// MARK: - Layer filament list

/// Bambu's `<layer_filament_lists>` entry. `filamentList` is a
/// semicolon-or-space-separated string of slot indices used somewhere on
/// these layers; `layerRanges` is the closed-open layer index range.
struct LayerFilamentRange: Equatable, Codable {
    var filamentSlots: [Int]    // sorted ascending, unique
    var firstLayer: Int
    var lastLayer: Int

    var filamentListString: String {
        filamentSlots.map(String.init).joined(separator: " ")
    }

    var layerRangeString: String {
        "\(firstLayer) \(lastLayer)"
    }
}

// MARK: - Planner

enum AMSLiteColorPlanner {

    /// Build a default assignment for a coloring policy.
    static func resolveAssignment(
        policy: ColoringPolicy,
        plate: AMSLitePlate,
        modules: [PrintableModule]
    ) -> AMSLiteAssignment {
        let actives = plate.activeFilaments
        guard let firstSlot = actives.first?.slot else {
            return .mono
        }

        switch policy {
        case .monoPlate:
            return AMSLiteAssignment(
                defaultSlot: firstSlot,
                moduleSlot: [:],
                featureSlot: [:],
                moduleFeatureSlot: [:]
            )

        case .perModule:
            var moduleSlot: [UUID: Int] = [:]
            for (i, module) in modules.enumerated() {
                let slot = actives[i % actives.count].slot
                moduleSlot[module.id] = slot
            }
            return AMSLiteAssignment(
                defaultSlot: firstSlot,
                moduleSlot: moduleSlot,
                featureSlot: [:],
                moduleFeatureSlot: [:]
            )

        case .perFeature:
            var featureSlot: [FeatureKind: Int] = [:]
            featureSlot[.outerWall] = actives[0].slot
            if actives.count >= 2 { featureSlot[.innerWall] = actives[1].slot }
            if actives.count >= 3 { featureSlot[.bottomSurface] = actives[2].slot }
            else { featureSlot[.bottomSurface] = actives[0].slot }
            return AMSLiteAssignment(
                defaultSlot: firstSlot,
                moduleSlot: [:],
                featureSlot: featureSlot,
                moduleFeatureSlot: [:]
            )

        case .custom:
            // Custom starts as mono — user fills in `moduleFeatureSlot`
            // through the editor UI.
            return AMSLiteAssignment(
                defaultSlot: firstSlot,
                moduleSlot: [:],
                featureSlot: [:],
                moduleFeatureSlot: [:]
            )
        }
    }

    /// Apply the assignment to the planner inputs for a single module —
    /// returns the slot indices for outer wall, inner wall, and bottom.
    static func slots(for module: PrintableModule,
                       assignment: AMSLiteAssignment) -> (outer: Int, inner: Int, bottom: Int) {
        return (
            outer: assignment.slot(for: module.id, feature: .outerWall),
            inner: assignment.slot(for: module.id, feature: .innerWall),
            bottom: assignment.slot(for: module.id, feature: .bottomSurface)
        )
    }

    /// Build per-layer filament lists from a sequence of layer plans across
    /// all modules. The Bambu `<layer_filament_list>` entries are run-length
    /// encoded contiguous ranges where the filament set is identical.
    static func computeLayerFilamentRanges(layers: [LayerPlan]) -> [LayerFilamentRange] {
        var ranges: [LayerFilamentRange] = []
        var currentSet: [Int] = []
        var rangeStart = 0

        for (i, layer) in layers.enumerated() {
            let slotSet = Array(Set(layer.paths.map { $0.colorSlot })).sorted()
            if slotSet != currentSet {
                if !currentSet.isEmpty {
                    ranges.append(LayerFilamentRange(
                        filamentSlots: currentSet,
                        firstLayer: rangeStart,
                        lastLayer: i - 1
                    ))
                }
                currentSet = slotSet
                rangeStart = i
            }
        }
        if !currentSet.isEmpty {
            ranges.append(LayerFilamentRange(
                filamentSlots: currentSet,
                firstLayer: rangeStart,
                lastLayer: layers.count - 1
            ))
        }
        return ranges
    }

    /// Compute total grams used per slot, accumulating extrusion across all
    /// paths for that slot. Uses simple line-volume math.
    static func computeFilamentUsage(layers: [LayerPlan],
                                       layerHeightMm: Double,
                                       plate: AMSLitePlate,
                                       filamentDiameterMm: Double = 1.75)
        -> [Int: (lengthMm: Double, weightG: Double)] {

        let filamentXSec = .pi * pow(filamentDiameterMm / 2, 2)
        var usage: [Int: Double] = [:]   // slot → mm of filament

        for layer in layers {
            for path in layer.paths {
                let pathLen = path.totalLengthMm
                // Volume of extrusion: pathLen * lineWidth * layerHeight
                let volume = pathLen * path.lineWidthMm * layerHeightMm
                let filamentLen = volume / filamentXSec
                usage[path.colorSlot, default: 0] += filamentLen
            }
        }

        var result: [Int: (lengthMm: Double, weightG: Double)] = [:]
        for (slot, length) in usage {
            let profile = plate.slots[safe: slot] ?? nil
            let density = profile.map { BambuFilamentCatalog.entry(for: $0.material).density } ?? 1.24
            let volumeCm3 = (length * filamentXSec) / 1000.0
            let grams = volumeCm3 * density
            result[slot] = (length, grams)
        }
        return result
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
