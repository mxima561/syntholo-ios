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
  '/^run_accessibility_audit_with_retry() {$/,/^}$/p' \
  scripts/test.sh)
reboot_source=$(sed -n \
  '/^reboot_ui_audit_simulator() {$/,/^}$/p' \
  scripts/test.sh)
if [[ -z "$helper_source" || -z "$reboot_source" ]]; then
  echo "Could not load the accessibility retry functions from scripts/test.sh." >&2
  exit 1
fi
eval "$reboot_source"
eval "$helper_source"

reboot_runner_call_count=0
reboot_runner_statuses=(0 73 0)

function ./scripts/run_with_timeout.sh {
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
create_partial_on_first_timeout=0
require_partial_removed_before_retry=0
active_result_bundle=""
runner_statuses=()

function ./scripts/run_with_timeout.sh {
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

reset_mocks() {
  runner_call_count=0
  reboot_call_count=0
  reboot_status=0
  create_partial_on_first_timeout=0
  require_partial_removed_before_retry=0
  active_result_bundle=$1
  shift
  runner_statuses=("$@")
}

capture_helper_status() {
  run_accessibility_audit_with_retry \
    1 \
    "$active_result_bundle" \
    SyntholoUITests/AccessibilityAuditUITests/testSyntheticAudit
}

direct_result="$result_directory/Direct.xcresult"
reset_mocks "$direct_result" 0
run_accessibility_audit_with_retry \
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

retry_result="$result_directory/Retry.xcresult"
reset_mocks "$retry_result" 124 0
create_partial_on_first_timeout=1
require_partial_removed_before_retry=1
run_accessibility_audit_with_retry \
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

echo "accessibility-retry-tests: timeout-only retry, reboot, cleanup, and path guards passed."
