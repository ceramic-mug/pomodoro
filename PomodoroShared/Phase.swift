import Foundation

enum Phase: String, CaseIterable, Identifiable, Codable {
    case focus, shortBreak, longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long Break"
        }
    }

    /// Alert shown the moment this phase begins, phrased with the user's own lengths.
    func arrivalNotification(minutes: Int) -> (title: String, body: String) {
        switch self {
        case .focus:
            return ("Break over", "\(minutes) minutes of focus. Begin.")
        case .shortBreak:
            return ("Focus complete", "\(minutes) minutes off. Look away from the screen.")
        case .longBreak:
            return ("Four sessions done", "\(minutes) minutes. Stand up, walk it off.")
        }
    }
}
