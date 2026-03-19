"""In-place mutators for TRACKING.md, Roadmap.md, and CLAUDE.md.

Design rule: this module does NOT import tracking_parser or roadmap_parser.
It performs its own minimal line-level searching to find and modify specific
lines.  Write-side errors stay isolated from read-side errors.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path

from sprint_lib.errors import InvalidTransitionError, ItemNotFoundError
from sprint_lib.models import NOTE_TYPES, TABLE_SEPARATOR_RE, VALID_STATUSES, VALID_TRANSITIONS


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines(keepends=True)


def _write_lines(path: Path, lines: list[str]) -> None:
    path.write_text("".join(lines), encoding="utf-8")


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _escape_cell(value: str) -> str:
    """Escape characters that would corrupt a markdown table cell."""
    return value.replace("|", "\\|").replace("\n", " ").replace("\r", "")


# ---------------------------------------------------------------------------
# set_item_status
# ---------------------------------------------------------------------------

def set_item_status(
    path: Path,
    item_id: str,
    new_status: str,
    evidence: str = "",
) -> None:
    """Update status column for *item_id* in the Sprint Board table.

    Raises ``ItemNotFoundError`` if *item_id* is not found.
    Raises ``InvalidTransitionError`` if the transition is not allowed.
    """
    if new_status not in VALID_STATUSES:
        raise InvalidTransitionError(
            f"Invalid status '{new_status}'. Must be one of {sorted(VALID_STATUSES)}."
        )

    lines = _read_lines(path)
    needle = f"| {item_id} |"
    target_idx: int | None = None

    for idx, line in enumerate(lines):
        if needle in line:
            target_idx = idx
            break

    if target_idx is None:
        raise ItemNotFoundError(f"Item '{item_id}' not found in {path.name}")

    parts = lines[target_idx].split("|")
    # parts: ['', ' ID ', ' Summary ', ' Status ', ' Sprint ', ' Evidence ', '' or '\n']
    current_status = parts[3].strip()

    # Validate transition
    allowed = VALID_TRANSITIONS.get(current_status)
    if allowed is None:
        raise InvalidTransitionError(
            f"No transitions defined from status '{current_status}'."
        )
    if new_status not in allowed:
        raise InvalidTransitionError(
            f"Cannot transition '{item_id}' from '{current_status}' to "
            f"'{new_status}'. Allowed: {sorted(allowed)}."
        )

    parts[3] = f" {new_status} "
    if evidence:
        parts[5] = f" {evidence} "

    lines[target_idx] = "|".join(parts)
    _write_lines(path, lines)


def set_items_status_batch(
    path: Path,
    items: list[tuple[str, str, str]],
) -> list[tuple[str, str]]:
    """Batch update status for multiple items in a single read/write cycle.

    *items* is a list of ``(item_id, new_status, evidence)`` tuples.
    Returns list of ``(item_id, old_status)`` for each successfully updated item.
    Raises on first validation error (all-or-nothing within the file write).
    """
    lines = _read_lines(path)
    old_statuses: list[tuple[str, str]] = []

    for item_id, new_status, evidence in items:
        if new_status not in VALID_STATUSES:
            raise InvalidTransitionError(
                f"Invalid status '{new_status}'. Must be one of {sorted(VALID_STATUSES)}."
            )

        needle = f"| {item_id} |"
        target_idx: int | None = None
        for idx, line in enumerate(lines):
            if needle in line:
                target_idx = idx
                break

        if target_idx is None:
            raise ItemNotFoundError(f"Item '{item_id}' not found in {path.name}")

        parts = lines[target_idx].split("|")
        current_status = parts[3].strip()

        allowed = VALID_TRANSITIONS.get(current_status)
        if allowed is None:
            raise InvalidTransitionError(
                f"No transitions defined from status '{current_status}'."
            )
        if new_status not in allowed:
            raise InvalidTransitionError(
                f"Cannot transition '{item_id}' from '{current_status}' to "
                f"'{new_status}'. Allowed: {sorted(allowed)}."
            )

        parts[3] = f" {new_status} "
        if evidence:
            parts[5] = f" {evidence} "
        lines[target_idx] = "|".join(parts)
        old_statuses.append((item_id, current_status))

    _write_lines(path, lines)
    return old_statuses


def append_changelog_batch(
    path: Path,
    entries: list[str],
    sprint_label: str = "",
    via_tool: str = "",
) -> None:
    """Append multiple dated entries to the Change Log in a single read/write cycle."""
    lines = _read_lines(path)
    date_str = _today()
    tag = f" [via sprint-tools {via_tool}]" if via_tool else ""

    changelog_idx: int | None = None
    for idx, line in enumerate(lines):
        if line.strip().startswith("## Change Log"):
            changelog_idx = idx
            break

    if changelog_idx is None:
        lines.append("\n## Change Log\n\n")
        changelog_idx = len(lines) - 1

    if not sprint_label:
        for entry in entries:
            if lines and not lines[-1].endswith("\n"):
                lines[-1] += "\n"
            lines.append(f"- {date_str} {entry}{tag}\n")
        _write_lines(path, lines)
        return

    subsection_header = f"### {sprint_label}"
    sub_idx: int | None = None
    for idx in range(changelog_idx + 1, len(lines)):
        stripped = lines[idx].strip()
        if stripped == subsection_header:
            sub_idx = idx
            break
        if stripped.startswith("## ") and not stripped.startswith("## Change Log"):
            break

    if sub_idx is not None:
        insert_at = sub_idx + 1
        for idx in range(sub_idx + 1, len(lines)):
            stripped = lines[idx].strip()
            if stripped.startswith("- "):
                insert_at = idx + 1
            elif stripped.startswith("#"):
                break
            elif stripped == "":
                continue
            else:
                break
        if insert_at > 0 and lines[insert_at - 1] and not lines[insert_at - 1].endswith("\n"):
            lines[insert_at - 1] += "\n"
        for i, entry in enumerate(entries):
            lines.insert(insert_at + i, f"- {date_str} {entry}{tag}\n")
    else:
        end_of_changelog = len(lines)
        for idx in range(changelog_idx + 1, len(lines)):
            stripped = lines[idx].strip()
            if stripped.startswith("## ") and not stripped.startswith("## Change Log"):
                end_of_changelog = idx
                break
        block = f"\n{subsection_header}\n"
        for entry in entries:
            block += f"- {date_str} {entry}{tag}\n"
        lines.insert(end_of_changelog, block)

    _write_lines(path, lines)


def update_roadmap_checkboxes_batch(
    roadmap_path: Path,
    items: list[tuple[str, str]],
) -> None:
    """Batch update checkboxes for multiple items in a single read/write cycle.

    *items* is a list of ``(item_id, state)`` tuples where state is "x", "~", or " ".
    """
    lines = _read_lines(roadmap_path)
    for item_id, state in items:
        pattern = re.compile(r"^(\s*- \[).(\]\s*" + re.escape(item_id) + r":)")
        for idx, line in enumerate(lines):
            m = pattern.match(line)
            if m:
                lines[idx] = f"{m.group(1)}{state}{m.group(2)}{line[m.end():]}"
                break
    _write_lines(roadmap_path, lines)


# ---------------------------------------------------------------------------
# append_changelog
# ---------------------------------------------------------------------------

def append_changelog(
    path: Path,
    entry: str,
    sprint_label: str = "",
    via_tool: str = "",
) -> None:
    """Append a dated entry to the Change Log section of TRACKING.md.

    If *sprint_label* is given (e.g. ``"Sprint 1"``), the entry is placed
    under that ``### Sprint N`` subsection, creating it if needed.
    If *via_tool* is given, appends ``[via sprint-tools <tool>]`` tag for traceability.
    """
    lines = _read_lines(path)
    date_str = _today()
    tag = f" [via sprint-tools {via_tool}]" if via_tool else ""
    formatted = f"- {date_str} {entry}{tag}\n"

    # Find the "## Change Log" section
    changelog_idx: int | None = None
    for idx, line in enumerate(lines):
        if line.strip().startswith("## Change Log"):
            changelog_idx = idx
            break

    if changelog_idx is None:
        # Append section at end of file
        lines.append("\n## Change Log\n\n")
        changelog_idx = len(lines) - 1

    if not sprint_label:
        # Append at the very end of the file
        # Ensure trailing newline
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        lines.append(formatted)
        _write_lines(path, lines)
        return

    # Look for ### Sprint N subsection after changelog_idx
    subsection_header = f"### {sprint_label}"
    sub_idx: int | None = None
    for idx in range(changelog_idx + 1, len(lines)):
        stripped = lines[idx].strip()
        if stripped == subsection_header or stripped == f"### {sprint_label}":
            sub_idx = idx
            break
        # Stop if we hit another ## section
        if stripped.startswith("## ") and not stripped.startswith("## Change Log"):
            break

    if sub_idx is not None:
        # Find the last entry line in this subsection (lines starting with -)
        insert_at = sub_idx + 1
        for idx in range(sub_idx + 1, len(lines)):
            stripped = lines[idx].strip()
            if stripped.startswith("- "):
                insert_at = idx + 1
            elif stripped.startswith("#"):
                break
            elif stripped == "":
                # blank line — keep scanning past blank lines between entries
                continue
            else:
                break
        # Ensure preceding line ends with newline to avoid concatenation
        if insert_at > 0 and lines[insert_at - 1] and not lines[insert_at - 1].endswith("\n"):
            lines[insert_at - 1] += "\n"
        lines.insert(insert_at, formatted)
    else:
        # Create the subsection.  Insert right after ## Change Log header
        # (and any blank line following it).
        insert_at = changelog_idx + 1
        while insert_at < len(lines) and lines[insert_at].strip() == "":
            insert_at += 1

        # If there are existing subsections, put the new one at the end
        # of the Change Log section.
        end_of_changelog = len(lines)
        for idx in range(changelog_idx + 1, len(lines)):
            stripped = lines[idx].strip()
            if stripped.startswith("## ") and not stripped.startswith("## Change Log"):
                end_of_changelog = idx
                break

        block = f"\n{subsection_header}\n{formatted}"
        lines.insert(end_of_changelog, block)

    _write_lines(path, lines)


# ---------------------------------------------------------------------------
# update_roadmap_checkbox
# ---------------------------------------------------------------------------

def update_roadmap_checkbox(
    roadmap_path: Path,
    item_id: str,
    state: str,
) -> None:
    """Update checkbox for *item_id* in Roadmap.md.

    *state*: ``"x"`` (verified), ``"~"`` (deferred), ``" "`` (pending).
    """
    valid_states = {"x", "~", " "}
    if state not in valid_states:
        raise ValueError(f"Invalid checkbox state '{state}'. Must be one of {valid_states}.")

    lines = _read_lines(roadmap_path)
    pattern = re.compile(r"^(\s*- \[).(\]\s*" + re.escape(item_id) + r":)")

    found = False
    for idx, line in enumerate(lines):
        m = pattern.match(line)
        if m:
            lines[idx] = f"{m.group(1)}{state}{m.group(2)}{line[m.end():]}"
            found = True
            break

    if not found:
        raise ItemNotFoundError(
            f"Item '{item_id}' not found in {roadmap_path.name}"
        )

    _write_lines(roadmap_path, lines)


# ---------------------------------------------------------------------------
# add_risk / remove_risk
# ---------------------------------------------------------------------------

def add_risk(
    path: Path,
    risk_id: str,
    risk: str,
    mitigation: str,
    sprint: str = "",
) -> None:
    """Add a new row to the Open Risks / Blockers table."""
    lines = _read_lines(path)

    # Find the risk table header
    header_idx: int | None = None
    for idx, line in enumerate(lines):
        if line.strip().startswith("## Open Risks"):
            header_idx = idx
            break

    if header_idx is None:
        raise ItemNotFoundError("Open Risks / Blockers section not found.")

    # Find the separator line (|----...) after the header, skip blank lines
    table_end = header_idx + 1
    for idx in range(header_idx + 1, len(lines)):
        stripped = lines[idx].strip()
        if stripped.startswith("|"):
            table_end = idx + 1
        elif stripped == "":
            continue  # skip blank lines
        else:
            break

    new_row = f"| {risk_id} | {risk} | {mitigation} | {sprint} |\n"
    lines.insert(table_end, new_row)
    _write_lines(path, lines)


def remove_risk(path: Path, risk_id: str) -> None:
    """Remove a risk row from the Open Risks / Blockers table."""
    lines = _read_lines(path)
    needle = f"| {risk_id} |"

    found = False
    for idx, line in enumerate(lines):
        if needle in line:
            lines.pop(idx)
            found = True
            break

    if not found:
        raise ItemNotFoundError(f"Risk '{risk_id}' not found in {path.name}")

    _write_lines(path, lines)


# ---------------------------------------------------------------------------
# add_baseline_entry
# ---------------------------------------------------------------------------

def add_baseline_entry(
    path: Path,
    sprint: str,
    metric: str,
    value: str,
    unit: str,
    method: str,
) -> None:
    """Append a row to the Performance Baseline Log table."""
    lines = _read_lines(path)

    header_idx: int | None = None
    for idx, line in enumerate(lines):
        if line.strip().startswith("## Performance Baseline Log"):
            header_idx = idx
            break

    if header_idx is None:
        raise ItemNotFoundError("Performance Baseline Log section not found.")

    # Find the end of the table (skip blank lines between header and table)
    table_end = header_idx + 1
    for idx in range(header_idx + 1, len(lines)):
        stripped = lines[idx].strip()
        if stripped.startswith("|"):
            table_end = idx + 1
        elif stripped == "":
            continue  # skip blank lines
        else:
            break

    new_row = f"| {sprint} | {metric} | {value} | {unit} | {method} |\n"
    lines.insert(table_end, new_row)
    _write_lines(path, lines)


# ---------------------------------------------------------------------------
# update_checkpoint
# ---------------------------------------------------------------------------

def update_checkpoint(
    claude_md_path: Path,
    date: str,
    focus: str,
    status: str,
    next_step: str,
) -> None:
    """Update the ``## Last Checkpoint`` section in CLAUDE.md."""
    lines = _read_lines(claude_md_path)

    # Find ## Last Checkpoint
    section_idx: int | None = None
    for idx, line in enumerate(lines):
        if line.strip().startswith("## Last Checkpoint"):
            section_idx = idx
            break

    if section_idx is None:
        raise ItemNotFoundError("## Last Checkpoint section not found in CLAUDE.md")

    # Replace the four key-value lines following the header.
    # They may not be immediately after the header (blank lines possible),
    # so we search for each one.
    field_map = {
        "Date": date,
        "Active focus": focus,
        "Status": status,
        "Next step": next_step,
    }

    # Determine the section boundary (next ## heading or EOF)
    section_end = len(lines)
    for idx in range(section_idx + 1, len(lines)):
        if lines[idx].strip().startswith("## "):
            section_end = idx
            break

    for field_name, new_value in field_map.items():
        pattern = re.compile(r"^(\s*-\s*" + re.escape(field_name) + r"\s*:\s*)(.*)$")
        found = False
        for idx in range(section_idx + 1, section_end):
            m = pattern.match(lines[idx].rstrip("\n"))
            if m:
                lines[idx] = f"{m.group(1)}{new_value}\n"
                found = True
                break
        if not found:
            raise ItemNotFoundError(
                f"Field '{field_name}' not found in Last Checkpoint section."
            )

    _write_lines(claude_md_path, lines)


