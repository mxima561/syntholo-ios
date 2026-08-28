#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/.." && pwd)
cd "$repository_root"

./scripts/bootstrap.sh
./tests/scripts/test_run_with_timeout.sh
./tests/scripts/test_result_assertions.sh
./scripts/run_with_timeout.sh 600 ./scripts/test_environment_configuration.sh

destination=${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}
result_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-test-results.XXXXXX")
trap 'rm -rf "$result_directory"' EXIT

assert_test_result() {
  local result_bundle=$1
  local expected_count=$2
  local label=$3

  xcrun xcresulttool get test-results summary \
    --path "$result_bundle" \
    | node ./scripts/assert_xcresult_summary.mjs "$expected_count" "$label"
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
./scripts/run_with_timeout.sh 300 \
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
    -skip-testing:SyntholoUITests/OnboardingAccessibilityAuditUITests
assert_test_result "$functional_ui_result" 16 functional-ui-tests

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
