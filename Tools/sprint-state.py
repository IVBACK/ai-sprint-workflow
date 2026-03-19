#!/usr/bin/env python3
"""Sprint state digest — compact sprint summary for LLM context injection."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict
from pathlib import Path

from sprint_lib.utils import find_project_root, find_tracking_file
from sprint_lib import tracking_parser, roadmap_parser, gate_parser
from sprint_lib.models import SprintDigest
from sprint_lib.errors import SetupError


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _extract_sprint_number(text: str) -> int:
    """Extract sprint number from strings like 'Sprint 1', 'S1', 'S2', etc."""
    m = re.search(r"(?:Sprint\s+|S)(\d+)", text, re.IGNORECASE)
    return int(m.group(1)) if m else 1


def _read_mode(root: Path) -> str:
    """Read sprint mode from hooks-config.sh if it exists."""
    cfg = root / "hooks-config.sh"
    if not cfg.is_file():
        return "standard"
    try:
        text = cfg.read_text(encoding="utf-8")
        m = re.search(r'WORKFLOW_MODE\s*=\s*["\']?(\w+)', text)
        if m:
            return m.group(1)
    except OSError:
        pass
    return "standard"


def _read_sprint_type(root: Path) -> str:
    """Read sprint type from hooks-config.sh if it exists."""
    cfg = root / "hooks-config.sh"
    if not cfg.is_file():
        return "feature"
    try:
        text = cfg.read_text(encoding="utf-8")
        m = re.search(r'SPRINT_TYPE\s*=\s*["\']?(\w+)', text)
        if m:
            return m.group(1)
    except OSError:
        pass
    return "feature"


def _truncate(s: str, maxlen: int = 35) -> str:
    """Truncate string to maxlen, adding ellipsis if needed."""
    if len(s) <= maxlen:
        return s
    return s[: maxlen - 1] + "\u2026"


# ---------------------------------------------------------------------------
# Build digest
# ---------------------------------------------------------------------------

def _infer_phase(
    items: list,
    entry_gate_exists: bool,
    close_gate_path: "Path | None",
    changelog: dict[str, list[str]],
) -> str:
    """Infer current sprint phase from available signals.

    Returns one of: planned, entry_gate, impl_loop, impl_done,
    close_gate, sprint_close, done.
    """
    # Check changelog for explicit phase markers
    all_entries = " ".join(
        entry for entries in changelog.values() for entry in entries
    ).lower()

    if "sprint close" in all_entries and "complete" in all_entries:
        return "done"

    # Close gate file exists → close_gate or sprint_close
    if close_gate_path is not None:
        try:
            cg = gate_parser.parse_close_gate(close_gate_path)
            if cg.get("verdict") == "PASS":
                return "sprint_close"
        except Exception:
            pass
        return "close_gate"

    # Item-based inference
    must_items = [i for i in items if (i.priority or "").lower() == "must"]
    has_in_progress = any(i.status == "in_progress" for i in items)
    has_fixed = any(i.status == "fixed" for i in items)
    all_must_verified = (
        must_items and all(i.status in ("verified", "deferred") for i in must_items)
    )

    if has_in_progress or has_fixed:
        return "impl_loop"

    if all_must_verified:
        return "impl_done"

    # Entry gate exists but no work started → just passed entry gate
    if entry_gate_exists:
        any_verified = any(i.status == "verified" for i in items)
        if any_verified:
            return "impl_loop"  # Some items done, still in impl
        return "impl_loop"  # Entry gate passed, ready to start

    # No entry gate, no work → planned or entry_gate in progress
    any_work = any(i.status != "open" for i in items)
    if any_work:
        return "impl_loop"  # Work started without formal gate (freestyle/lite)

    return "planned"


def build_digest(root: Path) -> SprintDigest:
    """Build a SprintDigest from project files."""
    tracking_path = find_tracking_file(root)
    if not tracking_path.is_file():
        raise SetupError(f"TRACKING.md not found at {tracking_path}")

    td = tracking_parser.parse(tracking_path)

    # Determine sprint number from current focus or items
    sprint_n = _extract_sprint_number(td.current_focus) if td.current_focus else 0
    sprint_key = f"S{sprint_n}" if sprint_n > 0 else ""

    sprint_type = _read_sprint_type(root)

    # Items for the active sprint (show all if sprint unknown)
    items = list(td.items)
    if sprint_key:
        filtered = tracking_parser.get_sprint_items(td, sprint_key)
        if filtered:
            items = filtered

    # Try to enrich priority from Roadmap (check multiple locations)
    roadmap_data = None
    for candidate in [
        root / "Roadmap.md",
        root / "Planning" / "Roadmap.md",
        root / "Docs" / "Planning" / "Roadmap.md",
        root / "Docs" / "Roadmap.md",
    ]:
        if candidate.is_file():
            try:
                roadmap_data = roadmap_parser.parse(candidate)
                break
            except Exception as exc:
                print(f"Warning: could not parse {candidate}: {exc}", file=sys.stderr)

    # If roadmap has an active sprint, prefer its sprint number
    if roadmap_data:
        active = roadmap_parser.get_active_sprint(roadmap_data)
        if active:
            rm_n = _extract_sprint_number(active.sprint_key)
            if rm_n != sprint_n:
                sprint_n = rm_n
                sprint_key = f"S{sprint_n}"
                items = tracking_parser.get_sprint_items(td, sprint_key)
                if not items:
                    items = list(td.items)

        # Enrich item priorities from roadmap
        rm_sprint = roadmap_parser.get_sprint(roadmap_data, sprint_key)
        if rm_sprint:
            priority_map = {ri.id: ri.priority for ri in rm_sprint.items}
            for item in items:
                if item.id in priority_map and (not item.priority or item.priority == "unknown"):
                    item.priority = priority_map[item.id]

    # Risks
    risks = tracking_parser.get_risks(td)

    # Recurring failures
    recurring = tracking_parser.get_recurring_failures(td)

    # Latest baselines
    baselines = tracking_parser.get_latest_baselines(td)

    # Entry gate
    entry_gate_path = gate_parser.find_gate_file(root, sprint_n, gate_type="entry")
    entry_gate_exists = entry_gate_path is not None

    # Close gate
    close_gate_path = gate_parser.find_gate_file(root, sprint_n, gate_type="close")

    # Phase inference
    phase = _infer_phase(items, entry_gate_exists, close_gate_path, td.changelog_entries)

    return SprintDigest(
        sprint_n=sprint_n,
        sprint_type=sprint_type,
        items=items,
        risks=risks,
        recurring_failure_categories=recurring,
        latest_baselines=baselines,
        entry_gate_exists=entry_gate_exists,
        phase=phase,
        working_context=td.working_context,
        session_note_count=len(td.session_notes),
        failure_encounters=td.failure_encounters,
    )


# ---------------------------------------------------------------------------
# Formatters
# ---------------------------------------------------------------------------

_PRIORITY_ORDER = {"must": 0, "should": 1, "could": 2, "": 3}


def format_text(digest: SprintDigest, mode: str) -> str:
    """Render the digest as a compact text block (target: <=23 lines)."""
    lines: list[str] = []

    # Line 1: sprint header with phase
    phase_label = digest.phase.replace("_", " ").title()
    sprint_label = str(digest.sprint_n) if digest.sprint_n > 0 else "?"
    lines.append(
        f"Sprint: {sprint_label} | Phase: {phase_label} | Type: {digest.sprint_type} | Mode: {mode}"
    )

    # Count priorities
    counts = {"must": 0, "should": 0, "could": 0}
    for item in digest.items:
        p = item.priority.lower() if item.priority else ""
        if p in counts:
            counts[p] += 1

    count_parts = []
    if counts["must"]:
        count_parts.append(f"{counts['must']} Must")
    if counts["should"]:
        count_parts.append(f"{counts['should']} Should")
    if counts["could"]:
        count_parts.append(f"{counts['could']} Could")
    if count_parts:
        lines.append(f"Items: {' / '.join(count_parts)}")
    elif digest.items:
        lines.append(f"Items: {len(digest.items)} (no priority data)")
    else:
        lines.append("Items: none")

    # Item lines sorted by priority (must first)
    sorted_items = sorted(
        digest.items,
        key=lambda i: _PRIORITY_ORDER.get(i.priority.lower() if i.priority else "", 3),
    )
    for item in sorted_items:
        summary = _truncate(item.summary)
        status = f"[{item.status}]"
        sprint_label = item.sprint or f"S{digest.sprint_n}"
        priority = item.priority.capitalize() if item.priority else ""
        lines.append(
            f"  {item.id:<10s} {summary:<37s} {status:<15s} {sprint_label:<4s} {priority}"
        )

    # Blockers
    if digest.risks:
        ids = ", ".join(f"{r.id}: {_truncate(r.risk, 40)}" for r in digest.risks)
        lines.append(f"Risks: {len(digest.risks)} open ({ids})")
    else:
        lines.append("Risks: 0")

    # Working Context
    wc = digest.working_context
    if wc and (wc.task or wc.doing):
        parts = []
        if wc.task and wc.task != "—":
            parts.append(f"Task: {_truncate(wc.task, 50)}")
        if wc.doing and wc.doing != "—":
            parts.append(f"Doing: {_truncate(wc.doing, 50)}")
        if wc.blockers and wc.blockers != "—":
            parts.append(f"Blockers: {_truncate(wc.blockers, 50)}")
        if parts:
            lines.append("Context: " + " | ".join(parts))

    # Session notes count
    if digest.session_note_count > 0:
        lines.append(f"Session notes: {digest.session_note_count}")

    # Entry Gate
    lines.append(f"Entry Gate: {'EXISTS' if digest.entry_gate_exists else 'NOT FOUND'}")

    # Baselines
    if digest.latest_baselines:
        parts = [f"{b.metric}={b.value}{b.unit}" for b in digest.latest_baselines]
        lines.append(f"Baselines: {'; '.join(parts)}")
    else:
        lines.append("Baselines: none")

    # Recurring failures
    if digest.recurring_failure_categories:
        lines.append(
            f"Recurring failures: {', '.join(digest.recurring_failure_categories)}"
        )
    else:
        lines.append("Recurring failures: none")

    return "\n".join(lines)


def format_json(digest: SprintDigest) -> str:
    """Serialize the digest as JSON."""
    return json.dumps(asdict(digest), indent=2, ensure_ascii=False)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sprint state digest — compact sprint summary for LLM context injection.",
    )
    parser.add_argument(
        "root",
        nargs="?",
        default=None,
        help="Project root directory (auto-detected if omitted)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="as_json",
        help="Output as JSON instead of text",
    )
    parser.add_argument(
        "--check-escalations",
        action="store_true",
        help="Check for recurring failure patterns needing escalation",
    )
    args = parser.parse_args()

    # Resolve project root
    try:
        if args.root:
            root = Path(args.root).resolve()
            if not root.is_dir():
                print(f"Error: {root} is not a directory", file=sys.stderr)
                sys.exit(3)
        else:
            root = find_project_root()
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(3)

    # Build digest
    try:
        digest = build_digest(root)
    except SetupError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(exc.exit_code)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    # Escalation check
    if args.check_escalations:
        # Use already-parsed data from digest (no double parse)
        cat_counts: dict[str, int] = {}
        for enc in digest.failure_encounters:
            cat = enc.category.strip()
            if cat:
                cat_counts[cat] = cat_counts.get(cat, 0) + 1
        escalations = {c: n for c, n in cat_counts.items() if n >= 3}
        if escalations:
            print("ESCALATION WARNING — recurring failure categories this sprint:")
            for cat, count in escalations.items():
                print(f"  {cat}: {count} encounters (threshold: 3)")
        else:
            print("No escalation triggers.")
        return

    # Output
    if args.as_json:
        print(format_json(digest))
    else:
        mode = _read_mode(root)
        print(format_text(digest, mode))


if __name__ == "__main__":
    main()
