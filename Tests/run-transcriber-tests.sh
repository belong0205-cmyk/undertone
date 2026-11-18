#!/bin/bash
# Compiles and runs Tests/TranscriberTests/main.swift against the app's sources (no network, no API calls).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(mktemp -d)"
swiftc -D DEBUG -swift-version 5 -target "$(uname -m)-apple-macos14.4" \
  $(ls Sources/*.swift | grep -v '/App.swift$') Tests/TranscriberTests/main.swift -o "$OUT/transcriber-tests"
"$OUT/transcriber-tests"
