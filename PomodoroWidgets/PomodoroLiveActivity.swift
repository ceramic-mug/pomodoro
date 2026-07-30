import ActivityKit
import SwiftUI
import WidgetKit

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            let view = Snapshot(state: context.state)
            LockScreenView(view: view)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(view.accent)
        } dynamicIsland: { context in
            let view = Snapshot(state: context.state)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(view.phase.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    } icon: {
                        Image(systemName: view.symbol)
                    }
                    .foregroundStyle(view.accent)
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(view: view, size: 17)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SegmentBar(view: view)
                        .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: view.symbol)
                    .foregroundStyle(view.accent)
            } compactTrailing: {
                CountdownText(view: view, size: 13)
                    .frame(width: 46)
            } minimal: {
                Ring(view: view, lineWidth: 3)
            }
            .keylineTint(view.accent)
        }
    }
}

/// What to draw right now. While running this is re-derived from the anchor at
/// render time, so a phase boundary the app slept through still shows correctly.
private struct Snapshot {
    let phase: Phase
    let index: Int
    let isRunning: Bool
    let range: ClosedRange<Date>
    let remaining: TimeInterval

    let config: PomodoroConfig

    init(state: PomodoroActivityAttributes.ContentState) {
        isRunning = state.isRunning
        config = state.config
        if state.isRunning {
            let slot = Cycle.slot(anchor: state.anchor, timings: state.config.timings)
            phase = slot.position.phase
            index = slot.position.indexInPattern
            remaining = slot.position.remaining
            range = slot.start...max(slot.end, slot.start.addingTimeInterval(1))
        } else {
            phase = state.pausedPhase
            index = Self.index(phase: state.pausedPhase, focusDone: state.pausedFocusDone)
            remaining = state.pausedRemaining
            let start = Date()
            range = start...start.addingTimeInterval(max(state.pausedRemaining, 1))
        }
    }

    var accent: Color { config.color(for: phase) }
    var symbol: String { config.symbol(for: phase) }

    var progress: Double {
        let total = config.duration(for: phase)
        guard total > 0 else { return 0 }
        return min(max(1 - remaining / total, 0), 1)
    }

    private static func index(phase: Phase, focusDone: Int) -> Int {
        for (i, candidate) in Cycle.pattern.enumerated() {
            let done = Cycle.pattern[0..<i].filter { $0 == .focus }.count
            if candidate == phase && done == focusDone { return i }
        }
        return 0
    }
}

// MARK: - Lock Screen / StandBy

private struct LockScreenView: View {
    let view: Snapshot

    var body: some View {
        HStack(spacing: 16) {
            Ring(view: view, lineWidth: 6)
                .frame(width: 54, height: 54)
                .overlay {
                    Image(systemName: view.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(view.accent)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(view.isRunning ? view.phase.title : "\(view.phase.title) · Paused")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                CountdownText(view: view, size: 38, weight: .thin)

                SegmentBar(view: view)
                    .padding(.top, 3)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

// MARK: - Pieces

private struct CountdownText: View {
    let view: Snapshot
    let size: CGFloat
    var weight: Font.Weight = .regular

    var body: some View {
        Group {
            if view.isRunning {
                // System-driven: keeps ticking with no further activity updates.
                Text(timerInterval: view.range, countsDown: true)
            } else {
                Text(frozen)
            }
        }
        .font(.system(size: size, weight: weight, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
    }

    private var frozen: String {
        let seconds = Int(view.remaining.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct Ring: View {
    let view: Snapshot
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: lineWidth)

            if view.isRunning {
                ProgressView(timerInterval: view.range, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(view.accent)
            } else {
                Circle()
                    .trim(from: 0, to: view.progress)
                    .stroke(view.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

/// The eight segments of the cycle, current one lit.
private struct SegmentBar: View {
    let view: Snapshot

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(Cycle.pattern.enumerated()), id: \.offset) { i, phase in
                Capsule()
                    .fill(i < view.index ? view.accent.opacity(0.4)
                          : i == view.index ? view.config.color(for: phase)
                          : Color.white.opacity(0.16))
                    .frame(width: phase == .focus ? 20 : phase == .longBreak ? 12 : 5, height: 3)
            }
        }
    }
}
