#!/usr/bin/env python3
"""SKM — Skill Manager CLI for Claude Code."""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent
CONFIG_PATH = Path.home() / ".config" / "skm" / "config.json"
SKILL_NAME = "skm"
ITEM_TYPES = ("command", "skill")


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config() -> dict:
    """Load and validate ~/.config/skm/config.json. Exits with a clear message on any problem."""
    if not CONFIG_PATH.exists():
        _die(
            f"SKM is not configured.\n"
            f"  Run: skm install <project-path>"
        )

    try:
        config = json.loads(CONFIG_PATH.read_text())
    except json.JSONDecodeError as exc:
        _die(f"{CONFIG_PATH} contains invalid JSON: {exc}\n  Re-run: skm install <project-path>")

    if "repo_path" not in config:
        _die(
            f"{CONFIG_PATH} is missing 'repo_path'.\n"
            f"  Re-run: skm install <project-path>"
        )

    repo = Path(config["repo_path"])
    if not repo.is_dir():
        _die(
            f"Library repo not found at {repo}\n"
            f"  If you moved the repo, re-run: skm install <project-path>"
        )

    return config


def _library_root(config: dict) -> Path:
    return Path(config["repo_path"])


def _library_dir(config: dict, item_type: str) -> Path:
    base = _library_root(config) / ".claude"
    return base / ("commands" if item_type == "command" else "skills")


def _project_dir(item_type: str) -> Path:
    base = Path.cwd() / ".claude"
    return base / ("commands" if item_type == "command" else "skills")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _die(msg: str, code: int = 1) -> None:
    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(code)


def _list_names(directory: Path, dirs_only: bool = False) -> list[str]:
    if not directory.is_dir():
        return []
    if dirs_only:
        return sorted(p.name for p in directory.iterdir() if p.is_dir())
    return sorted(p.name for p in directory.iterdir() if p.is_file())


def _copy_item(src: Path, dst: Path, item_type: str) -> None:
    if item_type == "skill":
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
    else:
        shutil.copy2(src, dst)


def _confirm_overwrite(label: str) -> bool:
    answer = input(f"'{label}' already exists. Overwrite? [y/N] ").strip().lower()
    return answer == "y"


# ---------------------------------------------------------------------------
# skm install  — bootstrap SKM skill into a project
# ---------------------------------------------------------------------------

def cmd_install(args):
    target = Path(args.target_project_path).resolve()

    if not target.is_dir():
        _die(f"Target path does not exist: {target}")

    _write_config()
    _install_skill(target)
    print()
    print('Done. In a Claude Code session say: "SKM list", "SKM install", or "SKM save"')


def _write_config() -> None:
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    config = {"repo_path": str(REPO_DIR)}
    CONFIG_PATH.write_text(json.dumps(config, indent=2) + "\n")
    print(f"Config written: {CONFIG_PATH}")
    print(f"  repo_path = {REPO_DIR}")


def _install_skill(target: Path) -> None:
    src = REPO_DIR / "src" / "skills" / SKILL_NAME
    dst = target / ".claude" / "skills" / SKILL_NAME

    if not src.is_dir():
        _die(f"Skill source not found: {src}")

    if dst.exists() and not _confirm_overwrite(SKILL_NAME):
        print("Skipped.")
        return

    dst.mkdir(parents=True, exist_ok=True)
    for item in src.iterdir():
        dest_item = dst / item.name
        if item.is_dir():
            if dest_item.exists():
                shutil.rmtree(dest_item)
            shutil.copytree(item, dest_item)
        else:
            shutil.copy2(item, dest_item)

    print(f"Installed '{SKILL_NAME}' -> {dst}")


# ---------------------------------------------------------------------------
# skm list  — show library contents
# ---------------------------------------------------------------------------

def cmd_list(args):
    config = load_config()
    lib = _library_root(config)

    commands = _list_names(_library_dir(config, "command"))
    skills = _list_names(_library_dir(config, "skill"), dirs_only=True)

    print(f"SKM library: {lib}")
    print()
    print("Commands:")
    if commands:
        for name in commands:
            print(f"  {name}")
    else:
        print("  (none)")

    print()
    print("Skills:")
    if skills:
        for name in skills:
            print(f"  {name}/")
    else:
        print("  (none)")


# ---------------------------------------------------------------------------
# skm pull  — copy from library into this project
# ---------------------------------------------------------------------------

