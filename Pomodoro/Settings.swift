import Observation
import UIKit

@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    /// Marks Pomodoro's alerts time-sensitive so they arrive during a Focus.
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

    /// Phase lengths, colours, and glyphs.
    var config: PomodoroConfig {
        didSet {
            guard config != oldValue else { return }
            if let data = try? JSONEncoder().encode(config) {
                store.set(data, forKey: "config")
            }
        }
    }

    private let store = UserDefaults.standard

    private init() {
        store.register(defaults: ["soundEnabled": true, "keepAwake": true, "quietMode": false])
        quietMode = store.bool(forKey: "quietMode")
        soundEnabled = store.bool(forKey: "soundEnabled")
        keepAwake = store.bool(forKey: "keepAwake")
        if let data = store.data(forKey: "config"),
           let decoded = try? JSONDecoder().decode(PomodoroConfig.self, from: data) {
            config = decoded
        } else {
            config = .standard
        }
    }
}
