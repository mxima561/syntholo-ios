#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/.." && pwd)
cd "$repository_root"

if [[ ! -f package.json || ! -f package-lock.json ]]; then
  echo "package.json and package-lock.json are required for content tests." >&2
  exit 1
fi

node_major=$(node -p 'process.versions.node.split(".")[0]')
if [[ "$node_major" != "22" ]]; then
  echo "Node 22 is required; found $(node --version)." >&2
  exit 1
fi

node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const expected = {
  ajv: "8.20.0",
  "ajv-formats": "3.0.1",
  "firebase-admin": "14.3.0",
  "json-canonicalize": "3.0.0",
};
const manifest = require("./package.json");
const lock = require("./package-lock.json");

for (const [name, version] of Object.entries(expected)) {
  const installedPath = path.join("node_modules", name, "package.json");
  if (!fs.existsSync(installedPath)) {
    console.error(`Missing pinned content dependency ${name}. Run: npm ci`);
    process.exit(1);
  }
  const installed = JSON.parse(fs.readFileSync(installedPath, "utf8")).version;
  const declared = manifest.devDependencies?.[name];
  const locked = lock.packages?.[`node_modules/${name}`]?.version;
  if (declared !== version || locked !== version || installed !== version) {
    console.error(
      `${name} version mismatch: expected=${version} package=${declared} lock=${locked} local=${installed}`,
    );
    process.exit(1);
  }
}
NODE

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-content-tests.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

node ./tools/content/validate.mjs \
  ./tests/fixtures/content/minimal-curriculum-v1.json

content_output="$temporary_directory/content-tests.tap.log"
node --test --test-reporter=tap \
  ./tests/content/curriculum-validation.test.mjs \
  > "$content_output" 2>&1
/usr/bin/sed -n 'p' "$content_output"
node ./scripts/assert_tap_summary.mjs 73 curriculum-content-tests \
  < "$content_output"

operator_output="$temporary_directory/operator-identity-tests.tap.log"
node --test --test-reporter=tap \
  ./tests/content/operator-identity.test.mjs \
  > "$operator_output" 2>&1
/usr/bin/sed -n 'p' "$operator_output"
node ./scripts/assert_tap_summary.mjs 32 curriculum-operator-identity-tests \
  < "$operator_output"

./tests/scripts/test_secret_scan.sh
./scripts/scan_secrets.sh --history --worktree

tracked_sensitive_files=$(git ls-files \
  '*service-account*.json' \
  '*GoogleService-Info.plist' \
  '*.firebase.plist' \
  'Config/Firebase.local.xcconfig')
if [[ -n "$tracked_sensitive_files" ]]; then
  echo "Sensitive deployment configuration is tracked:" >&2
  echo "$tracked_sensitive_files" >&2
  exit 1
fi

echo "content-gate: schema, graph, digest, budget, operator identity, CLI, dependency, and secret-scan checks passed."
