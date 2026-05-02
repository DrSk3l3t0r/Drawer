//
//  ObstacleMarkingView.swift
//  Drawer
//
//  Lets the user mark "keep-out" zones in the drawer — raised areas, rails,
//  drain holes, plastic feet, dishwasher screws, etc. — that an organizer
//  can't sit on top of. The layout engine uses these as forbidden rectangles
//  when packing.
//
//  Presented as a sheet from `MeasurementReviewView`. Operates on a top-down
//  representation of the drawer (not the live photo) for simplicity — adding
//  perspective-correct annotation on the photo would be a significantly
//  bigger lift and isn't needed for accuracy here, since the obstacles are
//  defined in inch-coordinates anyway.
//

import SwiftUI

struct ObstacleMarkingView: View {
    @Binding var measurement: DrawerMeasurement
    @Environment(\.dismiss) private var dismiss
    @State private var draftObstacles: [DrawerObstacle] = []
    @State private var draggingId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var newObstacleStart: CGPoint?
    @State private var newObstacleEnd: CGPoint?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                instructionsHeader

                GeometryReader { geo in
                    drawerCanvas(in: geo.size)
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)

                obstaclesList
                actionButtons
            }
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "0D1117"), Color(hex: "161B22")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Drawer obstacles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAndDismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear { draftObstacles = measurement.obstacles }
    }

    // MARK: - Header

    private var instructionsHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mark areas an organizer can't sit on")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text("Drag on the drawer to draw a forbidden zone. The layout engine will route around these when generating your design.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    // MARK: - Drawer canvas

    /// Top-down view of the drawer rectangle, scaled to the available area.
    /// Tap-and-drag adds a new obstacle; existing ones can be selected and
    /// dragged or deleted.
    private func drawerCanvas(in size: CGSize) -> some View {
        let drawerW = max(1, measurement.widthInches)
        let drawerD = max(1, measurement.depthInches)
        let aspect = drawerW / drawerD
        let scale = aspect >= 1
            ? min(size.width, size.height * aspect) / drawerW
            : min(size.height, size.width / aspect) / drawerD
        let renderW = drawerW * scale
        let renderH = drawerD * scale
        let originX = (size.width - renderW) / 2
        let originY = (size.height - renderH) / 2

        return ZStack(alignment: .topLeading) {
            // Drawer background
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(0.4), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "0A1628"))
                )
                .frame(width: renderW, height: renderH)
                .offset(x: originX, y: originY)
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            // Start a new obstacle if the touch began inside the
                            // drawer rectangle. Track both ends to draw the
                            // rubber-band rectangle.
                            let p = CGPoint(x: value.startLocation.x - originX,
                                            y: value.startLocation.y - originY)
                            let q = CGPoint(x: value.location.x - originX,
                                            y: value.location.y - originY)
                            if p.x >= 0 && p.x <= renderW && p.y >= 0 && p.y <= renderH {
                                newObstacleStart = p
                                newObstacleEnd = q
                            }
                        }
                        .onEnded { _ in
                            commitNewObstacle(scale: scale)
                        }
                )

            // Existing obstacles
            ForEach(draftObstacles) { obstacle in
                obstacleRect(obstacle, scale: scale,
                              originX: originX, originY: originY)
            }

            // In-progress new obstacle
            if let s = newObstacleStart, let e = newObstacleEnd {
                let r = CGRect(
                    x: min(s.x, e.x),
                    y: min(s.y, e.y),
                    width: abs(s.x - e.x),
                    height: abs(s.y - e.y)
                )
                Rectangle()
                    .fill(Color.red.opacity(0.25))
                    .overlay(Rectangle().strokeBorder(.red, lineWidth: 1.5))
                    .frame(width: r.width, height: r.height)
                    .offset(x: originX + r.minX, y: originY + r.minY)
                    .allowsHitTesting(false)
            }
        }
    }

    private func obstacleRect(_ obstacle: DrawerObstacle,
                                scale: Double,
                                originX: Double, originY: Double) -> some View {
        let isDragging = draggingId == obstacle.id
        let extraOffset = isDragging ? dragOffset : .zero

        return Rectangle()
            .fill(Color.red.opacity(0.40))
            .overlay(
                Rectangle().strokeBorder(.red.opacity(0.9), lineWidth: 1.5)
            )
            .frame(width: obstacle.width * scale,
                   height: obstacle.height * scale)
            .overlay(alignment: .topTrailing) {
                Button { delete(obstacle) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(Circle().fill(.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
            .offset(
                x: originX + obstacle.x * scale + extraOffset.width,
                y: originY + obstacle.y * scale + extraOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        draggingId = obstacle.id
                        dragOffset = value.translation
                    }
                    .onEnded { _ in
                        commitDrag(for: obstacle, scale: scale)
                        draggingId = nil
                        dragOffset = .zero
                    }
            )
    }

    private func commitNewObstacle(scale: Double) {
        guard let s = newObstacleStart, let e = newObstacleEnd else { return }
        let xMin = min(s.x, e.x) / scale
        let yMin = min(s.y, e.y) / scale
        let w = abs(s.x - e.x) / scale
        let h = abs(s.y - e.y) / scale
        // Reject tiny accidental drags.
        if w >= 0.4 && h >= 0.4 {
            let obs = DrawerObstacle(
                name: "Obstacle \(draftObstacles.count + 1)",
                x: xMin, y: yMin,
                width: w, height: h
            )
            draftObstacles.append(obs)
            UISelectionFeedbackGenerator().selectionChanged()
        }
        newObstacleStart = nil
        newObstacleEnd = nil
    }

    private func commitDrag(for obstacle: DrawerObstacle, scale: Double) {
        guard let idx = draftObstacles.firstIndex(where: { $0.id == obstacle.id })
        else { return }
        let dxIn = dragOffset.width / scale
        let dyIn = dragOffset.height / scale
        var updated = draftObstacles[idx]
        updated.x = max(0, min(measurement.widthInches - updated.width,
                                updated.x + dxIn))
        updated.y = max(0, min(measurement.depthInches - updated.height,
                                updated.y + dyIn))
        draftObstacles[idx] = updated
    }

    // MARK: - List + actions

    private var obstaclesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(draftObstacles.count) obstacle\(draftObstacles.count == 1 ? "" : "s")")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))

            if draftObstacles.isEmpty {
                Text("No obstacles yet — drag on the drawer above to add one.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(draftObstacles) { o in
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(.red.opacity(0.4))
                            .frame(width: 12, height: 12)
                        Text(o.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(String(format: "%.1f×%.1f at (%.1f,%.1f)",
                                    o.width, o.height, o.x, o.y))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.white.opacity(0.45))
                        Button { delete(o) } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var actionButtons: some View {
        Button {
            draftObstacles.removeAll()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Label("Clear all", systemImage: "trash")
                .font(.caption.bold())
                .foregroundStyle(.red.opacity(0.85))
        }
        .padding(.bottom, 4)
        .opacity(draftObstacles.isEmpty ? 0 : 1)
        .disabled(draftObstacles.isEmpty)
    }

    private func delete(_ obstacle: DrawerObstacle) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        draftObstacles.removeAll { $0.id == obstacle.id }
    }

    private func saveAndDismiss() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        measurement.obstacles = draftObstacles
        dismiss()
    }
}
