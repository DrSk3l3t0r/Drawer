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

    @EnvironmentObject var store: DrawerStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCustomSheet = false
    @State private var showStackingSheet = false

    private var allTemplates: [OrganizerTemplate] {
        LayoutEngine.templates(for: layout.purpose)
            + store.userTemplates.map(LayoutEngine.makeTemplate(from:))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    summaryHeader
                    placedSection
                    catalogSection
                    customAndStackingSection
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
            .sheet(isPresented: $showCustomSheet) {
                CustomDimensionSheet { newTemplate in
                    store.addTemplate(newTemplate)
                    let template = LayoutEngine.makeTemplate(from: newTemplate)
                    addTemplate(template)
                }
            }
            .sheet(isPresented: $showStackingSheet) {
                AddTier2Sheet(layout: $layout) { updated in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        layout = updated
                    }
                    onChange?()
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

    // MARK: - Custom dimensions + tier-2 stacking

    /// Two power-user actions live below the catalog: define a custom-sized
    /// module from scratch, or stack a tier-2 module on top of an existing
    /// tier-1 item. Both write through to the store / layout immediately.
    private var customAndStackingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(label: "More",
                          trailing: store.userTemplates.isEmpty
                            ? nil
                            : "\(store.userTemplates.count) custom",
                          trailingColor: .white.opacity(0.5))

            HStack(spacing: 10) {
                Button { showCustomSheet = true } label: {
                    actionTile(icon: "ruler.fill",
                               title: "Custom size",
                               subtitle: "Define your own width × depth")
                }
                Button { showStackingSheet = true } label: {
                    actionTile(icon: "square.stack.3d.up.fill",
                               title: "Stack on top",
                               subtitle: "Add a tier-2 organizer above a tray",
                               disabled: layout.items.contains { $0.tier == 1 } == false)
                }
                .disabled(layout.items.allSatisfy { $0.tier != 1 })
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func actionTile(icon: String, title: String, subtitle: String,
                             disabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(layout.purpose.color)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
        .opacity(disabled ? 0.4 : 1)
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

// MARK: - Custom dimension sheet

/// Lets the user define a fully custom organizer module — width × depth in
/// inches, plus a label and color hue. Saved to `DrawerStore.userTemplates`
/// so they show up in every drawer's edit sheet.
struct CustomDimensionSheet: View {
    var onAdd: (UserDefinedTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = "My Custom Slot"
    @State private var widthInches: Double = 4.0
    @State private var depthInches: Double = 4.0
    @State private var hue: Double = 0.55

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Live preview rectangle scaled to relative size.
                    preview

                    nameField

                    dimensionField(label: "Width",
                                    value: $widthInches,
                                    range: 1.5...20.0)
                    dimensionField(label: "Depth",
                                    value: $depthInches,
                                    range: 1.5...20.0)

                    hueField

                    addButton
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "0D1117"), Color(hex: "161B22")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Custom organizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var preview: some View {
        let aspect = widthInches / max(0.1, depthInches)
        let maxW: CGFloat = 200
        let maxH: CGFloat = 200
        let renderW: CGFloat = aspect >= 1 ? maxW : maxH * aspect
        let renderH: CGFloat = aspect >= 1 ? maxW / aspect : maxH
        return RoundedRectangle(cornerRadius: 8)
            .fill(Color(hue: hue, saturation: 0.6, brightness: 0.85))
            .frame(width: renderW, height: renderH)
            .overlay(
                Text("\(formatted(widthInches))″ × \(formatted(depthInches))″")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 1)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 220)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
            TextField("Custom Slot", text: $name)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.07))
                )
                .foregroundStyle(.white)
        }
    }

    private func dimensionField(label: String,
                                  value: Binding<Double>,
                                  range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.1f\"", value.wrappedValue))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range, step: 0.1)
                .tint(Color(hue: hue, saturation: 0.6, brightness: 0.85))
        }
    }

    private var hueField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Color")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            Slider(value: $hue, in: 0...1, step: 0.01)
                .tint(Color(hue: hue, saturation: 0.6, brightness: 0.9))
        }
    }

    private var addButton: some View {
        Button {
            let t = UserDefinedTemplate(
                name: name.isEmpty ? "Custom Slot" : name,
                widthInches: widthInches,
                heightInches: depthInches,
                hue: hue
            )
            onAdd(t)
            dismiss()
        } label: {
            Text("Save & add to drawer")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.6, brightness: 0.85),
                            Color(hue: hue, saturation: 0.55, brightness: 0.65)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
    }

    private func formatted(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".0", with: "")
    }
}