def update_working_context(
    tracking_path: Path,
    task: str = "",
    doing: str = "",
    decisions: str = "",
    blockers: str = "",
) -> None:
    """Update the ``## Working Context`` section in TRACKING.md.

    Only updates fields that are non-empty. Empty string = leave unchanged.
    """
    lines = _read_lines(tracking_path)

    section_idx: int | None = None
    for idx, line in enumerate(lines):
        if line.strip().startswith("## Working Context"):
            section_idx = idx
            break

    if section_idx is None:
        raise ItemNotFoundError("## Working Context section not found in TRACKING.md")

    section_end = len(lines)
    for idx in range(section_idx + 1, len(lines)):
        if lines[idx].strip().startswith("## "):
            section_end = idx
            break

    field_map = {}
    if task:
        field_map["Task"] = task
    if doing:
        field_map["Doing"] = doing
    if decisions:
        field_map["Decisions"] = decisions
    if blockers:
        field_map["Blockers"] = blockers

    if not field_map:
        return

    for field_name, new_value in field_map.items():
        pattern = re.compile(r"^(" + re.escape(field_name) + r"\s*:\s*)(.*)$")
        for idx in range(section_idx + 1, section_end):
            m = pattern.match(lines[idx].rstrip("\n"))
            if m:
                lines[idx] = f"{m.group(1)}{new_value}\n"
                break

    _write_lines(tracking_path, lines)


