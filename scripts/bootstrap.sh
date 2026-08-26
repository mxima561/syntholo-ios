#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Run: brew bundle"
  exit 1
fi

xcodegen generate
echo "Generated Syntholo.xcodeproj"
