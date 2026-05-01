//
//  PrintModels.swift
//  Drawer
//
//  Domain models for the 3D print pipeline. Layouts in inches are converted
//  to printable modules in millimeters with tolerances, wall thickness, and
//  Bambu-friendly defaults.
//

import SwiftUI
import Foundation

// MARK: - Constants

enum PrintConstants {
    static let inchToMm: Double = 25.4
    static let defaultWallThicknessMm: Double = 1.6
    static let defaultBottomThicknessMm: Double = 1.2
    static let defaultCornerRadiusMm: Double = 2.0
    static let defaultTolerance: Double = 0.5  // mm clearance per side
}

// MARK: - Filament

enum FilamentMaterial: String, CaseIterable, Codable, Identifiable {
    case pla, petg, abs, asa, tpu

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pla: return "PLA"
        case .petg: return "PETG"
        case .abs: return "ABS"
        case .asa: return "ASA"
        case .tpu: return "TPU"
        }
    }

    /// g/cm³ — used for filament estimates.
    var density: Double {
        switch self {
        case .pla: return 1.24
        case .petg: return 1.27
        case .abs: return 1.04
        case .asa: return 1.07
        case .tpu: return 1.21
        }
    }

    /// Recommended Bambu print profile name (used in metadata only).
    var bambuProfile: String {
        switch self {
        case .pla: return "Bambu PLA Basic"
        case .petg: return "Bambu PETG Basic"
        case .abs: return "Bambu ABS"
        case .asa: return "Generic ASA"
        case .tpu: return "Bambu TPU 95A"
        }
    }
}

struct FilamentColor: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let hex: String   // "#RRGGBB"

    var swiftUIColor: Color { Color(hex: hex) }

    static let defaults: [FilamentColor] = [
        FilamentColor(id: "matte_black", name: "Matte Black", hex: "#1A1A1A"),
        FilamentColor(id: "cool_white", name: "Cool White", hex: "#F2F2F2"),
        FilamentColor(id: "stone_gray", name: "Stone Gray", hex: "#8E9094"),
        FilamentColor(id: "ocean_blue", name: "Ocean Blue", hex: "#0F4C81"),
        FilamentColor(id: "leaf_green", name: "Leaf Green", hex: "#3E8E41"),
        FilamentColor(id: "sunset_orange", name: "Sunset Orange", hex: "#E96B4A"),
        FilamentColor(id: "lavender", name: "Lavender", hex: "#9B7EDE"),
        FilamentColor(id: "ruby_red", name: "Ruby Red", hex: "#B0182C"),
    ]
}

struct FilamentProfile: Codable, Equatable, Hashable {
    var material: FilamentMaterial
    var color: FilamentColor

    static let `default` = FilamentProfile(
        material: .petg,
        color: FilamentColor.defaults[0]
    )
}

// MARK: - Printer

struct PrinterProfile: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    /// Bed size in millimeters (X, Y).
    let bedWidthMm: Double
    let bedDepthMm: Double
    /// Maximum print Z height.
    let bedHeightMm: Double
    /// Whether this profile is from Bambu — used to flag Bambu-specific
    /// features in export/UI.
    let isBambu: Bool

    static let bambuA1Mini = PrinterProfile(
        id: "bambu_a1_mini",
        name: "Bambu Lab A1 mini",
        bedWidthMm: 180, bedDepthMm: 180, bedHeightMm: 180,
        isBambu: true
    )
    static let bambuA1 = PrinterProfile(
        id: "bambu_a1",
        name: "Bambu Lab A1",
        bedWidthMm: 256, bedDepthMm: 256, bedHeightMm: 256,
        isBambu: true
    )
    static let bambuP1S = PrinterProfile(
        id: "bambu_p1s",
        name: "Bambu Lab P1S",
        bedWidthMm: 256, bedDepthMm: 256, bedHeightMm: 256,
        isBambu: true
    )
    static let bambuX1Carbon = PrinterProfile(
        id: "bambu_x1c",
        name: "Bambu Lab X1 Carbon",
        bedWidthMm: 256, bedDepthMm: 256, bedHeightMm: 256,
        isBambu: true
    )
    static let bambuH2D = PrinterProfile(
        id: "bambu_h2d",
        name: "Bambu Lab H2D",
        bedWidthMm: 350, bedDepthMm: 320, bedHeightMm: 325,
        isBambu: true
    )
    static let generic220 = PrinterProfile(
        id: "generic_220",
        name: "Generic 220 mm",
        bedWidthMm: 220, bedDepthMm: 220, bedHeightMm: 250,
        isBambu: false
    )

    static let all: [PrinterProfile] = [
        .bambuA1Mini, .bambuA1, .bambuP1S, .bambuX1Carbon, .bambuH2D, .generic220
    ]

    static let `default`: PrinterProfile = .bambuA1
}

