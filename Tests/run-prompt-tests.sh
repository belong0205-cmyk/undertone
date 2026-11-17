#!/bin/bash
# Compiles and runs Tests/PromptTests/main.swift against the app's prompt code (no API calls).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(mktemp -d)"
swiftc -swift-version 5 -target "$(uname -m)-apple-macos14.4" \
  Sources/ClaudeClient.swift Sources/KnowledgeBase.swift Sources/DebugLog.swift Tests/PromptTests/main.swift -o "$OUT/prompt-tests"
"$OUT/prompt-tests"
