//
//  DesignSystem.swift
//  Drawer
//
//  Small shared style primitives used across screens. Keeps animations,
//  corner radii, and accent colors consistent without a heavy refactor.
//

import SwiftUI

enum DrawerRadius {
    static let card: CGFloat = 16
    static let chip: CGFloat = 12
    static let pill: CGFloat = 999
}

enum DrawerSpacing {
    static let sectionGap: CGFloat = 16
    static let edge: CGFloat = 20
}

enum DrawerAccent {
    static let primary = Color(hue: 0.6, saturation: 0.7, brightness: 0.95)
    static let secondary = Color(hue: 0.7, saturation: 0.6, brightness: 0.9)
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
}

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    var radius: CGFloat = DrawerRadius.card
    var stroke: Color = .white.opacity(0.06)
    var fill: Color = .white.opacity(0.05)

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(stroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassCard(radius: CGFloat = DrawerRadius.card,
                   stroke: Color = .white.opacity(0.06),
                   fill: Color = .white.opacity(0.05)) -> some View {
        modifier(GlassCard(radius: radius, stroke: stroke, fill: fill))
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let label: String
    var trailing: String? = nil
    var trailingColor: Color = .white.opacity(0.4)

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(2)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(trailingColor)
            }
        }
    }
}

// MARK: - Pressable Style

/// Button style that does a small press-in scale + opacity tick.
/// Tuned to feel snappy on press and gentle on release — same curve Apple
/// uses on system buttons in iOS 26.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.18, dampingFraction: 0.85)
                    : .spring(response: 0.32, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

// MARK: - Liquid Glass helpers

extension View {
    /// Wraps the view in a liquid-glass capsule chip — used for floating
    /// HUD-style controls that should feel material-aware.
    @ViewBuilder
    func liquidGlassCapsule(tint: Color? = nil) -> some View {
        if let tint {
            self.glassEffect(.regular.tint(tint).interactive(), in: Capsule())
        } else {
            self.glassEffect(.regular.interactive(), in: Capsule())
        }
    }
}

// MARK: - Primary Action Button

struct PrimaryActionButton<Content: View>: View {
    let action: () -> Void
    let tint: Color
    @ViewBuilder var content: () -> Content
    var isLoading: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
                content()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isDisabled
                        ? [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]
                        : [tint, tint.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DrawerRadius.card))
            .shadow(color: isDisabled ? .clear : tint.opacity(0.4),
                    radius: 12, y: 6)
        }
        .buttonStyle(PressableStyle())
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Animated Background

/// Subtle animated radial glow used as a background accent on major surfaces.
struct AmbientGlowBackground: View {
    let tint: Color
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 280
                    )
                )
                .frame(width: 380, height: 380)
                .scaleEffect(animate ? 1.1 : 0.85)
                .opacity(animate ? 0.7 : 0.4)
                .blur(radius: 40)
                .onAppear {
                    withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                }
        }
        .allowsHitTesting(false)
    }
}
