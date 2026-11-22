import Foundation

/// "Open at login", done with a launch agent file in ~/Library/LaunchAgents.
///
/// The newer way (SMAppService) only works for apps signed with an Apple
/// developer certificate: for a locally built app, macOS refuses to start it.
/// A plain launch agent file works for both, so there is one mechanism.
enum LoginItem {
    static var file: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(bundleID).plist")
    }

    private static var executable: String { Bundle.main.executablePath ?? "" }

    /// The name of whatever starts the app at login instead of this file, or
    /// nil. A package manager that runs the app as its own service says so by
    /// setting KEEP_AWAKE_LOGIN_MANAGED_BY (Homebrew's `brew services` does).
    static var managedBy: String? {
        ProcessInfo.processInfo.environment["KEEP_AWAKE_LOGIN_MANAGED_BY"].flatMap { $0.isEmpty ? nil : $0 }
    }

    /// On when the file exists and points at this copy of the app.
    static var isOn: Bool { programInFile == executable }

    private static var programInFile: String? {
        guard let data = try? Data(contentsOf: file),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return (plist["ProgramArguments"] as? [String])?.first
    }

    /// Takes effect at the next login. The running app is left alone.
    static func set(on: Bool) throws {
        guard on else {
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            return
        }
        let plist: [String: Any] = [
            "Label": bundleID,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            // Restart after a crash, but not after Quit.
            "KeepAlive": ["SuccessfulExit": false],
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: file, options: .atomic)
    }

    /// Run once at launch. Turns "Open at login" on the first time the app
    /// runs, and repairs the file if the app has been moved since.
    static func prepareAtLaunch(defaults: UserDefaults = .standard) {
        guard managedBy == nil else { return }
        let firstRunKey = "DidSetUpLoginItem"
        let moved = programInFile != nil && programInFile != executable
        guard moved || !defaults.bool(forKey: firstRunKey) else { return }
        defaults.set(true, forKey: firstRunKey)
        try? set(on: true)
    }
}
