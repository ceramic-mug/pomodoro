import AppIntents

/// Exposed so a Shortcuts automation can wrap a session in Do Not Disturb —
/// "Turn On Do Not Disturb → Start Pomodoro", and the reverse on stop. iOS has
/// no API for an app to set a Focus mode itself.
struct StartPomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Pomodoro"
    static var description = IntentDescription("Starts the 25-5 focus cycle.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let timer = PomodoroTimer.shared
        timer.start()
        return .result(dialog: "Focus started.")
    }
}

struct PausePomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Pomodoro"
    static var description = IntentDescription("Pauses the running cycle.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        PomodoroTimer.shared.pause()
        return .result(dialog: "Paused.")
    }
}

struct StopPomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Pomodoro"
    static var description = IntentDescription("Stops the cycle and returns to the first focus session.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        PomodoroTimer.shared.reset()
        return .result(dialog: "Stopped.")
    }
}

struct PomodoroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPomodoroIntent(),
            phrases: ["Start \(.applicationName)", "Start a focus session in \(.applicationName)"],
            shortTitle: "Start",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PausePomodoroIntent(),
            phrases: ["Pause \(.applicationName)"],
            shortTitle: "Pause",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: StopPomodoroIntent(),
            phrases: ["Stop \(.applicationName)"],
            shortTitle: "Stop",
            systemImageName: "stop.fill"
        )
    }
}
