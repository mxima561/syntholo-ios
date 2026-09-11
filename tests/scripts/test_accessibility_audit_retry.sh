#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repository_root"

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-accessibility-retry-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

result_directory="$temporary_directory/results"
mkdir -p "$result_directory"
ui_audit_destination="platform=iOS Simulator,id=00000000-0000-0000-0000-000000000000"
ui_audit_simulator_udid="00000000-0000-0000-0000-000000000000"

helper_source=$(sed -n \
  '/^run_ui_test_with_retry() {$/,/^}$/p' \
  scripts/test.sh)
reboot_source=$(sed -n \
  '/^reboot_ui_audit_simulator() {$/,/^}$/p' \
  scripts/test.sh)
report_source=$(sed -n \
  '/^report_ui_test_failure() {$/,/^}$/p' \
  scripts/test.sh)
if [[ -z "$helper_source" || -z "$reboot_source" || -z "$report_source" ]]; then
  echo "Could not load the UI test retry functions from scripts/test.sh." >&2
  exit 1
fi
eval "$reboot_source"
eval "$helper_source"

reboot_runner_call_count=0
reboot_runner_statuses=(0 73 0)

run_timed_command() {
  local status=${reboot_runner_statuses[$reboot_runner_call_count]}
  reboot_runner_call_count=$((reboot_runner_call_count + 1))
  return "$status"
}

set +e
reboot_ui_audit_simulator "$ui_audit_simulator_udid" >/dev/null
reboot_step_status=$?
set -e
[[ "$reboot_step_status" -eq 73 ]]
[[ "$reboot_runner_call_count" -eq 2 ]]

runner_call_count=0
reboot_call_count=0
reboot_status=0
failure_report_call_count=0
failure_report_result=""
failure_report_expected_count=""
failure_report_label=""
create_partial_on_first_timeout=0
require_partial_removed_before_retry=0
active_result_bundle=""
runner_statuses=()

run_timed_command() {
  local status_index=$runner_call_count
  local status=${runner_statuses[$status_index]}
  runner_call_count=$((runner_call_count + 1))

  if [[ "$runner_call_count" -eq 2 \
    && "$require_partial_removed_before_retry" -eq 1 \
    && -e "$active_result_bundle" ]]; then
    echo "Retry began before the partial result bundle was removed." >&2
    return 90
  fi

  if [[ "$runner_call_count" -eq 1 \
    && "$status" -eq 124 \
    && "$create_partial_on_first_timeout" -eq 1 ]]; then
    mkdir -p "$active_result_bundle"
  fi

  return "$status"
}

reboot_ui_audit_simulator() {
  [[ "$1" == "$ui_audit_simulator_udid" ]]
  reboot_call_count=$((reboot_call_count + 1))
  return "$reboot_status"
}

report_ui_test_failure() {
  failure_report_call_count=$((failure_report_call_count + 1))
  failure_report_result=$1
  failure_report_expected_count=$2
  failure_report_label=$3
}

reset_mocks() {
  runner_call_count=0
  reboot_call_count=0
  reboot_status=0
  failure_report_call_count=0
  failure_report_result=""
  failure_report_expected_count=""
  failure_report_label=""
  create_partial_on_first_timeout=0
  require_partial_removed_before_retry=0
  active_result_bundle=$1
  shift
  runner_statuses=("$@")
}

assert_equal() {
  local expected=$1
  local actual=$2
  local message=$3
  if [[ "$actual" != "$expected" ]]; then
    echo "$message: expected '$expected', got '$actual'." >&2
    exit 1
  fi
}

capture_helper_status() {
  run_ui_test_with_retry \
    1 \
    "$active_result_bundle" \
    SyntholoUITests/AccessibilityAuditUITests/testSyntheticAudit
}

direct_result="$result_directory/Direct.xcresult"
reset_mocks "$direct_result" 0
run_ui_test_with_retry \
  1 \
  "$direct_result" \
  SyntholoUITests/AccessibilityAuditUITests/testSyntheticAudit
[[ "$runner_call_count" -eq 1 && "$reboot_call_count" -eq 0 ]]

failure_result="$result_directory/Failure.xcresult"
reset_mocks "$failure_result" 65
set +e
capture_helper_status
failure_status=$?
set -e
[[ "$failure_status" -eq 65 ]]
[[ "$runner_call_count" -eq 1 && "$reboot_call_count" -eq 0 ]]
assert_equal 1 "$failure_report_call_count" "Direct failure report count"
assert_equal "$failure_result" "$failure_report_result" "Direct failure result"
assert_equal 1 "$failure_report_expected_count" "Direct failure expected count"
assert_equal Failure "$failure_report_label" "Direct failure label"

