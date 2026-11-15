#!/bin/bash
# Builds build/Undertone.app (signed with this Mac's Apple Development identity, else ad-hoc).
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
# Optional default API keys (gitignored); the app falls back to them when settings are empty.
[ -f Resources/Secrets.plist ] && cp Resources/Secrets.plist "$APP/Contents/Resources/"
# Sign with a stable identity when this Mac has one: macOS ties the system-audio permission to the
# signature, and an ad-hoc signature changes on every build, so the permission prompt came back each time.
# Override with SIGN_IDENTITY="..." ./build.sh; falls back to ad-hoc ("-") when no identity is found.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')}"
codesign --force --sign "${IDENTITY:--}" "$APP"

echo "Built $APP"
