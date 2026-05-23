#!/usr/bin/env bash
# tunnel-dashboard.sh — print (or run) the SSH command that tunnels the
# hermes dashboard to localhost:9119 and starts the dashboard on the remote
# side.
#
# Usage:
#   tunnel-dashboard.sh           → print the command for the user to run.
#   tunnel-dashboard.sh --run     → exec it directly. This is FOREGROUND and
#                                   will block this terminal until the user
#                                   ctrl-Cs. Only do this when invoked by a
#                                   human in their own shell, never inside a
#                                   Claude tool call.
#
# The dashboard is left to the user because:
#   - It runs forever, which would hang a tool call.
#   - The user may already have a tunnel; double-binding 9119 errors out.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$here/_ssh.sh"

cmd=(ssh -L 9119:127.0.0.1:9119 "$HERMES_SSH_HOST" 'hermes dashboard --no-open --skip-build')

if [ "${1:-}" = "--run" ]; then
  echo "Tunneling 9119 and starting hermes dashboard. Ctrl-C to stop." >&2
  echo "Open http://localhost:9119 in your browser." >&2
  exec "${cmd[@]}"
fi

printf 'Run this in your own terminal:\n  %s\nThen open http://localhost:9119\n' "${cmd[*]}"
