#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/.." && pwd)
cd "$repository_root"

./scripts/test_content.sh
./scripts/run_with_timeout.sh 300 ./scripts/test_content_publication.sh
./scripts/bootstrap.sh
./tests/scripts/test_run_with_timeout.sh
./tests/scripts/test_accessibility_audit_retry.sh
./tests/scripts/test_result_assertions.sh
./tests/scripts/test_ci_configuration.sh
./scripts/run_with_timeout.sh 600 ./scripts/test_environment_configuration.sh

destination=${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}
result_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-test-results.XXXXXX")
trap 'rm -rf "$result_directory"' EXIT

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
            console.error("Expected one iOS Simulator device in the functional UI result.");
            process.exit(1);
          }
          process.stdout.write(uniqueIDs[0]);
        });
      '
}

reboot_ui_audit_simulator() {
  local simulator_udid=$1
  echo "Rebooting simulator $simulator_udid before the next accessibility audit group."
  ./scripts/run_with_timeout.sh 120 \
    xcrun simctl bootstatus "$simulator_udid" -b >/dev/null \
    || return $?
  ./scripts/run_with_timeout.sh 60 \
    xcrun simctl shutdown "$simulator_udid" >/dev/null \
    || return $?
  ./scripts/run_with_timeout.sh 120 \
    xcrun simctl bootstatus "$simulator_udid" -b >/dev/null \
    || return $?
}

run_accessibility_audit_with_retry() {
  local timeout_seconds=$1
  local result_bundle=$2
  local test_identifier=$3
  local attempt
  local command_status
  local result_name

  case "$result_bundle" in
    "$result_directory"/*.xcresult)
      result_name=${result_bundle#"$result_directory"/}
      ;;
    *)
      echo "Refusing to manage an accessibility result outside $result_directory." >&2
      return 64
      ;;
  esac
  if [[ "$result_name" == */* ]]; then
    echo "Refusing to manage a nested accessibility result: $result_name." >&2
    return 64
  fi

  for attempt in 1 2; do
    if ./scripts/run_with_timeout.sh "$timeout_seconds" \
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

    if [[ "$command_status" -ne 124 || "$attempt" -eq 2 ]]; then
      return "$command_status"
    fi

    echo "Accessibility audit $test_identifier timed out; rebooting the simulator before retry 2 of 2."
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

echo "Building all test targets for $destination."
./scripts/run_with_timeout.sh 600 \
  xcodebuild -quiet build-for-testing \
    -project Syntholo.xcodeproj \
    -scheme Syntholo \
    -destination "$destination" \
    -derivedDataPath DerivedData \
    CODE_SIGNING_ALLOWED=NO

unit_result="$result_directory/Unit.xcresult"
echo "Running unit tests."
./scripts/run_with_timeout.sh 600 \
  xcodebuild -quiet test-without-building \
    -project Syntholo.xcodeproj \
    -scheme Syntholo \
    -destination "$destination" \
    -derivedDataPath DerivedData \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    -resultBundlePath "$unit_result" \
    -only-testing:SyntholoTests
assert_test_result "$unit_result" 232 unit-tests

functional_ui_result="$result_directory/FunctionalUI.xcresult"
echo "Running functional UI tests."
functional_ui_command_status=0
./scripts/run_with_timeout.sh 600 \
  xcodebuild -quiet test-without-building \
    -project Syntholo.xcodeproj \
    -scheme Syntholo \
    -destination "$destination" \
    -derivedDataPath DerivedData \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    -resultBundlePath "$functional_ui_result" \
    -only-testing:SyntholoUITests \
    -skip-testing:SyntholoUITests/AccessibilityAuditUITests \
    -skip-testing:SyntholoUITests/OnboardingAccessibilityAuditUITests \
    -skip-testing:SyntholoUITests/CurriculumAccessibilityAuditUITests \
  || functional_ui_command_status=$?

functional_ui_assertion_status=0
if [[ -d "$functional_ui_result" ]]; then
  assert_test_result "$functional_ui_result" 28 functional-ui-tests 1 \
    || functional_ui_assertion_status=$?
else
  echo "functional-ui-tests did not produce an xcresult bundle." >&2
  functional_ui_assertion_status=1
fi

if [[ "$functional_ui_command_status" -ne 0 ]]; then
  exit "$functional_ui_command_status"
fi
if [[ "$functional_ui_assertion_status" -ne 0 ]]; then
  exit "$functional_ui_assertion_status"
fi

if [[ "${SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT:-0}" == "1" ]]; then
  echo "Skipping accessibility audits by explicit diagnostic request."
else
  ui_audit_simulator_udid=$(simulator_udid_from_result_bundle "$functional_ui_result")
  ui_audit_destination="platform=iOS Simulator,id=$ui_audit_simulator_udid"
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
    run_accessibility_audit_with_retry \
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
    run_accessibility_audit_with_retry \
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
  ./scripts/run_with_timeout.sh 420 \
    xcodebuild -quiet test-without-building \
      -project Syntholo.xcodeproj \
      -scheme Syntholo \
      -destination "$ui_audit_destination" \
      -derivedDataPath DerivedData \
      -parallel-testing-enabled NO \
      CODE_SIGNING_ALLOWED=NO \
      -resultBundlePath "$onboarding_accessibility_result" \
      -only-testing:SyntholoUITests/OnboardingAccessibilityAuditUITests
  assert_test_result "$onboarding_accessibility_result" 11 onboarding-accessibility-tests
fi

./scripts/run_with_timeout.sh 300 ./scripts/test_firebase_rules.sh
