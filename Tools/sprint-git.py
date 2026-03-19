#!/usr/bin/env python3
"""Git ceremony wrapper for sprint context.

Usage:
    python3 sprint-git.py init 3
    python3 sprint-git.py commit CORE-001 "feat: add login endpoint"
    python3 sprint-git.py push
    python3 sprint-git.py merge 3
    python3 sprint-git.py abort 3
"""

import re
import subprocess
import sys
from pathlib import Path


def _detect_main_branch() -> str:
    """Detect the default branch name (main or master)."""
    for name in ["main", "master"]:
        r = subprocess.run(
            ["git", "rev-parse", "--verify", name],
            capture_output=True, text=True,
        )
        if r.returncode == 0:
            return name
    return "main"


def _run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a git command, print it, and check return code."""
    print(f"  $ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout.strip():
        print(f"    {result.stdout.strip()}")
    if result.returncode != 0:
        if result.stderr.strip():
            print(f"    Error: {result.stderr.strip()}", file=sys.stderr)
        if check:
            sys.exit(1)
    return result


def _ref_exists(ref: str) -> bool:
    """Check if a git ref (branch or tag) exists."""
    r = subprocess.run(["git", "rev-parse", "--verify", ref], capture_output=True, text=True)
    return r.returncode == 0


def cmd_init(sprint_n: int) -> None:
    """Create sprint branch and start tag."""
    branch = f"sprint-{sprint_n}-impl"
    tag = f"sprint-{sprint_n}-start"
    if _ref_exists(branch):
        print(f"Error: Branch '{branch}' already exists.", file=sys.stderr)
        sys.exit(1)
    if _ref_exists(tag):
        print(f"Error: Tag '{tag}' already exists.", file=sys.stderr)
        sys.exit(1)
    print(f"Initializing sprint {sprint_n}...")
    _run(["git", "tag", tag])
    _run(["git", "checkout", "-b", branch])
    print(f"Done. Branch '{branch}' created, tag '{tag}' set.")


def cmd_commit(item: str, message: str) -> None:
    """Commit staged changes with item prefix. Stages tracked files only (no -A)."""
    full_msg = f"[{item}] {message}"
    print(f"Committing: {full_msg}")
    _run(["git", "add", "-u"])  # stage tracked files only, never untracked/secrets
    _run(["git", "commit", "-m", full_msg])
    print("Done.")


def cmd_push() -> None:
    """Push current branch to origin."""
    print("Pushing to origin...")
    _run(["git", "push", "origin", "HEAD"])
    print("Done.")


def _update_evidence_hashes(sprint_n: int, squash_hash: str) -> None:
    """Update TRACKING evidence column: replace pre-squash hashes with squash hash."""
    tracking = Path("TRACKING.md")
    if not tracking.exists():
        return
    text = tracking.read_text(encoding="utf-8")
    sprint_key = f"S{sprint_n}"
    lines = text.splitlines(keepends=True)
    updated = False
    for i, line in enumerate(lines):
        # Match sprint board rows for this sprint
        if f"| {sprint_key} |" in line or f"|{sprint_key}|" in line or f"| {sprint_key}|" in line:
            # Replace any "commit <hash>" evidence with squash hash
            new_line = re.sub(r"commit [a-f0-9]{7,}", f"commit {squash_hash} (squash)", line)
            if new_line != line:
                lines[i] = new_line
                updated = True
    if updated:
        tracking.write_text("".join(lines), encoding="utf-8")
        _run(["git", "add", "TRACKING.md"])
        _run(["git", "commit", "--amend", "--no-edit"], check=False)
        print(f"  Evidence updated: pre-squash hashes → {squash_hash} (squash)")


def cmd_merge(sprint_n: int) -> None:
    """Squash merge sprint branch into main and tag close."""
    branch = f"sprint-{sprint_n}-impl"
    tag = f"sprint-{sprint_n}-close"
    commit_msg = f"Sprint {sprint_n}: squash merge"

    default_branch = _detect_main_branch()
    print(f"WARNING: This will squash-merge '{branch}' into {default_branch} and delete the branch.")
    print(f"  - Checkout {default_branch}")
    print(f"  - Squash merge {branch}")
    print(f"  - Commit: '{commit_msg}'")
    print(f"  - Tag: {tag}")
    print(f"  - Delete branch: {branch}")
    print()
    print("Proceeding...")

    _run(["git", "checkout", default_branch])
    _run(["git", "merge", "--squash", branch])
    _run(["git", "commit", "-m", commit_msg])

    # Get squash commit hash and update TRACKING evidence
    squash_hash = _run(["git", "rev-parse", "--short", "HEAD"], check=False).stdout.strip()
    if squash_hash:
        _update_evidence_hashes(sprint_n, squash_hash)

    _run(["git", "tag", tag])
    _run(["git", "branch", "-D", branch])  # -D required: squash merge leaves branch "unmerged"
    print(f"Done. Sprint {sprint_n} merged and tagged.")


def cmd_abort(sprint_n: int) -> None:
    """Delete sprint branch and remove start tag."""
    branch = f"sprint-{sprint_n}-impl"
    tag = f"sprint-{sprint_n}-start"

    default_branch = _detect_main_branch()
    print(f"WARNING: This will delete branch '{branch}' and tag '{tag}'.")
    print(f"  - Checkout {default_branch}")
    print(f"  - Force delete branch: {branch}")
    print(f"  - Delete tag: {tag}")
    print()
    print("Proceeding...")

    _run(["git", "checkout", default_branch])
    _run(["git", "branch", "-D", branch])
    _run(["git", "tag", "-d", tag])
    print(f"Done. Sprint {sprint_n} aborted.")


def main() -> None:
    if len(sys.argv) < 2:
        print(
            "Usage: python3 sprint-git.py <command> [args]\n"
            "Commands: init, commit, push, merge, abort",
            file=sys.stderr,
        )
        sys.exit(1)

    command = sys.argv[1]

    def _sprint_n(arg: str) -> int:
        try:
            return int(arg)
        except ValueError:
            print(f"Error: '{arg}' is not a valid sprint number", file=sys.stderr)
            sys.exit(1)

    if command == "init":
        if len(sys.argv) < 3:
            print("Usage: python3 sprint-git.py init <sprint_number>", file=sys.stderr)
            sys.exit(1)
        cmd_init(_sprint_n(sys.argv[2]))

    elif command == "commit":
        if len(sys.argv) < 4:
            print(
                'Usage: python3 sprint-git.py commit <ITEM> "<message>"',
                file=sys.stderr,
            )
            sys.exit(1)
        cmd_commit(sys.argv[2], sys.argv[3])

    elif command == "push":
        cmd_push()

    elif command == "merge":
        if len(sys.argv) < 3:
            print("Usage: python3 sprint-git.py merge <sprint_number>", file=sys.stderr)
            sys.exit(1)
        cmd_merge(_sprint_n(sys.argv[2]))

    elif command == "abort":
        if len(sys.argv) < 3:
            print("Usage: python3 sprint-git.py abort <sprint_number>", file=sys.stderr)
            sys.exit(1)
        cmd_abort(_sprint_n(sys.argv[2]))

    else:
        print(f"Error: Unknown command '{command}'", file=sys.stderr)
        print("Commands: init, commit, push, merge, abort", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
