#!/bin/bash
# Stops Keep Awake and removes everything install.sh added.
set -euo pipefail

label="com.dewierwan.keep-awake"

launchctl bootout "gui/$UID/$label" 2>/dev/null || true
pkill -TERM -x KeepAwake 2>/dev/null || true
sleep 1

rm -f "$HOME/Library/LaunchAgents/$label.plist"
rm -rf "/Applications/Keep Awake.app"
defaults delete "$label" 2>/dev/null || true
echo "Removed Keep Awake."
