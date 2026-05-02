//
//  ARDrawerPreviewView.swift
//  Drawer
//
//  Renders the generated layout as a real-scale AR overlay anchored to a
//  horizontal surface the user taps. Combines ARKit world tracking, plane
//  detection, and the existing mesh pipeline so the user can hold their
//  phone over the actual drawer and see the proposed organizer modules
//  ghosted in 3D at the right size.
//
//  Two phases:
//    1. SCANNING — user moves the phone until ARKit detects a horizontal
//       plane (the drawer floor). A tap confirms the drawer position.
//    2. PLACED — modules are rendered at their drawer-space coordinates
//       relative to the tap point. The user can long-press to reposition.
//

import SwiftUI
import ARKit
import SceneKit
import simd

struct ARDrawerPreviewView: View {
    let layout: DrawerLayout

    @Environment(\.dismiss) private var dismiss
    @State private var coordinator = ARCoordinator()
    @State private var hint: String = "Move the phone over the drawer to start"
    @State private var hasPlaced: Bool = false
    @State private var inspectedModule: InspectedModule?

    /// Snapshot of an AR-tapped module surfaced to the SwiftUI overlay so
    /// the user can read its name + dimensions without leaving the AR view.
    struct InspectedModule: Identifiable, Equatable {
        let id: UUID
        let name: String
        let widthInches: Double
        let depthInches: Double
        let heightInches: Double
        let tier: Int
    }

    var body: some View {
        ZStack {
            ARDrawerContainer(coordinator: coordinator,
                                layout: layout,
                                onPlaced: {
                                    hasPlaced = true
                                    hint = "Tap to inspect · Pinch · Twist · Long-press to move"
                                },
                                onHint: { hint = $0 },
                                onInspect: { inspectedModule = $0 })
                .ignoresSafeArea()

            // Top hint banner
            VStack {
                HStack(spacing: 10) {
                    Image(systemName: hasPlaced
                          ? "viewfinder.circle.fill"
                          : "arkit")
                        .foregroundStyle(.white)
                    Text(hint)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if !hasPlaced {
                    placementInstructions
                } else {
                    bottomActions
                }
            }

            // Inspection card — slides in when the user taps a module.
            // Sits above the bottom actions so it's the focus when present.
            if let inspected = inspectedModule {
                inspectionCard(for: inspected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82),
                   value: inspectedModule)
        .navigationTitle("AR Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if hasPlaced {
                    Button {
                        coordinator.reset()
                        hasPlaced = false
                        inspectedModule = nil
                        hint = "Tap on the drawer floor to place again"
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    /// Floating glass card that surfaces the tapped module's name and
    /// dimensions. Auto-dismisses on tap-anywhere or by tapping its X.
    @ViewBuilder
    private func inspectionCard(for module: InspectedModule) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: module.tier == 2
                          ? "square.stack.3d.up.fill"
                          : "rectangle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(module.tier == 2 ? "Tier-2 (stacked above)" : "Tier-1 (on drawer floor)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Button { inspectedModule = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                Divider().background(.white.opacity(0.2))
                HStack(spacing: 14) {
                    statChip(label: "Width",
                              value: String(format: "%.1f″", module.widthInches))
                    statChip(label: "Depth",
                              value: String(format: "%.1f″", module.depthInches))
                    statChip(label: "Height",
                              value: String(format: "%.1f″", module.heightInches))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.tint(.cyan.opacity(0.18)),
                          in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.bottom, 100)   // leave room for bottomActions
        }
    }

    private func statChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.10))
        )
    }

    private var placementInstructions: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeat(.continuous))
            Text("When the dotted plane appears, tap to drop the layout")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 28)
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                coordinator.reset()
                hasPlaced = false
                hint = "Tap to place again"
            } label: {
                Label("Place again", systemImage: "scope")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 28)
    }
}

// MARK: - ARSCNView container

