"""Read-only parser for TRACKING.md files.

Imports only from sprint_lib.models and stdlib.
"""

from __future__ import annotations

import re
from pathlib import Path

from sprint_lib.models import (
    TABLE_SEPARATOR_RE,
    BaselineEntry,
    DismissedSignal,
    FailureEncounter,
    FailureHistory,
    FailureMode,
    Item,
    Risk,
    SessionNote,
    TrackingData,
    WorkingContext,
)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _safe_int(value: str | int, default: int = 0) -> int:
    """Convert to int, returning *default* on failure."""
    try:
        return int(value)
    except (ValueError, TypeError):
        return default


def _extract_section(text: str, section_name: str) -> str:
    """Extract text between ``## section_name`` and the next ``##`` header."""
    pattern = re.compile(
        r"^##\s+" + re.escape(section_name) + r"\s*$",
        re.MULTILINE,
    )
    match = pattern.search(text)
    if match is None:
        return ""
    start = match.end()
    next_header = re.search(r"^##\s+", text[start:], re.MULTILINE)
    if next_header is None:
        return text[start:]
    return text[start : start + next_header.start()]


def _parse_table(section_text: str) -> list[dict[str, str]]:
    """Parse a markdown table into a list of dicts keyed by column header.

    Handles:
    - empty tables (header + separator, no data rows)
    - rows with extra or missing trailing pipes
    - whitespace around cell values
    """
    lines = [
        line.strip()
        for line in section_text.splitlines()
        if line.strip().startswith("|")
    ]
    if len(lines) < 2:
        return []

    def _split_row(line: str) -> list[str]:
        # Strip leading/trailing pipe then split on pipes.
        stripped = line.strip("|")
        return [cell.strip() for cell in stripped.split("|")]

    headers = _split_row(lines[0])
    # Normalise header keys: lowercase, replace spaces/special chars with '_'.
    keys = [re.sub(r"[^a-z0-9]+", "_", h.lower()).strip("_") for h in headers]

    rows: list[dict[str, str]] = []
    for line in lines[1:]:
        # Skip separator rows (e.g. |---|---|)
        if TABLE_SEPARATOR_RE.match(line):  # trailing pipe optional
            continue
        cells = _split_row(line)
        row: dict[str, str] = {}
        for idx, key in enumerate(keys):
            row[key] = cells[idx] if idx < len(cells) else ""
        rows.append(row)
    return rows


