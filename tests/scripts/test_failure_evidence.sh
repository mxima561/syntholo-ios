#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-failure-evidence-tests.XXXXXX")
active_runner_pid=""
active_child_pid=""
cleanup_fixture() {
  if [[ -n "$active_child_pid" ]]; then
    kill -TERM "$active_child_pid" 2>/dev/null || true
  fi
  if [[ -n "$active_runner_pid" ]]; then
    kill -TERM "$active_runner_pid" 2>/dev/null || true
    wait "$active_runner_pid" 2>/dev/null || true
  fi
  rm -rf -- "$test_root"
}
trap cleanup_fixture EXIT

# Execute the real runner. Only slow external build/tooling boundaries are
# replaced; its result allocation, assertions, exit handling and cleanup run.
function ./scripts/test_content.sh { :; }
function ./scripts/test_content_publication.sh { :; }
function ./scripts/bootstrap.sh { :; }
function ./tests/scripts/test_run_with_timeout.sh { :; }
function ./tests/scripts/test_accessibility_audit_retry.sh { :; }
function ./tests/scripts/test_result_assertions.sh { :; }
function ./tests/scripts/test_ci_configuration.sh { :; }
function ./tests/scripts/test_failure_evidence.sh { :; }
function ./scripts/test_environment_configuration.sh { :; }
function ./scripts/test_firebase_rules.sh {
  return "${EVIDENCE_RULES_STATUS:-0}"
}
function ./scripts/run_with_timeout.sh {
  shift
  "$@"
}

xcodebuild() {
  local result_bundle=""
  local previous=""
  local argument
  for argument in "$@"; do
    if [[ "$previous" == "-resultBundlePath" ]]; then
      result_bundle=$argument
    fi
    previous=$argument
  done
  [[ -n "$result_bundle" ]] || return 0

  mkdir -p "$result_bundle"
  printf 'synthetic test evidence\n' > "$result_bundle/Info.plist"
  printf '%s\n' "${result_bundle%/*}" > "$EVIDENCE_RESULT_PATH"
  if [[ "$result_bundle" == */Unit.xcresult ]]; then
    if [[ -n "${EVIDENCE_CHILD_PID:-}" ]]; then
      /bin/sh -c 'printf "%s\n" "$$" > "$EVIDENCE_CHILD_PID"; exec /bin/sleep 15'
      return
    fi
    if [[ "${EVIDENCE_CLOSE_STDERR:-0}" == 1 ]]; then
      exec 2>&-
    fi
    if [[ -n "${EVIDENCE_SIGNAL:-}" ]]; then
      kill -s "$EVIDENCE_SIGNAL" "$$"
      return 0
    fi
    return "${EVIDENCE_UNIT_STATUS:-0}"
  fi
}

xcrun() {
  [[ "$1" == "xcresulttool" ]] || return 0
  # The fixture satisfies the caller's count; separate assertion tests enforce
  # count correctness. The fallback serves the simulator-ID-only summary read.
  local count=${expected_count:-1}
  if [[ "$4" == "tests" ]]; then
    printf '{"testNodes":[]}\n'
    return
  fi
  printf '{"result":"Passed","totalTestCount":%s,"passedTests":%s,"failedTests":0,"skippedTests":0,"devicesAndConfigurations":[{"device":{"platform":"iOS Simulator","deviceId":"00000000-0000-0000-0000-000000000000"}}]}\n' \
    "$count" "$count"
}

declare -f ./scripts/test_content.sh ./scripts/test_content_publication.sh \
  ./scripts/bootstrap.sh ./tests/scripts/test_run_with_timeout.sh \
  ./tests/scripts/test_accessibility_audit_retry.sh \
  ./tests/scripts/test_result_assertions.sh ./tests/scripts/test_ci_configuration.sh \
  ./tests/scripts/test_failure_evidence.sh ./scripts/test_environment_configuration.sh \
  ./scripts/test_firebase_rules.sh ./scripts/run_with_timeout.sh xcodebuild xcrun \
  > "$test_root/tool-doubles.sh"

