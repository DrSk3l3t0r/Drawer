//
//  SavedDrawersView.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI

struct SavedDrawersView: View {
    @EnvironmentObject var store: DrawerStore
    @State private var selectedDrawer: SavedDrawer?
    @State private var hasAppeared = false

    var body: some View {
        Group {
            if store.savedDrawers.isEmpty {
                emptyState
            } else {
                drawerList
            }
        }
        .onAppear { hasAppeared = true }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 50))
                .foregroundStyle(.gray.opacity(0.4))
                .symbolEffect(.pulse, options: .repeat(.continuous))

            Text("No Saved Drawers")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.6))

            Text("Scan a drawer and save the layout\nto see it here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Drawer List
    
    private var drawerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(store.savedDrawers.enumerated()), id: \.element.id) { index, drawer in
                    SavedDrawerCard(drawer: drawer)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedDrawer = drawer
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation(.spring()) {
                                    store.delete(drawer)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 16)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.82)
                                .delay(0.04 * Double(min(index, 8))),
                            value: hasAppeared
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.85))
                        ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
            .animation(.spring(response: 0.45, dampingFraction: 0.8),
                       value: store.savedDrawers.map { $0.id })
        }
        .sheet(item: $selectedDrawer) { drawer in
            NavigationView {
                LayoutResultView(
                    layout: drawer.layout,
                    capturedImage: drawer.photoData.flatMap { UIImage(data: $0) }
                )
                .environmentObject(store)
            }
        }
    }
}

// MARK: - Saved Drawer Card

struct SavedDrawerCard: View {
    let drawer: SavedDrawer

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail or icon
            ZStack {
                if let photoData = drawer.photoData,
                   let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(drawer.layout.purpose.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: drawer.layout.purpose.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(drawer.layout.purpose.color)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(drawer.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text(drawer.layout.purpose.rawValue)
                    .font(.caption)
                    .foregroundStyle(drawer.layout.purpose.color)

                Text("\(drawer.layout.measurement.formattedWidth) × \(drawer.layout.measurement.formattedDepth) • \(drawer.layout.items.count) items")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(drawer.date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.25))
            }
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
