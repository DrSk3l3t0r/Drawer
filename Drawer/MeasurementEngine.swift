//
//  MeasurementEngine.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import UIKit
import Vision
import CoreImage

// MARK: - Measurement Engine

enum MeasurementError: Error, LocalizedError {
    case noImage
    case noRectangle
    case visionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noImage: return "No image to analyze"
        case .noRectangle: return "Couldn't find a rectangular shape in the photo"
        case .visionFailed(let e): return "Detection failed: \(e.localizedDescription)"
        }
    }
}

class MeasurementEngine {

    // Credit card dimensions in inches (ISO/IEC 7810 ID-1)
    static let creditCardWidth: Double = 3.370
    static let creditCardHeight: Double = 2.125

    // MARK: - LiDAR Measurement

    /// Wrap a LiDAR-derived plane size into a `DrawerMeasurement`.
    /// Used for legacy/test paths; the live `LiDARScanService` returns the
    /// measurement directly.
    static func measureFromLiDAR(planeSize: CGSize,
                                 estimatedHeight: Double = 4.0,
                                 confidence: Double = 0.85) -> DrawerMeasurement {
        DrawerMeasurement(
            widthInches: planeSize.width,
            depthInches: planeSize.height,
            heightInches: estimatedHeight,
            source: .lidar,
            confidenceScore: confidence,
            heightMeasured: false
        )
    }

    // MARK: - Vision-Based Measurement (Camera Only)

    /// Detect rectangles in `image` and estimate drawer dimensions using a
    /// credit card as a scale reference. Returns:
    ///   - `.success(measurement)` when a reference object scaled the result;
    ///     measurement source is `.cameraReference`.
    ///   - `.failure` when no reference was found — caller should ask the
    ///     user to enter dimensions manually instead of pretending a default
    ///     was a measurement.
    static func measureFromImage(_ image: UIImage,
                                  completion: @escaping (Result<DrawerMeasurement, MeasurementError>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(.noImage))
            return
        }

        let request = VNDetectRectanglesRequest { request, error in
            if let error = error {
                completion(.failure(.visionFailed(error)))
                return
            }
            guard let results = request.results as? [VNRectangleObservation],
                  !results.isEmpty else {
                completion(.failure(.noRectangle))
                return
            }

            // Sort by area — largest is likely the drawer, second a reference.
            let sorted = results.sorted {
                $0.boundingBox.width * $0.boundingBox.height >
                $1.boundingBox.width * $1.boundingBox.height
            }

            let imageWidth = Double(cgImage.width)
            let imageHeight = Double(cgImage.height)

            if sorted.count >= 2 {
                let drawerRect = sorted[0]
                let refRect = sorted[1]

                let refPixelWidth = refRect.boundingBox.width * imageWidth
                let refPixelHeight = refRect.boundingBox.height * imageHeight
                // Pick the longer side as credit card width.
                let refLong = max(refPixelWidth, refPixelHeight)
                let refShort = min(refPixelWidth, refPixelHeight)
                let scaleLong = refLong / creditCardWidth
                let scaleShort = refShort / creditCardHeight
                let scale = (scaleLong + scaleShort) / 2.0

                guard scale.isFinite, scale > 0 else {
                    completion(.failure(.noRectangle))
                    return
                }

                let drawerPixelWidth = drawerRect.boundingBox.width * imageWidth
                let drawerPixelHeight = drawerRect.boundingBox.height * imageHeight

                let widthInches = drawerPixelWidth / scale
                let depthInches = drawerPixelHeight / scale

                // Sanity: reject obviously wrong values.
                guard widthInches.isFinite, depthInches.isFinite,
                      widthInches > 3, widthInches < 60,
                      depthInches > 3, depthInches < 40 else {
                    completion(.failure(.noRectangle))
                    return
                }

                let measurement = DrawerMeasurement(
                    widthInches: widthInches,
                    depthInches: depthInches,
                    heightInches: 4.0,
                    source: .cameraReference,
                    confidenceScore: min(Double(drawerRect.confidence + refRect.confidence) / 2.0, 1.0),
                    heightMeasured: false
                )
                completion(.success(measurement))
            } else {
                // No reference object — we can't honestly produce a real
                // measurement, so signal failure and let the user enter
                // dimensions manually.
                completion(.failure(.noRectangle))
            }
        }

        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.05
        request.maximumObservations = 10
        request.minimumConfidence = 0.3

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(.visionFailed(error)))
            }
        }
    }

    // MARK: - Default Measurement

    /// Fallback for when no detection ran at all — explicitly labeled as a
    /// `.defaultEstimate` so the UI can prompt the user to verify/correct.
    static func createDefaultMeasurement() -> DrawerMeasurement {
        DrawerMeasurement(
            widthInches: 15.0,
            depthInches: 20.0,
            heightInches: 4.0,
            source: .defaultEstimate,
            confidenceScore: 0.0,
            heightMeasured: false
        )
    }
}
