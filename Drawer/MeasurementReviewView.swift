//
//  MeasurementReviewView.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI

struct MeasurementReviewView: View {
    let image: UIImage?
    @Binding var measurement: DrawerMeasurement
    @Binding var navigateToPurpose: Bool

    @State private var isMetric = false
    @State private var showObstacles = false
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    enum Field: Hashable { case width, depth, height }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                // Always-visible verification banner so the user knows what
                // the result actually is.
                sourceBanner

                photoSection
                measurementCards
                confidenceSection
                manualEntrySection
                adjustmentSection
                obstaclesSummary
                continueButton
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "0D1117")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .sheet(isPresented: $showObstacles) {
            ObstacleMarkingView(measurement: $measurement)
        }
    }

    /// Summary card + entry point for the obstacle-marking sheet. Sits just
    /// above the Continue button so users can opt into it without leaving
    /// the review screen.
    private var obstaclesSummary: some View {
        Button {
            showObstacles = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.orange.opacity(0.15)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(measurement.obstacles.isEmpty
                         ? "Mark drawer obstacles"
                         : "\(measurement.obstacles.count) obstacle\(measurement.obstacles.count == 1 ? "" : "s") marked")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(measurement.obstacles.isEmpty
                         ? "Optional — tag rails, drain holes, or raised areas the layout should avoid"
                         : "Tap to edit forbidden zones")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(measurement.obstacles.isEmpty
                                    ? .white.opacity(0.06)
                                    : .orange.opacity(0.3),
                                    lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Text("Review Measurements")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button(action: { withAnimation { isMetric.toggle() } }) {
                Text(isMetric ? "cm" : "in")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: - Source banner

    private var sourceBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: measurement.source.icon)
                .font(.system(size: 18))
                .foregroundStyle(sourceTint)

            VStack(alignment: .leading, spacing: 2) {
                Text(measurement.source.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(sourceSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if !measurement.source.isMeasured {
                Button(action: { dismiss() }) {
                    Label("Retake", systemImage: "camera.viewfinder")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(sourceTint.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(sourceTint.opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var sourceTint: Color {
        switch measurement.source {
        case .lidar: return .green
        case .cameraReference: return .blue
        case .manual: return Color(hue: 0.6, saturation: 0.7, brightness: 0.95)
        case .cameraEstimate: return .orange
        case .defaultEstimate: return .red
        }
    }

    private var sourceSubtitle: String {
        switch measurement.source {
        case .lidar:
            return "Captured with depth sensor — verify and adjust if needed"
        case .cameraReference:
            return "Estimated using credit-card scale — please verify"
        case .manual:
            return "Manually entered dimensions"
        case .cameraEstimate:
            return "Rough camera estimate — please correct manually"
        case .defaultEstimate:
            return "No measurement was captured — enter dimensions below"
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        DrawerDimensionOverlay(
                            measurement: measurement,
                            isMetric: isMetric
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.gray.opacity(0.3))
                    .aspectRatio(4/3, contentMode: .fit)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray)
                            Text("No photo available")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Measurement Cards

    private var measurementCards: some View {
        HStack(spacing: 12) {
            MeasurementCard(
                title: "Width",
                value: isMetric ? measurement.widthCm : measurement.widthInches,
                unit: isMetric ? "cm" : "\"",
                icon: "arrow.left.and.right",
                color: Color(hue: 0.55, saturation: 0.7, brightness: 0.9)
            )

            MeasurementCard(
                title: "Depth",
                value: isMetric ? measurement.depthCm : measurement.depthInches,
                unit: isMetric ? "cm" : "\"",
                icon: "arrow.up.and.down",
                color: Color(hue: 0.3, saturation: 0.7, brightness: 0.85)
            )

            MeasurementCard(
                title: "Height",
                value: isMetric ? measurement.heightCm : measurement.heightInches,
                unit: isMetric ? "cm" : "\"",
                icon: "arrow.up.to.line",
                color: Color(hue: 0.08, saturation: 0.7, brightness: 0.95)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Confidence

    private var confidenceSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: measurement.source.icon)
                    .foregroundStyle(sourceTint)
                Text(measurement.source.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(measurement.confidenceScore * 100))% confidence")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(confidenceColor)
                        .frame(width: max(0, geo.size.width * measurement.confidenceScore), height: 6)
                }
            }
            .frame(height: 6)

            if !measurement.heightMeasured {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                    Text("Height was not measured — please verify the value below.")
                }
                .font(.caption)
                .foregroundStyle(.yellow.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var confidenceColor: Color {
        if measurement.confidenceScore > 0.7 { return .green }
        if measurement.confidenceScore > 0.4 { return .orange }
        return .red
    }

    // MARK: - Manual entry

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exact Dimensions")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 10) {
                NumericField(
                    label: "W",
                    value: Binding(get: { displayValue(measurement.widthInches) },
                                   set: { setWidth(fromDisplay: $0) }),
                    suffix: isMetric ? "cm" : "in",
                    focused: $focusedField,
                    field: .width
                )
                NumericField(
                    label: "D",
                    value: Binding(get: { displayValue(measurement.depthInches) },
                                   set: { setDepth(fromDisplay: $0) }),
                    suffix: isMetric ? "cm" : "in",
                    focused: $focusedField,
                    field: .depth
                )
                NumericField(
                    label: "H",
                    value: Binding(get: { displayValue(measurement.heightInches) },
                                   set: { setHeight(fromDisplay: $0) }),
                    suffix: isMetric ? "cm" : "in",
                    focused: $focusedField,
                    field: .height
                )
            }

            Text("Editing any value marks the measurement as manually verified.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func displayValue(_ inches: Double) -> Double {
        isMetric ? inches * 2.54 : inches
    }

    private func toInches(_ display: Double) -> Double {
        isMetric ? display / 2.54 : display
    }

    private func setWidth(fromDisplay v: Double) {
        let inches = toInches(v)
        guard inches.isFinite, inches >= 0 else { return }
        if abs(inches - measurement.widthInches) > 0.001 {
            measurement.widthInches = inches
            markManual()
        }
    }

    private func setDepth(fromDisplay v: Double) {
        let inches = toInches(v)
        guard inches.isFinite, inches >= 0 else { return }
        if abs(inches - measurement.depthInches) > 0.001 {
            measurement.depthInches = inches
            markManual()
        }
    }

    private func setHeight(fromDisplay v: Double) {
        let inches = toInches(v)
        guard inches.isFinite, inches >= 0 else { return }
        if abs(inches - measurement.heightInches) > 0.001 {
            measurement.heightInches = inches
            measurement.heightMeasured = true
            markManual()
        }
    }

    private func markManual() {
        // Only escalate to .manual when the user actually edits a value;
        // keep .lidar / .cameraReference labels otherwise.
        if measurement.source == .defaultEstimate || measurement.source == .cameraEstimate {
            measurement.source = .manual
            measurement.confidenceScore = 1.0
        }
    }

    // MARK: - Adjustment sliders

    private var adjustmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Adjust")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.8))

            AdjustmentSlider(label: "Width",
                             value: Binding(get: { measurement.widthInches },
                                            set: { measurement.widthInches = $0; markManual() }),
                             range: 4...36, unit: "\"")
            AdjustmentSlider(label: "Depth",
                             value: Binding(get: { measurement.depthInches },
                                            set: { measurement.depthInches = $0; markManual() }),
                             range: 4...30, unit: "\"")
            AdjustmentSlider(label: "Height",
                             value: Binding(get: { measurement.heightInches },
                                            set: {
                                 measurement.heightInches = $0
                                 measurement.heightMeasured = true
                                 markManual()
                             }),
                             range: 1...12, unit: "\"")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: { navigateToPurpose = true }) {
            HStack {
                Text("Choose Drawer Purpose")
                    .font(.headline)
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hue: 0.6, saturation: 0.8, brightness: 0.9),
                             Color(hue: 0.7, saturation: 0.7, brightness: 0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(hue: 0.65, saturation: 0.8, brightness: 0.9).opacity(0.4),
                    radius: 12, y: 6)
        }
        .disabled(!isMeasurementValid)
        .opacity(isMeasurementValid ? 1 : 0.5)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    private var isMeasurementValid: Bool {
        measurement.widthInches >= 3 &&
        measurement.depthInches >= 3 &&
        measurement.heightInches >= 0.5 &&
        measurement.widthInches <= 60 &&
        measurement.depthInches <= 40 &&
        measurement.heightInches <= 24
    }
}

// MARK: - Numeric Field

private struct NumericField: View {
    let label: String
    @Binding var value: Double
    let suffix: String
    var focused: FocusState<MeasurementReviewView.Field?>.Binding
    let field: MeasurementReviewView.Field

    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 4) {
                TextField("", text: $text, prompt: Text("0.0")
                    .foregroundColor(.white.opacity(0.3)))
                    .keyboardType(.decimalPad)
                    .focused(focused, equals: field)
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .onAppear { text = formatted(value) }
                    .onChange(of: value) { _, new in
                        if focused.wrappedValue != field {
                            text = formatted(new)
                        }
                    }
                    .onChange(of: text) { _, new in
                        let normalized = new.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(normalized) {
                            value = v
                        } else if new.isEmpty {
                            value = 0
                        }
                    }
                Text(suffix)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focused.wrappedValue == field
                                ? Color(hue: 0.6, saturation: 0.7, brightness: 0.9)
                                : .clear,
                                lineWidth: 1.5)
                )
        )
    }

    private func formatted(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
}

// MARK: - Drawer Dimension Overlay (review)

/// Draws the captured drawer quad over the photo and scales it with current
/// dimension values. The original (LiDAR / camera) quad is shown as a faint
/// ghost so the user can see the difference between the captured measurement
/// and any manual adjustments they've made.
struct DrawerDimensionOverlay: View {
    let measurement: DrawerMeasurement
    let isMetric: Bool

    private var hasQuad: Bool { measurement.capturedQuad != nil }

    var body: some View {
        GeometryReader { geo in
            if let quad = measurement.capturedQuad {
                ZStack {
                    // Original captured outline (faint ghost)
                    QuadOutline(quad: quad, dashed: true,
                                color: .white.opacity(0.35), lineWidth: 1.2)

                    // Adjusted outline (scales with manual edits)
                    let adjusted = quad.scaled(
                        widthFactor: measurement.widthScaleFactor,
                        heightFactor: measurement.depthScaleFactor
                    )
                    QuadOutline(quad: adjusted, dashed: false,
                                color: accentColor, lineWidth: 2.2)
                        .shadow(color: accentColor.opacity(0.6), radius: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85),
                                   value: measurement.widthScaleFactor)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85),
                                   value: measurement.depthScaleFactor)

                    // Width label centered along top edge of adjusted quad
                    EdgeCallout(
                        start: adjusted.cgPoint(for: .topLeft, in: geo.size),
                        end: adjusted.cgPoint(for: .topRight, in: geo.size),
                        text: formatted(value: isMetric ? measurement.widthCm : measurement.widthInches,
                                        unit: isMetric ? "cm" : "in"),
                        accent: accentColor,
                        side: .top
                    )

                    // Depth label centered along left edge
                    EdgeCallout(
                        start: adjusted.cgPoint(for: .topLeft, in: geo.size),
                        end: adjusted.cgPoint(for: .bottomLeft, in: geo.size),
                        text: formatted(value: isMetric ? measurement.depthCm : measurement.depthInches,
                                        unit: isMetric ? "cm" : "in"),
                        accent: accentColor,
                        side: .left
                    )

                    // Corner dots
                    ForEach(NormalizedQuad.Corner.allCases, id: \.self) { corner in
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .position(adjusted.cgPoint(for: corner, in: geo.size))
                    }

                    // Height badge in a top corner
                    HeightBadge(
                        value: isMetric ? measurement.heightCm : measurement.heightInches,
                        unit: isMetric ? "cm" : "in",
                        measured: measurement.heightMeasured,
                        accent: accentColor
                    )
                    .position(x: 56, y: 24)
                }
            } else {
                // No quad available — fall back to corner labels.
                ZStack {
                    DimensionLabel(
                        value: isMetric ? measurement.widthCm : measurement.widthInches,
                        unit: isMetric ? "cm" : "in",
                        label: "Width"
                    )
                    .position(x: geo.size.width / 2, y: 24)

                    DimensionLabel(
                        value: isMetric ? measurement.depthCm : measurement.depthInches,
                        unit: isMetric ? "cm" : "in",
                        label: "Depth"
                    )
                    .position(x: geo.size.width - 50, y: geo.size.height / 2)

                    DimensionLabel(
                        value: isMetric ? measurement.heightCm : measurement.heightInches,
                        unit: isMetric ? "cm" : "in",
                        label: "Height"
                    )
                    .position(x: 50, y: geo.size.height - 24)
                }
            }
        }
    }

    private var accentColor: Color {
        switch measurement.source {
        case .lidar: return .green
        case .cameraReference: return Color(hue: 0.55, saturation: 0.7, brightness: 0.95)
        case .manual: return Color(hue: 0.6, saturation: 0.7, brightness: 0.95)
        case .cameraEstimate: return .orange
        case .defaultEstimate: return .red
        }
    }

    private func formatted(value: Double, unit: String) -> String {
        String(format: "%.1f %@", value, unit)
    }
}

private struct QuadOutline: View {
    let quad: NormalizedQuad
    let dashed: Bool
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let size = geo.size
                path.move(to: quad.cgPoint(for: .topLeft, in: size))
                path.addLine(to: quad.cgPoint(for: .topRight, in: size))
                path.addLine(to: quad.cgPoint(for: .bottomRight, in: size))
                path.addLine(to: quad.cgPoint(for: .bottomLeft, in: size))
                path.closeSubpath()
            }
            .stroke(color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: dashed ? [6, 4] : []
                    ))
        }
    }
}

