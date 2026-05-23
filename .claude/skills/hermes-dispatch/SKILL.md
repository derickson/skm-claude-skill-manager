---
name: hermes-dispatch
description: >
  Queue, monitor, and report on tasks running on the user's remote Hermes
  agent kanban board over SSH. Use whenever the user says "dispatch to
  hermes", "send this to hermes", "what's on the hermes board", "what's
  hermes working on", "check the kanban", or asks for the status/result of a
  task id matching ^t_[0-9a-f]{8}$.
metadata:
  author: dave
  version: 0.1.0
---

# hermes-dispatch

A thin SSH wrapper around `hermes kanban` on the user's `hermes` VPS. Use
this skill to put work on the board, check what's running, and report
results back. Nothing runs locally — the dispatcher is `hermes-gateway.service`
on the remote host.

## Connection model

Every operation is:

```
ssh ${HERMES_SSH_HOST:-hermes} "hermes kanban <subcommand> ... --json"
```

The scripts in `scripts/` wrap the common ones with consistent flags and a
single retry/timeout policy. The host alias `hermes` is in the user's
`~/.ssh/config`; override with `HERMES_SSH_HOST` for staging hosts.

## When to dispatch vs. ask first

**Always confirm with the user before calling `dispatch.sh`.** Creating a
kanban task is not destructive in the file-system sense, but it spawns a
worker on the VPS that burns model tokens. Treat it like sending a message
to another person. Read-only operations (`status.sh`, `log.sh`,
`poll.sh`) do not need confirmation.

If the user's intent is vague ("look into X"), prefer `--triage` so Hermes's
triage specifier flesh out the spec, rather than guessing a body yourself.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/dispatch.sh` | Create a task. Returns JSON with the new `id`. Auto-derives an idempotency key from `(title\|body\|assignee\|board)` so accidental re-runs don't fan out. |
| `scripts/status.sh`   | `stats` (the default with no args), `list`, `show <id>`, or `runs <id>` — all JSON. |
| `scripts/poll.sh`     | Bounded poll of `show --json` until `done`/`blocked`/`archived` or timeout. Default 600s/10s. |
| `scripts/log.sh`      | Worker log via `hermes kanban log --tail <bytes>`. Default 4000 bytes. |
| `scripts/tunnel-dashboard.sh` | Prints the `ssh -L 9119:...` command for the user to run themselves; with `--run` it execs it in foreground (humans only — never call with `--run` from a tool). |

## Polling rules — read this before fetching status

**Never call `hermes kanban watch` or `hermes kanban tail` from inside a tool
invocation.** Both stream forever and will hang the call.

To wait for a task to finish:

```bash
~/.claude/skills/hermes-dispatch/scripts/poll.sh <task-id> 600 10
```

Exits 0 (terminal), 2 (timeout), or 4 (3 consecutive SSH failures). The
final `show --json` is on stdout in every case.

Terminal statuses: `done`, `blocked`, `archived`.
Active statuses (keep polling): `ready`, `running`, `review`, `scheduled`,
`triage`, `todo`.

If the user wants a *live* stream of the worker log, hand them the command
instead of running it:

```
ssh hermes 'hermes kanban tail <task-id>'
```

## Output shape — what to report back to the user

When reporting on a task, always surface:

- `id` and `title` (`.task.id`, `.task.title` from `show --json`)
- `status` (`.task.status`) and `assignee` if non-default
- the most recent timestamp on the task (`.task.created_at` / `.task.started_at` / `.task.completed_at` — unix epoch ints, not ISO strings)
- if `done`: the **`.latest_summary`** field at the top of the show envelope (e.g. `"SMOKE-OK"`). `.task.result` is *usually `null`* for done tasks — don't lead with it. If `latest_summary` is also empty, fall back to `.runs[0].summary` or `.runs[0].metadata.response`, then to the last ~40 lines of `log.sh`.
- if `blocked` or `failed`: **both** `status.sh runs <id>` (attempt history)
  and `log.sh <id> --tail 4000` (worker log tail). This is the most common
  failure path and the runs + log are the user's debugging starting point.

## Common recipes

### Dispatch a task (after user confirmation)

```bash
~/.claude/skills/hermes-dispatch/scripts/dispatch.sh \
  --title 'fix flaky test in foo.py' \
  --body  'Reproduce with pytest -k test_flaky; root-cause and patch.' \
  --max-runtime 30m
# → prints {"id":"t_abc12345", ...}
```

Add `--triage` for vague asks, `--workspace worktree:/repo/path` to run
inside a real git repo, `--parent t_xxxx` to chain dependencies,
`--skill <name>` (repeatable) to force-load a hermes skill.

### Look at the board

```bash
~/.claude/skills/hermes-dispatch/scripts/status.sh                       # stats
~/.claude/skills/hermes-dispatch/scripts/status.sh list                  # everything
~/.claude/skills/hermes-dispatch/scripts/status.sh list --status running
~/.claude/skills/hermes-dispatch/scripts/status.sh list --assignee default
```

### Inspect / wait on one task

```bash
~/.claude/skills/hermes-dispatch/scripts/status.sh show t_abc12345
~/.claude/skills/hermes-dispatch/scripts/status.sh runs t_abc12345
~/.claude/skills/hermes-dispatch/scripts/log.sh    t_abc12345 --tail 4000
~/.claude/skills/hermes-dispatch/scripts/poll.sh   t_abc12345 600 10
```

### Comment / block / archive

These are plain `hermes kanban` calls (no wrapper needed):

```bash
ssh hermes "hermes kanban comment t_abc12345 'also check the new index mapping'"
ssh hermes "hermes kanban block   t_abc12345"
ssh hermes "hermes kanban unblock t_abc12345"
ssh hermes "hermes kanban archive t_abc12345"
```

Always confirm with the user before `block` or `archive` — those reclaim a
running worker or take the task off the board.

### Open the dashboard

```bash
~/.claude/skills/hermes-dispatch/scripts/tunnel-dashboard.sh
# prints the ssh -L command for the user to run; do not --run yourself.
```

## Failure-mode handling

| Symptom | What to do |
| --- | --- |
| `dispatch.sh` returns the *same* id you got last time. | That's the idempotency key working as designed — the previous task is still on the board. Don't re-create; check its status. |
| Task stuck in `ready`/`todo` for > 2 minutes. | Check `ssh hermes 'systemctl is-active hermes-gateway'`. If not `active`, surface that to the user — don't try to start the service from here. |
| `show` / `list` errors with a sqlite message. | Stop. Don't retry, don't touch `kanban.db`. Tell the user — historical backups live in `/root/.hermes/kanban.db.*` on hermes. |
| Bad task id (`not found`). | Surface the CLI's error verbatim; don't crash. |
| Worker `blocked` after retries. | Pull `runs --json` + `log --tail 4000` and surface both. |

## Out of scope

- Editing `kanban.db` directly. Always go through `hermes kanban`.
- Starting/stopping `hermes-gateway` or the dashboard from a tool call.
- Pushing skills/configs/secrets *into* hermes. This skill is one-way:
  workstation → board.
- Public HTTP endpoints. SSH (or SSH-tunneled local ports) only.

## Reference

`reference/kanban-cli-cheatsheet.md` has the full `hermes kanban` subcommand
list, common JSON shapes, and the field names this skill relies on.
