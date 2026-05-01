//
//  LayoutResultView.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI

struct LayoutResultView: View {
    @State var layout: DrawerLayout
    let capturedImage: UIImage?
    @EnvironmentObject var store: DrawerStore

    @State private var drawerName: String = ""
    @State private var showSaveSheet = false
    @State private var showShareSheet = false
    @State private var savedSuccessfully = false
    @State private var renderedImage: UIImage?
    @State private var selectedItemId: OrganizerItem.ID?
    @State private var regenerationStamp: UUID = UUID()
    @State private var isRegenerating = false
    @State private var showEditOrganizers = false
    @State private var showPrintPrep = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                
                // Blueprint diagram
                blueprintSection
                
                // Stats
                statsSection

                // Warnings (if any)
                if !layout.warnings.isEmpty {
                    warningsSection
                }

                // Item list
                itemListSection

                // Unplaced overflow
                if !layout.unplacedTemplates.isEmpty {
                    overflowSection
                }

                // Action buttons
                actionButtons
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "0D1117"), Color(hex: "0A1628"), Color(hex: "0D1117")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .sheet(isPresented: $showSaveSheet) { saveSheet }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showEditOrganizers) {
            EditOrganizersSheet(layout: $layout) {
                regenerationStamp = UUID()
            }
        }
        .sheet(isPresented: $showPrintPrep) {
            PrintPrepView(layout: layout)
        }
        .overlay(saveConfirmation)
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
            
            VStack(spacing: 2) {
                Text("Layout Design")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(layout.purpose.rawValue)
                    .font(.caption)
                    .foregroundStyle(layout.purpose.color)
            }
            
            Spacer()
            
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }
    
    // MARK: - Blueprint
    
    private var blueprintSection: some View {
        VStack(spacing: 12) {
            Text("TOP-DOWN VIEW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(2)
            
            DrawerBlueprintView(
                layout: layout,
                selectedItemId: $selectedItemId,
                regenerationStamp: regenerationStamp
            )
            .frame(height: 320)
            .padding(.horizontal, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "0A1628"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatBadge(
                value: "\(Int(layout.coveragePercentage))%",
                label: "Coverage",
                color: coverageColor
            )
            
            StatBadge(
                value: "\(layout.items.count)",
                label: "Organizers",
                color: Color(hue: 0.55, saturation: 0.6, brightness: 0.9)
            )
            
            StatBadge(
                value: layout.measurement.formattedWidth + "×" + layout.measurement.formattedDepth,
                label: "Drawer Size",
                color: Color(hue: 0.08, saturation: 0.6, brightness: 0.95)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var coverageColor: Color {
        if layout.coveragePercentage > 75 { return .green }
        if layout.coveragePercentage > 50 { return .orange }
        return .red
    }
    
    // MARK: - Warnings

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(layout.warnings, id: \.self) { msg in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(msg)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Overflow

    private var overflowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.orange)
                Text("Couldn't fit (\(layout.unplacedTemplates.count))")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }

            ForEach(layout.unplacedTemplates, id: \.self) { name in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
            }

            Text("Increase drawer size or pick fewer items to fit them all.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Item List

    private var itemListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Organizer Items")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(layout.items.count)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.5))
            }

            ForEach(layout.items) { item in
                Button(action: {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedItemId = (selectedItemId == item.id) ? nil : item.id
                    }
                }) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color)
                            .frame(width: 16, height: 16)
                            .scaleEffect(selectedItemId == item.id ? 1.2 : 1.0)

                        Text(item.name)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .fontWeight(selectedItemId == item.id ? .bold : .regular)

                        Spacer()

                        Text(String(format: "%.1f\" × %.1f\"", item.width, item.height))
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.5))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white.opacity(selectedItemId == item.id ? 0.7 : 0.25))
                            .rotationEffect(.degrees(selectedItemId == item.id ? 90 : 0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(item.color.opacity(selectedItemId == item.id ? 0.18 : 0))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.04))
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Edit Organizers — primary action right under the blueprint
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showEditOrganizers = true
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Edit Organizers")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [layout.purpose.color, layout.purpose.color.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: layout.purpose.color.opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(PressableStyle())

            // Print + Save row
            HStack(spacing: 12) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showPrintPrep = true
                }) {
                    HStack {
                        Image(systemName: "cube.transparent.fill")
                        Text("3D Print")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(
                                colors: [Color(hue: 0.55, saturation: 0.7, brightness: 0.55),
                                         Color(hue: 0.45, saturation: 0.5, brightness: 0.45)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                }
                .buttonStyle(PressableStyle())

                Button(action: { showSaveSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Save")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.08))
                    )
                }
                .buttonStyle(PressableStyle())
            }

            HStack(spacing: 12) {
                Button(action: regenerate) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.rotate, options: .speed(1.4), value: isRegenerating)
                        Text("Regenerate")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.08))
                    )
                }
                .disabled(isRegenerating)
                .buttonStyle(PressableStyle())

                Button(action: shareLayout) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.08))
                    )
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    // MARK: - Save Sheet
    
    private var saveSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Drawer name (e.g., Kitchen Main)", text: $drawerName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Button("Save") {
                    let saved = SavedDrawer(
                        name: drawerName.isEmpty ? "\(layout.purpose.rawValue) Drawer" : drawerName,
                        layout: layout,
                        photoData: capturedImage?.jpegData(compressionQuality: 0.6)
                    )
                    store.save(saved)
                    showSaveSheet = false
                    withAnimation { savedSuccessfully = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { savedSuccessfully = false }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(drawerName.isEmpty && false) // Allow empty (will use default)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Save Drawer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSaveSheet = false }
                }
            }
        }
        .presentationDetents([.height(220)])
    }
    
    // MARK: - Save Confirmation
    
    private var saveConfirmation: some View {
        Group {
            if savedSuccessfully {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Saved!")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Actions
    
    private func regenerate() {
        isRegenerating = true
        let selected: Set<String>? = layout.selectedTemplateIds.isEmpty
            ? nil
            : Set(layout.selectedTemplateIds)
        withAnimation(.spring(response: 0.4)) {
            layout = LayoutEngine.regenerateLayout(
                measurement: layout.measurement,
                purpose: layout.purpose,
                selectedIds: selected
            )
            selectedItemId = nil
            regenerationStamp = UUID()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isRegenerating = false
        }
    }
    
    private func shareLayout() {
        renderedImage = renderLayoutAsImage()
        if renderedImage != nil {
            showShareSheet = true
        }
    }
    
    private func renderLayoutAsImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800))
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: 600, height: 800))
            UIColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1).setFill()
            ctx.fill(rect)
            
            // Title
            let title = "\(layout.purpose.rawValue) Drawer Layout"
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            title.draw(at: CGPoint(x: 20, y: 20), withAttributes: titleAttrs)
            
            // Drawer outline
            let margin: CGFloat = 40
            let maxW: CGFloat = 520
            let maxH: CGFloat = 520
            let scale = min(maxW / layout.measurement.widthInches, maxH / layout.measurement.depthInches)
            
            let drawerRect = CGRect(
                x: margin,
                y: 70,
                width: layout.measurement.widthInches * scale,
                height: layout.measurement.depthInches * scale
            )
            
            UIColor.white.withAlphaComponent(0.2).setStroke()
            let path = UIBezierPath(roundedRect: drawerRect, cornerRadius: 4)
            path.lineWidth = 2
            path.stroke()
            
            // Items
            for item in layout.items {
                let itemRect = CGRect(
                    x: margin + item.x * scale,
                    y: 70 + item.y * scale,
                    width: item.width * scale,
                    height: item.height * scale
                )
                
                let color = UIColor(
                    hue: item.colorHue,
                    saturation: item.colorSaturation,
                    brightness: item.colorBrightness,
                    alpha: 0.6
                )
                color.setFill()
                UIBezierPath(roundedRect: itemRect, cornerRadius: 3).fill()
                
                let nameAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: UIColor.white
                ]
                item.name.draw(at: CGPoint(x: itemRect.minX + 4, y: itemRect.minY + 4), withAttributes: nameAttrs)
            }
            
            // Footer
            let footer = String(format: "Coverage: %.0f%% | %d items | %.1f\" × %.1f\"",
                                layout.coveragePercentage,
                                layout.items.count,
                                layout.measurement.widthInches,
                                layout.measurement.depthInches)
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]
            footer.draw(at: CGPoint(x: 20, y: 760), withAttributes: footerAttrs)
        }
    }
}

