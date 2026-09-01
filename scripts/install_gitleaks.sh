#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/.." && pwd)
# shellcheck source=gitleaks-version.sh
source "$script_directory/gitleaks-version.sh"

operating_system=$(/usr/bin/uname -s)
if [[ "$operating_system" != "Darwin" ]]; then
  echo "Pinned gitleaks installation supports macOS only; found: $operating_system" >&2
  exit 69
fi

machine_architecture=$(/usr/bin/uname -m)
case "$machine_architecture" in
  arm64)
    release_architecture="arm64"
    archive_sha256="$SYNTHOLO_GITLEAKS_DARWIN_ARM64_ARCHIVE_SHA256"
    binary_sha256="$SYNTHOLO_GITLEAKS_DARWIN_ARM64_BINARY_SHA256"
    ;;
  x86_64)
    release_architecture="x64"
    archive_sha256="$SYNTHOLO_GITLEAKS_DARWIN_X64_ARCHIVE_SHA256"
    binary_sha256="$SYNTHOLO_GITLEAKS_DARWIN_X64_BINARY_SHA256"
    ;;
  *)
    echo "Unsupported macOS architecture for pinned gitleaks: $machine_architecture" >&2
    exit 69
    ;;
esac

tool_directory="$repository_root/.tools/gitleaks/$SYNTHOLO_GITLEAKS_VERSION"
gitleaks_binary="$tool_directory/gitleaks"

sha256_of() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

if [[ -x "$gitleaks_binary" \
      && "$(sha256_of "$gitleaks_binary")" == "$binary_sha256" \
      && "$($gitleaks_binary version 2>/dev/null | /usr/bin/tr -d '[:space:]' | /usr/bin/sed 's/^v//')" == "$SYNTHOLO_GITLEAKS_VERSION" ]]; then
  echo "gitleaks $SYNTHOLO_GITLEAKS_VERSION is already installed from the verified $machine_architecture release."
  exit 0
fi

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-gitleaks-install.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT
archive_name="gitleaks_${SYNTHOLO_GITLEAKS_VERSION}_darwin_${release_architecture}.tar.gz"
archive_path="$temporary_directory/$archive_name"
extracted_directory="$temporary_directory/extracted"
release_url="https://github.com/gitleaks/gitleaks/releases/download/v${SYNTHOLO_GITLEAKS_VERSION}/$archive_name"

/bin/mkdir -p "$extracted_directory"
echo "Downloading pinned gitleaks $SYNTHOLO_GITLEAKS_VERSION for $machine_architecture."
/usr/bin/curl \
  --fail \
  --location \
  --proto '=https' \
  --tlsv1.2 \
  --retry 3 \
  --connect-timeout 20 \
  --max-time 120 \
  --output "$archive_path" \
  "$release_url"

actual_archive_sha256=$(sha256_of "$archive_path")
if [[ "$actual_archive_sha256" != "$archive_sha256" ]]; then
  echo "Pinned gitleaks archive checksum mismatch." >&2
  exit 65
fi

/usr/bin/tar -xzf "$archive_path" -C "$extracted_directory" gitleaks
actual_binary_sha256=$(sha256_of "$extracted_directory/gitleaks")
if [[ "$actual_binary_sha256" != "$binary_sha256" ]]; then
  echo "Pinned gitleaks binary checksum mismatch." >&2
  exit 65
fi

actual_version=$(
  "$extracted_directory/gitleaks" version 2>/dev/null \
    | /usr/bin/tr -d '[:space:]' \
    | /usr/bin/sed 's/^v//'
)
if [[ "$actual_version" != "$SYNTHOLO_GITLEAKS_VERSION" ]]; then
  echo "Pinned gitleaks version mismatch after extraction: $actual_version" >&2
  exit 65
fi

/bin/mkdir -p "$tool_directory"
/usr/bin/install -m 0755 "$extracted_directory/gitleaks" "$gitleaks_binary"
echo "Installed verified gitleaks $SYNTHOLO_GITLEAKS_VERSION at $gitleaks_binary."
