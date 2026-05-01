//
//  BambuA1GcodeEmitter.swift
//  Drawer
//
//  Renders Bambu A1 .gcode files (the `Metadata/plate_1.gcode` content of
//  a `.gcode.3mf` package) from a sequence of LayerPlans. Produces:
//    - `; HEADER_BLOCK_START/END`
//    - `; CONFIG_BLOCK_START/END`
//    - `; EXECUTABLE_BLOCK_START` ... `; EXECUTABLE_BLOCK_END`
//
//  Extrusion math: E += pathLength * lineWidth * layerHeight / filamentXSec.
//  All extrusion is relative (M83) so we don't accumulate floating-point
//  error across thousands of moves.
//

import Foundation
import CryptoKit

struct BambuEmitInputs {
    let modules: [PrintableModule]
    let layers: [LayerPlan]                 // already merged across all modules
    let plate: AMSLitePlate
    let assignment: AMSLiteAssignment
    let settings: PrintSettings
    let layerFilamentRanges: [LayerFilamentRange]
    let perSlotUsage: [Int: (lengthMm: Double, weightG: Double)]
    let modelTimeSeconds: Int               // print time without warmup
    let printTimeSeconds: Int               // total estimated time
    let firstLayerHeightMm: Double
    let layerHeightMm: Double
    let wallLineWidthMm: Double
    let infillLineWidthMm: Double
    let bottomLayerCount: Int
}

struct BambuEmitResult {
    let gcode: String
    let md5: String
    let totalLayers: Int
    let totalFilamentLengthMm: Double
    let totalFilamentVolumeCm3: Double
    let totalFilamentWeightG: Double
    let maxZmm: Double
}

enum BambuA1GcodeEmitter {

    static func emit(_ inputs: BambuEmitInputs) -> BambuEmitResult {
        let totalLengthMm = inputs.perSlotUsage.values.reduce(0) { $0 + $1.lengthMm }
        let totalWeightG = inputs.perSlotUsage.values.reduce(0) { $0 + $1.weightG }
        let filamentDiameter = 1.75
        let filamentXSec = .pi * pow(filamentDiameter / 2, 2)
        let totalVolumeCm3 = (totalLengthMm * filamentXSec) / 1000.0
        let maxZ = inputs.layers.last?.z ?? 0

        let primaryFilament = inputs.plate.activeFilaments.first?.profile ?? .default
        let primaryEntry = BambuFilamentCatalog.entry(for: primaryFilament.material)

        let header = BambuHeaderBlock.render(
            layerCount: inputs.layers.count,
            totalFilamentLengthMm: totalLengthMm,
            totalFilamentVolumeCm3: totalVolumeCm3,
            totalFilamentWeightG: totalWeightG,
            maxZmm: maxZ,
            printTimeSeconds: inputs.printTimeSeconds,
            modelTimeSeconds: inputs.modelTimeSeconds,
            filamentCount: inputs.plate.activeFilaments.count,
            filamentDensityFirst: primaryEntry.density
        )

        let configInputs = BambuA1ConfigBlock.ConfigInputs(
            layerHeightMm: inputs.layerHeightMm,
            firstLayerHeightMm: inputs.firstLayerHeightMm,
            wallThicknessMm: inputs.settings.wallThicknessMm,
            wallLineWidthMm: inputs.wallLineWidthMm,
            bottomLayerCount: inputs.bottomLayerCount,
            infillPercent: inputs.settings.infillPercent,
            filaments: inputs.plate.activeFilaments.map { $0.profile },
            nozzleTemp: primaryEntry.nozzleTemp,
            bedTemp: primaryEntry.bedTemp,
            totalLayers: inputs.layers.count,
            totalFilamentLengthMm: totalLengthMm,
            totalFilamentWeightG: totalWeightG,
            printTimeSeconds: inputs.printTimeSeconds,
            amsLiteEnabled: inputs.plate.activeFilaments.count > 1,
            usePurgeTower: false
        )

        let configBlock = """
        ; CONFIG_BLOCK_START
        \(BambuA1ConfigBlock.render(configInputs))
        ; CONFIG_BLOCK_END
        """

        let executable = renderExecutableBlock(inputs: inputs,
                                                primaryEntry: primaryEntry)

        let body = [header, "", configBlock, "", executable].joined(separator: "\n")
        let md5 = md5Hex(of: body)
        return BambuEmitResult(
            gcode: body,
            md5: md5,
            totalLayers: inputs.layers.count,
            totalFilamentLengthMm: totalLengthMm,
            totalFilamentVolumeCm3: totalVolumeCm3,
            totalFilamentWeightG: totalWeightG,
            maxZmm: maxZ
        )
    }

    // MARK: - Executable block

