//
//  CaptureView.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI
import AVFoundation

struct CaptureView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var lidarService = LiDARScanService()
    @Binding var navigateToReview: Bool
    @Binding var capturedImage: UIImage?
    @Binding var measurement: DrawerMeasurement?

    @State private var showGuide = true
    @State private var flashOpacity: Double = 0
    @State private var isProcessing = false
    @State private var captureError: String?
    @State private var viewportSize: CGSize = .zero
    @State private var pulse = false
    @Environment(\.dismiss) private var dismiss

    /// Drives the choice of LiDAR vs AVCapture pipeline. We resolve this
    /// once the camera service has reported availability so the user sees
    /// a stable indicator.
    private var useLiDAR: Bool {
        LiDARScanService.isSupported && cameraService.isLiDARAvailable
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    if useLiDAR {
                        ARCameraPreview(session: lidarService.arSession,
                                        onViewSizeChange: { size in
                            lidarService.updateViewportSize(size)
                            viewportSize = size
                        })
                        .ignoresSafeArea()
                    } else if cameraService.permission == .authorized {
                        CameraPreview(session: cameraService.session)
                            .ignoresSafeArea()
                    } else {
                        permissionDeniedView
                    }
                }
                .onAppear {
                    viewportSize = geo.size
                    lidarService.updateViewportSize(geo.size)
                }
                .onChange(of: geo.size) { _, newSize in
                    viewportSize = newSize
                    lidarService.updateViewportSize(newSize)
                }
            }

            // Flash effect
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Reactive overlay & HUD
            if showGuide {
                overlayLayer
            }

            // Foreground UI
            VStack {
                topBar
                Spacer()
                bottomControls
            }

            if isProcessing { processingOverlay }
            if let err = captureError { errorBanner(err) }
        }
        .navigationBarHidden(true)
        .onAppear {
            cameraService.checkPermission()
            startActivePipeline()
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            // Notify the review screen of state changes — only relevant while
            // useLiDAR; non-LiDAR path doesn't need lock notification.
            UIImpactFeedbackGenerator(style: .light).prepare()
        }
        .onDisappear {
            cameraService.stopSession()
            lidarService.stopScanning()
        }
        .onChange(of: lidarService.scanState) { _, new in
            if case .stable = new {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
            }
        }
    }

    // MARK: - Pipeline lifecycle

    private func startActivePipeline() {
        if useLiDAR {
            lidarService.startScanning()
            cameraService.stopSession()
        } else {
            lidarService.stopScanning()
            cameraService.startSession()
        }
    }

    // MARK: - Overlay

    private var overlayLayer: some View {
        GeometryReader { geo in
            ZStack {
                if useLiDAR {
                    DrawerScanOverlay(
                        quad: lidarService.lockedQuad,
                        guideRect: lidarService.guideRect,
                        scanState: lidarService.scanState,
                        lockProgress: lidarService.lockProgress,
                        isLocking: lidarService.isLocking,
                        depthConfidence: lidarService.depthConfidence,
                        trackingQuality: lidarService.trackingQuality,
                        liveMeasurement: lidarService.liveMeasurement,
                        viewportSize: geo.size,
                        pulse: pulse
                    )
                } else {
                    cameraGuide(in: geo.size)
                }
            }
        }
    }

    private func cameraGuide(in size: CGSize) -> some View {
        let rect = CGRect(
            x: 0.12 * size.width, y: 0.28 * size.height,
            width: 0.76 * size.width, height: 0.44 * size.height
        )
        return ZStack {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: 14, height: 14))
            }
            .fill(Color.black.opacity(0.3), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            Text("Place a credit card flat in the drawer for scale")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.85))
                .clipShape(Capsule())
                .position(x: rect.midX, y: rect.maxY + 28)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(radius: 4)
            }

            Spacer()

            modeIndicator
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var modeIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: useLiDAR ? "sensor.fill" : "camera.fill")
                .foregroundStyle(useLiDAR ? .green : .orange)
            Text(useLiDAR ? "LiDAR" : "Camera")
                .font(.caption.bold())
                .foregroundStyle(useLiDAR ? .green : .orange)
            if useLiDAR {
                Circle()
                    .fill(scanStateColor)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(scanStateColor.opacity(0.6), lineWidth: 2)
                            .scaleEffect(pulse && lidarService.isLocking ? 2.0 : 1.0)
                            .opacity(pulse && lidarService.isLocking ? 0 : 0.7)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var scanStateColor: Color {
        switch lidarService.scanState {
        case .stable: return .green
        case .tracking: return .yellow
        case .searching: return .orange
        case .initializing: return .gray
        case .failed: return .red
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            if useLiDAR {
                ScanQualityMeter(
                    tracking: lidarService.trackingQuality,
                    depth: lidarService.depthConfidence,
                    locked: lidarService.lockProgress
                )
                .frame(maxWidth: 260)
                .transition(.opacity)
            }

            ZStack {
                Circle()
                    .stroke(scanStateColor.opacity(useLiDAR ? 0.6 : 0), lineWidth: 3)
                    .frame(width: 96, height: 96)
                    .scaleEffect(pulse && lidarService.scanState.isReadyToCapture ? 1.08 : 1.0)
                    .opacity(pulse && lidarService.scanState.isReadyToCapture ? 0.4 : 0.85)

                Button(action: capturePhoto) {
                    ZStack {
                        Circle()
                            .fill(captureButtonColor)
                            .frame(width: 76, height: 76)
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 86, height: 86)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                }
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.5 : 1.0)
                .scaleEffect(isProcessing ? 0.94 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isProcessing)
            }

            HStack(spacing: 12) {
                Button(action: { withAnimation(.spring()) { showGuide.toggle() } }) {
                    Label(showGuide ? "Hide Guide" : "Show Guide",
                          systemImage: showGuide ? "eye.slash" : "eye")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                if useLiDAR {
                    Button(action: { lidarService.startScanning() }) {
                        Label("Reset Scan", systemImage: "arrow.counterclockwise")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.bottom, 36)
    }

    private var captureButtonColor: Color {
        if useLiDAR {
            return lidarService.scanState.isReadyToCapture ? .white : .white.opacity(0.75)
        }
        return .white
    }

    // MARK: - Permission Denied / Error

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("Camera Access Required")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Go to Settings → Drawer → Camera\nto enable camera access.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                Text(message)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { withAnimation { captureError = nil } }) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            Spacer()
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Analyzing drawer…")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(useLiDAR ? "Processing LiDAR depth data" : "Detecting reference objects")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Capture

    private func capturePhoto() {
        captureError = nil
        withAnimation(.easeInOut(duration: 0.1)) { flashOpacity = 1.0 }
        withAnimation(.easeInOut(duration: 0.2).delay(0.1)) { flashOpacity = 0 }

        if useLiDAR {
            captureWithLiDAR()
        } else {
            captureWithCamera()
        }
    }

    private func captureWithLiDAR() {
        withAnimation(.easeInOut(duration: 0.2)) { isProcessing = true }

        let image = lidarService.captureCurrentImage()
        capturedImage = image
        let m = lidarService.finalizedMeasurement()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let m = m, m.widthInches > 0, m.depthInches > 0 {
                measurement = m
            } else {
                measurement = MeasurementEngine.createDefaultMeasurement()
                withAnimation { captureError = "Couldn't lock a LiDAR measurement — please verify dimensions." }
            }
            withAnimation(.easeInOut(duration: 0.2)) { isProcessing = false }
            navigateToReview = true
        }
    }

    private func captureWithCamera() {
        withAnimation(.easeInOut(duration: 0.2)) { isProcessing = true }
        cameraService.capturePhoto { image in
            DispatchQueue.main.async {
                guard let image = image else {
                    measurement = MeasurementEngine.createDefaultMeasurement()
                    capturedImage = nil
                    withAnimation { captureError = "Photo capture failed — please verify dimensions manually." }
                    withAnimation(.easeInOut(duration: 0.2)) { isProcessing = false }
                    navigateToReview = true
                    return
                }

                capturedImage = image
                MeasurementEngine.measureFromImage(image) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let m):
                            measurement = m
                        case .failure(let err):
                            measurement = MeasurementEngine.createDefaultMeasurement()
                            withAnimation {
                                captureError = err.localizedDescription + " — verify or enter dimensions manually."
                            }
                        }
                        withAnimation(.easeInOut(duration: 0.2)) { isProcessing = false }
                        navigateToReview = true
                    }
                }
            }
        }
    }
}

