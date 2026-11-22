#!/bin/bash
# Builds "build/Keep Awake.app" from source. Needs only the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

app="build/Keep Awake.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/KeepAwake "$app/Contents/MacOS/KeepAwake"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

# Sign for this Mac only. There is no Apple developer certificate involved.
codesign --force --sign - "$app"
echo "Built $app"
