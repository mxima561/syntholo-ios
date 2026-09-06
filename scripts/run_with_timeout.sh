#!/usr/bin/env bash
set -u

if [[ "$#" -lt 2 || ! "$1" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 <positive-timeout-seconds> <command> [arguments ...]" >&2
  exit 64
fi

timeout_seconds=$1
shift
poll_interval=${SYNTHOLO_TIMEOUT_POLL_INTERVAL:-0.25}
interrupt_grace=${SYNTHOLO_TIMEOUT_INTERRUPT_GRACE_SECONDS:-5}
terminate_grace=${SYNTHOLO_TIMEOUT_TERMINATE_GRACE_SECONDS:-5}
command_pid=""
watchdog_pid=""

process_group_exists() {
  /bin/kill -0 -- "-$1" 2>/dev/null
}

terminate_process_group() {
  local process_group_id=$1
  local signal
  local grace

  for signal in INT TERM KILL; do
    process_group_exists "$process_group_id" || return
    /bin/kill -"$signal" -- "-$process_group_id" 2>/dev/null || true

    case "$signal" in
      INT) grace=$interrupt_grace ;;
      TERM) grace=$terminate_grace ;;
      KILL) grace=0 ;;
    esac
    [[ "$grace" == "0" ]] || sleep "$grace"
  done
}

handle_signal() {
  local exit_status=$1
  # A forwarded signal can follow a signal delivered to the whole group.
  # Cleanup must finish even when cancellation is requested more than once.
  trap '' INT TERM HUP

  if [[ -n "$command_pid" ]]; then
    terminate_process_group "$command_pid"
    wait "$command_pid" 2>/dev/null || true
  fi
  if [[ -n "$watchdog_pid" ]]; then
    /bin/kill -TERM "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
  fi
  exit "$exit_status"
}

trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM
trap 'handle_signal 129' HUP

deadline_epoch=$(($(date +%s) + timeout_seconds))
perl -MPOSIX -e '
  POSIX::setsid() != -1 or die "setsid failed: $!\n";
  exec @ARGV;
  die "exec failed: $!\n";
' -- "$@" &
command_pid=$!

process_group_ready=0
for _ in {1..100}; do
  if process_group_exists "$command_pid"; then
    process_group_ready=1
    break
  fi
  if ! /bin/kill -0 "$command_pid" 2>/dev/null; then
    wait "$command_pid" 2>/dev/null
    exit $?
  fi
  sleep 0.01
done
if [[ "$process_group_ready" -ne 1 ]]; then
  echo "Timed command did not establish its isolated process group." >&2
  /bin/kill -KILL "$command_pid" 2>/dev/null || true
  wait "$command_pid" 2>/dev/null || true
  exit 70
fi

(
  poll_pid=""
  stop_watchdog() {
    trap '' INT TERM HUP
    if [[ -n "$poll_pid" ]]; then
      /bin/kill -TERM "$poll_pid" 2>/dev/null || true
      wait "$poll_pid" 2>/dev/null || true
    fi
    exit 0
  }
  trap stop_watchdog INT TERM HUP

  while process_group_exists "$command_pid"; do
    if (( $(date +%s) >= deadline_epoch )); then
      echo "Command timed out after ${timeout_seconds}s (process group ${command_pid})." >&2
      terminate_process_group "$command_pid"
      exit 124
    fi
    sleep "$poll_interval" &
    poll_pid=$!
    wait "$poll_pid"
    poll_pid=""
  done
  exit 0
) &
watchdog_pid=$!

wait "$command_pid" 2>/dev/null
command_status=$?
wait "$watchdog_pid"
watchdog_status=$?
trap - INT TERM HUP

if [[ "$watchdog_status" -eq 124 ]]; then
  exit 124
fi
exit "$command_status"
