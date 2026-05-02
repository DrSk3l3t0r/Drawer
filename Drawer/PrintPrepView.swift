//
//  PrintPrepView.swift
//  Drawer
//
//  Print preparation: filament/material/printer selection, AMS lite color
//  slots, coloring policy, print settings, and slice/export actions. When
//  the selected printer is a Bambu A1 the native slicer engine is used and
//  the output is a printer-ready `.gcode.3mf`.
//

import SwiftUI

struct PrintPrepView: View {
    let layout: DrawerLayout

    @EnvironmentObject var store: DrawerStore
    @State private var settings: PrintSettings = .default
    @State private var printer: PrinterProfile = .bambuA1
    @State private var amsPlate: AMSLitePlate = .single
    @State private var coloringPolicy: ColoringPolicy = .monoPlate
    @State private var sliceJob: SlicedPrintJob?
    @State private var sliceError: String?
    @State private var exportResult: PrintExportResult?
    @State private var exportError: String?
    @State private var isExporting = false
    @State private var showShare = false
    @State private var showCalibrationConfirm = false
    @State private var showLargePrintConfirm = false
    @State private var showPrintTracker = false
    /// Which AMS slot the user is currently picking a color for. `nil` when
    /// the picker isn't shown. Lets the user change the existing color of
    /// any slot (including slot 1) without having to remove it first.
    @State private var pickingSlotIdx: Int?
    @Environment(\.dismiss) private var dismiss

    private var organizer: PrintableOrganizer {
        let primary = amsPlate.activeFilaments.first?.profile ?? .default
        return PrintModelGenerator.makeOrganizer(
            from: layout,
            settings: settings,
            filament: primary,
            printer: printer
        )
    }

    private var assignment: AMSLiteAssignment {
        AMSLiteColorPlanner.resolveAssignment(
            policy: coloringPolicy,
            plate: amsPlate,
            modules: organizer.modules
        )
    }

