"""Read-only parser for Entry Gate and Close Gate report files."""

from __future__ import annotations

import re
from pathlib import Path

from sprint_lib.models import Metric


# ---------------------------------------------------------------------------
# File discovery
# ---------------------------------------------------------------------------

def find_gate_file(
    root: Path,
    sprint_n: int,
    gate_type: str = "entry",
) -> Path | None:
    """Find gate report file for a sprint.

    Searches common locations for both entry and close gate reports.
    *gate_type*: ``"entry"`` or ``"close"``.
    Returns ``None`` if not found.
    """
    tag = f"S{sprint_n}"

    if gate_type == "entry":
        candidates = [
            f"{tag}_ENTRY_GATE.md",
            f"Docs/Planning/{tag}_ENTRY_GATE.md",
            f"Docs/{tag}_ENTRY_GATE.md",
        ]
    else:
        candidates = [
            "CLOSE_GATE_REPORT.md",
            f"{tag}_CLOSE_GATE.md",
            f"Docs/Planning/{tag}_CLOSE_GATE.md",
            f"Docs/Planning/CLOSE_GATE_REPORT.md",
            f"Docs/{tag}_CLOSE_GATE.md",
            f"Docs/CLOSE_GATE_REPORT.md",
        ]

    for rel in candidates:
        p = root / rel
        if p.is_file():
            return p
    return None


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_KV_RE = re.compile(r"\*\*([^*:]+):?\*\*:?\s*(.+)")


def _header_kv(text: str) -> dict[str, str]:
    """Extract ``**Key:** value`` pairs from the header area."""
    kv: dict[str, str] = {}
    for m in _KV_RE.finditer(text):
        kv[m.group(1).strip()] = m.group(2).strip()
    return kv


def _extract_sprint_label(text: str) -> str:
    """Return sprint label like ``S1`` from header metadata."""
    m = re.search(r"\bS(\d+)\b", text)
    return m.group(0) if m else ""


def _is_approved(text: str) -> bool:
    """Detect approval markers anywhere in the text."""
    lower = text.lower()
    return any(
        marker in lower
        for marker in ("gate passed", "approved", "approved ✓")
    )


def _parse_table_rows(block: str) -> list[dict[str, str]]:
    """Parse a markdown table block into a list of dicts keyed by header."""
    lines = [ln.strip() for ln in block.strip().splitlines() if ln.strip()]
    if len(lines) < 2:
        return []

    def _cells(line: str) -> list[str]:
        line = line.strip().strip("|")
        return [c.strip() for c in line.split("|")]

    headers = _cells(lines[0])
    # skip separator line (index 1)
    rows: list[dict[str, str]] = []
    for line in lines[2:]:
        if re.match(r"^[\s|:-]+$", line):
            continue
        vals = _cells(line)
        row = {h: (vals[i] if i < len(vals) else "") for i, h in enumerate(headers)}
        rows.append(row)
    return rows


def _find_section(text: str, heading_pattern: str) -> str:
    """Return text from the matched heading until the next heading of same or
    higher level, or end of file."""
    m = re.search(
        rf"^(#{{1,6}})\s+{heading_pattern}",
        text,
        re.MULTILINE | re.IGNORECASE,
    )
    if not m:
        return ""
    level = len(m.group(1))
    start = m.end()
    # Find next heading of same or higher (fewer #) level
    nxt = re.search(
        rf"^#{{{1},{level}}}\s",
        text[start:],
        re.MULTILINE,
    )
    end = start + nxt.start() if nxt else len(text)
    return text[start:end]


def _table_in(section: str) -> str:
    """Return the first markdown table found in *section* (including header
    and separator lines)."""
    lines = section.splitlines()
    table_lines: list[str] = []
    in_table = False
    for ln in lines:
        stripped = ln.strip()
        if "|" in stripped and not stripped.startswith("```"):
            in_table = True
            table_lines.append(stripped)
        elif in_table:
            break
    return "\n".join(table_lines)


# ---------------------------------------------------------------------------
# Metric extraction
# ---------------------------------------------------------------------------

def extract_metrics(path: Path) -> list[Metric]:
    """Extract metrics from an Entry Gate report.

    Handles two common formats:

    1. Inline under item lines::

           - [ ] CORE-001: description
             - **Metric:** some metric text

    2. Markdown tables with columns containing *Item* and *Metric*.
    """
    text = path.read_text(encoding="utf-8")
    metrics: list[Metric] = []
    seen: set[tuple[str, str]] = set()

    # --- Pattern 1: indented bullet metrics under item lines ---------------
    item_re = re.compile(
        r"^[\s-]*\[.\]\s*([\w-]+)\s*:", re.MULTILINE,
    )
    inline_metric_re = re.compile(
        r"^\s+-\s+\*\*Metric\*\*:\s*(.+)", re.MULTILINE,
    )
    for item_m in item_re.finditer(text):
        item_id = item_m.group(1)
        # Search lines immediately following
        rest = text[item_m.end(): item_m.end() + 500]
        for mm in inline_metric_re.finditer(rest):
            # Stop if we hit the next item
            between = rest[: mm.start()]
            if item_re.search(between):
                break
            key = (item_id, mm.group(1).strip())
            if key not in seen:
                seen.add(key)
                metrics.append(Metric(item_id=item_id, metric_text=mm.group(1).strip()))

    # --- Pattern 2: tables with Item + Metric columns ----------------------
    # Look in several possible sections
    for heading in (
        r"Metric Sufficiency",
        r"Verification Plan",
        r"Step 9c",
        r"Step 9b",
        r"Metric Verification",
    ):
        section = _find_section(text, heading)
        if not section:
            continue
        table = _table_in(section)
        if not table:
            continue
        rows = _parse_table_rows(table)
        for row in rows:
            item_id = ""
            metric_text = ""
            for k, v in row.items():
                kl = k.lower()
                if kl in ("item", "item(s)", "#"):
                    item_id = v.strip()
                elif "metric" in kl:
                    metric_text = v.strip()
            if item_id and metric_text:
                key = (item_id, metric_text)
                if key not in seen:
                    seen.add(key)
                    metrics.append(Metric(item_id=item_id, metric_text=metric_text))

    return metrics


