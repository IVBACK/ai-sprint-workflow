#!/usr/bin/env python3
"""Appends row to TRACKING.md §Performance Baseline Log.

Usage:
    python3 sprint-baseline.py coverage 82 "%" "pytest --cov"
    python3 sprint-baseline.py response_time 12 ms "httpx benchmark"
"""

import re
import sys

from sprint_lib.utils import find_project_root, find_tracking_file
from sprint_lib.tracking_parser import parse as parse_tracking
from sprint_lib.writers import add_baseline_entry
from sprint_lib.errors import SprintToolError


def _extract_sprint(focus: str) -> str:
    """Extract sprint label like 'S1' from current_focus text."""
    # Try "S1" shorthand first, then "Sprint 1" long form
    m = re.search(r"\bS(\d+)\b", focus)
    if m:
        return m.group(0)
    m = re.search(r"Sprint\s+(\d+)", focus, re.IGNORECASE)
    if m:
        return f"S{m.group(1)}"
    return ""


def main() -> None:
    if len(sys.argv) < 5:
        print(
            "Usage: python3 sprint-baseline.py <metric> <value> <unit> <method>",
            file=sys.stderr,
        )
        sys.exit(1)

    metric = sys.argv[1]
    value = sys.argv[2]
    unit = sys.argv[3]
    method = sys.argv[4]

    try:
        root = find_project_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    tracking_path = find_tracking_file(root)
    if not tracking_path.exists():
        print(f"Error: TRACKING.md not found at {tracking_path}", file=sys.stderr)
        sys.exit(1)

    tracking = parse_tracking(tracking_path)
    sprint = _extract_sprint(tracking.current_focus)
    if not sprint:
        print(
            "Error: Could not determine current sprint from TRACKING.md current_focus",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        add_baseline_entry(tracking_path, sprint, metric, value, unit, method)
    except SprintToolError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(e.exit_code)

    print(f"Baseline entry added to TRACKING.md")
    print(f"  Sprint: {sprint}")
    print(f"  Metric: {metric} = {value} {unit}")
    print(f"  Method: {method}")


if __name__ == "__main__":
    main()