# ---------------------------------------------------------------------------
# append_session_note
# ---------------------------------------------------------------------------

def append_session_note(
    path: Path,
    note_type: str,
    text: str,
    item: str = "",
) -> int:
    """Append a row to the Session Notes table and return the new seq number.

    Creates the §Session Notes section with header if it doesn't exist.
    Returns the assigned sequence number.
    """
    if note_type not in NOTE_TYPES:
        raise ValueError(
            f"Invalid note type '{note_type}'. Must be one of {sorted(NOTE_TYPES)}."
        )

    lines = _read_lines(path)
    time_str = datetime.now(timezone.utc).strftime("%H:%M")

    # Find §Session Notes section
    section_idx: int | None = None
    for idx, line in enumerate(lines):
        if line.strip().startswith("## Session Notes"):
            section_idx = idx
            break

    if section_idx is None:
        # Insert before §Change Log (or at end)
        insert_before = len(lines)
        for idx, line in enumerate(lines):
            if line.strip().startswith("## Change Log"):
                insert_before = idx
                break

        header_block = [
            "\n## Session Notes\n",
            "\n",
            "| # | Type | Item | Note | Time |\n",
            "|---|------|------|------|------|\n",
            "\n",
        ]
        for i, h in enumerate(header_block):
            lines.insert(insert_before + i, h)
        section_idx = insert_before

    # Find the last row in the table to determine seq and insert position.
    # Skip any prose between section header and table header row.
    max_seq = 0
    table_start: int | None = None
    table_end = section_idx + 1
    for idx in range(section_idx + 1, len(lines)):
        stripped = lines[idx].strip()
        if stripped.startswith("|"):
            # Header row (contains column names like "# | Type")
            if table_start is None and not TABLE_SEPARATOR_RE.match(stripped):
                table_start = idx
            # Separator row
            if TABLE_SEPARATOR_RE.match(stripped):
                table_end = idx + 1
                continue
            # Data row — extract seq
            cells = [c.strip() for c in stripped.strip("|").split("|")]
            if cells and cells[0].isdigit():
                max_seq = max(max_seq, int(cells[0]))
            table_end = idx + 1
        elif stripped == "":
            # Before table: skip prose gaps. After table: stop.
            if table_start is not None:
                break
            continue
        elif stripped.startswith("##"):
            break
        else:
            # Non-table text: skip if before table header, break if after
            if table_start is not None:
                break
            continue

    new_seq = max_seq + 1
    item_str = item if item else "—"
    new_row = f"| {new_seq} | {note_type} | {_escape_cell(item_str)} | {_escape_cell(text)} | {time_str} |\n"
    lines.insert(table_end, new_row)
    _write_lines(path, lines)
    return new_seq