# ---------------------------------------------------------------------------
# Entry Gate parser
# ---------------------------------------------------------------------------

def parse_entry_gate(path: Path) -> dict:
    """Parse an Entry Gate report.

    Returns a dict with keys:

    - ``sprint_label`` (str)
    - ``date`` (str)
    - ``approved`` (bool)
    - ``metrics`` (list[Metric])
    - ``failure_modes`` (list[dict] with keys item, category, mode, detection)
    """
    text = path.read_text(encoding="utf-8")
    kv = _header_kv(text)

    sprint_label = _extract_sprint_label(kv.get("Sprint", text))
    date = kv.get("Date", "")

    # --- Metrics ---
    metrics = extract_metrics(path)

    # --- Failure modes (Step 9a table) ---
    failure_modes: list[dict] = []
    for heading in (r"Failure Mode Analysis", r"Step 9a"):
        section = _find_section(text, heading)
        if section:
            break
    if section:
        table = _table_in(section)
        if table:
            rows = _parse_table_rows(table)
            for row in rows:
                fm: dict[str, str] = {}
                for k, v in row.items():
                    kl = k.lower()
                    if kl == "item":
                        fm["item"] = v
                    elif kl == "category":
                        fm["category"] = v
                    elif "mode" in kl or "predicted" in kl:
                        fm["mode"] = v
                    elif "detection" in kl or "plan" in kl:
                        fm["detection"] = v
                if fm.get("item"):
                    failure_modes.append(fm)

    return {
        "sprint_label": sprint_label,
        "date": date,
        "approved": _is_approved(text),
        "metrics": metrics,
        "failure_modes": failure_modes,
    }


# ---------------------------------------------------------------------------
# Close Gate parser
# ---------------------------------------------------------------------------

def parse_close_gate(path: Path) -> dict:
    """Parse a Close Gate report.

    Returns a dict with keys:

    - ``sprint_label`` (str)
    - ``date`` (str)
    - ``verdict`` (str — ``"PASS"`` or ``"FAIL"``)
    - ``metrics`` (list[Metric] with status filled in)
    - ``findings_count`` (int)
    - ``tests_passed`` (int)
    - ``tests_total`` (int)
    """
    text = path.read_text(encoding="utf-8")
    kv = _header_kv(text)

    sprint_label = _extract_sprint_label(kv.get("Sprint", text))
    date = kv.get("Date", "")

    # --- Verdict ---
    verdict = "PASS" if _is_approved(text) else "FAIL"
    # Explicit FAIL override
    if re.search(r"Gate\s+failed|verdict.*FAIL", text, re.IGNORECASE):
        verdict = "FAIL"

    # --- Metrics from Phase 0 table ---
    metrics: list[Metric] = []
    section = _find_section(text, r"(?:Phase\s*0|Metric Verification)")
    if section:
        table = _table_in(section)
        if table:
            rows = _parse_table_rows(table)
            for row in rows:
                item_id = ""
                metric_text = ""
                status = ""
                evidence = ""
                for k, v in row.items():
                    kl = k.lower()
                    if kl in ("item", "item(s)", "#"):
                        item_id = v.strip()
                    elif "metric" in kl:
                        metric_text = v.strip()
                    elif kl == "status":
                        status = v.strip()
                    elif "evidence" in kl or "escalation" in kl:
                        evidence = v.strip()
                if item_id and metric_text:
                    metrics.append(Metric(
                        item_id=item_id,
                        metric_text=metric_text,
                        status=status,
                        evidence=evidence,
                    ))

    # --- Findings count ---
    findings_count = 0
    fm = re.search(r"(\d+)\s+findings?", text, re.IGNORECASE)
    if fm:
        findings_count = int(fm.group(1))
    # Also try "Findings summary:" line
    fs = re.search(
        r"Findings summary.*?(\d+)\s+total",
        text,
        re.IGNORECASE,
    )
    if fs:
        findings_count = int(fs.group(1))

    # --- Test counts ---
    tests_passed = 0
    tests_total = 0
    # Pattern: "Tests: 18 passed, 18 total" or "18/18 PASS"
    tp = re.search(r"Tests:\s*(\d+)\s+passed,\s*(\d+)\s+total", text)
    if tp:
        tests_passed = int(tp.group(1))
        tests_total = int(tp.group(2))
    else:
        tp2 = re.search(r"(\d+)/(\d+)\s+(?:PASS|pass)", text)
        if tp2:
            tests_passed = int(tp2.group(1))
            tests_total = int(tp2.group(2))

    return {
        "sprint_label": sprint_label,
        "date": date,
        "verdict": verdict,
        "metrics": metrics,
        "findings_count": findings_count,
        "tests_passed": tests_passed,
        "tests_total": tests_total,
    }
