# Keep Awake

A macOS menu bar app that keeps a MacBook awake for a set time, lid open or closed. Read `README.md` first: "Why it exists" explains the kernel switch and the one rule the app follows.

## Commands

- `swift build` and `swift run Checks`: build and run the unit tests. Only the Xcode Command Line Tools are installed, so there is no `xcodebuild`, and XCTest and Swift Testing do not work reliably.
- `Scripts/install.sh`: build, copy to `/Applications`, and restart the login agent.
- `.build/debug/KeepAwake --snapshots <folder>`: render the panel to PNG files in both states and both appearances. Read every PNG after a design change.
- `"/Applications/Keep Awake.app/Contents/MacOS/KeepAwake" --start 1`, `--stop`, `--status`: drive the running app.

## Rules

- Never turn the lid switch off (`LidSwitch.set(on: false)`) while an external display is connected. With the lid closed this puts the Mac to sleep at once, in the middle of the owner's work. `lidAction` in `Sources/KeepAwakeCore/LidPolicy.swift` is the only place that decides, and its tests must keep passing.
- Do not use `@State`. It needs a compiler plugin that ships only with full Xcode. Use `@StateObject` with a small `ObservableObject`.
- To check a change to the switch, read the kernel log, as the last section of the README shows. The `AppleClamshellCausesSleep` property in `ioreg` is not updated live, so do not rely on it.
- Design tokens live in `Theme.swift`. State is shown with shape and text, never with red or green.
