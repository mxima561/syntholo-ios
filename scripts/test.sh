#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/.." && pwd)
cd "$repository_root"

./scripts/bootstrap.sh
./tests/scripts/test_run_with_timeout.sh
./tests/scripts/test_result_assertions.sh
./tests/scripts/test_ci_configuration.sh
./scripts/run_with_timeout.sh 600 ./scripts/test_environment_configuration.sh

destination=${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}
result_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-test-results.XXXXXX")
trap 'rm -rf "$result_directory"' EXIT

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
assert_test_result "$unit_result" 98 unit-tests

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
  || functional_ui_command_status=$?

functional_ui_assertion_status=0
if [[ -d "$functional_ui_result" ]]; then
  assert_test_result "$functional_ui_result" 16 functional-ui-tests 1 \
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
  shell_accessibility_result="$result_directory/ShellAccessibility.xcresult"
  echo "Running AppShell accessibility audit tests sequentially."
  ./scripts/run_with_timeout.sh 600 \
    xcodebuild -quiet test-without-building \
      -project Syntholo.xcodeproj \
      -scheme Syntholo \
      -destination "$destination" \
      -derivedDataPath DerivedData \
      -parallel-testing-enabled NO \
      CODE_SIGNING_ALLOWED=NO \
      -resultBundlePath "$shell_accessibility_result" \
      -only-testing:SyntholoUITests/AccessibilityAuditUITests
  assert_test_result "$shell_accessibility_result" 28 shell-accessibility-tests

  onboarding_accessibility_result="$result_directory/OnboardingAccessibility.xcresult"
  echo "Running onboarding accessibility audit tests sequentially."
  ./scripts/run_with_timeout.sh 420 \
    xcodebuild -quiet test-without-building \
      -project Syntholo.xcodeproj \
      -scheme Syntholo \
      -destination "$destination" \
      -derivedDataPath DerivedData \
      -parallel-testing-enabled NO \
      CODE_SIGNING_ALLOWED=NO \
      -resultBundlePath "$onboarding_accessibility_result" \
      -only-testing:SyntholoUITests/OnboardingAccessibilityAuditUITests
  assert_test_result "$onboarding_accessibility_result" 10 onboarding-accessibility-tests
fi

./scripts/run_with_timeout.sh 300 ./scripts/test_firebase_rules.sh