    private var isBambuA1: Bool {
        printer.id == PrinterProfile.bambuA1.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    summaryCard
                    Print3DPreview(
                        organizer: organizer,
                        plate: amsPlate,
                        assignment: assignment
                    )
                    // Order: visualize → choose materials/colors → see what
                    // those choices cost → fine-tune settings → review &
                    // export. Estimate sits *after* AMS so material choices
                    // immediately reflect in grams + time stats.
                    materialSection
                    amsLiteSection
                    if amsPlate.activeFilaments.count > 1 {
                        coloringPolicySection
                    }
                    estimateCard
                    costCard
                    printerSection
                    settingsSection
                    warningsSection
                    actionsSection
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
            .navigationTitle("3D Print")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear { recomputeSlice() }
            .onChange(of: settings) { _, _ in recomputeSlice() }
            .onChange(of: amsPlate) { _, _ in recomputeSlice() }
            .onChange(of: printer) { _, _ in recomputeSlice() }
            .onChange(of: coloringPolicy) { _, _ in recomputeSlice() }
            .sheet(isPresented: $showShare) {
                if let result = exportResult {
                    ShareSheet(items: [result.fileURL])
                }
            }
            .sheet(item: Binding(
                get: { pickingSlotIdx.map { SlotPickIndex(idx: $0) } },
                set: { pickingSlotIdx = $0?.idx }
            )) { wrapper in
                FilamentColorPickerSheet(
                    currentColor: amsPlate.slots[wrapper.idx]?.color
                ) { picked in
                    setSlot(wrapper.idx, color: picked)
                }
            }
            .alert("Print a calibration cube first?",
                   isPresented: $showCalibrationConfirm) {
                Button("Continue with organizer", role: .destructive) {
                    runExport()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Apple recommends running a quick 20×20×5 mm calibration print before your first organizer print on a new material/printer combo.")
            }
            .alert("Large print confirmation",
                   isPresented: $showLargePrintConfirm) {
                Button("I understand, proceed", role: .destructive) {
                    runExport()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(largePrintMessage)
            }
        }
        .presentationDetents([.large])
    }

    private var largePrintMessage: String {
        let grams = sliceJob?.estimatedFilamentGrams ?? 0
        let minutes = sliceJob?.estimatedPrintTimeMinutes ?? 0
        return "This print will use about \(Int(grams)) g of filament and take \(Int(minutes / 60)) hr \(Int(minutes.truncatingRemainder(dividingBy: 60))) min. Make sure you have enough filament loaded and that the printer is supervised."
    }

    /// Module count surfaced to the user. Excludes locating-lip pieces
    /// (auto-generated for tier-2 stacks); they print fused with their
    /// parent body so they're not user-meaningful objects.
    private var userVisibleModuleCount: Int {
        organizer.modules.filter { !$0.isLocatingLip }.count
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let modules = layout.items.count
        let drawer = layout.measurement
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(activeColor.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(modules) modules • \(amsPlate.activeFilaments.first?.profile.material.displayName ?? "Filament")")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("Drawer \(drawer.formattedWidth) × \(drawer.formattedDepth) × \(drawer.formattedHeight)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if isBambuA1 {
                Text("A1 NATIVE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .glassCard()
    }

    private var activeColor: Color {
        amsPlate.activeFilaments.first?.profile.color.swiftUIColor ?? .gray
    }

    // MARK: - Estimate

    private var estimateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(label: "Estimate")
            if let job = sliceJob {
                Text(job.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                if let grams = job.estimatedFilamentGrams,
                   let mins = job.estimatedPrintTimeMinutes {
                    HStack(spacing: 16) {
                        statChip(label: "Filament", value: String(format: "%.0f g", grams))
                        statChip(label: "Time", value: formatMinutes(mins))
                        statChip(label: "Modules", value: "\(layout.items.count)")
                    }
                }
                if isBambuA1 {
                    Text("Native A1 G-code with \(amsPlate.activeFilaments.count) AMS lite slot(s) — open the .gcode.3mf in Bambu Studio to verify, then print.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Text(SlicerProvider.engine(for: printer).availabilityNote)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else if let error = sliceError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
            } else {
                ProgressView().tint(.white)
            }
        }
        .padding(14)
        .glassCard()
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
                .fill(.white.opacity(0.06))
        )
    }

    // MARK: - Cost

    /// Filament cost preview based on the user's $/kg setting (kept on the
    /// shared store so it persists across sessions and screens). Updates
    /// live with the estimate card's grams figure.
    private var costCard: some View {
        let grams = sliceJob?.estimatedFilamentGrams ?? 0
        let kg = grams / 1000.0
        let totalCost = kg * store.costPerKg
        let perGram = store.costPerKg / 1000.0

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(label: "Filament cost",
                          trailing: String(format: "$%.2f/kg", store.costPerKg),
                          trailingColor: .white.opacity(0.6))

            HStack(spacing: 14) {
                statChip(label: "Total",
                         value: String(format: "$%.2f", totalCost))
                statChip(label: "Per gram",
                         value: String(format: "%.1f¢", perGram * 100))
                statChip(label: "Filament",
                         value: String(format: "%.0f g", grams))
            }

            HStack {
                Text("Spool price ($/kg)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: "$%.0f", store.costPerKg))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
            }
            Slider(value: Binding(
                get: { store.costPerKg },
                set: { store.costPerKg = $0 }
            ), in: 10...80, step: 1)
                .tint(.green)

            Text("Set this once for your spool. Used to estimate the cost of every print.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Material

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(label: "Material (all slots)")
            HStack(spacing: 8) {
                ForEach(FilamentMaterial.allCases) { material in
                    materialChip(material)
                }
            }
            Text("AMS lite slots share a material; only the colors differ.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(14)
        .glassCard()
    }

    private func materialChip(_ material: FilamentMaterial) -> some View {
        let isSelected = (amsPlate.activeFilaments.first?.profile.material ?? .pla) == material
        return Button(action: {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                amsPlate = AMSLitePlate(slots: amsPlate.slots.map { profile in
                    profile.map { FilamentProfile(material: material, color: $0.color) }
                })
            }
        }) {
            Text(material.displayName)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? .white : .white.opacity(0.1)))
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - AMS lite slots

    private var amsLiteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(label: "AMS Lite Slots",
                          trailing: "\(amsPlate.activeFilaments.count)/4")
            ForEach(0..<4, id: \.self) { slotIdx in
                amsSlotRow(slotIdx: slotIdx)
            }
        }
        .padding(14)
        .glassCard()
    }

    private func amsSlotRow(slotIdx: Int) -> some View {
        let profile = amsPlate.slots[slotIdx]
        return HStack(spacing: 12) {
            Text("Slot \(slotIdx + 1)")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 50, alignment: .leading)

            if let p = profile {
                // The whole "swatch + name" area is tappable to change the
                // color — fixes the previous UX where slot 1's color was
                // un-editable unless you removed it first.
                Button {
                    pickingSlotIdx = slotIdx
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(p.color.swiftUIColor)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                        Text(p.color.name)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .buttonStyle(PressableStyle())

                Spacer()
                Button(action: { setSlot(slotIdx, color: nil) }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red.opacity(0.9))
                }
                .buttonStyle(.plain)
                .disabled(slotIdx == 0 && amsPlate.activeFilaments.count == 1)
            } else {
                Spacer()
                Button {
                    pickingSlotIdx = slotIdx
                } label: {
                    Label("Add Color", systemImage: "plus.circle")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.vertical, 4)
    }

    private func setSlot(_ index: Int, color: FilamentColor?) {
        UISelectionFeedbackGenerator().selectionChanged()
        let material = amsPlate.activeFilaments.first?.profile.material ?? .pla
        var slots = amsPlate.slots
        if let c = color {
            slots[index] = FilamentProfile(material: material, color: c)
        } else {
            slots[index] = nil
        }
        // Compact slots: keep order, ensure first slot is always populated.
        if slots.compactMap({ $0 }).isEmpty {
            slots[0] = .default
        }
        withAnimation(.spring()) { amsPlate = AMSLitePlate(slots: slots) }
    }

    // MARK: - Coloring policy

    private var coloringPolicySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(label: "Coloring Mode")
            ForEach(ColoringPolicy.allCases) { policy in
                Button(action: {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring()) { coloringPolicy = policy }
                }) {
                    HStack {
                        Image(systemName: coloringPolicy == policy
                              ? "largecircle.fill.circle"
                              : "circle")
                            .foregroundStyle(layout.purpose.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(policy.displayName)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text(policy.description)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Printer

    private var printerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(label: "Printer",
                          trailing: printer.isBambu ? "BAMBU" : nil,
                          trailingColor: .green)
            VStack(spacing: 6) {
                ForEach(PrinterProfile.all) { profile in
                    Button(action: {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring()) { printer = profile }
                    }) {
                        HStack {
                            Image(systemName: profile.isBambu ? "scope" : "printer")
                                .foregroundStyle(profile.isBambu ? .green : .white.opacity(0.6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                Text(String(format: "Bed %.0f × %.0f × %.0f mm",
                                            profile.bedWidthMm,
                                            profile.bedDepthMm,
                                            profile.bedHeightMm))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            if profile.id == PrinterProfile.bambuA1.id {
                                Text("NATIVE")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            if printer.id == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(printer.id == profile.id
                                      ? Color.white.opacity(0.08)
                                      : Color.white.opacity(0.03))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Print settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(label: "Print Settings")
            settingSlider(label: "Layer Height",
                          value: $settings.layerHeightMm,
                          range: 0.08...0.32, step: 0.04, unit: "mm")
            settingSlider(label: "Wall Thickness",
                          value: $settings.wallThicknessMm,
                          range: 0.8...3.2, step: 0.4, unit: "mm")
            settingSlider(label: "Module Height",
                          value: $settings.heightMm,
                          range: 15...80, step: 1, unit: "mm")
            settingSlider(label: "Tolerance",
                          value: $settings.toleranceMm,
                          range: 0.0...1.5, step: 0.1, unit: "mm")
            settingSlider(label: "Infill",
                          value: $settings.infillPercent,
                          range: 0...50, step: 5, unit: "%")

            Divider()
                .background(.white.opacity(0.1))
                .padding(.vertical, 4)

            Toggle(isOn: $settings.autoSplitOversized) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-split oversized modules")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Split trays bigger than the printer bed into pieces that fit and snap together")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .tint(layout.purpose.color)
        }
        .padding(14)
        .glassCard()
    }

    private func settingSlider(label: String,
                                value: Binding<Double>,
                                range: ClosedRange<Double>,
                                step: Double,
                                unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.2f %@", value.wrappedValue, unit))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range, step: step)
                .tint(layout.purpose.color)
        }
    }

    // MARK: - Warnings

    private var warningsSection: some View {
        let warnings = sliceJob?.warnings ?? []
        let oversized = organizer.oversizedModules()
        return Group {
            if !warnings.isEmpty || !oversized.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(label: "Warnings", trailing: nil)
                    ForEach(warnings, id: \.self) { msg in
                        warningRow(msg, color: .yellow)
                    }
                    if !oversized.isEmpty {
                        warningRow(
                            "\(oversized.count) module(s) exceed the printer bed: \(oversized.map { $0.name }.joined(separator: ", "))",
                            color: .red
                        )
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.yellow.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(.yellow.opacity(0.25), lineWidth: 1))
                )
            }
        }
    }

    private func warningRow(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button(action: handleExportTap) {
                HStack {
                    if isExporting {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: isBambuA1 ? "cube.transparent.fill" : "square.and.arrow.up.fill")
                            .symbolEffect(.bounce, value: exportResult != nil)
                    }
                    Text(isExporting
                         ? "Slicing…"
                         : (isBambuA1 ? "Slice & Export A1 .gcode.3mf" : "Export 3MF"))
                        .font(.headline)
                        .contentTransition(.identity)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [layout.purpose.color, layout.purpose.color.opacity(0.7)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: layout.purpose.color.opacity(0.4),
                        radius: 12, y: 6)
                .scaleEffect(isExporting ? 0.985 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExporting)
            }
            .buttonStyle(PressableStyle())
            .disabled(isExporting || layout.items.isEmpty)
            .sensoryFeedback(.success, trigger: exportResult)

            HStack(spacing: 10) {
                Button(action: { showShare = exportResult != nil }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.08))
                    )
                }
                .buttonStyle(PressableStyle())
                .disabled(exportResult == nil)
                .opacity(exportResult == nil ? 0.4 : 1)

                Button(action: startTrackingPrint) {
                    HStack {
                        Image(systemName: "timer")
                        Text("Track print")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.green.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(.green.opacity(0.4), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(PressableStyle())
                .disabled(exportResult == nil)
                .opacity(exportResult == nil ? 0.4 : 1)
            }

            // Inline tracker — shows active print countdown if one is running.
            PrintTrackerView()

            if let error = exportError {
                Text(error)
                    .font(.caption.bold())
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.top, 4)
            }
            if let result = exportResult {
                Text(String(format: "Exported %.1f KB · %d module(s)",
                            Double(result.sizeBytes) / 1024, result.moduleCount))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text("First time printing? Run a 20×20×5 mm calibration cube before this print.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    /// Start a live print tracker for the most recently exported file.
    /// Picks up filament + time estimates from the current `sliceJob`.
    private func startTrackingPrint() {
        let totalSeconds = Int((sliceJob?.estimatedPrintTimeMinutes ?? 60) * 60)
        let totalGrams = sliceJob?.estimatedFilamentGrams ?? organizer.totalGrams
        let attrs = PrintActivityAttributes(
            drawerName: "\(layout.purpose.rawValue) Drawer",
            printerName: printer.name,
            totalGrams: totalGrams,
            totalSeconds: max(60, totalSeconds)
        )
        PrintProgressManager.shared.start(attributes: attrs)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Logic

    private func handleExportTap() {
        let mins = sliceJob?.estimatedPrintTimeMinutes ?? 0
        let grams = sliceJob?.estimatedFilamentGrams ?? 0
        let multiColor = amsPlate.activeFilaments.count > 1

        if mins > 360 || (multiColor && grams > 200) {
            showLargePrintConfirm = true
        } else if isBambuA1 && exportResult == nil {
            showCalibrationConfirm = true
        } else {
            runExport()
        }
    }

    /// Recompute just the lightweight estimate (filament grams + time +
    /// warnings) used by the live UI. Earlier this called the full Bambu A1
    /// slicer on every settings change — slicing 1,000+ layers, emitting
    /// the whole G-code body, and ZIP-packaging it on each slider tick is
    /// what was making the print-settings sliders laggy. The real slice
    /// happens only on `runExport()`.
    private func recomputeSlice() {
        sliceError = nil

        guard !organizer.modules.isEmpty else {
            sliceJob = nil
            sliceError = "No modules to estimate."
            return
        }

        // Filament: sum of per-module estimates from the geometry. Cheap.
        let grams = organizer.totalGrams
        // ~3 g/min throughput for Bambu A1 at standard quality.
        let minutes = max(8.0, grams / 3.0)

        var warnings: [String] = []
        if organizer.settings.wallThicknessMm < 0.8 {
            warnings.append("Walls thinner than 0.8 mm may print poorly.")
        }
        if minutes > 360 {
            warnings.append("Estimated print time exceeds 6 hours.")
        }
        if amsPlate.activeFilaments.count > 1 && grams > 200 {
            warnings.append("Multi-color print over 200 g — flush volume can be significant.")
        }

        let materialName = amsPlate.activeFilaments.first?.profile.material.displayName ?? "Filament"
        let summary: String
        if isBambuA1 {
            summary = "\(userVisibleModuleCount) modules • \(amsPlate.activeFilaments.count) filament(s) • \(materialName) • \(String(format: "%.0f", grams)) g • approx \(formatMinutes(minutes))"
        } else {
            summary = "\(userVisibleModuleCount) modules • \(String(format: "%.0f", grams)) g \(materialName) • approx \(formatMinutes(minutes))"
        }

        sliceJob = SlicedPrintJob(
            capability: isBambuA1 ? .fullToolpath : .diagnostic,
            summary: summary,
            warnings: warnings,
            estimatedPrintTimeMinutes: minutes,
            estimatedFilamentGrams: grams,
            outputURL: nil
        )
    }

    private func runExport() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isExporting = true
        exportError = nil

        let captured = (organizer: organizer, amsPlate: amsPlate,
                         coloringPolicy: coloringPolicy, assignment: assignment,
                         layout: layout, isBambuA1: isBambuA1, printer: printer)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let engine = SlicerProvider.engine(for: captured.printer)
                if captured.isBambuA1, let bambu = engine as? BambuA1SlicerEngine {
                    let ctx = BambuSliceContext(
                        organizer: captured.organizer,
                        amsPlate: captured.amsPlate,
                        coloringPolicy: captured.coloringPolicy,
                        assignment: captured.assignment
                    )
                    let out = try bambu.sliceWithContext(ctx,
                        fileBaseName: "drawer_\(captured.layout.purpose.rawValue)")
                    DispatchQueue.main.async {
                        // Don't count locating lips toward the user-facing
                        // module count — they print fused into their parent
                        // tier-2 bodies, so they're not separate objects.
                        let visibleCount = captured.organizer.modules
                            .filter { !$0.isLocatingLip }.count
                        exportResult = PrintExportResult(
                            fileURL: out.packageURL,
                            format: .threeMF,
                            moduleCount: visibleCount,
                            sizeBytes: out.sizeBytes
                        )
                        isExporting = false
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showShare = true
                    }
                } else {
                    let result = try ThreeMFExporter.export(
                        captured.organizer,
                        fileBaseName: "drawer_\(captured.layout.purpose.rawValue)"
                    )
                    DispatchQueue.main.async {
                        exportResult = result
                        isExporting = false
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showShare = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    exportError = error.localizedDescription
                    isExporting = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total < 60 { return "\(total) min" }
        let h = total / 60
        let m = total % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }
}

// MARK: - Filament color picker

/// `Identifiable` wrapper around a slot index so we can use `sheet(item:)`
/// — `Int` itself can't conform to `Identifiable` and tagging the literal
/// each time would require an extension we don't want polluting the global
/// namespace.
private struct SlotPickIndex: Identifiable {
    var id: Int { idx }
    let idx: Int
}

/// Bottom sheet for picking a filament color. Renders each option as a
/// real colored circle (the previous `Menu` rendering showed every option
/// as a flat black SF Symbol because Menu can't tint per-row icons) and
/// pre-selects the slot's existing color so re-opening the picker shows
/// the user where they already are.
struct FilamentColorPickerSheet: View {
    let currentColor: FilamentColor?
    var onPick: (FilamentColor) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(FilamentColor.defaults) { color in
                        colorTile(color: color,
                                   isSelected: color.id == currentColor?.id)
                            .onTapGesture {
                                UISelectionFeedbackGenerator().selectionChanged()
                                onPick(color)
                                dismiss()
                            }
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "0D1117"), Color(hex: "161B22")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Pick a filament color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func colorTile(color: FilamentColor, isSelected: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle().stroke(.white.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: color.swiftUIColor.opacity(0.45),
                            radius: isSelected ? 14 : 0, y: 4)
                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                }
            }
            .frame(width: 64, height: 64)

            Text(color.name)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(isSelected ? 0.10 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? .white.opacity(0.55)
                                            : .white.opacity(0.06),
                                 lineWidth: isSelected ? 1.5 : 1)
                )
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.75),
                   value: isSelected)
    }
}
