import Foundation
import Observation
import SwiftUI
import UIKit
import UserNotifications

/// Drives an endless 25-5-25-5-25-5-15 cycle.
///
/// Nothing is stepped by the ticker: the current phase and its remaining time
/// are *derived* from `anchor`, the absolute date the session's elapsed time is
/// measured from. That keeps the cycle correct while the app is backgrounded,
/// suspended, or killed, and lets the whole chain of phase-change alerts be
/// scheduled up front.
@MainActor
@Observable
final class PomodoroTimer {
    static let shared = PomodoroTimer()

    static let pattern = Cycle.pattern

    private(set) var isRunning = false
    private(set) var elapsed: TimeInterval = 0

    private var anchor: Date?
    private var pausedElapsed: TimeInterval = 0
    private var ticker: Timer?
    private var lastSeenPhase: Phase?

    private let store = UserDefaults.standard
    private let settings = Settings.shared

    /// How many phase boundaries get an alert queued ahead of time. iOS allows
    /// 64 pending requests; 28 covers ~7 hours and is replenished on foreground.
    private let scheduledBoundaries = 28

    private init() {
        restore()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Derived state

    typealias Position = Cycle.Position

    static let cycleLength = Cycle.length

    var position: Position { Cycle.position(at: elapsed) }

    var phase: Phase { position.phase }
    var remaining: TimeInterval { position.remaining }

    var progress: Double {
        let p = position
        return min(max(1 - p.remaining / p.phase.duration, 0), 1)
    }

    var clock: String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// True before the first start of a session — used to hide "reset".
    var isFresh: Bool { !isRunning && elapsed == 0 }

    // MARK: - Controls

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        anchor = Date().addingTimeInterval(-pausedElapsed)
        isRunning = true
        lastSeenPhase = phase
        applyIdleTimer()
        startTicker()
        scheduleAlerts()
        persist()
        pushActivity()
        Haptics.tap()
    }

    func pause() {
        guard isRunning else { return }
        pausedElapsed = elapsed
        isRunning = false
        anchor = nil
        stopTicker()
        cancelAlerts()
        UIApplication.shared.isIdleTimerDisabled = false
        persist()
        pushActivity()
        Haptics.tap()
    }

    /// Back to the top of the cycle, stopped.
    func reset() {
        stopTicker()
        cancelAlerts()
        isRunning = false
        anchor = nil
        pausedElapsed = 0
        elapsed = 0
        lastSeenPhase = nil
        UIApplication.shared.isIdleTimerDisabled = false
        persist()
        LiveActivityController.shared.end()
        Haptics.tap()
    }

    /// Jump to the start of the next phase, keeping run state.
    func skip() {
        let target = elapsed + position.remaining
        seek(to: target)
        Haptics.tap()
    }

    // MARK: - Live Activity

    private var activityState: PomodoroActivityAttributes.ContentState {
        let p = position
        return .init(
            anchor: anchor ?? Date().addingTimeInterval(-elapsed),
            isRunning: isRunning,
            pausedPhase: p.phase,
            pausedRemaining: p.remaining,
            pausedFocusDone: p.focusDoneInCycle,
            pausedCyclesDone: p.cyclesDone
        )
    }

    private func pushActivity() {
        LiveActivityController.shared.sync(activityState)
    }

    private func seek(to newElapsed: TimeInterval) {
        elapsed = newElapsed
        if isRunning {
            anchor = Date().addingTimeInterval(-newElapsed)
            scheduleAlerts()
        } else {
            pausedElapsed = newElapsed
        }
        lastSeenPhase = phase
        persist()
        pushActivity()
    }

    /// Recomputes from the anchor — call on foreground and every tick.
    func sync() {
        guard isRunning, let anchor else { return }
        let now = Date().timeIntervalSince(anchor)
        let previous = lastSeenPhase
        withAnimation(.easeInOut(duration: 0.5)) {
            elapsed = now
        }
        let current = phase
        if let previous, previous != current {
            Haptics.success()
            pushActivity()
        }
        lastSeenPhase = current
    }

    /// Foreground refresh: resync, top the alert queue back up, and correct the
    /// Live Activity, which cannot advance itself past a phase boundary while
    /// the app is suspended.
    func refresh() {
        sync()
        if isRunning {
            scheduleAlerts()
            pushActivity()
        }
    }

    // MARK: - Ticker

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = settings.keepAwake && isRunning
    }

    // MARK: - Alerts

    private static let alertPrefix = "pomodoro.boundary."

    /// Queues one alert per upcoming phase change, so the cycle announces itself
    /// whether or not the app is running.
    private func scheduleAlerts() {
        cancelAlerts()
        let center = UNUserNotificationCenter.current()
        var cursor = elapsed

        for index in 0..<scheduledBoundaries {
            let here = Cycle.position(at: cursor)
            let boundary = cursor + here.remaining
            let delay = boundary - elapsed
            guard delay > 0.5 else { break }

            let arriving = here.next
            let copy = arriving.arrivalNotification
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = settings.soundEnabled ? .default : nil
            content.interruptionLevel = settings.quietMode ? .timeSensitive : .active

            let request = UNNotificationRequest(
                identifier: Self.alertPrefix + String(index),
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            )
            center.add(request)
            cursor = boundary + 0.001
        }
    }

    private func cancelAlerts() {
        let ids = (0..<scheduledBoundaries).map { Self.alertPrefix + String($0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Re-queue alerts after a settings change (sound, quiet mode).
    func alertSettingsChanged() {
        guard isRunning else { return }
        scheduleAlerts()
    }

    // MARK: - Persistence

    private func persist() {
        store.set(isRunning, forKey: "isRunning")
        store.set(anchor?.timeIntervalSince1970 ?? 0, forKey: "anchor")
        store.set(pausedElapsed, forKey: "pausedElapsed")
    }

    private func restore() {
        pausedElapsed = store.double(forKey: "pausedElapsed")
        let saved = store.double(forKey: "anchor")
        if store.bool(forKey: "isRunning"), saved > 0 {
            anchor = Date(timeIntervalSince1970: saved)
            isRunning = true
            elapsed = Date().timeIntervalSince(anchor!)
            lastSeenPhase = phase
            startTicker()
            applyIdleTimer()
        } else {
            elapsed = pausedElapsed
        }
    }
}

enum Haptics {
    @MainActor
    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    @MainActor
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
