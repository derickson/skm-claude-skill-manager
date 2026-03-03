# skm CLI Reference

`skm` is a Python CLI for managing Claude Code skills and commands. It requires no dependencies beyond the Python standard library.

## Installation

```bash
cd /path/to/claude-skill-manager
make install      # creates ~/.local/bin/skm -> skill_manager.py
make uninstall    # removes ~/.local/bin/skm
```

Ensure `~/.local/bin` is on your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify:

```bash
skm --help
```

## How it works

`skm` derives the library location from its own path at runtime:

```python
REPO_DIR = Path(__file__).resolve().parent
```

This means the CLI works correctly regardless of where the repo is cloned. If you move the repo, re-run `skm install` in your projects to update the config.

---

## Commands

### `skm install [target_project_path]`

Bootstraps SKM into a Claude Code project. Does two things:

**1. Writes `~/.config/skm/config.json`**

```json
{
  "repo_path": "/path/to/claude-skill-manager"
}
```

This file is read by every other `skm` command and by the in-Claude SKM skill to locate the library. Running `skm install` always refreshes it to point at the current repo location.

**2. Copies `src/skills/skm/` into the target project**

Source: `<repo>/src/skills/skm/`
Destination: `<target>/.claude/skills/skm/`

If the destination already exists, you are prompted:

```
'skm' already exists. Overwrite? [y/N]
```

Enter `y` to overwrite, anything else to skip the copy (config is still written).

**Arguments:**

| Argument | Default | Description |
|---|---|---|
| `target_project_path` | `.` (current directory) | Path to the Claude Code project to install SKM into |

**Examples:**

```bash
skm install               # install into current directory
skm install ~/dev/myapp   # install into a specific project
```

---

### `skm list`

Lists all commands and skills available in the library. Requires config to be present.

**Output:**

```
SKM library: /path/to/claude-skill-manager

Commands:
  git-auto-commit.md
  serve.md
  ...

Skills:
  my-skill/
  ...
```

**Example:**

```bash
skm list
```

---

### `skm pull <type> <name> [--force]`

Copies a command or skill from the library into the current project's `.claude/` directory.

**Arguments:**

| Argument | Description |
|---|---|
| `type` | `command` or `skill` |
| `name` | Filename of the command (e.g. `git-auto-commit.md`) or directory name of the skill |

**Flags:**

| Flag | Description |
|---|---|
| `--force`, `-f` | Skip the overwrite confirmation prompt |

If the item does not exist in the library, `skm` exits with an error and lists what is available.

If the destination already exists in the project and `--force` is not set, you are prompted:

```
'<name>' already exists. Overwrite? [y/N]
```

The destination directory (`.claude/commands/` or `.claude/skills/`) is created if it does not exist.

**Examples:**

```bash
skm pull command git-auto-commit.md
skm pull skill my-skill
skm pull command git-auto-commit.md --force   # skip prompt
```

---

### `skm push <type> <name> [--force] [--commit | --no-commit]`

Copies a command or skill from the current project into the library.

**Arguments:**

| Argument | Description |
|---|---|
| `type` | `command` or `skill` |
| `name` | Filename of the command or directory name of the skill |

**Flags:**

| Flag | Description |
|---|---|
| `--force`, `-f` | Skip the overwrite confirmation prompt |
| `--commit` | Commit the change to the library git repo without prompting |
| `--no-commit` | Skip the git commit without prompting |

`--commit` and `--no-commit` are mutually exclusive. Without either flag, you are prompted interactively:

```
Commit to library repo? [y/N]
```

If the item does not exist in the project, `skm` exits with an error and lists what is available.

If the destination already exists in the library and `--force` is not set, you are prompted:

```
'<name> (in library)' already exists. Overwrite? [y/N]
```

When committing, the commit message is:

```
SKM: add/update <name> from <current-directory-name>
```

**Examples:**

```bash
skm push command my-command.md
skm push skill my-skill --commit
skm push command my-command.md --force --no-commit
```

---

### `skm remove <type> <name> [--force]`

Removes a command or skill from the current project. Does **not** affect the library.

**Arguments:**

| Argument | Description |
|---|---|
| `type` | `command` or `skill` |
| `name` | Filename of the command or directory name of the skill |

**Flags:**

| Flag | Description |
|---|---|
| `--force`, `-f` | Skip the confirmation prompt |

If the item does not exist in the project, `skm` exits with an error and lists what is available.

Without `--force`, you are prompted:

```
Remove <type> '<name>' from this project? [y/N]
```

**Examples:**

```bash
skm remove command git-auto-commit.md
skm remove skill python-http-server
skm remove command old-command.md --force   # skip prompt
```

---

## Config file

`~/.config/skm/config.json` is written by `skm install` and read by all other subcommands and by the in-Claude SKM skill.

```json
{
  "repo_path": "/Users/you/dev/claude-skill-manager"
}
```

**Error conditions handled at startup:**

| Condition | Error message |
|---|---|
| File missing | `SKM is not configured. Run: skm install <project-path>` |
| Invalid JSON | `config.json contains invalid JSON` |
| Missing `repo_path` key | `config.json is missing 'repo_path'` |
| `repo_path` directory not found | `Library repo not found at <path>` |

---

## Relationship to the in-Claude SKM skill

The `skm` CLI and the in-Claude SKM skill are complementary:

| Task | Tool |
|---|---|
| First-time setup, installing SKM into a project | `skm install` |
| Library management from the terminal | `skm list`, `skm pull`, `skm push` |
| Library management from inside Claude Code | Say `"SKM"` to activate the in-Claude skill |

The in-Claude skill calls `skm list`, `skm pull`, and `skm push` internally, passing `--force` after confirming with the user. Both interfaces share the same config and library.
