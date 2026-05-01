//
//  BambuA1SlicerEngine.swift
//  Drawer
//
//  End-to-end on-device slicer for the Bambu A1, specialized for the
//  hollow-rectangular tray geometry this app generates. Conforms to the
//  existing `SlicerEngine` protocol; replaces `SlicerProvider.shared` when
//  the user picks a Bambu A1 printer profile.
//

import Foundation

/// Aggregates everything the slicer needs beyond what the basic
/// `PrintableOrganizer` carries — most importantly the AMS lite plate and
/// per-module/per-feature color assignment.
struct BambuSliceContext {
    var organizer: PrintableOrganizer
    var amsPlate: AMSLitePlate
    var coloringPolicy: ColoringPolicy
    var assignment: AMSLiteAssignment

    static func defaultContext(for organizer: PrintableOrganizer,
                                colors: [FilamentColor]) -> BambuSliceContext {
        let mat = organizer.filament.material
        let slots: [FilamentProfile?] = (0..<4).map { i in
            i < colors.count
                ? FilamentProfile(material: mat, color: colors[i])
                : nil
        }
        let plate = AMSLitePlate(slots: slots)
        let assignment = AMSLiteColorPlanner.resolveAssignment(
            policy: .monoPlate,
            plate: plate,
            modules: organizer.modules
        )
        return BambuSliceContext(
            organizer: organizer,
            amsPlate: plate,
            coloringPolicy: .monoPlate,
            assignment: assignment
        )
    }
}

struct BambuSliceOutput {
    var jobSummary: SlicedPrintJob
    var packageURL: URL
    var sizeBytes: Int
    var moduleCount: Int
    var perSlotUsage: [Int: (lengthMm: Double, weightG: Double)]
}

struct BambuA1SlicerEngine: SlicerEngine {
    let capability: SlicerCapability = .fullToolpath
    let displayName: String = "Bambu A1 (on-device)"
    let availabilityNote: String = "Native Bambu A1 .gcode.3mf generation. Geometry is limited to the tray modules this app produces — open in Bambu Studio to verify before your first print."

    /// Default `slice` for the protocol when the caller doesn't supply a
    /// context. Falls back to a mono-color plate using the organizer's
    /// current filament.
    func slice(organizer: PrintableOrganizer) throws -> SlicedPrintJob {
        let ctx = BambuSliceContext.defaultContext(
            for: organizer,
            colors: [organizer.filament.color]
        )
        let result = try sliceWithContext(ctx, fileBaseName: "drawer_\(organizer.purpose.rawValue)")
        return result.jobSummary
    }

