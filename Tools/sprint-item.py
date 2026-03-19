#!/usr/bin/env python3
"""Sprint item status transitions — single responsibility: status + changelog."""

import sys
from pathlib import Path

from sprint_lib.utils import find_project_root, find_tracking_file
from sprint_lib import tracking_parser, writers
from sprint_lib.models import VALID_TRANSITIONS, VALID_STATUSES
from sprint_lib.errors import ItemNotFoundError, InvalidTransitionError, SetupError


ROADMAP_CANDIDATES = [
    Path("Docs") / "Planning" / "Roadmap.md",
    Path("Docs") / "Roadmap.md",
    Path("Roadmap.md"),
]


def _find_roadmap(root: Path) -> Path | None:
    """Return roadmap path if it exists, or None."""
    for candidate in ROADMAP_CANDIDATES:
        full = root / candidate
        if full.exists():
            return full
    return None


def _log_encounter_if_applicable(
    tracking_path: Path, data, item_id: str, note: str, sprint_label: str
) -> None:
    """If a predicted failure mode matches this item, log a failure encounter.

    Checks §Predicted Failure Modes for the item and auto-creates an encounter row.
    This shift-left approach captures retro data incrementally rather than batching at Sprint Close.
    """
    matching_predictions = [
        pf for pf in data.predicted_failures if pf.item == item_id
    ]
    if not matching_predictions:
        return

    # Use the first matching prediction's category
    prediction = matching_predictions[0]
    try:
        writers.append_failure_encounter(
            tracking_path,
            item=item_id,
            category=prediction.category,
            description=note,
            detection="code-review",
        )
    except Exception as exc:
        # Non-fatal — don't block status transition, but warn
        print(f"Warning: Could not log failure encounter for {item_id}: {exc}", file=sys.stderr)


def _get_sprint_label(data) -> str:
    """Extract sprint label from current_focus."""
    if data.current_focus:
        import re
        m = re.search(r"Sprint\s+(\d+)", data.current_focus)
        if m:
            return f"Sprint {m.group(1)}"
    return ""


def _run_single(root, tracking_path, data, item_id, new_status, note):
    """Process a single item transition. Returns (item_id, old_status) or raises."""
    item = tracking_parser.get_item(data, item_id)
    if item is None:
        raise ItemNotFoundError(f"Item '{item_id}' not found in {tracking_path.name}")

    old_status = item.status
    allowed = VALID_TRANSITIONS.get(old_status)
    if allowed is None or new_status not in allowed:
        allowed_str = sorted(allowed) if allowed else []
        raise InvalidTransitionError(
            f"Cannot transition '{item_id}' from '{old_status}' to "
            f"'{new_status}'. Allowed: {allowed_str}."
        )
    return old_status


def main():
    if len(sys.argv) < 3:
        print("Usage: sprint-item.py <ID[,ID,...]> <new_status> [note]", file=sys.stderr)
        sys.exit(1)

    raw_ids = sys.argv[1]
    new_status = sys.argv[2].lower()
    note = sys.argv[3] if len(sys.argv) > 3 else ""

    # Parse comma-separated IDs
    item_ids = [x.strip() for x in raw_ids.split(",") if x.strip()]

    # Validate status value
    if new_status not in VALID_STATUSES:
        print(
            f"Error: Invalid status '{new_status}'. "
            f"Must be one of {sorted(VALID_STATUSES)}.",
            file=sys.stderr,
        )
        sys.exit(2)

    # Find project root and tracking file
    try:
        root = find_project_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    tracking_path = find_tracking_file(root)
    if not tracking_path.exists():
        raise SetupError(f"Tracking file not found: {tracking_path}")

    # Parse tracking data once
    data = tracking_parser.parse(tracking_path)
    sprint_label = _get_sprint_label(data)

    # --- Single item: original path (backward compatible) ---
    if len(item_ids) == 1:
        item_id = item_ids[0]
        old_status = _run_single(root, tracking_path, data, item_id, new_status, note)

        evidence = note if new_status in ("fixed", "verified") else ""
        writers.set_item_status(tracking_path, item_id, new_status, evidence=evidence)

        entry = f"{item_id}: {old_status} \u2192 {new_status}"
        if note:
            entry += f" \u2014 {note}"
        writers.append_changelog(tracking_path, entry, sprint_label=sprint_label, via_tool="item")

        if new_status == "fixed" and note:
            _log_encounter_if_applicable(tracking_path, data, item_id, note, sprint_label)

        if new_status in ("verified", "deferred"):
            roadmap_path = _find_roadmap(root)
            if roadmap_path is not None:
                checkbox = "x" if new_status == "verified" else "~"
                try:
                    writers.update_roadmap_checkbox(roadmap_path, item_id, checkbox)
                except ItemNotFoundError:
                    pass

        msg = f"{item_id}: {old_status} \u2192 {new_status}"
        if note:
            msg += f" \u2014 {note}"
        print(msg)
        return

    # --- Batch: multiple items, same status, single read/write cycle ---

    # Validate all transitions before writing anything
    old_statuses = {}
    for item_id in item_ids:
        old_statuses[item_id] = _run_single(root, tracking_path, data, item_id, new_status, note)

    # Batch status update (1 read + 1 write for TRACKING.md Sprint Board)
    evidence = note if new_status in ("fixed", "verified") else ""
    batch_items = [(item_id, new_status, evidence) for item_id in item_ids]
    writers.set_items_status_batch(tracking_path, batch_items)

    # Batch changelog (1 read + 1 write for TRACKING.md Change Log)
    entries = []
    for item_id in item_ids:
        entry = f"{item_id}: {old_statuses[item_id]} \u2192 {new_status}"
        if note:
            entry += f" \u2014 {note}"
        entries.append(entry)
    writers.append_changelog_batch(tracking_path, entries, sprint_label=sprint_label, via_tool="item")

    # Batch failure encounter logging
    if new_status == "fixed" and note:
        for item_id in item_ids:
            _log_encounter_if_applicable(tracking_path, data, item_id, note, sprint_label)

    # Batch roadmap checkbox (1 read + 1 write for Roadmap.md)
    if new_status in ("verified", "deferred"):
        roadmap_path = _find_roadmap(root)
        if roadmap_path is not None:
            checkbox = "x" if new_status == "verified" else "~"
            roadmap_items = [(item_id, checkbox) for item_id in item_ids]
            writers.update_roadmap_checkboxes_batch(roadmap_path, roadmap_items)

    # Print confirmation
    for item_id in item_ids:
        msg = f"{item_id}: {old_statuses[item_id]} \u2192 {new_status}"
        if note:
            msg += f" \u2014 {note}"
        print(msg)


if __name__ == "__main__":
    try:
        main()
    except (ItemNotFoundError, InvalidTransitionError, SetupError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(e.exit_code)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)
