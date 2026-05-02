//
//  BambuReferenceAssets.swift
//  Drawer
//
//  Bambu A1 reference gcode templates and constants extracted from a real
//  Bambu Studio export. The templates are intentionally streamlined relative
//  to Bambu Studio's full output — they contain the essential calibration,
//  heating, bed-leveling, priming, AMS lite tool-change, and end-of-print
//  sequences needed for a successful print, without printer-finishing sound
//  patterns and other non-essential decoration.
//

import Foundation

// MARK: - Bambu A1 Identifiers

enum BambuA1Identifiers {
    static let printerModelId = "N2S"           // A1 internal id
    static let printerName = "Bambu Lab A1"
    static let nozzleDiameterMm: Double = 0.4
    static let bedType = "Textured PEI Plate"
    static let bedTypeShort = "textured_plate"
    static let defaultPrintProfile = "0.20mm Standard @BBL A1"
    static let defaultFilamentProfile = "Bambu PLA Basic @BBL A1"
    static let buildVolume = (x: 256.0, y: 256.0, z: 256.0)
    static let bedWipeY: Double = 0
    /// Bambu Studio version we declare in the metadata so the file is
    /// recognized as having come from a recent slicer.
    static let slicerVersion = "02.02.02.56"
}

// MARK: - Filament Catalog

/// Bambu's `tray_info_idx` codes identify specific Bambu filaments. Generic
/// filaments use a leading `GFL`/`GFG` family. The list below covers what we
/// actually emit; using a Bambu code unlocks the right thermal profile in
/// Bambu Studio's preview.
enum BambuFilamentCatalog {

    struct Entry {
        let trayInfoIdx: String
        let typeName: String         // "PLA", "PETG", etc.
        let nozzleTemp: Int
        let nozzleTempInitialLayer: Int
        let bedTemp: Int
        let bedTempInitialLayer: Int
        let density: Double          // g/cm³
        let flowRatio: Double
        let maxVolumetricSpeed: Double
        let fanMinSpeed: Int
        let fanMaxSpeed: Int
        let bambuProfileName: String
    }

    static func entry(for material: FilamentMaterial) -> Entry {
        switch material {
        case .pla:
            return Entry(
                trayInfoIdx: "GFA00",
                typeName: "PLA",
                nozzleTemp: 220, nozzleTempInitialLayer: 220,
                bedTemp: 65, bedTempInitialLayer: 65,
                density: 1.24, flowRatio: 0.98,
                maxVolumetricSpeed: 21,
                fanMinSpeed: 60, fanMaxSpeed: 80,
                bambuProfileName: "Bambu PLA Basic @BBL A1"
            )
        case .petg:
            return Entry(
                trayInfoIdx: "GFG00",
                typeName: "PETG",
                nozzleTemp: 250, nozzleTempInitialLayer: 250,
                bedTemp: 70, bedTempInitialLayer: 70,
                density: 1.27, flowRatio: 0.95,
                maxVolumetricSpeed: 16,
                fanMinSpeed: 30, fanMaxSpeed: 60,
                bambuProfileName: "Bambu PETG HF @BBL A1"
            )
        case .abs:
            return Entry(
                trayInfoIdx: "GFB00",
                typeName: "ABS",
                nozzleTemp: 250, nozzleTempInitialLayer: 250,
                bedTemp: 90, bedTempInitialLayer: 90,
                density: 1.04, flowRatio: 1.0,
                maxVolumetricSpeed: 18,
                fanMinSpeed: 0, fanMaxSpeed: 30,
                bambuProfileName: "Generic ABS @BBL A1"
            )
        case .asa:
            return Entry(
                trayInfoIdx: "GFB01",
                typeName: "ASA",
                nozzleTemp: 260, nozzleTempInitialLayer: 260,
                bedTemp: 95, bedTempInitialLayer: 95,
                density: 1.07, flowRatio: 1.0,
                maxVolumetricSpeed: 18,
                fanMinSpeed: 0, fanMaxSpeed: 30,
                bambuProfileName: "Generic ASA @BBL A1"
            )
        case .tpu:
            return Entry(
                trayInfoIdx: "GFU01",
                typeName: "TPU",
                nozzleTemp: 240, nozzleTempInitialLayer: 240,
                bedTemp: 35, bedTempInitialLayer: 35,
                density: 1.21, flowRatio: 1.0,
                maxVolumetricSpeed: 5,
                fanMinSpeed: 100, fanMaxSpeed: 100,
                bambuProfileName: "Bambu TPU 95A @BBL A1"
            )
        }
    }

