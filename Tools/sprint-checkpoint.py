#!/usr/bin/env python3
"""Updates CLAUDE.md §Last Checkpoint + TRACKING.md §Working Context.

Usage:
    python3 sprint-checkpoint.py "Entry Gate complete — S1"
    python3 sprint-checkpoint.py "Implementation in progress — S1, CORE-003 done"
    python3 sprint-checkpoint.py "Implementing CORE-001" --task "CORE-001 API endpoints" --doing "Writing tests"
"""

import re
import sys
from datetime import datetime, timezone

from sprint_lib.utils import find_project_root, find_tracking_file
from sprint_lib.tracking_parser import parse as parse_tracking
from sprint_lib.writers import update_checkpoint, update_working_context
from sprint_lib.errors import SprintToolError


_NEXT_STEP_MAP = {
    "entry gate complete": "Start implementation",
    "implementation complete": "Run Close Gate",
    "close gate complete": "Sprint retrospective",
    "close gate passed": "Start next sprint planning",
    "implementation in progress": "Continue implementation",
    "planning complete": "Run Entry Gate",
}


def _derive_next_step(status: str) -> str:
    """Derive a reasonable next step from the status text."""
    lower = status.lower()
    for pattern, step in _NEXT_STEP_MAP.items():
        if pattern in lower:
            return step
    return "Review and continue"


def _parse_args(argv: list[str]) -> tuple[str, dict[str, str]]:
    """Parse positional status + optional --task/--doing/--decisions/--blockers flags."""
    status = ""
    wc: dict[str, str] = {}
    i = 1
    while i < len(argv):
        if argv[i] == "--task" and i + 1 < len(argv):
            wc["task"] = argv[i + 1]; i += 2
        elif argv[i] == "--doing" and i + 1 < len(argv):
            wc["doing"] = argv[i + 1]; i += 2
        elif argv[i] == "--decisions" and i + 1 < len(argv):
            wc["decisions"] = argv[i + 1]; i += 2
        elif argv[i] == "--blockers" and i + 1 < len(argv):
            wc["blockers"] = argv[i + 1]; i += 2
        elif not status:
            status = argv[i]; i += 1
        else:
            i += 1
    return status, wc


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: sprint-checkpoint.py <status> [--task T] [--doing D] [--decisions D] [--blockers B]",
              file=sys.stderr)
        sys.exit(1)

    status_text, wc_fields = _parse_args(sys.argv)

    if not status_text:
        print("Error: status text required", file=sys.stderr)
        sys.exit(1)

    try:
        root = find_project_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    claude_md = root / "CLAUDE.md"
    if not claude_md.exists():
        print(f"Error: CLAUDE.md not found at {claude_md}", file=sys.stderr)
        sys.exit(1)

    # Get current focus from TRACKING.md
    focus = ""
    tracking_path = None
    try:
        tracking_path = find_tracking_file(root)
        if tracking_path.exists():
            tracking = parse_tracking(tracking_path)
            focus = tracking.current_focus
    except Exception:
        pass

    if not focus:
        focus = "Unknown"

    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    next_step = _derive_next_step(status_text)

    # Update CLAUDE.md Last Checkpoint
    try:
        update_checkpoint(claude_md, date, focus, status_text, next_step)
    except SprintToolError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(e.exit_code)

    print(f"Checkpoint updated in CLAUDE.md")
    print(f"  Date:        {date}")
    print(f"  Focus:       {focus}")
    print(f"  Status:      {status_text}")
    print(f"  Next step:   {next_step}")

    # Update TRACKING.md Working Context (if any --task/--doing flags given)
    if wc_fields and tracking_path and tracking_path.exists():
        try:
            update_working_context(tracking_path, **wc_fields)
            print(f"Working Context updated in TRACKING.md")
            for k, v in wc_fields.items():
                print(f"  {k.capitalize():12}: {v}")
        except SprintToolError as e:
            print(f"Warning: Working Context update failed: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
