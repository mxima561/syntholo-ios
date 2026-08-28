#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
xcresult_assertion="$repository_root/scripts/assert_xcresult_summary.mjs"
tap_assertion="$repository_root/scripts/assert_tap_summary.mjs"

assert_accepts() {
  local input=$1
  shift

  if ! printf '%s\n' "$input" | node "$@" >/dev/null; then
    echo "Expected result assertion to accept a complete fixture: $*" >&2
    exit 1
  fi
}

assert_rejects() {
  local input=$1
  shift
  local assertion_status

  set +e
  printf '%s\n' "$input" | node "$@" >/dev/null 2>&1
  assertion_status=$?
  set -e

  if [[ "$assertion_status" -eq 0 ]]; then
    echo "Expected result assertion to reject an incomplete fixture: $*" >&2
    exit 1
  fi
}

unit_summary='{"result":"Passed","totalTestCount":98,"passedTests":98,"failedTests":0,"skippedTests":0}'
functional_ui_summary='{"result":"Passed","totalTestCount":16,"passedTests":16,"failedTests":0,"skippedTests":0}'

assert_accepts "$unit_summary" "$xcresult_assertion" 98 unit-tests
assert_accepts "$functional_ui_summary" "$xcresult_assertion" 16 functional-ui-tests
assert_rejects '{"result":"Passed","totalTestCount":97,"passedTests":97,"failedTests":0,"skippedTests":0}' \
  "$xcresult_assertion" 98 unit-tests
assert_rejects '{"result":"Passed","totalTestCount":15,"passedTests":15,"failedTests":0,"skippedTests":0}' \
  "$xcresult_assertion" 16 functional-ui-tests
assert_rejects '{"result":"Passed","totalTestCount":16,"passedTests":15,"failedTests":0,"skippedTests":1}' \
  "$xcresult_assertion" 16 functional-ui-tests

complete_tap=$'TAP version 13\n1..20\n# tests 20\n# suites 0\n# pass 20\n# fail 0\n# cancelled 0\n# skipped 0\n# todo 0'
mismatched_tap=$'TAP version 13\n1..19\n# tests 19\n# suites 0\n# pass 19\n# fail 0\n# cancelled 0\n# skipped 0\n# todo 0'
skipped_tap=$'TAP version 13\n1..20\n# tests 20\n# suites 0\n# pass 19\n# fail 0\n# cancelled 0\n# skipped 1\n# todo 0'

assert_accepts "$complete_tap" "$tap_assertion" 20 firestore-rules-tests
assert_rejects "$mismatched_tap" "$tap_assertion" 20 firestore-rules-tests
assert_rejects "$skipped_tap" "$tap_assertion" 20 firestore-rules-tests

echo "result-assertion-tests: exact XCTest and TAP counts enforced."
