#!/usr/bin/env bash
# dispatch.sh — create a kanban task on the remote hermes board.
#
# Usage:
#   dispatch.sh --title "<title>" --body "<body>" [options]
#
# Options:
#   --title         Required. Short title.
#   --body          Required. Full task body / instructions for the worker.
#   --assignee      Profile/assignee name. Default: default.
#   --workspace     Workspace spec (e.g. scratch, worktree:/path). Default: scratch.
#   --max-runtime   Wall-clock cap for the worker. Default: 30m.
#   --board         Board slug. Default: (server default).
#   --triage        Push as a triage card (let Hermes specify/decompose).
#   --skill <name>  Force-load a hermes skill into the worker (repeatable).
#   --parent <id>   Parent task id (dependency chain).
#   --idempotency-key <key>
#                   Override the auto-derived sha256 key.
#   --created-by    Override the created-by tag. Default: claude-<hostname>.
#   --json          Print full create JSON (default). Pass --no-json for plain.
#
# Output: JSON from `hermes kanban create --json` on stdout. The caller is
# expected to parse `.id` with jq.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$here/_ssh.sh"

title=""
body=""
assignee="default"
workspace="scratch"
max_runtime="30m"
board=""
triage=0
created_by="claude-$(hostname -s 2>/dev/null || hostname)"
idempotency_key=""
json_flag="--json"
skills=()
parent=""

while [ $# -gt 0 ]; do
  case "$1" in
    --title)            title="$2"; shift 2 ;;
    --body)             body="$2";  shift 2 ;;
    --assignee)         assignee="$2"; shift 2 ;;
    --workspace)        workspace="$2"; shift 2 ;;
    --max-runtime)      max_runtime="$2"; shift 2 ;;
    --board)            board="$2"; shift 2 ;;
    --triage)           triage=1; shift ;;
    --skill)            skills+=("$2"); shift 2 ;;
    --parent)           parent="$2"; shift 2 ;;
    --idempotency-key)  idempotency_key="$2"; shift 2 ;;
    --created-by)       created_by="$2"; shift 2 ;;
    --json)             json_flag="--json"; shift ;;
    --no-json)          json_flag=""; shift ;;
    *) echo "dispatch.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$title" ] || [ -z "$body" ]; then
  echo "dispatch.sh: --title and --body are required" >&2
  exit 2
fi

# Derive an idempotency key from (title|body|assignee|board) if the caller
# didn't supply one. Same inputs → same task on the board.
if [ -z "$idempotency_key" ]; then
  idempotency_key="$(hermes_sha256 "${title}|${body}|${assignee}|${board}")"
fi

# Build the remote command. We rely on printf %q for safe quoting of every
# user-supplied string so titles / bodies with quotes don't break the shell
# on the far side.
remote="hermes kanban"
[ -n "$board" ] && remote+=" --board $(printf '%q' "$board")"
remote+=" create $(printf '%q' "$title")"
remote+=" --body $(printf '%q' "$body")"
remote+=" --assignee $(printf '%q' "$assignee")"
remote+=" --workspace $(printf '%q' "$workspace")"
remote+=" --max-runtime $(printf '%q' "$max_runtime")"
remote+=" --idempotency-key $(printf '%q' "$idempotency_key")"
remote+=" --created-by $(printf '%q' "$created_by")"
[ "$triage" -eq 1 ] && remote+=" --triage"
[ -n "$parent" ] && remote+=" --parent $(printf '%q' "$parent")"
# Empty-array expansion under `set -u` errors on bash 3.2 (macOS); guard it.
if [ "${#skills[@]}" -gt 0 ]; then
  for s in "${skills[@]}"; do
    remote+=" --skill $(printf '%q' "$s")"
  done
fi
[ -n "$json_flag" ] && remote+=" $json_flag"

hermes_ssh "$remote"
