//
//  DrawerModels.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI
import Combine

// MARK: - Normalized Quad (for capturing the measured drawer opening
// in normalized portrait-image coordinates so the overlay can be redrawn
// over the captured photo and scaled with manual adjustments).

struct NormalizedPoint: Codable, Equatable, Hashable {
    var x: Double   // 0..1 (left → right)
    var y: Double   // 0..1 (top → bottom)
}

struct NormalizedQuad: Codable, Equatable, Hashable {
    var topLeft: NormalizedPoint
    var topRight: NormalizedPoint
    var bottomLeft: NormalizedPoint
    var bottomRight: NormalizedPoint

    static let `default` = NormalizedQuad(
        topLeft: NormalizedPoint(x: 0.12, y: 0.28),
        topRight: NormalizedPoint(x: 0.88, y: 0.28),
        bottomLeft: NormalizedPoint(x: 0.12, y: 0.72),
        bottomRight: NormalizedPoint(x: 0.88, y: 0.72)
    )

    enum Corner: CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }

    var center: NormalizedPoint {
        NormalizedPoint(
            x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4,
            y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4
        )
    }

    func point(for corner: Corner) -> NormalizedPoint {
        switch corner {
        case .topLeft: return topLeft
        case .topRight: return topRight
        case .bottomLeft: return bottomLeft
        case .bottomRight: return bottomRight
        }
    }

    func cgPoint(for corner: Corner, in size: CGSize) -> CGPoint {
        let p = point(for: corner)
        return CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    /// EMA smoothing toward another quad. `alpha` 1.0 keeps current; 0.0 jumps to other.
    func eased(toward other: NormalizedQuad, alpha: Double) -> NormalizedQuad {
        func mix(_ a: NormalizedPoint, _ b: NormalizedPoint) -> NormalizedPoint {
            NormalizedPoint(x: a.x * alpha + b.x * (1 - alpha),
                            y: a.y * alpha + b.y * (1 - alpha))
        }
        return NormalizedQuad(
            topLeft: mix(topLeft, other.topLeft),
            topRight: mix(topRight, other.topRight),
            bottomLeft: mix(bottomLeft, other.bottomLeft),
            bottomRight: mix(bottomRight, other.bottomRight)
        )
    }

    /// Returns a quad whose width is scaled by `widthFactor` and height by
    /// `heightFactor` around its center (used to visually grow/shrink the
    /// overlay when the user adjusts dimension values).
    func scaled(widthFactor: Double, heightFactor: Double) -> NormalizedQuad {
        let c = center
        func transform(_ p: NormalizedPoint) -> NormalizedPoint {
            NormalizedPoint(x: c.x + (p.x - c.x) * widthFactor,
                            y: c.y + (p.y - c.y) * heightFactor)
        }
        return NormalizedQuad(
            topLeft: transform(topLeft),
            topRight: transform(topRight),
            bottomLeft: transform(bottomLeft),
            bottomRight: transform(bottomRight)
        )
    }

    /// Aspect ratio (width / height) — uses the average of the two horizontal
    /// edge lengths over the average of the two vertical edge lengths. This
    /// is image-space aspect, not physical; used purely for visual fitting.
    var aspectRatio: Double {
        let topLen = hypot(topRight.x - topLeft.x, topRight.y - topLeft.y)
        let bottomLen = hypot(bottomRight.x - bottomLeft.x, bottomRight.y - bottomLeft.y)
        let leftLen = hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y)
        let rightLen = hypot(bottomRight.x - topRight.x, bottomRight.y - topRight.y)
        let h = (topLen + bottomLen) / 2
        let v = (leftLen + rightLen) / 2
        guard v > 0 else { return 1 }
        return h / v
    }

    /// Whether all four corners lie within (-0.05, 1.05) — i.e. quad isn't crazy.
    var isValid: Bool {
        let pts = [topLeft, topRight, bottomLeft, bottomRight]
        for p in pts {
            if !p.x.isFinite || !p.y.isFinite { return false }
            if p.x < -0.05 || p.x > 1.05 || p.y < -0.05 || p.y > 1.05 { return false }
        }
        let topLen = hypot(topRight.x - topLeft.x, topRight.y - topLeft.y)
        let leftLen = hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y)
        return topLen > 0.05 && leftLen > 0.05
    }
}

