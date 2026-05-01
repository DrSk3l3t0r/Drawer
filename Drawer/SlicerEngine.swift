//
//  SlicerEngine.swift
//  Drawer
//
//  Protocol seam for an on-device slicer. Real production slicing requires
//  embedding a substantial native engine (e.g. PrusaSlicer/Slic3r/CuraEngine)
//  as a separate library target, with build-system, licensing, and
//  performance work that is well outside the scope of an iOS app feature.
//
//  Until that lands, the app exposes a `DiagnosticSlicerEngine` that
//  validates geometry, computes simple estimates, and returns a structured
//  `SlicedPrintJob` describing the *intended* print without actually
//  generating G-code.
//
//  The protocol is the integration seam: when a real engine is available,
//  swap in a new implementation behind `SlicerProvider.shared`.
//

import Foundation

// MARK: - Slicer Capability

enum SlicerCapability: String, Codable {
    /// Cannot generate real toolpaths — only validate and estimate.
    case diagnostic
    /// Full G-code generation available.
    case fullToolpath
}

// MARK: - Slicer Output

struct SlicedPrintJob: Equatable {
    let capability: SlicerCapability
    let summary: String
    let warnings: [String]
    let estimatedPrintTimeMinutes: Double?
    let estimatedFilamentGrams: Double?
    /// File URL of the slicer output, if any (G-code, sliced 3MF, etc.).
    /// Diagnostic engine returns `nil`.
    let outputURL: URL?
}

enum SlicerError: Error, LocalizedError {
    case noModules
    case engineUnavailable(reason: String)
    case sliceFailed(String)

    var errorDescription: String? {
        switch self {
        case .noModules: return "No modules to slice."
        case .engineUnavailable(let r): return "Slicing unavailable: \(r)"
        case .sliceFailed(let m): return "Slicing failed: \(m)"
        }
    }
}

// MARK: - Slicer Protocol

protocol SlicerEngine {
    var capability: SlicerCapability { get }
    var displayName: String { get }
    /// Brief human description shown in the UI when the engine cannot fully
    /// slice (e.g. why on-device G-code generation isn't available yet).
    var availabilityNote: String { get }

    func slice(organizer: PrintableOrganizer) throws -> SlicedPrintJob
}

// MARK: - Provider

enum SlicerProvider {
    /// Replace this when a full on-device engine is integrated. The
    /// diagnostic engine is the safe default for this build.
    static var shared: SlicerEngine = DiagnosticSlicerEngine()
}

// MARK: - Diagnostic Engine

/// Validates geometry and estimates filament/time without actually generating
/// G-code. Documents the gap between "we can export 3MF" and "we can slice
/// on-device" so the UI can be honest about it.
struct DiagnosticSlicerEngine: SlicerEngine {
    let capability: SlicerCapability = .diagnostic
    let displayName: String = "On-device estimator"
    let availabilityNote: String = "Full on-device slicing requires embedding a native slicer engine. For now, this estimates filament and time and exports the 3MF for Bambu Studio."

    func slice(organizer: PrintableOrganizer) throws -> SlicedPrintJob {
        guard !organizer.modules.isEmpty else { throw SlicerError.noModules }

        var warnings: [String] = []

        let oversized = organizer.oversizedModules()
        if !oversized.isEmpty {
            warnings.append("\(oversized.count) module(s) exceed the printer bed and will need to be split: \(oversized.map { $0.name }.joined(separator: ", "))")
        }

        if organizer.settings.wallThicknessMm < 0.8 {
            warnings.append("Walls thinner than 0.8 mm may print poorly.")
        }
        if organizer.settings.layerHeightMm < 0.08 || organizer.settings.layerHeightMm > 0.32 {
            warnings.append("Layer height \(organizer.settings.layerHeightMm) mm is outside typical 0.08–0.32 mm range.")
        }

        // Very rough time estimate: ~3 g/min print throughput for FDM at
        // medium-quality settings. This is intentionally a ballpark figure.
        let grams = organizer.totalGrams
        let timeMinutes = max(8, grams / 3.0)

        let summary = """
        \(organizer.modules.count) modules • \(String(format: "%.0f", grams)) g \(organizer.filament.material.displayName) • approx \(formatTime(timeMinutes))
        """

        return SlicedPrintJob(
            capability: capability,
            summary: summary,
            warnings: warnings,
            estimatedPrintTimeMinutes: timeMinutes,
            estimatedFilamentGrams: grams,
            outputURL: nil
        )
    }

    private func formatTime(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours == 0 { return "\(mins) min" }
        if mins == 0 { return "\(hours) hr" }
        return "\(hours) hr \(mins) min"
    }
}
