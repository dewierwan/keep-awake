// The unit tests, as a plain program: `swift run Checks`.
//
// They are not written with XCTest or Swift Testing because neither works
// reliably with the Xcode Command Line Tools alone, and this project is meant
// to build and test without full Xcode.

import Foundation
import KeepAwakeCore

var failures = 0

func expect(_ condition: Bool, _ what: String, line: UInt = #line) {
    if condition { return }
    failures += 1
    print("FAIL (line \(line)): \(what)")
}

// MARK: The lid rule

for docked in [true, false] {
    for ours in [true, false] {
        expect(
            lidAction(sessionActive: true, externalDisplayConnected: docked, weTurnedItOn: ours) == .hold,
            "a running session always holds the switch"
        )
    }
    expect(
        lidAction(sessionActive: false, externalDisplayConnected: docked, weTurnedItOn: false) == .leaveAlone,
        "we never turn off a switch we did not turn on"
    )
}

// The bug this app exists to fix: turning the switch off at a desk puts the
// Mac to sleep mid-work, because macOS was relying on it too.
expect(
    lidAction(sessionActive: false, externalDisplayConnected: true, weTurnedItOn: true) == .leaveAlone,
    "ending a session at a desk leaves the switch for macOS"
)
expect(
    lidAction(sessionActive: false, externalDisplayConnected: false, weTurnedItOn: true) == .release,
    "ending a session away from a desk turns the switch off"
)

// MARK: Time text

expect(TimeText.menuBar(secondsLeft: 0) == "0s", "menu bar: zero")
expect(TimeText.menuBar(secondsLeft: 44.2) == "45s", "menu bar: rounds seconds up")
expect(TimeText.menuBar(secondsLeft: 60) == "1m", "menu bar: one minute")
expect(TimeText.menuBar(secondsLeft: 61) == "2m", "menu bar: rounds minutes up")
expect(TimeText.menuBar(secondsLeft: 20 * 60) == "20m", "menu bar: twenty minutes")
expect(TimeText.menuBar(secondsLeft: 60 * 60) == "1h", "menu bar: one hour")
expect(TimeText.menuBar(secondsLeft: 109 * 60) == "1h 49m", "menu bar: hours and minutes")
expect(TimeText.menuBar(secondsLeft: -5) == "0s", "menu bar: never negative")

expect(TimeText.countdown(secondsLeft: 19 * 60 + 42) == "19:42", "countdown: minutes and seconds")
expect(TimeText.countdown(secondsLeft: 5) == "0:05", "countdown: pads seconds")
expect(TimeText.countdown(secondsLeft: 3600 + 49 * 60 + 5) == "1:49:05", "countdown: hours")
expect(TimeText.countdown(secondsLeft: -1) == "0:00", "countdown: never negative")

expect(TimeText.length(minutes: 5) == "5 min", "length: minutes")
expect(TimeText.length(minutes: 60) == "1 hr", "length: one hour")
expect(TimeText.length(minutes: 120) == "2 hr", "length: two hours")
expect(TimeText.length(minutes: 90) == "90 min", "length: ninety minutes stays in minutes")

// MARK: Keyboard shortcut text

if let spec = HotkeySpec("ctrl+opt+cmd+k") {
    expect(spec.keyCode == 40, "shortcut: K is key 40")
    expect(spec.carbonModifiers == (1 << 12) | (1 << 11) | (1 << 8), "shortcut: control, option and command")
    expect(spec.display == "⌃⌥⌘K", "shortcut: shown in the usual symbol order")
} else {
    expect(false, "shortcut: ctrl+opt+cmd+k parses")
}

if let spec = HotkeySpec("Command + Shift + J") {
    expect(spec.keyCode == 38, "shortcut: J is key 38")
    expect(spec.display == "⇧⌘J", "shortcut: long names, capitals and spaces are accepted")
} else {
    expect(false, "shortcut: Command + Shift + J parses")
}

for bad in ["none", "", "k", "cmd", "cmd+j+k", "cmd+f13"] {
    expect(HotkeySpec(bad) == nil, "shortcut: \"\(bad)\" is rejected")
}

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("All checks passed")
