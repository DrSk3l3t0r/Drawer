//
//  Layout3DView.swift
//  Drawer
//
//  Standalone 3D viewer for a generated layout. Unlike `Print3DPreview`
//  (which lives inside the print-prep flow and ties into AMS lite color
//  assignments), this view is purpose-built for *understanding* the layout —
//  particularly when tier-2 organizers stack on tier-1 ones and the
//  top-down blueprint can't show them clearly.
//
//  Key feature: an "Explode" toggle that animates tier-2 modules upward,
//  separating them from their tier-1 parents so the user can see both
//  layers distinctly.
//

import SwiftUI
import SceneKit

struct Layout3DView: View {
    let layout: DrawerLayout
    @Environment(\.dismiss) private var dismiss

    @State private var scene: SCNScene = Self.makeBaseScene()
    @State private var exploded: Bool = false
    @State private var autoRotate: Bool = true

    private let cameraNodeName = "previewCamera"

    /// Tag names used so `applyExplode` can find tier-2 bodies and lips
    /// independently — they need to lift in lockstep but at different base
    /// heights (the lip sits below its body's main floor).
    private let tier2BodyName = "tier2Body"
    private let tier2LipName = "tier2Lip"

    var body: some View {
        ZStack {
            // The dark background that matches the rest of the app's UI.
            Color(hex: "0A1628").ignoresSafeArea()

            SceneView(
                scene: scene,
                pointOfView: scene.rootNode.childNode(withName: cameraNodeName, recursively: true),
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                tierLegend
                Spacer().frame(height: 12)
                bottomControls
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationBarHidden(true)
        .onAppear {
            rebuildScene()
            startAutoRotateIfNeeded()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Done")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("3D View")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button {
                autoRotate.toggle()
                startAutoRotateIfNeeded()
            } label: {
                Image(systemName: autoRotate ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tier legend (only when there are tier-2 modules)

    @ViewBuilder
    private var tierLegend: some View {
        let hasTier2 = layout.items.contains { $0.tier >= 2 }
        if hasTier2 {
            HStack(spacing: 14) {
                legendChip(color: .white.opacity(0.85), label: "Tier 1 — base")
                legendChip(color: .cyan.opacity(0.85), label: "Tier 2 — stacked")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
        }
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        let hasTier2 = layout.items.contains { $0.tier >= 2 }
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                if hasTier2 {
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            exploded.toggle()
                        }
                        applyExplode(animated: true)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: exploded
                                  ? "rectangle.stack.fill"
                                  : "rectangle.stack")
                                .font(.system(size: 14, weight: .bold))
                            Text(exploded ? "Collapse stack" : "Explode stack")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect(
                            .regular.tint(exploded ? .cyan.opacity(0.40)
                                                    : .white.opacity(0.10))
                                    .interactive(),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    rebuildScene()
                    startAutoRotateIfNeeded()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                        Text("Reset view")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Text("Drag to rotate · Pinch to zoom")
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Scene building

    /// Builds (or rebuilds) the scene from `layout`. Tier-2 nodes are tagged
    /// with `tier2NodeName` so `applyExplode` can lift just those without
    /// rebuilding the entire scene each time the toggle flips.
    private func rebuildScene() {
        let s = Self.makeBaseScene()
        let model = SCNNode()
        model.name = "organizer"

        let inToMm = PrintConstants.inchToMm
        let drawerWMm = layout.measurement.widthInches * inToMm
        let drawerDMm = layout.measurement.depthInches * inToMm

        // Drawer floor reference.
        let floor = SCNBox(
            width: CGFloat(drawerWMm),
            height: 1.0,
            length: CGFloat(drawerDMm),
            chamferRadius: 1.0
        )
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(white: 0.10, alpha: 1.0)
        floorMat.lightingModel = .physicallyBased
        floorMat.roughness.contents = 0.95
        floor.materials = [floorMat]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.5, 0)
        model.addChildNode(floorNode)

        // Modules — go through `makeOrganizer` so any tier-2 locating lips
        // render too. The lip is what physically interlocks tier-2 with its
        // tier-1 parent; showing it here makes the stack look (and be)
        // mechanically real instead of just floating on top.
        let organizer = PrintModelGenerator.makeOrganizer(
            from: layout,
            settings: .default,
            filament: .default,
            printer: .bambuA1
        )
        // Map item id → OrganizerItem for color lookups (the lip's own
        // tintHex is generic; the parent's color is what we want).
        let itemById = Dictionary(uniqueKeysWithValues: layout.items.map { ($0.id, $0) })

        for module in organizer.modules {
            let isTier2 = module.tier >= 2
            let isLip = module.isLocatingLip
            let mesh = PrintModelGenerator.makeMesh(for: module)
            let geo = Self.makeGeometry(from: mesh)

            let parentItem = itemById[module.originalModuleId ?? module.id]
            let baseColor: UIColor = isTier2
                ? UIColor.cyan
                : (parentItem.map { UIColor($0.color) } ?? UIColor.systemBlue)

            let mat = SCNMaterial()
            // Lip is rendered at lower opacity so it reads as structural
            // (the locating mechanism) rather than as another visible tray.
            mat.diffuse.contents = isLip
                ? baseColor.withAlphaComponent(0.55)
                : baseColor.withAlphaComponent(isTier2 ? 0.85 : 0.92)
            mat.lightingModel = .physicallyBased
            mat.roughness.contents = 0.45
            mat.metalness.contents = 0.05
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            node.castsShadow = true
            // Drawer-space (top-left origin) → SceneKit-space (centered).
            let topLeftX = module.originXMm - drawerWMm / 2
            let topLeftZ = module.originYMm - drawerDMm / 2
            node.position = SCNVector3(
                Float(topLeftX),
                Float(module.zOffsetMm),
                Float(topLeftZ)
            )
            if isLip {
                node.name = tier2LipName
            } else if isTier2 {
                node.name = tier2BodyName
            }
            model.addChildNode(node)
        }

        // Auto-rotate target so the camera can stay still while the model
        // spins, just like Print3DPreview.
        let rotator = SCNNode()
        rotator.name = "rotator"
        rotator.addChildNode(model)
        s.rootNode.addChildNode(rotator)

        // Camera positioned for an iso 3/4 view that scales with drawer size.
        let camera = makeCamera(drawerWMm: drawerWMm, drawerDMm: drawerDMm)
        s.rootNode.addChildNode(camera)

        scene = s
        // Re-apply explode state after rebuild so the toggle survives a
        // "Reset view" tap (which actually rebuilds the scene to reset the
        // camera control gestures).
        applyExplode(animated: false)
    }

    /// Lift / drop tier-2 nodes by the explode amount. Bodies and their
    /// locating lips lift together so the stack stays mechanically
    /// coherent — the lip stays a fixed offset below its body so the
    /// user can see how they interlock.
    private func applyExplode(animated: Bool) {
        let lift: Float = exploded ? 60 : 0
        let baseHeightMm: Float = 35.0   // PrintSettings.heightMm default
        let lipDepthMm: Float = 6.0      // PrintModelGenerator.tier2LipDepthMm
        guard let model = scene.rootNode.childNode(withName: "organizer", recursively: true)
        else { return }

        let bodies = model.childNodes { node, _ in node.name == self.tier2BodyName }
        let lips = model.childNodes { node, _ in node.name == self.tier2LipName }

        func move(_ node: SCNNode, to targetY: Float) {
            if animated {
                let action = SCNAction.move(
                    to: SCNVector3(node.position.x, targetY, node.position.z),
                    duration: 0.35
                )
                action.timingMode = .easeInEaseOut
                node.runAction(action)
            } else {
                node.position = SCNVector3(node.position.x, targetY, node.position.z)
            }
        }

        for body in bodies {
            move(body, to: baseHeightMm + lift)
        }
        for lip in lips {
            // Lip lives a fixed lipDepthMm below its body's bottom, so it
            // tracks the body's lift exactly.
            move(lip, to: baseHeightMm - lipDepthMm + lift)
        }
    }

    // MARK: - Camera + lighting

    private func makeCamera(drawerWMm: Double, drawerDMm: Double) -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 38
        camera.zNear = 1
        camera.zFar = 5000
        let node = SCNNode()
        node.camera = camera
        node.name = cameraNodeName
        let largest = max(drawerWMm, drawerDMm, 200)
        let distance = largest * 1.85
        node.position = SCNVector3(
            Float(distance * 0.55),
            Float(distance * 0.55),
            Float(distance * 0.55)
        )
        node.look(at: SCNVector3(0, 0, 0))
        return node
    }

    private func startAutoRotateIfNeeded() {
        guard let rotator = scene.rootNode.childNode(withName: "rotator", recursively: true)
        else { return }
        rotator.removeAllActions()
        if autoRotate {
            let spin = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 22)
            rotator.runAction(SCNAction.repeatForever(spin), forKey: "spin")
        }
    }

    // MARK: - Static helpers

    private static func makeBaseScene() -> SCNScene {
        let s = SCNScene()
        s.background.contents = UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 850
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(80, 240, 120)
        keyNode.look(at: SCNVector3(0, 0, 0))
        s.rootNode.addChildNode(keyNode)

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 380
        rim.color = UIColor(red: 0.6, green: 0.75, blue: 1.0, alpha: 1.0)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.position = SCNVector3(-160, 80, -120)
        rimNode.look(at: SCNVector3(0, 0, 0))
        s.rootNode.addChildNode(rimNode)

        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 260
        let ambNode = SCNNode()
        ambNode.light = amb
        s.rootNode.addChildNode(ambNode)

        return s
    }

    /// Mesh (Z-up, mm) → SCNGeometry (Y-up, with reversed winding).
    private static func makeGeometry(from mesh: Mesh) -> SCNGeometry {
        let scnVerts = mesh.vertices.map {
            SCNVector3(Float($0.x), Float($0.z), Float($0.y))
        }
        let vertexSource = SCNGeometrySource(vertices: scnVerts)
        var indices: [Int32] = []
        indices.reserveCapacity(mesh.triangles.count * 3)
        for t in mesh.triangles {
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
}
