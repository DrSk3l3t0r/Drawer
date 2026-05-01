//
//  EditOrganizersSheet.swift
//  Drawer
//
//  Post-layout editor: add and remove specific organizer modules from the
//  current `DrawerLayout`. Module availability is gated on whether the
//  module fits within the drawer's remaining space.
//

import SwiftUI

struct EditOrganizersSheet: View {
    @Binding var layout: DrawerLayout
    /// Called whenever the layout meaningfully changes — used by the parent
    /// view to bump animation stamps.
    var onChange: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var allTemplates: [OrganizerTemplate] {
        LayoutEngine.templates(for: layout.purpose)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    summaryHeader
                    placedSection
                    catalogSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "0D1117"), Color(hex: "161B22")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Edit Organizers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Summary

    private var summaryHeader: some View {
        let summary = LayoutEngine.fitSummary(for: layout)
        let coveragePct = Int(summary.coverage * 100)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(summary.placedCount) organizers")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(String(format: "%.1f sq in free • %d%% used",
                            summary.freeAreaSqInches, coveragePct))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            CoverageRing(value: summary.coverage, accent: layout.purpose.color)
                .frame(width: 44, height: 44)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(layout.purpose.color.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Placed list

    private var placedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(label: "In Drawer", trailing: "\(layout.items.count)",
                          trailingColor: layout.purpose.color)

            if layout.items.isEmpty {
                Text("No organizers placed yet — add some below.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 8) {
                    ForEach(layout.items) { item in
                        PlacedItemRow(item: item, accent: layout.purpose.color) {
                            removeItem(item.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Catalog

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(label: "Available Modules",
                          trailing: "\(layout.purpose.rawValue)",
                          trailingColor: layout.purpose.color.opacity(0.8))

            VStack(spacing: 8) {
                ForEach(allTemplates) { template in
                    let fit = LayoutEngine.canAdd(template, to: layout)
                    CatalogRow(
                        template: template,
                        fit: fit,
                        accent: layout.purpose.color
                    ) {
                        addTemplate(template)
                    }
                }
            }
        }
    }

    // MARK: - Mutations

    private func addTemplate(_ template: OrganizerTemplate) {
        UISelectionFeedbackGenerator().selectionChanged()
        guard let updated = LayoutEngine.adding(template, to: layout) else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            layout = updated
        }
        onChange?()
    }

    private func removeItem(_ id: OrganizerItem.ID) {
        UISelectionFeedbackGenerator().selectionChanged()
        let updated = LayoutEngine.removingItem(id, from: layout)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            layout = updated
        }
        onChange?()
    }
}

// MARK: - Placed item row

private struct PlacedItemRow: View {
    let item: OrganizerItem
    let accent: Color
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(item.color)
                .frame(width: 20, height: 20)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(.white.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(String(format: "%.1f\" × %.1f\"", item.width, item.height))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red.opacity(0.9))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.04))
        )
    }
}

// MARK: - Catalog row

private struct CatalogRow: View {
    let template: OrganizerTemplate
    let fit: LayoutEngine.FitResult
    let accent: Color
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hue: template.hue, saturation: 0.55, brightness: 0.85)
                        .opacity(fit.canAdd ? 0.85 : 0.3))
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(fit.canAdd ? 1 : 0.5))
                    if template.isRecommended {
                        Text("REC")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                fitDescription
            }

            Spacer()

            addButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(fit.canAdd ? 0.04 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var fitDescription: some View {
        switch fit {
        case .fits:
            Text(String(format: "%.1f\" × %.1f\" • fits as-is",
                        template.width, template.height))
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.55))
        case .fitsAfterRegenerate:
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Fits after regenerate")
            }
            .font(.caption.bold())
            .foregroundStyle(.yellow.opacity(0.85))
        case .doesNotFit(let reason):
            HStack(spacing: 4) {
                Image(systemName: "xmark.octagon.fill")
                Text(reason)
            }
            .font(.caption.bold())
            .foregroundStyle(.red.opacity(0.85))
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if fit.canAdd {
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(accent)
            }
            .buttonStyle(PressableStyle())
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}

// MARK: - Coverage ring

private struct CoverageRing: View {
    let value: Double
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.02, value))
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
            Text("\(Int(value * 100))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
