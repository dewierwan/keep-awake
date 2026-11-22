#!/bin/bash
# Rebuilds Resources/AppIcon.icns from Resources/AppIcon.svg.
# Only needed after changing the SVG; the .icns file is checked in.
set -euo pipefail
cd "$(dirname "$0")/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
iconset="$work/AppIcon.iconset"
mkdir "$iconset"

for size in 16 32 128 256 512; do
  double=$((size * 2))
  sips -s format png -z "$size" "$size" Resources/AppIcon.svg --out "$iconset/icon_${size}x${size}.png" >/dev/null
  sips -s format png -z "$double" "$double" Resources/AppIcon.svg --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$iconset" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
