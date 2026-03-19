from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Item:
    id: str
    summary: str
    status: str
    sprint: str
    priority: str
    evidence: str = ""


@dataclass
class Risk:
    id: str
    risk: str
    mitigation: str
    sprint: str = ""


@dataclass
class BaselineEntry:
    sprint: str
    metric: str
    value: str
    unit: str
    method: str


@dataclass
class FailureMode:
    item: str
    category: str
    predicted_mode: str
    detection_plan: str


@dataclass
class FailureEncounter:
    item: str
    category: str
    description: str
    detection: str
    date: str


@dataclass
class FailureHistory:
    sprint: str
    category: str
    predicted: str
    detection: str
    mode: str
    impact: str
    root_cause: str
    guardrail: str
    escalate: str


@dataclass
class DismissedSignal:
    date: str
    checkpoint: str
    system_metric: str
    signal_summary: str
    user_decision: str
    dismissal_num: str
    suppressed: str
    revisit_sprint: str


@dataclass
class Metric:
    item_id: str
    metric_text: str
    status: str = ""
    evidence: str = ""


@dataclass
class RoadmapItem:
    id: str
    description: str
    priority: str
    checkbox: str
    metric: str = ""


@dataclass
class RoadmapSprint:
    sprint_key: str
    title: str
    status: str
    items: list[RoadmapItem] = field(default_factory=list)


@dataclass
class RoadmapData:
    overview: list[RoadmapSprint] = field(default_factory=list)


@dataclass
class WorkingContext:
    task: str = ""
    doing: str = ""
    decisions: str = ""
    blockers: str = ""


@dataclass
class SessionNote:
    """A single session journal entry (append-only)."""
    seq: int
    note_type: str  # decision | attempt | side-effect | observation | artifact
    text: str
    item: str = ""  # CORE-NNN if linked
    timestamp: str = ""


@dataclass
class SprintDigest:
    sprint_n: int
    sprint_type: str = "feature"
    items: list[Item] = field(default_factory=list)
    risks: list[Risk] = field(default_factory=list)
    recurring_failure_categories: list[str] = field(default_factory=list)
    latest_baselines: list[BaselineEntry] = field(default_factory=list)
    entry_gate_exists: bool = False
    phase: str = "unknown"  # planned|entry_gate|impl_loop|impl_done|close_gate|sprint_close|done
    working_context: Optional[WorkingContext] = None
    session_note_count: int = 0
    failure_encounters: list[FailureEncounter] = field(default_factory=list)


@dataclass
class TrackingData:
    current_focus: str = ""
    working_context: Optional[WorkingContext] = None
    items: list[Item] = field(default_factory=list)
    risks: list[Risk] = field(default_factory=list)
    predicted_failures: list[FailureMode] = field(default_factory=list)
    failure_encounters: list[FailureEncounter] = field(default_factory=list)
    failure_history: list[FailureHistory] = field(default_factory=list)
    baselines: list[BaselineEntry] = field(default_factory=list)
    dismissed_signals: list[DismissedSignal] = field(default_factory=list)
    changelog_entries: dict[str, list[str]] = field(default_factory=dict)
    session_notes: list[SessionNote] = field(default_factory=list)


NOTE_TYPES = {"decision", "attempt", "side-effect", "observation", "artifact"}

# Shared regex for detecting markdown table separator rows (e.g. |---|---|)
TABLE_SEPARATOR_RE = re.compile(r"^\|[\s\-:#|]+\|?\s*$")

VALID_STATUSES = {"open", "in_progress", "fixed", "verified", "deferred", "blocked"}

VALID_TRANSITIONS = {
    "open": {"in_progress", "blocked", "deferred"},
    "in_progress": {"fixed", "blocked", "deferred"},
    "fixed": {"verified", "in_progress", "deferred"},
    "verified": {"open"},  # regression
    "blocked": {"open", "in_progress", "deferred"},
    "deferred": {"open"},
}

PRIORITIES = {"must", "should", "could"}
