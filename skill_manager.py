#!/usr/bin/env python3
"""Claude Skill Manager — CLI tool for managing Claude Code skills and commands."""

import argparse
import json
import shutil
import sys
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent
CONFIG_PATH = Path.home() / ".config" / "skill-manager" / "config.json"
SKILL_NAME = "claude-skill-manager"


def write_config():
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    config = {"repo_path": str(REPO_DIR)}
    CONFIG_PATH.write_text(json.dumps(config, indent=2) + "\n")
    print(f"Config written to {CONFIG_PATH}")
    print(f"  repo_path = {REPO_DIR}")


def install_skill(target: Path):
    src = REPO_DIR / ".claude" / "skills" / SKILL_NAME
    dst = target / ".claude" / "skills" / SKILL_NAME

    if not src.exists():
        print(f"Error: skill source not found at {src}", file=sys.stderr)
        sys.exit(1)

    if dst.exists():
        answer = input(f"'{SKILL_NAME}' already exists in {target}. Overwrite? [y/N] ").strip().lower()
        if answer != "y":
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

    print(f"Installed '{SKILL_NAME}' into {dst}")


def cmd_install(args):
    target = Path(args.target_project_path).resolve()

    if not target.exists():
        print(f"Error: target path does not exist: {target}", file=sys.stderr)
        sys.exit(1)

    write_config()
    install_skill(target)
    print()
    print("Done. Open a Claude Code session in your project and say:")
    print('  "list skills in the library"')


def main():
    parser = argparse.ArgumentParser(
        prog="skill-manager",
        description="Manage Claude Code skills and commands.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    install_parser = subparsers.add_parser(
        "install",
        help="Write config and install the skill manager into a project.",
    )
    install_parser.add_argument(
        "target_project_path",
        nargs="?",
        default=".",
        help="Path to the target Claude Code project (default: current directory).",
    )
    install_parser.set_defaults(func=cmd_install)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
