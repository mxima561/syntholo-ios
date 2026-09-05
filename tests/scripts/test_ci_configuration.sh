#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
workflow="$repository_root/.github/workflows/ios.yml"
test_script="$repository_root/scripts/test.sh"
minimum_timeout_minutes=90

job_block() {
  local job_name=$1

  awk -v job="$job_name" '
    $0 == "  " job ":" { in_job = 1 }
    in_job && /^  [[:alnum:]_-]+:$/ && $0 != "  " job ":" { exit }
    in_job { print }
  ' "$workflow"
}

assert_job_contract() {
  local job_name=$1
  local block
  local timeout_minutes

  block=$(job_block "$job_name")
  [[ -n "$block" ]] || {
    echo "Missing CI job: $job_name" >&2
    exit 1
  }

  timeout_minutes=$(
    awk '/^    timeout-minutes:[[:space:]]*[0-9]+[[:space:]]*$/ { print $2 }' <<< "$block"
  )
  if [[ ! "$timeout_minutes" =~ ^[0-9]+$ ]] \
    || (( timeout_minutes < minimum_timeout_minutes )); then
    echo "$job_name must allow at least $minimum_timeout_minutes minutes for the canonical gate." >&2
    exit 1
  fi

  for expected_line in \
    'java-version: "21.0.12+8.0.LTS"' \
    'uses: actions/checkout@v5' \
    'fetch-depth: 0' \
    'uses: actions/setup-node@v5' \
    'node-version: 22.22.2' \
    'uses: actions/setup-java@v5' \
    './scripts/install_gitleaks.sh' \
    'test "$(./node_modules/.bin/firebase --version)" = "15.28.1"' \
    'run: ./scripts/test.sh'; do
    if ! grep -Fq -- "$expected_line" <<< "$block"; then
      echo "$job_name is missing required CI contract: $expected_line" >&2
      exit 1
    fi
  done
}

assert_job_contract test
assert_job_contract test-ios-17

for functional_group in \
  'AppShellUITests:2' \
  'CurriculumUITests:10' \
  'OnboardingUITests:16'; do
  if ! grep -Fq -- "\"$functional_group\"" "$test_script"; then
    echo "The canonical gate is missing functional UI partition: $functional_group" >&2
    exit 1
  fi
done

echo "ci-configuration-tests: both jobs use available exact toolchains and the partitioned canonical gate."
