#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/../.." && pwd)
scanner="$repository_root/scripts/scan_secrets.sh"
# shellcheck source=../../scripts/gitleaks-version.sh
source "$repository_root/scripts/gitleaks-version.sh"
gitleaks_binary="$repository_root/.tools/gitleaks/$SYNTHOLO_GITLEAKS_VERSION/gitleaks"
if [[ ! -x "$gitleaks_binary" ]]; then
  echo "Pinned gitleaks is missing. Run: ./scripts/install_gitleaks.sh" >&2
  exit 1
fi
test_root=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-secret-scan-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT
empty_ignore_path="$test_root/empty.gitleaksignore"
: > "$empty_ignore_path"

plant_credential_fixture() {
  local target=$1
  local access_key
  local secret_key
  local attempt
  for attempt in {1..20}; do
    access_key="AKIA$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')"
    secret_key=$(openssl rand -base64 30 | tr -d '\n' | cut -c1-40)
    printf 'AWS_ACCESS_KEY_ID=%s\nAWS_SECRET_ACCESS_KEY=%s\n' \
      "$access_key" "$secret_key" > "$target"
    if ! "$gitleaks_binary" dir "$(dirname "$target")" \
      --no-banner --redact=100 >/dev/null 2>&1; then
      return
    fi
  done
  echo "Could not construct a planted credential recognized by the pinned scanner." >&2
  exit 1
}

plant_compiled_credential_fixture() {
  local target=$1
  local extracted_strings="$test_root/compiled-fixture-strings.txt"
  local compiler_log="$test_root/compiled-fixture-clang.log"
  local access_key
  local secret_key
  local attempt

  if ! xcrun --find clang >/dev/null 2>&1; then
    echo "Xcode clang is required for the app-bundle secret-scan regression." >&2
    exit 1
  fi

  for attempt in {1..20}; do
    access_key="AKIA$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')"
    secret_key=$(openssl rand -base64 30 | tr -d '\n' | cut -c1-40)
    printf '#include <stdio.h>\nint main(void) { puts("AWS_ACCESS_KEY_ID=%s\\nAWS_SECRET_ACCESS_KEY=%s"); return 0; }\n' \
      "$access_key" "$secret_key" \
      | xcrun clang -x c - -o "$target" 2> "$compiler_log"
    /usr/bin/strings -a -- "$target" > "$extracted_strings"
    if ! "$gitleaks_binary" stdin \
      --config "$repository_root/scripts/gitleaks.toml" \
      --gitleaks-ignore-path "$empty_ignore_path" \
      --ignore-gitleaks-allow \
      --no-banner \
      --redact=100 \
      < "$extracted_strings" >/dev/null 2>&1; then
      : > "$extracted_strings"
      return
    fi
  done
  echo "Could not compile a planted credential recognized after string extraction." >&2
  exit 1
}

plant_binary_plist_credential_fixture() {
  local target=$1
  local source_plist="$test_root/binary-plist-fixture.xml"
  local normalized_plist="$test_root/binary-plist-fixture-normalized.xml"
  local access_key
  local secret_key
  local attempt

  for attempt in {1..20}; do
    access_key="AKIA$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')"
    secret_key=$(openssl rand -base64 30 | tr -d '\n' | cut -c1-40)
    printf '%s\n' \
      '<?xml version="1.0" encoding="UTF-8"?>' \
      '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
      '<plist version="1.0"><dict>' \
      '<key>CredentialFixture</key>' \
      "<string>fixture&#10;AWS_ACCESS_KEY_ID=$access_key&#10;AWS_SECRET_ACCESS_KEY=$secret_key&#10;</string>" \
      '</dict></plist>' > "$source_plist"
    /usr/bin/plutil -convert binary1 -o "$target" -- "$source_plist"
    /usr/bin/plutil -convert xml1 -o "$normalized_plist" -- "$target"
    if ! "$gitleaks_binary" dir "$normalized_plist" \
      --config "$repository_root/scripts/gitleaks.toml" \
      --gitleaks-ignore-path "$empty_ignore_path" \
      --ignore-gitleaks-allow \
      --no-banner \
      --redact=100 >/dev/null 2>&1; then
      : > "$source_plist"
      : > "$normalized_plist"
      return
    fi
  done
  echo "Could not build a binary plist credential recognized after normalization." >&2
  exit 1
}

annotate_credential_fixture() {
  local target=$1
  local annotated_target="$target.annotated"
  while IFS= read -r credential_line; do
    printf '%s # gitleaks:allow\n' "$credential_line"
  done < "$target" > "$annotated_target"
  mv "$annotated_target" "$target"
}

