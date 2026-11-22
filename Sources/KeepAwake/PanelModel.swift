import AppKit
import Carbon.HIToolbox
import KeepAwakeCore

/// What the panel shows besides the session: whether settings are open, the
/// settings themselves, and the shortcut recorder.
final class PanelModel: ObservableObject {
    @Published var showingSettings = false
    @Published private(set) var recordingShortcut = false
    @Published private(set) var hotkey: HotkeySpec? = Settings.hotkey
    @Published private(set) var defaultMinutes = Settings.defaultMinutes
    @Published private(set) var openAtLogin = LoginItem.isOn
    @Published private(set) var surviveUnplugging = Settings.surviveUnplugging
    /// A short message under the settings, such as why a shortcut was refused.
    @Published private(set) var settingsNotice: String?

    /// Registers a shortcut with macOS; returns false if macOS refuses it.
    var applyHotkey: (HotkeySpec?) -> Bool = { _ in true }
    /// Tells the session that "Survive unplugging" changed.
    var surviveUnpluggingChanged: (Bool) -> Void = { _ in }
    private var keyMonitor: Any?

    var hotkeyHint: String? {
        hotkey.map { "\($0.display) starts \(TimeText.length(minutes: defaultMinutes))" }
    }

    var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            .map { "Version \($0)" } ?? "Development build"
    }

    /// Called each time the panel opens, so it shows what is true now.
    func refresh() {
        showingSettings = false
        settingsNotice = nil
        hotkey = Settings.hotkey
        defaultMinutes = Settings.defaultMinutes
        openAtLogin = LoginItem.isOn
        surviveUnplugging = Settings.surviveUnplugging
    }

    /// Turns "Survive unplugging" on or off. Either way macOS asks for the
    /// administrator password, because the change is to the system's sudo rules.
    func toggleSurviveUnplugging() {
        do {
            if surviveUnplugging {
                try AllSleepBlock.remove()
            } else {
                try AllSleepBlock.install()
            }
            settingsNotice = nil
        } catch AllSleepBlock.SetupError.cancelled {
            settingsNotice = nil
        } catch {
            settingsNotice = "Could not change Survive unplugging."
            log.error("Survive unplugging: \(String(describing: error), privacy: .public)")
        }
        surviveUnplugging = Settings.surviveUnplugging
        surviveUnpluggingChanged(surviveUnplugging)
    }

    /// Steps the shortcut's session length to the next preset.
    func cycleDefaultMinutes() {
        let presets = Settings.presetMinutes
        let next = presets.first { $0 > defaultMinutes } ?? presets[0]
        Settings.defaultMinutes = next
        defaultMinutes = next
    }

    /// What the "Open at login" button says.
    var openAtLoginLabel: String { LoginItem.managedBy ?? (openAtLogin ? "On" : "Off") }

    func toggleOpenAtLogin() {
        if let manager = LoginItem.managedBy {
            settingsNotice = "\(manager) starts Keep Awake at login. Change it there."
            return
        }
        do {
            try LoginItem.set(on: !openAtLogin)
            settingsNotice = nil
        } catch {
            settingsNotice = "Could not change Open at login."
        }
        openAtLogin = LoginItem.isOn
    }

    // MARK: Recording a shortcut

    /// Starts or cancels listening for the next key press in the panel.
    func toggleRecording() {
        recordingShortcut ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recordingShortcut = true
        settingsNotice = "Press the new shortcut. Delete removes it, Esc cancels."
        // Let go of the current shortcut, or pressing it would start a session
        // instead of being recorded.
        _ = applyHotkey(nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil // the panel swallows the key press
        }
    }

    /// Cancels recording and puts the saved shortcut back in force.
    func stopRecording() {
        guard recordingShortcut else { return }
        endRecording()
        settingsNotice = nil
        _ = applyHotkey(hotkey)
    }

    private func endRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        recordingShortcut = false
    }

    private func record(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            save(nil)
            return
        }
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.control) { modifiers |= HotkeySpec.control }
        if event.modifierFlags.contains(.option) { modifiers |= HotkeySpec.option }
        if event.modifierFlags.contains(.shift) { modifiers |= HotkeySpec.shift }
        if event.modifierFlags.contains(.command) { modifiers |= HotkeySpec.command }
        guard let spec = HotkeySpec(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers) else {
            settingsNotice = "Use Control, Option or Command with a letter or a digit."
            return
        }
        save(spec)
    }

    private func save(_ spec: HotkeySpec?) {
        endRecording()
        if applyHotkey(spec) {
            hotkey = spec
            Settings.hotkey = spec
            settingsNotice = nil
        } else {
            _ = applyHotkey(hotkey)
            settingsNotice = "macOS would not accept that shortcut."
        }
    }
}
