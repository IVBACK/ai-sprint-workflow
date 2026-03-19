#!/usr/bin/env python3
"""Sprint-end chore automation: size check, archive, cleanup.

Usage:
    python3 sprint-close.py 1              # sprint number
    python3 sprint-close.py 1 --dry-run    # show what would happen
"""

import sys

from pathlib import Path

from sprint_lib.utils import find_project_root, find_tracking_file
from sprint_lib.tracking_parser import parse as parse_tracking
from sprint_lib.gate_parser import find_gate_file
from sprint_lib.writers import clear_session_notes


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 sprint-close.py <sprint_number> [--dry-run]", file=sys.stderr)
        sys.exit(1)

    try:
        sprint_n = int(sys.argv[1])
    except ValueError:
        print(f"Error: Invalid sprint number '{sys.argv[1]}'", file=sys.stderr)
        sys.exit(1)

    dry_run = "--dry-run" in sys.argv
    sprint_label = f"Sprint {sprint_n}"
    sprint_key = f"S{sprint_n}"

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
    actions: list[str] = []

    # ── Step 1: Size check ──────────────────────────────────────────────
    changelog_lines: list[str] = []
    for key, entries in tracking.changelog_entries.items():
        if sprint_key in key or sprint_label in key:
            changelog_lines.extend(entries)

    line_count = len(changelog_lines)
    if line_count > 50:
        print(f"WARNING: Changelog for {sprint_label} has {line_count} lines (>50)")
    else:
        print(f"Changelog for {sprint_label}: {line_count} lines (OK)")

    # ── Step 2: Archive ─────────────────────────────────────────────────
    archive_dir = root / "Docs" / "Archive"
    archive_file = archive_dir / f"changelog-{sprint_key}.md"

    if changelog_lines:
        content = f"# Changelog — {sprint_label}\n\n"
        for entry in changelog_lines:
            content += f"- {entry}\n"

        if dry_run:
            print(f"[DRY RUN] Would create {archive_file} with {line_count} entries")
            actions.append(f"Archive {line_count} changelog entries to {archive_file}")
        else:
            try:
                archive_dir.mkdir(parents=True, exist_ok=True)
                archive_file.write_text(content, encoding="utf-8")
                print(f"Archived {line_count} changelog entries to {archive_file}")
                actions.append(f"Archived {line_count} entries")
            except OSError as e:
                print(f"Error: Could not write archive file: {e}", file=sys.stderr)
                sys.exit(1)
    else:
        print(f"No changelog entries found for {sprint_label}")

    # ── Step 3: Session notes archive ──────────────────────────────────
    session_notes = tracking.session_notes
    if session_notes:
        notes_file = archive_dir / f"session-notes-{sprint_key}.md"
        content = f"# Session Notes — {sprint_label}\n\n"
        content += "| # | Type | Item | Note | Time |\n"
        content += "|---|------|------|------|------|\n"
        for n in session_notes:
            item_str = n.item if n.item else "—"
            content += f"| {n.seq} | {n.note_type} | {item_str} | {n.text} | {n.timestamp} |\n"

        if dry_run:
            print(f"[DRY RUN] Would archive {len(session_notes)} session notes to {notes_file}")
        else:
            try:
                archive_dir.mkdir(parents=True, exist_ok=True)
                notes_file.write_text(content, encoding="utf-8")
                print(f"Archived {len(session_notes)} session notes to {notes_file}")
                # Clear session notes from TRACKING.md (keep header, remove data rows)
                clear_session_notes(tracking_path)
                print(f"Cleared session notes from {tracking_path.name}")
            except OSError as e:
                print(f"Warning: Could not archive session notes: {e}", file=sys.stderr)
        actions.append(f"Session notes archived + cleared: {len(session_notes)} entries")
    else:
        print(f"No session notes found for {sprint_label}")

    # ── Step 4: Gate report archive + cleanup ───────────────────────────
    for gate_type in ["entry", "close"]:
        gate_file = find_gate_file(root, sprint_n, gate_type)
        if gate_file is not None:
            archive_gate = archive_dir / f"{gate_type}-gate-{sprint_key}.md"
            if dry_run:
                print(f"[DRY RUN] Would archive {gate_file.name} → {archive_gate}")
            else:
                try:
                    archive_dir.mkdir(parents=True, exist_ok=True)
                    import shutil
                    shutil.copy2(gate_file, archive_gate)
                    gate_file.unlink()
                    print(f"Archived {gate_file.name} → {archive_gate.name}")
                except OSError as e:
                    print(f"Warning: Could not archive {gate_file.name}: {e}", file=sys.stderr)
            actions.append(f"{gate_type.title()} Gate archived: {archive_gate.name}")
        else:
            print(f"No {gate_type} gate file found for S{sprint_n}")

    # ── Summary ─────────────────────────────────────────────────────────
    print()
    prefix = "[DRY RUN] " if dry_run else ""
    print(f"{prefix}Sprint close summary for S{sprint_n}:")
    if actions:
        for a in actions:
            print(f"  - {a}")
    else:
        print("  No actions taken.")


if __name__ == "__main__":
    main()