/// `UIViewRepresentable` wrapper around `ARSCNView`. Keeps the AR session
/// configuration owned by the coordinator so the SwiftUI view stays
/// stateless on its own.
struct ARDrawerContainer: UIViewRepresentable {
    let coordinator: ARCoordinator
    let layout: DrawerLayout
    let onPlaced: () -> Void
    let onHint: (String) -> Void
    let onInspect: (ARDrawerPreviewView.InspectedModule?) -> Void

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.autoenablesDefaultLighting = true
        view.automaticallyUpdatesLighting = true
        // IMPORTANT: do NOT set `view.scene.background.contents` —
        // ARSCNView uses that property to render the live camera feed,
        // and overriding it (even to .clear) replaces the camera with
        // whatever you set. Leaving it default keeps the AR pass-through
        // visible behind the layout.

        coordinator.layout = layout
        coordinator.arView = view
        coordinator.onPlaced = onPlaced
        coordinator.onHint = onHint
        coordinator.onInspect = onInspect
        view.delegate = coordinator
        view.session.delegate = coordinator

        // Tap → place layout if not yet placed, otherwise inspect a module.
        let tap = UITapGestureRecognizer(target: coordinator,
                                          action: #selector(ARCoordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        // Pinch → uniformly scale the placed layout. Useful when ARKit's
        // detected plane scale is slightly off from the real drawer size.
        let pinch = UIPinchGestureRecognizer(target: coordinator,
                                              action: #selector(ARCoordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        // Long-press + drag → reposition the entire layout in 2D plane.
        let pan = UILongPressGestureRecognizer(target: coordinator,
                                                action: #selector(ARCoordinator.handleLongPressDrag(_:)))
        pan.minimumPressDuration = 0.35
        pan.allowableMovement = 1000   // don't cancel on movement
        view.addGestureRecognizer(pan)

        // Two-finger twist → rotate the entire layout around its vertical
        // axis. Useful when the layout's default orientation doesn't match
        // the way the user's drawer actually opens.
        let rotate = UIRotationGestureRecognizer(target: coordinator,
                                                  action: #selector(ARCoordinator.handleRotate(_:)))
        view.addGestureRecognizer(rotate)

        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            cfg.frameSemantics.insert(.sceneDepth)
        }
        view.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        coordinator.layout = layout
    }
}

// MARK: - Coordinator

/// Owns the AR session, plane-detection state, tap handling, and the SceneKit
/// nodes that represent the layout in AR space. Built as a class so SwiftUI
/// re-renders don't tear down the session.
@MainActor
final class ARCoordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
    var arView: ARSCNView?
    var layout: DrawerLayout?
    var onPlaced: (() -> Void)?
    var onHint: ((String) -> Void)?
    var onInspect: ((ARDrawerPreviewView.InspectedModule?) -> Void)?

    private var placementAnchor: ARAnchor?
    private var modulesNode: SCNNode?
    private var detectedPlaneCount: Int = 0

    /// Maps SCNNode → the OrganizerItem it represents. Used by tap-inspect to
    /// figure out *which* module the user touched. Filled in when the layout
    /// is placed; cleared on reset.
    private var nodeToItem: [SCNNode: OrganizerItem] = [:]
    /// Currently highlighted module's node (so we can clear its highlight
    /// when the user inspects a different one).
    private var highlightedNode: SCNNode?
    /// Original Y position of the modulesNode at placement time, used by the
    /// long-press drag to compute a delta from the start point.
    private var dragStartPosition: SCNVector3?

    // MARK: - ARSessionDelegate

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Hint the user as tracking improves.
        Task { @MainActor in
            switch frame.camera.trackingState {
            case .normal:
                if self.placementAnchor == nil && self.detectedPlaneCount == 0 {
                    self.onHint?("Move the phone slowly over the drawer floor")
                }
            case .limited(let reason):
                let msg: String
                switch reason {
                case .initializing: msg = "Initialising — keep moving the phone"
                case .insufficientFeatures: msg = "Need more texture — try better lighting"
                case .excessiveMotion: msg = "Slow down — too much motion"
                default: msg = "Hold steady"
                }
                self.onHint?(msg)
            case .notAvailable:
                self.onHint?("AR not available")
            @unknown default:
                break
            }
        }
    }

