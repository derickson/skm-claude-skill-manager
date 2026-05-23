#!/usr/bin/env bash
# status.sh — read board state or single-task state, as JSON.
#
# Usage:
#   status.sh                            → hermes kanban stats --json
#   status.sh list [--status <s>] [--assignee <a>] [--board <b>]
#                                        → hermes kanban list --json (filtered)
#   status.sh show <task-id> [--board <b>]
#                                        → hermes kanban show <id> --json
#   status.sh runs <task-id> [--board <b>]
#                                        → hermes kanban runs <id> --json
#
# Always prints JSON on stdout. Non-zero exit on SSH/CLI failure.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$here/_ssh.sh"

mode="${1:-stats}"
shift || true

board=""
status_filter=""
assignee_filter=""
task_id=""

# Pull a --board flag (and a task id for show/runs) out of the remaining args.
positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    --board)     board="$2"; shift 2 ;;
    --status)    status_filter="$2"; shift 2 ;;
    --assignee)  assignee_filter="$2"; shift 2 ;;
    *)           positional+=("$1"); shift ;;
  esac
done

board_prefix=""
[ -n "$board" ] && board_prefix=" --board $(printf '%q' "$board")"

case "$mode" in
  stats)
    hermes_ssh "hermes kanban${board_prefix} stats --json"
    ;;
  list)
    cmd="hermes kanban${board_prefix} list --json"
    [ -n "$status_filter" ]   && cmd+=" --status $(printf '%q' "$status_filter")"
    [ -n "$assignee_filter" ] && cmd+=" --assignee $(printf '%q' "$assignee_filter")"
    hermes_ssh "$cmd"
    ;;
  show)
    task_id="${positional[0]:-}"
    [ -z "$task_id" ] && { echo "status.sh show: task id required" >&2; exit 2; }
    hermes_ssh "hermes kanban${board_prefix} show $(printf '%q' "$task_id") --json"
    ;;
  runs)
    task_id="${positional[0]:-}"
    [ -z "$task_id" ] && { echo "status.sh runs: task id required" >&2; exit 2; }
    hermes_ssh "hermes kanban${board_prefix} runs $(printf '%q' "$task_id") --json"
    ;;
  *)
    echo "status.sh: unknown mode '$mode' (want: stats|list|show|runs)" >&2
    exit 2
    ;;
esac
