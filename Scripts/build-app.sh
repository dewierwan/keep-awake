#!/bin/bash
# Builds "build/Keep Awake.app" from source. Needs only the Xcode Command Line Tools.
#
# Optional settings, used for releases:
#   UNIVERSAL=1            build for Apple silicon and Intel in one app
#   SIGN_IDENTITY="..."    sign with a Developer ID certificate instead of for this Mac only
#   VERSION=1.2.3          stamp this version into the app
#   SWIFT_BUILD_FLAGS=...  extra flags for `swift build` (Homebrew passes --disable-sandbox)
set -euo pipefail
cd "$(dirname "$0")/.."

flags="${SWIFT_BUILD_FLAGS:-}"
app="build/Keep Awake.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

if [ "${UNIVERSAL:-0}" = "1" ]; then
  slices=()
  for arch in arm64 x86_64; do
    triple="$arch-apple-macosx13.0"
    swift build -c release --triple "$triple" $flags
    cp "$(swift build -c release --triple "$triple" $flags --show-bin-path)/KeepAwake" "build/KeepAwake-$arch"
    slices+=("build/KeepAwake-$arch")
  done
  lipo -create "${slices[@]}" -output "$app/Contents/MacOS/KeepAwake"
  rm -f "${slices[@]}"
else
  swift build -c release $flags
  cp "$(swift build -c release $flags --show-bin-path)/KeepAwake" "$app/Contents/MacOS/KeepAwake"
fi

cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
if [ -n "${VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$app/Contents/Info.plist"
fi

if [ -n "${SIGN_IDENTITY:-}" ]; then
  # A release: Apple will only notarize apps with the hardened runtime and a timestamp.
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
else
  # Sign for this Mac only. There is no Apple developer certificate involved.
  codesign --force --sign - "$app"
fi
echo "Built $app ($(lipo -archs "$app/Contents/MacOS/KeepAwake"))"