# ---------------------------------------------------------------------------
# append_failure_encounter
# ---------------------------------------------------------------------------

def append_failure_encounter(
    path: Path,
    item: str,
    category: str,
    description: str,
    detection: str = "code-review",
) -> None:
    """Append a row to the Failure Encounters — Current Sprint table."""
    lines = _read_lines(path)
    date_str = _today()

    header_idx: int | None = None
    for idx, line in enumerate(lines):
        if "Failure Encounters" in line and line.strip().startswith("##"):
            header_idx = idx
            break

    if header_idx is None:
        raise ItemNotFoundError("Failure Encounters section not found.")

    # Find end of table
    table_end = header_idx + 1
    for idx in range(header_idx + 1, len(lines)):
        stripped = lines[idx].strip()
        if stripped.startswith("|"):
            table_end = idx + 1
        elif stripped == "":
            continue
        else:
            break

    new_row = f"| {item} | {_escape_cell(category)} | {_escape_cell(description)} | {detection} | {date_str} |\n"
    lines.insert(table_end, new_row)
    _write_lines(path, lines)


# ---------------------------------------------------------------------------
# clear_session_notes
# ---------------------------------------------------------------------------

def clear_session_notes(path: Path) -> None:
    """Remove data rows from §Session Notes table, keeping header + separator."""
    lines = _read_lines(path)
    in_section = False
    past_separator = False
    new_lines: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("## Session Notes"):
            in_section = True
            past_separator = False
            new_lines.append(line)
            continue
        if in_section:
            if stripped.startswith("##"):
                in_section = False
                new_lines.append(line)
                continue
            if stripped.startswith("|"):
                if TABLE_SEPARATOR_RE.match(stripped):
                    past_separator = True
                    new_lines.append(line)
                elif not past_separator:
                    new_lines.append(line)
                continue
            new_lines.append(line)
        else:
            new_lines.append(line)
    _write_lines(path, new_lines)
