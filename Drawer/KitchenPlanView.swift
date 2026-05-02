//
//  KitchenPlanView.swift
//  Drawer
//
//  Lets users group multiple saved drawers into a single "kitchen" project.
//  Each plan is an ordered list of drawers with a per-drawer location label
//  (e.g. "left of stove", "junk drawer near sink") so the user can think
//  about their whole kitchen as one design rather than as scattered files.
//

import SwiftUI

// MARK: - Kitchen Plans list

/// Top-level list of all kitchen plans. Tapping a plan opens its detail
/// view; the trailing "+" creates a new empty plan.
struct KitchenPlansListView: View {
    @EnvironmentObject var store: DrawerStore
    @State private var creatingNewPlan = false
    @State private var newPlanName = ""

    var body: some View {
        Group {
            if store.kitchenPlans.isEmpty {
                emptyState
            } else {
                planList
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "0D1117"), Color(hex: "161B22")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Kitchen Plans")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creatingNewPlan = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.white)
                }
            }
        }
        .alert("New kitchen plan", isPresented: $creatingNewPlan) {
            TextField("Plan name (e.g. Main Kitchen)", text: $newPlanName)
            Button("Create") {
                let name = newPlanName.isEmpty ? "Kitchen" : newPlanName
                let plan = KitchenPlan(name: name, date: Date(),
                                         drawerEntries: [])
                store.savePlan(plan)
                newPlanName = ""
            }
            Button("Cancel", role: .cancel) {
                newPlanName = ""
            }
        } message: {
            Text("Name your kitchen — you'll add drawers next.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 50))
                .foregroundStyle(.gray.opacity(0.4))
                .symbolEffect(.pulse, options: .repeat(.continuous))

            Text("No Kitchen Plans yet")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.7))

            Text("Group your saved drawers into a kitchen to design it as one project.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                creatingNewPlan = true
            } label: {
                Label("Create your first plan", systemImage: "plus")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive(),
                                  in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var planList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.kitchenPlans) { plan in
                    NavigationLink(destination: KitchenPlanDetailView(plan: plan)) {
                        KitchenPlanCard(plan: plan)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deletePlan(plan)
                        } label: {
                            Label("Delete plan", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
    }
}

// MARK: - Plan card

struct KitchenPlanCard: View {
    let plan: KitchenPlan
    @EnvironmentObject var store: DrawerStore

    var body: some View {
        let drawerCount = plan.drawerEntries.count
        let totalItems = plan.drawerEntries.reduce(0) { acc, entry in
            (store.savedDrawers.first { $0.id == entry.drawerId })
                .map { acc + $0.layout.items.count } ?? acc
        }
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [
                            Color(hue: 0.55, saturation: 0.6, brightness: 0.6),
                            Color(hue: 0.7, saturation: 0.5, brightness: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("\(drawerCount) drawer\(drawerCount == 1 ? "" : "s") · \(totalItems) item\(totalItems == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text(plan.date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Plan detail

/// Edit a single kitchen plan: rename it, add/remove drawers, label each
/// with a location string. Tapping a drawer opens its layout view.
struct KitchenPlanDetailView: View {
    @State var plan: KitchenPlan
    @EnvironmentObject var store: DrawerStore
    @State private var showAddDrawer = false
    @State private var renamingPlan = false
    @State private var draftName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                summaryHeader
                drawerEntries
                addDrawerButton
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
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        draftName = plan.name
                        renamingPlan = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        store.deletePlan(plan)
                    } label: {
                        Label("Delete plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showAddDrawer) {
            AddDrawerToPlanSheet(plan: $plan, onChange: persist)
        }
        .alert("Rename plan", isPresented: $renamingPlan) {
            TextField("Plan name", text: $draftName)
            Button("Save") {
                plan.name = draftName.isEmpty ? plan.name : draftName
                persist()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var summaryHeader: some View {
        let drawerCount = plan.drawerEntries.count
        let totalItems = plan.drawerEntries.reduce(0) { acc, entry in
            (store.savedDrawers.first { $0.id == entry.drawerId })
                .map { acc + $0.layout.items.count } ?? acc
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(drawerCount) drawer\(drawerCount == 1 ? "" : "s") in this kitchen")
                .font(.headline)
                .foregroundStyle(.white)
            Text("\(totalItems) total organizer slot\(totalItems == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private var drawerEntries: some View {
        VStack(spacing: 8) {
            ForEach(plan.drawerEntries) { entry in
                if let drawer = store.savedDrawers.first(where: { $0.id == entry.drawerId }) {
                    NavigationLink(destination:
                        LayoutResultView(layout: drawer.layout,
                                          capturedImage: drawer.photoData
                                            .flatMap(UIImage.init(data:)))
                    ) {
                        PlanDrawerRow(drawer: drawer, location: entry.location)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            removeEntry(entry)
                        } label: {
                            Label("Remove from plan", systemImage: "minus.circle")
                        }
                    }
                }
            }
        }
    }

    private var addDrawerButton: some View {
        Button {
            showAddDrawer = true
        } label: {
            Label("Add drawer to this plan", systemImage: "plus")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.15),
                                                style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                )
        }
        .buttonStyle(PressableStyle())
    }

    private func removeEntry(_ entry: KitchenPlan.Entry) {
        plan.drawerEntries.removeAll { $0.id == entry.id }
        persist()
    }

    private func persist() {
        store.savePlan(plan)
    }
}

private struct PlanDrawerRow: View {
    let drawer: SavedDrawer
    let location: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let data = drawer.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(drawer.layout.purpose.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: drawer.layout.purpose.icon)
                                .foregroundStyle(drawer.layout.purpose.color)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(drawer.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(location.isEmpty ? drawer.layout.purpose.rawValue : location)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Add-drawer sheet

private struct AddDrawerToPlanSheet: View {
    @Binding var plan: KitchenPlan
    var onChange: () -> Void

    @EnvironmentObject var store: DrawerStore
    @Environment(\.dismiss) private var dismiss
    @State private var pickedDrawerId: UUID?
    @State private var locationText: String = ""

    /// Drawers that aren't already in the plan.
    private var availableDrawers: [SavedDrawer] {
        let inPlan = Set(plan.drawerEntries.map { $0.drawerId })
        return store.savedDrawers.filter { !inPlan.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if availableDrawers.isEmpty {
                        emptyState
                    } else {
                        ForEach(availableDrawers) { drawer in
                            Button {
                                pickedDrawerId = drawer.id
                            } label: {
                                drawerOptionRow(drawer)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if pickedDrawerId != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Location label (optional)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.7))
                            TextField("e.g. Top drawer left of sink", text: $locationText)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.white.opacity(0.07))
                                )
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 4)

                        Button(action: commit) {
                            Text("Add to plan")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                )
                        }
                        .buttonStyle(PressableStyle())
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
            .navigationTitle("Add drawer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.5))
            Text("All your saved drawers are already in this plan.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Text("Scan a new drawer first, then come back here to add it.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func drawerOptionRow(_ drawer: SavedDrawer) -> some View {
        let picked = pickedDrawerId == drawer.id
        return HStack(spacing: 12) {
            if let data = drawer.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(drawer.layout.purpose.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: drawer.layout.purpose.icon)
                            .foregroundStyle(drawer.layout.purpose.color)
                    )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(drawer.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(drawer.layout.purpose.rawValue)
                    .font(.caption)
                    .foregroundStyle(drawer.layout.purpose.color)
            }
            Spacer()
            if picked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(picked ? 0.10 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(picked ? .green : .clear, lineWidth: 1.5)
                )
        )
    }

    private func commit() {
        guard let id = pickedDrawerId else { return }
        let entry = KitchenPlan.Entry(
            drawerId: id,
            location: locationText,
            order: plan.drawerEntries.count
        )
        plan.drawerEntries.append(entry)
        onChange()
        dismiss()
    }
}
