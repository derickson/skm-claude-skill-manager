# claude-skill-manager

A central library and CLI tool for managing [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills and commands across projects.

## What's in this repo

```
src/
  skills/
    claude-skill-manager/
      SKILL.md       # The in-Claude interactive skill manager (installed into projects)
.claude/
  commands/          # Library of distributable slash commands
skill_manager.py     # CLI tool
Makefile             # install / uninstall
```

`src/` holds the skill manager itself — it is installed into other projects by the CLI, not managed as library content. `.claude/commands/` and `.claude/skills/` (when present) are the distributable library that the skill manager operates on.

## Setup

### 1. Clone and install the CLI

```bash
git clone <this-repo> ~/dev/claude-skill-manager
cd ~/dev/claude-skill-manager
make install
```

This creates a symlink at `~/.local/bin/skill-manager`. Make sure that directory is on your `PATH` (add `export PATH="$HOME/.local/bin:$PATH"` to your shell profile if needed).

To remove the symlink:

```bash
make uninstall
```

### 2. Install the skill into a project

```bash
skill-manager install /path/to/your/project
```

Or from inside the project directory:

```bash
skill-manager install .
```

This does two things:

1. Writes `~/.config/skill-manager/config.json` pointing back to this repo — the bridge between the CLI and the in-Claude skill.
2. Copies `src/skills/claude-skill-manager/` into the target project's `.claude/skills/`.

Re-run this command any time you move the repo.

## Using the skill inside Claude Code

Open a Claude Code session in your project and say any of:

- `"list skills in the library"`
- `"install a skill"`
- `"install a command"`
- `"save skill to library"`
- `"save command to library"`
- `"skill library"`

The skill reads `~/.config/skill-manager/config.json` to find the library, then presents an interactive menu for listing, installing, and saving skills and commands.

## Commands in this library

| Command | Description |
|---|---|
| `git-auto-commit` | Add and commit all changes with a descriptive message |
| `git-issuebranch-cleanup` | Delete remote branches for merged/closed PRs |
| `serve` | Serve a directory via Python's HTTP server |
| `serve-stop` | Stop running Python HTTP servers |
| `servers` | List and manage running Python HTTP servers |

## Adding your own skills/commands

Use the "Save" action in the in-Claude skill manager, or manually copy files into `.claude/commands/` (for commands) or `.claude/skills/<name>/` (for skills) and commit.
