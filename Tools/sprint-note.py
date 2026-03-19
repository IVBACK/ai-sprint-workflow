#!/usr/bin/env python3
"""Session journal — append-only notes for decisions, attempts, observations.

Usage:
    sprint-note.py <type> <text> [--item CORE-NNN]
    sprint-note.py --list [--last N]
    sprint-note.py --artifact <title> [--item CORE-NNN] < content

Types: decision, attempt, side-effect, observation, artifact

Examples:
    sprint-note.py decision "Use keyword matching instead of LLM for classify"
    sprint-note.py attempt "Tried regex parser — too brittle for nested tables" --item CORE-012
    sprint-note.py observation "PreCompact destroys ~60% of session context"
    sprint-note.py --list --last 5
    sprint-note.py --artifact "Auth middleware analysis" --item CORE-007 < report.md
"""

import argparse
import re
import sys
from pathlib import Path

from sprint_lib.utils import find_project_root, find_tracking_file
from sprint_lib import tracking_parser, writers
from sprint_lib.models import NOTE_TYPES
from sprint_lib.errors import SetupError


def _get_sprint_number(data) -> int:
    """Extract sprint number from current focus."""
    if data.current_focus:
        m = re.search(r"Sprint\s+(\d+)", data.current_focus)
        if m:
            return int(m.group(1))
    return 0


def cmd_add(args, tracking_path):
    """Add a session note."""
    seq = writers.append_session_note(
        tracking_path,
        note_type=args.type,
        text=args.text,
        item=args.item or "",
    )
    item_str = f" [{args.item}]" if args.item else ""
    print(f"#{seq} {args.type}{item_str}: {args.text}")


def cmd_list(args, tracking_path):
    """List recent session notes."""
    data = tracking_parser.parse(tracking_path)
    notes = tracking_parser.get_latest_session_notes(data, count=args.last)
    if not notes:
        print("No session notes.")
        return
    for n in notes:
        item_str = f" [{n.item}]" if n.item and n.item != "—" else ""
        print(f"  #{n.seq} {n.note_type}{item_str}: {n.text} ({n.timestamp})")


def cmd_artifact(args, tracking_path):
    """Save long-form content as artifact file + session note pointer."""
    root = tracking_path.parent
    # Handle .dev/ tracking location
    if root.name == ".dev":
        root = root.parent

    data = tracking_parser.parse(tracking_path)
    sprint_n = _get_sprint_number(data)
    sprint_key = f"S{sprint_n}" if sprint_n > 0 else "S0"

    # Build artifact filename
    item_slug = args.item.replace("-", "") if args.item else "general"
    # Sanitize title for filename
    title_slug = re.sub(r"[^a-zA-Z0-9]+", "-", args.artifact).strip("-").lower()[:40]
    filename = f"{sprint_key}-{item_slug}-{title_slug}.md"

    artifact_dir = root / "Docs" / "Artifacts"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = artifact_dir / filename

    # Read content from stdin
    content = sys.stdin.read()
    if not content.strip():
        print("Error: No content provided on stdin.", file=sys.stderr)
        sys.exit(1)

    # Write artifact
    header = f"# {args.artifact}\n\n"
    if args.item:
        header += f"**Item:** {args.item}  \n"
    header += f"**Sprint:** {sprint_key}  \n\n---\n\n"
    artifact_path.write_text(header + content, encoding="utf-8")

    # Add session note as pointer
    rel_path = artifact_path.relative_to(root)
    note_text = f"Artifact: {args.artifact} → {rel_path}"
    seq = writers.append_session_note(
        tracking_path,
        note_type="artifact",
        text=note_text,
        item=args.item or "",
    )

    print(f"#{seq} artifact: {args.artifact} → {artifact_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Session journal — append-only notes.",
    )
    parser.add_argument(
        "--list", action="store_true",
        help="List recent session notes",
    )
    parser.add_argument(
        "--last", type=int, default=10,
        help="Number of recent notes to show (default: 10)",
    )
    parser.add_argument(
        "--artifact", metavar="TITLE",
        help="Save stdin as artifact file with TITLE",
    )
    parser.add_argument(
        "--item", default="",
        help="Link note to CORE-NNN item",
    )
    parser.add_argument(
        "type", nargs="?", choices=sorted(NOTE_TYPES),
        help="Note type",
    )
    parser.add_argument(
        "text", nargs="?", default="",
        help="Note text",
    )

    args = parser.parse_args()

    # Find project root and tracking file
    try:
        root = find_project_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    tracking_path = find_tracking_file(root)
    if not tracking_path.exists():
        raise SetupError(f"Tracking file not found: {tracking_path}")

    # Route to subcommand
    if args.artifact:
        cmd_artifact(args, tracking_path)
    elif args.list:
        cmd_list(args, tracking_path)
    elif args.type and args.text:
        cmd_add(args, tracking_path)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except (SetupError,) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(getattr(e, "exit_code", 1))
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)
