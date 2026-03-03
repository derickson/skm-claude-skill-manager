# SKM — Skill Manager for Claude Code

A central library and CLI tool (`skm`) for managing [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills and commands across projects.

All trigger phrases, CLI commands, config paths, and skill names are prefixed with **SKM** to avoid collision with any future Anthropic-native skill management features.

## What's in this repo

```
src/
  skills/
    skm/
      SKILL.md       # The SKM in-Claude skill (installed into projects)
.claude/
  commands/          # SKM library — distributable slash commands
  skills/            # SKM library — distributable skills
skill_manager.py     # SKM CLI (installed as `skm`)
Makefile             # skm install / uninstall
```

`src/` holds the SKM skill itself — it is installed into other projects by the CLI, not managed as library content. `.claude/commands/` and `.claude/skills/` (when present) are the distributable library that SKM operates on.

## Setup

### 1. Clone and install the CLI

```bash
git clone <this-repo> ~/dev/skm-claude-skill-manager
cd ~/dev/skm-claude-skill-manager
make install
```

This creates a symlink at `~/.local/bin/skm`. Make sure that directory is on your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"   # add to ~/.zshrc or ~/.bashrc
```

To remove the symlink:

```bash
make uninstall
```

### 2. Install SKM into a project

```bash
skm install /path/to/your/project
```

Or from inside the project directory:

```bash
skm install .
```

This does two things:

1. Writes `~/.config/skm/config.json` pointing back to this repo — the bridge between the CLI and the in-Claude skill.
2. Copies `src/skills/skm/` into the target project's `.claude/skills/skm/`.

Re-run this command any time you move the repo.

## Using SKM inside Claude Code

Open a Claude Code session in your project and say any of:

- `"SKM"`
- `"SKM list"`
- `"SKM install"`
- `"SKM save"`
- `"SKM library"`
- `"SKM help"`

SKM reads `~/.config/skm/config.json` to find the library, then presents an interactive menu:

| Action | What it does |
|---|---|
| **SKM List** | Show all skills and commands in the library |
| **SKM Install** | Copy a skill or command from the library into this project |
| **SKM Save** | Copy a skill or command from this project to the library (with optional git commit) |

## Library contents

**Commands**

| Command | Description |
|---|---|
| `git-auto-commit` | Add and commit all changes with a descriptive message |
| `git-issuebranch-cleanup` | Delete remote branches for merged/closed PRs |

**Skills**

| Skill | Description |
|---|---|
| `python-http-server` | Start, list, and stop Python simple HTTP servers |

## Further reading

- [skm CLI reference](docs/skm-cli.md) — full documentation for the `skm` command-line tool

## Adding your own skills/commands

Use **SKM Save** inside Claude Code, or manually copy files into `.claude/commands/` (for commands) or `.claude/skills/<name>/` (for skills) and commit.
