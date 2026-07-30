import Foundation

/// The single source of truth for the cycle, shared by the app and the widget
/// extension: 25-5-25-5-25-5-25-15, then it repeats.
enum Cycle {
    static let pattern: [Phase] = [
        .focus, .shortBreak,
        .focus, .shortBreak,
        .focus, .shortBreak,
        .focus, .longBreak
    ]

    static let length: TimeInterval = pattern.reduce(0) { $0 + $1.duration }

    struct Position {
        var phase: Phase
        var next: Phase
        var indexInPattern: Int
        var remaining: TimeInterval
        /// Focus sessions finished inside the current cycle.
        var focusDoneInCycle: Int
        /// Completed cycles this session.
        var cyclesDone: Int
        /// Seconds from the session start to the beginning of this phase.
        var phaseStartElapsed: TimeInterval
    }

    static func position(at elapsed: TimeInterval) -> Position {
        let clamped = max(elapsed, 0)
        let cyclesDone = Int(floor(clamped / length))
        let cycleStart = Double(cyclesDone) * length
        var offset = clamped - cycleStart
        var consumed: TimeInterval = 0

        for (index, phase) in pattern.enumerated() {
            if offset < phase.duration {
                return Position(
                    phase: phase,
                    next: pattern[(index + 1) % pattern.count],
                    indexInPattern: index,
                    remaining: phase.duration - offset,
                    focusDoneInCycle: pattern[0..<index].filter { $0 == .focus }.count,
                    cyclesDone: cyclesDone,
                    phaseStartElapsed: cycleStart + consumed
                )
            }
            offset -= phase.duration
            consumed += phase.duration
        }
        // Unreachable while offset < length; fall back to the cycle start.
        return Position(phase: pattern[0], next: pattern[1], indexInPattern: 0,
                        remaining: pattern[0].duration, focusDoneInCycle: 0,
                        cyclesDone: cyclesDone, phaseStartElapsed: cycleStart)
    }

    /// Where the cycle stands right now for a session anchored at `anchor`,
    /// with the current phase's absolute bounds. Lets the widget re-derive the
    /// phase at render time instead of trusting a snapshot the app may not have
    /// been awake to update.
    static func slot(anchor: Date, now: Date = Date()) -> (position: Position, start: Date, end: Date) {
        let position = position(at: now.timeIntervalSince(anchor))
        let start = anchor.addingTimeInterval(position.phaseStartElapsed)
        return (position, start, start.addingTimeInterval(position.phase.duration))
    }
}
