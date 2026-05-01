//
//  ThreeMFExporter.swift
//  Drawer
//
//  Generates a Bambu-friendly 3MF package from a `PrintableOrganizer`.
//  The package is a small ZIP archive (STORE method, no compression) that
//  contains the OPC/3MF parts:
//    - [Content_Types].xml
//    - _rels/.rels
//    - 3D/3dmodel.model
//    - Metadata/project_settings.config (Bambu-style settings hint)
//    - Metadata/slice_info.config (basic info for Bambu Studio)
//
//  3MF spec: https://3mf.io/specification/
//

import Foundation

enum ThreeMFExporterError: Error, LocalizedError {
    case noModules
    case ioFailed(String)

    var errorDescription: String? {
        switch self {
        case .noModules: return "No printable modules to export."
        case .ioFailed(let m): return m
        }
    }
}

enum ThreeMFExporter {

    /// Build the 3MF package and write it to a temporary URL. Returns the
    /// file URL plus a small set of warnings (e.g. modules over bed size).
    static func export(_ organizer: PrintableOrganizer,
                        fileBaseName: String) throws -> PrintExportResult {
        guard !organizer.modules.isEmpty else { throw ThreeMFExporterError.noModules }

        let model = buildModelXML(organizer: organizer)
        let contentTypes = buildContentTypesXML()
        let rels = buildRelsXML()
        let projectSettings = buildProjectSettings(organizer: organizer)
        let sliceInfo = buildSliceInfo(organizer: organizer)

        let entries: [(name: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rels.utf8)),
            ("3D/3dmodel.model", Data(model.utf8)),
            ("Metadata/project_settings.config", Data(projectSettings.utf8)),
            ("Metadata/slice_info.config", Data(sliceInfo.utf8)),
        ]

        let archive = ZipWriter.write(entries: entries)

        let tempDir = FileManager.default.temporaryDirectory
        let safeName = sanitize(fileName: fileBaseName)
        let url = tempDir
            .appendingPathComponent(safeName)
            .appendingPathExtension(ExportFormat.threeMF.fileExtension)
        do {
            try archive.write(to: url, options: .atomic)
        } catch {
            throw ThreeMFExporterError.ioFailed(error.localizedDescription)
        }

