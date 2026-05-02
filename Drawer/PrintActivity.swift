//
//  PrintActivity.swift
//  Drawer
//
//  ActivityKit infrastructure for tracking print progress on the Lock Screen
//  + Dynamic Island + an in-app fallback tracker.
//
//  How this is wired:
//  - `PrintActivityAttributes` defines the activity's static + dynamic data.
//    These types are shared between the main app and a Widget Extension.
//  - `PrintProgressManager` (singleton) starts / updates / ends activities
//    and also drives the in-app tracker view.
//  - `PrintTrackerView` is the in-app fallback when no Widget Extension is
//    embedded (Lock-Screen + Dynamic Island rendering both require a
//    separate Widget Extension target — see SETUP NOTES below).
//
//  SETUP NOTES (one-time, Xcode UI):
//  -----------------------------------------------------------------------
//  To get the Lock-Screen / Dynamic Island UI rendering, add a Widget
//  Extension target via Xcode → File → New → Target → "Widget Extension",
//  named "DrawerWidgets". Check "Include Live Activity" so Xcode scaffolds
//  the `ActivityConfiguration` for you. Then:
//    1. Move (don't copy) `PrintActivityAttributes` into a shared file
//       added to BOTH the app target AND the widget extension target.
//    2. In the widget extension's auto-generated `LiveActivity` view,
//       reference `PrintActivityAttributes.ContentState`.
//    3. Build & run the app target. Starting a print kicks off a Live
//       Activity which shows on the Lock Screen and (on iPhone 14 Pro+)
//       in the Dynamic Island.
//  Until then, the in-app `PrintTrackerView` provides equivalent feedback.
//

import Foundation
import SwiftUI
import Combine
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Activity attributes

/// Static + dynamic state for a Drawer print Live Activity.
///
/// The static `attributes` set once at start. The `ContentState` updates
/// every few seconds as the print progresses.
struct PrintActivityAttributes: Codable, Hashable {
    /// Drawer label (e.g. "Utensils Drawer").
    let drawerName: String
    /// Bambu A1 / A1 mini etc.
    let printerName: String
    /// Total grams the print should consume — surfaced in the activity body.
    let totalGrams: Double
    /// Total estimated print time in seconds.
    let totalSeconds: Int

    /// Ticks every few seconds while the print runs.
    struct ContentState: Codable, Hashable {
        /// 0…1 progress fraction.
        var progress: Double
        /// Seconds remaining in the print.
        var remainingSeconds: Int
        /// Current operation label ("Heating bed", "Layer 42 of 175", etc.).
        var statusLabel: String
        /// Whether the print has finished.
        var isComplete: Bool

        var formattedRemaining: String {
            let m = max(0, remainingSeconds)
            let h = m / 3600
            let mm = (m % 3600) / 60
            if h > 0 { return "\(h) hr \(mm) min" }
            return "\(mm) min"
        }
    }
}

#if canImport(ActivityKit)
extension PrintActivityAttributes: ActivityAttributes {}
#endif

// MARK: - Manager

/// Manages the lifecycle of a Drawer print Live Activity, plus a parallel
/// SwiftUI-observable timer that powers the in-app tracker.
///
/// Single shared instance — only one print activity makes sense at a time.
@MainActor
final class PrintProgressManager: ObservableObject {
    static let shared = PrintProgressManager()
    private init() {}

    @Published var attributes: PrintActivityAttributes?
    @Published var state: PrintActivityAttributes.ContentState?
    /// Wall-clock time the print was started (for in-app countdown).
    private var startedAt: Date?
    private var tickTimer: Timer?

    #if canImport(ActivityKit)
    private var activity: Activity<PrintActivityAttributes>?
    #endif