    /// Default flush volume (mm³) for changing from one filament/color to
    /// another. Bambu Studio uses a 4×4 matrix; a single sensible value is
    /// good enough for v1. Real volumes vary 250–700 mm³ depending on color
    /// difference.
    static func defaultFlushVolume(from a: FilamentColor, to b: FilamentColor) -> Double {
        if a == b { return 0 }
        // Heuristic: lighter destination requires more flush.
        let dstBrightness = approxBrightness(b)
        let srcBrightness = approxBrightness(a)
        let base: Double = 280
        let bonus: Double = max(0, dstBrightness - srcBrightness) * 220
        return base + bonus
    }

    private static func approxBrightness(_ color: FilamentColor) -> Double {
        let hex = color.hex.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return 0.5 }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}

// MARK: - Start / End / Filament Change Templates

/// Streamlined Bambu A1 start sequence. Performs heat-up, homing, bed
/// leveling, AMS lite filament load, nozzle wipe + prime, and switches
/// to relative extrusion. The `{{...}}` placeholders are substituted by
/// the emitter.
///
/// Critical: the AMS LOAD section (M620 → T0 → G1 E50 → M621) is what
/// physically pushes filament from AMS slot 0 through the extruder gear
/// into the hotend. Without it, the printer happily mimics print motion
/// (G1 X/Y commands work) but no filament is ever extruded because the
/// hotend is empty. This was the bug behind "printer prints air."
enum BambuA1StartGcode {
    static let template = """
; FEATURE: Custom
;===== machine: A1 =========================
;===== Drawer Organizer for iOS slicer =====
G392 S0
M9833.2

;===== start to heat heatbed & hotend ======
M1002 gcode_claim_action : 2
M1002 set_filament_type:{{FILAMENT_TYPE}}
M104 S{{NOZZLE_TEMP_PREHEAT}}
M140 S{{BED_TEMP}}

;===== avoid end stop ======================
G91
G380 S2 Z40 F1200
G380 S3 Z-15 F1200
G90

;===== reset machine status ================
M204 S6000
M630 S0 P0
G91
M17 Z0.3
G90
M17 X0.65 Y1.2 Z0.6
M220 S100
M221 S100
M73.2   R1.0

;===== cog noise reduction ==================
M982.2 S1

;===== home ================================
G28 X
G91
G1 Z5 F1200
G90
G0 X128 F30000
G0 Y254 F3000
G91
G1 Z-5 F1200

M109 S25 H140
M17 E0.3
M83
G1 E10 F1200
G1 E-0.5 F30
M17 D

G28 Z P0 T140
M104 S{{NOZZLE_TEMP}}

;===== bed leveling ========================
M1002 gcode_claim_action : 1
G29.2 S0
G29
G29.2 S1
M190 S{{BED_TEMP}}
M109 S{{NOZZLE_TEMP}}

;===== AMS Lite filament load (slot 0) =====
;       Tells the printer to engage AMS slot 0 and push filament through
;       the extruder gear into the hotend. The 50 mm prime at slow speed
;       (F200) is what physically loads the hotend. Without this block
;       the print head moves correctly but extrudes nothing.
M211 X0 Y0 Z0          ; turn off soft endstops for the side wipe
M975 S1                ; turn on mech mode suppression

G90
G1 X-28.5 F30000        ; move to side wipe area
G1 X-48.2 F3000

M620 M                  ; enable AMS remap
M620 S0A                ; start switch to AMS slot 0
    M1002 gcode_claim_action : 4
    M400
    M1002 set_filament_type:UNKNOWN
    M109 S{{NOZZLE_TEMP}}
    M104 S250           ; raise to common flush temp
    M400
    T0                  ; SELECT TOOL 0 — engages AMS slot 0
    G1 X-48.2 F3000
    M400

    M620.1 E F523.843 T240
    M109 S250           ; wait for nozzle at flush temp
    M106 P1 S0
    G92 E0
    G1 E50 F200         ; PRIME 50 mm — loads filament into hotend
    M400
    M1002 set_filament_type:{{FILAMENT_TYPE}}
M621 S0A                ; finish AMS switch

;===== final temp + secondary prime ========
M109 S{{NOZZLE_TEMP}} H300
G92 E0
G1 E50 F200             ; second prime to ensure full load
M400
M106 P1 S178            ; side fan on for cooling
G92 E0
G1 E5 F200              ; small additional prime
M104 S{{NOZZLE_TEMP}}   ; back to print temp
G92 E0
G1 E-0.5 F300           ; tiny retract before wipe

;===== side wipe ==========================
G1 X-28.5 F30000
G1 X-48.2 F3000
G1 X-28.5 F30000
G1 X-48.2 F3000
G1 X-28.5 F30000
G1 X-48.2 F3000

M400
M106 P1 S0              ; side fan off

;===== prime line on bed ==================
M1002 gcode_claim_action : 24
G90
G0 X10 Y0.5 Z0.3 F12000
G92 E0
G1 X120 E12 F1500
G92 E0
G1 X10 Y0.8 Z0.3 F1200  ; second pass to clean nozzle
G92 E0

G0 Z2 F600

; MACHINE_START_GCODE_END
; filament start gcode
M106 P3 S200

;VT0
G90
G21
M83                     ; relative extrusion
M981 S1 P20000          ; open spaghetti detector
M1007 S1                ; turn on mass estimation
"""
}

