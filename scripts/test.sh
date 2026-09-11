#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/.." && pwd)
cd "$repository_root"

active_timed_command_pid=""
timed_command_starting=0
pending_cancellation_status=0

cancel_test_run() {
  local exit_status=$1
  if [[ "$timed_command_starting" -eq 1 ]]; then
    if [[ "$pending_cancellation_status" -eq 0 ]]; then
      pending_cancellation_status=$exit_status
    fi
    return
  fi
  trap '' INT TERM HUP
  if [[ -n "$active_timed_command_pid" ]]; then
    # The wrapper owns its isolated command group. Signal only this child;
    # a background shell can inherit ignored INT, so forward TERM instead.
    kill -TERM "$active_timed_command_pid" 2>/dev/null || true
    wait "$active_timed_command_pid" 2>/dev/null || true
  fi
  exit "$exit_status"
}

run_timed_command() {
  local command_status
  timed_command_starting=1
  ./scripts/run_with_timeout.sh "$@" &
  active_timed_command_pid=$!
  timed_command_starting=0
  if [[ "$pending_cancellation_status" -ne 0 ]]; then
    cancel_test_run "$pending_cancellation_status"
  fi
  # A builtin wait lets the signal trap run promptly while the child is busy.
  if wait "$active_timed_command_pid"; then
    command_status=0
  else
    command_status=$?
  fi
  active_timed_command_pid=""
  return "$command_status"
}

trap 'cancel_test_run 130' INT
trap 'cancel_test_run 143' TERM
trap 'cancel_test_run 129' HUP

run_timed_command 600 ./scripts/test_content.sh
run_timed_command 300 ./scripts/test_content_publication.sh
run_timed_command 600 ./scripts/bootstrap.sh
run_timed_command 600 ./tests/scripts/test_run_with_timeout.sh
run_timed_command 600 ./tests/scripts/test_accessibility_audit_retry.sh
run_timed_command 600 ./tests/scripts/test_result_assertions.sh
run_timed_command 600 ./tests/scripts/test_ci_configuration.sh
run_timed_command 600 ./tests/scripts/test_failure_evidence.sh
run_timed_command 600 ./scripts/test_environment_configuration.sh

destination=${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}
result_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-test-results.XXXXXX")
# Clean only after the final gate actually completed successfully.
test_run_completed=0
finish_test_run() {
  local exit_status=$?
  trap - EXIT
  if [[ "$exit_status" -eq 0 && "$test_run_completed" -eq 1 ]]; then
    if ! rm -rf -- "$result_directory"; then
      echo "Could not clean successful test results: $result_directory" >&2 || true
    fi
  else
    echo "Test run did not complete successfully. Retained XCTest results: $result_directory" >&2 || true
  fi
  return "$exit_status"
}
trap finish_test_run EXIT

simulator_udid_from_result_bundle() {
  local result_bundle=$1
  xcrun xcresulttool get test-results summary --path "$result_bundle" \
    | node -e '
        let input = "";
        process.stdin.setEncoding("utf8");
        process.stdin.on("data", (chunk) => { input += chunk; });
        process.stdin.on("end", () => {
          const summary = JSON.parse(input);
          const devices = (summary.devicesAndConfigurations ?? [])
            .map((entry) => entry?.device)
            .filter((device) =>
              device?.platform === "iOS Simulator"
              && /^[0-9A-Fa-f-]{36}$/.test(device?.deviceId ?? ""));
          const uniqueIDs = [...new Set(devices.map((device) => device.deviceId))];
          if (uniqueIDs.length !== 1) {
            console.error("Expected one iOS Simulator device in the test result.");
            process.exit(1);
          }
          process.stdout.write(uniqueIDs[0]);
        });
      '
}

reboot_ui_audit_simulator() {
  local simulator_udid=$1
  echo "Rebooting simulator $simulator_udid before the next accessibility audit group."
  run_timed_command 120 \
    xcrun simctl bootstatus "$simulator_udid" -b >/dev/null \
    || return $?
  run_timed_command 60 \
    xcrun simctl shutdown "$simulator_udid" >/dev/null \
    || return $?
  run_timed_command 120 \
    xcrun simctl bootstatus "$simulator_udid" -b >/dev/null \
    || return $?
}

