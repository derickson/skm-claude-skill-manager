#!/usr/bin/env bash
# poll.sh — bounded poll on `hermes kanban show <id> --json` until the task
# reaches a terminal state (done|blocked|archived) or the timeout fires.
#
# Usage:
#   poll.sh <task-id> [timeout_seconds] [interval_seconds] [--board <slug>]
#
# Defaults: timeout=600s, interval=10s.
#
# Exit codes:
#   0 → terminal state reached. Final show-JSON printed on stdout.
#   2 → timeout. Last show-JSON printed on stdout.
#   3 → invalid args.
#
# Notes:
#   - One failed `show` call is not fatal — we re-issue on the next interval.
#     Three consecutive failures bail out with exit 4.
#   - This script must never call `hermes kanban watch` or `tail` — those
#     stream forever and would hang a tool call.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$here/_ssh.sh"

task="${1:-}"
timeout="${2:-600}"
interval="${3:-10}"
board=""

# Optional --board, parsed from remaining args.
shift 3 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --board) board="$2"; shift 2 ;;
    *) echo "poll.sh: unknown arg: $1" >&2; exit 3 ;;
  esac
done

if [ -z "$task" ]; then
  echo "poll.sh: task id required" >&2
  exit 3
fi

board_prefix=""
[ -n "$board" ] && board_prefix=" --board $(printf '%q' "$board")"

deadline=$(( $(date +%s) + timeout ))
last_json=""
fail_streak=0

while :; do
  if json=$(hermes_ssh "hermes kanban${board_prefix} show $(printf '%q' "$task") --json" 2>/dev/null); then
    last_json="$json"
    fail_streak=0
    # `hermes kanban show --json` wraps the task in {task:{...}, events:[...],
    # runs:[...], ...}. Older/other CLIs may emit a flat object — fall back to
    # top-level .status if .task.status is missing.
    status=$(printf '%s' "$json" | jq -r '.task.status // .status // empty' 2>/dev/null || true)
    case "$status" in
      done|blocked|archived)
        printf '%s\n' "$json"
        exit 0
        ;;
    esac
  else
    fail_streak=$(( fail_streak + 1 ))
    if [ "$fail_streak" -ge 3 ]; then
      echo "poll.sh: 3 consecutive show failures; giving up" >&2
      [ -n "$last_json" ] && printf '%s\n' "$last_json"
      exit 4
    fi
  fi

  now=$(date +%s)
  if [ "$now" -ge "$deadline" ]; then
    [ -n "$last_json" ] && printf '%s\n' "$last_json"
    exit 2
  fi

  sleep "$interval"
done
