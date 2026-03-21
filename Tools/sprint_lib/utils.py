"""Shared helpers for sprint_lib parsers.

This module provides canonical implementations of markdown parsing utilities
used by tracking_parser, gate_parser, roadmap_parser, and the dashboard.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

from sprint_lib.models import TABLE_SEPARATOR_RE


# ---------------------------------------------------------------------------
# Working-context placeholder values (shared across parsers + dashboard)
# ---------------------------------------------------------------------------

WC_PLACEHOLDERS: frozenset[str] = frozenset({"", "\u2014", "-"})


# ---------------------------------------------------------------------------
# Project discovery
# ---------------------------------------------------------------------------

def find_project_root(start: Path | None = None) -> Path:
    """Walk up from start to find directory containing TRACKING.md or CLAUDE.md."""
    current = (start or Path.cwd()).resolve()
    for d in [current, *current.parents]:
        if (d / "TRACKING.md").exists() or (d / "CLAUDE.md").exists():
            return d
    raise FileNotFoundError(
        "No TRACKING.md or CLAUDE.md found in parent directories"
    )


def find_tracking_file(root: Path, member: str = "") -> Path:
    """Find tracking file, supporting team mode via SPRINT_MEMBER env var."""
    member = member or os.environ.get("SPRINT_MEMBER", "")
    if member:
        candidate = root / f"TRACKING-{member}.md"
        if candidate.exists():
            return candidate
    return root / "TRACKING.md"


# ---------------------------------------------------------------------------
# Markdown section extraction
# ---------------------------------------------------------------------------

def extract_section(text: str, section_name: str, min_level: int = 2) -> str:
    """Extract text between a markdown heading and the next heading of same/higher level.

    Searches for headings at levels *min_level* through 3.  At each level,
    tries an **exact match** first, then falls back to a **fuzzy substring
    match** (case-insensitive).  The fuzzy fallback is useful for headings
    with em-dashes, extra punctuation, or slight variations.

    Returns the text between the matched heading and the next heading of the
    same or higher level (or end of string).  Returns ``""`` if not found.
    """
    for level in range(min_level, 4):
        prefix = "#" * level
        # Exact match first
        pattern = rf"^{prefix}\s+{re.escape(section_name)}\s*$"
        match = re.search(pattern, text, re.MULTILINE)
        if not match:
            # Fuzzy (substring, case-insensitive) fallback
            pattern = rf"^{prefix}\s+.*{re.escape(section_name)}.*$"
            match = re.search(pattern, text, re.MULTILINE | re.IGNORECASE)
        if match:
            start = match.end()
            next_heading = re.search(rf"^{'#' * level}\s+", text[start:], re.MULTILINE)
            # Also respect parent headings when level > min_level
            if level > min_level:
                parent = re.search(rf"^{'#' * min_level}\s+", text[start:], re.MULTILINE)
                if parent and (not next_heading or parent.start() < next_heading.start()):
                    next_heading = parent
            end = start + next_heading.start() if next_heading else len(text)
            return text[start:end].strip()
    return ""


# ---------------------------------------------------------------------------
# Markdown table parsing
# ---------------------------------------------------------------------------

def parse_md_table(text: str) -> list[dict[str, str]]:
    """Parse a markdown table into a list of dicts keyed by normalised column header.

    Handles:
    - empty tables (header + separator, no data rows)
    - rows with extra or missing trailing pipes
    - whitespace around cell values
    - separator rows anywhere in the table body

    Header keys are normalised: lowercased, non-alphanumeric runs replaced
    with ``_``, leading/trailing ``_`` stripped.
    """
    lines = [
        line.strip()
        for line in text.strip().splitlines()
        if line.strip().startswith("|")
    ]
    if len(lines) < 2:
        return []

    def _split_row(line: str) -> list[str]:
        return [cell.strip() for cell in line.strip("|").split("|")]

    headers = _split_row(lines[0])
    keys = [re.sub(r"[^a-z0-9]+", "_", h.lower()).strip("_") for h in headers]

    rows: list[dict[str, str]] = []
    for line in lines[1:]:
        if TABLE_SEPARATOR_RE.match(line):
            continue
        cells = _split_row(line)
        row: dict[str, str] = {}
        for idx, key in enumerate(keys):
            row[key] = cells[idx] if idx < len(cells) else ""
        rows.append(row)
    return rows


def extract_table_from_section(text: str, heading: str) -> list[dict[str, str]]:
    """Extract and parse the first markdown table under *heading*."""
    section = extract_section(text, heading)
    if not section:
        return []
    table_lines: list[str] = []
    in_table = False
    for line in section.splitlines():
        stripped = line.strip()
        if stripped.startswith("|"):
            in_table = True
            table_lines.append(stripped)
        elif in_table:
            break
    return parse_md_table("\n".join(table_lines)) if table_lines else []


# ---------------------------------------------------------------------------
# Safe type conversions
# ---------------------------------------------------------------------------

def safe_int(value: str | int, default: int = 0) -> int:
    """Convert to int, returning *default* on failure."""
    try:
        return int(value)
    except (ValueError, TypeError):
        return default


def safe_float(value: str | float, default: float = 0.0) -> float:
    """Convert to float, returning *default* on failure."""
    try:
        return float(value)
    except (ValueError, TypeError):
        return default