enum BambuA1EndGcode {
    static let template = """
;===== drawer organizer end gcode ==========
; close powerlost recovery
M1003 S0
M104 S0 ; turn off hotend
M106 S0 ; turn off part fan

M400 ; wait for moves
M17 S
M17 Z0.4 ; reduce z motor current

G1 Z{{Z_LIFT}} F600
G91
G1 Z2 F600
G90

M400 P100
M17 R

G90
G1 X10 Y240 F3600 ; park bed forward
M140 S0 ; turn off bed
M84 ; motors off
M220 S100  ; reset feed rate
M201.2 K1.0 ; reset accel
M73.2   R1.0 ; reset time
M1002 set_gcode_claim_speed_level : 0

M73 P100 R0
"""
}

/// AMS lite tool-change template. Simplified relative to the full Bambu
/// template — performs the essential M620/T/M621 sequence, flushes the old
/// filament for `flush_length` mm at the side wipe position, and wipes.
enum BambuAMSLiteChange {
    /// Render a filament-change block from old extruder index `from` to new
    /// extruder index `to` with the provided parameters.
    static func render(
        from previousExtruder: Int,
        to nextExtruder: Int,
        oldTemp: Int,
        newTemp: Int,
        flushLengthMm: Double,
        currentZMm: Double,
        oldFeedrate: Int = 1200,
        newFeedrate: Int = 1200
    ) -> String {
        let liftZ = currentZMm + 3.0
        return """
        ;===== filament change \(previousExtruder) -> \(nextExtruder) =====
        M620 S\(nextExtruder)A
        M204 S9000
        G1 Z\(String(format: "%.3f", liftZ)) F1200
        M400
        M106 P1 S0
        M104 S\(oldTemp)
        G1 X267 F18000
        M620.10 A0 F\(oldFeedrate)
        T\(nextExtruder)
        M620.10 A1 F\(newFeedrate) L\(String(format: "%.0f", flushLengthMm)) H\(String(format: "%.1f", BambuA1Identifiers.nozzleDiameterMm)) T\(newTemp)
        G1 Y128 F9000

        ; FLUSH_START
        M109 S\(newTemp)
        M106 P1 S60
        G1 E\(String(format: "%.0f", flushLengthMm)) F\(oldFeedrate)
        ; FLUSH_END

        ; WIPE
        M400
        M106 P1 S178
        G1 X-38.2 F18000
        G1 X-48.2 F3000
        G1 X-38.2 F18000
        G1 X-48.2 F3000
        G1 X-38.2 F12000
        G1 X-48.2 F3000
        M400
        M106 P1 S0
        G1 Z\(String(format: "%.3f", liftZ)) F3000

        M621 S\(nextExtruder)A
        G392 S0
        ;===== filament change end ===================
        """
    }
}

