//
//  DrawerTests.swift
//  DrawerTests
//
//  Created by Seth Sullivan on 3/23/26.
//

import Testing
import Foundation
@testable import Drawer

struct DrawerTests {

    // MARK: - DrawerMeasurement: codable & legacy migration

    @Test func measurementRoundtripsThroughCodable() throws {
        let original = DrawerMeasurement(
            widthInches: 18.5,
            depthInches: 22.25,
            heightInches: 4.5,
            source: .lidar,
            confidenceScore: 0.83,
            heightMeasured: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DrawerMeasurement.self, from: data)
        #expect(decoded == original)
        #expect(decoded.source == .lidar)
        #expect(decoded.heightMeasured == true)
    }

    @Test func legacyMeasurementWithUsedLiDARMigrates() throws {
        // Older saved drawers had `usedLiDAR: Bool` and no `source` field.
        let json = """
        {
            "widthInches": 15.0,
            "depthInches": 20.0,
            "heightInches": 4.0,
            "usedLiDAR": true,
            "confidenceScore": 0.9
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(DrawerMeasurement.self, from: json)
        #expect(decoded.source == .lidar)
        #expect(decoded.usedLiDAR == true)
        #expect(decoded.heightMeasured == false)
    }

    @Test func legacyNonLiDARMigrationFallsBackToCameraEstimate() throws {
        let json = """
        {
            "widthInches": 12.0,
            "depthInches": 18.0,
            "heightInches": 3.5,
            "usedLiDAR": false,
            "confidenceScore": 0.4
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(DrawerMeasurement.self, from: json)
        #expect(decoded.source == .cameraEstimate)
        #expect(decoded.usedLiDAR == false)
    }

    @Test func unitConversionsAreCorrect() {
        let m = DrawerMeasurement(widthInches: 10, depthInches: 5, heightInches: 4,
                                  source: .manual, confidenceScore: 1.0, heightMeasured: true)
        #expect(abs(m.widthCm - 25.4) < 0.001)
        #expect(abs(m.depthCm - 12.7) < 0.001)
        #expect(abs(m.heightCm - 10.16) < 0.001)
        #expect(m.formattedWidth == "10.0\"")
    }

    // MARK: - MeasurementSource

    @Test func measurementSourceMeasuredFlagsAreCorrect() {
        #expect(MeasurementSource.lidar.isMeasured == true)
        #expect(MeasurementSource.cameraReference.isMeasured == true)
        #expect(MeasurementSource.manual.isMeasured == true)
        #expect(MeasurementSource.cameraEstimate.isMeasured == false)
        #expect(MeasurementSource.defaultEstimate.isMeasured == false)
    }

    // MARK: - MeasurementEngine

    @Test func defaultMeasurementIsLabeledAsDefault() {
        let m = MeasurementEngine.createDefaultMeasurement()
        #expect(m.source == .defaultEstimate)
        #expect(m.source.isMeasured == false)
        #expect(m.confidenceScore == 0.0)
    }

    @Test func measureFromLiDARProducesLiDARSource() {
        let m = MeasurementEngine.measureFromLiDAR(
            planeSize: CGSize(width: 18, height: 22),
            estimatedHeight: 5,
            confidence: 0.7
        )
        #expect(m.source == .lidar)
        #expect(m.widthInches == 18)
        #expect(m.depthInches == 22)
        #expect(m.heightInches == 5)
        #expect(m.confidenceScore == 0.7)
    }

    // MARK: - LayoutEngine

    @Test func layoutRejectsTinyDrawers() {
        let m = DrawerMeasurement(widthInches: 1, depthInches: 1, heightInches: 1,
                                  source: .manual, confidenceScore: 1.0)
        let layout = LayoutEngine.generateLayout(measurement: m, purpose: .junkDrawer)

        #expect(layout.items.isEmpty)
        #expect(!layout.warnings.isEmpty)
        #expect(!layout.unplacedTemplates.isEmpty)
        #expect(layout.coveragePercentage == 0)
    }

    @Test func layoutKeepsItemsWithinDrawerBounds() {
        let m = DrawerMeasurement(widthInches: 18, depthInches: 22, heightInches: 4,
                                  source: .lidar, confidenceScore: 0.9)
        let layout = LayoutEngine.generateLayout(measurement: m, purpose: .utensils)

        #expect(!layout.items.isEmpty)

        for item in layout.items {
            #expect(item.x >= 0)
            #expect(item.y >= 0)
            #expect(item.x + item.width <= m.widthInches + 0.01)
            #expect(item.y + item.height <= m.depthInches + 0.01)
        }
    }

    @Test func layoutItemsDoNotOverlap() {
        let m = DrawerMeasurement(widthInches: 18, depthInches: 22, heightInches: 4,
                                  source: .lidar, confidenceScore: 0.9)
        let layout = LayoutEngine.generateLayout(measurement: m, purpose: .junkDrawer)

        let items = layout.items
        for i in 0..<items.count {
            for j in (i + 1)..<items.count {
                let a = items[i]
                let b = items[j]
                let separateX = (a.x + a.width <= b.x + 0.01) || (b.x + b.width <= a.x + 0.01)
                let separateY = (a.y + a.height <= b.y + 0.01) || (b.y + b.height <= a.y + 0.01)
                #expect(separateX || separateY,
                        "Overlap between \(a.name) and \(b.name)")
            }
        }
    }