retry_result="$result_directory/Retry.xcresult"
reset_mocks "$retry_result" 124 0
create_partial_on_first_timeout=1
require_partial_removed_before_retry=1
run_ui_test_with_retry \
  1 \
  "$retry_result" \
  SyntholoUITests/AccessibilityAuditUITests/testSyntheticAudit
[[ "$runner_call_count" -eq 2 && "$reboot_call_count" -eq 1 ]]
[[ ! -e "$retry_result" ]]

double_timeout_result="$result_directory/DoubleTimeout.xcresult"
reset_mocks "$double_timeout_result" 124 124
set +e
capture_helper_status
double_timeout_status=$?
set -e
[[ "$double_timeout_status" -eq 124 ]]
[[ "$runner_call_count" -eq 2 && "$reboot_call_count" -eq 1 ]]

retry_failure_result="$result_directory/RetryFailure.xcresult"
reset_mocks "$retry_failure_result" 124 65
set +e
capture_helper_status
retry_failure_status=$?
set -e
[[ "$retry_failure_status" -eq 65 ]]
[[ "$runner_call_count" -eq 2 && "$reboot_call_count" -eq 1 ]]
assert_equal 1 "$failure_report_call_count" "Retry failure report count"
assert_equal "$retry_failure_result" "$failure_report_result" "Retry failure result"
assert_equal 1 "$failure_report_expected_count" "Retry failure expected count"
assert_equal RetryFailure "$failure_report_label" "Retry failure label"

assertion_call_count=0
assertion_result=""
assertion_expected_count=""
assertion_label=""
assertion_diagnostics=""
assert_test_result() {
  assertion_call_count=$((assertion_call_count + 1))
  assertion_result=$1
  assertion_expected_count=$2
  assertion_label=$3
  assertion_diagnostics=$4
  return 1
}
eval "$report_source"

readable_failure_result="$result_directory/ReadableFailure.xcresult"
mkdir -p "$readable_failure_result"
touch "$readable_failure_result/Info.plist"
report_ui_test_failure "$readable_failure_result" 10 functional-CurriculumUITests
assert_equal 1 "$assertion_call_count" "Readable failure assertion count"
assert_equal "$readable_failure_result" "$assertion_result" "Readable failure result"
assert_equal 10 "$assertion_expected_count" "Readable failure expected count"
assert_equal functional-CurriculumUITests "$assertion_label" "Readable failure label"
assert_equal 1 "$assertion_diagnostics" "Readable failure diagnostics flag"

incomplete_failure_result="$result_directory/IncompleteFailure.xcresult"
mkdir -p "$incomplete_failure_result"
incomplete_message=$(report_ui_test_failure \
  "$incomplete_failure_result" \
  1 \
  IncompleteFailure 2>&1)
assert_equal 1 "$assertion_call_count" "Incomplete failure assertion count"
assert_equal \
  "IncompleteFailure failed without a readable xcresult bundle." \
  "$incomplete_message" \
  "Incomplete failure message"

reboot_failure_result="$result_directory/RebootFailure.xcresult"
reset_mocks "$reboot_failure_result" 124 0
reboot_status=73
set +e
capture_helper_status
reboot_failure_status=$?
set -e
[[ "$reboot_failure_status" -eq 73 ]]
[[ "$runner_call_count" -eq 1 && "$reboot_call_count" -eq 1 ]]

outside_result="$result_directory/../Outside.xcresult"
reset_mocks "$outside_result" 0
set +e
capture_helper_status 2>/dev/null
outside_status=$?
set -e
[[ "$outside_status" -eq 64 ]]
[[ "$runner_call_count" -eq 0 && "$reboot_call_count" -eq 0 ]]

nested_result="$result_directory/nested/Nested.xcresult"
reset_mocks "$nested_result" 0
set +e
capture_helper_status 2>/dev/null
nested_status=$?
set -e
[[ "$nested_status" -eq 64 ]]
[[ "$runner_call_count" -eq 0 && "$reboot_call_count" -eq 0 ]]

echo "ui-test-retry-tests: timeout-only retry, diagnostics, reboot, cleanup, and path guards passed."
