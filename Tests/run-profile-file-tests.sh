#!/bin/bash
# Compiles and runs Tests/ProfileFileTests/main.swift against the app's sources (no API calls).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(mktemp -d)"
swiftc -swift-version 5 -target "$(uname -m)-apple-macos14.4" \
  $(ls Sources/*.swift | grep -v '/App.swift$') Tests/ProfileFileTests/main.swift -o "$OUT/profile-file-tests"
"$OUT/profile-file-tests"
