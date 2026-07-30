import SwiftUI

@main
struct PomodoroApp: App {
    private let timer = PomodoroTimer.shared

    var body: some Scene {
        WindowGroup {
            TimerScreen(timer: timer)
                .preferredColorScheme(.dark)
        }
    }
}