run_ui_test_with_retry() {
  local timeout_seconds=$1
  local result_bundle=$2
  local test_identifier=$3
  local expected_count=${4:-1}
  local label=${5:-}
  local attempt
  local command_status
  local result_name

  case "$result_bundle" in
    "$result_directory"/*.xcresult)
      result_name=${result_bundle#"$result_directory"/}
      ;;
    *)
      echo "Refusing to manage a UI test result outside $result_directory." >&2
      return 64
      ;;
  esac
  if [[ "$result_name" == */* ]]; then
    echo "Refusing to manage a nested UI test result: $result_name." >&2
    return 64
  fi
  if [[ -z "$label" ]]; then
    label=${result_name%.xcresult}
  fi

  for attempt in 1 2; do
    if run_timed_command "$timeout_seconds" \
      xcodebuild -quiet test-without-building \
        -project Syntholo.xcodeproj \
        -scheme Syntholo \
        -destination "$ui_audit_destination" \
        -derivedDataPath DerivedData \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        -resultBundlePath "$result_bundle" \
        -only-testing:"$test_identifier"; then
      return 0
    else
      command_status=$?
    fi

    if [[ "$command_status" -ne 124 ]]; then
      report_ui_test_failure \
        "$result_bundle" \
        "$expected_count" \
        "$label"
      return "$command_status"
    fi

    if [[ "$attempt" -eq 2 ]]; then
      echo "UI test $test_identifier timed out twice; the result bundle may be incomplete." >&2
      return "$command_status"
    fi

    echo "UI test $test_identifier timed out; rebooting the simulator before retry 2 of 2."
    if reboot_ui_audit_simulator "$ui_audit_simulator_udid"; then
      :
    else
      return $?
    fi
    if rm -rf -- "$result_bundle"; then
      :
    else
      return $?
    fi
  done
}

assert_test_result() {
  local result_bundle=$1
  local expected_count=$2
  local label=$3
  local include_diagnostics=${4:-0}
  local -a diagnostic_paths=()

  if [[ "$include_diagnostics" == "1" ]]; then
    local tests_path="$result_directory/${label}-tests.json"
    if xcrun xcresulttool get test-results tests \
      --path "$result_bundle" > "$tests_path"; then
      diagnostic_paths+=("$tests_path")

      local activity_index=0
      local failed_identifier
      while IFS= read -r failed_identifier; do
        [[ -n "$failed_identifier" ]] || continue
        local activities_path="$result_directory/${label}-activities-${activity_index}.json"
        if xcrun xcresulttool get test-results activities \
          --path "$result_bundle" \
          --test-id "$failed_identifier" > "$activities_path"; then
          diagnostic_paths+=("$activities_path")
        fi
        activity_index=$((activity_index + 1))
      done < <(
        node -e '
          const tree = require(process.argv[1]);
          const walk = (value) => {
            if (Array.isArray(value)) return value.forEach(walk);
            if (!value || typeof value !== "object") return;
            if (value.nodeType === "Test Case"
                && value.result === "Failed"
                && value.nodeIdentifier) {
              console.log(value.nodeIdentifier);
            }
            Object.values(value).forEach(walk);
          };
          walk(tree);
        ' "$tests_path"
      )
    else
      echo "$label could not read xcresult test diagnostics." >&2
    fi
  fi

  if [[ -n "${diagnostic_paths[0]:-}" ]]; then
    xcrun xcresulttool get test-results summary \
      --path "$result_bundle" \
      | node ./scripts/assert_xcresult_summary.mjs \
          "$expected_count" "$label" "${diagnostic_paths[@]}"
  else
    xcrun xcresulttool get test-results summary \
      --path "$result_bundle" \
      | node ./scripts/assert_xcresult_summary.mjs "$expected_count" "$label"
  fi
}

report_ui_test_failure() {
  local result_bundle=$1
  local expected_count=$2
  local label=$3

  if [[ -f "$result_bundle/Info.plist" ]]; then
    assert_test_result "$result_bundle" "$expected_count" "$label" 1 || true
  else
    echo "$label failed without a readable xcresult bundle." >&2
  fi
}

echo "Building all test targets for $destination."
run_timed_command 600 \
  xcodebuild -quiet build-for-testing \
    -project Syntholo.xcodeproj \
    -scheme Syntholo \
    -destination "$destination" \
    -derivedDataPath DerivedData \
    CODE_SIGNING_ALLOWED=NO

unit_result="$result_directory/Unit.xcresult"
echo "Running unit tests."
run_timed_command 600 \
  xcodebuild -quiet test-without-building \
    -project Syntholo.xcodeproj \
    -scheme Syntholo \
    -destination "$destination" \
    -derivedDataPath DerivedData \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    -resultBundlePath "$unit_result" \
    -only-testing:SyntholoTests
assert_test_result "$unit_result" 245 unit-tests

ui_audit_simulator_udid=$(simulator_udid_from_result_bundle "$unit_result")
ui_audit_destination="platform=iOS Simulator,id=$ui_audit_simulator_udid"

