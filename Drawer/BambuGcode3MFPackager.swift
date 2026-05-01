//
//  BambuGcode3MFPackager.swift
//  Drawer
//
//  Assembles a Bambu A1 `.gcode.3mf` package using the existing ZipWriter.
//  Writes the canonical 16 files Bambu Studio expects.
//

import Foundation

enum BambuGcode3MFPackagerError: Error, LocalizedError {
    case noModules
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noModules: return "No modules to package."
        case .writeFailed(let m): return "3MF write failed: \(m)"
        }
    }
}

struct BambuGcode3MFInputs {
    let modules: [PrintableModule]
    let plate: AMSLitePlate
    let assignment: AMSLiteAssignment
    let drawerWidthMm: Double
    let drawerDepthMm: Double
    let gcodeBody: String
    let gcodeMd5: String
    let layerFilamentRanges: [LayerFilamentRange]
    let perSlotUsage: [Int: (lengthMm: Double, weightG: Double)]
    let totalWeightG: Double
    let predictionSeconds: Int
    let fileBaseName: String
}

enum BambuGcode3MFPackager {

    static func package(_ inputs: BambuGcode3MFInputs) throws -> PrintExportResult {
        guard !inputs.modules.isEmpty else { throw BambuGcode3MFPackagerError.noModules }

        // Render thumbnails
        let thumbs = BambuThumbnailRenderer.render(.init(
            modules: inputs.modules,
            plate: inputs.plate,
            assignment: inputs.assignment,
            drawerWidthMm: inputs.drawerWidthMm,
            drawerDepthMm: inputs.drawerDepthMm
        ))

        // Build XML/JSON metadata
        let contentTypes = BambuPackageMetadata.contentTypesXML()
        let rootRels = BambuPackageMetadata.packageRelsXML()
        // Populate geometry so Bambu Studio's "Import" path renders the trays
        // — Bambu's own sliced files are empty here but that only works for
        // their "Open Project" path; we want both import paths to work.
        let model3D = BambuPackageMetadata.populatedModelXML(modules: inputs.modules)
        let modelRels = BambuPackageMetadata.modelSettingsRelsXML()
        let modelSettings = BambuPackageMetadata.modelSettingsConfigXML()
        let cutInfo = BambuPackageMetadata.cutInformationXML()

        let sliceInfo = BambuPackageMetadata.sliceInfoConfigXML(.init(
            printerModelId: BambuA1Identifiers.printerModelId,
            nozzleDiameterMm: BambuA1Identifiers.nozzleDiameterMm,
            predictionSeconds: inputs.predictionSeconds,
            totalWeightG: inputs.totalWeightG,
            supportUsed: false,
            modules: inputs.modules,
            plate: inputs.plate,
            perSlotUsage: inputs.perSlotUsage,
            layerFilamentRanges: inputs.layerFilamentRanges
        ))

        let plateJSON = BambuPackageMetadata.plate1JSON(.init(
            modules: inputs.modules,
            plate: inputs.plate,
            nozzleDiameterMm: BambuA1Identifiers.nozzleDiameterMm,
            bedType: BambuA1Identifiers.bedTypeShort
        ))

        // Compose entries in canonical Bambu order.
        let entries: [(name: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("Metadata/plate_1.png", thumbs.plateLarge),
            ("Metadata/plate_1_small.png", thumbs.plateSmall),
            ("Metadata/plate_no_light_1.png", thumbs.plateNoLight),
            ("Metadata/top_1.png", thumbs.top),
            ("Metadata/pick_1.png", thumbs.pick),
            ("Metadata/plate_1.json", Data(plateJSON.utf8)),
            ("3D/3dmodel.model", Data(model3D.utf8)),
            ("Metadata/project_settings.config", Data(buildProjectSettings(inputs).utf8)),
            ("Metadata/plate_1.gcode.md5", Data(inputs.gcodeMd5.utf8)),
            ("Metadata/plate_1.gcode", Data(inputs.gcodeBody.utf8)),
            ("Metadata/_rels/model_settings.config.rels", Data(modelRels.utf8)),
            ("Metadata/model_settings.config", Data(modelSettings.utf8)),
            ("Metadata/cut_information.xml", Data(cutInfo.utf8)),
            ("Metadata/slice_info.config", Data(sliceInfo.utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
        ]

        let archive = ZipWriter.write(entries: entries)

        let tempDir = FileManager.default.temporaryDirectory
        let safeName = sanitize(fileName: inputs.fileBaseName)
        let url = tempDir
            .appendingPathComponent(safeName)
            .appendingPathExtension("gcode.3mf")
        do {
            try archive.write(to: url, options: .atomic)
        } catch {
            throw BambuGcode3MFPackagerError.writeFailed(error.localizedDescription)
        }

        return PrintExportResult(
            fileURL: url,
            format: .threeMF,
            moduleCount: inputs.modules.count,
            sizeBytes: archive.count
        )
    }

    // MARK: - Project settings

    /// A pruned version of Bambu's project_settings.config — much smaller than
    /// the reference file but large enough for Bambu Studio to recognize the
    /// printer/material context.
    private static func buildProjectSettings(_ inputs: BambuGcode3MFInputs) -> String {
        let primary = inputs.plate.activeFilaments.first?.profile ?? .default
        let entry = BambuFilamentCatalog.entry(for: primary.material)
        let allFilaments = inputs.plate.activeFilaments
        let colorList = allFilaments.map { $0.profile.color.hex }.joined(separator: ";")
        let trayList = allFilaments.map { BambuFilamentCatalog.entry(for: $0.profile.material).trayInfoIdx }.joined(separator: ";")
        let typeList = allFilaments.map { BambuFilamentCatalog.entry(for: $0.profile.material).typeName }.joined(separator: ";")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <project_settings>
          <printer>\(BambuA1Identifiers.printerName)</printer>
          <printer_id>\(BambuA1Identifiers.printerModelId)</printer_id>
          <bed_type>\(BambuA1Identifiers.bedType)</bed_type>
          <bed_size_mm>256x256</bed_size_mm>
          <bambu_compatible>true</bambu_compatible>
          <print_profile>\(BambuA1Identifiers.defaultPrintProfile)</print_profile>
          <filament_profile>\(entry.bambuProfileName)</filament_profile>
          <filament_ids>\(trayList)</filament_ids>
          <filament_type>\(typeList)</filament_type>
          <filament_colour>\(colorList)</filament_colour>
          <filament_count>\(allFilaments.count)</filament_count>
          <ams_lite_enabled>\(allFilaments.count > 1)</ams_lite_enabled>
          <slicer_app>Drawer Organizer for iOS</slicer_app>
          <slicer_version>\(BambuA1Identifiers.slicerVersion)</slicer_version>
        </project_settings>
        """
    }

    private static func sanitize(fileName: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>| ").union(.whitespaces)
        let cleaned = fileName.unicodeScalars
            .map { invalid.contains($0) ? "_" : String($0) }
            .joined()
        return cleaned.isEmpty ? "drawer_organizer" : cleaned
    }
}
