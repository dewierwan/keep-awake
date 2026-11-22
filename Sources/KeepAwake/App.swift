import AppKit
import Combine
import KeepAwakeCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let session = Session()
    private let hotkey = Hotkey()
    private let panel = PanelModel()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var subscriptions: Set<AnyCancellable> = []
    private var termination: DispatchSourceSignal?
    private var shownActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // A fixed name lets macOS (and menu bar managers) remember where the icon sits.
        statusItem.autosaveName = "KeepAwake"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.imagePosition = .imageLeading

        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self

        // Redraw the menu bar text whenever the session or the clock changes.
        session.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refreshStatusItem() }
            .store(in: &subscriptions)

        hotkey.onPress = { [weak self] in
            self?.session.start(minutes: Settings.defaultMinutes)
        }
        panel.applyHotkey = { [weak self] spec in self?.hotkey.set(spec) ?? false }
        panel.surviveUnpluggingChanged = { [weak self] isOn in self?.session.surviveUnpluggingChanged(isOn: isOn) }
        if let spec = Settings.hotkey, !hotkey.set(spec) {
            log.error("macOS would not accept the shortcut \(spec.display, privacy: .public)")
        }

        // `KeepAwake --start 20` and `KeepAwake --stop` in a terminal reach the
        // running app through this notification.
        DistributedNotificationCenter.default().addObserver(
            forName: Command.notification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let command = Command(text: note.object as? String ?? "") else { return }
            switch command {
            case .start(let minutes): self.session.start(minutes: minutes)
            case .stop: self.session.stop()
            }
        }

        // launchd stops the app with SIGTERM, which skips applicationWillTerminate.
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak self] in
            self?.session.stop()
            exit(0)
        }
        source.resume()
        termination = source

        LoginItem.prepareAtLaunch()
        session.resumeAfterLaunch()
        refreshStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        let active = session.isActive
        if button.image == nil || active != shownActive {
            let image = NSImage(
                systemSymbolName: active ? "eye.fill" : "eye",
                accessibilityDescription: active ? "Keep Awake, session running" : "Keep Awake"
            )
            image?.isTemplate = true
            button.image = image
            shownActive = active
        }
        let title = active ? " " + TimeText.menuBar(secondsLeft: session.secondsLeft) : ""
        if button.title != title {
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.title = title
        }
    }

    @objc private func togglePanel() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        panel.refresh()
        let controller = NSHostingController(
            rootView: PanelView(session: session, model: panel, quit: { NSApp.terminate(nil) })
        )
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
        // A menu bar app is never frontmost, and a popover only closes on an
        // outside click when its app is.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        panel.stopRecording()
        popover.contentViewController = nil
    }
}

let bundleID = "com.dewierwan.keep-awake"

/// What a terminal can ask the running app to do.
enum Command {
    case start(minutes: Int)
    case stop

    static let notification = Notification.Name("\(bundleID).command")

    /// From command-line arguments: `--start 20` or `--stop`.
    init?(arguments: [String]) {
        switch arguments.first {
        case "--stop": self = .stop
        case "--start":
            guard arguments.count > 1, let minutes = Int(arguments[1]), minutes > 0 else { return nil }
            self = .start(minutes: minutes)
        default: return nil
        }
    }

    /// From the text carried by the notification: "start 20" or "stop".
    init?(text: String) {
        self.init(arguments: text.split(separator: " ").enumerated().map { $0.offset == 0 ? "--\($0.element)" : String($0.element) })
    }

    var text: String {
        switch self {
        case .start(let minutes): return "start \(minutes)"
        case .stop: return "stop"
        }
    }
}

@main
enum Main {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments.dropFirst()
        if arguments.first == "--status" {
            printStatus()
            return
        }
        if let command = Command(arguments: Array(arguments)) {
            guard isAlreadyRunning else {
                print("Keep Awake is not running. Open it first.")
                exit(1)
            }
            DistributedNotificationCenter.default().postNotificationName(
                Command.notification, object: command.text, userInfo: nil, deliverImmediately: true
            )
            return
        }
        if arguments.first == "--login" {
            switch arguments.dropFirst().first {
            case "on", "off":
                do {
                    try LoginItem.set(on: arguments.dropFirst().first == "on")
                } catch {
                    print("Could not change it: \(error.localizedDescription)")
                }
            default: break
            }
            print("Open at login: \(LoginItem.isOn ? "on" : "off")")
            return
        }
        if arguments.first == "--snapshots", let directory = arguments.dropFirst().first {
            writeSnapshots(to: directory)
            return
        }

        if isAlreadyRunning { return }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    static var isAlreadyRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }.isEmpty
    }

    /// Prints what the app sees. For checking a setup from the terminal.
    static func printStatus() {
        func text(_ value: Bool?) -> String { value.map { $0 ? "yes" : "no" } ?? "unknown" }
        // Run from inside the app, the standard defaults already are the app's.
        let defaults = Bundle.main.bundleIdentifier == bundleID
            ? UserDefaults.standard : (UserDefaults(suiteName: bundleID) ?? .standard)
        let end = defaults.double(forKey: "SessionEndDate")
        print("At a desk:                  \(text(Machine.atDesk)) (mains power: \(text(Machine.onMainsPower)))")
        print("Displays:                   \(Machine.displaySummary)")
        print("Lid closed:                 \(text(Machine.lidClosed))")
        print("On battery at:              \(Machine.batteryPercentWhileOnBattery.map { "\($0)%" } ?? "not on battery")")
        print("Session running:            \(text(end > Date().timeIntervalSince1970))")
        print("Lid switch turned on by us: \(text(defaults.bool(forKey: "LidSwitchIsOurs")))")
        print("Survive unplugging:         \(AllSleepBlock.isInstalled ? "on" : "off")")
        print("All sleep blocked now:      \(text(AllSleepBlock.isOn)) (by us: \(text(defaults.bool(forKey: "AllSleepBlockIsOurs"))))")
    }
}