// MARK: - Print Settings

struct PrintSettings: Codable, Equatable {
    var layerHeightMm: Double         // 0.08–0.32 typical
    var wallThicknessMm: Double       // perimeter wall total
    var bottomThicknessMm: Double
    var cornerRadiusMm: Double
    var toleranceMm: Double           // clearance from drawer wall, per side
    var heightMm: Double              // organizer module height
    var infillPercent: Double         // 0…100
    var modularSeparate: Bool         // true → export each module as separate object

    static let `default` = PrintSettings(
        layerHeightMm: 0.20,
        wallThicknessMm: PrintConstants.defaultWallThicknessMm,
        bottomThicknessMm: PrintConstants.defaultBottomThicknessMm,
        cornerRadiusMm: PrintConstants.defaultCornerRadiusMm,
        toleranceMm: PrintConstants.defaultTolerance,
        heightMm: 35.0,
        infillPercent: 15,
        modularSeparate: true
    )
}

// MARK: - Printable Module

/// A single printable tray/bin matching one organizer slot.
/// Coordinates are in mm. `originX/originY` is the module's location in
/// drawer space (left/top of the drawer floor). The module is a hollow box
/// with rounded corners, a closed bottom, and open top.
struct PrintableModule: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var name: String
    /// Outer module footprint in mm.
    var outerWidthMm: Double
    var outerDepthMm: Double
    var heightMm: Double
    /// Position in mm from drawer floor origin.
    var originXMm: Double
    var originYMm: Double
    var wallThicknessMm: Double
    var bottomThicknessMm: Double
    var cornerRadiusMm: Double
    /// Hex tint preserved from the layout.
    var tintHex: String

    var innerWidthMm: Double { max(0, outerWidthMm - 2 * wallThicknessMm) }
    var innerDepthMm: Double { max(0, outerDepthMm - 2 * wallThicknessMm) }

    /// Fits inside the printer's bed (in any orientation).
    func fitsBed(_ printer: PrinterProfile) -> Bool {
        let small = min(outerWidthMm, outerDepthMm)
        let large = max(outerWidthMm, outerDepthMm)
        let bedSmall = min(printer.bedWidthMm, printer.bedDepthMm)
        let bedLarge = max(printer.bedWidthMm, printer.bedDepthMm)
        return small <= bedSmall && large <= bedLarge && heightMm <= printer.bedHeightMm
    }

    /// Approximate filament use (very rough): wall surface area * thickness
    /// + bottom area * bottom thickness, in cm³.
    var approximateVolumeCm3: Double {
        let walls = 2 * (outerWidthMm + outerDepthMm) * heightMm * wallThicknessMm
        let bottom = outerWidthMm * outerDepthMm * bottomThicknessMm
        let mm3 = walls + bottom
        return mm3 / 1000.0
    }

    func gramsForFilament(_ filament: FilamentProfile,
                          infillPercent: Double = 15) -> Double {
        // Treat infill as a small fraction of inner volume.
        let cavityCm3 = (innerWidthMm * innerDepthMm
                         * max(0, heightMm - bottomThicknessMm)) / 1000.0
        let infillCm3 = cavityCm3 * (infillPercent / 100.0)
        let totalCm3 = approximateVolumeCm3 + infillCm3
        return totalCm3 * filament.material.density
    }
}

// MARK: - Printable Organizer

/// Aggregates printable modules and their settings for a layout.
struct PrintableOrganizer: Codable, Equatable {
    var modules: [PrintableModule]
    var drawerInteriorWidthMm: Double
    var drawerInteriorDepthMm: Double
    var drawerInteriorHeightMm: Double
    var settings: PrintSettings
    var filament: FilamentProfile
    var printer: PrinterProfile
    var purpose: DrawerPurpose

    var totalGrams: Double {
        modules.reduce(0) {
            $0 + $1.gramsForFilament(filament,
                                     infillPercent: settings.infillPercent)
        }
    }

    /// Modules that exceed the printer's bed; the export step will need to
    /// flag these to the user.
    func oversizedModules() -> [PrintableModule] {
        modules.filter { !$0.fitsBed(printer) }
    }
}

// MARK: - Export Format

enum ExportFormat: String, Codable, CaseIterable, Identifiable {
    case threeMF
    case stl

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .threeMF: return "3MF"
        case .stl: return "STL"
        }
    }

    var fileExtension: String {
        switch self {
        case .threeMF: return "3mf"
        case .stl: return "stl"
        }
    }
}

// MARK: - Export Result

struct PrintExportResult: Equatable {
    var fileURL: URL
    var format: ExportFormat
    var moduleCount: Int
    var sizeBytes: Int
}
