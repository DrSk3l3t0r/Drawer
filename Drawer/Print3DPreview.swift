//
//  Print3DPreview.swift
//  Drawer
//
//  Interactive SceneKit preview of the printable organizer. Each module is
//  built directly from `PrintModelGenerator`'s mesh and tinted with its
//  resolved AMS lite slot color, so the preview reflects exactly what will
//  end up on the bed.
//

import SwiftUI
import SceneKit

struct Print3DPreview: View {
    let organizer: PrintableOrganizer
    let plate: AMSLitePlate
    let assignment: AMSLiteAssignment

    @State private var scene: SCNScene = Self.makeBaseScene()
    @State private var autoRotate: Bool = true
    @State private var resetTick: Int = 0
    @State private var showWireframe: Bool = false

    private let cameraNodeName = "previewCamera"

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("3D PREVIEW")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
                Text("\(organizer.modules.count) module\(organizer.modules.count == 1 ? "" : "s")")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.45))
            }

            ZStack {
                SceneView(
                    scene: scene,
                    pointOfView: scene.rootNode.childNode(withName: cameraNodeName, recursively: true),
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
                .background(
                    RadialGradient(
                        colors: [Color(hex: "1A2233"), Color(hex: "0A0F1A")],
                        center: .center,
                        startRadius: 30,
                        endRadius: 280
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .frame(height: 280)

                // Floating overlay controls — top-right
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        controlButton(icon: autoRotate ? "pause.fill" : "play.fill",
                                       label: autoRotate ? "Pause" : "Spin") {
                            autoRotate.toggle()
                            applyAutoRotate()
                        }
                        controlButton(icon: "arrow.counterclockwise", label: "Reset") {
                            resetTick += 1
                            resetCamera()
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(true)

                // Bottom hint chip
                VStack {
                    Spacer()
                    Text("Drag to rotate · Pinch to zoom")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(.black.opacity(0.35))
                        )
                        .padding(.bottom, 8)
                }
                .allowsHitTesting(false)
            }
        }
        .padding(14)
        .glassCard()
        .onAppear {
            rebuildScene()
            applyAutoRotate()
        }
        .onChange(of: organizer) { _, _ in rebuildScene() }
        .onChange(of: plate) { _, _ in rebuildScene() }
        .onChange(of: assignment) { _, _ in rebuildScene() }
    }

    // MARK: - Controls UI

    private func controlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    // MARK: - Scene building

    private func rebuildScene() {
        let s = Self.makeBaseScene()
        // Build a model node centered around drawer center.
        let model = SCNNode()
        model.name = "organizer"

        let drawerW = organizer.drawerInteriorWidthMm
        let drawerD = organizer.drawerInteriorDepthMm

        // Drawer floor plate — subtle reference rectangle.
        let floor = SCNBox(
            width: CGFloat(drawerW),
            height: 1.0,
            length: CGFloat(drawerD),
            chamferRadius: 1.0
        )
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(white: 0.10, alpha: 1.0)
        floorMat.lightingModel = .physicallyBased
        floorMat.metalness.contents = 0.0
        floorMat.roughness.contents = 0.95
        floor.materials = [floorMat]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.5, 0)
        model.addChildNode(floorNode)

        // Drawer outline — thin frame on top of floor.
        let frame = makeDrawerFrame(width: drawerW, depth: drawerD)
        model.addChildNode(frame)

        // Modules — each as its own colored node. The mesh's local origin is
        // the module's top-left corner, so we offset by drawer center to
        // place the model around (0,0,0) in world space.
        for module in organizer.modules {
            let node = makeModuleNode(module)
            let topLeftX = module.originXMm - drawerW / 2
            let topLeftZ = module.originYMm - drawerD / 2
            node.position = SCNVector3(Float(topLeftX), 0, Float(topLeftZ))
            model.addChildNode(node)
        }

        // Auto-rotate target — wraps the model so the camera can stay still.
        let rotator = SCNNode()
        rotator.name = "rotator"
        rotator.addChildNode(model)
        s.rootNode.addChildNode(rotator)

        // Camera — fit to the drawer's longest dimension.
        let camera = makeCamera(drawerW: drawerW, drawerD: drawerD)
        s.rootNode.addChildNode(camera)

        scene = s
        applyAutoRotate()
    }

    private func makeModuleNode(_ module: PrintableModule) -> SCNNode {
        let mesh = PrintModelGenerator.makeMesh(for: module)
        let geometry = Self.makeGeometry(from: mesh)

        // Determine the dominant slot for this module — outer wall is the
        // most visible feature, so we tint by that.
        let slotIndex = assignment.slot(for: module.id, feature: .outerWall)
        let color = colorForSlot(slotIndex, fallback: module.tintHex)

        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .physicallyBased
        mat.metalness.contents = 0.05
        mat.roughness.contents = 0.55
        mat.isDoubleSided = false
        if showWireframe {
            mat.fillMode = .lines
        }
        geometry.materials = [mat]

        let node = SCNNode(geometry: geometry)
        node.castsShadow = true
        return node
    }

    private func makeDrawerFrame(width w: Double, depth d: Double) -> SCNNode {
        let frame = SCNNode()
        let strokeColor = UIColor.white.withAlphaComponent(0.18)

        // Four thin bars along the drawer rim.
        let thickness = 1.5
        func bar(width: Double, depth: Double, x: Double, z: Double) -> SCNNode {
            let g = SCNBox(width: CGFloat(width), height: CGFloat(thickness),
                           length: CGFloat(depth), chamferRadius: 0.4)
            let m = SCNMaterial()
            m.diffuse.contents = strokeColor
            m.lightingModel = .constant
            g.materials = [m]
            let n = SCNNode(geometry: g)
            n.position = SCNVector3(Float(x), Float(thickness / 2 - 0.5), Float(z))
            return n
        }
        // Top edge
        frame.addChildNode(bar(width: w, depth: thickness, x: 0, z: -d / 2))
        // Bottom edge
        frame.addChildNode(bar(width: w, depth: thickness, x: 0, z: d / 2))
        // Left edge
        frame.addChildNode(bar(width: thickness, depth: d, x: -w / 2, z: 0))
        // Right edge
        frame.addChildNode(bar(width: thickness, depth: d, x: w / 2, z: 0))
        return frame
    }

    private func makeCamera(drawerW: Double, drawerD: Double) -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 38
        camera.zNear = 1
        camera.zFar = 5000
        camera.usesOrthographicProjection = false

        let node = SCNNode()
        node.camera = camera
        node.name = cameraNodeName

        // Position the camera in an iso-ish 3/4 view — distance scales with
        // the larger drawer dimension so big drawers still fit on-screen.
        let largest = max(drawerW, drawerD, 200)
        let distance = largest * 1.85
        node.position = SCNVector3(
            Float(distance * 0.55),
            Float(distance * 0.55),
            Float(distance * 0.55)
        )
        node.look(at: SCNVector3(0, 0, 0))
        return node
    }

    // MARK: - Auto-rotate

    private func applyAutoRotate() {
        guard let rotator = scene.rootNode.childNode(withName: "rotator", recursively: true)
        else { return }
        rotator.removeAllActions()
        if autoRotate {
            let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 22)
            rotator.runAction(SCNAction.repeatForever(spin), forKey: "spin")
        }
    }

    private func resetCamera() {
        // Replace the scene with a freshly-built one so the camera control
        // gesture state also resets.
        rebuildScene()
    }

    // MARK: - Static helpers

    private static func makeBaseScene() -> SCNScene {
        let s = SCNScene()
        // Solid dark background that matches the surrounding card. SceneKit
        // ignores the SwiftUI `.background()` modifier and paints over it,
        // so setting `UIColor.clear` here would let SceneKit's default light
        // surface show — looks like a bright white box in the middle of the
        // dark UI. A specific dark UIColor keeps the preview visually unified
        // with the rest of the print-prep sheet.
        s.background.contents = UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0)

        // Soft fill light from above.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 850
        key.color = UIColor(white: 1.0, alpha: 1.0)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(80, 240, 120)
        keyNode.look(at: SCNVector3(0, 0, 0))
        s.rootNode.addChildNode(keyNode)

        // Cool rim light to add separation.
        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 380
        rim.color = UIColor(red: 0.6, green: 0.75, blue: 1.0, alpha: 1.0)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.position = SCNVector3(-160, 80, -120)
        rimNode.look(at: SCNVector3(0, 0, 0))
        s.rootNode.addChildNode(rimNode)

        // Soft ambient.
        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 260
        amb.color = UIColor(white: 1.0, alpha: 1.0)
        let ambNode = SCNNode()
        ambNode.light = amb
        s.rootNode.addChildNode(ambNode)

        return s
    }

    /// Convert a `Mesh` (mm, +Z up) into an `SCNGeometry` (+Y up).
    private static func makeGeometry(from mesh: Mesh) -> SCNGeometry {
        // SceneKit prefers Y-up; the mesh is Z-up. Swap Y ↔ Z and keep the
        // winding consistent by also flipping triangle order.
        let scnVerts = mesh.vertices.map {
            SCNVector3(Float($0.x), Float($0.z), Float($0.y))
        }

        let vertexSource = SCNGeometrySource(vertices: scnVerts)

        var indices: [Int32] = []
        indices.reserveCapacity(mesh.triangles.count * 3)
        for t in mesh.triangles {
            // Reverse winding to match the axis swap above.
            indices.append(Int32(t.a))
            indices.append(Int32(t.c))
            indices.append(Int32(t.b))
        }

        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .triangles
        )

        return SCNGeometry(sources: [vertexSource], elements: [element])
    }

    private func colorForSlot(_ slot: Int, fallback hex: String) -> UIColor {
        if let profile = plate.slots[safe: slot] ?? nil {
            return UIColor(profile.color.swiftUIColor)
        }
        return UIColor(Color(hex: hex))
    }
}

// MARK: - Local helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