// MARK: - Blueprint View

struct DrawerBlueprintView: View {
    let layout: DrawerLayout
    @Binding var selectedItemId: OrganizerItem.ID?
    /// Bumped when the layout is regenerated so items re-animate in.
    let regenerationStamp: UUID

    @State private var animatedItemIds: Set<OrganizerItem.ID> = []

    var body: some View {
        GeometryReader { geo in
            let drawerW = layout.measurement.widthInches
            let drawerD = layout.measurement.depthInches
            let scale = min(
                (geo.size.width - 20) / drawerW,
                (geo.size.height - 20) / drawerD
            )
            let offsetX = (geo.size.width - drawerW * scale) / 2
            let offsetY = (geo.size.height - drawerD * scale) / 2

            ZStack(alignment: .topLeading) {
                // Grid pattern
                ForEach(0..<Int(drawerW) + 1, id: \.self) { i in
                    Path { path in
                        let x = offsetX + Double(i) * scale
                        path.move(to: CGPoint(x: x, y: offsetY))
                        path.addLine(to: CGPoint(x: x, y: offsetY + drawerD * scale))
                    }
                    .stroke(.white.opacity(0.05), lineWidth: 0.5)
                }

                ForEach(0..<Int(drawerD) + 1, id: \.self) { i in
                    Path { path in
                        let y = offsetY + Double(i) * scale
                        path.move(to: CGPoint(x: offsetX, y: y))
                        path.addLine(to: CGPoint(x: offsetX + drawerW * scale, y: y))
                    }
                    .stroke(.white.opacity(0.05), lineWidth: 0.5)
                }

                // Drawer outline
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.4), lineWidth: 2)
                    .frame(width: drawerW * scale, height: drawerD * scale)
                    .offset(x: offsetX, y: offsetY)

                // Tap-to-clear background — clicking the empty drawer
                // deselects any highlighted item.
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: drawerW * scale, height: drawerD * scale)
                    .contentShape(Rectangle())
                    .offset(x: offsetX, y: offsetY)
                    .onTapGesture {
                        withAnimation(.spring()) { selectedItemId = nil }
                    }