    private static func renderExecutableBlock(inputs: BambuEmitInputs,
                                                primaryEntry: BambuFilamentCatalog.Entry) -> String {
        var s = "; EXECUTABLE_BLOCK_START\n"
        s += "M73 P0 R\(max(1, inputs.printTimeSeconds / 60))\n"
        s += "M201 X12000 Y12000 Z1500 E5000\n"
        s += "M203 X500 Y500 Z30 E30\n"
        s += "M204 P12000 R5000 T12000\n"
        s += "M205 X9.00 Y9.00 Z3.00 E3.00\n"
        s += renderStartGcode(primaryEntry: primaryEntry)
        s += "\n"

        let extruder = ExtruderState(
            layerHeight: inputs.layerHeightMm,
            wallLineWidth: inputs.wallLineWidthMm,
            infillLineWidth: inputs.infillLineWidthMm,
            filamentDiameter: 1.75,
            travelFeedrate: 12000,
            outerWallFeedrate: 7200,    // 200 * 60 / 1.67 ish — actually 200 mm/s = 12000 mm/min, but A1 limits to ~7200 for outer
            innerWallFeedrate: 9000,
            infillFeedrate: 9000,
            firstLayerFeedrate: 1500
        )

        let totalLayers = inputs.layers.count
        var currentSlot = inputs.assignment.defaultSlot
        var lastZ = 0.0
        var currentColorRangeIndex = 0

        for layer in inputs.layers {
            let progressPercent = Int((Double(layer.index + 1) / Double(totalLayers)) * 100.0)

            s += "; CHANGE_LAYER\n"
            s += "; Z_HEIGHT: \(format(layer.z))\n"
            s += "; LAYER_HEIGHT: \(format(layer.layerHeightMm))\n"
            s += "G1 E-\(format(0.8)) F1800\n"   // retract on layer change
            s += "; layer num/total_layer_count: \(layer.index + 1)/\(totalLayers)\n"
            s += "M73 L\(layer.index + 1)\n"
            s += "M73 P\(progressPercent)\n"
            s += "M991 S0 P\(layer.index)\n"

            // Cooling fan ramps in after `close_fan_the_first_x_layers`.
            if layer.index == 1 {
                s += "M106 P1 S\(Int(Double(primaryEntry.fanMinSpeed) * 2.55))\n"
            }

            // Z move
            if abs(layer.z - lastZ) > 1e-4 {
                s += "G1 Z\(format(layer.z)) F600\n"
                lastZ = layer.z
            }

            // Group paths by feature for nicer markers.
            let grouped = groupedByFeature(layer.paths)
            for (feature, paths) in grouped {
                guard !paths.isEmpty else { continue }
                // Tool change if needed (use the first path's slot).
                let neededSlot = paths.first!.colorSlot
                if neededSlot != currentSlot {
                    s += renderToolChange(
                        from: currentSlot,
                        to: neededSlot,
                        plate: inputs.plate,
                        currentZ: layer.z
                    )
                    currentSlot = neededSlot
                }

                s += "; FEATURE: \(feature.bambuFeatureLabel)\n"
                let lineWidth = paths.first?.lineWidthMm ?? inputs.wallLineWidthMm
                s += "; LINE_WIDTH: \(format(lineWidth))\n"

                let feedrate = feedrateFor(feature: feature, layer: layer, extruder: extruder)
                for path in paths {
                    s += extruder.renderPath(path: path,
                                              layerHeight: layer.layerHeightMm,
                                              feedrate: feedrate,
                                              isFirstLayer: layer.index == 0)
                }
            }

            currentColorRangeIndex += 1
            _ = currentColorRangeIndex  // silence warning
        }

        s += renderEndGcode(maxZ: inputs.layers.last?.z ?? 0)
        s += "\n; EXECUTABLE_BLOCK_END\n"
        return s
    }

    // MARK: - Tool change

    private static func renderToolChange(from: Int, to: Int,
                                          plate: AMSLitePlate,
                                          currentZ: Double) -> String {
        guard let oldProfile = plate.slots[safe: from] ?? nil,
              let newProfile = plate.slots[safe: to] ?? nil else {
            return "; (skipping tool change — invalid slot)\n"
        }
        let oldEntry = BambuFilamentCatalog.entry(for: oldProfile.material)
        let newEntry = BambuFilamentCatalog.entry(for: newProfile.material)
        let flushVol = BambuFilamentCatalog.defaultFlushVolume(
            from: oldProfile.color, to: newProfile.color
        )
        // Convert volume → length: length = volume / cross_section
        let crossSection = .pi * pow(1.75 / 2, 2)
        let flushLengthMm = flushVol / crossSection

        let block = BambuAMSLiteChange.render(
            from: from,
            to: to,
            oldTemp: oldEntry.nozzleTemp,
            newTemp: newEntry.nozzleTemp,
            flushLengthMm: flushLengthMm,
            currentZMm: currentZ,
            oldFeedrate: 1200,
            newFeedrate: 1200
        )
        return "\n" + block + "\n"
    }

