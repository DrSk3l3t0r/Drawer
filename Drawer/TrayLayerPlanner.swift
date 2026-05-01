//
//  TrayLayerPlanner.swift
//  Drawer
//
//  Generates per-layer toolpaths for axis-aligned hollow rectangular trays.
//  This planner is intentionally specialized — every module is a closed-bottom
//  hollow box, so we can emit perfect rectangular contours and a simple
//  zigzag bottom infill without going through general mesh slicing.
//

import Foundation

// MARK: - Path primitives

struct Point2D: Equatable, Hashable {
    var x: Double  // mm
    var y: Double  // mm

    static let zero = Point2D(x: 0, y: 0)

    func translated(dx: Double, dy: Double) -> Point2D {
        Point2D(x: x + dx, y: y + dy)
    }
}

enum FeatureKind: String, Codable {
    case outerWall, innerWall, bottomSurface, topSurface, primeTower, skirt
    case custom

    var bambuFeatureLabel: String {
        switch self {
        case .outerWall: return "Outer wall"
        case .innerWall: return "Inner wall"
        case .bottomSurface: return "Bottom surface"
        case .topSurface: return "Top surface"
        case .primeTower: return "Prime tower"
        case .skirt: return "Skirt"
        case .custom: return "Custom"
        }
    }
}

/// A connected sequence of points belonging to a single feature on a single
/// layer. `closed` means the last point connects back to the first
/// (perimeters); `false` means open path (infill lines).
struct ToolPath: Equatable {
    var feature: FeatureKind
    var moduleId: UUID?
    var points: [Point2D]
    var closed: Bool
    var lineWidthMm: Double
    /// Index into `AMSLitePlate.colors` when multi-color is enabled.
    var colorSlot: Int

    var totalLengthMm: Double {
        guard points.count >= 2 else { return 0 }
        var len = 0.0
        for i in 0..<(points.count - 1) {
            len += hypot(points[i + 1].x - points[i].x,
                          points[i + 1].y - points[i].y)
        }
        if closed, let first = points.first, let last = points.last {
            len += hypot(first.x - last.x, first.y - last.y)
        }
        return len
    }
}

struct LayerPlan: Equatable {
    var index: Int
    var z: Double               // top of layer in mm
    var layerHeightMm: Double
    var paths: [ToolPath]
}

// MARK: - Planner

enum TrayLayerPlanner {

    struct PlanInputs {
        let module: PrintableModule
        let settings: PrintSettings
        let wallLineWidthMm: Double
        let infillLineWidthMm: Double
        let bottomLayerCount: Int
        let outerWallColorSlot: Int
        let innerWallColorSlot: Int
        let bottomColorSlot: Int
    }

    /// Plan all layers for a single module. Coordinates are returned in the
    /// drawer-space of the plate (i.e. translated by the module origin).
    static func plan(_ inputs: PlanInputs) -> [LayerPlan] {
        let module = inputs.module
        let layerHeight = inputs.settings.layerHeightMm
        let totalLayers = max(1, Int(ceil(module.heightMm / layerHeight)))
        var layers: [LayerPlan] = []
        layers.reserveCapacity(totalLayers)

        let outerW = module.outerWidthMm
        let outerD = module.outerDepthMm
        let wall = module.wallThicknessMm
        let bottom = module.bottomThicknessMm
        let lw = inputs.wallLineWidthMm
        let infillLW = inputs.infillLineWidthMm
        let originX = module.originXMm
        let originY = module.originYMm

        // Number of perimeter loops on each side. We always emit one outer
        // loop and one inner loop minimum, plus extras based on requested
        // wall thickness.
        let wallLoops = max(1, Int(round(wall / lw)))

        for i in 0..<totalLayers {
            let z = min(module.heightMm, Double(i + 1) * layerHeight)
            let isBottomBand = z <= bottom + 0.0001
            var paths: [ToolPath] = []

            // Walls: every layer (including bottom band — bottom solid sits
            // between the walls).
            for loop in 0..<wallLoops {
                // Outer perimeter: rect inset by (loop + 0.5) * lw.
                let outerInset = (Double(loop) + 0.5) * lw
                let outer = rectanglePath(
                    minX: originX + outerInset,
                    minY: originY + outerInset,
                    maxX: originX + outerW - outerInset,
                    maxY: originY + outerD - outerInset
                )
                paths.append(ToolPath(
                    feature: .outerWall,
                    moduleId: module.id,
                    points: outer,
                    closed: true,
                    lineWidthMm: lw,
                    colorSlot: inputs.outerWallColorSlot
                ))

                // Inner cavity perimeter: rect outset from the cavity by
                // (loop + 0.5) * lw — only emitted while there is actually
                // a cavity (i.e. above the bottom solid band).
                if !isBottomBand {
                    let cavityInset = (Double(loop) + 0.5) * lw
                    let innerMinX = originX + wall + cavityInset
                    let innerMinY = originY + wall + cavityInset
                    let innerMaxX = originX + outerW - wall - cavityInset
                    let innerMaxY = originY + outerD - wall - cavityInset
                    if innerMaxX > innerMinX + lw && innerMaxY > innerMinY + lw {
                        let inner = rectanglePath(
                            minX: innerMinX,
                            minY: innerMinY,
                            maxX: innerMaxX,
                            maxY: innerMaxY
                        )
                        paths.append(ToolPath(
                            feature: .innerWall,
                            moduleId: module.id,
                            points: inner,
                            closed: true,
                            lineWidthMm: lw,
                            colorSlot: inputs.innerWallColorSlot
                        ))
                    }
                }
            }

            // Bottom solid infill: only on layers within the bottom band.
            if isBottomBand {
                let infillMinX = originX + Double(wallLoops) * lw
                let infillMinY = originY + Double(wallLoops) * lw
                let infillMaxX = originX + outerW - Double(wallLoops) * lw
                let infillMaxY = originY + outerD - Double(wallLoops) * lw
                if infillMaxX > infillMinX && infillMaxY > infillMinY {
                    let zigzag = zigzagInfill(
                        minX: infillMinX,
                        minY: infillMinY,
                        maxX: infillMaxX,
                        maxY: infillMaxY,
                        spacing: infillLW * 0.95,
                        diagonal: i % 2 == 0
                    )
                    for line in zigzag {
                        paths.append(ToolPath(
                            feature: .bottomSurface,
                            moduleId: module.id,
                            points: line,
                            closed: false,
                            lineWidthMm: infillLW,
                            colorSlot: inputs.bottomColorSlot
                        ))
                    }
                }
            }

            layers.append(LayerPlan(
                index: i,
                z: z,
                layerHeightMm: layerHeight,
                paths: paths
            ))
        }

        return layers
    }

