#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
runner="$repository_root/scripts/run_with_timeout.sh"
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-watchdog-test.XXXXXX")

cleanup() {
  local process_id

  for process_file in "$temporary_directory"/*.pid; do
    [[ -f "$process_file" ]] || continue
    process_id=$(<"$process_file")
    kill -KILL "$process_id" 2>/dev/null || true
  done
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

parent_file="$temporary_directory/parent.pid"
child_file="$temporary_directory/child.pid"

set +e
SYNTHOLO_TIMEOUT_POLL_INTERVAL=0.05 \
SYNTHOLO_TIMEOUT_INTERRUPT_GRACE_SECONDS=0.1 \
SYNTHOLO_TIMEOUT_TERMINATE_GRACE_SECONDS=0.1 \
"$runner" 1 \
  /bin/bash -c '
    trap "" INT TERM
    printf "%s\n" "$BASHPID" > "$1"
    (
      trap "" INT TERM
      printf "%s\n" "$BASHPID" > "$2"
      while :; do sleep 0.1; done
    ) &
    wait
  ' _ "$parent_file" "$child_file"
timeout_status=$?
set -e

[[ "$timeout_status" -eq 124 ]]
[[ -s "$parent_file" && -s "$child_file" ]]

parent_pid=$(<"$parent_file")
child_pid=$(<"$child_file")
if kill -0 "$parent_pid" 2>/dev/null || kill -0 "$child_pid" 2>/dev/null; then
  echo "Watchdog left a timed-out process alive." >&2
  exit 1
fi

set +e
"$runner" 5 /bin/bash -c 'exit 7'
command_status=$?
set -e
[[ "$command_status" -eq 7 ]]

echo "watchdog-tests: process group timed out cleanly and exit status propagated."