    // MARK: - ARSCNViewDelegate (plane detection)

    nonisolated func renderer(_ renderer: SCNSceneRenderer,
                                didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let plane = anchor as? ARPlaneAnchor,
              plane.alignment == .horizontal else { return }
        Task { @MainActor in
            self.detectedPlaneCount += 1
            if self.placementAnchor == nil {
                self.onHint?("Floor detected — tap to drop your layout")
                let dot = self.makePlaneIndicator(for: plane)
                node.addChildNode(dot)
            }
        }
    }

    nonisolated func renderer(_ renderer: SCNSceneRenderer,
                                didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Refresh the dotted-plane indicator as ARKit refines the plane size.
        guard let plane = anchor as? ARPlaneAnchor,
              plane.alignment == .horizontal else { return }
        Task { @MainActor in
            for child in node.childNodes where child.name == "planeIndicator" {
                child.geometry = self.makePlaneGeometry(for: plane)
                child.position = SCNVector3(plane.center.x, 0, plane.center.z)
            }
        }
    }

    // MARK: - Placement

    @objc nonisolated func handleTap(_ recognizer: UITapGestureRecognizer) {
        Task { @MainActor in
            guard let view = self.arView else { return }
            let point = recognizer.location(in: view)

            // Already placed → tap is for inspecting a module.
            if self.placementAnchor != nil {
                self.tryInspect(at: point, in: view)
                return
            }

            // Not yet placed → tap drops the layout at the hit point.
            guard let query = view.raycastQuery(from: point,
                                                  allowing: .existingPlaneInfinite,
                                                  alignment: .horizontal),
                  let result = view.session.raycast(query).first
            else {
                self.onHint?("Couldn't lock on — keep scanning the surface")
                return
            }

            let anchor = ARAnchor(name: "drawerAnchor", transform: result.worldTransform)
            view.session.add(anchor: anchor)
            self.placementAnchor = anchor

            self.placeLayout(at: result.worldTransform, on: view)
            self.onPlaced?()
        }
    }

    /// SceneKit hit-test the tapped point, find the module node it landed
    /// on, surface the corresponding `OrganizerItem` to the SwiftUI overlay,
    /// and apply a visual highlight.
    private func tryInspect(at point: CGPoint, in view: ARSCNView) {
        let hits = view.hitTest(point,
                                  options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
        // Walk up the parent chain — the hit might be on a wall geometry
        // child, but the lookup is keyed on the module's root node.
        var foundItem: OrganizerItem?
        var foundNode: SCNNode?
        for hit in hits {
            var node: SCNNode? = hit.node
            while let n = node {
                if let item = nodeToItem[n] {
                    foundItem = item
                    foundNode = n
                    break
                }
                node = n.parent
            }
            if foundItem != nil { break }
        }

        if let item = foundItem, let node = foundNode {
            applyHighlight(to: node)
            UISelectionFeedbackGenerator().selectionChanged()
            onInspect?(.init(
                id: item.id,
                name: item.name,
                widthInches: item.width,
                depthInches: item.height,
                heightInches: layout?.measurement.heightInches ?? 0,
                tier: item.tier
            ))
        } else {
            // Tapped empty space → dismiss any open inspection.
            clearHighlight()
            onInspect?(nil)
        }
    }

    private func applyHighlight(to node: SCNNode) {
        clearHighlight()
        highlightedNode = node
        // Emission glow so the picked module reads above the rest without
        // obscuring the underlying real-world content. We deliberately
        // avoid scaling the node — every module sits at 0.001 scale to
        // convert mm → m, so an absolute scale animation would balloon
        // the geometry.
        node.geometry?.materials.first?.emission.contents = UIColor.cyan.withAlphaComponent(0.45)
    }

    private func clearHighlight() {
        guard let node = highlightedNode else { return }
        node.geometry?.materials.first?.emission.contents = UIColor.black
        highlightedNode = nil
    }

    /// Pinch-to-scale uniformly resizes the entire layout. ARKit's plane
    /// detection isn't always pixel-perfect; this lets the user nudge the
    /// virtual layout to match their actual drawer.
    @objc nonisolated func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        Task { @MainActor in
            guard let parent = self.modulesNode else { return }
            switch recognizer.state {
            case .changed:
                let factor = Float(recognizer.scale)
                parent.scale = SCNVector3(
                    parent.scale.x * factor,
                    parent.scale.y * factor,
                    parent.scale.z * factor
                )
                recognizer.scale = 1.0
            default:
                break
            }
        }
    }