// MARK: - Tier-2 stacking sheet

/// Pick a tier-1 organizer to stack a second tier on top of. Built around a
/// visual drawer map (so the user can SEE which tray they're picking instead
/// of trying to match a name to a position) and a side-view preview that
/// shows the parent + proposed tier-2 stack at relative scale.
struct AddTier2Sheet: View {
    @Binding var layout: DrawerLayout
    var onCommit: (DrawerLayout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pickedItemId: UUID?
    @State private var tier2Name: String = "Top tray"

    private var tier1Items: [OrganizerItem] {
        layout.items.filter { $0.tier == 1 }
    }

    private var pickedItem: OrganizerItem? {
        guard let id = pickedItemId else { return nil }
        return tier1Items.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    instructions

                    drawerMap
                        .frame(height: 240)
                        .padding(.horizontal, 20)

                    if let parent = pickedItem {
                        sideViewPreview(parent: parent)
                            .padding(.horizontal, 20)
                        nameField
                        commitButton(parent: parent)
                    } else {
                        Text("Tap a tray above to pick where to stack the new organizer.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "0D1117"), Color(hex: "161B22")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Stack on top")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var instructions: some View {
        VStack(spacing: 6) {
            Text("Pick a tray, then add a stacked compartment above it.")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text("Tier-2 organizers share their parent's footprint and add a shorter, lift-out tray above.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Drawer map (top-down)

    /// Top-down map of the drawer with each tier-1 item drawn at its actual
    /// position. Tappable. The user picks visually instead of matching by
    /// name.
    private var drawerMap: some View {
        GeometryReader { geo in
            let drawerW = max(1, layout.measurement.widthInches)
            let drawerD = max(1, layout.measurement.depthInches)
            let aspect = drawerW / drawerD
            let scale = aspect >= 1
                ? min(geo.size.width, geo.size.height * aspect) / drawerW
                : min(geo.size.height, geo.size.width / aspect) / drawerD
            let renderW = drawerW * scale
            let renderH = drawerD * scale
            let originX = (geo.size.width - renderW) / 2
            let originY = (geo.size.height - renderH) / 2

            ZStack(alignment: .topLeading) {
                // Drawer outline
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.white.opacity(0.4), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "0A1628"))
                    )
                    .frame(width: renderW, height: renderH)
                    .offset(x: originX, y: originY)

                // Each tier-1 item as a tappable rectangle.
                ForEach(tier1Items) { item in
                    let picked = pickedItemId == item.id
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            pickedItemId = item.id
                            if tier2Name == "Top tray" {
                                // Auto-suggest a contextual name based on the
                                // parent so the field doesn't always say "Top
                                // tray" — easy to override.
                                tier2Name = "\(item.name) lid"
                            }
                        }
                    } label: {
                        Rectangle()
                            .fill(item.color.opacity(picked ? 0.85 : 0.55))
                            .overlay(
                                Rectangle().strokeBorder(
                                    picked ? .white : .white.opacity(0.2),
                                    lineWidth: picked ? 2 : 0.5
                                )
                            )
                            .overlay(
                                Text(item.name)
                                    .font(.system(size: max(8, min(11, item.width * scale / 6)),
                                                  weight: picked ? .bold : .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                                    .padding(2)
                            )
                            .overlay(alignment: .topTrailing) {
                                if picked {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.green)
                                        .background(Circle().fill(.black.opacity(0.6)))
                                        .offset(x: 4, y: -4)
                                }
                            }
                            .frame(width: item.width * scale,
                                   height: item.height * scale)
                            .scaleEffect(picked ? 1.04 : 1)
                            .shadow(color: picked ? item.color.opacity(0.6) : .clear,
                                    radius: 6)
                    }
                    .buttonStyle(.plain)
                    .offset(x: originX + item.x * scale,
                            y: originY + item.y * scale)
                }
            }
        }
    }

    // MARK: - Side-view preview

    /// Side-view diagram of the parent + proposed tier-2 stack so the user
    /// can see how tall the combined stack will be relative to the drawer.
    private func sideViewPreview(parent: OrganizerItem) -> some View {
        let drawerHeightIn = layout.measurement.heightInches
        let baseHeightIn = 35.0 / 25.4   // PrintSettings.heightMm default
        let tier2HeightIn = 22.0 / 25.4  // PrintSettings.tier2HeightMm default
        let totalStackIn = baseHeightIn + tier2HeightIn

        let scale = 220.0 / max(drawerHeightIn, totalStackIn + 0.5)
        let drawerHeightPt = drawerHeightIn * scale
        let baseHeightPt = baseHeightIn * scale
        let tier2HeightPt = tier2HeightIn * scale
        let widthPt: CGFloat = 90

        let fits = totalStackIn <= drawerHeightIn

        return VStack(alignment: .leading, spacing: 8) {
            Text("Side view")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)
            HStack(alignment: .bottom, spacing: 16) {
                // The drawer interior (taller, dashed outline showing its full height).
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .strokeBorder(
                            .white.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1, dash: [4])
                        )
                        .frame(width: widthPt, height: drawerHeightPt)
                    VStack(spacing: 2) {
                        // Tier 2 (top, lighter color, slightly inset)
                        Rectangle()
                            .fill(Color(hue: parent.colorHue,
                                         saturation: 0.45,
                                         brightness: 0.95).opacity(0.85))
                            .overlay(Rectangle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                            .frame(width: widthPt - 6, height: tier2HeightPt)
                        // Tier 1 (bottom, parent's actual color)
                        Rectangle()
                            .fill(parent.color)
                            .overlay(Rectangle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                            .frame(width: widthPt - 6, height: baseHeightPt)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color(hue: parent.colorHue, saturation: 0.45, brightness: 0.95).opacity(0.85))
                            .frame(width: 12, height: 12)
                        Text("Tier 2 — \(String(format: "%.1f", tier2HeightIn))″ tall")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(parent.color)
                            .frame(width: 12, height: 12)
                        Text("\(parent.name) — \(String(format: "%.1f", baseHeightIn))″ tall")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "ruler")
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Drawer is \(String(format: "%.1f", drawerHeightIn))″ deep")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    if fits {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Stack fits with \(String(format: "%.1f", drawerHeightIn - totalStackIn))″ to spare")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Stack is \(String(format: "%.1f", totalStackIn - drawerHeightIn))″ taller than the drawer")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tier-2 name")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
            TextField("Top tray", text: $tier2Name)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.07))
                )
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
    }

    private func commitButton(parent: OrganizerItem) -> some View {
        Button(action: commit) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                Text("Add tier-2 above \(parent.name)")
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [layout.purpose.color,
                              layout.purpose.color.opacity(0.7)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: layout.purpose.color.opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 20)
    }

    private func commit() {
        guard let id = pickedItemId,
              let parent = layout.items.first(where: { $0.id == id })
        else { return }

        // Tier-2 clones the parent's XY footprint, takes the shorter
        // `tier2HeightMm` height, and references the parent via `stacksOn`.
        var newLayout = layout
        let tier2 = OrganizerItem(
            name: tier2Name.isEmpty ? "Top tray" : tier2Name,
            x: parent.x,
            y: parent.y,
            width: parent.width,
            height: parent.height,
            hue: (parent.colorHue + 0.08).truncatingRemainder(dividingBy: 1.0),
            saturation: 0.45,
            brightness: 0.95,
            tier: 2,
            stacksOn: parent.id
        )
        newLayout.items.append(tier2)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCommit(newLayout)
        dismiss()
    }
}
