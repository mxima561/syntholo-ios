#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
workflow="$repository_root/.github/workflows/ios.yml"

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

  block=$(job_block "$job_name")
  [[ -n "$block" ]] || {
    echo "Missing CI job: $job_name" >&2
    exit 1
  }

  for expected_line in \
    'java-version: "21.0.12+8.0.LTS"' \
    'uses: actions/checkout@v5' \
    'uses: actions/setup-node@v5' \
    'node-version: 22.22.2' \
    'uses: actions/setup-java@v5' \
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

echo "ci-configuration-tests: both jobs use available exact toolchains and the canonical gate."
