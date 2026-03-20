"""Read-only parser for Roadmap.md files."""

from __future__ import annotations

import re
from pathlib import Path

from sprint_lib.models import RoadmapData, RoadmapItem, RoadmapSprint

# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------

_OVERVIEW_ROW = re.compile(
    r"^\|\s*(?P<key>\S+)\s*\|\s*(?P<theme>.+?)\s*\|(?:.*\|)?\s*(?P<status>\w[\w\s]*?)\s*\|?\s*$"
)

_SPRINT_HEADING = re.compile(
    r"^##\s+Sprint\s+(\d+)\s*[—–-]\s*(.+)$"
)

_PRIORITY_HEADING = re.compile(
    r"^(?:###\s+|\*\*)(Must|Should|Could):?(?:\*\*)?\s*$", re.IGNORECASE
)

_ITEM_LINE = re.compile(
    r"^- \[(?P<cb>[ x~])\]\s+(?P<id>[A-Z]+-\d+):?\s+(?P<desc>.+)$"
)

_METRIC_LINE = re.compile(
    r"^\s+-\s+\*\*Metric:\*\*\s*(?P<text>.+)$"
)

_CHECKBOX_MAP = {
    " ": "pending",
    "x": "verified",
    "~": "deferred",
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _parse_overview(lines: list[str]) -> list[RoadmapSprint]:
    """Parse the Sprint Overview table into stub RoadmapSprint objects."""
    sprints: list[RoadmapSprint] = []
    in_overview = False
    for line in lines:
        if line.strip().startswith("## Sprint Overview"):
            in_overview = True
            continue
        if in_overview and line.startswith("## "):
            break
        if not in_overview:
            continue
        m = _OVERVIEW_ROW.match(line.strip())
        if m and not m.group("key").startswith("-"):
            key = m.group("key")
            # Skip the table header row
            if key.lower() == "sprint":
                continue
            theme = m.group("theme").strip()
            status = m.group("status").strip()
            sprints.append(RoadmapSprint(sprint_key=key, title=theme, status=status))
    return sprints


def _parse_sprint_sections(
    lines: list[str], sprints: list[RoadmapSprint]
) -> None:
    """Fill items into already-created RoadmapSprint objects."""
    sprint_map: dict[str, RoadmapSprint] = {s.sprint_key: s for s in sprints}

    current_sprint: RoadmapSprint | None = None
    current_priority: str = ""
    last_item: RoadmapItem | None = None

    for line in lines:
        # Detect sprint heading
        m_sprint = _SPRINT_HEADING.match(line.strip())
        if m_sprint:
            num = int(m_sprint.group(1))
            key = f"S{num}"
            current_sprint = sprint_map.get(key)
            current_priority = ""
            last_item = None
            continue

        if current_sprint is None:
            continue

        # Detect priority subsection
        m_pri = _PRIORITY_HEADING.match(line.strip())
        if m_pri:
            current_priority = m_pri.group(1).lower()
            last_item = None
            continue

        # Skip lines when we have no priority section (sketch sprints, goal
        # paragraphs, etc.)
        if not current_priority:
            continue

        # Detect item line
        m_item = _ITEM_LINE.match(line.strip())
        if m_item:
            cb = _CHECKBOX_MAP.get(m_item.group("cb"), "pending")
            item = RoadmapItem(
                id=m_item.group("id"),
                description=m_item.group("desc").strip(),
                priority=current_priority,
                checkbox=cb,
            )
            current_sprint.items.append(item)
            last_item = item
            continue

        # Detect metric line (must follow an item)
        if last_item is not None:
            m_metric = _METRIC_LINE.match(line)
            if m_metric:
                last_item.metric = m_metric.group("text").strip()
                continue

        # Any other non-blank, non-indented line resets last_item context
        if line.strip() and not line.startswith("  "):
            last_item = None


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def parse(path: Path) -> RoadmapData:
    """Parse Roadmap.md into structured data."""
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    sprints = _parse_overview(lines)
    _parse_sprint_sections(lines, sprints)

    return RoadmapData(overview=sprints)


def get_sprint(data: RoadmapData, sprint_key: str) -> RoadmapSprint | None:
    """Get a specific sprint by key (e.g. 'S1')."""
    for s in data.overview:
        if s.sprint_key == sprint_key:
            return s
    return None


def get_active_sprint(data: RoadmapData) -> RoadmapSprint | None:
    """Get the sprint with status 'Active'."""
    for s in data.overview:
        if s.status.lower().startswith("active"):
            return s
    return None


def get_items_by_priority(
    data: RoadmapData, sprint_key: str, priority: str
) -> list[RoadmapItem]:
    """Get items for a sprint filtered by priority (must/should/could)."""
    sprint = get_sprint(data, sprint_key)
    if sprint is None:
        return []
    p = priority.lower()
    return [i for i in sprint.items if i.priority == p]


def count_items(data: RoadmapData, sprint_key: str) -> dict[str, int]:
    """Count items by priority for a sprint. Returns {'must': N, 'should': N, 'could': N}."""
    sprint = get_sprint(data, sprint_key)
    counts = {"must": 0, "should": 0, "could": 0}
    if sprint is None:
        return counts
    for item in sprint.items:
        if item.priority in counts:
            counts[item.priority] += 1
    return counts