    /// Two-finger twist → rotate the entire layout around the vertical axis.
    /// `UIRotationGestureRecognizer.rotation` is in radians, positive
    /// counter-clockwise from the user's perspective. SceneKit's
    /// `eulerAngles.y` rotates around the Y axis (up), positive
    /// counter-clockwise viewed from above — same direction, so subtract.
    @objc nonisolated func handleRotate(_ recognizer: UIRotationGestureRecognizer) {
        Task { @MainActor in
            guard let parent = self.modulesNode else { return }
            switch recognizer.state {
            case .began:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .changed:
                parent.eulerAngles.y -= Float(recognizer.rotation)
                recognizer.rotation = 0
            default:
                break
            }
        }
    }

    /// Long-press + drag: lift the entire layout off its anchor and slide
    /// it across the detected plane to a new position. Matches how iOS users
    /// already manipulate AR objects in apps like Measure / Quick Look.
    @objc nonisolated func handleLongPressDrag(_ recognizer: UILongPressGestureRecognizer) {
        Task { @MainActor in
            guard let view = self.arView, let parent = self.modulesNode else { return }
            let point = recognizer.location(in: view)
            switch recognizer.state {
            case .began:
                self.dragStartPosition = parent.position
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .changed:
                // Project the touch onto the existing plane to get a world
                // point we can use as the new layout origin.
                if let query = view.raycastQuery(from: point,
                                                   allowing: .existingPlaneInfinite,
                                                   alignment: .horizontal),
                   let result = view.session.raycast(query).first {
                    let m = result.worldTransform
                    parent.position = SCNVector3(m.columns.3.x,
                                                  m.columns.3.y,
                                                  m.columns.3.z)
                }
            case .ended, .cancelled:
                self.dragStartPosition = nil
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            default:
                break
            }
        }
    }

    func placeLayout(at transform: simd_float4x4, on view: ARSCNView) {
        guard let layout = layout else { return }

        // Tear down any previous placement so re-tapping starts fresh.
        modulesNode?.removeFromParentNode()
        nodeToItem.removeAll()
        clearHighlight()

        let parent = SCNNode()
        parent.simdTransform = transform

        // Build modules from the layout (using the same generator the print
        // pipeline uses, so geometry matches what would actually print).
        let organizer = PrintModelGenerator.makeOrganizer(
            from: layout,
            settings: .default,
            filament: .default,
            printer: .bambuA1
        )

        let drawerW = organizer.drawerInteriorWidthMm / 1000.0   // mm → m
        let drawerD = organizer.drawerInteriorDepthMm / 1000.0
        // ARKit uses meters; SceneKit conversion factor 1000.

        // Subtle floor outline.
        let floor = SCNPlane(width: CGFloat(drawerW), height: CGFloat(drawerD))
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.08)
        floorMat.isDoubleSided = true
        floor.materials = [floorMat]
        let floorNode = SCNNode(geometry: floor)
        floorNode.eulerAngles.x = -.pi / 2
        parent.addChildNode(floorNode)

