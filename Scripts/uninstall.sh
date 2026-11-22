#!/bin/bash
# Stops Keep Awake and removes everything install.sh added.
set -euo pipefail

label="com.dewierwan.keep-awake"

launchctl bootout "gui/$UID/$label" 2>/dev/null || true
pkill -TERM -x KeepAwake 2>/dev/null || true
sleep 1

# "Survive unplugging" adds one administrator rule. Removing it needs your password.
if [ -e /etc/sudoers.d/keep-awake ]; then
  echo "Removing the Survive unplugging rule (asks for your password)."
  sudo /bin/sh -c '/usr/bin/pmset -a disablesleep 0; /bin/rm -f /etc/sudoers.d/keep-awake'
fi

rm -f "$HOME/Library/LaunchAgents/$label.plist"
rm -rf "/Applications/Keep Awake.app"
defaults delete "$label" 2>/dev/null || true
echo "Removed Keep Awake."