                // Organizer items
                ForEach(Array(layout.items.enumerated()), id: \.element.id) { index, item in
                    let isSelected = selectedItemId == item.id
                    let dim = !animatedItemIds.contains(item.id)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.color.opacity(isSelected ? 0.85 : 0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(item.color,
                                        lineWidth: isSelected ? 2.5 : 1)
                        )
                        .overlay(
                            Text(item.name)
                                .font(.system(size: max(8, min(11, item.width * scale / 6)),
                                              weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.5)
                                .padding(3)
                        )
                        .shadow(color: isSelected ? item.color.opacity(0.7) : .clear,
                                radius: 8)
                        .frame(width: item.width * scale, height: item.height * scale)
                        .scaleEffect(dim ? 0.6 : (isSelected ? 1.04 : 1.0),
                                     anchor: .center)
                        .opacity(dim ? 0 : 1)
                        .offset(x: offsetX + item.x * scale, y: offsetY + item.y * scale)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.7)
                                .delay(Double(index) * 0.025),
                            value: animatedItemIds
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7),
                                   value: selectedItemId)
                        .onTapGesture {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedItemId = isSelected ? nil : item.id
                            }
                        }
                }

                // Dimension labels
                Text(layout.measurement.formattedWidth)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .position(x: offsetX + (drawerW * scale) / 2,
                              y: offsetY - 10)

                Text(layout.measurement.formattedDepth)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .rotationEffect(.degrees(-90))
                    .position(x: offsetX - 14,
                              y: offsetY + (drawerD * scale) / 2)
            }
        }
        .onAppear { animateIn() }
        .onChange(of: regenerationStamp) { _, _ in
            animatedItemIds.removeAll()
            animateIn()
        }
        .onChange(of: layout.items.map { $0.id }) { _, _ in
            // If items were swapped externally (e.g. saved drawer reopened)
            animateIn()
        }
    }

    private func animateIn() {
        // Stagger items in — set their IDs into the animated set with a
        // slight delay so they "drop" into position.
        for (index, item) in layout.items.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.04) {
                animatedItemIds.insert(item.id)
            }
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
        )
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
