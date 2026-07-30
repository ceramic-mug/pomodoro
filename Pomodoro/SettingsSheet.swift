import SwiftUI
import UIKit

struct SettingsSheet: View {
    let timer: PomodoroTimer
    @State private var settings = Settings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Card {
                        Toggle(isOn: Binding(
                            get: { settings.quietMode },
                            set: { settings.quietMode = $0; timer.alertSettingsChanged() }
                        )) {
                            Label {
                                Text("Quiet while running")
                            } icon: {
                                Image(systemName: "moon.fill")
                            }
                        }

                        Divider().overlay(.white.opacity(0.08))

                        Text("iOS lets no app switch Do Not Disturb on its own. With this on, Pomodoro's own alerts are marked time-sensitive so they still land during a Focus. To silence everything else, add a Shortcuts automation — Pomodoro exposes Start, Pause and Stop actions for it.")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            openShortcuts()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Open Shortcuts")
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Phase.focus.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    Card {
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

                    Card {
                        Label("The cycle", systemImage: "repeat")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("25 focus · 5 break, four times over, with the last break stretched to 15 minutes — then it starts again. It keeps going until you stop it, and stays on time while the app is closed.")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Phase.focus.accent)
                }
            }
        }
        .tint(Phase.focus.accent)
        .presentationDetents([.medium, .large])
    }

    private func openShortcuts() {
        if let url = URL(string: "shortcuts://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
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
