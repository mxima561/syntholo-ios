#!/usr/bin/env bash
set -euo pipefail

derived_data_path=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-environment-configuration.XXXXXX")
trap 'rm -rf "$derived_data_path"' EXIT

assert_environment() {
  local configuration=$1
  local expected_environment=$2
  local info_plist="$derived_data_path/Build/Products/${configuration}-iphoneos/Syntholo.app/Info.plist"
  local actual_environment

  xcodebuild build \
    -project Syntholo.xcodeproj \
    -scheme Syntholo \
    -configuration "$configuration" \
    -sdk iphoneos \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGNING_ALLOWED=NO

  actual_environment=$(/usr/libexec/PlistBuddy -c 'Print :SYNTHOLO_ENV' "$info_plist")
  if [[ "$actual_environment" != "$expected_environment" ]]; then
    echo "Expected $configuration Syntholo.app to bundle SYNTHOLO_ENV=$expected_environment, got $actual_environment." >&2
    exit 1
  fi

  [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist") == "com.syntholo.ios" ]]
  [[ $(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$info_plist") == "17.0" ]]
  [[ $(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily:0' "$info_plist") == "1" ]]
}

assert_environment Debug development
assert_environment Release production