        return PrintExportResult(
            fileURL: url,
            format: .threeMF,
            moduleCount: organizer.modules.count,
            sizeBytes: archive.count
        )
    }

    // MARK: - XML payloads

    private static func buildContentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
          <Default Extension="config" ContentType="application/vnd.ms-printing.printticket+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
        </Types>
        """
    }

    private static func buildRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rel0" Target="/3D/3dmodel.model" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
        </Relationships>
        """
    }

    private static func buildModelXML(organizer: PrintableOrganizer) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <model unit="millimeter" xml:lang="en-US"
               xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">
          <metadata name="Application">Drawer Organizer for iOS</metadata>
          <metadata name="DrawerWidthMm">\(format(organizer.drawerInteriorWidthMm))</metadata>
          <metadata name="DrawerDepthMm">\(format(organizer.drawerInteriorDepthMm))</metadata>
          <metadata name="DrawerHeightMm">\(format(organizer.drawerInteriorHeightMm))</metadata>
          <metadata name="Purpose">\(escape(organizer.purpose.rawValue))</metadata>
          <metadata name="FilamentMaterial">\(organizer.filament.material.displayName)</metadata>
          <metadata name="FilamentColor">\(escape(organizer.filament.color.name))</metadata>
          <metadata name="Printer">\(escape(organizer.printer.name))</metadata>

          <resources>

        """

        // Each module is its own object so it can be moved/separated in
        // Bambu Studio. Module ids start at 1.
        for (index, module) in organizer.modules.enumerated() {
            let objectId = index + 1
            let mesh = PrintModelGenerator.makeMesh(for: module)
            xml += buildObjectXML(objectId: objectId, name: module.name,
                                   mesh: mesh)
        }

        xml += "  </resources>\n  <build>\n"
        for (index, module) in organizer.modules.enumerated() {
            let objectId = index + 1
            // Translate each object into drawer space — Bambu Studio reads
            // the build transforms.
            let tx = module.originXMm
            let ty = module.originYMm
            xml += "    <item objectid=\"\(objectId)\" transform=\"1 0 0 0 1 0 0 0 1 \(format(tx)) \(format(ty)) 0\"/>\n"
        }
        xml += "  </build>\n</model>\n"
        return xml
    }

    private static func buildObjectXML(objectId: Int, name: String, mesh: Mesh) -> String {
        var s = "    <object id=\"\(objectId)\" type=\"model\" name=\"\(escape(name))\">\n"
        s += "      <mesh>\n        <vertices>\n"
        for v in mesh.vertices {
            s += "          <vertex x=\"\(format(v.x))\" y=\"\(format(v.y))\" z=\"\(format(v.z))\"/>\n"
        }
        s += "        </vertices>\n        <triangles>\n"
        for t in mesh.triangles {
            s += "          <triangle v1=\"\(t.a)\" v2=\"\(t.b)\" v3=\"\(t.c)\"/>\n"
        }
        s += "        </triangles>\n      </mesh>\n    </object>\n"
        return s
    }

    private static func buildProjectSettings(organizer: PrintableOrganizer) -> String {
        // Plain XML metadata — Bambu Studio reads its own project settings,
        // but this gives a clear hint for users opening the file in any
        // slicer or sharing it. Use the printer/material profile names.
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <project_settings>
          <printer>\(escape(organizer.printer.name))</printer>
          <printer_id>\(escape(organizer.printer.id))</printer_id>
          <bed_size_mm>\(format(organizer.printer.bedWidthMm))x\(format(organizer.printer.bedDepthMm))</bed_size_mm>
          <bambu_compatible>\(organizer.printer.isBambu ? "true" : "false")</bambu_compatible>
          <filament>\(organizer.filament.material.displayName)</filament>
          <filament_profile>\(escape(organizer.filament.material.bambuProfile))</filament_profile>
          <color_hex>\(escape(organizer.filament.color.hex))</color_hex>
          <layer_height>\(format(organizer.settings.layerHeightMm))</layer_height>
          <wall_thickness>\(format(organizer.settings.wallThicknessMm))</wall_thickness>
          <bottom_thickness>\(format(organizer.settings.bottomThicknessMm))</bottom_thickness>
          <infill_percent>\(format(organizer.settings.infillPercent))</infill_percent>
          <module_height>\(format(organizer.settings.heightMm))</module_height>
          <tolerance>\(format(organizer.settings.toleranceMm))</tolerance>
        </project_settings>
        """
    }

    private static func buildSliceInfo(organizer: PrintableOrganizer) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <slice_info>
          <module_count>\(organizer.modules.count)</module_count>
          <total_filament_g>\(format(organizer.totalGrams))</total_filament_g>
          <purpose>\(escape(organizer.purpose.rawValue))</purpose>
        </slice_info>
        """
    }

    private static func format(_ d: Double) -> String {
        String(format: "%.4f", d)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func sanitize(fileName: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>| ").union(.whitespaces)
        let cleaned = fileName.unicodeScalars
            .map { invalid.contains($0) ? "_" : String($0) }
            .joined()
        return cleaned.isEmpty ? "drawer_organizer" : cleaned
    }
}

// MARK: - Minimal ZIP Writer (STORE method)

/// Lightweight ZIP archive builder that produces a non-compressed (STORE)
/// archive containing UTF-8 named entries. Adequate for 3MF/OPC packages,
/// which permit STORE. Avoids any external dependencies.
enum ZipWriter {

    static func write(entries: [(name: String, data: Data)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()

        let modTime = msdosTime(for: Date())
        let modDate = msdosDate(for: Date())

        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let crc = CRC32.compute(entry.data)
            let localOffset = UInt32(archive.count)

            var header = Data()
            header.appendLE(UInt32(0x04034b50))            // local file signature
            header.appendLE(UInt16(20))                    // version needed
            header.appendLE(UInt16(0x0800))                // flags (UTF-8)
            header.appendLE(UInt16(0))                     // method (STORE)
            header.appendLE(UInt16(modTime))
            header.appendLE(UInt16(modDate))
            header.appendLE(UInt32(crc))
            header.appendLE(UInt32(entry.data.count))      // compressed size
            header.appendLE(UInt32(entry.data.count))      // uncompressed size
            header.appendLE(UInt16(nameData.count))
            header.appendLE(UInt16(0))                     // extra length
            header.append(nameData)

            archive.append(header)
            archive.append(entry.data)

            // Central directory entry
            var central = Data()
            central.appendLE(UInt32(0x02014b50))
            central.appendLE(UInt16(0x031E))               // version made by (Unix, 3.0)
            central.appendLE(UInt16(20))                   // version needed
            central.appendLE(UInt16(0x0800))               // flags
            central.appendLE(UInt16(0))                    // method
            central.appendLE(UInt16(modTime))
            central.appendLE(UInt16(modDate))
            central.appendLE(UInt32(crc))
            central.appendLE(UInt32(entry.data.count))
            central.appendLE(UInt32(entry.data.count))
            central.appendLE(UInt16(nameData.count))
            central.appendLE(UInt16(0))                    // extra
            central.appendLE(UInt16(0))                    // comment
            central.appendLE(UInt16(0))                    // disk number
            central.appendLE(UInt16(0))                    // internal attrs
            central.appendLE(UInt32(0))                    // external attrs
            central.appendLE(UInt32(localOffset))
            central.append(nameData)
            centralDirectory.append(central)
        }

        let centralOffset = UInt32(archive.count)
        let centralSize = UInt32(centralDirectory.count)

        archive.append(centralDirectory)

        // End of central directory record
        var eocd = Data()
        eocd.appendLE(UInt32(0x06054b50))
        eocd.appendLE(UInt16(0))                          // disk number
        eocd.appendLE(UInt16(0))                          // disk start
        eocd.appendLE(UInt16(entries.count))
        eocd.appendLE(UInt16(entries.count))
        eocd.appendLE(centralSize)
        eocd.appendLE(centralOffset)
        eocd.appendLE(UInt16(0))                          // comment length

        archive.append(eocd)
        return archive
    }

    private static func msdosTime(for date: Date) -> UInt16 {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let h = UInt16(comps.hour ?? 0) & 0x1F
        let m = UInt16(comps.minute ?? 0) & 0x3F
        let s = UInt16((comps.second ?? 0) / 2) & 0x1F
        return (h << 11) | (m << 5) | s
    }

    private static func msdosDate(for date: Date) -> UInt16 {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = UInt16(max(0, (comps.year ?? 1980) - 1980)) & 0x7F
        let mo = UInt16(comps.month ?? 1) & 0x0F
        let d = UInt16(comps.day ?? 1) & 0x1F
        return (y << 9) | (mo << 5) | d
    }
}

private extension Data {
    mutating func appendLE(_ v: UInt16) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
    mutating func appendLE(_ v: UInt32) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}

// MARK: - CRC-32

enum CRC32 {
    private static let table: [UInt32] = {
        var t = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            t[i] = c
        }
        return t
    }()

    static func compute(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[idx]
        }
        return crc ^ 0xFFFFFFFF
    }
}
