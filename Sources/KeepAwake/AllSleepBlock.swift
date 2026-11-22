import Foundation
import KeepAwakeCore

/// "Survive unplugging": a stronger, administrator-level switch that blocks all
/// sleep (`pmset disablesleep`) while a session runs.
///
/// The lid switch alone is not enough when a display or charger is unplugged
/// with the lid closed: macOS turns the lid switch off itself at that moment
/// and the Mac sleeps before any app can react. Blocking all sleep stops that.
/// It needs administrator rights, so it is off until the user turns it on and
/// types their password once (see `SudoersRule`).
enum AllSleepBlock {
    /// True when Keep Awake's rule file is in place. (Asking `sudo -l` instead
    /// does not work: it says yes for any administrator, password or not.)
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: SudoersRule.path)
    }

    /// True when all sleep is blocked system-wide right now, by anyone.
    static var isOn: Bool {
        let settings = run("/usr/bin/pmset", ["-g"]).output
        return settings.split(separator: "\n").contains { line in
            let words = line.split(whereSeparator: \.isWhitespace)
            return words.first == "SleepDisabled" && words.last == "1"
        }
    }

    /// Returns false when the command was refused, for example because
    /// "Survive unplugging" was never turned on.
    @discardableResult
    static func set(on: Bool) -> Bool {
        let command = on ? SudoersRule.blockAllSleep : SudoersRule.allowSleep
        let ok = run("/usr/bin/sudo", ["-n"] + command).status == 0
        if ok {
            log.notice("All sleep \(on ? "blocked" : "allowed again", privacy: .public)")
        } else {
            log.error("Could not \(on ? "block" : "allow", privacy: .public) all sleep")
        }
        return ok
    }

    enum SetupError: Error { case unsafeUserName, cancelled, failed(String) }

    /// Asks for the administrator password and adds the rule.
    static func install() throws {
        guard let line = SudoersRule.line(user: NSUserName()) else { throw SetupError.unsafeUserName }
        // Check the rule with visudo before putting it in place: a broken file
        // in that folder would stop `sudo` working.
        let script = """
            f=$(/usr/bin/mktemp) && /usr/bin/printf '%s\\n' '\(line)' > "$f" \
            && /usr/sbin/visudo -cf "$f" >/dev/null \
            && /usr/bin/install -o root -g wheel -m 0440 "$f" \(SudoersRule.path); \
            s=$?; /bin/rm -f "$f"; exit $s
            """
        try runAsAdministrator(
            script,
            prompt: "Keep Awake needs your password once, so a session can keep your Mac awake when you unplug it."
        )
    }

    /// Asks for the administrator password, allows sleep again and removes the rule.
    static func remove() throws {
        let script = "\(SudoersRule.allowSleep.joined(separator: " ")); /bin/rm -f \(SudoersRule.path)"
        try runAsAdministrator(script, prompt: "Keep Awake needs your password to turn off Survive unplugging.")
    }

    private static func runAsAdministrator(_ shell: String, prompt: String) throws {
        func quoted(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let source = "do shell script \(quoted(shell)) with prompt \(quoted(prompt)) with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard let error else { return }
        if (error[NSAppleScript.errorNumber] as? Int) == -128 { throw SetupError.cancelled }
        throw SetupError.failed(error[NSAppleScript.errorMessage] as? String ?? "unknown error")
    }

    private static func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return (-1, "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