        // Map item id → OrganizerItem for tap-inspect lookup. The print
        // generator may split modules; we want the original layout item, so
        // walk the layout's items list directly.
        let itemById = Dictionary(uniqueKeysWithValues: layout.items.map { ($0.id, $0) })

        // Modules — each at its drawer-space position, scaled mm → m.
        for module in organizer.modules {
            let mesh = PrintModelGenerator.makeMesh(for: module)
            let geo = makeGeometry(from: mesh)

            // Use the item's actual color from the layout (more saturated
            // than the print-pipeline tint hex, which is desaturated for
            // printability). Translucent enough to see real-world content
            // through but solid enough to be legible against busy
            // backgrounds (kitchen tables, drawers with patterns, etc.).
            let item = itemById[module.id] ?? itemById[module.originalModuleId ?? UUID()]
            let baseColor: UIColor
            if let it = item {
                baseColor = UIColor(it.color)
            } else {
                baseColor = UIColor(Color(hex: module.tintHex))
            }
            let mat = SCNMaterial()
            mat.diffuse.contents = baseColor.withAlphaComponent(0.85)
            mat.lightingModel = .physicallyBased
            mat.roughness.contents = 0.4
            mat.metalness.contents = 0.05
            // Subtle inner highlight on edges so each tray reads distinctly
            // even when overlapping in the camera frame.
            mat.emission.contents = UIColor.black
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            // Convert drawer-space (mm) to AR space (m), centered on the
            // anchor with drawer top-left at (-w/2, -d/2).
            node.scale = SCNVector3(0.001, 0.001, 0.001)
            let xCenter = (module.originXMm - organizer.drawerInteriorWidthMm / 2) / 1000.0
            let zCenter = (module.originYMm - organizer.drawerInteriorDepthMm / 2) / 1000.0
            node.position = SCNVector3(Float(xCenter),
                                         Float(module.zOffsetMm) / 1000,
                                         Float(zCenter))
            // Casts a soft contact shadow on the floor plane below for
            // grounding (without it the modules look like they float).
            node.castsShadow = true
            parent.addChildNode(node)

            // Register the node for tap-inspect lookup.
            if let item {
                nodeToItem[node] = item
            }
        }

        view.scene.rootNode.addChildNode(parent)
        modulesNode = parent
    }

    func reset() {
        modulesNode?.removeFromParentNode()
        modulesNode = nil
        nodeToItem.removeAll()
        clearHighlight()
        if let anchor = placementAnchor {
            arView?.session.remove(anchor: anchor)
            placementAnchor = nil
        }
        detectedPlaneCount = 0
        dragStartPosition = nil
        onInspect?(nil)
        onHint?("Move the phone over the drawer to start")
    }

    // MARK: - Helpers

    private func makePlaneIndicator(for plane: ARPlaneAnchor) -> SCNNode {
        let node = SCNNode(geometry: makePlaneGeometry(for: plane))
        node.name = "planeIndicator"
        node.position = SCNVector3(plane.center.x, 0, plane.center.z)
        return node
    }

    private func makePlaneGeometry(for plane: ARPlaneAnchor) -> SCNGeometry {
        let geo = SCNPlane(width: CGFloat(plane.planeExtent.width),
                            height: CGFloat(plane.planeExtent.height))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.20)
        mat.isDoubleSided = true
        geo.materials = [mat]
        // SCNPlane is XY by default; rotate to lie flat on the world's XZ
        // plane (the floor).
        geo.firstMaterial?.diffuse.wrapS = .repeat
        return geo
    }

    /// Shared mesh-to-SCNGeometry conversion (mirrors Print3DPreview's
    /// helper). Z-up mesh is mapped to Y-up SceneKit, with triangle
    /// winding reversed to keep faces visible after the axis swap.
    private func makeGeometry(from mesh: Mesh) -> SCNGeometry {
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
        let element = SCNGeometryElement(indices: indices,
                                            primitiveType: .triangles)
        return SCNGeometry(sources: [vertexSource], elements: [element])
    }
}