private struct EdgeCallout: View {
    let start: CGPoint
    let end: CGPoint
    let text: String
    let accent: Color
    let side: Side

    enum Side { case top, left }

    var body: some View {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let offset: CGSize = side == .top ? CGSize(width: 0, height: -22)
                                          : CGSize(width: -32, height: 0)
        return Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.black.opacity(0.7))
                    .overlay(Capsule().stroke(accent.opacity(0.6), lineWidth: 1))
            )
            .position(x: mid.x + offset.width, y: mid.y + offset.height)
    }
}

private struct HeightBadge: View {
    let value: Double
    let unit: String
    let measured: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.to.line")
                .font(.system(size: 10, weight: .heavy))
            Text(String(format: "H %.1f %@", value, unit))
                .font(.system(size: 11, weight: .bold, design: .rounded))
            if !measured {
                Text("est")
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.yellow.opacity(0.85))
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.7))
                .overlay(Capsule().stroke(accent.opacity(0.6), lineWidth: 1))
        )
    }
}

// MARK: - Supporting Views

struct DimensionLabel: View {
    let value: Double
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
            Text(String(format: "%.1f%@", value, unit))
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct MeasurementCard: View {
    let title: String
    let value: Double
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(String(format: "%.1f", value))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("\(title) (\(unit))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct AdjustmentSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 50, alignment: .leading)

            Slider(value: $value, in: range, step: 0.5)
                .tint(Color(hue: 0.6, saturation: 0.7, brightness: 0.9))

            Text(String(format: "%.1f%@", value, unit))
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
