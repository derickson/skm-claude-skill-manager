#!/usr/bin/env bash
# log.sh — fetch a worker log for a task. Bounded by --tail; never streams.
#
# Usage:
#   log.sh <task-id> [--tail <bytes>] [--board <slug>]
#
# Default --tail is 4000 bytes.
#
# IMPORTANT: this does NOT call `hermes kanban tail` (which streams live and
# would hang inside a tool call). To watch logs live, the user runs `hermes
# kanban tail <id>` themselves in their own terminal.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$here/_ssh.sh"

task="${1:-}"
shift || true

tail_bytes="4000"
board=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tail)  tail_bytes="$2"; shift 2 ;;
    --board) board="$2"; shift 2 ;;
    *) echo "log.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -z "$task" ] && { echo "log.sh: task id required" >&2; exit 2; }

board_prefix=""
[ -n "$board" ] && board_prefix=" --board $(printf '%q' "$board")"

hermes_ssh "hermes kanban${board_prefix} log $(printf '%q' "$task") --tail $(printf '%q' "$tail_bytes")"
