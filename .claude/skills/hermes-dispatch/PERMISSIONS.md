# Permission allow-rules for hermes-dispatch

This file is **not** linked from `SKILL.md` and is not auto-loaded into the
LLM context when the skill runs. It is a setup note for the human installing
the skill.

## Where these go

Paste the entries into `~/.claude/settings.json` (or a project-local
`.claude/settings.local.json`) under `permissions.allow`. If you already have
a `permissions.allow` array, merge — don't replace.

Format reminder: Claude Code matches on the literal command string with `*`
as a trailing wildcard. The rules below use the `~/.claude/...` form because
that's what the LLM types when calling scripts from the skill dir; if you
prefer fully-resolved paths, both `~/.claude/skills/...` and
`/Users/<you>/.claude/skills/...` patterns are honored.

## Tier 1 — read-only (safe to allow broadly)

These never modify board state. Read calls, log fetches, status polls,
sanity checks.

```json
{
  "permissions": {
    "allow": [
      "Bash(ssh hermes hermes kanban stats*)",
      "Bash(ssh hermes hermes kanban list*)",
      "Bash(ssh hermes hermes kanban show*)",
      "Bash(ssh hermes hermes kanban runs*)",
      "Bash(ssh hermes hermes kanban log*)",
      "Bash(ssh hermes hermes kanban assignees*)",
      "Bash(ssh hermes hermes kanban boards list*)",
      "Bash(ssh hermes hermes kanban diagnostics*)",
      "Bash(ssh hermes hermes --version*)",
      "Bash(ssh hermes systemctl is-active hermes-gateway*)",
      "Bash(ssh -o BatchMode=yes hermes echo*)",

      "Bash(~/.claude/skills/hermes-dispatch/scripts/status.sh*)",
      "Bash(~/.claude/skills/hermes-dispatch/scripts/log.sh*)",
      "Bash(~/.claude/skills/hermes-dispatch/scripts/poll.sh*)",
      "Bash(~/.claude/skills/hermes-dispatch/scripts/tunnel-dashboard.sh*)"
    ]
  }
}
```

## Tier 2 — create / dispatch (mid-risk; pre-approves spawning workers)

Dispatching a task is not destructive to your filesystem but **does spawn a
worker on the VPS that burns model tokens**. Decide whether you want this
pre-approved. If yes, add:

```json
"Bash(~/.claude/skills/hermes-dispatch/scripts/dispatch.sh*)",
"Bash(ssh hermes hermes kanban create*)"
```

The wrapper's `--idempotency-key` derivation (sha256 of title|body|assignee|board)
limits the blast radius of duplicate calls — re-running the same dispatch
returns the existing task id instead of spawning a second worker.

## Tier 3 — destructive (NOT recommended for blanket allow)

Archive, block, unblock, reclaim, reassign, comment, complete, edit. These
reach into shared kanban state and can reclaim workers mid-flight. The skill's
own SKILL.md flags `block` and `archive` as requiring user confirmation, so
the auto-classifier will (correctly) block them even with a permission rule
in some cases.

If you really want a one-shot allow for a cleanup session, add them
temporarily and remove afterward:

```json
"Bash(ssh hermes hermes kanban archive*)",
"Bash(ssh hermes hermes kanban block*)",
"Bash(ssh hermes hermes kanban unblock*)",
"Bash(ssh hermes hermes kanban comment*)",
"Bash(ssh hermes hermes kanban reclaim*)",
"Bash(ssh hermes hermes kanban reassign*)",
"Bash(ssh hermes hermes kanban complete*)",
"Bash(ssh hermes hermes kanban edit*)"
```

Better default: leave these off the allow-list. When a real cleanup is
needed, type the exact command (or paste the task id list) into the chat —
that puts the approval in transcript form and the classifier honors it.

## Minimal recommended starter

If you want to copy-paste *one* block and stop thinking about it, use
**Tier 1 only**. That covers everything you'd want to do interactively
("what's on the board?", "what's the status of t_xxxx?", "tail the log",
"wait for it to finish") without ever pre-authorizing a write. Dispatch and
mutation calls will still prompt — which is the right default.

## Verifying the rules are in effect

After editing `settings.json`:

1. Restart any open Claude Code session (the settings file is read at
   startup).
2. Run `~/.claude/skills/hermes-dispatch/scripts/status.sh` from a fresh
   session. It should execute without a permission prompt.
3. If you still get prompted, check the Claude Code CLI's `/permissions`
   view to see which rules matched and which didn't.

## Notes on why wrappers alone don't help

The auto-mode classifier evaluates the *effect* of a command, not just the
shell string. Wrapping `ssh hermes 'hermes kanban block …'` inside a script
called `cancel.sh` does not bypass the classifier — it still recognises that
the script reaches a remote host and mutates shared state. Permission rules
are the proper escape hatch because they're a user-set authorization signal
that the classifier explicitly honors.