functional_ui_groups=(
  "AppShellUITests:2"
  "CurriculumUITests:10"
  "OnboardingUITests:17"
)
functional_ui_total=0
echo "Running functional UI tests in isolated class sessions."
for functional_ui_group in "${functional_ui_groups[@]}"; do
  functional_ui_class=${functional_ui_group%%:*}
  functional_ui_expected_count=${functional_ui_group##*:}
  functional_ui_label="functional-$functional_ui_class"
  functional_ui_result="$result_directory/${functional_ui_label}.xcresult"
  echo "Running functional UI class: $functional_ui_class."
  run_ui_test_with_retry \
    600 \
    "$functional_ui_result" \
    "SyntholoUITests/$functional_ui_class" \
    "$functional_ui_expected_count" \
    "$functional_ui_label"
  assert_test_result \
    "$functional_ui_result" \
    "$functional_ui_expected_count" \
    "$functional_ui_label" \
    1
  functional_ui_total=$((functional_ui_total + functional_ui_expected_count))
done
if [[ "$functional_ui_total" -ne 29 ]]; then
  echo "Functional UI partition expected 29 tests, found $functional_ui_total." >&2
  exit 1
fi
echo "functional-ui-tests: 29 passed, 0 failed, 0 skipped."

if [[ "${SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT:-0}" == "1" ]]; then
  echo "Skipping accessibility audits by explicit diagnostic request."
else
  shell_accessibility_tests=(
    testLearnContrastAudit
    testLearnElementDetectionAudit
    testLearnHitRegionAudit
    testLearnSufficientElementDescriptionAudit
    testLearnDynamicTypeAudit
    testLearnTextClippedAudit
    testLearnTraitAudit
    testPracticeContrastAudit
    testPracticeElementDetectionAudit
    testPracticeHitRegionAudit
    testPracticeSufficientElementDescriptionAudit
    testPracticeDynamicTypeAudit
    testPracticeTextClippedAudit
    testPracticeTraitAudit
    testSocialContrastAudit
    testSocialElementDetectionAudit
    testSocialHitRegionAudit
    testSocialSufficientElementDescriptionAudit
    testSocialDynamicTypeAudit
    testSocialTextClippedAudit
    testSocialTraitAudit
    testProfileContrastAudit
    testProfileElementDetectionAudit
    testProfileHitRegionAudit
    testProfileSufficientElementDescriptionAudit
    testProfileDynamicTypeAudit
    testProfileTextClippedAudit
    testProfileTraitAudit
  )
  echo "Running 28 AppShell accessibility audits in isolated Xcode sessions."
  for shell_accessibility_test in "${shell_accessibility_tests[@]}"; do
    if [[ "$shell_accessibility_test" == *ContrastAudit ]]; then
      reboot_ui_audit_simulator "$ui_audit_simulator_udid"
    fi
    shell_accessibility_result="$result_directory/${shell_accessibility_test}.xcresult"
    echo "Running isolated AppShell audit: $shell_accessibility_test."
    run_ui_test_with_retry \
      180 \
      "$shell_accessibility_result" \
      "SyntholoUITests/AccessibilityAuditUITests/$shell_accessibility_test"
    assert_test_result "$shell_accessibility_result" 1 "$shell_accessibility_test"
  done
  echo "shell-accessibility-tests: 28 passed, 0 failed, 0 skipped."

  curriculum_accessibility_tests=(
    testCatalogContrastAudit
    testCatalogElementDetectionAudit
    testCatalogHitRegionAudit
    testCatalogSufficientElementDescriptionAudit
    testCatalogTextClippedAudit
    testCatalogTraitAudit
    testCatalogAccessibility5TextLayoutAudit
    testPreviewContrastAudit
    testPreviewElementDetectionAudit
    testPreviewHitRegionAudit
    testPreviewSufficientElementDescriptionAudit
    testPreviewTextClippedAudit
    testPreviewTraitAudit
    testPreviewAccessibility5TextLayoutAudit
  )
  echo "Running 14 curriculum accessibility audits in isolated Xcode sessions."
  for curriculum_accessibility_test in "${curriculum_accessibility_tests[@]}"; do
    if [[ "$curriculum_accessibility_test" == *ContrastAudit ]]; then
      reboot_ui_audit_simulator "$ui_audit_simulator_udid"
    fi
    curriculum_accessibility_result="$result_directory/${curriculum_accessibility_test}.xcresult"
    echo "Running isolated curriculum audit: $curriculum_accessibility_test."
    run_ui_test_with_retry \
      300 \
      "$curriculum_accessibility_result" \
      "SyntholoUITests/CurriculumAccessibilityAuditUITests/$curriculum_accessibility_test"
    assert_test_result \
      "$curriculum_accessibility_result" \
      1 \
      "$curriculum_accessibility_test"
  done
  echo "curriculum-accessibility-tests: 14 passed, 0 failed, 0 skipped."

  onboarding_accessibility_result="$result_directory/OnboardingAccessibility.xcresult"
  reboot_ui_audit_simulator "$ui_audit_simulator_udid"
  echo "Running onboarding accessibility audit tests sequentially."
  run_ui_test_with_retry \
    420 \
    "$onboarding_accessibility_result" \
    SyntholoUITests/OnboardingAccessibilityAuditUITests \
    12 \
    onboarding-accessibility-tests
  assert_test_result "$onboarding_accessibility_result" 12 onboarding-accessibility-tests
fi

run_timed_command 300 ./scripts/test_firebase_rules.sh
test_run_completed=1
