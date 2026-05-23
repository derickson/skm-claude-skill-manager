# hermes-dispatch — CHANGELOG

## v0.1.0 — 2026-05-23

Initial release. SKILL.md, six wrapper scripts under `scripts/`, and a
cheatsheet under `reference/`. Implements all of §4 in the project's
`full_plan.md`; built and tested against Hermes Agent v0.14.0 on the
`hermes` VPS.

### What's in

- `scripts/dispatch.sh` — create a task with auto-derived sha256 idempotency
  key, configurable assignee/workspace/runtime/board, optional triage,
  parent, and force-load skills.
- `scripts/status.sh` — `stats` / `list` / `show <id>` / `runs <id>`, all
  emitting JSON.
- `scripts/poll.sh` — bounded poll of `show --json` until terminal or
  timeout. Tolerates up to 2 transient SSH failures before bailing.
- `scripts/log.sh` — bounded `kanban log --tail <bytes>` fetch.
- `scripts/tunnel-dashboard.sh` — prints the `ssh -L 9119:...` command for
  the user to run (does not auto-start). `--run` for human-driven exec.
- `scripts/_ssh.sh` — shared `hermes_ssh` wrapper and `hermes_sha256` helper.
- `reference/kanban-cli-cheatsheet.md` — exact JSON shapes for `show`,
  `list`, `runs`, `stats`, and a list of flags worth knowing.

### Validation evidence (from build-out session)

| Phase | Outcome | Notes |
| --- | --- | --- |
| A1–A6 | ✓ all green | Re-ran as Phase E after final edits — still green. |
| B1 | ✓ | Created task `t_29668f4e` via `dispatch.sh`. |
| B2 | ✓ | `show` reported `running` within ~8s of create. |
| B3 | ✓ | Reached `done` in ~37s; `latest_summary: "SMOKE-OK"`. |
| B4 | ✓ | `.[0].outcome == "completed"` (CLI uses `completed` not `success`). |
| B5 | ✓ | Worker log contained the literal `SMOKE-OK`. |
| B6 | ✓ | `archive t_29668f4e` succeeded after explicit user authorization. |
| C1 | ✓ | Two `create` calls with the same idempotency key returned the same id (`t_36948b45`). |
| C2 | ✓ | Read half: created `t_467ea2d1`, confirmed `running`, watched it resolve naturally. Write half: after the user added Tier-1 permission rules to `~/.claude/settings.json`, re-ran on `t_afa278ea` — claimed `running` after ~15s, blocked mid-run with `block <id> 'reason'`, `.task.status` correctly reported `blocked` and `runs[0].outcome` was `blocked`. Archived for cleanup. |
| C3 | skipped | Gateway-down test intentionally not run (per plan §7). |
| C4 | ✓ | `show t_deadbeef --json` surfaces `no such task: t_deadbeef` (exit 0 with informative message — acceptable surface per plan). |
| D1–D5 | ✓ | Re-validated by an isolated subagent that discovered the skill cold from `SKILL.md`. Reports a single round-trip per call, correct JSON shapes, and `tunnel-dashboard.sh` printing-only (no auto-exec). |
| D6 | ✓ | `archive t_36948b45` and `archive t_467ea2d1` both succeeded under explicit user authorization. Board's active list is empty post-run. |
| E   | ✓ | Re-ran A1–A6 after all edits — identical green. Final `bash -n` syntax check across all six scripts clean. |

### Bugs found and fixed during build-out

- `dispatch.sh`: empty-array expansion `"${skills[@]}"` errored under bash 3.2
  (macOS default shell) with `set -u`. Now guarded with `[ "${#skills[@]}" -gt 0 ]`.
- `poll.sh`: originally read `.status` from `hermes kanban show --json`, but
  the CLI wraps the task object in `{task: {...}, events, runs, ...}`. Now
  reads `.task.status // .status` to handle both shapes. Cheatsheet updated
  to document this asymmetry between `show` (wrapped) and `create`/`list`
  (flat).
- SKILL.md "Output shape" originally told the model to surface `.task.result`
  on done tasks, but the CLI populates `.latest_summary` (top-level on the
  show envelope) instead and leaves `.task.result` null. Fixed by the
  fresh-session subagent's feedback during Phase D validation.

### Cleanup at v0.1.0 close

- `t_29668f4e`, `t_36948b45`, `t_467ea2d1`, `t_afa278ea` — all archived. Active list empty.

### Permissions setup

A `PERMISSIONS.md` was added to the skill dir (not linked from SKILL.md so it
doesn't load into LLM context). It documents three tiers of Bash allow-rules
for `~/.claude/settings.json`. The user adopted Tier 1 (read-only) during
v0.1.0 close; that's what unblocked the C2 write-path validation above.

### Known gaps carried into v0.2.0

- **`max-retries` / circuit-breaker surfacing.** The skill correctly fetches
  `runs --json` + `log --tail` on `blocked` outcomes (per SKILL.md "Output
  shape") but this codepath has not been seen end-to-end with a *real worker
  failure* — only with a user-initiated `block`. Best validated
  opportunistically when an actual worker run fails.
- **Gateway-down detection (Phase C3).** Intentionally skipped per plan §7
  to avoid disrupting the live `hermes-gateway.service`. Could be exercised
  in a maintenance window.
