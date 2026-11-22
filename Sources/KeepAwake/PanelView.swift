import KeepAwakeCore
import SwiftUI

/// The panel that opens from the menu bar icon.
struct PanelView: View {
    @ObservedObject var session: Session
    @ObservedObject var model: PanelModel
    @Environment(\.colorScheme) private var scheme
    let quit: () -> Void

    private var theme: Theme { Theme.current(scheme) }

    private static let endTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if session.isActive { countdownCard.padding(.top, 14) }
            lengths.padding(.top, 20)
            if model.showingSettings { settings.padding(.top, 20) }
            footer.padding(.top, 20)
        }
        .padding(14)
        .frame(width: 284, alignment: .leading)
        .background(theme.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Keep Awake")
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.2)
                .foregroundColor(theme.ink)
            Text(statusLine)
                .font(.system(size: 12))
                .foregroundColor(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusLine: String {
        if let end = session.endDate {
            return "Awake until \(Self.endTime.string(from: end)), lid open or closed."
        }
        return session.notice ?? "Not running. Your Mac sleeps as normal."
    }

    private var countdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TimeText.countdown(secondsLeft: session.secondsLeft))
                .font(.system(size: 34, weight: .medium, design: .monospaced))
                .foregroundColor(theme.ink)
            HStack(spacing: 8) {
                Button("+10 min") { session.extend(minutes: 10) }
                    .buttonStyle(PanelButtonStyle(kind: .quiet))
                Button("+30 min") { session.extend(minutes: 30) }
                    .buttonStyle(PanelButtonStyle(kind: .quiet))
                Button("Stop") { session.stop() }
                    .buttonStyle(PanelButtonStyle(kind: .primary))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card)
    }

    /// The white card that the countdown and the settings sit on.
    private var card: some View {
        RoundedRectangle(cornerRadius: Theme.radiusLarge)
            .fill(theme.card)
            .shadow(color: theme.shadow, radius: 6, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .strokeBorder(theme.rule, lineWidth: 1)
            )
    }

    private var lengths: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: session.isActive ? "Start over" : "Stay awake for")
            VStack(spacing: 8) {
                ForEach(lengthRows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { minutes in
                            Button(TimeText.length(minutes: minutes)) { session.start(minutes: minutes) }
                                .buttonStyle(PanelButtonStyle(kind: highlight(minutes) ? .primary : .quiet))
                        }
                    }
                }
            }
        }
    }

    /// The preset lengths, three to a row.
    private var lengthRows: [[Int]] {
        let all = Settings.presetMinutes
        return stride(from: 0, to: all.count, by: 3).map { Array(all[$0..<min($0 + 3, all.count)]) }
    }

    /// The length the shortcut starts gets the solid button, but only while
    /// nothing is running: during a session the solid button is Stop.
    private func highlight(_ minutes: Int) -> Bool {
        !session.isActive && minutes == model.defaultMinutes
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Settings")
            VStack(spacing: 10) {
                settingRow("Shortcut") {
                    Button(model.recordingShortcut ? "Press keys" : (model.hotkey?.display ?? "None")) {
                        model.toggleRecording()
                    }
                    .buttonStyle(PanelButtonStyle(kind: model.recordingShortcut ? .primary : .quiet))
                }
                settingRow("Shortcut starts") {
                    Button(TimeText.length(minutes: model.defaultMinutes)) { model.cycleDefaultMinutes() }
                        .buttonStyle(PanelButtonStyle(kind: .quiet))
                }
                settingRow("Open at login") {
                    Button(model.openAtLoginLabel) { model.toggleOpenAtLogin() }
                        .buttonStyle(PanelButtonStyle(kind: .quiet))
                }
                settingRow("Survive unplugging") {
                    Button(model.surviveUnplugging ? "On" : "Off") { model.toggleSurviveUnplugging() }
                        .buttonStyle(PanelButtonStyle(kind: .quiet))
                }
            }
            .padding(14)
            .background(card)
            Text(model.settingsNotice ?? model.version)
                .font(.system(size: 11))
                .foregroundColor(theme.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One setting: its name on the left, a button showing its value on the right.
    private func settingRow<Control: View>(_ name: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(theme.ink)
            Spacer()
            control().frame(width: 96)
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            if let hint = model.hotkeyHint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkSubtle)
            }
            Spacer()
            footerButton(model.showingSettings ? "Done" : "Settings") {
                model.stopRecording()
                model.showingSettings.toggle()
            }
            footerButton("Quit", action: quit)
        }
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(theme.inkSubtle)
    }
}