// MARK: - Measurement Source

enum MeasurementSource: String, Codable, Equatable {
    case lidar              // Real LiDAR depth scan
    case cameraReference    // Vision + reference object (credit card)
    case cameraEstimate     // Vision rectangle without scale reference
    case manual             // User entered/adjusted
    case defaultEstimate    // Fallback default values

    var displayName: String {
        switch self {
        case .lidar: return "LiDAR Measurement"
        case .cameraReference: return "Camera + Reference"
        case .cameraEstimate: return "Camera Estimate"
        case .manual: return "Manual Entry"
        case .defaultEstimate: return "Default Estimate"
        }
    }

    var icon: String {
        switch self {
        case .lidar: return "sensor.fill"
        case .cameraReference: return "creditcard.fill"
        case .cameraEstimate: return "camera.fill"
        case .manual: return "pencil.circle.fill"
        case .defaultEstimate: return "questionmark.circle.fill"
        }
    }

    var isMeasured: Bool {
        switch self {
        case .lidar, .cameraReference, .manual: return true
        case .cameraEstimate, .defaultEstimate: return false
        }
    }
}

// MARK: - Drawer Measurement

struct DrawerMeasurement: Codable, Equatable {
    var widthInches: Double
    var depthInches: Double
    var heightInches: Double
    var source: MeasurementSource
    var confidenceScore: Double // 0.0 – 1.0 — overall
    /// Whether height was actually measured (vs. defaulted/estimated).
    /// Width/depth confidence is captured by the overall confidenceScore.
    var heightMeasured: Bool

    /// Quad covering the drawer opening in the captured photo's normalized
    /// portrait coordinates, when available. Allows the review screen to
    /// redraw the live overlay over the photo and scale it with edits.
    var capturedQuad: NormalizedQuad?

    /// Width/depth as captured at the moment the photo was taken. The review
    /// screen uses these to compute scale factors when the user edits.
    var originalWidthInches: Double?
    var originalDepthInches: Double?

    var widthCm: Double { widthInches * 2.54 }
    var depthCm: Double { depthInches * 2.54 }
    var heightCm: Double { heightInches * 2.54 }

    var formattedWidth: String { String(format: "%.1f\"", widthInches) }
    var formattedDepth: String { String(format: "%.1f\"", depthInches) }
    var formattedHeight: String { String(format: "%.1f\"", heightInches) }

    /// Backward-compat alias used by older UI code.
    var usedLiDAR: Bool { source == .lidar }

    /// Width/depth scale factors from the original capture to current values.
    /// Used by the review overlay to grow/shrink the quad as the user edits.
    var widthScaleFactor: Double {
        guard let orig = originalWidthInches, orig > 0 else { return 1 }
        return max(0.2, min(3.0, widthInches / orig))
    }

    var depthScaleFactor: Double {
        guard let orig = originalDepthInches, orig > 0 else { return 1 }
        return max(0.2, min(3.0, depthInches / orig))
    }

    init(widthInches: Double,
         depthInches: Double,
         heightInches: Double,
         source: MeasurementSource,
         confidenceScore: Double,
         heightMeasured: Bool = false,
         capturedQuad: NormalizedQuad? = nil,
         originalWidthInches: Double? = nil,
         originalDepthInches: Double? = nil) {
        self.widthInches = widthInches
        self.depthInches = depthInches
        self.heightInches = heightInches
        self.source = source
        self.confidenceScore = confidenceScore
        self.heightMeasured = heightMeasured
        self.capturedQuad = capturedQuad
        self.originalWidthInches = originalWidthInches ?? widthInches
        self.originalDepthInches = originalDepthInches ?? depthInches
    }

