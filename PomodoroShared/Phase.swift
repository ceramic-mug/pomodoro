import SwiftUI

enum Phase: String, CaseIterable, Identifiable, Codable {
    case focus, shortBreak, longBreak

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long Break"
        }
    }

    /// Compact duration label, e.g. "25 min".
    var lengthLabel: String {
        "\(Int(duration / 60)) min"
    }

    var accent: Color {
        switch self {
        case .focus: return Color(red: 1.00, green: 0.42, blue: 0.35)
        case .shortBreak: return Color(red: 0.31, green: 0.82, blue: 0.76)
        case .longBreak: return Color(red: 0.49, green: 0.60, blue: 1.00)
        }
    }

    var symbol: String {
        switch self {
        case .focus: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }

    /// Alert shown the moment this phase begins.
    var arrivalNotification: (title: String, body: String) {
        switch self {
        case .focus:
            return ("Break over", "25 minutes of focus. Begin.")
        case .shortBreak:
            return ("Focus complete", "Five minutes off. Look away from the screen.")
        case .longBreak:
            return ("Four sessions done", "Fifteen minutes. Stand up, walk it off.")
        }
    }
}
