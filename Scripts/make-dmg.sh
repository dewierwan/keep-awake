#!/bin/bash
# Packs "build/Keep Awake.app" into a disk image people can download:
# the app next to a shortcut to the Applications folder.
# Prints the path of the disk image.
set -euo pipefail
cd "$(dirname "$0")/.."

app="build/Keep Awake.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
dmg="build/Keep-Awake-$version.dmg"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"

rm -f "$dmg"
hdiutil create -volname "Keep Awake" -srcfolder "$staging" -format UDZO -quiet "$dmg"
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg"
fi
echo "$dmg"
