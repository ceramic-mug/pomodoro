import SwiftUI

struct SettingsSheet: View {
    let timer: PomodoroTimer
    @State private var settings = Settings.shared
    @State private var tab: Tab = .timer
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable, Identifiable {
        case timer = "Timer"
        case appearance = "Appearance"

        var id: String { rawValue }
    }

    private var accent: Color { settings.config.color(for: .focus) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabSwitcher(tab: $tab, accent: accent)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 14) {
                        switch tab {
                        case .timer: timerTab
                        case .appearance: appearanceTab
                        }

                        Button {
                            settings.config = .standard
                            timer.timingsChanged()
                        } label: {
                            Text("Reset to defaults")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                }
            }
        }
        .tint(accent)
        .presentationDetents([.large])
    }

    // MARK: - Timer tab

    private var timerTab: some View {
        Group {
            Card {
                SectionLabel("Session lengths", systemImage: "timer")

                ForEach(Phase.allCases) { phase in
                    if phase != Phase.allCases.first { Divider().overlay(.white.opacity(0.08)) }

                    HStack {
                        Image(systemName: settings.config.symbol(for: phase))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(settings.config.color(for: phase))
                            .frame(width: 26)

                        Text(phase.title)

                        Spacer()

                        Stepper(
                            minutes: settings.config.timings.minutes(for: phase),
                            range: Timings.range(for: phase),
                            accent: settings.config.color(for: phase)
                        ) { minutes in
                            var config = settings.config
                            config.timings.setMinutes(minutes, for: phase)
                            settings.config = config
                            timer.timingsChanged()
                        }
                    }
                }
            }

            Card {
                SectionLabel("Alerts", systemImage: "bell.badge")

                Toggle(isOn: Binding(
                    get: { settings.quietMode },
                    set: { settings.quietMode = $0; timer.alertSettingsChanged() }
                )) {
                    Label("Alert through Focus", systemImage: "moon.fill")
                }

                Text("Phase alerts arrive even while Do Not Disturb is on.")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(.white.opacity(0.08))

                Toggle(isOn: Binding(
                    get: { settings.soundEnabled },
                    set: { settings.soundEnabled = $0; timer.alertSettingsChanged() }
                )) {
                    Label("Alert sound", systemImage: "bell.fill")
                }

                Divider().overlay(.white.opacity(0.08))

                Toggle(isOn: Binding(
                    get: { settings.keepAwake },
                    set: { settings.keepAwake = $0 }
                )) {
                    Label("Keep screen awake", systemImage: "sun.max.fill")
                }
            }
        }
    }

    // MARK: - Appearance tab

    private var appearanceTab: some View {
        ForEach(Phase.allCases) { phase in
            Card {
                HStack(spacing: 12) {
                    Image(systemName: settings.config.symbol(for: phase))
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(settings.config.color(for: phase))
                        .frame(width: 34, height: 34)
                        .background {
                            Circle().fill(settings.config.color(for: phase).opacity(0.14))
                        }

                    Text(phase.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    Spacer()
                }

                SwatchRow(selected: settings.config.palette.hex(for: phase)) { hex in
                    var config = settings.config
                    config.palette.set(hex, for: phase)
                    settings.config = config
                    timer.appearanceChanged()
                }

                GlyphRow(
                    options: Glyphs.options(for: phase),
                    selected: settings.config.symbol(for: phase),
                    accent: settings.config.color(for: phase)
                ) { symbol in
                    var config = settings.config
                    config.glyphs.set(symbol, for: phase)
                    settings.config = config
                    timer.appearanceChanged()
                }
            }
        }
    }

}

// MARK: - Tab switcher

private struct TabSwitcher: View {
    @Binding var tab: SettingsSheet.Tab
    let accent: Color
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsSheet.Tab.allCases) { candidate in
                let isOn = candidate == tab
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { tab = candidate }
                } label: {
                    Text(candidate.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isOn ? Color.black.opacity(0.85) : Color.white.opacity(0.55))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isOn {
                                Capsule(style: .continuous)
                                    .fill(accent)
                                    .matchedGeometryEffect(id: "tab", in: pill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            Capsule(style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        }
    }
}

// MARK: - Pieces

private struct SectionLabel: View {
    let text: String
    let systemImage: String

    init(_ text: String, systemImage: String) {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.white.opacity(0.4))
            .textCase(.uppercase)
    }
}

private struct Stepper: View {
    let minutes: Int
    let range: ClosedRange<Int>
    let accent: Color
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            button("minus", enabled: minutes > range.lowerBound) { onChange(minutes - 1) }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(minutes)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("min")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(minWidth: 52)
            .animation(.snappy(duration: 0.2), value: minutes)

            button("plus", enabled: minutes < range.upperBound) { onChange(minutes + 1) }
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? accent : .white.opacity(0.2))
                .frame(width: 30, height: 30)
                .background {
                    Circle().fill(.white.opacity(enabled ? 0.09 : 0.04))
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct SwatchRow: View {
    let selected: String
    let onPick: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Swatch.allCases) { swatch in
                let isOn = swatch.hex == selected
                Button { onPick(swatch.hex) } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 26, height: 26)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(isOn ? 0.9 : 0), lineWidth: 2)
                                .padding(-4)
                        }
                        .shadow(color: swatch.color.opacity(isOn ? 0.6 : 0), radius: 7)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}

private struct GlyphRow: View {
    let options: [String]
    let selected: String
    let accent: Color
    let onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { symbol in
                    let isOn = symbol == selected
                    Button { onPick(symbol) } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isOn ? accent : .white.opacity(0.45))
                            .frame(width: 40, height: 40)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isOn ? accent.opacity(0.16) : .white.opacity(0.05))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(accent.opacity(isOn ? 0.7 : 0), lineWidth: 1.5)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}