// MARK: - Config Block

/// A representative subset of Bambu Studio config keys for the A1's
/// "0.20mm Standard @BBL A1" profile. Bambu Studio writes hundreds; we emit
/// the keys that are documented as required-or-strongly-influential when
/// opening a `.gcode.3mf`.
enum BambuA1ConfigBlock {

    struct ConfigInputs {
        let layerHeightMm: Double
        let firstLayerHeightMm: Double
        let wallThicknessMm: Double
        let wallLineWidthMm: Double
        let bottomLayerCount: Int
        let infillPercent: Double
        let filaments: [FilamentProfile]   // 1–4 filaments
        let nozzleTemp: Int
        let bedTemp: Int
        let totalLayers: Int
        let totalFilamentLengthMm: Double
        let totalFilamentWeightG: Double
        let printTimeSeconds: Int
        let amsLiteEnabled: Bool
        let usePurgeTower: Bool
    }

    /// Render the CONFIG_BLOCK between `; CONFIG_BLOCK_START` and
    /// `; CONFIG_BLOCK_END` (caller wraps).
    static func render(_ inputs: ConfigInputs) -> String {
        let primary = inputs.filaments.first?.material ?? .pla
        let primaryEntry = BambuFilamentCatalog.entry(for: primary)
        let colorList = inputs.filaments.map { $0.color.hex }.joined(separator: ";")
        let typeList = inputs.filaments.map { BambuFilamentCatalog.entry(for: $0.material).typeName }.joined(separator: ";")
        let trayList = inputs.filaments.map { BambuFilamentCatalog.entry(for: $0.material).trayInfoIdx }.joined(separator: ";")

        var lines: [String] = []
        func k(_ key: String, _ value: String) { lines.append("; \(key) = \(value)") }
        func k(_ key: String, _ value: Double, decimals: Int = 2) {
            lines.append("; \(key) = " + String(format: "%.\(decimals)f", value))
        }
        func k(_ key: String, _ value: Int) { lines.append("; \(key) = \(value)") }

        // --- printer ---
        k("printer_model", "Bambu Lab A1")
        k("printer_variant", "0.4")
        k("printer_settings_id", "Bambu Lab A1 0.4 nozzle")
        k("printable_area", "0x0,256x0,256x256,0x256")
        k("printable_height", inputs.amsLiteEnabled ? 256 : 256)
        k("nozzle_diameter", BambuA1Identifiers.nozzleDiameterMm, decimals: 1)
        k("nozzle_type", "stainless_steel")
        k("default_print_profile", BambuA1Identifiers.defaultPrintProfile)
        k("default_filament_profile", primaryEntry.bambuProfileName)
        k("curr_bed_type", BambuA1Identifiers.bedType)
        k("first_layer_print_sequence", "0")

        // --- speeds ---
        k("default_acceleration", 6000)
        k("initial_layer_acceleration", 500)
        k("travel_acceleration", 10000)
        k("outer_wall_acceleration", 5000)
        k("inner_wall_acceleration", 6000)
        k("infill_acceleration", 6000)
        k("travel_speed", 500)
        k("outer_wall_speed", 200)
        k("inner_wall_speed", 250)
        k("infill_speed", 270)
        k("top_surface_speed", 200)
        k("initial_layer_speed", 50)
        k("initial_layer_infill_speed", 105)
        k("bridge_speed", 50)
        k("gap_infill_speed", 250)

        // --- layers ---
        k("layer_height", inputs.layerHeightMm, decimals: 2)
        k("initial_layer_print_height", inputs.firstLayerHeightMm, decimals: 2)
        k("wall_loops", max(2, Int(round(inputs.wallThicknessMm / inputs.wallLineWidthMm))))
        k("top_shell_layers", 0)
        k("bottom_shell_layers", inputs.bottomLayerCount)
        k("bottom_shell_thickness", 0)
        k("sparse_infill_density", inputs.infillPercent, decimals: 0)
        k("sparse_infill_pattern", "grid")
        k("top_surface_pattern", "monotonic")
        k("bottom_surface_pattern", "monotonic")
        k("ironing_type", "no ironing")

        // --- line widths ---
        k("line_width", inputs.wallLineWidthMm, decimals: 2)
        k("inner_wall_line_width", inputs.wallLineWidthMm, decimals: 2)
        k("outer_wall_line_width", inputs.wallLineWidthMm, decimals: 2)
        k("top_surface_line_width", inputs.wallLineWidthMm, decimals: 2)
        k("sparse_infill_line_width", inputs.wallLineWidthMm, decimals: 2)
        k("initial_layer_line_width", inputs.wallLineWidthMm, decimals: 2)

        // --- thermals ---
        k("nozzle_temperature", primaryEntry.nozzleTemp)
        k("nozzle_temperature_initial_layer", primaryEntry.nozzleTempInitialLayer)
        k("nozzle_temperature_range_low", primaryEntry.nozzleTemp - 10)
        k("nozzle_temperature_range_high", primaryEntry.nozzleTemp + 20)
        k("hot_plate_temp", primaryEntry.bedTemp)
        k("hot_plate_temp_initial_layer", primaryEntry.bedTempInitialLayer)
        k("textured_plate_temp", primaryEntry.bedTemp)
        k("textured_plate_temp_initial_layer", primaryEntry.bedTempInitialLayer)
        k("cool_plate_temp", primaryEntry.bedTemp)
        k("cool_plate_temp_initial_layer", primaryEntry.bedTempInitialLayer)
        k("eng_plate_temp", 0)
        k("eng_plate_temp_initial_layer", 0)
        k("chamber_temperatures", 0)
        k("close_fan_the_first_x_layers", 1)
        k("fan_min_speed", primaryEntry.fanMinSpeed)
        k("fan_max_speed", primaryEntry.fanMaxSpeed)
        k("fan_cooling_layer_time", 80)
        k("slow_down_layer_time", 8)
        k("slow_down_min_speed", 20)

        // --- retraction ---
        k("retraction_length", 0.8, decimals: 1)
        k("retraction_speed", 30)
        k("deretraction_speed", 30)
        k("retract_lift_below", 256)
        k("retract_when_changing_layer", 1)
        k("z_hop", 0.4, decimals: 1)
        k("z_hop_types", "Auto Lift")

        // --- adhesion ---
        k("brim_type", "auto_brim")
        k("brim_width", 5)
        k("brim_object_gap", 0.1, decimals: 2)
        k("skirt_loops", 0)
        k("raft_layers", 0)

        // --- supports ---
        k("enable_support", 0)
        k("support_type", "tree(auto)")

        // --- filaments ---
        k("filament_settings_id", inputs.filaments.map { BambuFilamentCatalog.entry(for: $0.material).bambuProfileName }.joined(separator: ";"))
        k("filament_ids", trayList)
        k("filament_type", typeList)
        k("filament_colour", colorList)
        k("filament_density", inputs.filaments.map { String(BambuFilamentCatalog.entry(for: $0.material).density) }.joined(separator: ";"))
        k("filament_diameter", inputs.filaments.map { _ in "1.75" }.joined(separator: ";"))
        k("filament_flow_ratio", inputs.filaments.map { String(BambuFilamentCatalog.entry(for: $0.material).flowRatio) }.joined(separator: ";"))
        k("filament_max_volumetric_speed", inputs.filaments.map { String(BambuFilamentCatalog.entry(for: $0.material).maxVolumetricSpeed) }.joined(separator: ";"))
        k("filament_cost", inputs.filaments.map { _ in "29.99" }.joined(separator: ";"))
        k("filament_minimal_purge_on_wipe_tower", inputs.filaments.map { _ in "15" }.joined(separator: ";"))

        // --- prime tower ---
        k("enable_prime_tower", inputs.usePurgeTower ? 1 : 0)
        k("prime_tower_width", 35)
        k("prime_tower_brim_width", 3)
        k("prime_tower_position_x", 165)
        k("prime_tower_position_y", 220)

        // --- machine extras ---
        k("extruder_type", "Direct Drive")
        k("extruder_clearance_height_to_lid", 256)
        k("extruder_clearance_height_to_rod", 25)
        k("extruder_clearance_max_radius", 73)
        k("filament_extruder_variant", "Direct Drive Standard")
        k("default_nozzle_volume_type", "Standard")

        // --- pressure advance / dynamics ---
        k("enable_pressure_advance", 0)
        k("pressure_advance", 0.02)
        k("activate_air_filtration", 0)
        k("auxiliary_fan", 0)

        // --- finishing ---
        k("scarf_seam_speed", 50)
        k("seam_position", "aligned")
        k("wall_generator", "classic")
        k("flush_volumes_matrix", "0")
        k("flush_multiplier", 1.0)

        // --- start / end gcode (referenced but the emitter writes the
        // executable block separately; Bambu Studio still parses these so
        // the file looks faithful). Use plain double-quoted single-line
        // entries to mirror the reference format.
        k("machine_start_gcode", "\"\"")
        k("machine_end_gcode", "\"\"")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Header Block

enum BambuHeaderBlock {

    static func render(
        layerCount: Int,
        totalFilamentLengthMm: Double,
        totalFilamentVolumeCm3: Double,
        totalFilamentWeightG: Double,
        maxZmm: Double,
        printTimeSeconds: Int,
        modelTimeSeconds: Int,
        filamentCount: Int,
        filamentDensityFirst: Double
    ) -> String {
        func formatTime(_ seconds: Int) -> String {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            let s = seconds % 60
            if h > 0 { return "\(h)h \(m)m \(s)s" }
            if m > 0 { return "\(m)m \(s)s" }
            return "\(s)s"
        }
        return """
        ; HEADER_BLOCK_START
        ; Drawer Organizer iOS slicer (Bambu A1 native)
        ; model printing time: \(formatTime(modelTimeSeconds)); total estimated time: \(formatTime(printTimeSeconds))
        ; total layer number: \(layerCount)
        ; total filament length [mm] : \(String(format: "%.2f", totalFilamentLengthMm))
        ; total filament volume [cm^3] : \(String(format: "%.2f", totalFilamentVolumeCm3))
        ; total filament weight [g] : \(String(format: "%.2f", totalFilamentWeightG))
        ; filament_density: \(String(format: "%.2f", filamentDensityFirst))
        ; filament_diameter: 1.75
        ; max_z_height: \(String(format: "%.2f", maxZmm))
        ; filament: \(filamentCount)
        ; HEADER_BLOCK_END
        """
    }
}
