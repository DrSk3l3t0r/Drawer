//
//  PurposeSelectionView.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI

struct PurposeSelectionView: View {
    let measurement: DrawerMeasurement
    let capturedImage: UIImage?
    @Binding var navigateToLayout: Bool
    @Binding var generatedLayout: DrawerLayout?

    @State private var selectedPurpose: DrawerPurpose?
    @State private var isGenerating = false
    @State private var customName: String = ""
    @State private var showCustomInput = false
    @State private var hasAppeared = false
    @Environment(\.dismiss) private var dismiss

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                drawerSummary
                purposeGrid

                if let purpose = selectedPurpose, showCustomInput && purpose == .custom {
                    customInputSection
                }

                generateButton
                    .padding(.bottom, 30)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: selectedPurpose)
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

            Text("Drawer Purpose")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: - Drawer Summary

    private var drawerSummary: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 60, height: 40)

                VStack(spacing: 2) {
                    Text(measurement.formattedWidth)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    Text("×")
                        .font(.system(size: 8))
                    Text(measurement.formattedDepth)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Drawer")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("\(measurement.formattedWidth) × \(measurement.formattedDepth) × \(measurement.formattedHeight)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.05))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Purpose Grid

    private var purposeGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(DrawerPurpose.allCases.enumerated()), id: \.element.id) { index, purpose in
                PurposeCard(
                    purpose: purpose,
                    isSelected: selectedPurpose == purpose,
                    action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            if purpose == .custom {
                                showCustomInput = true
                            } else {
                                showCustomInput = false
                            }
                            selectedPurpose = purpose
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                )
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1 : 0.92)
                .offset(y: hasAppeared ? 0 : 10)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.78)
                        .delay(0.04 * Double(index)),
                    value: hasAppeared
                )
            }
        }
        .padding(.horizontal, 20)
        .onAppear { hasAppeared = true }
    }

    // MARK: - Custom Input

    private var customInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Category Name")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))

            TextField("e.g., Art Supplies", text: $customName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.08))
                )
                .foregroundStyle(.white)
                .tint(.blue)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button(action: generateLayout) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(isGenerating ? "Generating…" : "Generate Layout")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if let purpose = selectedPurpose {
                        LinearGradient(
                            colors: [purpose.color, purpose.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: (selectedPurpose?.color ?? .clear).opacity(0.4),
                    radius: 12, y: 6)
            .scaleEffect(isGenerating ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGenerating)
        }
        .disabled(selectedPurpose == nil || isGenerating)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    // MARK: - Generate

    private func generateLayout() {
        guard let purpose = selectedPurpose else { return }
        isGenerating = true
        let impact = UINotificationFeedbackGenerator()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Start with the recommended set, sized to the drawer (smaller
            // drawers get fewer pre-selected items; larger drawers get the
            // full catalog so the engine has more to pack with). The layout
            // result editor lets the user add/remove specific organizers
            // afterwards.
            let drawerArea = measurement.widthInches * measurement.depthInches
            let layout = LayoutEngine.generateLayout(
                measurement: measurement,
                purpose: purpose,
                selectedIds: LayoutEngine.recommendedIds(
                    for: purpose,
                    drawerArea: drawerArea
                )
            )
            generatedLayout = layout
            isGenerating = false
            impact.notificationOccurred(.success)
            navigateToLayout = true
        }
    }
}

// MARK: - Purpose Card

struct PurposeCard: View {
    let purpose: DrawerPurpose
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(purpose.color.opacity(isSelected ? 0.3 : 0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: purpose.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(purpose.color)
                        .scaleEffect(isSelected ? 1.12 : 1.0)
                        .symbolEffect(.bounce, value: isSelected)
                }

                Text(purpose.rawValue)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text(purpose.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(isSelected ? 0.1 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? purpose.color : .clear, lineWidth: 2)
                    )
                    .shadow(color: isSelected ? purpose.color.opacity(0.35) : .clear,
                            radius: 14, y: 6)
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Organizer Selection Row

struct OrganizerSelectionRow: View {
    let template: OrganizerTemplate
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hue: template.hue, saturation: 0.55, brightness: 0.85)
                            .opacity(isSelected ? 0.85 : 0.35))
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(String(format: "%.1f\" × %.1f\"", template.width, template.height))
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                if template.isRecommended {
                    Text("REC")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(isSelected ? 0.1 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? accent : .clear, lineWidth: 1.5)
                    )
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