    // MARK: - Start / end gcode rendering

    private static func renderStartGcode(primaryEntry: BambuFilamentCatalog.Entry) -> String {
        var s = BambuA1StartGcode.template
        s = s.replacingOccurrences(of: "{{FILAMENT_TYPE}}", with: primaryEntry.typeName)
        s = s.replacingOccurrences(of: "{{NOZZLE_TEMP_PREHEAT}}",
                                    with: String(min(primaryEntry.nozzleTemp - 60, 180)))
        s = s.replacingOccurrences(of: "{{NOZZLE_TEMP}}", with: String(primaryEntry.nozzleTemp))
        s = s.replacingOccurrences(of: "{{BED_TEMP}}", with: String(primaryEntry.bedTemp))
        return s + "\n"
    }

    private static func renderEndGcode(maxZ: Double) -> String {
        var s = BambuA1EndGcode.template
        let lift = min(255, max(maxZ + 10, 20))
        s = s.replacingOccurrences(of: "{{Z_LIFT}}", with: format(lift))
        return "\n" + s + "\n"
    }

    // MARK: - Helpers

    private static func groupedByFeature(_ paths: [ToolPath]) -> [(FeatureKind, [ToolPath])] {
        var byFeature: [FeatureKind: [ToolPath]] = [:]
        var order: [FeatureKind] = []
        for path in paths {
            if byFeature[path.feature] == nil { order.append(path.feature) }
            byFeature[path.feature, default: []].append(path)
        }
        return order.map { ($0, byFeature[$0]!) }
    }

    private static func feedrateFor(feature: FeatureKind,
                                     layer: LayerPlan,
                                     extruder: ExtruderState) -> Int {
        if layer.index == 0 { return extruder.firstLayerFeedrate }
        switch feature {
        case .outerWall, .skirt: return extruder.outerWallFeedrate
        case .innerWall: return extruder.innerWallFeedrate
        case .bottomSurface, .topSurface, .primeTower, .custom: return extruder.infillFeedrate
        }
    }

    private static func format(_ d: Double) -> String {
        // Bambu uses 3 decimals for positions
        return String(format: "%.3f", d)
    }

    static func md5Hex(of s: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Extruder state

private struct ExtruderState {
    let layerHeight: Double
    let wallLineWidth: Double
    let infillLineWidth: Double
    let filamentDiameter: Double
    let travelFeedrate: Int
    let outerWallFeedrate: Int
    let innerWallFeedrate: Int
    let infillFeedrate: Int
    let firstLayerFeedrate: Int

    var filamentXSec: Double { .pi * pow(filamentDiameter / 2, 2) }

    func extrusionAmount(forLength lengthMm: Double, lineWidth: Double, layerHeight: Double) -> Double {
        let volume = lengthMm * lineWidth * layerHeight
        return volume / filamentXSec
    }

    /// Render a path as G1 moves. The first move is a travel (no extrusion);
    /// subsequent moves extrude. Closes the path if `closed`.
    func renderPath(path: ToolPath, layerHeight: Double,
                    feedrate: Int, isFirstLayer: Bool) -> String {
        guard path.points.count >= 2 else { return "" }
        var s = ""
        let first = path.points.first!
        s += "G1 X\(fmt(first.x)) Y\(fmt(first.y)) F\(travelFeedrate)\n"
        // Deretract before extruding
        s += "G1 E0.8 F1800\n"

        var prev = first
        for next in path.points.dropFirst() {
            let len = hypot(next.x - prev.x, next.y - prev.y)
            let e = extrusionAmount(forLength: len,
                                     lineWidth: path.lineWidthMm,
                                     layerHeight: layerHeight)
            s += "G1 X\(fmt(next.x)) Y\(fmt(next.y)) E\(fmt(e, decimals: 5)) F\(feedrate)\n"
            prev = next
        }
        if path.closed {
            let len = hypot(first.x - prev.x, first.y - prev.y)
            let e = extrusionAmount(forLength: len,
                                     lineWidth: path.lineWidthMm,
                                     layerHeight: layerHeight)
            s += "G1 X\(fmt(first.x)) Y\(fmt(first.y)) E\(fmt(e, decimals: 5)) F\(feedrate)\n"
        }
        // Wipe + retract at end of contour
        s += "; WIPE_START\n"
        s += "G1 E-0.8 F1800\n"
        s += "; WIPE_END\n"
        return s
    }

    private func fmt(_ d: Double, decimals: Int = 3) -> String {
        String(format: "%.\(decimals)f", d)
    }
}

// MARK: - Helpers shared with planner

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
