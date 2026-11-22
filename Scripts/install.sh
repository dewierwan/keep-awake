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

# The app writes its own login entry. Loading it now starts the app, and lets
# macOS restart it if it ever crashes.
"$app/Contents/MacOS/KeepAwake" --login on >/dev/null
launchctl bootstrap "gui/$UID" "$agent"
echo "Installed. Look for the eye icon in the menu bar."
