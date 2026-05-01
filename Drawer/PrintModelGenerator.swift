//
//  PrintModelGenerator.swift
//  Drawer
//
//  Translates a `DrawerLayout` into printable modules and generates
//  triangle meshes for export.
//

import Foundation
import simd

// MARK: - Mesh primitives

struct MeshVertex: Equatable {
    var x: Double
    var y: Double
    var z: Double
}

struct MeshTriangle: Equatable {
    var a: Int
    var b: Int
    var c: Int
}

struct Mesh: Equatable {
    var vertices: [MeshVertex] = []
    var triangles: [MeshTriangle] = []

    mutating func append(_ other: Mesh) {
        let offset = vertices.count
        vertices.append(contentsOf: other.vertices)
        triangles.append(contentsOf: other.triangles.map {
            MeshTriangle(a: $0.a + offset, b: $0.b + offset, c: $0.c + offset)
        })
    }

    /// Add a quad as two triangles. Vertex order should be counter-clockwise
    /// when viewed from outside the surface.
    mutating func appendQuad(_ a: MeshVertex, _ b: MeshVertex,
                              _ c: MeshVertex, _ d: MeshVertex) {
        let i0 = vertices.count
        vertices.append(contentsOf: [a, b, c, d])
        triangles.append(MeshTriangle(a: i0, b: i0 + 1, c: i0 + 2))
        triangles.append(MeshTriangle(a: i0, b: i0 + 2, c: i0 + 3))
    }
}

// MARK: - Generator

enum PrintModelGenerator {

    /// Convert a `DrawerLayout` into a `PrintableOrganizer`. Pads each module
    /// inwards with `tolerance` on all sides so individual trays slot easily
    /// into the drawer.
    static func makeOrganizer(from layout: DrawerLayout,
                               settings: PrintSettings = .default,
                               filament: FilamentProfile = .default,
                               printer: PrinterProfile = .default) -> PrintableOrganizer {
        let inToMm = PrintConstants.inchToMm

        let drawerWidthMm = layout.measurement.widthInches * inToMm
        let drawerDepthMm = layout.measurement.depthInches * inToMm
        let drawerHeightMm = layout.measurement.heightInches * inToMm

        let tolerance = settings.toleranceMm
        let height = min(settings.heightMm, max(10, drawerHeightMm - 2))

        let modules: [PrintableModule] = layout.items.map { item in
            // Convert layout coordinates (inches, top-left origin) into mm.
            let xMm = item.x * inToMm
            let yMm = item.y * inToMm
            let wMm = item.width * inToMm
            let dMm = item.height * inToMm

            // Apply tolerance — shrink each module slightly so it slides into
            // the drawer without binding.
            let outerW = max(10, wMm - tolerance * 2)
            let outerD = max(10, dMm - tolerance * 2)

            return PrintableModule(
                id: item.id,
                name: item.name,
                outerWidthMm: outerW,
                outerDepthMm: outerD,
                heightMm: height,
                originXMm: xMm + tolerance,
                originYMm: yMm + tolerance,
                wallThicknessMm: settings.wallThicknessMm,
                bottomThicknessMm: settings.bottomThicknessMm,
                cornerRadiusMm: settings.cornerRadiusMm,
                tintHex: hex(for: item)
            )
        }

        return PrintableOrganizer(
            modules: modules,
            drawerInteriorWidthMm: drawerWidthMm,
            drawerInteriorDepthMm: drawerDepthMm,
            drawerInteriorHeightMm: drawerHeightMm,
            settings: settings,
            filament: filament,
            printer: printer,
            purpose: layout.purpose
        )
    }

    /// Triangle mesh for a hollow tray module:
    ///   - Closed bottom of `bottomThickness`
    ///   - Four walls (outer + inner faces) of `wallThickness`
    ///   - Top rim connecting outer + inner walls
    ///   - Open top
    /// Coordinates are local to the module: origin at (0, 0, 0), +X width,
    /// +Y depth, +Z up.
    static func makeMesh(for module: PrintableModule) -> Mesh {
        let w = module.outerWidthMm
        let d = module.outerDepthMm
        let h = module.heightMm
        let wall = module.wallThicknessMm
        let bot = module.bottomThicknessMm

        var mesh = Mesh()

        // Outer box surface (no top face)
        mesh.append(boxSurfaceWithoutTop(width: w, depth: d, height: h))

        // Inner cavity surface (walls + cavity floor) — inverted normals.
        let innerW = max(0.1, w - 2 * wall)
        let innerD = max(0.1, d - 2 * wall)
        let innerH = max(0.1, h - bot)

        // Inner cavity = inverted box from (wall, wall, bot) to (w-wall, d-wall, h)
        mesh.append(invertedBoxSurfaceWithoutTop(
            offsetX: wall, offsetY: wall, offsetZ: bot,
            width: innerW, depth: innerD, height: innerH
        ))

        // Top rim — connect outer top edge and inner top edge as a flat ring.
        mesh.append(topRim(
            outerW: w, outerD: d,
            wall: wall,
            zTop: h
        ))

        return mesh
    }

    /// Convenience: meshes for all modules, each translated to its drawer
    /// position (used when exporting a single combined object).
    static func makeCombinedMesh(for organizer: PrintableOrganizer) -> Mesh {
        var combined = Mesh()
        for module in organizer.modules {
            var local = makeMesh(for: module)
            // Translate vertices by module origin so the combined mesh shows
            // each tray in its drawer location.
            for i in 0..<local.vertices.count {
                local.vertices[i].x += module.originXMm
                local.vertices[i].y += module.originYMm
            }
            combined.append(local)
        }
        return combined
    }

