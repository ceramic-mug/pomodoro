import SwiftUI

/// User-tunable phase lengths, in seconds.
struct Timings: Codable, Hashable {
    var focus: TimeInterval
    var shortBreak: TimeInterval
    var longBreak: TimeInterval

    static let standard = Timings(focus: 25 * 60, shortBreak: 5 * 60, longBreak: 15 * 60)

    /// Allowed range for each phase, in whole minutes.
    static func range(for phase: Phase) -> ClosedRange<Int> {
        switch phase {
        case .focus: return 5...90
        case .shortBreak: return 1...30
        case .longBreak: return 5...60
        }
    }

    func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: return focus
        case .shortBreak: return shortBreak
        case .longBreak: return longBreak
        }
    }

    func minutes(for phase: Phase) -> Int {
        Int((duration(for: phase) / 60).rounded())
    }

    mutating func setMinutes(_ minutes: Int, for phase: Phase) {
        let clamped = TimeInterval(min(max(minutes, Self.range(for: phase).lowerBound),
                                       Self.range(for: phase).upperBound)) * 60
        switch phase {
        case .focus: focus = clamped
        case .shortBreak: shortBreak = clamped
        case .longBreak: longBreak = clamped
        }
    }
}

/// Per-phase accent colours, stored as hex so they travel in the Live Activity.
struct Palette: Codable, Hashable {
    var focus: String
    var shortBreak: String
    var longBreak: String

    static let standard = Palette(focus: Swatch.ember.hex,
                                  shortBreak: Swatch.teal.hex,
                                  longBreak: Swatch.indigo.hex)

    func hex(for phase: Phase) -> String {
        switch phase {
        case .focus: return focus
        case .shortBreak: return shortBreak
        case .longBreak: return longBreak
        }
    }

    func color(for phase: Phase) -> Color {
        Color(hex: hex(for: phase)) ?? Swatch.ember.color
    }

    mutating func set(_ hex: String, for phase: Phase) {
        switch phase {
        case .focus: focus = hex
        case .shortBreak: shortBreak = hex
        case .longBreak: longBreak = hex
        }
    }
}

/// The curated accent choices offered in settings.
enum Swatch: String, CaseIterable, Identifiable {
    case ember, amber, rose, teal, mint, sky, indigo, violet

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .ember: return "#FF6B5A"
        case .amber: return "#FFB35C"
        case .rose: return "#FF7EA8"
        case .teal: return "#4FD1C2"
        case .mint: return "#6EE7A8"
        case .sky: return "#5AC8FA"
        case .indigo: return "#7C9CFF"
        case .violet: return "#B08CFF"
        }
    }

    var color: Color { Color(hex: hex) ?? .orange }
}

/// Per-phase glyphs. SF Symbols rather than emoji: they are monochrome and take
/// the phase's accent colour, which emoji cannot.
struct Glyphs: Codable, Hashable {
    var focus: String
    var shortBreak: String
    var longBreak: String

    static let standard = Glyphs(focus: "brain.head.profile",
                                 shortBreak: "cup.and.saucer.fill",
                                 longBreak: "figure.walk")

    /// Options are curated per phase — heads-down glyphs for focus, small
    /// comforts for a break, going-outside ones for a long break. All legible
    /// at dial size and in the Dynamic Island.
    static func options(for phase: Phase) -> [String] {
        switch phase {
        case .focus:
            return ["brain.head.profile", "bolt.fill", "target", "flame.fill",
                    "book.fill", "pencil.and.scribble", "laptopcomputer", "eye.fill"]
        case .shortBreak:
            return ["cup.and.saucer.fill", "leaf.fill", "wind", "drop.fill",
                    "music.note", "face.smiling", "sparkles", "hourglass"]
        case .longBreak:
            return ["figure.walk", "figure.run", "mountain.2.fill", "bed.double.fill",
                    "fork.knife", "sun.horizon.fill", "moon.stars.fill", "tortoise.fill"]
        }
    }

    func symbol(for phase: Phase) -> String {
        switch phase {
        case .focus: return focus
        case .shortBreak: return shortBreak
        case .longBreak: return longBreak
        }
    }

    mutating func set(_ symbol: String, for phase: Phase) {
        switch phase {
        case .focus: focus = symbol
        case .shortBreak: shortBreak = symbol
        case .longBreak: longBreak = symbol
        }
    }
}

struct PomodoroConfig: Codable, Hashable {
    var timings: Timings = .standard
    var palette: Palette = .standard
    var glyphs: Glyphs = .standard

    static let standard = PomodoroConfig()

    func duration(for phase: Phase) -> TimeInterval { timings.duration(for: phase) }
    func color(for phase: Phase) -> Color { palette.color(for: phase) }
    func symbol(for phase: Phase) -> String { glyphs.symbol(for: phase) }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
