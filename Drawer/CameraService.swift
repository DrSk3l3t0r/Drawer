//
//  CameraService.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI
import AVFoundation
import ARKit
import Combine
import simd
import Vision

// MARK: - Camera Permission

enum CameraPermission {
    case authorized, denied, notDetermined
}

// MARK: - Camera Service (AVCapture path — non-LiDAR fallback)

class CameraService: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var permission: CameraPermission = .notDetermined
    @Published var isLiDARAvailable: Bool = false
    @Published var isCapturing: Bool = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCompletion: ((UIImage?) -> Void)?

    override init() {
        super.init()
        checkLiDARAvailability()
    }

    func checkLiDARAvailability() {
        // Treat scene-depth support as the LiDAR signal — wider device coverage
        // than scene-reconstruction, and that's what we actually consume.
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    // MARK: - Permissions

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized
            setupSession()
        case .denied, .restricted:
            permission = .denied
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permission = granted ? .authorized : .denied
                    if granted { self?.setupSession() }
                }
            }
        @unknown default:
            permission = .denied
        }
    }

    // MARK: - Session Setup

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        }

        session.commitConfiguration()
    }

    // MARK: - Start / Stop

    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Capture Photo

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard session.isRunning else {
            completion(nil)
            return
        }
        isCapturing = true
        photoCompletion = completion

        let settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { [weak self] in
                self?.photoCompletion?(nil)
                self?.photoCompletion = nil
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
            self?.photoCompletion?(image)
            self?.photoCompletion = nil
        }
    }
}

// MARK: - AVCapture Preview View

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let preview = uiView as? CameraPreviewUIView {
            preview.previewLayer.frame = uiView.bounds
        }
    }
}

class CameraPreviewUIView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// MARK: - Scan State

enum ScanState: Equatable {
    case initializing
    case searching          // looking for the drawer
    case tracking           // detected, refining
    case stable             // measurement is stable & high confidence
    case failed(String)

    var displayLabel: String {
        switch self {
        case .initializing: return "Starting scanner…"
        case .searching:    return "Aim at the drawer interior"
        case .tracking:     return "Hold steady — measuring"
        case .stable:       return "Ready to capture"
        case .failed(let r): return r
        }
    }

    var isReadyToCapture: Bool {
        if case .stable = self { return true }
        return false
    }
}

// MARK: - LiDAR Scan Service (live measurement)

final class LiDARScanService: NSObject, ObservableObject, ARSessionDelegate {

    // MARK: Published state
    @Published private(set) var scanState: ScanState = .initializing
    @Published private(set) var liveMeasurement: DrawerMeasurement?
    @Published private(set) var trackingQuality: Double = 0       // 0..1
    @Published private(set) var depthConfidence: Double = 0       // 0..1

    /// Quad currently used for measurement and visual overlay, in normalized
    /// portrait viewport coords. Eases toward detected drawer rectangles.
    @Published private(set) var lockedQuad: NormalizedQuad = .default
    /// 0..1 — how confident the rectangle/edge lock is. UI shows this as a
    /// pulse / progress indicator.
    @Published private(set) var lockProgress: Double = 0
    /// Whether a real rectangle is currently being tracked (vs. just sitting
    /// on the default guide rect).
    @Published private(set) var isLocking: Bool = false

    /// Guide rectangle expressed in normalized portrait viewport coords (0..1).
    /// The user is told to align the drawer interior inside this rect. Acts
    /// as the search region for the auto-lock detector.
    var guideRect: CGRect = CGRect(x: 0.12, y: 0.28, width: 0.76, height: 0.44)

    let arSession = ARSession()

    private var viewportSize: CGSize = CGSize(width: 390, height: 844) // sensible default
    private var measurementHistory: [DrawerMeasurement] = []
    private let historyCapacity = 12
    private var lastFrameTimestamp: TimeInterval = 0
    private let frameThrottle: TimeInterval = 0.1   // 10 Hz measurement updates

    // Rectangle detection
    private var lastRectangleDetection: TimeInterval = 0
    private let rectangleThrottle: TimeInterval = 0.25
    private var rectangleDetectionInFlight = false
    private var consecutiveDetections = 0
    private var consecutiveMisses = 0

    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    override init() {
        super.init()
        arSession.delegate = self
    }

    // MARK: Lifecycle

