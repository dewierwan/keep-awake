#!/bin/bash
# Builds Keep Awake, puts it in /Applications, and sets it to start at login.
# Run it again to update.
set -euo pipefail
cd "$(dirname "$0")/.."

label="com.dewierwan.keep-awake"
app="/Applications/Keep Awake.app"
agent="$HOME/Library/LaunchAgents/$label.plist"

Scripts/build-app.sh

# Stop a running copy first. It hands the lid switch back before it exits.
launchctl bootout "gui/$UID/$label" 2>/dev/null || true
pkill -TERM -x KeepAwake 2>/dev/null || true
sleep 1

rm -rf "$app"
cp -R "build/Keep Awake.app" "$app"

mkdir -p "$(dirname "$agent")"
cat > "$agent" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>ProgramArguments</key>
	<array>
		<string>$app/Contents/MacOS/KeepAwake</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<!-- Restart after a crash, but not after Quit. -->
	<key>KeepAlive</key>
	<dict>
		<key>SuccessfulExit</key>
		<false/>
	</dict>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$UID" "$agent"
echo "Installed. Look for the eye icon in the menu bar."
