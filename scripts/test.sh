#!/usr/bin/env bash
set -euo pipefail

./scripts/bootstrap.sh
xcodebuild test \
  -project Syntholo.xcodeproj \
  -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -skip-testing:SyntholoUITests/AccessibilityAuditUITests
