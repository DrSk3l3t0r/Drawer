//
//  ContentView.swift
//  Drawer
//
//  Created by Seth Sullivan on 3/23/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = DrawerStore()

    @State private var showCapture = false
    @State private var navigateToReview = false
    @State private var navigateToPurpose = false
    @State private var navigateToLayout = false

    @State private var capturedImage: UIImage?
    @State private var measurement: DrawerMeasurement?
    @State private var generatedLayout: DrawerLayout?

    @State private var selectedTab = 0
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "0D1117"), Color(hex: "161B22"), Color(hex: "0D1117")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                    homeTab
                        .tag(0)

                    SavedDrawersView()
                        .environmentObject(store)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: selectedTab)

                LiquidGlassBottomBar(
                    selectedTab: $selectedTab,
                    onScan: { showCapture = true }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 24)
                .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05),
                           value: hasAppeared)
            }
        }
        .onAppear { hasAppeared = true }
        .fullScreenCover(isPresented: $showCapture) {
            NavigationStack {
                CaptureView(
                    navigateToReview: $navigateToReview,
                    capturedImage: $capturedImage,
                    measurement: $measurement
                )
                .navigationDestination(isPresented: $navigateToReview) {
                    MeasurementReviewView(
                        image: capturedImage,
                        measurement: Binding(
                            get: { measurement ?? MeasurementEngine.createDefaultMeasurement() },
                            set: { measurement = $0 }
                        ),
                        navigateToPurpose: $navigateToPurpose
                    )
                    .navigationDestination(isPresented: $navigateToPurpose) {
                        PurposeSelectionView(
                            measurement: measurement ?? MeasurementEngine.createDefaultMeasurement(),
                            capturedImage: capturedImage,
                            navigateToLayout: $navigateToLayout,
                            generatedLayout: $generatedLayout
                        )
                        .navigationDestination(isPresented: $navigateToLayout) {
                            if let layout = generatedLayout {
                                LayoutResultView(
                                    layout: layout,
                                    capturedImage: capturedImage
                                )
                                .environmentObject(store)
                                // Force a fresh `LayoutResultView` instance per
                                // generated layout. Without this, SwiftUI
                                // reuses the destination and `@State var layout`
                                // keeps its first-seen value — so picking a new
                                // category and tapping Generate would still
                                // render the previous category's items.
                                .id("\(layout.purpose.rawValue)-\(layout.items.first?.id.uuidString ?? "empty")")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Home Tab
    
    private var homeTab: some View {
        ScrollView {
            VStack(spacing: 36) {
                Spacer().frame(height: 32)

                // App header (logo + title)
                appHeader

                // How it works (the only "content" section on home —
                // scanning is launched from the bar's FAB, saved drawers
                // live on the Saved tab, so there's no need to duplicate
                // those affordances here).
                tipsSection

                // Bottom inset so the floating Liquid Glass bar doesn't
                // overlap content on devices with a home indicator.
                Spacer().frame(height: 132)
            }
        }
    }
    
    // MARK: - App Header
    
    private var appHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                // Soft breathing glow — uses phaseAnimator for buttery smoothness.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hue: 0.6, saturation: 0.8, brightness: 0.9).opacity(0.3), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .phaseAnimator([0.9, 1.1]) { content, scale in
                        content.scaleEffect(scale)
                    } animation: { _ in
                        .easeInOut(duration: 2.4)
                    }

                Image(systemName: "square.split.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hue: 0.55, saturation: 0.7, brightness: 0.95),
                                Color(hue: 0.7, saturation: 0.6, brightness: 0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hue: 0.6, saturation: 0.8, brightness: 0.9).opacity(0.5),
                            radius: 20)
                    .symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
            }

            Text("Drawer")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Smart Kitchen Drawer Organization")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    // MARK: - Tips
    
    private var tipsSection: some View {
        let tips: [(String, String, String, String)] = [
            ("1", "camera.fill", "Capture", "Take a photo of your empty drawer"),
            ("2", "ruler.fill", "Measure", "Auto-detect dimensions with LiDAR or camera"),
            ("3", "tag.fill", "Purpose", "Tell us what you'll store in the drawer"),
            ("4", "wand.and.stars", "Optimize", "Get a custom organization layout")
        ]
        return VStack(alignment: .leading, spacing: 14) {
            Text("HOW IT WORKS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(2)

            ForEach(Array(tips.enumerated()), id: \.offset) { idx, tip in
                TipRow(step: tip.0, icon: tip.1, title: tip.2, desc: tip.3)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : -16)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.82)
                            .delay(0.18 + Double(idx) * 0.06),
                        value: hasAppeared
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.04))
        )
        .padding(.horizontal, 20)
    }
    
}

// MARK: - Supporting Views

struct TipRow: View {
    let step: String
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hue: 0.6, saturation: 0.5, brightness: 0.9).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hue: 0.6, saturation: 0.5, brightness: 0.9))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
            
            Text(step)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.2))
        }
    }
}

// MARK: - Liquid Glass Bottom Bar

/// Floating navigation bar built on iOS 26 native Liquid Glass.
/// Tabs sit on either side of a centered scan FAB; the bar uses
/// `.glassEffect()` for the real Apple liquid material, and the FAB
/// gets its own interactive tinted glass that physically reacts to touch.
struct LiquidGlassBottomBar: View {
    @Binding var selectedTab: Int
    let onScan: () -> Void

    @Namespace private var tabSelectionNS
    @State private var scanBounce = 0

    var body: some View {
        // Two separate glass surfaces (bar pill and FAB) — no
        // GlassEffectContainer here. Wrapping them produced visual artifacts
        // where the inner selection pill subtracted from the outer bar's
        // glass, making the selected tab read as a dark hole. With separate
        // surfaces each gets its own clean refraction.
        ZStack {
            // The bar — single rounded glass capsule with tabs spread on
            // either side of the centered FAB cutout.
            HStack(spacing: 0) {
                barTab(icon: "house.fill", label: "Home", index: 0)
                Spacer().frame(width: 78)   // room for the floating FAB
                barTab(icon: "archivebox.fill", label: "Saved", index: 1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())

            // Scan FAB — interactive, tinted glass that floats above center.
            Button {
                scanBounce += 1
                onScan()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .symbolEffect(.bounce, value: scanBounce)
                    .contentShape(Circle())   // explicit hit shape for reliable taps
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular
                    .tint(Color(hue: 0.6, saturation: 0.7, brightness: 0.95).opacity(0.45))
                    .interactive(),
                in: Circle()
            )
            .offset(y: -10)
            .accessibilityLabel("Scan New Drawer")
            .sensoryFeedback(.impact(weight: .medium), trigger: scanBounce)
        }
        // Extend the ZStack's hit-test region above the bar so the FAB's
        // upward offset doesn't put its top edge outside the parent's
        // bounds — that was causing the "FAB doesn't always tap" issue.
        .padding(.top, 12)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private func barTab(icon: String, label: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                if isSelected {
                    // Simple translucent capsule — readable as a selection
                    // indicator on top of the bar's glass without trying to
                    // be its own glass surface (which produced visual
                    // subtraction artifacts inside the parent glass).
                    Capsule()
                        .fill(.white.opacity(0.20))
                        .overlay(
                            Capsule().strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                        )
                        .matchedGeometryEffect(id: "tabSelection", in: tabSelectionNS)
                        .padding(.horizontal, 6)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle(scale: 0.94))
    }
}

#Preview {
    ContentView()
}
