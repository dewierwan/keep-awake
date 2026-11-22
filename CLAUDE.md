# Keep Awake

A macOS menu bar app that keeps a MacBook awake for a set time, lid open or closed. Read `README.md` first: "Why it exists" explains the kernel switch and the one rule the app follows.

## Commands

- `swift build` and `swift run Checks`: build and run the unit tests. Only the Xcode Command Line Tools are installed, so there is no `xcodebuild`, and XCTest and Swift Testing do not work reliably.
- `Scripts/install.sh`: build, copy to `/Applications`, and restart the login agent.
- `.build/debug/KeepAwake --snapshots <folder>`: render the panel to PNG files in both states and both appearances. Read every PNG after a design change.
- `"/Applications/Keep Awake.app/Contents/MacOS/KeepAwake" --start 1`, `--stop`, `--status`: drive the running app.

## Rules

- Never turn the lid switch off (`LidSwitch.set(on: false)`) while an external display is connected. With the lid closed this puts the Mac to sleep at once, in the middle of the owner's work. `lidAction` in `Sources/KeepAwakeCore/LidPolicy.swift` is the only place that decides, and its tests must keep passing.
- "Open at login" is a launch agent file the app writes itself (`LoginItem.swift`). `SMAppService` was tried and macOS refuses to start a locally signed app from it (exit code 78).
- "Survive unplugging" (`AllSleepBlock.swift`) blocks all sleep with `sudo -n pmset -a disablesleep 1` during a session. Never run that command, or install the sudo rule, from a development session: turning the setting on is the owner's click and password. If a change could leave all sleep blocked after a session ends, it is a serious bug.
- Do not use `@State`. It needs a compiler plugin that ships only with full Xcode. Use `@StateObject` with a small `ObservableObject`.
- To check a change to the switch, read the kernel log, as the last section of the README shows. The `AppleClamshellCausesSleep` property in `ioreg` is not updated live, so do not rely on it.
- Design tokens live in `Theme.swift`. State is shown with shape and text, never with red or green.

## Releasing

1. Set the new version in `Resources/Info.plist` (`CFBundleShortVersionString`, and add one to `CFBundleVersion`), commit and push.
2. Tag it (`git tag -a v1.2.3 -m "Keep Awake 1.2.3"`) and push the tag. The Release workflow publishes a signed download once the signing secrets exist; until then it only builds an unsigned rehearsal.
3. Update the Homebrew formula in the `dewierwan/homebrew-tap` repository (`Formula/keep-awake.rb`): the `url` for the new tag and the `sha256` of that archive (`curl -sL <url> | shasum -a 256`). Test with `brew install dewierwan/tap/keep-awake`, then push.
