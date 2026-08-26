#!/usr/bin/env bash
set -euo pipefail

./scripts/bootstrap.sh
destination='platform=iOS Simulator,name=iPhone 17 Pro'

# Accessibility audits run below one method per process, not in this baseline invocation.
xcodebuild test \
  -project Syntholo.xcodeproj \
  -scheme Syntholo \
  -destination "$destination" \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -skip-testing:SyntholoUITests/AccessibilityAuditUITests

if [[ "${SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT:-0}" == "1" ]]; then
  echo "Skipping accessibility audits by explicit diagnostic request."
  exit 0
fi

run_with_timeout() {
  local timeout_seconds=$1
  shift

  "$@" &
  local command_pid=$!

  (
    sleep "$timeout_seconds"
    if kill -0 "$command_pid" 2>/dev/null; then
      echo "Accessibility audit timed out after ${timeout_seconds}s (PID ${command_pid})." >&2
      kill -INT "$command_pid" 2>/dev/null || true
      sleep 10
      kill -TERM "$command_pid" 2>/dev/null || true
      sleep 5
      kill -KILL "$command_pid" 2>/dev/null || true
    fi
  ) &
  local watchdog_pid=$!

  local command_status
  if wait "$command_pid"; then
    command_status=0
  else
    command_status=$?
  fi

  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true
  return "$command_status"
}

echo "Running accessibility audit suite."
run_with_timeout 600 \
  xcodebuild -quiet test-without-building \
    -project Syntholo.xcodeproj \
    -scheme Syntholo \
    -destination "$destination" \
    -derivedDataPath DerivedData \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    -only-testing:SyntholoUITests/AccessibilityAuditUITests