def _parse_changelog(section_text: str) -> dict[str, list[str]]:
    """Parse Change Log section into ``{sprint_key: [entries]}``."""
    result: dict[str, list[str]] = {}
    current_key: str | None = None
    for line in section_text.splitlines():
        stripped = line.strip()
        header_match = re.match(r"^###\s+(.+)$", stripped)
        if header_match:
            current_key = header_match.group(1).strip()
            result[current_key] = []
            continue
        if current_key is not None and stripped.startswith("- "):
            result[current_key].append(stripped[2:].strip())
    return result


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def parse(path: Path) -> TrackingData:
    """Parse a TRACKING.md file into structured :class:`TrackingData`."""
    text = path.read_text(encoding="utf-8")

    # --- Working Context ---
    wc_section = _extract_section(text, "Working Context").strip()
    working_context = None
    if wc_section:
        wc_data: dict[str, str] = {}
        for line in wc_section.splitlines():
            line = line.strip()
            if ":" in line:
                key, _, val = line.partition(":")
                wc_data[key.strip().lower()] = val.strip()
        if wc_data:
            working_context = WorkingContext(
                task=wc_data.get("task", ""),
                doing=wc_data.get("doing", ""),
                decisions=wc_data.get("decisions", ""),
                blockers=wc_data.get("blockers", ""),
            )

    # --- Current Focus ---
    focus_section = _extract_section(text, "Current Focus").strip()
    # Take the first non-empty line.
    current_focus = ""
    for line in focus_section.splitlines():
        line = line.strip()
        if line:
            current_focus = line
            break

    # --- Sprint Board ---
    items: list[Item] = []
    for row in _parse_table(_extract_section(text, "Sprint Board")):
        items.append(
            Item(
                id=row.get("id", ""),
                summary=row.get("summary", ""),
                status=row.get("status", "").lower().strip(),
                sprint=row.get("sprint", ""),
                priority=row.get("priority", ""),
                evidence=row.get("evidence", ""),
            )
        )

    # --- Open Risks / Blockers ---
    risks: list[Risk] = []
    for row in _parse_table(_extract_section(text, "Open Risks / Blockers")):
        risks.append(
            Risk(
                id=row.get("id", ""),
                risk=row.get("risk", ""),
                mitigation=row.get("mitigation", ""),
                sprint=row.get("sprint", ""),
            )
        )

    # --- Predicted Failure Modes — Current Sprint ---
    predicted_failures: list[FailureMode] = []
    section = _extract_section(text, "Predicted Failure Modes \u2014 Current Sprint")
    for row in _parse_table(section):
        predicted_failures.append(
            FailureMode(
                item=row.get("item", ""),
                category=row.get("category", ""),
                predicted_mode=row.get("predicted_mode", ""),
                detection_plan=row.get("detection_plan", ""),
            )
        )

    # --- Failure Encounters — Current Sprint ---
    failure_encounters: list[FailureEncounter] = []
    section = _extract_section(text, "Failure Encounters \u2014 Current Sprint")
    for row in _parse_table(section):
        failure_encounters.append(
            FailureEncounter(
                item=row.get("item", ""),
                category=row.get("category", ""),
                description=row.get("failure_description", ""),
                detection=row.get("detection", ""),
                date=row.get("date", ""),
            )
        )

    # --- Failure Mode History ---
    failure_history: list[FailureHistory] = []
    for row in _parse_table(_extract_section(text, "Failure Mode History")):
        failure_history.append(
            FailureHistory(
                sprint=row.get("sprint", ""),
                category=row.get("category", ""),
                predicted=row.get("predicted", ""),
                detection=row.get("detection", ""),
                mode=row.get("mode", ""),
                impact=row.get("impact", ""),
                root_cause=row.get("root_cause", ""),
                guardrail=row.get("guardrail", ""),
                escalate=row.get("escalate", ""),
            )
        )

    # --- Performance Baseline Log ---
    baselines: list[BaselineEntry] = []
    for row in _parse_table(_extract_section(text, "Performance Baseline Log")):
        baselines.append(
            BaselineEntry(
                sprint=row.get("sprint", ""),
                metric=row.get("metric", ""),
                value=row.get("value", ""),
                unit=row.get("unit", ""),
                method=row.get("method", ""),
            )
        )

    # --- Dismissed Signals ---
    dismissed_signals: list[DismissedSignal] = []
    for row in _parse_table(_extract_section(text, "Dismissed Signals")):
        dismissed_signals.append(
            DismissedSignal(
                date=row.get("date", ""),
                checkpoint=row.get("checkpoint", ""),
                system_metric=row.get("system_metric", ""),
                signal_summary=row.get("signal_summary", ""),
                user_decision=row.get("user_decision", ""),
                dismissal_num=row.get("dismissal", row.get("dismissal_num", "")),
                suppressed=row.get("suppressed", ""),
                revisit_sprint=row.get("revisit_sprint", ""),
            )
        )

    # --- Session Notes ---
    session_notes: list[SessionNote] = []
    for row in _parse_table(_extract_section(text, "Session Notes")):
        session_notes.append(
            SessionNote(
                seq=_safe_int(row.get("seq", row.get("#", row.get("", "0"))) or "0"),
                note_type=row.get("type", ""),
                text=row.get("note", ""),
                item=row.get("item", ""),
                timestamp=row.get("time", ""),
            )
        )

    # --- Change Log ---
    changelog_entries = _parse_changelog(_extract_section(text, "Change Log"))

    return TrackingData(
        current_focus=current_focus,
        working_context=working_context,
        items=items,
        risks=risks,
        predicted_failures=predicted_failures,
        failure_encounters=failure_encounters,
        failure_history=failure_history,
        baselines=baselines,
        dismissed_signals=dismissed_signals,
        changelog_entries=changelog_entries,
        session_notes=session_notes,
    )


def get_item(data: TrackingData, item_id: str) -> Item | None:
    """Find an item by its ID (e.g. ``'CORE-001'``)."""
    for item in data.items:
        if item.id == item_id:
            return item
    return None


def get_sprint_items(data: TrackingData, sprint: str) -> list[Item]:
    """Return all items belonging to *sprint* (e.g. ``'S1'``)."""
    return [item for item in data.items if item.sprint == sprint]


def get_risks(data: TrackingData) -> list[Risk]:
    """Return the list of open risks / blockers."""
    return list(data.risks)


def get_recurring_failures(data: TrackingData, min_sprints: int = 2) -> list[str]:
    """Find failure categories that appear in *min_sprints* or more distinct sprints.

    Searches the ``failure_history`` table and returns category names.
    """
    sprints_per_category: dict[str, set[str]] = {}
    for entry in data.failure_history:
        cat = entry.category.strip()
        if cat:
            sprints_per_category.setdefault(cat, set()).add(entry.sprint.strip())
    return [
        cat
        for cat, sprints in sprints_per_category.items()
        if len(sprints) >= min_sprints
    ]


def get_latest_session_notes(data: TrackingData, count: int = 5) -> list[SessionNote]:
    """Return the last *count* session notes (most recent last)."""
    return data.session_notes[-count:]


def get_latest_baselines(data: TrackingData) -> list[BaselineEntry]:
    """Return baseline entries from the most recent (last) sprint."""
    if not data.baselines:
        return []
    # The last sprint that appears in the baselines list.
    latest_sprint = data.baselines[-1].sprint
    return [b for b in data.baselines if b.sprint == latest_sprint]
