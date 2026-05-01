//
//  BambuPackageMetadata.swift
//  Drawer
//
//  Builders for the XML and JSON metadata files inside a Bambu A1
//  `.gcode.3mf` package. Output strings are the exact contents of files
//  inside the ZIP.
//

import Foundation

enum BambuPackageMetadata {

    // MARK: - [Content_Types].xml

    static func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
         <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
         <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
         <Default Extension="png" ContentType="image/png"/>
         <Default Extension="gcode" ContentType="text/x.gcode"/>
        </Types>
        """
    }

    // MARK: - _rels/.rels

    static func packageRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
         <Relationship Target="/3D/3dmodel.model" Id="rel-1" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
         <Relationship Target="/Metadata/plate_1.png" Id="rel-2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"/>
         <Relationship Target="/Metadata/plate_1.png" Id="rel-4" Type="http://schemas.bambulab.com/package/2021/cover-thumbnail-middle"/>
        <Relationship Target="/Metadata/plate_1_small.png" Id="rel-5" Type="http://schemas.bambulab.com/package/2021/cover-thumbnail-small"/>
        </Relationships>
        """
    }

    // MARK: - 3D/3dmodel.model

    /// Empty model — used only as a structural placeholder in tests; the
    /// real package writer populates geometry via `populatedModelXML(modules:)`.
    static func emptyModelXML(modificationDateISO: String = isoDate()) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:BambuStudio="http://schemas.bambulab.com/package/2021" xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06" requiredextensions="p">
         <metadata name="Application">Drawer Organizer iOS</metadata>
         <metadata name="BambuStudio:3mfVersion">1</metadata>
         <metadata name="Copyright"></metadata>
         <metadata name="CreationDate">\(modificationDateISO)</metadata>
         <metadata name="Description"></metadata>
         <metadata name="Designer">Drawer Organizer iOS</metadata>
         <metadata name="DesignerCover"></metadata>
         <metadata name="DesignerUserId"></metadata>
         <metadata name="License"></metadata>
         <metadata name="ModificationDate">\(modificationDateISO)</metadata>
         <metadata name="Origin"></metadata>
         <metadata name="Title"></metadata>
         <resources>
         </resources>
         <build/>
        </model>
        """
    }

    /// Real model XML containing one `<object>` per printable module with
    /// triangle mesh geometry, plus per-module `<build><item>` transforms
    /// placing each tray at its drawer-space position. Including geometry
    /// here means Bambu Studio's "Import" path sees the trays as proper
    /// objects (Bambu Studio's own sliced files leave this empty because
    /// they're opened as sliced projects, but writing the geometry costs
    /// nothing and lets the file open cleanly via either import path).
    static func populatedModelXML(modules: [PrintableModule],
                                   modificationDateISO: String = isoDate()) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:BambuStudio="http://schemas.bambulab.com/package/2021" xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06" requiredextensions="p">
         <metadata name="Application">Drawer Organizer iOS</metadata>
         <metadata name="BambuStudio:3mfVersion">1</metadata>
         <metadata name="Copyright"></metadata>
         <metadata name="CreationDate">\(modificationDateISO)</metadata>
         <metadata name="Description"></metadata>
         <metadata name="Designer">Drawer Organizer iOS</metadata>
         <metadata name="DesignerCover"></metadata>
         <metadata name="DesignerUserId"></metadata>
         <metadata name="License"></metadata>
         <metadata name="ModificationDate">\(modificationDateISO)</metadata>
         <metadata name="Origin"></metadata>
         <metadata name="Title"></metadata>
         <resources>

        """
        for (index, module) in modules.enumerated() {
            let objectId = index + 1
            let mesh = PrintModelGenerator.makeMesh(for: module)
            xml += buildObjectXML(objectId: objectId, name: module.name, mesh: mesh)
        }
        xml += "  </resources>\n  <build>\n"
        for (index, module) in modules.enumerated() {
            let objectId = index + 1
            let tx = module.originXMm
            let ty = module.originYMm
            xml += "    <item objectid=\"\(objectId)\" transform=\"1 0 0 0 1 0 0 0 1 \(format(tx, decimals: 4)) \(format(ty, decimals: 4)) 0\"/>\n"
        }
        xml += "  </build>\n</model>\n"
        return xml
    }

    private static func buildObjectXML(objectId: Int, name: String, mesh: Mesh) -> String {
        var s = "    <object id=\"\(objectId)\" type=\"model\" name=\"\(escape(name))\">\n"
        s += "      <mesh>\n        <vertices>\n"
        for v in mesh.vertices {
            s += "          <vertex x=\"\(format(v.x, decimals: 4))\" y=\"\(format(v.y, decimals: 4))\" z=\"\(format(v.z, decimals: 4))\"/>\n"
        }
        s += "        </vertices>\n        <triangles>\n"
        for t in mesh.triangles {
            s += "          <triangle v1=\"\(t.a)\" v2=\"\(t.b)\" v3=\"\(t.c)\"/>\n"
        }
        s += "        </triangles>\n      </mesh>\n    </object>\n"
        return s
    }

    // MARK: - Metadata/_rels/model_settings.config.rels

    static func modelSettingsRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
         <Relationship Target="/Metadata/plate_1.gcode" Id="rel-1" Type="http://schemas.bambulab.com/package/2021/gcode"/>
        </Relationships>
        """
    }

    // MARK: - Metadata/model_settings.config

    static func modelSettingsConfigXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <config>
          <plate>
            <metadata key="plater_id" value="1"/>
            <metadata key="plater_name" value=""/>
            <metadata key="locked" value="false"/>
            <metadata key="filament_map_mode" value="Auto For Flush"/>
            <metadata key="filament_maps" value="1"/>
            <metadata key="gcode_file" value="Metadata/plate_1.gcode"/>
            <metadata key="thumbnail_file" value="Metadata/plate_1.png"/>
            <metadata key="thumbnail_no_light_file" value="Metadata/plate_no_light_1.png"/>
            <metadata key="top_file" value="Metadata/top_1.png"/>
            <metadata key="pick_file" value="Metadata/pick_1.png"/>
            <metadata key="pattern_bbox_file" value="Metadata/plate_1.json"/>
          </plate>
        </config>
        """
    }

    // MARK: - Metadata/cut_information.xml (empty placeholder)

    static func cutInformationXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <objects/>
        """
    }

    // MARK: - Metadata/slice_info.config

    struct SliceInfoInputs {
        let printerModelId: String
        let nozzleDiameterMm: Double
        let predictionSeconds: Int
        let totalWeightG: Double
        let supportUsed: Bool
        let modules: [PrintableModule]
        let plate: AMSLitePlate
        let perSlotUsage: [Int: (lengthMm: Double, weightG: Double)]
        let layerFilamentRanges: [LayerFilamentRange]
    }

    static func sliceInfoConfigXML(_ inputs: SliceInfoInputs) -> String {
        var s = """
        <?xml version="1.0" encoding="UTF-8"?>
        <config>
          <header>
            <header_item key="X-BBL-Client-Type" value="slicer"/>
            <header_item key="X-BBL-Client-Version" value="\(BambuA1Identifiers.slicerVersion)"/>
          </header>
          <plate>
            <metadata key="index" value="1"/>
            <metadata key="extruder_type" value="0"/>
            <metadata key="nozzle_volume_type" value="0"/>
            <metadata key="printer_model_id" value="\(inputs.printerModelId)"/>
            <metadata key="nozzle_diameters" value="\(format(inputs.nozzleDiameterMm, decimals: 1))"/>
            <metadata key="timelapse_type" value="0"/>
            <metadata key="prediction" value="\(inputs.predictionSeconds)"/>
            <metadata key="weight" value="\(format(inputs.totalWeightG, decimals: 2))"/>
            <metadata key="outside" value="false"/>
            <metadata key="support_used" value="\(inputs.supportUsed ? "true" : "false")"/>
            <metadata key="label_object_enabled" value="false"/>
            <metadata key="filament_maps" value="1"/>
            <metadata key="limit_filament_maps" value="0"/>

        """
        for (i, module) in inputs.modules.enumerated() {
            let id = i + 1
            s += "    <object identify_id=\"\(id)\" name=\"\(escape(module.name)).stl\" skipped=\"false\" />\n"
        }
        for (slotIdx, profile) in inputs.plate.activeFilaments {
            let entry = BambuFilamentCatalog.entry(for: profile.material)
            let usage = inputs.perSlotUsage[slotIdx] ?? (lengthMm: 0, weightG: 0)
            s += """
                <filament id="\(slotIdx + 1)" tray_info_idx="\(entry.trayInfoIdx)" type="\(entry.typeName)" color="\(profile.color.hex)" used_m="\(format(usage.lengthMm / 1000.0, decimals: 2))" used_g="\(format(usage.weightG, decimals: 2))" />

            """
        }
        s += "    <layer_filament_lists>\n"
        for range in inputs.layerFilamentRanges {
            s += "      <layer_filament_list filament_list=\"\(range.filamentListString)\" layer_ranges=\"\(range.layerRangeString)\" />\n"
        }
        s += "    </layer_filament_lists>\n"
        s += "  </plate>\n</config>"
        return s
    }

    // MARK: - Metadata/plate_1.json

    struct PlateJSONInputs {
        let modules: [PrintableModule]
        let plate: AMSLitePlate
        let nozzleDiameterMm: Double
        let bedType: String
    }

    static func plate1JSON(_ inputs: PlateJSONInputs) -> String {
        let bbox = bbox(for: inputs.modules)
        let filamentColors = inputs.plate.activeFilaments.map { "\"\($0.profile.color.hex)\"" }.joined(separator: ",")
        let filamentIds = inputs.plate.activeFilaments.map { String($0.slot) }.joined(separator: ",")

        var bboxObjects: [String] = []
        for (i, module) in inputs.modules.enumerated() {
            let id = i + 1
            let area = module.outerWidthMm * module.outerDepthMm
            let mb = boundingBox(for: module)
            bboxObjects.append("""
            {"area":\(format(area, decimals: 4)),"bbox":[\(format(mb.minX, decimals: 4)),\(format(mb.minY, decimals: 4)),\(format(mb.maxX, decimals: 4)),\(format(mb.maxY, decimals: 4))],"id":\(id),"layer_height":0.20000000298023224,"name":"\(escape(module.name)).stl"}
            """)
        }

        return """
        {"bbox_all":[\(format(bbox.minX, decimals: 4)),\(format(bbox.minY, decimals: 4)),\(format(bbox.maxX, decimals: 4)),\(format(bbox.maxY, decimals: 4))],"bbox_objects":[\(bboxObjects.joined(separator: ","))],"bed_type":"\(inputs.bedType)","filament_colors":[\(filamentColors)],"filament_ids":[\(filamentIds)],"first_extruder":\(inputs.plate.activeFilaments.first?.slot ?? 0),"is_seq_print":false,"nozzle_diameter":\(format(inputs.nozzleDiameterMm, decimals: 4)),"version":2}
        """
    }

    // MARK: - Helpers

    private static func format(_ d: Double, decimals: Int = 3) -> String {
        String(format: "%.\(decimals)f", d)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func isoDate() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: Date())
    }

    private static func boundingBox(for module: PrintableModule) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        return (
            minX: module.originXMm,
            minY: module.originYMm,
            maxX: module.originXMm + module.outerWidthMm,
            maxY: module.originYMm + module.outerDepthMm
        )
    }

    private static func bbox(for modules: [PrintableModule]) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        guard !modules.isEmpty else { return (0, 0, 0, 0) }
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for m in modules {
            let b = boundingBox(for: m)
            minX = min(minX, b.minX); minY = min(minY, b.minY)
            maxX = max(maxX, b.maxX); maxY = max(maxY, b.maxY)
        }
        return (minX, minY, maxX, maxY)
    }
}
