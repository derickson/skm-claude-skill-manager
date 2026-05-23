# `hermes kanban` cheatsheet

Quick reference for the subset of `hermes kanban` that the `hermes-dispatch`
skill uses. Source of truth is `hermes kanban --help` on the VPS — this file
captures the shapes the skill depends on so it doesn't need to re-discover
them every conversation.

## Subcommands at a glance

```
init        boards     create      swarm
list / ls   show       assign      reclaim
reassign    diagnostics            link / unlink
claim       comment    complete    edit
block       schedule   unblock     archive
tail        dispatch   watch       stats
notify-*    log        runs        heartbeat
assignees   context    specify     decompose   gc
```

All read-style subcommands accept `--json`. Use it.

**Never call these from inside a tool invocation — they stream forever:**

- `hermes kanban watch`
- `hermes kanban tail`
- `hermes kanban chat` (if/when present)

## Common shapes

### `create --json`

```json
{
  "id": "t_abc12345",
  "title": "...",
  "status": "todo",
  "assignee": "default",
  "workspace": "scratch",
  "idempotency_key": "<sha256>",
  "created_at": "2026-05-23T11:22:33Z"
}
```

Field that matters most: `id`. Always echo this back to the user.

### `show <id> --json`

Wraps the task object inside an envelope. **`status` is at `.task.status`**,
**not** the top level (this differs from `create --json` and `list --json`,
which are flat). The poller reads `.task.status // .status` to handle both.

```json
{
  "task": {
    "id": "t_abc12345",
    "title": "...",
    "body": "...",
    "status": "running",
    "assignee": "default",
    "workspace_kind": "scratch",
    "workspace_path": "/root/.hermes/kanban/workspaces/t_abc12345",
    "created_at": 1779551539,
    "started_at": 1779551547,
    "completed_at": null,
    "result": null
  },
  "latest_summary": null,
  "parents": [],
  "children": [],
  "comments": [],
  "events": [{"kind": "created|claimed|spawned|completed", "...": "..."}],
  "runs":   [{"id": 14, "status": "running|done", "outcome": null, "...": "..."}]
}
```

`.latest_summary` is the worker's one-line result (e.g. `"SMOKE-OK"`) when
the task finishes. Surface it to the user — it's usually what they want.

Statuses we treat as **terminal**: `done`, `blocked`, `archived`.
Statuses we treat as **active** (keep polling): `ready`, `running`,
`review`, `scheduled`, `triage`, `todo`.

### `runs <id> --json`

Array of attempt objects. Verified field names (Hermes v0.14.0):

```json
[
  {
    "id": 14,
    "profile": "default",
    "step_key": null,
    "status": "running|done",
    "outcome": "completed",      // null while running; "completed" on success
    "summary": "SMOKE-OK",       // populated when the worker finishes
    "error": null,
    "metadata": {
      "response": "SMOKE-OK",
      "files_modified": [],
      "worker_session_id": "20260523_155229_6f4a26"
    },
    "worker_pid": null,          // populated only while running
    "started_at": 1779551547,
    "ended_at": 1779551576
  }
]
```

`.[0].outcome` is the simplest "did it work?" signal. `.[0].metadata` has
the actual worker response and a list of modified files.

### `stats --json`

```json
{
  "by_status":   { "done": 2, "running": 1 },
  "by_assignee": { "default": { "done": 2, "running": 1 } },
  "oldest_ready_age_seconds": null,
  "now": 1779551825
}
```

Note: `by_assignee` is **nested** (assignee → status → count), not flat.
`oldest_ready_age_seconds` is `null` when no task is in `ready`. `now` is a
unix epoch integer, not an ISO timestamp.

`oldest_ready_age_seconds` > a couple hundred → the dispatcher is probably
not running. Check `systemctl is-active hermes-gateway`.

### `list --json`

Array of **flat** task objects — same shape as `create --json` (no `.task`
envelope, unlike `show --json`).

```json
[
  {
    "id": "t_abc12345",
    "title": "...",
    "status": "running",
    "assignee": "default",
    "workspace_kind": "scratch",
    "created_at": 1779551539,
    "started_at": 1779551547,
    "completed_at": null,
    "result": null
  }
]
```

Filter with `--status <s>` and/or `--assignee <a>`.

### `log <id> --tail <bytes>`

Plain text (not JSON). Worker stdout/stderr, last `<bytes>` bytes. Default
the wrapper passes is 4000. For longer dumps the user can request more
explicitly — but consider that we have to pipe it all through SSH.

## Flags worth knowing on `create`

| Flag | Purpose |
| --- | --- |
| `--body <text>` | Full instructions for the worker. |
| `--assignee <profile>` | Which profile/skill set picks it up. Default: `default`. |
| `--workspace <spec>` | `scratch`, `worktree:/path`, etc. |
| `--max-runtime <dur>` | Hard wall-clock cap. Defaults vary; the wrapper passes `30m`. |
| `--triage` | Push as a triage card; Hermes will specify/decompose. |
| `--skill <name>` | Force-load a hermes skill on the worker side. Repeatable. |
| `--parent <id>` | Dependency chain. The new task waits on the parent. |
| `--idempotency-key <key>` | Dedupe re-creates. Wrapper derives a sha256 if omitted. |
| `--created-by <tag>` | Free-form provenance tag. Wrapper sets `claude-<hostname>`. |
| `--json` | Stable machine-readable output. Always pass this. |

## Board selection

Multi-board is supported; today only `default` exists. To target a
non-default board, put `--board <slug>` **before** the subcommand:

```bash
ssh hermes 'hermes kanban --board myproj list --json'
ssh hermes 'hermes kanban --board myproj create "..." --json'
```

Or pre-export `HERMES_KANBAN_BOARD=<slug>` on the remote side. The skill's
wrappers all accept `--board <slug>`.

## Things that have bitten before

- The kanban DB has been corrupted/rebuilt at least once. **Never** open
  `/root/.hermes/kanban.db` with `sqlite3` from this skill. If `hermes
  kanban` itself surfaces a sqlite error, stop and surface it to the user.
- `hermes kanban daemon` is **deprecated**. The dispatcher runs inside
  `hermes-gateway.service`. Don't try to start a daemon process.
- `hermes dashboard` listens on `127.0.0.1:9119` and is not always running.
  Tunnel it on demand; don't assume it's up.