    // Custom decoding so previously-saved drawers (which used `usedLiDAR`)
    // still load correctly.
    private enum CodingKeys: String, CodingKey {
        case widthInches, depthInches, heightInches
        case source, confidenceScore, heightMeasured
        case usedLiDAR
        case capturedQuad, originalWidthInches, originalDepthInches
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        widthInches = try c.decode(Double.self, forKey: .widthInches)
        depthInches = try c.decode(Double.self, forKey: .depthInches)
        heightInches = try c.decode(Double.self, forKey: .heightInches)
        confidenceScore = try c.decode(Double.self, forKey: .confidenceScore)
        heightMeasured = (try? c.decode(Bool.self, forKey: .heightMeasured)) ?? false
        capturedQuad = try? c.decode(NormalizedQuad.self, forKey: .capturedQuad)
        originalWidthInches = (try? c.decode(Double.self, forKey: .originalWidthInches)) ?? widthInches
        originalDepthInches = (try? c.decode(Double.self, forKey: .originalDepthInches)) ?? depthInches
        if let raw = try? c.decode(MeasurementSource.self, forKey: .source) {
            source = raw
        } else if let usedLiDAR = try? c.decode(Bool.self, forKey: .usedLiDAR) {
            source = usedLiDAR ? .lidar : .cameraEstimate
        } else {
            source = .defaultEstimate
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(widthInches, forKey: .widthInches)
        try c.encode(depthInches, forKey: .depthInches)
        try c.encode(heightInches, forKey: .heightInches)
        try c.encode(heightMeasured, forKey: .heightMeasured)
        try c.encode(source, forKey: .source)
        try c.encode(confidenceScore, forKey: .confidenceScore)
        try c.encode(source == .lidar, forKey: .usedLiDAR)
        try c.encodeIfPresent(capturedQuad, forKey: .capturedQuad)
        try c.encodeIfPresent(originalWidthInches, forKey: .originalWidthInches)
        try c.encodeIfPresent(originalDepthInches, forKey: .originalDepthInches)
    }
}

// MARK: - Drawer Purpose

enum DrawerPurpose: String, Codable, CaseIterable, Identifiable {
    case utensils = "Utensils"
    case junkDrawer = "Junk Drawer"
    case spices = "Spices"
    case bakingTools = "Baking Tools"
    case officeSupplies = "Office Supplies"
    case linens = "Linens"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .utensils: return "fork.knife"
        case .junkDrawer: return "archivebox.fill"
        case .spices: return "leaf.fill"
        case .bakingTools: return "birthday.cake.fill"
        case .officeSupplies: return "paperclip"
        case .linens: return "bed.double.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .utensils: return Color(hue: 0.08, saturation: 0.7, brightness: 0.95)
        case .junkDrawer: return Color(hue: 0.55, saturation: 0.6, brightness: 0.9)
        case .spices: return Color(hue: 0.35, saturation: 0.7, brightness: 0.85)
        case .bakingTools: return Color(hue: 0.95, saturation: 0.6, brightness: 0.95)
        case .officeSupplies: return Color(hue: 0.6, saturation: 0.5, brightness: 0.9)
        case .linens: return Color(hue: 0.75, saturation: 0.4, brightness: 0.9)
        case .custom: return Color(hue: 0.45, saturation: 0.5, brightness: 0.9)
        }
    }
    
    var description: String {
        switch self {
        case .utensils: return "Forks, knives, spoons, spatulas"
        case .junkDrawer: return "Batteries, tape, scissors, misc"
        case .spices: return "Spice jars, seasoning packets"
        case .bakingTools: return "Measuring cups, whisks, rollers"
        case .officeSupplies: return "Pens, clips, sticky notes, stapler"
        case .linens: return "Towels, napkins, placemats"
        case .custom: return "Define your own categories"
        }
    }
}

