#!/usr/bin/env python3
"""Reads HTML comment tags from TRACKING.md and builds SPRINT-INDEX.md.

Usage:
    python3 sprint-index.py 1    # rebuild index for sprint 1
    python3 sprint-index.py      # rebuild full index

Scans for tags like:
    <!-- topics:auth,api type:failure sprint:5 item:CORE-220 -->
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

from sprint_lib.utils import find_project_root, find_tracking_file


# Pattern for HTML comment tags
_TAG_RE = re.compile(
    r"<!--\s+"
    r"(?=.*\btopics?:)"   # require topics field
    r"(?P<body>[^>]+?)"
    r"\s*-->"
)


def _parse_tag(body: str) -> dict[str, str]:
    """Parse key:value pairs from tag body."""
    result: dict[str, str] = {}
    for m in re.finditer(r"(\w+):(\S+)", body):
        result[m.group(1)] = m.group(2)
    return result


def _scan_file(path: Path) -> list[dict[str, str]]:
    """Scan a file for HTML comment tags and return parsed entries."""
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    entries: list[dict[str, str]] = []
    for m in _TAG_RE.finditer(text):
        parsed = _parse_tag(m.group("body"))
        if parsed:
            entries.append(parsed)
    return entries


def main() -> None:
    sprint_filter = None
    if len(sys.argv) >= 2:
        try:
            sprint_filter = int(sys.argv[1])
        except ValueError:
            print(f"Error: Invalid sprint number '{sys.argv[1]}'", file=sys.stderr)
            sys.exit(1)

    try:
        root = find_project_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    # Collect entries from TRACKING.md
    tracking_path = find_tracking_file(root)
    all_entries = _scan_file(tracking_path)

    # Collect entries from archive files
    archive_dir = root / "Docs" / "Archive"
    if archive_dir.is_dir():
        for archive_file in sorted(archive_dir.glob("changelog-S*.md")):
            all_entries.extend(_scan_file(archive_file))

    # Filter by sprint if specified
    if sprint_filter is not None:
        sprint_key = f"S{sprint_filter}"
        # Also accept just the number
        all_entries = [
            e for e in all_entries
            if e.get("sprint", "") in (sprint_key, str(sprint_filter))
        ]

    if not all_entries:
        print("No index tags found.")
        sys.exit(0)

    # Group by topic, then by type
    # Structure: {topic: {type: [entries]}}
    index: dict[str, dict[str, list[dict[str, str]]]] = defaultdict(
        lambda: defaultdict(list)
    )

    for entry in all_entries:
        topics_raw = entry.get("topics", entry.get("topic", ""))
        if not topics_raw:
            continue  # skip entries without topics
        entry_type = entry.get("type", "general")
        topics = [t.strip() for t in topics_raw.split(",") if t.strip()]
        for topic in topics:
            index[topic][entry_type].append(entry)

    # Build output
    lines: list[str] = []
    lines.append("# Sprint Index")
    lines.append("")

    if sprint_filter is not None:
        lines.append(f"*Filtered: Sprint {sprint_filter}*")
        lines.append("")

    for topic in sorted(index.keys()):
        lines.append(f"## {topic}")
        lines.append("")
        type_groups = index[topic]
        for entry_type in sorted(type_groups.keys()):
            lines.append(f"### {entry_type}")
            lines.append("")
            for entry in type_groups[entry_type]:
                item = entry.get("item", "—")
                sprint = entry.get("sprint", "—")
                lines.append(f"- **{item}** (Sprint {sprint})")
            lines.append("")

    output_path = root / "SPRINT-INDEX.md"
    output_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Index written to {output_path}")
    print(f"  Topics: {len(index)}")
    print(f"  Entries: {len(all_entries)}")


if __name__ == "__main__":
    main()