assert_exit_status() {
  local label=$1
  local expected_status=$2
  shift 2
  local status
  set +e
  "$@" > "$test_root/$label.log" 2>&1
  status=$?
  set -e
  if [[ "$status" -ne "$expected_status" ]]; then
    echo "Expected $label to exit $expected_status; found $status." >&2
    exit 1
  fi
}

assert_detects() {
  local label=$1
  shift
  assert_exit_status "$label" 1 "$@"
}

clean_generated="$test_root/clean-generated"
mkdir -p "$clean_generated"
printf '%s\n' 'synthetic output without credentials' > "$clean_generated/result.txt"
"$scanner" --generated "$clean_generated" >/dev/null

generated_fixture="$test_root/generated"
annotation_fixture="$test_root/annotated-generated"
bundle_fixture="$test_root/Syntholo.app"
plist_bundle_fixture="$test_root/PlistFixture.app"
symlink_bundle_fixture="$test_root/SymlinkFixture.app"
mkdir -p \
  "$generated_fixture" \
  "$annotation_fixture" \
  "$bundle_fixture" \
  "$plist_bundle_fixture" \
  "$symlink_bundle_fixture"
plant_credential_fixture "$generated_fixture/generated.env"
plant_credential_fixture "$annotation_fixture/annotated.env"
annotate_credential_fixture "$annotation_fixture/annotated.env"
plant_compiled_credential_fixture "$bundle_fixture/SyntholoBinary"
plant_binary_plist_credential_fixture "$plist_bundle_fixture/Info.plist"
printf '%s\n' 'clean bundle fixture' > "$symlink_bundle_fixture/payload.txt"
ln -s payload.txt "$symlink_bundle_fixture/payload-link.txt"
printf '%s\n' '[allowlist]' 'paths = [".*"]' > "$generated_fixture/.gitleaks.toml"
assert_detects generated "$scanner" --generated "$generated_fixture"
assert_detects annotations "$scanner" --generated "$annotation_fixture"
assert_detects bundle "$scanner" --bundle "$bundle_fixture"
assert_detects bundle-plist "$scanner" --bundle "$plist_bundle_fixture"
assert_exit_status bundle-symlink 65 \
  "$scanner" --bundle "$symlink_bundle_fixture"

worktree_fixture="$test_root/worktree-repository"
mkdir -p "$worktree_fixture"
git -C "$worktree_fixture" init -q
plant_credential_fixture "$worktree_fixture/untracked.env"
assert_detects worktree env SYNTHOLO_SECRET_SCAN_ROOT="$worktree_fixture" \
  "$scanner" --worktree

ignored_worktree_fixture="$test_root/ignored-worktree-repository"
mkdir -p "$ignored_worktree_fixture"
git -C "$ignored_worktree_fixture" init -q
printf '%s\n' 'ignored.env' > "$ignored_worktree_fixture/.gitignore"
plant_credential_fixture "$ignored_worktree_fixture/ignored.env"
assert_detects ignored-worktree env \
  SYNTHOLO_SECRET_SCAN_ROOT="$ignored_worktree_fixture" \
  "$scanner" --worktree

non_git_fixture="$test_root/non-git-directory"
mkdir -p "$non_git_fixture"
assert_exit_status non-git-worktree 69 \
  env SYNTHOLO_SECRET_SCAN_ROOT="$non_git_fixture" \
  "$scanner" --worktree

history_fixture="$test_root/history-repository"
mkdir -p "$history_fixture"
git -C "$history_fixture" init -q
git -C "$history_fixture" config user.name "Syntholo Secret Scan Test"
git -C "$history_fixture" config user.email "secret-scan-test@example.invalid"
plant_credential_fixture "$history_fixture/committed.env"
git -C "$history_fixture" add committed.env
git -C "$history_fixture" commit -q -m "test fixture"
git -C "$history_fixture" rm -q committed.env
git -C "$history_fixture" commit -q -m "remove test fixture"
assert_detects history env SYNTHOLO_SECRET_SCAN_ROOT="$history_fixture" \
  "$scanner" --history

shallow_history_fixture="$test_root/shallow-history-repository"
git clone -q --depth 1 "file://$history_fixture" "$shallow_history_fixture"
assert_exit_status shallow-history 69 \
  env SYNTHOLO_SECRET_SCAN_ROOT="$shallow_history_fixture" \
  "$scanner" --history

echo "secret-scan-tests: clean scope passed; exact failure codes, suppression resistance, ignored worktree coverage, deleted history, shallow-clone rejection, compiled-bundle extraction, and binary-plist normalization passed."
