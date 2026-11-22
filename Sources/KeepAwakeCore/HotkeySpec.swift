/// A global keyboard shortcut written as text, such as "ctrl+opt+cmd+k".
public struct HotkeySpec: Equatable {
    /// macOS virtual key code (ANSI layout).
    public let keyCode: UInt32
    /// Carbon modifier flags, as RegisterEventHotKey expects them.
    public let carbonModifiers: UInt32
    /// How to show it to a person: "⌃⌥⌘K".
    public let display: String
    /// How to save it: "ctrl+opt+cmd+k". Parsing this text gives the same shortcut back.
    public let text: String

    // Carbon modifier bits (cmdKey, shiftKey, optionKey, controlKey).
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12

    static let keyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32,
        "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    ]

    /// Parses text like "cmd+j" or "ctrl+opt+cmd+k": Control, Option or Command,
    /// optionally Shift, and exactly one letter or digit. Returns nil for
    /// anything else, including "none", which means "no shortcut".
    public init?(_ text: String) {
        var modifiers: UInt32 = 0
        var key: String?
        for part in text.lowercased().split(separator: "+").map(String.init) {
            switch part.trimmingCharacters(in: .whitespaces) {
            case "cmd", "command": modifiers |= Self.command
            case "shift": modifiers |= Self.shift
            case "opt", "option", "alt": modifiers |= Self.option
            case "ctrl", "control": modifiers |= Self.control
            case let other:
                guard key == nil, Self.keyCodes[other] != nil else { return nil }
                key = other
            }
        }
        guard let key, let code = Self.keyCodes[key] else { return nil }
        self.init(keyCode: code, carbonModifiers: modifiers)
    }

    /// From a key press. Needs Control, Option or Command: Shift alone would
    /// take over ordinary typing. Returns nil for keys other than letters and digits.
    public init?(keyCode: UInt32, carbonModifiers modifiers: UInt32) {
        let allowed = Self.control | Self.option | Self.shift | Self.command
        guard modifiers & ~allowed == 0,
              modifiers & (Self.control | Self.option | Self.command) != 0,
              let key = Self.keyCodes.first(where: { $0.value == keyCode })?.key
        else { return nil }
        self.keyCode = keyCode
        carbonModifiers = modifiers
        var shown = ""
        var saved: [String] = []
        if modifiers & Self.control != 0 { shown += "⌃"; saved.append("ctrl") }
        if modifiers & Self.option != 0 { shown += "⌥"; saved.append("opt") }
        if modifiers & Self.shift != 0 { shown += "⇧"; saved.append("shift") }
        if modifiers & Self.command != 0 { shown += "⌘"; saved.append("cmd") }
        display = shown + key.uppercased()
        text = (saved + [key]).joined(separator: "+")
    }
}
