import SwiftUI

struct TimerScreen: View {
    let timer: PomodoroTimer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showingSettings = false

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        let position = timer.position

        ZStack {
            Backdrop(accent: position.phase.accent)

            if isLandscape {
                landscape(position)
            } else {
                portrait(position)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(timer: timer)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { timer.refresh() }
        }
    }

    // MARK: - Layouts

    private func portrait(_ position: PomodoroTimer.Position) -> some View {
        VStack(spacing: 0) {
            TopBar(cyclesDone: position.cyclesDone) { showingSettings = true }
                .padding(.top, 8)

            Spacer()

            dial(position, size: 274)

            CycleTrack(position: position)
                .padding(.top, 34)

            UpNext(next: position.next)
                .padding(.top, 18)

            Spacer()

            controls(position)
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }

    private func landscape(_ position: PomodoroTimer.Position) -> some View {
        HStack(spacing: 34) {
            dial(position, size: 206)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(position.cyclesDone > 0
                         ? "\(position.cyclesDone) cycle\(position.cyclesDone == 1 ? "" : "s") done"
                         : "Pomodoro")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    SettingsButton { showingSettings = true }
                }

                CycleTrack(position: position)
                UpNext(next: position.next)
                controls(position)
            }
            .frame(maxWidth: 360)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
    }

    // MARK: - Shared pieces

    private func dial(_ position: PomodoroTimer.Position, size: CGFloat) -> some View {
        Dial(
            progress: timer.progress,
            clock: timer.clock,
            phase: position.phase,
            isRunning: timer.isRunning,
            size: size
        )
        .onTapGesture { timer.toggle() }
    }

    private func controls(_ position: PomodoroTimer.Position) -> some View {
        Controls(
            isRunning: timer.isRunning,
            isFresh: timer.isFresh,
            accent: position.phase.accent,
            onToggle: { timer.toggle() },
            onSkip: { timer.skip() },
            onReset: { timer.reset() }
        )
    }
}

// MARK: - Backdrop

private struct Backdrop: View {
    let accent: Color

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)

            RadialGradient(
                colors: [accent.opacity(0.32), .clear],
                center: .init(x: 0.5, y: 0.34),
                startRadius: 0,
                endRadius: 480
            )

            RadialGradient(
                colors: [accent.opacity(0.12), .clear],
                center: .init(x: 0.1, y: 1.0),
                startRadius: 0,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: accent)
    }
}

// MARK: - Top bar

private struct TopBar: View {
    let cyclesDone: Int
    let onSettings: () -> Void

    var body: some View {
        HStack {
            Text(cyclesDone > 0 ? "\(cyclesDone) cycle\(cyclesDone == 1 ? "" : "s") done" : "Pomodoro")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            SettingsButton(action: onSettings)
        }
    }
}

private struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 38, height: 38)
                .background {
                    Circle().fill(.white.opacity(0.07))
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dial

private struct Dial: View {
    let progress: Double
    let clock: String
    let phase: Phase
    let isRunning: Bool
    let size: CGFloat

    private var accent: Color { phase.accent }
    private var lineWidth: CGFloat { size * 0.051 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.07), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [accent.opacity(0.55), accent],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(0.5), radius: 14)
                .opacity(progress > 0.001 ? 1 : 0)
                .animation(.linear(duration: 0.12), value: progress)

            VStack(spacing: size * 0.03) {
                Image(systemName: phase.symbol)
                    .font(.system(size: size * 0.135, weight: .medium))
                    .foregroundStyle(accent)
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: accent.opacity(0.55), radius: size * 0.05)
                    .id(phase)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .padding(.bottom, size * 0.012)

                Text(clock)
                    .font(.system(size: size * 0.245, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))

                Text(phase.title.uppercased())
                    .font(.system(size: max(size * 0.042, 10), weight: .semibold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(accent.opacity(0.75))
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: phase)
        }
        .frame(width: size, height: size)
        .scaleEffect(isRunning ? 1 : 0.98)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isRunning)
        .contentShape(Circle())
    }
}

// MARK: - Cycle track

/// The seven segments of one cycle, widths proportional to their durations.
private struct CycleTrack: View {
    let position: PomodoroTimer.Position

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            let gaps = spacing * CGFloat(PomodoroTimer.pattern.count - 1)
            let unit = (geo.size.width - gaps) / PomodoroTimer.cycleLength

            HStack(spacing: spacing) {
                ForEach(Array(PomodoroTimer.pattern.enumerated()), id: \.offset) { index, phase in
                    Capsule()
                        .fill(fill(index: index, phase: phase))
                        .frame(width: max(phase.duration * unit, 6), height: index == position.indexInPattern ? 6 : 4)
                }
            }
            .frame(height: 8, alignment: .center)
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.4), value: position.indexInPattern)
    }

    private func fill(index: Int, phase: Phase) -> Color {
        if index < position.indexInPattern { return position.phase.accent.opacity(0.35) }
        if index == position.indexInPattern { return phase.accent }
        return .white.opacity(0.13)
    }
}

// MARK: - Up next

private struct UpNext: View {
    let next: Phase

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: next.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text("Next · \(next.title) · \(next.lengthLabel)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.4))
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.35), value: next)
    }
}

// MARK: - Controls

private struct Controls: View {
    let isRunning: Bool
    let isFresh: Bool
    let accent: Color
    let onToggle: () -> Void
    let onSkip: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onReset) {
                Icon(name: "stop.fill")
            }
            .buttonStyle(.plain)
            .opacity(isFresh ? 0.35 : 1)
            .disabled(isFresh)

            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                    Text(isRunning ? "Pause" : (isFresh ? "Start" : "Resume"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Capsule(style: .continuous).fill(accent))
                .shadow(color: accent.opacity(0.35), radius: 18, y: 8)
            }
            .buttonStyle(.plain)

            Button(action: onSkip) {
                Icon(name: "forward.end.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private struct Icon: View {
        let name: String

        var body: some View {
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 54, height: 54)
                .background {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
                }
        }
    }
}
