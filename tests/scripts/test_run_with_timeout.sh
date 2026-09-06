#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
runner="$repository_root/scripts/run_with_timeout.sh"
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/syntholo-watchdog-test.XXXXXX")

cleanup() {
  local process_id

  for process_file in "$temporary_directory"/*.group-pid; do
    [[ -f "$process_file" ]] || continue
    process_id=$(<"$process_file")
    /bin/kill -KILL -- "-$process_id" 2>/dev/null || true
  done
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
    printf "%s\n" "$$" > "$1"
    /bin/bash -c '\''
      trap "" INT TERM
      printf "%s\n" "$$" > "$1"
      while :; do sleep 0.1; done
    '\'' _ "$2" &
    wait
  ' _ "$parent_file" "$child_file"
timeout_status=$?
set -e

[[ "$timeout_status" -eq 124 ]]
[[ -s "$parent_file" && -s "$child_file" ]]

parent_pid=$(<"$parent_file")
child_pid=$(<"$child_file")
[[ "$parent_pid" =~ ^[1-9][0-9]*$ && "$child_pid" =~ ^[1-9][0-9]*$ ]]
if kill -0 "$parent_pid" 2>/dev/null || kill -0 "$child_pid" 2>/dev/null; then
  echo "Watchdog left a timed-out process alive." >&2
  exit 1
fi

set +e
"$runner" 5 /bin/bash -c 'exit 7'
command_status=$?
set -e
[[ "$command_status" -eq 7 ]]

assert_signal_cleanup() {
  local signal_scope=$1
  local command_file="$temporary_directory/$signal_scope-command.group-pid"
  local wrapper_file="$temporary_directory/$signal_scope-wrapper.group-pid"
  local signal_file="$temporary_directory/$signal_scope-term-observed"
  local wrapper_pid
  local command_pid
  local watchdog_pid
  local wrapper_status
  local attempt

  # Both groups are real, separately owned sessions. The command acknowledges
  # TERM without exiting, exposing a second signal during escalation cleanup.
  SYNTHOLO_TIMEOUT_POLL_INTERVAL=5 \
  SYNTHOLO_TIMEOUT_INTERRUPT_GRACE_SECONDS=0.1 \
  SYNTHOLO_TIMEOUT_TERMINATE_GRACE_SECONDS=0.5 \
    perl -MPOSIX -e '
      POSIX::setsid() != -1 or die "setsid failed: $!\n";
      exec @ARGV;
      die "exec failed: $!\n";
    ' -- "$runner" 15 /bin/bash -c '
      trap "" INT
      trap '\''printf "received\n" > "$2"'\'' TERM
      printf "%s\n" "$$" > "$1"
      while :; do sleep 0.02; done
    ' _ "$command_file" "$signal_file" \
    > "$temporary_directory/$signal_scope.log" 2>&1 &
  wrapper_pid=$!
  printf '%s\n' "$wrapper_pid" > "$wrapper_file"

  for attempt in {1..150}; do
    [[ -s "$command_file" ]] && break
    sleep 0.02
  done
  [[ -s "$command_file" ]] || {
    echo "$signal_scope fixture did not start its command." >&2
    return 1
  }
  command_pid=$(<"$command_file")
  [[ "$command_pid" =~ ^[1-9][0-9]*$ ]] || {
    echo "$signal_scope fixture did not record a real process ID." >&2
    return 1
  }
  for attempt in {1..150}; do
    watchdog_pid=$(ps -axo pid=,ppid=,comm= | awk \
      -v owner="$wrapper_pid" -v command="$command_pid" \
      '$2 == owner && $1 != command && $3 ~ /bash$/ { print $1; exit }')
    [[ -n "$watchdog_pid" ]] && break
    sleep 0.02
  done
  [[ "$watchdog_pid" =~ ^[1-9][0-9]*$ ]] || {
    echo "$signal_scope fixture did not start its watchdog." >&2
    return 1
  }
  kill -TERM "$wrapper_pid"
  for attempt in {1..150}; do
    [[ -s "$signal_file" ]] && break
    sleep 0.02
  done
  [[ -s "$signal_file" ]] || {
    echo "$signal_scope fixture did not reach TERM cleanup." >&2
    return 1
  }
  if [[ "$signal_scope" == group ]]; then
    /bin/kill -TERM -- "-$wrapper_pid"
  else
    kill -TERM "$wrapper_pid"
  fi

  for attempt in {1..150}; do
    kill -0 "$wrapper_pid" 2>/dev/null || break
    sleep 0.02
  done
  if kill -0 "$wrapper_pid" 2>/dev/null; then
    echo "$signal_scope cancellation did not complete within 3 seconds." >&2
    return 1
  fi
  if wait "$wrapper_pid"; then
    wrapper_status=0
  else
    wrapper_status=$?
  fi
  [[ "$wrapper_status" -eq 143 ]] || {
    echo "$signal_scope cancellation changed TERM status to $wrapper_status." >&2
    return 1
  }
  if /bin/kill -0 -- "-$command_pid" 2>/dev/null; then
    echo "$signal_scope cancellation left its command process group alive." >&2
    return 1
  fi
  if /bin/kill -0 -- "-$wrapper_pid" 2>/dev/null; then
    echo "$signal_scope cancellation left its watchdog process group alive." >&2
    return 1
  fi
  echo "watchdog-tests: $signal_scope cancellation reaped owned processes."
}

# Break caught: resetting signal traps lets a repeated signal abort cleanup.
assert_signal_cleanup repeated
# Break caught: group cancellation interrupts escalation or leaves its watchdog.
assert_signal_cleanup group

echo "watchdog-tests: timeout and command statuses propagated; signal cleanup complete."
