#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
default_repository_root=$(cd "$script_directory/.." && pwd)
requested_repository_root=${SYNTHOLO_SECRET_SCAN_ROOT:-$default_repository_root}
if [[ ! -d "$requested_repository_root" ]]; then
  echo "Secret-scan repository root does not exist: $requested_repository_root" >&2
  exit 66
fi
repository_root=$(cd "$requested_repository_root" && pwd)
readonly gitleaks_config="$script_directory/gitleaks.toml"
# shellcheck source=gitleaks-version.sh
source "$script_directory/gitleaks-version.sh"
readonly expected_gitleaks_version="$SYNTHOLO_GITLEAKS_VERSION"
readonly gitleaks_binary="$default_repository_root/.tools/gitleaks/$expected_gitleaks_version/gitleaks"

show_usage() {
  echo "Usage: ./scripts/scan_secrets.sh [--history] [--worktree] [--generated <path>] [--bundle <path>]" >&2
}

operating_system=$(/usr/bin/uname -s)
if [[ "$operating_system" != "Darwin" ]]; then
  echo "Pinned gitleaks scanning supports macOS only; found: $operating_system" >&2
  exit 69
fi

machine_architecture=$(/usr/bin/uname -m)
case "$machine_architecture" in
  arm64)
    expected_gitleaks_sha256="$SYNTHOLO_GITLEAKS_DARWIN_ARM64_BINARY_SHA256"
    ;;
  x86_64)
    expected_gitleaks_sha256="$SYNTHOLO_GITLEAKS_DARWIN_X64_BINARY_SHA256"
    ;;
  *)
    echo "Unsupported macOS architecture for pinned gitleaks: $machine_architecture" >&2
    exit 69
    ;;
esac

if [[ ! -x "$gitleaks_binary" ]]; then
  echo "Pinned gitleaks $expected_gitleaks_version is required; run: ./scripts/install_gitleaks.sh" >&2
  exit 69
fi

actual_gitleaks_sha256=$(
  /usr/bin/shasum -a 256 "$gitleaks_binary" | /usr/bin/awk '{print $1}'
)
if [[ "$actual_gitleaks_sha256" != "$expected_gitleaks_sha256" ]]; then
  echo "Pinned gitleaks binary checksum mismatch; rerun: ./scripts/install_gitleaks.sh" >&2
  exit 69
fi

actual_gitleaks_version=$(
  "$gitleaks_binary" version 2>/dev/null \
    | /usr/bin/tr -d '[:space:]' \
    | /usr/bin/sed 's/^v//'
)
if [[ "$actual_gitleaks_version" != "$expected_gitleaks_version" ]]; then
  echo "Expected gitleaks $expected_gitleaks_version, found $actual_gitleaks_version." >&2
  exit 69
fi