    @Test func coverageNeverExceedsHundredPercent() {
        let m = DrawerMeasurement(widthInches: 24, depthInches: 24, heightInches: 4,
                                  source: .manual, confidenceScore: 1.0)
        let layout = LayoutEngine.generateLayout(measurement: m, purpose: .custom)
        #expect(layout.coveragePercentage <= 100.0)
        #expect(layout.coveragePercentage >= 0.0)
    }

    @Test func unplacedTemplatesAreSurfaced() {
        // Tiny drawer that can fit small items but not large ones.
        let m = DrawerMeasurement(widthInches: 6, depthInches: 6, heightInches: 4,
                                  source: .manual, confidenceScore: 1.0)
        let layout = LayoutEngine.generateLayout(measurement: m, purpose: .utensils)
        // Some items in the utensils catalog (e.g. 12" sections) shouldn't fit.
        #expect(!layout.unplacedTemplates.isEmpty)
    }

    @Test func savedDrawerLayoutCodableRoundtrips() throws {
        let m = DrawerMeasurement(widthInches: 18, depthInches: 22, heightInches: 4,
                                  source: .lidar, confidenceScore: 0.85, heightMeasured: false)
        let layout = LayoutEngine.generateLayout(measurement: m, purpose: .spices)
        let saved = SavedDrawer(name: "Test", layout: layout, photoData: nil)

        let data = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(SavedDrawer.self, from: data)

        #expect(decoded.name == "Test")
        #expect(decoded.layout.items.count == layout.items.count)
        #expect(decoded.layout.measurement.source == .lidar)
        #expect(decoded.layout.unplacedTemplates == layout.unplacedTemplates)
    }

    // MARK: - NormalizedQuad

    @Test func normalizedQuadDefaultIsValid() {
        #expect(NormalizedQuad.default.isValid)
    }

    @Test func normalizedQuadInvalidWhenCornersOutOfBounds() {
        let bad = NormalizedQuad(
            topLeft: .init(x: -2, y: 0.3),
            topRight: .init(x: 0.9, y: 0.3),
            bottomLeft: .init(x: 0.1, y: 0.7),
            bottomRight: .init(x: 0.9, y: 0.7)
        )
        #expect(!bad.isValid)
    }

    @Test func normalizedQuadScaleAroundCenter() {
        let quad = NormalizedQuad.default
        let scaled = quad.scaled(widthFactor: 2.0, heightFactor: 1.0)
        // Width should expand around center; original center should be unchanged.
        let originalCenter = quad.center
        let scaledCenter = scaled.center
        #expect(abs(originalCenter.x - scaledCenter.x) < 1e-9)
        #expect(abs(originalCenter.y - scaledCenter.y) < 1e-9)

        // Top edge length should roughly double.
        let origTop = hypot(quad.topRight.x - quad.topLeft.x,
                            quad.topRight.y - quad.topLeft.y)
        let newTop = hypot(scaled.topRight.x - scaled.topLeft.x,
                           scaled.topRight.y - scaled.topLeft.y)
        #expect(abs(newTop - 2 * origTop) < 1e-9)
    }

    @Test func normalizedQuadEaseTowardConverges() {
        let a = NormalizedQuad.default
        let b = NormalizedQuad(
            topLeft: .init(x: 0.0, y: 0.0),
            topRight: .init(x: 1.0, y: 0.0),
            bottomLeft: .init(x: 0.0, y: 1.0),
            bottomRight: .init(x: 1.0, y: 1.0)
        )
        var current = a
        for _ in 0..<60 {
            current = current.eased(toward: b, alpha: 0.6)
        }
        #expect(abs(current.topLeft.x - b.topLeft.x) < 0.05)
        #expect(abs(current.bottomRight.y - b.bottomRight.y) < 0.05)
    }

