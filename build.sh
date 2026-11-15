#!/bin/bash
# Builds build/Undertone.app (ad-hoc signed).
# Usage: ./build.sh                          (this Mac's architecture, fast)
#        ARCHS="arm64 x86_64" ./build.sh     (universal: Apple Silicon + Intel)
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Undertone.app
ARCHS="${ARCHS:-$(uname -m)}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SLICES=()
for ARCH in $ARCHS; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macos14.4" -parse-as-library \
    Sources/*.swift -o "build/Undertone-$ARCH"
  SLICES+=("build/Undertone-$ARCH")
done
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/Undertone"
rm -f "${SLICES[@]}"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Knowledge "$APP/Contents/Resources/Knowledge"
codesign --force --sign - "$APP"

echo "Built $APP"
