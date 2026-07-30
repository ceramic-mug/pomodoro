import Observation
import UIKit

@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    /// Marks Pomodoro's alerts time-sensitive and surfaces the Shortcuts
    /// automation that flips system Do Not Disturb — iOS gives apps no API to
    /// toggle Focus modes directly.
    var quietMode: Bool {
        didSet { store.set(quietMode, forKey: "quietMode") }
    }

    var soundEnabled: Bool {
        didSet { store.set(soundEnabled, forKey: "soundEnabled") }
    }

    var keepAwake: Bool {
        didSet {
            store.set(keepAwake, forKey: "keepAwake")
            if !keepAwake { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    private let store = UserDefaults.standard

    private init() {
        store.register(defaults: ["soundEnabled": true, "keepAwake": true, "quietMode": false])
        quietMode = store.bool(forKey: "quietMode")
        soundEnabled = store.bool(forKey: "soundEnabled")
        keepAwake = store.bool(forKey: "keepAwake")
    }
}