    func updateViewportSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        viewportSize = size
    }

    func startScanning() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }

        DispatchQueue.main.async {
            self.scanState = .initializing
            self.measurementHistory.removeAll()
            self.liveMeasurement = nil
            self.lockedQuad = .default
            self.lockProgress = 0
            self.isLocking = false
            self.consecutiveDetections = 0
            self.consecutiveMisses = 0
        }

        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stopScanning() {
        arSession.pause()
    }

    /// Capture the current AR frame's RGB image as a UIImage in portrait orientation.
    func captureCurrentImage() -> UIImage? {
        guard let frame = arSession.currentFrame else { return nil }
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Camera buffer is in landscape — rotate to portrait for display.
        let rotated = ciImage.oriented(.right)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(rotated, from: rotated.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// The most recent stable / averaged measurement, or `liveMeasurement` if not yet stable.
    /// Stamped with the current locked quad and original dimensions so the
    /// review screen can redraw and scale the overlay.
    func finalizedMeasurement() -> DrawerMeasurement? {
        var m: DrawerMeasurement?
        if scanState.isReadyToCapture, let avg = averagedMeasurement() {
            m = avg
        } else {
            m = liveMeasurement
        }
        guard var measurement = m else { return nil }
        measurement.capturedQuad = lockedQuad.isValid ? lockedQuad : .default
        measurement.originalWidthInches = measurement.widthInches
        measurement.originalDepthInches = measurement.depthInches
        return measurement
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Auto-lock detector — runs on a background queue, throttled.
        runRectangleDetection(on: frame)

        // Throttle measurement updates to keep CPU sane.
        let now = frame.timestamp
        if now - lastFrameTimestamp < frameThrottle { return }
        lastFrameTimestamp = now

        let (state, measurement, quality, dConf) = computeMeasurement(from: frame)

        DispatchQueue.main.async {
            self.trackingQuality = quality
            self.depthConfidence = dConf
            self.liveMeasurement = measurement
            self.scanState = state
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.scanState = .failed(error.localizedDescription)
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.scanState = .failed("Session interrupted")
        }
    }

    // MARK: - Measurement Pipeline

    private func computeMeasurement(from frame: ARFrame) ->
        (ScanState, DrawerMeasurement?, Double, Double) {

        // 1. Tracking quality
        let trackingQ = trackingQualityScore(frame.camera.trackingState)
        if trackingQ < 0.2 {
            return (.searching, nil, trackingQ, 0)
        }

        // 2. Need scene depth — prefer smoothed when available.
        guard let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            return (.searching, nil, trackingQ, 0)
        }

        // 3. Sample drawer corners using guide rect → depth-map coords
        guard let sampled = sampleDrawerCorners(frame: frame, sceneDepth: sceneDepth) else {
            return (.searching, nil, trackingQ, 0)
        }

        // 4. Compute width/depth from world-space corner positions.
        let widthMeters = (simd_distance(sampled.tl, sampled.tr) +
                           simd_distance(sampled.bl, sampled.br)) / 2
        let depthMeters = (simd_distance(sampled.tl, sampled.bl) +
                           simd_distance(sampled.tr, sampled.br)) / 2

        // Reject obviously wrong values.
        let minMeters: Float = 0.06     // 2.4"
        let maxMeters: Float = 1.5      // 59"
        guard widthMeters > minMeters, widthMeters < maxMeters,
              depthMeters > minMeters, depthMeters < maxMeters else {
            return (.searching, nil, trackingQ, Double(sampled.confidence))
        }

        // 5. Estimate height from horizontal plane raycast vs. closest vertical plane (rim).
        let heightInfo = estimateDrawerHeight(frame: frame, floorCenter: sampled.center)

        // 6. Build measurement.
        let widthInches = Double(widthMeters) * 39.3701
        let depthInches = Double(depthMeters) * 39.3701

        // Drawer width should be the larger horizontal dimension visible
        // through the opening; respect orientation as captured.
        let measurement = DrawerMeasurement(
            widthInches: widthInches,
            depthInches: depthInches,
            heightInches: heightInfo?.inches ?? 4.0,
            source: .lidar,
            confidenceScore: combinedConfidence(tracking: trackingQ,
                                                depth: Double(sampled.confidence),
                                                stability: 0),
            heightMeasured: heightInfo != nil
        )

        // 7. Update history & determine stability.
        appendMeasurement(measurement)
        let stability = stabilityScore()
        var refined = averagedMeasurement() ?? measurement
        refined.confidenceScore = combinedConfidence(tracking: trackingQ,
                                                     depth: Double(sampled.confidence),
                                                     stability: stability)

        let state: ScanState
        if measurementHistory.count >= 6 && stability > 0.7 && refined.confidenceScore > 0.65 {
            state = .stable
        } else {
            state = .tracking
        }

        return (state, refined, trackingQ, Double(sampled.confidence))
    }

    // MARK: Tracking quality

    private func trackingQualityScore(_ s: ARCamera.TrackingState) -> Double {
        switch s {
        case .normal: return 1.0
        case .limited(let r):
            switch r {
            case .initializing, .relocalizing: return 0.1
            case .insufficientFeatures, .excessiveMotion: return 0.4
            @unknown default: return 0.3
            }
        case .notAvailable: return 0.0
        }
    }

    // MARK: Corner sampling

    private struct CornerSample {
        let tl: SIMD3<Float>   // world-space points
        let tr: SIMD3<Float>
        let bl: SIMD3<Float>
        let br: SIMD3<Float>
        let center: SIMD3<Float>
        let confidence: Float  // 0..1 — average of corner confidences
    }

    private func sampleDrawerCorners(frame: ARFrame,
                                     sceneDepth: ARDepthData) -> CornerSample? {

        let depthMap = sceneDepth.depthMap
        let confidenceMap = sceneDepth.confidenceMap

        let dWidth = CVPixelBufferGetWidth(depthMap)
        let dHeight = CVPixelBufferGetHeight(depthMap)
        guard dWidth > 0, dHeight > 0 else { return nil }

        // Normalized portrait guide rect → image coords on the captured image.
        let displayTransform = frame.displayTransform(for: .portrait,
                                                      viewportSize: viewportSize)
        guard let inverseDT = displayTransform.inverted().nonIdentity() else { return nil }

        // Use the live locked quad (which eases toward detected drawer rectangles)
        // when it's valid; otherwise fall back to the guide rect. Reading the
        // quad here keeps measurement and visual overlay consistent.
        let quad = lockedQuad.isValid ? lockedQuad : NormalizedQuad.default
        let center = NormalizedPoint(
            x: (quad.topLeft.x + quad.bottomRight.x) / 2,
            y: (quad.topLeft.y + quad.bottomRight.y) / 2
        )

        // Corners in *normalized portrait viewport* space (0..1, y down).
        let cornersPortrait: [CGPoint] = [
            CGPoint(x: quad.topLeft.x, y: quad.topLeft.y),
            CGPoint(x: quad.topRight.x, y: quad.topRight.y),
            CGPoint(x: quad.bottomLeft.x, y: quad.bottomLeft.y),
            CGPoint(x: quad.bottomRight.x, y: quad.bottomRight.y),
            CGPoint(x: center.x, y: center.y),
        ]

        // Map portrait viewport coords → normalized image coords (landscape).
        let cornersImage = cornersPortrait.map { $0.applying(inverseDT) }

        // Convert to depth-map pixel coords, with bounds check.
        var depthPixelCoords: [(Int, Int)] = []
        depthPixelCoords.reserveCapacity(cornersImage.count)
        for p in cornersImage {
            let px = Int((p.x.clamped(0, 1)) * CGFloat(dWidth - 1))
            let py = Int((p.y.clamped(0, 1)) * CGFloat(dHeight - 1))
            depthPixelCoords.append((px, py))
        }

        // Sample depth + confidence around each pixel (small neighborhood for noise).
        var depthSamples: [Float] = []
        var confidenceSamples: [Float] = []
        for (px, py) in depthPixelCoords {
            guard let s = sampleDepth(depthMap: depthMap,
                                       confidenceMap: confidenceMap,
                                       x: px, y: py,
                                       radius: 3,
                                       width: dWidth, height: dHeight) else { return nil }
            depthSamples.append(s.depth)
            confidenceSamples.append(s.confidence)
        }

        // Camera intrinsics scaled to depth-map resolution.
        let intrinsics = frame.camera.intrinsics
        let imageRes = frame.camera.imageResolution
        let scaleX = Float(dWidth) / Float(imageRes.width)
        let scaleY = Float(dHeight) / Float(imageRes.height)
        let fx = intrinsics[0, 0] * scaleX
        let fy = intrinsics[1, 1] * scaleY
        let cx = intrinsics[2, 0] * scaleX
        let cy = intrinsics[2, 1] * scaleY

        func unproject(px: Int, py: Int, depth: Float) -> SIMD3<Float> {
            // Camera-space 3D point.
            let x = (Float(px) - cx) * depth / fx
            let y = (Float(py) - cy) * depth / fy
            let z = depth
            // Camera convention: +X right, +Y down, +Z forward (image space).
            // ARKit camera transform expects +X right, +Y up, -Z forward —
            // flip Y and Z to match.
            let cameraSpace = SIMD4<Float>(x, -y, -z, 1)
            let worldSpace = frame.camera.transform * cameraSpace
            return SIMD3<Float>(worldSpace.x, worldSpace.y, worldSpace.z)
        }

        let tl = unproject(px: depthPixelCoords[0].0, py: depthPixelCoords[0].1, depth: depthSamples[0])
        let tr = unproject(px: depthPixelCoords[1].0, py: depthPixelCoords[1].1, depth: depthSamples[1])
        let bl = unproject(px: depthPixelCoords[2].0, py: depthPixelCoords[2].1, depth: depthSamples[2])
        let br = unproject(px: depthPixelCoords[3].0, py: depthPixelCoords[3].1, depth: depthSamples[3])
        let centerWorld = unproject(px: depthPixelCoords[4].0,
                                     py: depthPixelCoords[4].1,
                                     depth: depthSamples[4])

        let avgConfidence = confidenceSamples.reduce(0, +) / Float(confidenceSamples.count)

        return CornerSample(tl: tl, tr: tr, bl: bl, br: br,
                            center: centerWorld, confidence: avgConfidence)
    }

    /// Sample depth + confidence at (x, y) with stride-safe access and a small
    /// neighborhood average. Returns nil if no valid (>0) depth was found.
    private func sampleDepth(depthMap: CVPixelBuffer,
                              confidenceMap: CVPixelBuffer?,
                              x: Int, y: Int, radius: Int,
                              width: Int, height: Int) -> (depth: Float, confidence: Float)? {

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let rowStride = bytesPerRow / MemoryLayout<Float32>.size

        var depthSum: Float = 0
        var depthCount: Int = 0

        for dy in -radius...radius {
            for dx in -radius...radius {
                let sx = x + dx
                let sy = y + dy
                guard sx >= 0, sx < width, sy >= 0, sy < height else { continue }
                let ptr = base.advanced(by: sy * bytesPerRow + sx * MemoryLayout<Float32>.size)
                let depth = ptr.assumingMemoryBound(to: Float32.self).pointee
                if depth > 0.05 && depth.isFinite {
                    depthSum += depth
                    depthCount += 1
                }
                _ = rowStride
            }
        }

        guard depthCount > 0 else { return nil }
        let avgDepth = depthSum / Float(depthCount)

        // Confidence map: ARConfidenceLevel is UInt8 with values 0=low, 1=med, 2=high.
        var confidence: Float = 0.5
        if let confidenceMap = confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            if let cBase = CVPixelBufferGetBaseAddress(confidenceMap) {
                let cBytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
                var sum: Int = 0
                var count: Int = 0
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let sx = x + dx
                        let sy = y + dy
                        guard sx >= 0, sx < width, sy >= 0, sy < height else { continue }
                        let ptr = cBase.advanced(by: sy * cBytesPerRow + sx)
                        let level = ptr.assumingMemoryBound(to: UInt8.self).pointee
                        sum += Int(level)
                        count += 1
                    }
                }
                if count > 0 {
                    confidence = Float(sum) / Float(count) / 2.0   // 0..1
                }
            }
        }

        return (avgDepth, confidence)
    }

    // MARK: Rectangle / lock detection

    /// Run Vision rectangle detection on the camera frame, throttled, and
    /// EMA-smooth `lockedQuad` toward any detected drawer-like rectangle.
    private func runRectangleDetection(on frame: ARFrame) {
        let now = frame.timestamp
        guard now - lastRectangleDetection >= rectangleThrottle else { return }
        guard !rectangleDetectionInFlight else { return }
        lastRectangleDetection = now
        rectangleDetectionInFlight = true

        let pixelBuffer = frame.capturedImage
        let displayTransform = frame.displayTransform(for: .portrait,
                                                       viewportSize: viewportSize)
        let currentGuide = guideRect

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            defer { self.rectangleDetectionInFlight = false }

            let request = VNDetectRectanglesRequest()
            request.minimumAspectRatio = 0.25
            request.maximumAspectRatio = 1.0
            request.minimumSize = 0.15
            request.minimumConfidence = 0.6
            request.maximumObservations = 5
            request.quadratureTolerance = 25

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { self.handleDetectionMiss() }
                return
            }

            guard let observations = request.results, !observations.isEmpty else {
                DispatchQueue.main.async { self.handleDetectionMiss() }
                return
            }

            // Convert each observation into a portrait-normalized quad and pick
            // the one whose center is closest to the guide rect's center.
            var candidates: [(quad: NormalizedQuad, score: Double)] = []
            let guideCenter = CGPoint(x: currentGuide.midX, y: currentGuide.midY)

            for obs in observations {
                guard let quad = self.portraitQuad(from: obs,
                                                    displayTransform: displayTransform),
                      quad.isValid else { continue }
                let qc = quad.center
                let center = CGPoint(x: qc.x, y: qc.y)
                let distance = hypot(center.x - guideCenter.x, center.y - guideCenter.y)
                let confidence = Double(obs.confidence)
                // Prefer detections near the guide rect with high confidence.
                let score = confidence - distance * 0.5
                candidates.append((quad, score))
            }

            guard let best = candidates.max(by: { $0.score < $1.score }),
                  best.score > 0.2 else {
                DispatchQueue.main.async { self.handleDetectionMiss() }
                return
            }

            DispatchQueue.main.async { self.handleDetectionHit(best.quad) }
        }
    }

    /// Convert a Vision rectangle observation into a quad in portrait
    /// normalized viewport coords. Returns nil if the conversion is invalid.
    private func portraitQuad(from observation: VNRectangleObservation,
                               displayTransform: CGAffineTransform) -> NormalizedQuad? {
        // Vision returns coords in image normalized space with origin
        // bottom-left. The displayTransform expects top-left origin, so flip Y.
        func toPortrait(_ p: CGPoint) -> CGPoint {
            let imgPoint = CGPoint(x: p.x, y: 1 - p.y)
            return imgPoint.applying(displayTransform)
        }

        let tl = toPortrait(observation.topLeft)
        let tr = toPortrait(observation.topRight)
        let bl = toPortrait(observation.bottomLeft)
        let br = toPortrait(observation.bottomRight)

        return NormalizedQuad(
            topLeft: NormalizedPoint(x: Double(tl.x), y: Double(tl.y)),
            topRight: NormalizedPoint(x: Double(tr.x), y: Double(tr.y)),
            bottomLeft: NormalizedPoint(x: Double(bl.x), y: Double(bl.y)),
            bottomRight: NormalizedPoint(x: Double(br.x), y: Double(br.y))
        )
    }

    private func handleDetectionHit(_ quad: NormalizedQuad) {
        consecutiveDetections = min(consecutiveDetections + 1, 10)
        consecutiveMisses = 0

        // Stronger ease as detections accumulate (alpha = current weight).
        // alpha closer to 0 means snap; closer to 1 means stay.
        let alpha = consecutiveDetections >= 3 ? 0.55 : 0.75
        let target = lockedQuad.eased(toward: quad, alpha: alpha)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            lockedQuad = target
            isLocking = true
            lockProgress = min(1.0, Double(consecutiveDetections) / 5.0)
        }
    }

    private func handleDetectionMiss() {
        consecutiveDetections = max(consecutiveDetections - 1, 0)
        consecutiveMisses = min(consecutiveMisses + 1, 10)

        // After a few misses, decay the lock and ease back toward the guide rect.
        if consecutiveMisses >= 3 {
            let target = NormalizedQuad(
                topLeft: NormalizedPoint(x: guideRect.minX, y: guideRect.minY),
                topRight: NormalizedPoint(x: guideRect.maxX, y: guideRect.minY),
                bottomLeft: NormalizedPoint(x: guideRect.minX, y: guideRect.maxY),
                bottomRight: NormalizedPoint(x: guideRect.maxX, y: guideRect.maxY)
            )
            withAnimation(.easeInOut(duration: 0.4)) {
                lockedQuad = lockedQuad.eased(toward: target, alpha: 0.85)
                isLocking = false
                lockProgress = max(0, lockProgress - 0.1)
            }
        }
    }

    // MARK: Height estimation

    private func estimateDrawerHeight(frame: ARFrame,
                                      floorCenter: SIMD3<Float>) -> (inches: Double, confidence: Double)? {
        // Look for vertical planes whose footprint is reasonably close to the
        // drawer interior point — those are the drawer walls. The drawer rim
        // height is the distance from the floor sample to the top of the
        // closest vertical plane.
        let verticalAnchors = frame.anchors.compactMap { $0 as? ARPlaneAnchor }
            .filter { $0.alignment == .vertical }

        guard !verticalAnchors.isEmpty else { return nil }

        var bestRim: Float?
        var bestConfidence: Double = 0

        for anchor in verticalAnchors {
            let world = anchor.transform.columns.3
            let center = SIMD3<Float>(world.x, world.y, world.z)

            // Horizontal distance from drawer center to plane center.
            let dx = center.x - floorCenter.x
            let dz = center.z - floorCenter.z
            let horizontalDist = sqrtf(dx * dx + dz * dz)

            // Drawer walls should be within ~24" (0.6m) of the drawer interior.
            guard horizontalDist < 0.6 else { continue }

            // Height of plane *above* the floor sample, plus half the plane
            // extent along Y (vertical) gives an approximation of the rim.
            let planeTopY = center.y + anchor.planeExtent.height / 2
            let rim = planeTopY - floorCenter.y

            // Drawers are usually 1.5"–10" deep.
            if rim > 0.03, rim < 0.30 {
                let conf = max(0.0, 1.0 - Double(horizontalDist / 0.6))
                if conf > bestConfidence {
                    bestRim = rim
                    bestConfidence = conf
                }
            }
        }

        guard let rim = bestRim else { return nil }
        return (Double(rim) * 39.3701, bestConfidence)
    }

    // MARK: History / stability

    private func appendMeasurement(_ m: DrawerMeasurement) {
        measurementHistory.append(m)
        if measurementHistory.count > historyCapacity {
            measurementHistory.removeFirst(measurementHistory.count - historyCapacity)
        }
    }

    private func averagedMeasurement() -> DrawerMeasurement? {
        guard !measurementHistory.isEmpty else { return nil }
        let n = Double(measurementHistory.count)
        let w = measurementHistory.map { $0.widthInches }.reduce(0, +) / n
        let d = measurementHistory.map { $0.depthInches }.reduce(0, +) / n
        let h = measurementHistory.map { $0.heightInches }.reduce(0, +) / n
        let measured = measurementHistory.contains { $0.heightMeasured }
        let conf = measurementHistory.map { $0.confidenceScore }.reduce(0, +) / n
        return DrawerMeasurement(
            widthInches: w,
            depthInches: d,
            heightInches: h,
            source: .lidar,
            confidenceScore: conf,
            heightMeasured: measured
        )
    }

    /// 0..1 — higher means measurements have stopped wobbling.
    private func stabilityScore() -> Double {
        guard measurementHistory.count >= 4 else { return 0 }
        let widths = measurementHistory.map { $0.widthInches }
        let depths = measurementHistory.map { $0.depthInches }
        let wStd = standardDeviation(widths)
        let dStd = standardDeviation(depths)
        let avg = (wStd + dStd) / 2
        // Std dev of <0.25" → very stable; >2" → unstable.
        let normalized = max(0, min(1, 1 - (avg / 2.0)))
        return normalized
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return sqrt(variance)
    }

    private func combinedConfidence(tracking: Double,
                                    depth: Double,
                                    stability: Double) -> Double {
        // Weighted average — tracking and depth are gates.
        let base = (tracking * 0.35 + depth * 0.35 + stability * 0.30)
        return max(0, min(1, base))
    }
}

// MARK: - Helpers

private extension CGFloat {
    func clamped(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
        Swift.max(low, Swift.min(high, self))
    }
}

private extension CGAffineTransform {
    /// Returns nil if the transform's determinant is ~0 (non-invertible).
    func nonIdentity() -> CGAffineTransform? {
        let det = a * d - b * c
        return abs(det) < 1e-6 ? nil : self
    }
}

// MARK: - AR Camera Preview (UIViewRepresentable)

/// ARSCNView-based preview. We don't render any nodes — we just need the
/// camera feed displayed. Sharing a single ARSession with `LiDARScanService`
/// keeps live measurement and preview in lockstep.
struct ARCameraPreview: UIViewRepresentable {
    let session: ARSession
    var onViewSizeChange: ((CGSize) -> Void)? = nil

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.automaticallyUpdatesLighting = false
        view.scene = SCNScene()
        view.rendersContinuously = true
        view.backgroundColor = .black
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        DispatchQueue.main.async {
            onViewSizeChange?(uiView.bounds.size)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, ARSCNViewDelegate {}
}
