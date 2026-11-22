import AppKit
import Combine
import Foundation
import IOKit.ps
import KeepAwakeCore

/// Settings, saved in the app's defaults. The panel changes them, and so can
/// `defaults write com.dewierwan.keep-awake`.
enum Settings {
    static let defaults = UserDefaults.standard
    static let presetMinutes = [5, 10, 20, 30, 60, 120]

    /// Length of the session the keyboard shortcut starts.
    static var defaultMinutes: Int {
        get {
            let value = defaults.integer(forKey: "DefaultMinutes")
            return value > 0 ? value : 20
        }
        set { defaults.set(newValue, forKey: "DefaultMinutes") }
    }

    /// Global shortcut that starts a session, saved as text such as
    /// "ctrl+opt+cmd+k". Saved as "none" when there is no shortcut.
    static var hotkey: HotkeySpec? {
        get { HotkeySpec(defaults.string(forKey: "Hotkey") ?? "ctrl+opt+cmd+k") }
        set { defaults.set(newValue?.text ?? "none", forKey: "Hotkey") }
    }

    /// On battery, a session stops when the charge falls to this level.
    static var stopAtBatteryPercent: Int {
        defaults.object(forKey: "StopAtBatteryPercent") == nil ? 10 : defaults.integer(forKey: "StopAtBatteryPercent")
    }
}

/// The one session the app can run: when it ends, and what it holds while it runs.
final class Session: ObservableObject {
    /// When the running session ends; nil when nothing is running.
    @Published private(set) var endDate: Date?
    /// The current time, republished every second while a session runs.
    @Published private(set) var now = Date()
    /// A short message for the panel, such as why the last session stopped.
    @Published private(set) var notice: String?

    private let blocker = SleepBlocker()
    private var timer: Timer?
    private var ticks = 0
    private var lastLoggedAction: LidAction?
    private var lastLoggedAtDesk: Bool?
    private var powerSource: CFRunLoopSource?
    private let defaults = UserDefaults.standard

    private enum Key {
        static let endDate = "SessionEndDate"
        static let lidSwitchIsOurs = "LidSwitchIsOurs"
    }

    var isActive: Bool { endDate != nil }
    var secondsLeft: TimeInterval { max(0, (endDate ?? now).timeIntervalSince(now)) }

    /// True while this app has turned the lid switch on and not yet off.
    /// Saved to disk so a crash cannot leave the switch on with nobody to turn it off.
    private var lidSwitchIsOurs: Bool {
        get { defaults.bool(forKey: Key.lidSwitchIsOurs) }
        set { defaults.set(newValue, forKey: Key.lidSwitchIsOurs) }
    }

    init() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(displaysChanged),
                           name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

        // Plugging in or unplugging power changes whether the Mac is at a desk.
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<Session>.fromOpaque(context).takeUnretainedValue().applyLidPolicySoon()
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
    }

    /// Picks up a session that was running when the app last exited without
    /// stopping it (a crash), and settles the lid switch either way.
    func resumeAfterLaunch() {
        let saved = defaults.double(forKey: Key.endDate)
        if saved > Date().timeIntervalSince1970 {
            begin(until: Date(timeIntervalSince1970: saved))
        } else {
            defaults.removeObject(forKey: Key.endDate)
            applyLidPolicy()
        }
    }

    func start(minutes: Int) {
        if let percent = Machine.batteryPercentWhileOnBattery, percent <= Settings.stopAtBatteryPercent {
            notice = "Battery is at \(percent)%. Plug in to start a session."
            return
        }
        begin(until: Date().addingTimeInterval(TimeInterval(minutes * 60)))
    }

    func extend(minutes: Int) {
        guard let endDate else { return }
        begin(until: endDate.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    func stop(notice: String? = nil) {
        guard isActive else { return }
        endDate = nil
        defaults.removeObject(forKey: Key.endDate)
        timer?.invalidate()
        timer = nil
        blocker.release()
        self.notice = notice
        applyLidPolicy()
    }

    /// Shows a running session in a picture of the panel. Holds nothing and
    /// saves nothing, so it has no effect on the Mac.
    func setPreview(end: Date) {
        endDate = end
        now = Date()
    }

    private func begin(until end: Date) {
        endDate = end
        now = Date()
        notice = nil
        defaults.set(end.timeIntervalSince1970, forKey: Key.endDate)
        blocker.hold()
        applyLidPolicy()
        if timer == nil {
            ticks = 0
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    private func tick() {
        now = Date()
        guard let endDate else { return }
        if now >= endDate {
            stop()
            return
        }
        ticks += 1
        guard ticks % 30 == 0 else { return }
        // macOS turns the lid switch off by itself when a display or power
        // source changes, so keep turning it back on while a session runs.
        applyLidPolicy()
        if let percent = Machine.batteryPercentWhileOnBattery, percent <= Settings.stopAtBatteryPercent {
            stop(notice: "Stopped because the battery reached \(percent)%.")
        }
    }

    /// Sets the lid switch to what `lidAction` says. Safe to call at any time.
    private func applyLidPolicy() {
        let atDesk = Machine.atDesk
        let action = lidAction(sessionActive: isActive, atDesk: atDesk, weTurnedItOn: lidSwitchIsOurs)
        if action != lastLoggedAction || atDesk != lastLoggedAtDesk {
            // The facts behind the decision, so a wrong one can be traced later.
            log.notice("""
                Lid policy: \(String(describing: action), privacy: .public), session=\(self.isActive), \
                atDesk=\(atDesk), mains=\(Machine.onMainsPower), displays=[\(Machine.displaySummary, privacy: .public)]
                """)
            lastLoggedAction = action
            lastLoggedAtDesk = atDesk
        }
        switch action {
        case .hold:
            // Record first: if we crash right after the call, the next launch must still know.
            lidSwitchIsOurs = true
            LidSwitch.set(on: true)
        case .release:
            if LidSwitch.set(on: false) { lidSwitchIsOurs = false }
        case .leaveAlone:
            break
        }
    }

    /// Called when displays or power change, and after waking.
    /// Applies the lid policy now and again shortly after, because macOS makes
    /// its own change to the switch a moment after these events.
    func applyLidPolicySoon() {
        if isActive {
            applyLidPolicy()
            for delay in [2.0, 10.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    if self?.isActive == true { self?.applyLidPolicy() }
                }
            }
        } else {
            // A display can drop out for a moment (waking, changing mode). Wait
            // before deciding the Mac has really left the desk.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if self?.isActive == false { self?.applyLidPolicy() }
            }
        }
    }

    @objc private func displaysChanged() { applyLidPolicySoon() }

    @objc private func didWake() {
        tick()
        applyLidPolicySoon()
    }
}
