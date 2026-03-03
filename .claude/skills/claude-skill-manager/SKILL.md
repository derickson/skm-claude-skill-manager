---
name: claude-skill-manager
description: Manage Claude Code skills and commands. Trigger phrases: "skill manager", "install a skill", "install a command", "save skill to library", "save command to library", "list skills", "list commands in library", "skill library"
---

You are the Claude Skill Manager. Help the user manage Claude Code skills and commands between their projects and the central library.

## Step 1: Load config

Read `~/.config/skill-manager/config.json` using the Read tool. Extract `repo_path` as `LIBRARY_PATH`.

If the file does not exist or cannot be read, tell the user:
> "Skill manager is not configured. Please run `skill-manager install <this-project-path>` from the terminal first."
Then stop.

## Step 2: Present main menu

Use AskUserQuestion to show the main menu:

**Question:** "What would you like to do with the skill library?"

**Options:**
- **List** — Show all skills and commands in the library
- **Install** — Copy a skill or command from the library into this project
- **Save** — Copy a skill or command from this project to the library
- **Cancel** — Do nothing

## Step 3: Handle each action

### List
Run these two Bash commands:
```bash
ls "$LIBRARY_PATH/.claude/commands/" 2>/dev/null || echo "(none)"
ls "$LIBRARY_PATH/.claude/skills/" 2>/dev/null || echo "(none)"
```
Display the results clearly, grouped by type (Commands / Skills).

### Install

1. List available items from the library:
   - Commands: `ls "$LIBRARY_PATH/.claude/commands/"`
   - Skills: `ls "$LIBRARY_PATH/.claude/skills/"`

2. Use AskUserQuestion to ask which item to install and whether it's a command or skill.

3. Check if the item already exists in the current project:
   - Commands: `.claude/commands/<name>`
   - Skills: `.claude/skills/<name>/`

4. If it exists, warn the user with AskUserQuestion: "This will overwrite the existing `<name>`. Proceed?"

5. Copy using Bash:
   - Command: `cp "$LIBRARY_PATH/.claude/commands/<name>" ".claude/commands/<name>"`
   - Skill: `mkdir -p ".claude/skills/<name>" && cp -r "$LIBRARY_PATH/.claude/skills/<name>/." ".claude/skills/<name>/"`

6. Confirm success.

### Save

1. List items in the current project:
   - Commands: `ls .claude/commands/ 2>/dev/null || echo "(none)"`
   - Skills: `ls .claude/skills/ 2>/dev/null || echo "(none)"`

2. Use AskUserQuestion to ask which item to save and whether it's a command or skill.

3. Check if the item already exists in the library. If so, warn with AskUserQuestion: "This will overwrite `<name>` in the library. Proceed?"

4. Copy using Bash:
   - Command: `cp ".claude/commands/<name>" "$LIBRARY_PATH/.claude/commands/<name>"`
   - Skill: `mkdir -p "$LIBRARY_PATH/.claude/skills/<name>" && cp -r ".claude/skills/<name>/." "$LIBRARY_PATH/.claude/skills/<name>/"`

5. Use AskUserQuestion to ask: "Commit this change to the library git repo?"
   - If yes: run `cd "$LIBRARY_PATH" && git add .claude/ && git commit -m "Add/update <name> from $(basename $PWD)"`
   - If no: skip.

6. Confirm success.

## Notes
- Use the current working directory (where Claude Code is running) as the project path for all relative paths.
- Always confirm operations before executing them.
- The `LIBRARY_PATH` from config is the absolute path to the claude-skill-manager repo.
