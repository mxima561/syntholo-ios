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

assert_rejects_with_detail() {
  local input=$1
  local expected_detail=$2
  shift 2
  local assertion_output
  local assertion_status

  set +e
  assertion_output=$(printf '%s\n' "$input" | node "$@" 2>&1)
  assertion_status=$?
  set -e

  if [[ "$assertion_status" -eq 0 ]]; then
    echo "Expected result assertion to reject a failed fixture: $*" >&2
    exit 1
  fi

  if ! grep -Fq "$expected_detail" <<< "$assertion_output"; then
    echo "Expected failed result output to contain: $expected_detail" >&2
    echo "$assertion_output" >&2
    exit 1
  fi
}

unit_summary='{"result":"Passed","totalTestCount":106,"passedTests":106,"failedTests":0,"skippedTests":0}'
functional_ui_summary='{"result":"Passed","totalTestCount":18,"passedTests":18,"failedTests":0,"skippedTests":0}'

assert_accepts "$unit_summary" "$xcresult_assertion" 106 unit-tests
assert_accepts "$functional_ui_summary" "$xcresult_assertion" 18 functional-ui-tests
assert_rejects '{"result":"Passed","totalTestCount":105,"passedTests":105,"failedTests":0,"skippedTests":0}' \
  "$xcresult_assertion" 106 unit-tests
assert_rejects '{"result":"Passed","totalTestCount":17,"passedTests":17,"failedTests":0,"skippedTests":0}' \
  "$xcresult_assertion" 18 functional-ui-tests
assert_rejects '{"result":"Passed","totalTestCount":18,"passedTests":17,"failedTests":0,"skippedTests":1}' \
  "$xcresult_assertion" 18 functional-ui-tests
failed_ui_summary='{"result":"Failed","totalTestCount":18,"passedTests":17,"failedTests":1,"skippedTests":0,"testFailures":[{"testName":"testAlternatePathStaysSelectedWithoutReplacingRecommendation()","failureText":"AI for Work did not expose its persisted selected state."}]}'
assert_rejects_with_detail "$failed_ui_summary" \
  'testAlternatePathStaysSelectedWithoutReplacingRecommendation(): AI for Work did not expose its persisted selected state.' \
  "$xcresult_assertion" 18 functional-ui-tests

diagnostic_fixture=$(mktemp "${TMPDIR:-/tmp}/syntholo-xcresult-diagnostic.XXXXXX")
trap 'rm -f "$diagnostic_fixture"' EXIT
printf '%s\n' '{"testNodes":[{"children":[{"name":"OnboardingUITests.swift:259: XCTAssertTrue failed","nodeType":"Failure Message"}]}],"testRuns":[{"activities":[{"attachments":[{"name":"UI Snapshot at failure","payloadId":"snapshot-payload"}],"isAssociatedWithFailure":true,"sourceCodeContext":{"filePath":"/workspace/SyntholoUITests/OnboardingUITests.swift","lineNumber":260},"title":"XCTAssertTrue failed"}]}]}' > "$diagnostic_fixture"
assert_rejects_with_detail "$failed_ui_summary" \
  'OnboardingUITests.swift:259: XCTAssertTrue failed' \
  "$xcresult_assertion" 18 functional-ui-tests "$diagnostic_fixture"
assert_rejects_with_detail "$failed_ui_summary" \
  'OnboardingUITests.swift:260: XCTAssertTrue failed' \
  "$xcresult_assertion" 18 functional-ui-tests "$diagnostic_fixture"
assert_rejects_with_detail "$failed_ui_summary" \
  'Failure activity: XCTAssertTrue failed' \
  "$xcresult_assertion" 18 functional-ui-tests "$diagnostic_fixture"
assert_rejects_with_detail "$failed_ui_summary" \
  'UI Snapshot at failure (payload snapshot-payload)' \
  "$xcresult_assertion" 18 functional-ui-tests "$diagnostic_fixture"

complete_tap=$'TAP version 13\n1..20\n# tests 20\n# suites 0\n# pass 20\n# fail 0\n# cancelled 0\n# skipped 0\n# todo 0'
mismatched_tap=$'TAP version 13\n1..19\n# tests 19\n# suites 0\n# pass 19\n# fail 0\n# cancelled 0\n# skipped 0\n# todo 0'
skipped_tap=$'TAP version 13\n1..20\n# tests 20\n# suites 0\n# pass 19\n# fail 0\n# cancelled 0\n# skipped 1\n# todo 0'
complete_content_tap=$'TAP version 13\n1..29\n# tests 73\n# suites 0\n# pass 73\n# fail 0\n# cancelled 0\n# skipped 0\n# todo 0'
mismatched_content_tap=$'TAP version 13\n1..28\n# tests 72\n# suites 0\n# pass 72\n# fail 0\n# cancelled 0\n# skipped 0\n# todo 0'
skipped_content_tap=$'TAP version 13\n1..29\n# tests 73\n# suites 0\n# pass 72\n# fail 0\n# cancelled 0\n# skipped 1\n# todo 0'

assert_accepts "$complete_tap" "$tap_assertion" 20 firestore-rules-tests
assert_rejects "$mismatched_tap" "$tap_assertion" 20 firestore-rules-tests
assert_rejects "$skipped_tap" "$tap_assertion" 20 firestore-rules-tests
assert_accepts "$complete_content_tap" "$tap_assertion" 73 curriculum-content-tests
assert_rejects "$mismatched_content_tap" "$tap_assertion" 73 curriculum-content-tests
assert_rejects "$skipped_content_tap" "$tap_assertion" 73 curriculum-content-tests

echo "result-assertion-tests: exact XCTest and TAP counts enforced."