    // MARK: - Helpers

    /// CCW rectangle as four corners (closed path; emitter closes it).
    private static func rectanglePath(minX: Double, minY: Double,
                                       maxX: Double, maxY: Double) -> [Point2D] {
        return [
            Point2D(x: minX, y: minY),
            Point2D(x: maxX, y: minY),
            Point2D(x: maxX, y: maxY),
            Point2D(x: minX, y: maxY)
        ]
    }

    /// Generate parallel zigzag lines that fill a rectangle. Lines alternate
    /// axis (horizontal/vertical) per layer for solid coverage.
    private static func zigzagInfill(minX: Double, minY: Double,
                                      maxX: Double, maxY: Double,
                                      spacing: Double,
                                      diagonal: Bool) -> [[Point2D]] {
        var lines: [[Point2D]] = []
        if diagonal {
            // Horizontal sweeps (varying Y)
            var y = minY
            var even = true
            while y <= maxY + 1e-6 {
                let line: [Point2D] = even
                    ? [Point2D(x: minX, y: y), Point2D(x: maxX, y: y)]
                    : [Point2D(x: maxX, y: y), Point2D(x: minX, y: y)]
                lines.append(line)
                y += spacing
                even.toggle()
            }
        } else {
            // Vertical sweeps (varying X)
            var x = minX
            var even = true
            while x <= maxX + 1e-6 {
                let line: [Point2D] = even
                    ? [Point2D(x: x, y: minY), Point2D(x: x, y: maxY)]
                    : [Point2D(x: x, y: maxY), Point2D(x: x, y: minY)]
                lines.append(line)
                x += spacing
                even.toggle()
            }
        }
        return lines
    }
}

// MARK: - Skirt / Brim

enum SkirtPlanner {

    /// Generate skirt loops around a list of modules. Skirt is drawn on
    /// layer 1 only and uses the outer wall color slot.
    static func skirt(around modules: [PrintableModule],
                       distanceMm: Double,
                       loops: Int,
                       lineWidthMm: Double,
                       colorSlot: Int) -> [ToolPath] {
        guard !modules.isEmpty, loops > 0 else { return [] }
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for m in modules {
            minX = min(minX, m.originXMm)
            minY = min(minY, m.originYMm)
            maxX = max(maxX, m.originXMm + m.outerWidthMm)
            maxY = max(maxY, m.originYMm + m.outerDepthMm)
        }
        var paths: [ToolPath] = []
        for loop in 0..<loops {
            let inset = -(distanceMm + Double(loop) * lineWidthMm)
            paths.append(ToolPath(
                feature: .skirt,
                moduleId: nil,
                points: [
                    Point2D(x: minX + inset, y: minY + inset),
                    Point2D(x: maxX - inset, y: minY + inset),
                    Point2D(x: maxX - inset, y: maxY - inset),
                    Point2D(x: minX + inset, y: maxY - inset)
                ],
                closed: true,
                lineWidthMm: lineWidthMm,
                colorSlot: colorSlot
            ))
        }
        return paths
    }
}