run_case() {
  local name=$1
  local unit_status=$2
  local rules_status=$3
  local signal=$4
  local expected_status=$5
  local should_retain=$6
  local close_stderr=${7:-0}
  local case_root="$test_root/$name"
  local actual_status
  local results
  mkdir -p "$case_root/tmp"
  printf 'unrelated file\n' > "$case_root/tmp/neighbor"

  set +e
  {
    TMPDIR="$case_root/tmp" \
      BASH_ENV="$test_root/tool-doubles.sh" \
      EVIDENCE_RESULT_PATH="$case_root/result-path" \
      EVIDENCE_UNIT_STATUS="$unit_status" \
      EVIDENCE_RULES_STATUS="$rules_status" \
      EVIDENCE_SIGNAL="$signal" \
      EVIDENCE_CLOSE_STDERR="$close_stderr" \
      SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT=1 \
      bash "$repository_root/scripts/test.sh" > "$case_root/output.log" 2>&1
    actual_status=$?
  } 2>> "$case_root/output.log"
  set -e
  if [[ "$actual_status" -ne "$expected_status" ]]; then
    echo "$name changed the runner exit: expected $expected_status, got $actual_status." >&2
    sed -n 'p' "$case_root/output.log" >&2
    exit 1
  fi
  [[ -f "$case_root/result-path" ]] || {
    echo "$name did not reach the real runner's XCTest phase." >&2
    exit 1
  }
  IFS= read -r results < "$case_root/result-path"
  if [[ "$should_retain" == 1 ]]; then
    if [[ ! -f "$results/Unit.xcresult/Info.plist" ]]; then
      echo "$name deleted failed-run XCTest evidence: $results" >&2
      exit 1
    fi
    if [[ "$close_stderr" == 0 ]] \
      && ! grep -Fq -- "$results" "$case_root/output.log"; then
      echo "$name did not report where the failed-run evidence was retained." >&2
      exit 1
    fi
  elif [[ -e "$results" ]]; then
    echo "$name failed to clean successful-run XCTest evidence: $results" >&2
    exit 1
  fi
  [[ -f "$case_root/tmp/neighbor" ]] || {
    echo "$name removed a file outside its result directory." >&2
    exit 1
  }
  echo "failure-evidence-tests: $name passed."
}

# Break caught: unconditional cleanup erases the bundle needed to diagnose RED.
run_case test_failure 65 0 "" 65 1
# Break caught: a final non-XCTest failure deletes earlier diagnostic evidence.
run_case rules_failure 0 73 "" 73 1
# Break caught: retaining all outcomes leaks successful temporary result trees.
run_case success 0 0 "" 0 0
# Break caught: interrupted runs lose evidence or are reported as successful.
run_case hangup 0 0 HUP 129 1
run_case interrupt 0 0 INT 130 1
run_case terminate 0 0 TERM 143 1
# Break caught: a reporting error replaces the actual failed-test status.
run_case closed_stderr 65 0 "" 65 1 1

# Exercise real asynchronous cancellation while an external child is active.
# Installing TERM traps on the runner can defer its exit until that child ends.
case_root="$test_root/active_child"
mkdir -p "$case_root/tmp"
TMPDIR="$case_root/tmp" \
  BASH_ENV="$test_root/tool-doubles.sh" \
  EVIDENCE_RESULT_PATH="$case_root/result-path" \
  EVIDENCE_CHILD_PID="$case_root/child-pid" \
  SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT=1 \
  bash "$repository_root/scripts/test.sh" > "$case_root/output.log" 2>&1 &
active_runner_pid=$!
for attempt in {1..150}; do
  [[ -s "$case_root/child-pid" ]] && break
  /bin/sleep 0.02
done
[[ -s "$case_root/child-pid" ]] || {
  echo "The cancellation fixture did not start its external child." >&2
  exit 1
}
IFS= read -r active_child_pid < "$case_root/child-pid"
kill -0 "$active_child_pid"
{
  kill -TERM "$active_runner_pid"
  for attempt in {1..150}; do
    kill -0 "$active_runner_pid" 2>/dev/null || break
    /bin/sleep 0.02
  done
} 2>> "$case_root/output.log"
if kill -0 "$active_runner_pid" 2>/dev/null; then
  echo "Runner TERM handling waited for the active child instead of terminating." >&2
  exit 1
fi
set +e
wait "$active_runner_pid" 2>/dev/null
actual_status=$?
set -e
active_runner_pid=""
[[ "$actual_status" -eq 143 ]] || {
  echo "Active-child cancellation changed TERM status to $actual_status." >&2
  exit 1
}
IFS= read -r results < "$case_root/result-path"
[[ -f "$results/Unit.xcresult/Info.plist" ]] || {
  echo "Active-child cancellation deleted XCTest evidence." >&2
  exit 1
}
grep -Fq -- "$results" "$case_root/output.log"
kill -TERM "$active_child_pid" 2>/dev/null || true
active_child_pid=""
echo "failure-evidence-tests: active-child cancellation passed."
