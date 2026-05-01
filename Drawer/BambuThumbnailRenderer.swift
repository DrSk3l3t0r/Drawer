//
//  BambuThumbnailRenderer.swift
//  Drawer
//
//  Renders the five PNG thumbnails Bambu Studio embeds in a `.gcode.3mf`:
//   - plate_1.png         — large plate preview (512×512)
//   - plate_1_small.png   — small plate preview (128×128)
//   - plate_no_light_1.png — flat / no-lighting variant for the printer LCD
//   - top_1.png           — top-down ortho view
//   - pick_1.png          — colored-by-object pick map (printer skip detection)
//
//  Each module is drawn in its assigned AMS lite color so the print preview
//  reflects the multi-color assignment.
//

import UIKit

enum BambuThumbnailRenderer {

    struct ThumbnailSet {
        var plateLarge: Data
        var plateSmall: Data
        var plateNoLight: Data
        var top: Data
        var pick: Data
    }

    struct Inputs {
        let modules: [PrintableModule]
        let plate: AMSLitePlate
        let assignment: AMSLiteAssignment
        let drawerWidthMm: Double
        let drawerDepthMm: Double
    }

    static func render(_ inputs: Inputs) -> ThumbnailSet {
        let plateLarge = renderPlate(inputs, size: CGSize(width: 512, height: 512), shaded: true, withBackground: true)
        let plateSmall = renderPlate(inputs, size: CGSize(width: 128, height: 128), shaded: true, withBackground: true)
        let plateNoLight = renderPlate(inputs, size: CGSize(width: 512, height: 512), shaded: false, withBackground: true)
        let top = renderPlate(inputs, size: CGSize(width: 256, height: 256), shaded: false, withBackground: false)
        let pick = renderPick(inputs, size: CGSize(width: 256, height: 256))
        return ThumbnailSet(
            plateLarge: pngData(plateLarge),
            plateSmall: pngData(plateSmall),
            plateNoLight: pngData(plateNoLight),
            top: pngData(top),
            pick: pngData(pick)
        )
    }

    // MARK: - Plate rendering

    private static func renderPlate(_ inputs: Inputs,
                                     size: CGSize,
                                     shaded: Bool,
                                     withBackground: Bool) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Background — A1 textured plate is roughly dark gray with grid.
            if withBackground {
                cg.setFillColor(UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1).cgColor)
                cg.fill(CGRect(origin: .zero, size: size))

                // Bed grid lines for visual reference
                cg.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
                cg.setLineWidth(0.5)
                let gridStep: CGFloat = size.width / 16
                for i in 0...16 {
                    let v = CGFloat(i) * gridStep
                    cg.move(to: CGPoint(x: v, y: 0)); cg.addLine(to: CGPoint(x: v, y: size.height))
                    cg.move(to: CGPoint(x: 0, y: v)); cg.addLine(to: CGPoint(x: size.width, y: v))
                }
                cg.strokePath()
            } else {
                cg.setFillColor(UIColor.black.cgColor)
                cg.fill(CGRect(origin: .zero, size: size))
            }

            // Compute scale: fit drawer into image with margin.
            let margin: CGFloat = size.width * 0.08
            let availW = size.width - 2 * margin
            let availH = size.height - 2 * margin
            let scaleX = availW / CGFloat(inputs.drawerWidthMm)
            let scaleY = availH / CGFloat(inputs.drawerDepthMm)
            let scale = min(scaleX, scaleY)
            let offsetX = (size.width - CGFloat(inputs.drawerWidthMm) * scale) / 2
            let offsetY = (size.height - CGFloat(inputs.drawerDepthMm) * scale) / 2

            // Drawer outline
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            cg.setLineWidth(1.5)
            let drawerRect = CGRect(
                x: offsetX, y: offsetY,
                width: CGFloat(inputs.drawerWidthMm) * scale,
                height: CGFloat(inputs.drawerDepthMm) * scale
            )
            cg.stroke(drawerRect)

            // Modules
            for module in inputs.modules {
                let slot = inputs.assignment.slot(for: module.id, feature: .outerWall)
                let color = inputs.plate.slots[safeIdx: slot]??.color ?? FilamentColor.defaults[0]
                let uiColor = UIColor(swiftUIHex: color.hex)

                let rect = CGRect(
                    x: offsetX + CGFloat(module.originXMm) * scale,
                    y: offsetY + CGFloat(module.originYMm) * scale,
                    width: CGFloat(module.outerWidthMm) * scale,
                    height: CGFloat(module.outerDepthMm) * scale
                )

                // Outer fill
                cg.setFillColor(uiColor.withAlphaComponent(shaded ? 0.95 : 0.85).cgColor)
                let outer = UIBezierPath(roundedRect: rect, cornerRadius: 2)
                outer.fill()

                // Inner cavity (subtract walls)
                let wallPx = CGFloat(module.wallThicknessMm) * scale
                let innerRect = rect.insetBy(dx: wallPx, dy: wallPx)
                if innerRect.width > 0 && innerRect.height > 0 {
                    cg.setFillColor(UIColor.black.withAlphaComponent(shaded ? 0.55 : 0.7).cgColor)
                    UIBezierPath(roundedRect: innerRect, cornerRadius: 1).fill()
                }

                // Subtle highlight (shaded only)
                if shaded {
                    cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
                    cg.setLineWidth(0.8)
                    cg.stroke(rect)
                }
            }
        }
    }

    // MARK: - Pick rendering

    /// Pick map: each object gets a unique solid color so the printer can
    /// identify objects by RGB (used for object-skip on collision).
    private static func renderPick(_ inputs: Inputs, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let margin: CGFloat = size.width * 0.08
            let availW = size.width - 2 * margin
            let availH = size.height - 2 * margin
            let scaleX = availW / CGFloat(inputs.drawerWidthMm)
            let scaleY = availH / CGFloat(inputs.drawerDepthMm)
            let scale = min(scaleX, scaleY)
            let offsetX = (size.width - CGFloat(inputs.drawerWidthMm) * scale) / 2
            let offsetY = (size.height - CGFloat(inputs.drawerDepthMm) * scale) / 2

            for (i, module) in inputs.modules.enumerated() {
                // Encode index into RGB so printer can decode the pick id.
                let r = CGFloat((i * 17) % 256) / 255
                let g = CGFloat((i * 31 + 80) % 256) / 255
                let b = CGFloat((i * 53 + 40) % 256) / 255
                cg.setFillColor(UIColor(red: r, green: g, blue: b, alpha: 1).cgColor)
                let rect = CGRect(
                    x: offsetX + CGFloat(module.originXMm) * scale,
                    y: offsetY + CGFloat(module.originYMm) * scale,
                    width: CGFloat(module.outerWidthMm) * scale,
                    height: CGFloat(module.outerDepthMm) * scale
                )
                cg.fill(rect)
            }
        }
    }

    // MARK: - PNG encoding

    private static func pngData(_ image: UIImage) -> Data {
        return image.pngData() ?? Data()
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safeIdx index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension UIColor {
    convenience init(swiftUIHex hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