scan_history=0
scan_worktree=0
declare -a generated_paths=()
declare -a bundle_paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --history)
      scan_history=1
      shift
      ;;
    --worktree)
      scan_worktree=1
      shift
      ;;
    --generated|--bundle)
      option=$1
      if [[ $# -lt 2 || -z "$2" ]]; then
        show_usage
        exit 64
      fi
      if [[ "$option" == "--generated" ]]; then
        generated_paths+=("$2")
      else
        bundle_paths+=("$2")
      fi
      shift 2
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    *)
      show_usage
      exit 64
      ;;
  esac
done

if [[ "$scan_history" -eq 0 && "$scan_worktree" -eq 0 \
      && "${#generated_paths[@]}" -eq 0 && "${#bundle_paths[@]}" -eq 0 ]]; then
  show_usage
  exit 64
fi

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-secret-scan.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT
empty_ignore_path="$temporary_directory/empty.gitleaksignore"
: > "$empty_ignore_path"

run_directory_scan() {
  local label=$1
  local target=$2
  local report_path="$temporary_directory/${label}.json"

  if [[ ! -e "$target" ]]; then
    echo "$label target does not exist: $target" >&2
    return 66
  fi

  echo "Scanning $label with gitleaks $expected_gitleaks_version."
  "$gitleaks_binary" dir "$target" \
    --config "$gitleaks_config" \
    --gitleaks-ignore-path "$empty_ignore_path" \
    --ignore-gitleaks-allow \
    --no-banner \
    --redact=100 \
    --report-format json \
    --report-path "$report_path"
}

run_bundle_extracted_scan() {
  local label=$1
  local target=$2
  local file_list="$temporary_directory/${label}-files.zlist"
  local symlink_list="$temporary_directory/${label}-symlinks.zlist"
  local corpus_path="$temporary_directory/${label}-extracted.txt"
  local extracted_file_count=0
  local file_path

  if [[ ! -x /usr/bin/strings || ! -x /usr/bin/plutil ]]; then
    echo "Bundle scanning requires macOS /usr/bin/strings and /usr/bin/plutil." >&2
    return 69
  fi

  find "$target" -type l -print0 > "$symlink_list"
  if [[ -s "$symlink_list" ]]; then
    echo "$label target contains unsupported symbolic links; scan a resolved bundle." >&2
    return 65
  fi

  find "$target" -type f -print0 > "$file_list"
  : > "$corpus_path"
  while IFS= read -r -d '' file_path; do
    extracted_file_count=$((extracted_file_count + 1))
    /usr/bin/strings -a -- "$file_path" >> "$corpus_path"
    printf '\n' >> "$corpus_path"

    if [[ "$file_path" == *.plist ]]; then
      /usr/bin/plutil -convert xml1 -o - -- "$file_path" >> "$corpus_path"
      printf '\n' >> "$corpus_path"
    fi
  done < "$file_list"

  if [[ "$extracted_file_count" -eq 0 ]]; then
    echo "$label target contains no regular files: $target" >&2
    return 66
  fi

  run_directory_scan "$label-extracted" "$corpus_path"
}

cd "$repository_root"

if [[ "$scan_history" -eq 1 ]]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "History scanning requires a Git worktree." >&2
    exit 69
  fi
  if [[ "$(git rev-parse --is-shallow-repository)" != "false" ]]; then
    echo "Complete history scanning requires a non-shallow Git clone." >&2
    exit 69
  fi
  echo "Scanning complete Git history with gitleaks $expected_gitleaks_version."
  "$gitleaks_binary" git "$repository_root" \
    --config "$gitleaks_config" \
    --gitleaks-ignore-path "$empty_ignore_path" \
    --ignore-gitleaks-allow \
    --log-opts="--all" \
    --no-banner \
    --redact=100 \
    --report-format json \
    --report-path "$temporary_directory/history.json"
fi

if [[ "$scan_worktree" -eq 1 ]]; then
  if ! git -C "$repository_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Worktree scanning requires a Git worktree." >&2
    exit 69
  fi
  worktree_snapshot="$temporary_directory/worktree"
  worktree_file_list="$temporary_directory/worktree-files.zlist"
  mkdir -p "$worktree_snapshot"
  find "$repository_root" \
    \( -type d \( \
      -name .git -o \
      -name node_modules -o \
      -name DerivedData -o \
      -name .build \
    \) \) -prune -o \
    \( -path "$repository_root/.worktrees" -o \
       -path "$repository_root/.tools/gitleaks" \
    \) -prune -o \
    -type f -print0 > "$worktree_file_list"
  while IFS= read -r -d '' source_path; do
    relative_path=${source_path#"$repository_root"/}
    snapshot_path="$worktree_snapshot/$relative_path"
    mkdir -p "$(dirname "$snapshot_path")"
    cp "$source_path" "$snapshot_path"
  done < "$worktree_file_list"
  run_directory_scan "worktree" "$worktree_snapshot"
fi

generated_index=0
if [[ "${#generated_paths[@]}" -gt 0 ]]; then
  for generated_path in "${generated_paths[@]}"; do
    run_directory_scan "generated-$generated_index" "$generated_path"
    generated_index=$((generated_index + 1))
  done
fi

bundle_index=0
if [[ "${#bundle_paths[@]}" -gt 0 ]]; then
  for bundle_path in "${bundle_paths[@]}"; do
    run_directory_scan "bundle-$bundle_index" "$bundle_path"
    run_bundle_extracted_scan "bundle-$bundle_index" "$bundle_path"
    bundle_index=$((bundle_index + 1))
  done
fi

echo "secret-scan: requested scopes passed with gitleaks $expected_gitleaks_version."