    /// Full slice that returns the produced `.gcode.3mf` URL plus diagnostics.
    func sliceWithContext(_ ctx: BambuSliceContext,
                           fileBaseName: String) throws -> BambuSliceOutput {
        guard !ctx.organizer.modules.isEmpty else { throw SlicerError.noModules }

        // Resolve assignment from policy if it wasn't provided.
        let assignment = ctx.assignment

        // 1. Per-module layer plans
        let settings = ctx.organizer.settings
        let lineWidth = settings.wallThicknessMm > 0
            ? min(settings.wallThicknessMm, 0.45)
            : 0.42
        let infillLineWidth = lineWidth
        let bottomLayerCount = max(1, Int(round(settings.bottomThicknessMm / settings.layerHeightMm)))

        // Plan layers per module then merge across modules at each layer index.
        var perModuleLayers: [[LayerPlan]] = []
        for module in ctx.organizer.modules {
            let slots = AMSLiteColorPlanner.slots(for: module, assignment: assignment)
            let inputs = TrayLayerPlanner.PlanInputs(
                module: module,
                settings: settings,
                wallLineWidthMm: lineWidth,
                infillLineWidthMm: infillLineWidth,
                bottomLayerCount: bottomLayerCount,
                outerWallColorSlot: slots.outer,
                innerWallColorSlot: slots.inner,
                bottomColorSlot: slots.bottom
            )
            perModuleLayers.append(TrayLayerPlanner.plan(inputs))
        }

        // Merge to plate-level layers (interleave modules at each z step).
        let maxLayerCount = perModuleLayers.map { $0.count }.max() ?? 0
        var mergedLayers: [LayerPlan] = []
        mergedLayers.reserveCapacity(maxLayerCount)
        for i in 0..<maxLayerCount {
            var paths: [ToolPath] = []
            var z = 0.0
            var layerHeight = settings.layerHeightMm
            for moduleLayers in perModuleLayers {
                if i < moduleLayers.count {
                    paths.append(contentsOf: moduleLayers[i].paths)
                    z = moduleLayers[i].z
                    layerHeight = moduleLayers[i].layerHeightMm
                }
            }
            // Add skirt on layer 0 only.
            if i == 0 {
                let skirtSlot = assignment.defaultSlot
                paths.append(contentsOf: SkirtPlanner.skirt(
                    around: ctx.organizer.modules,
                    distanceMm: 3.0,
                    loops: 1,
                    lineWidthMm: lineWidth,
                    colorSlot: skirtSlot
                ))
            }
            mergedLayers.append(LayerPlan(
                index: i, z: z,
                layerHeightMm: layerHeight,
                paths: paths
            ))
        }

        // 2. AMS lite ranges + filament usage
        let ranges = AMSLiteColorPlanner.computeLayerFilamentRanges(layers: mergedLayers)
        let usage = AMSLiteColorPlanner.computeFilamentUsage(
            layers: mergedLayers,
            layerHeightMm: settings.layerHeightMm,
            plate: ctx.amsPlate
        )
        let totalGrams = usage.values.reduce(0) { $0 + $1.weightG }
        let printTimeSec = max(60, Int(totalGrams * 60.0 / 3.0))   // 3 g/min throughput baseline
        let modelTimeSec = max(60, Int(printTimeSec * 8 / 10))

        // 3. Emit gcode
        let emitInputs = BambuEmitInputs(
            modules: ctx.organizer.modules,
            layers: mergedLayers,
            plate: ctx.amsPlate,
            assignment: assignment,
            settings: settings,
            layerFilamentRanges: ranges,
            perSlotUsage: usage,
            modelTimeSeconds: modelTimeSec,
            printTimeSeconds: printTimeSec,
            firstLayerHeightMm: settings.layerHeightMm,
            layerHeightMm: settings.layerHeightMm,
            wallLineWidthMm: lineWidth,
            infillLineWidthMm: infillLineWidth,
            bottomLayerCount: bottomLayerCount
        )
        let emit = BambuA1GcodeEmitter.emit(emitInputs)

        // 4. Package
        let pkgInputs = BambuGcode3MFInputs(
            modules: ctx.organizer.modules,
            plate: ctx.amsPlate,
            assignment: assignment,
            drawerWidthMm: ctx.organizer.drawerInteriorWidthMm,
            drawerDepthMm: ctx.organizer.drawerInteriorDepthMm,
            gcodeBody: emit.gcode,
            gcodeMd5: emit.md5,
            layerFilamentRanges: ranges,
            perSlotUsage: usage,
            totalWeightG: totalGrams,
            predictionSeconds: printTimeSec,
            fileBaseName: fileBaseName
        )
        let exportResult = try BambuGcode3MFPackager.package(pkgInputs)

        // 5. Build job summary
        // NOTE: oversized-module warnings are intentionally *not* appended
        // here — `PrintPrepView.warningsSection` builds that message itself
        // (in red, since oversize is a hard fit failure) so duplicating it
        // here would render the same string twice.
        var warnings: [String] = []
        if ctx.organizer.settings.wallThicknessMm < 0.8 {
            warnings.append("Walls thinner than 0.8 mm may print poorly.")
        }
        if printTimeSec > 6 * 3600 {
            warnings.append("Estimated print time exceeds 6 hours.")
        }
        if ctx.amsPlate.activeFilaments.count > 1 && totalGrams > 200 {
            warnings.append("Multi-color print over 200 g — flush volume can be significant.")
        }

        let summary = """
        \(ctx.organizer.modules.count) modules • \(ctx.amsPlate.activeFilaments.count) filament(s) • \(String(format: "%.0f", totalGrams)) g • approx \(formatDuration(printTimeSec))
        """
        let job = SlicedPrintJob(
            capability: .fullToolpath,
            summary: summary,
            warnings: warnings,
            estimatedPrintTimeMinutes: Double(printTimeSec) / 60.0,
            estimatedFilamentGrams: totalGrams,
            outputURL: exportResult.fileURL
        )
        return BambuSliceOutput(
            jobSummary: job,
            packageURL: exportResult.fileURL,
            sizeBytes: exportResult.sizeBytes,
            moduleCount: emit.totalLayers > 0 ? ctx.organizer.modules.count : 0,
            perSlotUsage: usage
        )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) hr" }
        return "\(h) hr \(m) min"
    }
}

// MARK: - Provider helper

extension SlicerProvider {
    /// Pick the right slicer for a printer profile. Bambu A1 → native engine;
    /// any other profile → diagnostic engine (we don't claim full slicing
    /// support outside the A1).
    static func engine(for printer: PrinterProfile) -> SlicerEngine {
        if printer.id == PrinterProfile.bambuA1.id ||
           printer.id == PrinterProfile.bambuA1Mini.id {
            return BambuA1SlicerEngine()
        }
        return DiagnosticSlicerEngine()
    }
}