// MARK: - Drawer Scan Overlay

struct DrawerScanOverlay: View {
    let quad: NormalizedQuad
    let guideRect: CGRect
    let scanState: ScanState
    let lockProgress: Double
    let isLocking: Bool
    let depthConfidence: Double
    let trackingQuality: Double
    let liveMeasurement: DrawerMeasurement?
    let viewportSize: CGSize
    let pulse: Bool

    private var stateColor: Color {
        switch scanState {
        case .stable: return .green
        case .tracking: return .yellow
        case .searching: return .orange
        case .initializing: return .gray
        case .failed: return .red
        }
    }

    var body: some View {
        ZStack {
            // Dim everything outside the locked quad.
            Path { path in
                path.addRect(CGRect(origin: .zero, size: viewportSize))
                path.move(to: quad.cgPoint(for: .topLeft, in: viewportSize))
                path.addLine(to: quad.cgPoint(for: .topRight, in: viewportSize))
                path.addLine(to: quad.cgPoint(for: .bottomRight, in: viewportSize))
                path.addLine(to: quad.cgPoint(for: .bottomLeft, in: viewportSize))
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.32), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            // Quad outline
            QuadShape(quad: quad)
                .stroke(stateColor.opacity(0.95),
                        style: StrokeStyle(lineWidth: 2.4,
                                           dash: isLocking ? [] : [8, 6]))
                .shadow(color: stateColor.opacity(0.7), radius: 6)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: quad)

            // Edge dimension callouts
            EdgeDimensionLabel(
                start: quad.cgPoint(for: .topLeft, in: viewportSize),
                end: quad.cgPoint(for: .topRight, in: viewportSize),
                value: liveMeasurement?.widthInches,
                axis: "W"
            )
            EdgeDimensionLabel(
                start: quad.cgPoint(for: .topLeft, in: viewportSize),
                end: quad.cgPoint(for: .bottomLeft, in: viewportSize),
                value: liveMeasurement?.depthInches,
                axis: "D",
                vertical: true
            )

            // Corner handles
            ForEach(NormalizedQuad.Corner.allCases, id: \.self) { corner in
                CornerHandle(color: stateColor,
                             pulse: pulse && lockProgress > 0.4)
                    .position(quad.cgPoint(for: corner, in: viewportSize))
            }

            // Lock progress ring at center
            ZStack {
                Circle()
                    .stroke(stateColor.opacity(0.25), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: max(0.02, lockProgress))
                    .stroke(stateColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                    .animation(.spring(response: 0.3), value: lockProgress)

                Image(systemName: scanState.isReadyToCapture
                      ? "checkmark"
                      : (isLocking ? "viewfinder" : "scope"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(stateColor)
            }
            .position(
                x: (quad.cgPoint(for: .topLeft, in: viewportSize).x +
                    quad.cgPoint(for: .bottomRight, in: viewportSize).x) / 2,
                y: (quad.cgPoint(for: .topLeft, in: viewportSize).y +
                    quad.cgPoint(for: .bottomRight, in: viewportSize).y) / 2
            )

            // Status pill above quad
            Text(scanState.displayLabel)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(stateColor.opacity(0.5), lineWidth: 1)
                )
                .position(
                    x: (quad.cgPoint(for: .topLeft, in: viewportSize).x +
                        quad.cgPoint(for: .topRight, in: viewportSize).x) / 2,
                    y: max(40,
                           min(quad.cgPoint(for: .topLeft, in: viewportSize).y,
                               quad.cgPoint(for: .topRight, in: viewportSize).y) - 22)
                )
        }
        .allowsHitTesting(false)
    }
}

private struct QuadShape: Shape {
    let quad: NormalizedQuad