    // MARK: Box helpers

    /// Outer box: bottom + 4 side walls (no top). CCW from outside.
    private static func boxSurfaceWithoutTop(width w: Double,
                                              depth d: Double,
                                              height h: Double) -> Mesh {
        var mesh = Mesh()

        // Vertices of the box
        let v000 = MeshVertex(x: 0, y: 0, z: 0)
        let v100 = MeshVertex(x: w, y: 0, z: 0)
        let v110 = MeshVertex(x: w, y: d, z: 0)
        let v010 = MeshVertex(x: 0, y: d, z: 0)
        let v001 = MeshVertex(x: 0, y: 0, z: h)
        let v101 = MeshVertex(x: w, y: 0, z: h)
        let v111 = MeshVertex(x: w, y: d, z: h)
        let v011 = MeshVertex(x: 0, y: d, z: h)

        // Bottom (normal -Z) — CCW viewed from below
        mesh.appendQuad(v000, v010, v110, v100)
        // Front (normal -Y)
        mesh.appendQuad(v000, v100, v101, v001)
        // Right (normal +X)
        mesh.appendQuad(v100, v110, v111, v101)
        // Back (normal +Y)
        mesh.appendQuad(v110, v010, v011, v111)
        // Left (normal -X)
        mesh.appendQuad(v010, v000, v001, v011)

        return mesh
    }

    /// Inner cavity box with normals pointing into the cavity — bottom + 4
    /// walls only (no top), translated by the given offsets.
    private static func invertedBoxSurfaceWithoutTop(offsetX ox: Double,
                                                      offsetY oy: Double,
                                                      offsetZ oz: Double,
                                                      width w: Double,
                                                      depth d: Double,
                                                      height h: Double) -> Mesh {
        var mesh = Mesh()

        let x0 = ox, x1 = ox + w
        let y0 = oy, y1 = oy + d
        let z0 = oz, z1 = oz + h

        // Vertices
        let v000 = MeshVertex(x: x0, y: y0, z: z0)
        let v100 = MeshVertex(x: x1, y: y0, z: z0)
        let v110 = MeshVertex(x: x1, y: y1, z: z0)
        let v010 = MeshVertex(x: x0, y: y1, z: z0)
        let v001 = MeshVertex(x: x0, y: y0, z: z1)
        let v101 = MeshVertex(x: x1, y: y0, z: z1)
        let v111 = MeshVertex(x: x1, y: y1, z: z1)
        let v011 = MeshVertex(x: x0, y: y1, z: z1)

        // Cavity floor (normal +Z) — viewed from +Z, CCW
        mesh.appendQuad(v000, v100, v110, v010)
        // Cavity front wall (normal +Y) — opposite of outer
        mesh.appendQuad(v001, v101, v100, v000)
        // Cavity right wall (normal -X)
        mesh.appendQuad(v101, v111, v110, v100)
        // Cavity back wall (normal -Y)
        mesh.appendQuad(v111, v011, v010, v110)
        // Cavity left wall (normal +X)
        mesh.appendQuad(v011, v001, v000, v010)

        return mesh
    }

    /// Flat ring at the top connecting the outer wall to the inner cavity.
    /// Drawn as 4 quads (one per side), normals up.
    private static func topRim(outerW w: Double, outerD d: Double,
                                wall: Double, zTop: Double) -> Mesh {
        var mesh = Mesh()

        let inner = wall
        let xL = 0.0, xR = w
        let yF = 0.0, yB = d
        let xLi = inner, xRi = w - inner
        let yFi = inner, yBi = d - inner

        // Each rim segment is a quad on the top plane.
        // Front strip
        mesh.appendQuad(
            MeshVertex(x: xL,  y: yF,  z: zTop),
            MeshVertex(x: xR,  y: yF,  z: zTop),
            MeshVertex(x: xRi, y: yFi, z: zTop),
            MeshVertex(x: xLi, y: yFi, z: zTop)
        )
        // Right strip
        mesh.appendQuad(
            MeshVertex(x: xR,  y: yF,  z: zTop),
            MeshVertex(x: xR,  y: yB,  z: zTop),
            MeshVertex(x: xRi, y: yBi, z: zTop),
            MeshVertex(x: xRi, y: yFi, z: zTop)
        )
        // Back strip
        mesh.appendQuad(
            MeshVertex(x: xR,  y: yB,  z: zTop),
            MeshVertex(x: xL,  y: yB,  z: zTop),
            MeshVertex(x: xLi, y: yBi, z: zTop),
            MeshVertex(x: xRi, y: yBi, z: zTop)
        )
        // Left strip
        mesh.appendQuad(
            MeshVertex(x: xL,  y: yB,  z: zTop),
            MeshVertex(x: xL,  y: yF,  z: zTop),
            MeshVertex(x: xLi, y: yFi, z: zTop),
            MeshVertex(x: xLi, y: yBi, z: zTop)
        )

        return mesh
    }

    // MARK: Helpers

    private static func hex(for item: OrganizerItem) -> String {
        let r = Int(item.colorBrightness * 255 * 0.6 + item.colorHue * 255 * 0.4)
        let g = Int(item.colorBrightness * 255 * 0.6 + item.colorSaturation * 255 * 0.4)
        let b = Int(item.colorBrightness * 255 * 0.5 + (1 - item.colorHue) * 255 * 0.5)
        let clamp: (Int) -> Int = { Swift.max(0, Swift.min(255, $0)) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }
}
