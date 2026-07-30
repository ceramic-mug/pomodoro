import Foundation

/// The single source of truth for the cycle, shared by the app and the widget
/// extension: focus / break, four times over, with the last break long.
/// Phase lengths come from the user's `Timings`.
enum Cycle {
    static let pattern: [Phase] = [
        .focus, .shortBreak,
        .focus, .shortBreak,
        .focus, .shortBreak,
        .focus, .longBreak
    ]

    static func length(_ timings: Timings) -> TimeInterval {
        pattern.reduce(0) { $0 + timings.duration(for: $1) }
    }

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
        /// The current phase's full length, for progress.
        var phaseDuration: TimeInterval
    }

    static func position(at elapsed: TimeInterval, timings: Timings) -> Position {
        let total = length(timings)
        let clamped = max(elapsed, 0)
        let cyclesDone = total > 0 ? Int(floor(clamped / total)) : 0
        let cycleStart = Double(cyclesDone) * total
        var offset = clamped - cycleStart
        var consumed: TimeInterval = 0

        for (index, phase) in pattern.enumerated() {
            let duration = timings.duration(for: phase)
            if offset < duration {
                return Position(
                    phase: phase,
                    next: pattern[(index + 1) % pattern.count],
                    indexInPattern: index,
                    remaining: duration - offset,
                    focusDoneInCycle: pattern[0..<index].filter { $0 == .focus }.count,
                    cyclesDone: cyclesDone,
                    phaseStartElapsed: cycleStart + consumed,
                    phaseDuration: duration
                )
            }
            offset -= duration
            consumed += duration
        }
        // Unreachable while offset < total; fall back to the cycle start.
        return Position(phase: pattern[0], next: pattern[1], indexInPattern: 0,
                        remaining: timings.duration(for: pattern[0]), focusDoneInCycle: 0,
                        cyclesDone: cyclesDone, phaseStartElapsed: cycleStart,
                        phaseDuration: timings.duration(for: pattern[0]))
    }

    /// Where the cycle stands right now for a session anchored at `anchor`,
    /// with the current phase's absolute bounds. Lets the widget re-derive the
    /// phase at render time instead of trusting a snapshot the app may not have
    /// been awake to update.
    static func slot(anchor: Date, timings: Timings, now: Date = Date()) -> (position: Position, start: Date, end: Date) {
        let position = position(at: now.timeIntervalSince(anchor), timings: timings)
        let start = anchor.addingTimeInterval(position.phaseStartElapsed)
        return (position, start, start.addingTimeInterval(position.phaseDuration))
    }
}
