#!/bin/bash
# Renders design snapshots of every UI state + the app icon, and rebuilds Resources/AppIcon.icns.
# Usage: ./design.sh [output-dir]   (default: build/design)
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-build/design}"
mkdir -p build "$OUT"

# Same sources as the app minus its entry point; Design/main.swift is the entry point here.
SOURCES=$(ls Sources/*.swift | grep -v '/App.swift$')
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos14.4" $SOURCES Design/*.swift -o build/design-tool
build/design-tool "$OUT"

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$OUT/AppIcon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$OUT/AppIcon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Updated Resources/AppIcon.icns"