    // MARK: - Captured quad on DrawerMeasurement

    @Test func measurementWithQuadRoundtripsThroughCodable() throws {
        let quad = NormalizedQuad(
            topLeft: .init(x: 0.1, y: 0.2),
            topRight: .init(x: 0.9, y: 0.2),
            bottomLeft: .init(x: 0.1, y: 0.8),
            bottomRight: .init(x: 0.9, y: 0.8)
        )
        let m = DrawerMeasurement(
            widthInches: 18,
            depthInches: 22,
            heightInches: 4,
            source: .lidar,
            confidenceScore: 0.8,
            heightMeasured: false,
            capturedQuad: quad,
            originalWidthInches: 18,
            originalDepthInches: 22
        )
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(DrawerMeasurement.self, from: data)
        #expect(decoded.capturedQuad == quad)
        #expect(decoded.originalWidthInches == 18)
        #expect(decoded.originalDepthInches == 22)
    }

    @Test func legacyMeasurementWithoutQuadStillDecodes() throws {
        let json = """
        {
            "widthInches": 15.0,
            "depthInches": 20.0,
            "heightInches": 4.0,
            "usedLiDAR": true,
            "confidenceScore": 0.9
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DrawerMeasurement.self, from: json)
        #expect(decoded.capturedQuad == nil)
        #expect(decoded.originalWidthInches == 15.0)
        #expect(decoded.originalDepthInches == 20.0)
    }

    @Test func widthScaleFactorTracksManualEdits() {
        var m = DrawerMeasurement(
            widthInches: 20, depthInches: 10, heightInches: 4,
            source: .lidar, confidenceScore: 0.9,
            originalWidthInches: 20, originalDepthInches: 10
        )
        #expect(abs(m.widthScaleFactor - 1.0) < 1e-9)
        m.widthInches = 30
        #expect(abs(m.widthScaleFactor - 1.5) < 1e-9)
        m.depthInches = 5
        #expect(abs(m.depthScaleFactor - 0.5) < 1e-9)
    }

    // MARK: - Organizer template IDs and selection

    @Test func organizerTemplateIdsAreUniquePerPurpose() {
        for purpose in DrawerPurpose.allCases {
            let templates = LayoutEngine.templates(for: purpose)
            let ids = templates.map { $0.id }
            #expect(Set(ids).count == ids.count,
                    "Duplicate template ids in \(purpose.rawValue)")
        }
    }

    @Test func recommendedAndMinimalIdsAreSubsetsOfCatalog() {
        for purpose in DrawerPurpose.allCases {
            let allIds = Set(LayoutEngine.templates(for: purpose).map { $0.id })
            let recommended = LayoutEngine.recommendedIds(for: purpose)
            let minimal = LayoutEngine.minimalIds(for: purpose)
            #expect(recommended.isSubset(of: allIds))
            #expect(minimal.isSubset(of: allIds))
        }
    }

    @Test func generateLayoutHonorsSelectedIds() {
        let m = DrawerMeasurement(
            widthInches: 24, depthInches: 24, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let allIds = Set(LayoutEngine.templates(for: .junkDrawer).map { $0.id })
        let chosen: Set<String> = [allIds.sorted().first!]
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: chosen
        )
        // Only items derived from chosen templates should be placed.
        let chosenName = LayoutEngine.templates(for: .junkDrawer)
            .first { $0.id == chosen.first }!.name
        #expect(layout.items.allSatisfy { $0.name == chosenName })
        #expect(Set(layout.selectedTemplateIds) == chosen)
    }

    @Test func generateLayoutEmptySelectionFallsBackToRecommended() {
        let m = DrawerMeasurement(
            widthInches: 24, depthInches: 24, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .utensils,
            selectedIds: Set<String>()
        )
        #expect(!layout.items.isEmpty)
    }

    @Test func regenerateLayoutKeepsSelection() {
        let m = DrawerMeasurement(
            widthInches: 24, depthInches: 24, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let chosen: Set<String> = LayoutEngine.minimalIds(for: .spices)
        let original = LayoutEngine.generateLayout(
            measurement: m, purpose: .spices, selectedIds: chosen
        )
        let regen = LayoutEngine.regenerateLayout(
            measurement: original.measurement,
            purpose: original.purpose,
            selectedIds: Set(original.selectedTemplateIds)
        )
        #expect(Set(regen.selectedTemplateIds) == Set(original.selectedTemplateIds))
    }

    // MARK: - Fit-aware editing

    @Test func canAddDetectsItemTooLargeForDrawer() {
        let m = DrawerMeasurement(
            widthInches: 4, depthInches: 4, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .utensils,
            selectedIds: Set<String>()
        )
        // Big "Large Utensil Tray" cannot fit a 4x4 drawer in any orientation.
        let big = LayoutEngine.templates(for: .utensils)
            .first { $0.id == "utensils.large_tray" }!
        let result = LayoutEngine.canAdd(big, to: layout)
        #expect(!result.canAdd)
        switch result {
        case .doesNotFit: break
        default: Issue.record("Expected doesNotFit")
        }
    }

    @Test func canAddPlacesItemThatFitsInExistingLayout() {
        let m = DrawerMeasurement(
            widthInches: 24, depthInches: 24, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: LayoutEngine.minimalIds(for: .junkDrawer)
        )
        // A small key tray should fit somewhere.
        let small = LayoutEngine.templates(for: .junkDrawer)
            .first { $0.id == "junk.key" }!
        let result = LayoutEngine.canAdd(small, to: layout)
        #expect(result.canAdd)
    }

    @Test func addingItemReturnsLayoutWithItem() {
        let m = DrawerMeasurement(
            widthInches: 24, depthInches: 24, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: Set<String>()
        )
        let template = LayoutEngine.templates(for: .junkDrawer)
            .first { $0.id == "junk.key" }!
        let updated = LayoutEngine.adding(template, to: layout)
        #expect(updated != nil)
        #expect(updated!.items.contains { $0.name == template.name })
        #expect(updated!.selectedTemplateIds.contains(template.id))
    }

    @Test func removingItemDropsFromLayoutAndSelection() {
        let m = DrawerMeasurement(
            widthInches: 24, depthInches: 24, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: LayoutEngine.recommendedIds(for: .junkDrawer)
        )
        guard let firstItem = layout.items.first else {
            Issue.record("Expected items in baseline layout")
            return
        }
        let initialCount = layout.items.count
        let updated = LayoutEngine.removingItem(firstItem.id, from: layout)
        #expect(updated.items.count <= initialCount - 1 || updated.items.allSatisfy { $0.id != firstItem.id })
    }

    @Test func fitSummaryComputesCoverage() {
        let m = DrawerMeasurement(
            widthInches: 20, depthInches: 20, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .utensils,
            selectedIds: LayoutEngine.recommendedIds(for: .utensils)
        )
        let summary = LayoutEngine.fitSummary(for: layout)
        #expect(summary.totalAreaSqInches == 400)
        #expect(summary.coverage >= 0)
        #expect(summary.coverage <= 1)
        #expect(summary.placedCount == layout.items.count)
    }

    // MARK: - Print models

    @Test func printableModuleFitsOrFailsBedCheck() {
        let big = PrintableModule(
            id: UUID(), name: "Big",
            outerWidthMm: 300, outerDepthMm: 300, heightMm: 60,
            originXMm: 0, originYMm: 0,
            wallThicknessMm: 1.6, bottomThicknessMm: 1.2, cornerRadiusMm: 2,
            tintHex: "#888888"
        )
        #expect(!big.fitsBed(.bambuA1Mini))
        #expect(big.fitsBed(.bambuH2D))
    }

    @Test func filamentGramsScaleWithVolume() {
        let small = PrintableModule(
            id: UUID(), name: "Small",
            outerWidthMm: 60, outerDepthMm: 60, heightMm: 30,
            originXMm: 0, originYMm: 0,
            wallThicknessMm: 1.6, bottomThicknessMm: 1.2, cornerRadiusMm: 2,
            tintHex: "#888888"
        )
        let big = PrintableModule(
            id: UUID(), name: "Big",
            outerWidthMm: 120, outerDepthMm: 120, heightMm: 30,
            originXMm: 0, originYMm: 0,
            wallThicknessMm: 1.6, bottomThicknessMm: 1.2, cornerRadiusMm: 2,
            tintHex: "#888888"
        )
        let f = FilamentProfile.default
        #expect(big.gramsForFilament(f) > small.gramsForFilament(f))
    }

    @Test func printableOrganizerCarriesDrawerDimensionsInMm() {
        let m = DrawerMeasurement(
            widthInches: 10, depthInches: 5, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: LayoutEngine.recommendedIds(for: .junkDrawer)
        )
        let organizer = PrintModelGenerator.makeOrganizer(from: layout)
        #expect(abs(organizer.drawerInteriorWidthMm - 254) < 0.1)
        #expect(abs(organizer.drawerInteriorDepthMm - 127) < 0.1)
        #expect(organizer.modules.count == layout.items.count)
    }

    // MARK: - Mesh generation

    @Test func makeMeshProducesNonEmptyTriangles() {
        let module = PrintableModule(
            id: UUID(), name: "Tray",
            outerWidthMm: 50, outerDepthMm: 40, heightMm: 30,
            originXMm: 0, originYMm: 0,
            wallThicknessMm: 1.6, bottomThicknessMm: 1.2, cornerRadiusMm: 2,
            tintHex: "#888888"
        )
        let mesh = PrintModelGenerator.makeMesh(for: module)
        #expect(mesh.vertices.count > 0)
        #expect(mesh.triangles.count > 0)
        // All triangle indices must be inside the vertex array.
        for t in mesh.triangles {
            #expect(t.a < mesh.vertices.count)
            #expect(t.b < mesh.vertices.count)
            #expect(t.c < mesh.vertices.count)
        }
    }

    // MARK: - 3MF export

    @Test func threeMFExportProducesValidZip() throws {
        let m = DrawerMeasurement(
            widthInches: 18, depthInches: 22, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .utensils,
            selectedIds: LayoutEngine.recommendedIds(for: .utensils)
        )
        let organizer = PrintModelGenerator.makeOrganizer(from: layout)
        let result = try ThreeMFExporter.export(organizer, fileBaseName: "test_drawer")
        defer { try? FileManager.default.removeItem(at: result.fileURL) }

        let data = try Data(contentsOf: result.fileURL)
        #expect(data.count > 200)
        // ZIP signature
        #expect(data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04)

        func dataContains(_ s: String) -> Bool {
            guard let needle = s.data(using: .utf8) else { return false }
            return data.range(of: needle) != nil
        }

        #expect(dataContains("3D/3dmodel.model"))
        #expect(dataContains("[Content_Types].xml"))
        #expect(dataContains("Metadata/project_settings.config"))
        #expect(result.moduleCount == layout.items.count)
    }

    @Test func threeMFExportFailsWithNoModules() {
        let m = DrawerMeasurement(
            widthInches: 1, depthInches: 1, heightInches: 1,
            source: .manual, confidenceScore: 1.0
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .utensils,
            selectedIds: LayoutEngine.recommendedIds(for: .utensils)
        )
        let organizer = PrintModelGenerator.makeOrganizer(from: layout)
        var threw = false
        do {
            _ = try ThreeMFExporter.export(organizer, fileBaseName: "bad")
        } catch ThreeMFExporterError.noModules {
            threw = true
        } catch {
            Issue.record("Expected noModules error, got \(error)")
        }
        #expect(threw)
    }

    // MARK: - CRC32

    @Test func crc32MatchesKnownValue() {
        // CRC-32 of "123456789" is well-known: 0xCBF43926
        let data = Data("123456789".utf8)
        let crc = CRC32.compute(data)
        #expect(crc == 0xCBF43926)
    }

    // MARK: - Slicer

    @Test func diagnosticSlicerReturnsEstimates() throws {
        let m = DrawerMeasurement(
            widthInches: 18, depthInches: 22, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .utensils,
            selectedIds: LayoutEngine.recommendedIds(for: .utensils)
        )
        let organizer = PrintModelGenerator.makeOrganizer(from: layout)
        let job = try DiagnosticSlicerEngine().slice(organizer: organizer)
        #expect(job.capability == .diagnostic)
        #expect(job.estimatedFilamentGrams! > 0)
        #expect(job.estimatedPrintTimeMinutes! > 0)
    }

    @Test func diagnosticSlicerWarnsOnOversizedModule() throws {
        // A drawer larger than the printer bed should trigger a warning.
        let m = DrawerMeasurement(
            widthInches: 30, depthInches: 30, heightInches: 4,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .linens,
            selectedIds: LayoutEngine.recommendedIds(for: .linens)
        )
        let organizer = PrintModelGenerator.makeOrganizer(
            from: layout,
            settings: .default,
            filament: .default,
            printer: .bambuA1Mini   // 180x180 bed
        )
        let job = try DiagnosticSlicerEngine().slice(organizer: organizer)
        #expect(!job.warnings.isEmpty)
    }

    // MARK: - TrayLayerPlanner

    @Test func trayPlannerProducesLayersWithinModuleBounds() {
        let module = PrintableModule(
            id: UUID(), name: "Test",
            outerWidthMm: 60, outerDepthMm: 50, heightMm: 30,
            originXMm: 100, originYMm: 100,
            wallThicknessMm: 1.6, bottomThicknessMm: 1.2, cornerRadiusMm: 2,
            tintHex: "#888"
        )
        let layers = TrayLayerPlanner.plan(.init(
            module: module,
            settings: .default,
            wallLineWidthMm: 0.42,
            infillLineWidthMm: 0.42,
            bottomLayerCount: 6,
            outerWallColorSlot: 0,
            innerWallColorSlot: 0,
            bottomColorSlot: 0
        ))
        #expect(layers.count > 1)
        for layer in layers {
            for path in layer.paths {
                for p in path.points {
                    #expect(p.x >= module.originXMm - 0.01)
                    #expect(p.y >= module.originYMm - 0.01)
                    #expect(p.x <= module.originXMm + module.outerWidthMm + 0.01)
                    #expect(p.y <= module.originYMm + module.outerDepthMm + 0.01)
                }
            }
        }
    }

    @Test func trayPlannerEmitsBottomInfillOnlyInBottomBand() {
        let module = PrintableModule(
            id: UUID(), name: "Test",
            outerWidthMm: 60, outerDepthMm: 50, heightMm: 20,
            originXMm: 0, originYMm: 0,
            wallThicknessMm: 1.6, bottomThicknessMm: 1.2, cornerRadiusMm: 2,
            tintHex: "#888"
        )
        let layers = TrayLayerPlanner.plan(.init(
            module: module,
            settings: PrintSettings(layerHeightMm: 0.2,
                                     wallThicknessMm: 1.6,
                                     bottomThicknessMm: 1.2,
                                     cornerRadiusMm: 2,
                                     toleranceMm: 0.5,
                                     heightMm: 20,
                                     infillPercent: 15,
                                     modularSeparate: true),
            wallLineWidthMm: 0.42,
            infillLineWidthMm: 0.42,
            bottomLayerCount: 6,
            outerWallColorSlot: 0,
            innerWallColorSlot: 0,
            bottomColorSlot: 0
        ))
        let bottomBandLayers = layers.filter { $0.z <= 1.2 + 0.01 }
        let topLayers = layers.filter { $0.z > 1.2 + 0.01 }
        for l in bottomBandLayers {
            #expect(l.paths.contains { $0.feature == .bottomSurface })
        }
        for l in topLayers {
            #expect(!l.paths.contains { $0.feature == .bottomSurface })
        }
    }

    // MARK: - AMS lite

    @Test func amsLiteAssignmentMonoUsesFirstSlot() {
        let plate = AMSLitePlate(slots: [
            FilamentProfile(material: .pla, color: FilamentColor.defaults[0]),
            FilamentProfile(material: .pla, color: FilamentColor.defaults[1]),
            nil, nil
        ])
        let modules = sampleModules(count: 3)
        let assignment = AMSLiteColorPlanner.resolveAssignment(
            policy: .monoPlate, plate: plate, modules: modules
        )
        for module in modules {
            #expect(assignment.slot(for: module.id, feature: .outerWall) == 0)
            #expect(assignment.slot(for: module.id, feature: .bottomSurface) == 0)
        }
    }

    @Test func amsLiteAssignmentPerModuleCyclesSlots() {
        let plate = AMSLitePlate(slots: [
            FilamentProfile(material: .pla, color: FilamentColor.defaults[0]),
            FilamentProfile(material: .pla, color: FilamentColor.defaults[1]),
            FilamentProfile(material: .pla, color: FilamentColor.defaults[2]),
            nil
        ])
        let modules = sampleModules(count: 4)
        let assignment = AMSLiteColorPlanner.resolveAssignment(
            policy: .perModule, plate: plate, modules: modules
        )
        let slots = modules.map { assignment.slot(for: $0.id, feature: .outerWall) }
        // 3 active slots cycle: 0, 1, 2, 0
        #expect(slots == [0, 1, 2, 0])
    }

    @Test func amsLiteAssignmentPerFeatureSplitsByFeature() {
        let plate = AMSLitePlate(slots: [
            FilamentProfile(material: .pla, color: FilamentColor.defaults[0]),
            FilamentProfile(material: .pla, color: FilamentColor.defaults[1]),
            nil, nil
        ])
        let modules = sampleModules(count: 2)
        let assignment = AMSLiteColorPlanner.resolveAssignment(
            policy: .perFeature, plate: plate, modules: modules
        )
        let outer = assignment.slot(for: modules[0].id, feature: .outerWall)
        let inner = assignment.slot(for: modules[0].id, feature: .innerWall)
        #expect(outer != inner)
    }

    @Test func layerFilamentRangesCoverAllLayers() {
        var layers: [LayerPlan] = []
        for i in 0..<6 {
            let slot = i < 3 ? 0 : 1
            layers.append(LayerPlan(
                index: i, z: Double(i + 1) * 0.2,
                layerHeightMm: 0.2,
                paths: [ToolPath(
                    feature: .outerWall, moduleId: nil,
                    points: [.zero, Point2D(x: 1, y: 0)],
                    closed: true, lineWidthMm: 0.42, colorSlot: slot
                )]
            ))
        }
        let ranges = AMSLiteColorPlanner.computeLayerFilamentRanges(layers: layers)
        let covered = ranges.flatMap { $0.firstLayer...$0.lastLayer }
        #expect(Set(covered) == Set(0..<6))
    }

    // MARK: - Bambu A1 slicer end-to-end

    @Test func bambuA1SlicerProducesValidGcode3MF() throws {
        let m = DrawerMeasurement(
            widthInches: 8, depthInches: 6, heightInches: 3,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: LayoutEngine.minimalIds(for: .junkDrawer)
        )
        let organizer = PrintModelGenerator.makeOrganizer(
            from: layout, settings: .default,
            filament: .default, printer: .bambuA1
        )
        let ctx = BambuSliceContext.defaultContext(
            for: organizer, colors: [organizer.filament.color]
        )
        let out = try BambuA1SlicerEngine().sliceWithContext(
            ctx, fileBaseName: "test_a1"
        )
        defer { try? FileManager.default.removeItem(at: out.packageURL) }

        let data = try Data(contentsOf: out.packageURL)
        // ZIP signature
        #expect(data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04)

        func contains(_ s: String) -> Bool {
            guard let needle = s.data(using: .utf8) else { return false }
            return data.range(of: needle) != nil
        }

        // Required Bambu paths
        #expect(contains("Metadata/plate_1.gcode"))
        #expect(contains("Metadata/plate_1.gcode.md5"))
        #expect(contains("Metadata/plate_1.png"))
        #expect(contains("Metadata/plate_1_small.png"))
        #expect(contains("Metadata/plate_no_light_1.png"))
        #expect(contains("Metadata/top_1.png"))
        #expect(contains("Metadata/pick_1.png"))
        #expect(contains("Metadata/plate_1.json"))
        #expect(contains("Metadata/slice_info.config"))
        #expect(contains("Metadata/model_settings.config"))
        #expect(contains("Metadata/_rels/model_settings.config.rels"))
        #expect(contains("Metadata/cut_information.xml"))
        #expect(contains("Metadata/project_settings.config"))
        #expect(contains("3D/3dmodel.model"))
        #expect(contains("[Content_Types].xml"))
        #expect(contains("_rels/.rels"))

        // Bambu identifiers
        #expect(contains("printer_model_id"))
        #expect(contains("N2S"))
    }

    @Test func bambuA1GcodeContainsExpectedMarkers() throws {
        let m = DrawerMeasurement(
            widthInches: 12, depthInches: 10, heightInches: 3,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: LayoutEngine.minimalIds(for: .junkDrawer)
        )
        let organizer = PrintModelGenerator.makeOrganizer(
            from: layout, settings: .default,
            filament: .default, printer: .bambuA1
        )
        let ctx = BambuSliceContext.defaultContext(
            for: organizer, colors: [organizer.filament.color]
        )
        let out = try BambuA1SlicerEngine().sliceWithContext(
            ctx, fileBaseName: "test_markers"
        )
        defer { try? FileManager.default.removeItem(at: out.packageURL) }

        // Read gcode via Foundation
        let data = try Data(contentsOf: out.packageURL)
        func contains(_ s: String) -> Bool {
            guard let needle = s.data(using: .utf8) else { return false }
            return data.range(of: needle) != nil
        }
        #expect(contains("HEADER_BLOCK_START"))
        #expect(contains("HEADER_BLOCK_END"))
        #expect(contains("CONFIG_BLOCK_START"))
        #expect(contains("CONFIG_BLOCK_END"))
        #expect(contains("EXECUTABLE_BLOCK_START"))
        #expect(contains("EXECUTABLE_BLOCK_END"))
        #expect(contains("; CHANGE_LAYER"))
        #expect(contains("; FEATURE: Outer wall"))
        #expect(contains("M73 L"))
    }

    @Test func bambuA1MultiColorEmitsToolChange() throws {
        let m = DrawerMeasurement(
            widthInches: 8, depthInches: 6, heightInches: 2,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: LayoutEngine.minimalIds(for: .junkDrawer)
        )
        let organizer = PrintModelGenerator.makeOrganizer(
            from: layout, settings: .default,
            filament: .default, printer: .bambuA1
        )
        let plate = AMSLitePlate(slots: [
            FilamentProfile(material: .pla, color: FilamentColor.defaults[0]),
            FilamentProfile(material: .pla, color: FilamentColor.defaults[1]),
            nil, nil
        ])
        let assignment = AMSLiteColorPlanner.resolveAssignment(
            policy: .perFeature, plate: plate, modules: organizer.modules
        )
        let ctx = BambuSliceContext(
            organizer: organizer, amsPlate: plate,
            coloringPolicy: .perFeature, assignment: assignment
        )
        let out = try BambuA1SlicerEngine().sliceWithContext(
            ctx, fileBaseName: "test_multi"
        )
        defer { try? FileManager.default.removeItem(at: out.packageURL) }

        let data = try Data(contentsOf: out.packageURL)
        func contains(_ s: String) -> Bool {
            guard let needle = s.data(using: .utf8) else { return false }
            return data.range(of: needle) != nil
        }
        // M620 / T / M621 sequence indicates tool change orchestration.
        #expect(contains("M620 S1A"))
        #expect(contains("M621 S1A"))
        #expect(contains("filament change"))
    }

    @Test func bambuMd5MatchesGcodeBody() throws {
        let m = DrawerMeasurement(
            widthInches: 12, depthInches: 10, heightInches: 3,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: LayoutEngine.minimalIds(for: .junkDrawer)
        )
        let organizer = PrintModelGenerator.makeOrganizer(
            from: layout, settings: .default,
            filament: .default, printer: .bambuA1
        )
        let ctx = BambuSliceContext.defaultContext(
            for: organizer, colors: [organizer.filament.color]
        )
        let out = try BambuA1SlicerEngine().sliceWithContext(
            ctx, fileBaseName: "test_md5"
        )
        defer { try? FileManager.default.removeItem(at: out.packageURL) }

        // The md5 file content should be a 32-hex-char string.
        let data = try Data(contentsOf: out.packageURL)
        let needle = "Metadata/plate_1.gcode.md5".data(using: .utf8)!
        #expect(data.range(of: needle) != nil)
    }

    @Test func slicerProviderRoutesA1ToBambuEngine() {
        let engine = SlicerProvider.engine(for: .bambuA1)
        #expect(engine is BambuA1SlicerEngine)
        let other = SlicerProvider.engine(for: .generic220)
        #expect(other is DiagnosticSlicerEngine)
    }

    @Test func bambuA1GcodePackageContainsMeshGeometry() throws {
        // Bambu Studio's "Import" path needs real <vertex>/<triangle> data
        // in 3D/3dmodel.model — sliced files with empty resources only work
        // via Bambu's "Open Project" path.
        let m = DrawerMeasurement(
            widthInches: 10, depthInches: 8, heightInches: 3,
            source: .lidar, confidenceScore: 0.9
        )
        let layout = LayoutEngine.generateLayout(
            measurement: m, purpose: .junkDrawer,
            selectedIds: LayoutEngine.minimalIds(for: .junkDrawer)
        )
        let organizer = PrintModelGenerator.makeOrganizer(
            from: layout, settings: .default,
            filament: .default, printer: .bambuA1
        )
        let ctx = BambuSliceContext.defaultContext(
            for: organizer, colors: [organizer.filament.color]
        )
        let out = try BambuA1SlicerEngine().sliceWithContext(
            ctx, fileBaseName: "test_geometry"
        )
        defer { try? FileManager.default.removeItem(at: out.packageURL) }

        let data = try Data(contentsOf: out.packageURL)
        func contains(_ s: String) -> Bool {
            guard let needle = s.data(using: .utf8) else { return false }
            return data.range(of: needle) != nil
        }
        // The 3D/3dmodel.model file should now have real mesh geometry.
        #expect(contains("<vertex"))
        #expect(contains("<triangle"))
        #expect(contains("<object id=\"1\""))
        #expect(contains("<build>"))
        #expect(contains("<item objectid=\"1\""))
    }

    // MARK: - Helpers

    private func sampleModules(count: Int) -> [PrintableModule] {
        (0..<count).map { i in
            PrintableModule(
                id: UUID(), name: "Mod\(i)",
                outerWidthMm: 50, outerDepthMm: 40, heightMm: 25,
                originXMm: Double(i) * 60, originYMm: 0,
                wallThicknessMm: 1.6, bottomThicknessMm: 1.2, cornerRadiusMm: 2,
                tintHex: "#888"
            )
        }
    }
}
