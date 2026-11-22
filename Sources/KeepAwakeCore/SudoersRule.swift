/// The one line Keep Awake adds to the system's `sudo` rules when "Survive
/// unplugging" is turned on. It lets one user run two exact commands as an
/// administrator without typing a password: turn "block all sleep" on, and off.
public enum SudoersRule {
    public static let path = "/etc/sudoers.d/keep-awake"
    public static let blockAllSleep = ["/usr/bin/pmset", "-a", "disablesleep", "1"]
    public static let allowSleep = ["/usr/bin/pmset", "-a", "disablesleep", "0"]

    /// The rule for one user, or nil if the user name contains anything other
    /// than letters, digits, dots, underscores and hyphens. The name goes into
    /// a file that controls administrator rights, so nothing else is accepted.
    public static func line(user: String) -> String? {
        let safe = user.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) || "._-".unicodeScalars.contains(scalar))
        }
        guard safe, !user.isEmpty, !user.hasPrefix("-") else { return nil }
        let commands = [allowSleep, blockAllSleep].map { $0.joined(separator: " ") }
        return "\(user) ALL=(root) NOPASSWD: " + commands.joined(separator: ", ")
    }
}
