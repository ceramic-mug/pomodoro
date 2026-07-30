import ActivityKit
import Foundation

/// Shared between the app (which drives the Live Activity) and the widget
/// extension (which renders it on the Lock Screen, in the Dynamic Island, and
/// full-screen in StandBy while charging in landscape).
struct PomodoroActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The date the session's elapsed time is measured from. The widget
        /// derives the live phase from this, so the display stays correct even
        /// across phase boundaries the app slept through.
        var anchor: Date
        var isRunning: Bool
        /// Frozen snapshot, used while paused (no anchor to derive from).
        var pausedPhase: Phase
        var pausedRemaining: TimeInterval
        var pausedFocusDone: Int
        var pausedCyclesDone: Int
    }

    /// When the session began — stable identity for the activity.
    var sessionStart: Date
}