def cmd_pull(args):
    config = load_config()
    item_type = args.type
    name = args.name
    dirs_only = item_type == "skill"

    src = _library_dir(config, item_type) / name
    project_dir = _project_dir(item_type)
    dst = project_dir / name

    if not src.exists():
        available = _list_names(_library_dir(config, item_type), dirs_only=dirs_only)
        msg = f"{item_type} '{name}' not found in library."
        if available:
            msg += f"\n  Available: {', '.join(available)}"
        else:
            msg += f"\n  Library {item_type} directory is empty or missing."
        _die(msg)

    if dst.exists() and not args.force:
        if not _confirm_overwrite(name):
            print("Aborted.")
            sys.exit(0)

    project_dir.mkdir(parents=True, exist_ok=True)
    _copy_item(src, dst, item_type)
    print(f"Pulled {item_type} '{name}' -> {dst}")


# ---------------------------------------------------------------------------
# skm push  — copy from this project into the library
# ---------------------------------------------------------------------------

def cmd_push(args):
    config = load_config()
    item_type = args.type
    name = args.name
    dirs_only = item_type == "skill"

    project_dir = _project_dir(item_type)
    src = project_dir / name
    lib_dir = _library_dir(config, item_type)
    dst = lib_dir / name

    if not src.exists():
        available = _list_names(project_dir, dirs_only=dirs_only)
        msg = f"{item_type} '{name}' not found in this project at {src}."
        if available:
            msg += f"\n  Available: {', '.join(available)}"
        else:
            msg += f"\n  Project {item_type} directory is empty or missing."
        _die(msg)

    if dst.exists() and not args.force:
        if not _confirm_overwrite(f"{name} (in library)"):
            print("Aborted.")
            sys.exit(0)

    lib_dir.mkdir(parents=True, exist_ok=True)
    _copy_item(src, dst, item_type)
    print(f"Pushed {item_type} '{name}' -> {dst}")

    if args.commit:
        _git_commit(_library_root(config), name)
    elif not args.no_commit:
        if input("Commit to library repo? [y/N] ").strip().lower() == "y":
            _git_commit(_library_root(config), name)


def _git_commit(lib: Path, name: str) -> None:
    project_name = Path.cwd().name
    msg = f"SKM: add/update {name} from {project_name}"

    result = subprocess.run(
        ["git", "add", ".claude/"],
        cwd=lib,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        _die(f"git add failed:\n{result.stderr.strip()}")

    result = subprocess.run(
        ["git", "commit", "-m", msg],
        cwd=lib,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        _die(f"git commit failed:\n{result.stderr.strip()}")

    print(f"Committed: {msg}")


# ---------------------------------------------------------------------------
# Argument parser
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        prog="skm",
        description="SKM — Manage Claude Code skills and commands.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # --- install ---
    p = subparsers.add_parser("install", help="Bootstrap SKM into a project and write config.")
    p.add_argument(
        "target_project_path",
        nargs="?",
        default=".",
        help="Path to the Claude Code project (default: current directory).",
    )
    p.set_defaults(func=cmd_install)

    # --- list ---
    p = subparsers.add_parser("list", help="List commands and skills available in the library.")
    p.set_defaults(func=cmd_list)

    # --- pull ---
    p = subparsers.add_parser("pull", help="Copy a command or skill from the library into this project.")
    p.add_argument("type", choices=ITEM_TYPES)
    p.add_argument("name", help="Name of the command file or skill directory.")
    p.add_argument(
        "--force", "-f",
        action="store_true",
        help="Skip overwrite confirmation (use after obtaining consent via AskUserQuestion).",
    )
    p.set_defaults(func=cmd_pull)

    # --- push ---
    p = subparsers.add_parser("push", help="Copy a command or skill from this project into the library.")
    p.add_argument("type", choices=ITEM_TYPES)
    p.add_argument("name", help="Name of the command file or skill directory.")
    p.add_argument(
        "--force", "-f",
        action="store_true",
        help="Skip overwrite confirmation (use after obtaining consent via AskUserQuestion).",
    )
    commit_group = p.add_mutually_exclusive_group()
    commit_group.add_argument(
        "--commit",
        action="store_true",
        help="Commit the change to the library git repo without prompting.",
    )
    commit_group.add_argument(
        "--no-commit",
        action="store_true",
        help="Skip git commit without prompting.",
    )
    p.set_defaults(func=cmd_push)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