// MARK: - Organizer Item

struct OrganizerItem: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    var x: Double      // position in inches from left
    var y: Double      // position in inches from top
    var width: Double   // inches
    var height: Double  // inches
    var colorHue: Double
    var colorSaturation: Double
    var colorBrightness: Double
    
    init(name: String, x: Double, y: Double, width: Double, height: Double,
         hue: Double = 0.5, saturation: Double = 0.6, brightness: Double = 0.85) {
        self.id = UUID()
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.colorHue = hue
        self.colorSaturation = saturation
        self.colorBrightness = brightness
    }
    
    var color: Color {
        Color(hue: colorHue, saturation: colorSaturation, brightness: colorBrightness)
    }
}

// MARK: - Drawer Layout

struct DrawerLayout: Codable, Equatable {
    let measurement: DrawerMeasurement
    let purpose: DrawerPurpose
    var items: [OrganizerItem]
    var coveragePercentage: Double
    /// Names of organizer templates that didn't fit in the drawer.
    var unplacedTemplates: [String]
    /// Warnings to surface to the user (e.g. drawer too small for any item).
    var warnings: [String]
    /// IDs of templates the user explicitly selected — used by regenerate to
    /// keep their picks instead of using the full purpose catalog.
    var selectedTemplateIds: [String]

    var totalDrawerArea: Double {
        measurement.widthInches * measurement.depthInches
    }

    var usedArea: Double {
        items.reduce(0) { $0 + ($1.width * $1.height) }
    }

    init(measurement: DrawerMeasurement,
         purpose: DrawerPurpose,
         items: [OrganizerItem],
         coveragePercentage: Double,
         unplacedTemplates: [String] = [],
         warnings: [String] = [],
         selectedTemplateIds: [String] = []) {
        self.measurement = measurement
        self.purpose = purpose
        self.items = items
        self.coveragePercentage = coveragePercentage
        self.unplacedTemplates = unplacedTemplates
        self.warnings = warnings
        self.selectedTemplateIds = selectedTemplateIds
    }

    private enum CodingKeys: String, CodingKey {
        case measurement, purpose, items, coveragePercentage
        case unplacedTemplates, warnings, selectedTemplateIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        measurement = try c.decode(DrawerMeasurement.self, forKey: .measurement)
        purpose = try c.decode(DrawerPurpose.self, forKey: .purpose)
        items = try c.decode([OrganizerItem].self, forKey: .items)
        coveragePercentage = try c.decode(Double.self, forKey: .coveragePercentage)
        unplacedTemplates = (try? c.decode([String].self, forKey: .unplacedTemplates)) ?? []
        warnings = (try? c.decode([String].self, forKey: .warnings)) ?? []
        selectedTemplateIds = (try? c.decode([String].self, forKey: .selectedTemplateIds)) ?? []
    }
}

// MARK: - Saved Drawer

struct SavedDrawer: Identifiable, Codable {
    let id: UUID
    var name: String
    let date: Date
    let layout: DrawerLayout
    var photoData: Data?
    
    init(name: String, layout: DrawerLayout, photoData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.date = Date()
        self.layout = layout
        self.photoData = photoData
    }
}

// MARK: - Persistence

class DrawerStore: ObservableObject {
    @Published var savedDrawers: [SavedDrawer] = []
    
    private let key = "savedDrawers"
    
    init() {
        load()
    }
    
    func save(_ drawer: SavedDrawer) {
        savedDrawers.insert(drawer, at: 0)
        persist()
    }
    
    func delete(at offsets: IndexSet) {
        savedDrawers.remove(atOffsets: offsets)
        persist()
    }
    
    func delete(_ drawer: SavedDrawer) {
        savedDrawers.removeAll { $0.id == drawer.id }
        persist()
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(savedDrawers) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let drawers = try? JSONDecoder().decode([SavedDrawer].self, from: data) {
            savedDrawers = drawers
        }
    }
}
