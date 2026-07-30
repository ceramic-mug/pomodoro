import ActivityKit
import Foundation

/// Mirrors the timer into a Live Activity, which is what StandBy shows
/// full-screen when the phone is charging in landscape (and what appears on the
/// Lock Screen and in the Dynamic Island).
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<PomodoroActivityAttributes>?
    private var sessionStart = Date()

    private init() {
        // Reattach after a relaunch so we update the existing activity rather
        // than stacking a second one.
        activity = Activity<PomodoroActivityAttributes>.activities.first
    }

    private var enabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func sync(_ state: PomodoroActivityAttributes.ContentState) {
        guard enabled else { return }
        // No stale date while running: the widget derives the phase from the
        // anchor at render time, so the content never goes out of date.
        let content = ActivityContent(state: state, staleDate: nil)

        if let activity {
            Task { await activity.update(content) }
        } else {
            sessionStart = Date()
            do {
                activity = try Activity.request(
                    attributes: PomodoroActivityAttributes(sessionStart: sessionStart),
                    content: content,
                    pushType: nil
                )
            } catch {
                activity = nil
            }
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