    // Animate the eight corner coordinates as an AnimatablePair tower so the
    // stroke morphs smoothly when the locked quad updates.
    typealias QuadPair = AnimatablePair<Double, Double>
    typealias QuadEdge = AnimatablePair<QuadPair, QuadPair>
    typealias QuadAll  = AnimatablePair<QuadEdge, QuadEdge>

    var animatableData: QuadAll {
        get {
            QuadAll(
                QuadEdge(
                    QuadPair(quad.topLeft.x, quad.topLeft.y),
                    QuadPair(quad.topRight.x, quad.topRight.y)
                ),
                QuadEdge(
                    QuadPair(quad.bottomLeft.x, quad.bottomLeft.y),
                    QuadPair(quad.bottomRight.x, quad.bottomRight.y)
                )
            )
        }
        set { /* read-only — view will rebuild on quad change */ }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = rect.size
        path.move(to: quad.cgPoint(for: .topLeft, in: size))
        path.addLine(to: quad.cgPoint(for: .topRight, in: size))
        path.addLine(to: quad.cgPoint(for: .bottomRight, in: size))
        path.addLine(to: quad.cgPoint(for: .bottomLeft, in: size))
        path.closeSubpath()
        return path
    }
}

private struct CornerHandle: View {
    let color: Color
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .shadow(color: color.opacity(0.7), radius: 6)
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 2)
                .frame(width: 22, height: 22)
                .scaleEffect(pulse ? 1.6 : 1.0)
                .opacity(pulse ? 0 : 0.7)
        }
    }
}

private struct EdgeDimensionLabel: View {
    let start: CGPoint
    let end: CGPoint
    let value: Double?
    let axis: String
    var vertical: Bool = false

    var body: some View {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        let angle = atan2(dy, dx)

        return ZStack {
            // Tick line along the edge
            Capsule()
                .fill(.white.opacity(0.85))
                .frame(width: max(0, length - 30), height: 1.5)
                .position(mid)
                .rotationEffect(.radians(angle), anchor: .center)
                .shadow(color: .black.opacity(0.5), radius: 2)

            HStack(spacing: 4) {
                Text(axis)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.white)
                    .clipShape(Capsule())
                if let v = value {
                    Text(String(format: "%.1f\"", v))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("—")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.65))
            .clipShape(Capsule())
            .position(
                x: mid.x + (vertical ? -28 : 0),
                y: mid.y + (vertical ? 0 : -22)
            )
        }
    }
}

// MARK: - Scan Quality Meter

struct ScanQualityMeter: View {
    let tracking: Double
    let depth: Double
    let locked: Double

    var body: some View {
        HStack(spacing: 10) {
            QualityBar(label: "Track", value: tracking, color: .blue)
            QualityBar(label: "Depth", value: depth, color: Color(hue: 0.55, saturation: 0.7, brightness: 0.9))
            QualityBar(label: "Lock", value: locked, color: .green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct QualityBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: max(2, geo.size.width * value))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: value)
                }
            }
            .frame(height: 4)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}