    /// Start a new print activity. Stops any existing one first.
    func start(attributes: PrintActivityAttributes) {
        stop()
        self.attributes = attributes
        self.state = .init(progress: 0,
                           remainingSeconds: attributes.totalSeconds,
                           statusLabel: "Preparing print",
                           isComplete: false)
        self.startedAt = Date()

        #if canImport(ActivityKit)
        if #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                let initial = ActivityContent(state: state!,
                                                staleDate: nil)
                let act = try Activity<PrintActivityAttributes>.request(
                    attributes: attributes,
                    content: initial,
                    pushType: nil
                )
                self.activity = act
            } catch {
                // Live Activities unavailable (no Widget Extension target,
                // or user disabled them). Fall back to in-app only.
                self.activity = nil
            }
        }
        #endif

        // Tick once per second; in-app view recomputes UI from state.
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in self.tick() }
        }
    }

    /// Periodic update — called both by the wall-clock timer and externally
    /// when the user gets explicit progress info from a printer integration.
    func tick() {
        guard let attrs = attributes,
              let started = startedAt,
              var newState = state,
              !newState.isComplete else { return }

        let elapsed = Int(Date().timeIntervalSince(started))
        let remaining = max(0, attrs.totalSeconds - elapsed)
        let progress = min(1.0, Double(elapsed) / Double(max(1, attrs.totalSeconds)))

        newState.progress = progress
        newState.remainingSeconds = remaining
        newState.statusLabel = computeStatusLabel(progress: progress, attrs: attrs)
        newState.isComplete = progress >= 1.0

        self.state = newState
        Task { await pushUpdate(newState) }

        if newState.isComplete {
            stop()
        }
    }

    /// Manually mark the print as complete (e.g. user tapped "Done printing").
    func complete() {
        guard var newState = state else { return }
        newState.progress = 1
        newState.remainingSeconds = 0
        newState.statusLabel = "Print finished"
        newState.isComplete = true
        self.state = newState
        Task { await pushUpdate(newState) }
        stop()
    }

    /// Cancel everything and clear state.
    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil

        #if canImport(ActivityKit)
        if #available(iOS 16.1, *), let act = activity {
            Task {
                let final = ActivityContent(
                    state: state ?? .init(progress: 1,
                                            remainingSeconds: 0,
                                            statusLabel: "Print ended",
                                            isComplete: true),
                    staleDate: nil
                )
                await act.end(final, dismissalPolicy: .default)
            }
            activity = nil
        }
        #endif
    }

    // MARK: - Internal

    private func pushUpdate(_ s: PrintActivityAttributes.ContentState) async {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *), let act = activity {
            let content = ActivityContent(state: s, staleDate: nil)
            await act.update(content)
        }
        #endif
    }

    private func computeStatusLabel(progress: Double,
                                      attrs: PrintActivityAttributes) -> String {
        // Rough phase labels driven by progress — without a real printer
        // integration we can only approximate. Maps to the typical Bambu A1
        // print phases observed by Bambu Studio.
        switch progress {
        case 0..<0.02:  return "Heating bed"
        case 0.02..<0.05: return "Calibrating"
        case 0.05..<0.08: return "Purging filament"
        case 0.08..<0.95: return "Printing"
        case 0.95..<1.00: return "Finishing"
        default:        return "Print finished"
        }
    }
}

// MARK: - In-app tracker view

/// Displays current print progress within the app — used as a fallback when
/// the Widget Extension hasn't been added to the project (so Live Activities
/// can't render on the Lock Screen yet).
struct PrintTrackerView: View {
    @ObservedObject var manager = PrintProgressManager.shared

    var body: some View {
        if let attrs = manager.attributes, let state = manager.state {
            VStack(spacing: 14) {
                header(attrs: attrs)
                progressCard(state: state)
                statsRow(attrs: attrs, state: state)
                actions(state: state)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
            )
        } else {
            EmptyView()
        }
    }

    private func header(attrs: PrintActivityAttributes) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(attrs.drawerName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(attrs.printerName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text("Live")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.green)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.green.opacity(0.18))
                .clipShape(Capsule())
        }
    }

    private func progressCard(state: PrintActivityAttributes.ContentState) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: state.progress)
                .tint(.green)
            HStack {
                Text(state.statusLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(state.progress * 100))%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.green)
            }
        }
    }

    private func statsRow(attrs: PrintActivityAttributes,
                            state: PrintActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            stat(label: "Remaining", value: state.formattedRemaining)
            stat(label: "Filament", value: String(format: "%.0f g", attrs.totalGrams))
            stat(label: "Total", value: formatSeconds(attrs.totalSeconds))
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private func actions(state: PrintActivityAttributes.ContentState) -> some View {
        HStack(spacing: 8) {
            Button {
                PrintProgressManager.shared.complete()
            } label: {
                Label("Mark complete", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.20))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(state.isComplete)

            Button {
                PrintProgressManager.shared.stop()
            } label: {
                Label("Stop", systemImage: "xmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.20))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatSeconds(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h) hr \(m) min" }
        return "\(m) min"
    }
}
