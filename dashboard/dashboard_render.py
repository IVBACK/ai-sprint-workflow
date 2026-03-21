"""Data collection, post-processing, and CLI rendering for sprint-status.

This module contains:
- File discovery (find_project_root, find_file, find_all_gate_reports)
- Data parsers (parse_tracking, parse_roadmap, parse_gate_report) — via sprint_lib
- Post-processing (build_sprint_failure_analysis, build_trends)
- v3.1 collectors (hooks, workflow config, knowledge, validation)
- Sprint phase inference
- CLI renderer

Markdown parsing (tables, sections) is provided by sprint_lib.utils — no local
duplicates.  If sprint_lib is unavailable, the dashboard returns empty data
(graceful degradation) rather than maintaining a parallel parser.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


# ─── File Discovery ───────────────────────────────────────────────────────────

def find_project_root(start: str = ".") -> Optional[Path]:
    current = Path(start).resolve()
    for _ in range(10):
        if (current / "TRACKING.md").exists():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    return None


def find_file(root: Path, name: str) -> Optional[Path]:
    try:
        search_depth = max(1, min(10, int(os.environ.get("DASHBOARD_SEARCH_DEPTH", "3"))))
    except (ValueError, TypeError):
        search_depth = 3
    for depth in range(search_depth):
        for p in root.glob("/".join(["*"] * depth + [name])):
            if p.is_file():
                return p
    return None


def find_all_gate_reports(root: Path) -> List[Tuple[str, Path]]:
    """Find all gate reports and return (gate_type, path) tuples."""
    results: List[Tuple[str, Path]] = []
    search_dirs = [root]
    if root.parent != root:
        search_dirs.append(root.parent)
    for search_dir in search_dirs:
        for p in sorted(search_dir.glob("**/S*_ENTRY_GATE.md")):
            results.append(("entry", p))
        for p in sorted(search_dir.glob("**/*CLOSE_GATE*.md")):
            results.append(("close", p))
        for p in sorted(search_dir.glob("**/SPRINT_CLOSE*.md")):
            results.append(("sprint_close", p))
    seen = set()
    deduped = []
    for gate_type, path in results:
        rp = str(path.resolve())
        if rp not in seen:
            seen.add(rp)
            deduped.append((gate_type, path))
    return deduped


# ─── sprint_lib Integration ──────────────────────────────────────────────────

def _init_sprint_lib():
    """Add Tools/ to sys.path so sprint_lib is importable."""
    tools_dir = Path(__file__).resolve().parent.parent / "Tools"
    if not tools_dir.is_dir():
        raise ImportError(f"sprint_lib not found: {tools_dir} does not exist")
    canonical = str(tools_dir)
    if canonical not in sys.path:
        sys.path.insert(0, canonical)

_init_sprint_lib()

from sprint_lib.utils import (  # noqa: E402 (import after sys.path modification)
    WC_PLACEHOLDERS,
    extract_section,
    extract_table_from_section,
    safe_float,
)


# ─── Data Parsers ─────────────────────────────────────────────────────────────


_EMPTY_TRACKING: Dict[str, Any] = {
    "items": [], "status_counts": {}, "total_items": 0, "completed_items": 0,
    "sprints": [], "risks": [], "failure_history": [], "performance": [],
    "predicted_failures": [], "failure_encounters": [], "dismissed_signals": [],
    "changelog_lines": [], "changelog_by_sprint": {},
    "working_context": {}, "session_notes": [],
    "current_focus": "Parse error",
}


def parse_tracking(path: Path) -> Dict[str, Any]:
    """Parse TRACKING.md via sprint_lib.  Returns empty structure on failure."""
    try:
        from sprint_lib.tracking_parser import parse as _parse

        td = _parse(path)

        items = [
            {"id": i.id, "summary": i.summary, "status": i.status,
             "sprint": i.sprint, "priority": i.priority, "evidence": i.evidence}
            for i in td.items
        ]
        statuses = [it["status"] for it in items]
        risks = [
            {"id": r.id, "risk": r.risk, "mitigation": r.mitigation, "sprint": r.sprint}
            for r in td.risks
        ]
        failure_history = [
            {"sprint": fh.sprint, "category": fh.category, "predicted": fh.predicted,
             "detection": fh.detection, "mode": fh.mode, "impact": fh.impact,
             "root_cause": fh.root_cause, "guardrail": fh.guardrail, "escalate": fh.escalate}
            for fh in td.failure_history
        ]
        performance = [
            {"sprint": b.sprint, "metric": b.metric, "value": b.value,
             "unit": b.unit, "method": b.method}
            for b in td.baselines
        ]
        predicted_failures = [
            {"item": pf.item, "category": pf.category,
             "predicted_mode": pf.predicted_mode, "detection_plan": pf.detection_plan}
            for pf in td.predicted_failures
        ]
        failure_encounters = [
            {"item": fe.item, "category": fe.category, "failure_description": fe.description,
             "detection": fe.detection, "date": fe.date}
            for fe in td.failure_encounters
        ]
        dismissed_signals = [
            {"date": ds.date, "checkpoint": ds.checkpoint, "system_metric": ds.system_metric,
             "signal_summary": ds.signal_summary, "user_decision": ds.user_decision,
             "dismissal": ds.dismissal_num, "suppressed": ds.suppressed,
             "revisit_sprint": ds.revisit_sprint}
            for ds in td.dismissed_signals
        ]
        changelog_lines = []
        changelog_by_sprint: Dict[str, List[str]] = {}
        for key, entries in td.changelog_entries.items():
            changelog_lines.extend(entries)
            sm = re.match(r"Sprint\s+(\d+)", key)
            sprint_key = f"S{sm.group(1)}" if sm else key
            changelog_by_sprint[sprint_key] = entries

        wc = td.working_context
        if wc and any(v and v not in WC_PLACEHOLDERS for v in [wc.task, wc.doing, wc.decisions, wc.blockers]):
            working_context = {
                "task": wc.task, "doing": wc.doing,
                "decisions": wc.decisions, "blockers": wc.blockers,
            }
        else:
            working_context = {}

        session_notes = [
            {"seq": n.seq, "type": n.note_type, "text": n.text,
             "item": n.item, "timestamp": n.timestamp}
            for n in td.session_notes
        ]

        return {
            "current_focus": td.current_focus or "Unknown",
            "working_context": working_context,
            "session_notes": session_notes,
            "items": items,
            "status_counts": {
                "open": statuses.count("open"), "in_progress": statuses.count("in_progress"),
                "fixed": statuses.count("fixed"), "verified": statuses.count("verified"),
                "blocked": statuses.count("blocked"), "deferred": statuses.count("deferred"),
            },
            "total_items": len(items),
            "completed_items": statuses.count("verified"),
            "sprints": sorted(set(it["sprint"] for it in items if it.get("sprint"))),
            "risks": risks,
            "failure_history": failure_history,
            "performance": performance,
            "predicted_failures": predicted_failures,
            "failure_encounters": failure_encounters,
            "dismissed_signals": dismissed_signals,
            "changelog_lines": changelog_lines,
            "changelog_by_sprint": changelog_by_sprint,
        }
    except Exception:
        return dict(_EMPTY_TRACKING)


def parse_roadmap(path: Path) -> Dict[str, Any]:
    """Parse Roadmap.md via sprint_lib.  Returns empty structure on failure."""
    try:
        from sprint_lib.roadmap_parser import parse as _parse

        rd = _parse(path)

        overview = [
            {"sprint": s.sprint_key, "theme": s.title, "status": s.status}
            for s in rd.overview
        ]
        sprint_items: Dict[str, Dict[str, Any]] = {}
        for s in rd.overview:
            items = [
                {"id": i.id, "description": i.description,
                 "status": i.checkbox, "priority": i.priority}
                for i in s.items
            ]
            sprint_items[s.sprint_key] = {"title": s.title, "items": items}

        return {"overview": overview, "sprints": sprint_items}
    except Exception:
        return {"overview": [], "sprints": {}}


def parse_gate_report(path: Path, gate_type: str) -> Dict[str, Any]:
    """Parse gate report via sprint_lib (header + details).

    Uses sprint_lib.gate_parser for close/entry gates and sprint_lib.utils
    (extract_table_from_section) for detail tables.  Returns minimal data
    on failure (graceful degradation).
    """
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(encoding="utf-8", errors="replace")
    data: Dict[str, Any] = {"exists": True, "path": str(path)}

    # --- Header metadata via sprint_lib gate parsers ---
    try:
        if gate_type == "close":
            from sprint_lib.gate_parser import parse_close_gate
            gd = parse_close_gate(path)
            data["date"] = gd.get("date", "")
            data["sprint_label"] = gd.get("sprint_label", "")
            data["sprint_raw"] = gd.get("sprint_label", "")
            data["approved"] = gd.get("verdict", "") == "PASS" or bool(
                re.search(r"\*\*PASS\*\*", text) or re.search(r"Verdict:\s*PASS", text, re.IGNORECASE)
            )
            if gd.get("tests_passed"):
                data["tests_passed"] = gd["tests_passed"]
                data["tests_total"] = gd["tests_total"]
        elif gate_type == "entry":
            from sprint_lib.gate_parser import parse_entry_gate
            gd = parse_entry_gate(path)
            data["date"] = gd.get("date", "")
            data["sprint_label"] = gd.get("sprint_label", "")
            data["sprint_raw"] = gd.get("sprint_label", "")
            data["approved"] = gd.get("approved", False)
        else:
            # sprint_close — no sprint_lib parser, extract from text directly
            date_match = re.search(r"\*\*Date:\*\*\s*(.+)", text)
            data["date"] = date_match.group(1).strip() if date_match else ""
            data["approved"] = bool(
                re.search(r"Gate passed", text) or re.search(r"\*\*PASS\*\*", text)
                or re.search(r"Verdict:\s*PASS", text, re.IGNORECASE)
            )
    except Exception:
        pass  # header fields default to empty

    # Fallback sprint_label from filename or title
    if not data.get("sprint_label"):
        sn = re.search(r'S(\d+)', path.name)
        if sn:
            data["sprint_label"] = f"S{sn.group(1)}"
        else:
            title_match = re.search(r'Sprint\s+(\d+)', text[:200])
            if title_match:
                data["sprint_label"] = f"S{title_match.group(1)}"

    # --- Detail tables via sprint_lib ---
    if gate_type == "close":
        try:
            from sprint_lib.gate_parser import extract_close_gate_details
            details = extract_close_gate_details(path)
            data.update(details)
            if "tests_passed" not in data and details.get("tests_passed"):
                data["tests_passed"] = details["tests_passed"]
                data["tests_total"] = details["tests_total"]
        except Exception:
            pass  # close gate detail tables unavailable
    elif gate_type == "entry":
        data["alignment"] = extract_table_from_section(text, "Step 8")
        data["failure_modes"] = extract_table_from_section(text, "Step 9a")
        data["verification_plan"] = extract_table_from_section(text, "Step 9b")
        data["metric_sufficiency"] = extract_table_from_section(text, "Step 9c")
    elif gate_type == "sprint_close":
        data["checkmarks"] = extract_table_from_section(text, "Step 1")
        data["baseline"] = extract_table_from_section(text, "Step 5")
        data["retrospective"] = extract_table_from_section(text, "Step 7") or extract_table_from_section(text, "Failure Mode Retrospective")
    return data


# ─── Post-Processing ──────────────────────────────────────────────────────────

def build_sprint_failure_analysis(gates: Dict[str, Any], tracking_fh: List[Dict], sprint_label: str) -> Dict[str, Any]:
    """Build failure analysis for a specific sprint."""
    analysis = {"total_predicted": 0, "total_occurred": 0, "predicted_and_caught": 0,
                "unpredicted": 0, "new_guardrails": 0, "details": [], "close_gate_findings": 0}

    sprint_close = gates.get("sprint_close", {})
    retro = sprint_close.get("retrospective", [])
    if retro:
        for row in retro:
            predicted = row.get("predicted?", row.get("predicted", row.get("predicted_mode", ""))).lower().strip("*")
            occurred = row.get("actually_occurred?", row.get("occurred?", "")).lower().strip("*")
            guardrail = row.get("new_guardrail?", row.get("new_guardrail", "")).strip("*").strip()
            mode = row.get("item", row.get("predicted_mode", "")).strip("*").strip()
            is_predicted = predicted.startswith("yes")
            is_occurred = occurred not in ("no", "\u2014", "-", "") and "same failure" not in occurred
            if is_predicted:
                analysis["total_predicted"] += 1
            if is_occurred:
                analysis["total_occurred"] += 1
                if is_predicted:
                    analysis["predicted_and_caught"] += 1
                else:
                    analysis["unpredicted"] += 1
                analysis["details"].append({
                    "mode": mode, "predicted": is_predicted, "impact": row.get("impact", ""),
                    "root_cause": row.get("root_cause", ""), "guardrail": guardrail,
                    "escalate": row.get("escalate?", row.get("escalate", "")),
                })
            if guardrail and guardrail.lower() not in ("no", "\u2014", "-", "") and not guardrail.startswith("covered"):
                analysis["new_guardrails"] += 1
    else:
        for row in tracking_fh:
            if row.get("sprint", "").strip() != sprint_label:
                continue
            predicted = row.get("predicted?", row.get("predicted", "")).lower()
            guardrail = row.get("guardrail", "").strip()
            analysis["total_occurred"] += 1
            if predicted.startswith("yes"):
                analysis["total_predicted"] += 1
                analysis["predicted_and_caught"] += 1
            else:
                analysis["unpredicted"] += 1
            if guardrail and guardrail.lower() not in ("no", "\u2014", "-", ""):
                analysis["new_guardrails"] += 1
            analysis["details"].append({
                "mode": row.get("mode", ""), "predicted": predicted.startswith("yes"),
                "impact": row.get("impact", ""), "root_cause": row.get("root_cause", ""), "guardrail": guardrail,
                "escalate": row.get("escalate?", row.get("escalate", "")),
            })
    close_gate = gates.get("close", {})
    analysis["close_gate_findings"] = len(close_gate.get("findings", []))
    return analysis


_safe_float = safe_float


def build_trends(sprint_data_list: List[Dict], tracking: Dict, all_failure_history: List[Dict]) -> Dict[str, Any]:
    """Derive cross-sprint trend metrics."""
    trends: Dict[str, Any] = {"sprints": []}
    total_predicted = 0
    total_occurred = 0
    total_caught = 0
    total_unpredicted = 0
    total_guardrails = 0

    for sd in sprint_data_list:
        fa = sd.get("failure_analysis", {})
        gates = sd.get("gates", {})
        items = sd.get("items", [])
        total = len(items)
        deferred = sum(1 for i in items if i.get("status", "").lower() == "deferred")

        sprint_trend: Dict[str, Any] = {
            "sprint": sd["label"],
            "total_items": total,
            "deferred": deferred,
            "deferred_ratio": round(deferred / total, 2) if total else 0,
        }

        cg = gates.get("close", {})
        if cg.get("exists"):
            metrics = cg.get("metrics", [])
            verdicts = [(m.get("verdict", "") or m.get("status", "")).upper().strip() for m in metrics]
            rework = sum(1 for v in verdicts if v and v not in ("PASS", "DEFERRED", "N/A", ""))
            total_metrics = len(verdicts) if verdicts else 1
            sprint_trend["rework_count"] = rework
            sprint_trend["rework_rate"] = round(rework / total_metrics, 2) if total_metrics else 0
            sprint_trend["first_pass"] = total_metrics - rework
            sprint_trend["first_pass_rate"] = round((total_metrics - rework) / total_metrics, 2) if total_metrics else 0
            findings_count = len(cg.get("findings", []))
            sprint_trend["findings_count"] = findings_count
            sprint_trend["finding_density"] = round(findings_count / total, 2) if total else 0

        total_predicted += fa.get("total_predicted", 0)
        total_occurred += fa.get("total_occurred", 0)
        total_caught += fa.get("predicted_and_caught", 0)
        total_unpredicted += fa.get("unpredicted", 0)
        total_guardrails += fa.get("new_guardrails", 0)

        trends["sprints"].append(sprint_trend)

    trends["prediction_accuracy"] = {
        "total_predicted": total_predicted,
        "total_occurred": total_occurred,
        "caught": total_caught,
        "unpredicted": total_unpredicted,
        "accuracy": round(total_caught / total_occurred, 2) if total_occurred > 0 else None,
    }
    trends["guardrail_velocity"] = total_guardrails

    perf = tracking.get("performance", [])
    perf_by_metric: Dict[str, List[Dict[str, Any]]] = {}
    for p in perf:
        key = p.get("metric", "")
        if key not in perf_by_metric:
            perf_by_metric[key] = []
        perf_by_metric[key].append({
            "sprint": p.get("sprint", ""),
            "value": _safe_float(p.get("value", "")),
            "unit": p.get("unit", ""),
        })
    trends["performance_trend"] = perf_by_metric

    cat_sprints: Dict[str, List[str]] = {}
    for row in all_failure_history:
        cat = row.get("category", "").strip()
        sprint = row.get("sprint", "").strip()
        if cat and sprint:
            cat_sprints.setdefault(cat, []).append(sprint)
    recurrences = []
    for cat, sprints_list in cat_sprints.items():
        unique = sorted(set(sprints_list))
        if len(unique) > 1:
            recurrences.append({"category": cat, "sprints": unique, "count": len(unique)})
    trends["failure_recurrence"] = recurrences
    trends["has_recurrence"] = len(recurrences) > 0

    guardrails_created: Dict[str, str] = {}
    for row in all_failure_history:
        gr = row.get("guardrail", "").strip()
        gr_match = re.search(r"(G-[A-Z0-9][-\w]*)", gr, re.IGNORECASE)
        gr = gr_match.group(1) if gr_match else gr
        sprint = row.get("sprint", "").strip()
        if gr and gr.lower() not in ("no", "\u2014", "-", "") and sprint:
            guardrails_created[gr] = sprint
    for sd in sprint_data_list:
        retro = sd.get("gates", {}).get("sprint_close", {}).get("retrospective", [])
        for row in retro:
            gr_raw = row.get("new_guardrail?", row.get("new_guardrail", "")).strip("*").strip()
            gr_match2 = re.search(r"(G-[A-Z0-9][-\w]*)", gr_raw, re.IGNORECASE)
            gr2 = gr_match2.group(1) if gr_match2 else gr_raw
            if gr2 and gr2.lower() not in ("no", "\u2014", "-", "") and not gr2.startswith("covered"):
                guardrails_created[gr2] = sd["label"]

    guardrail_effectiveness = []
    for gr_id, created_sprint in guardrails_created.items():
        created_num = int(re.search(r"\d+", created_sprint).group()) if re.search(r"\d+", created_sprint) else 0
        recurred = False
        recurred_in = []
        for row in all_failure_history:
            row_sprint = row.get("sprint", "")
            row_num = int(re.search(r"\d+", row_sprint).group()) if re.search(r"\d+", row_sprint) else 0
            if row_num > created_num:
                row_gr = row.get("guardrail", "").strip()
                row_gr_match = re.search(r"(G-[A-Z0-9][-\w]*)", row_gr, re.IGNORECASE)
                if row_gr_match and row_gr_match.group(1) == gr_id:
                    recurred = True
                    recurred_in.append(row_sprint)
        guardrail_effectiveness.append({
            "guardrail": gr_id, "created_sprint": created_sprint,
            "effective": not recurred, "recurred_in": recurred_in,
        })
    trends["guardrail_effectiveness"] = guardrail_effectiveness
    trends["guardrails_total"] = len(guardrail_effectiveness)
    trends["guardrails_effective"] = sum(1 for g in guardrail_effectiveness if g["effective"])

    return trends


# ─── v3.1 Data Collectors ────────────────────────────────────────────────────

def collect_hooks_status(root: Path) -> Dict[str, Any]:
    hooks_dir = root / ".claude" / "hooks"
    config_path = root / ".claude" / "hooks-config.sh"
    hooks: List[Dict[str, Any]] = []
    if hooks_dir.is_dir():
        for f in sorted(hooks_dir.iterdir()):
            if f.suffix == ".sh" and not f.name.startswith("_"):
                hooks.append({"name": f.stem, "path": str(f.relative_to(root))})
    config_flags: Dict[str, bool] = {}
    if config_path.is_file():
        try:
            text = config_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = config_path.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'^HOOK_(\w+)=.*\$\{HOOK_\1:-\$_(\w+)\}', text, re.MULTILINE):
            config_flags[m.group(1).lower()] = True
        for m in re.finditer(r'_(\w+)=(true|false)', text):
            key = m.group(1).lower()
            config_flags[key] = m.group(2) == "true"
    flag_map = {
        "protect-claude": "protect_claude_md", "protect-secrets": "protect_secrets",
        "validate-tracking": "validate_tracking", "session-start": "session_start_protocol",
        "validate-id-uniqueness": "validate_id_uniqueness",
        "entry-gate-session": "entry_gate_session",
        "detect-test-regression": "detect_test_regression",
        "validate-close-gate": "validate_close_gate",
        "validate-sprint-close": "validate_sprint_close",
        "detect-audit-signals": "detect_audit_signals",
        "memory-sync": "memory_sync", "cross-llm-audit": "cross_llm_audit",
        "bootstrap-guard": "bootstrap_guard",
        "bootstrap-phase-gate": "bootstrap_phase_gate",
        "verify-evidence": "verify_evidence",
        "audit-health-check": "audit_health_check",
        "pre-merge-audit": "pre_merge_audit",
    }
    for h in hooks:
        flag_key = flag_map.get(h["name"], "")
        h["enabled"] = config_flags.get(flag_key, True) if flag_key else True
    return {
        "total": len(hooks),
        "enabled": sum(1 for h in hooks if h["enabled"]),
        "hooks": hooks,
    }


def collect_workflow_config(root: Path) -> Dict[str, str]:
    config_path = root / ".claude" / "hooks-config.sh"
    result = {"workflow_mode": "standard", "sprint_type": "", "hooks_version": ""}
    if config_path.is_file():
        try:
            text = config_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = config_path.read_text(encoding="utf-8", errors="replace")
        m = re.search(r'^WORKFLOW_MODE="(\w+)"', text, re.MULTILINE)
        if m:
            result["workflow_mode"] = m.group(1)
        m = re.search(r'^SPRINT_TYPE="(\w+)"', text, re.MULTILINE)
        if m:
            result["sprint_type"] = m.group(1)
        m = re.search(r'^HOOKS_VERSION="([^"]+)"', text, re.MULTILINE)
        if m:
            result["hooks_version"] = m.group(1)
    return result


def collect_knowledge(root: Path) -> Dict[str, int]:
    result = {"guardrails": 0, "index_entries": 0}
    for name in ("CODING_GUARDRAILS.md", "Docs/CODING_GUARDRAILS.md"):
        p = root / name
        if p.is_file():
            try:
                text = p.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                text = p.read_text(encoding="utf-8", errors="replace")
            result["guardrails"] = len(re.findall(r"^(?:##?\s+G-?\d+|^-\s+\*\*G)", text, re.MULTILINE))
            if result["guardrails"] == 0:
                result["guardrails"] = len(re.findall(r"^[-*]\s+", text, re.MULTILINE))
            break
    for name in ("SPRINT-INDEX.md", "Docs/SPRINT-INDEX.md"):
        p = root / name
        if p.is_file():
            try:
                text = p.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                text = p.read_text(encoding="utf-8", errors="replace")
            result["index_entries"] = len(re.findall(r"^\|\s*\w", text, re.MULTILINE)) - 1
            if result["index_entries"] < 0:
                result["index_entries"] = 0
            break
    return result


def collect_validation(root: Path) -> Dict[str, Any]:
    script = root / "validation" / "validate-structure.sh"
    if not script.is_file():
        return {"available": False, "checks": [], "passed": 0, "failed": 0, "total": 0}
    try:
        result = subprocess.run(
            ["bash", str(script)], capture_output=True, text=True,
            timeout=15, cwd=str(root),
            env={**os.environ, "NO_COLOR": "1"},
        )
        output = result.stdout + result.stderr
        passed = len(re.findall(r"(?:PASS|CHECK|OK|✓)", output))
        failed = len(re.findall(r"(?:FAIL|ERROR|✗)", output))
        checks: List[Dict[str, str]] = []
        for line in output.splitlines():
            m = re.match(r"\s*(PASS|FAIL|CHECK|OK|ERROR|WARN|SKIP)\b[:\s]*(.*)", line, re.IGNORECASE)
            if m:
                checks.append({"status": m.group(1).upper(), "detail": m.group(2).strip()})
        return {
            "available": True, "checks": checks,
            "passed": passed, "failed": failed,
            "total": passed + failed,
            "exit_code": result.returncode,
        }
    except (subprocess.TimeoutExpired, OSError):
        return {"available": True, "checks": [], "passed": 0, "failed": 0, "total": 0, "error": "timeout"}


# ─── Sprint Phase Inference ───────────────────────────────────────────────────

def infer_sprint_phase(items: List[Dict], gates: Dict, changelog_lines: List[str]) -> str:
    all_cl = " ".join(changelog_lines).lower()
    sc_gate = gates.get("sprint_close", {})
    if sc_gate.get("exists") and sc_gate.get("approved"):
        return "done"
    if "sprint close" in all_cl:
        return "done"
    cg = gates.get("close", {})
    if cg.get("exists"):
        if cg.get("approved"):
            return "sprint_close"
        return "close_gate"
    must_items = [i for i in items if (i.get("priority") or "").lower() == "must"]
    has_wip = any(i.get("status") in ("in_progress", "fixed") for i in items)
    all_must_done = must_items and all(
        i.get("status") in ("verified", "deferred") for i in must_items
    )
    if has_wip:
        return "impl_loop"
    if all_must_done:
        return "impl_done"
    eg = gates.get("entry", {})
    if eg.get("exists"):
        if all(i.get("status", "open") == "open" for i in items) or not items:
            return "entry_gate"
        return "impl_loop"
    if any(i.get("status") != "open" for i in items):
        return "impl_loop"
    return "planned"


# ─── Main Data Collection ─────────────────────────────────────────────────────

def collect_data(root: Path) -> Dict[str, Any]:
    """Build project-level + per-sprint data model."""
    tracking_path = find_file(root, "TRACKING.md")
    tracking = parse_tracking(tracking_path) if tracking_path else {
        "items": [], "status_counts": {}, "total_items": 0, "completed_items": 0,
        "sprints": [], "risks": [], "failure_history": [], "performance": [],
        "predicted_failures": [], "failure_encounters": [], "dismissed_signals": [],
        "changelog_lines": [], "changelog_by_sprint": {},
        "working_context": {}, "session_notes": [],
        "current_focus": "No TRACKING.md found",
    }
    if "retroactive_audits" not in tracking and tracking_path:
        try:
            _text = tracking_path.read_text(encoding="utf-8", errors="replace")
            tracking["retroactive_audits"] = extract_table_from_section(_text, "Retroactive Audits")
        except OSError:
            tracking["retroactive_audits"] = []

    roadmap_path = find_file(root, "Roadmap.md")
    roadmap = parse_roadmap(roadmap_path) if roadmap_path else {"overview": [], "sprints": {}}

    gate_reports = find_all_gate_reports(root)
    parsed_gates: List[Tuple[str, Dict[str, Any]]] = []
    for gate_type, path in gate_reports:
        parsed = parse_gate_report(path, gate_type)
        parsed_gates.append((gate_type, parsed))

    sprint_labels = tracking.get("sprints", [])
    for key in roadmap.get("sprints", {}).keys():
        if key not in sprint_labels:
            sprint_labels.append(key)
    sprint_labels = sorted(set(sprint_labels), key=lambda s: int(re.search(r"\d+", s).group()) if re.search(r"\d+", s) else 0)

    sprints: Dict[str, Dict[str, Any]] = {}
    for s_label in sprint_labels:
        s_items = [i for i in tracking["items"] if i.get("sprint") == s_label]
        s_statuses = [i.get("status", "").lower() for i in s_items]

        s_gates: Dict[str, Any] = {}
        for gate_type, parsed in parsed_gates:
            if parsed.get("sprint_label") == s_label:
                s_gates[gate_type] = parsed
        for gt in ("entry", "close", "sprint_close"):
            if gt not in s_gates:
                s_gates[gt] = {"exists": False}

        s_failure_history = [r for r in tracking.get("failure_history", []) if r.get("sprint", "").strip() == s_label]
        fa = build_sprint_failure_analysis(s_gates, tracking.get("failure_history", []), s_label)
        s_perf = [p for p in tracking.get("performance", []) if p.get("sprint", "").strip() == s_label]
        s_item_ids = {i.get("id", "") for i in s_items}

        changelog_by_sprint = tracking.get("changelog_by_sprint", {})
        if s_label in changelog_by_sprint:
            s_changelog = changelog_by_sprint[s_label]
        else:
            s_changelog = []
            for line in tracking.get("changelog_lines", []):
                for item_id in s_item_ids:
                    if item_id in line:
                        s_changelog.append(line)
                        break
                else:
                    if s_label in line or s_label.replace("S", "Sprint ") in line:
                        s_changelog.append(line)

        s_roadmap = roadmap.get("sprints", {}).get(s_label, {})

        if all(s == "verified" for s in s_statuses) and s_statuses:
            s_status = "complete"
        elif any(s in ("in_progress", "fixed") for s in s_statuses):
            s_status = "active"
        elif all(s == "open" for s in s_statuses) and s_statuses:
            s_status = "planned"
        elif not s_items and s_roadmap:
            s_status = "planned"
        else:
            s_status = "unknown"

        s_phase = infer_sprint_phase(s_items, s_gates, s_changelog)

        sprints[s_label] = {
            "label": s_label,
            "theme": next(
                (row.get("theme", "") for row in roadmap.get("overview", [])
                 if row.get("sprint", "").strip() == s_label),
                s_roadmap.get("title", "")
            ),
            "status": s_status,
            "phase": s_phase,
            "items": s_items,
            "status_counts": {
                "open": s_statuses.count("open"), "in_progress": s_statuses.count("in_progress"),
                "fixed": s_statuses.count("fixed"), "verified": s_statuses.count("verified"),
                "blocked": s_statuses.count("blocked"), "deferred": s_statuses.count("deferred"),
            },
            "total_items": len(s_items),
            "completed_items": s_statuses.count("verified"),
            "gates": s_gates,
            "failure_analysis": fa,
            "performance": s_perf,
            "changelog_lines": s_changelog,
            "roadmap": s_roadmap,
            "predicted_failures": [p for p in tracking.get("predicted_failures", []) if p.get("item", "").strip() in s_item_ids or p.get("sprint", "").strip() == s_label] if tracking.get("predicted_failures") else s_gates.get("entry", {}).get("failure_modes", []),
            "failure_encounters": [e for e in tracking.get("failure_encounters", []) if e.get("sprint", "").strip() == s_label or e.get("item", "").strip() in s_item_ids],
        }

    current_sprint = None
    for s_label in reversed(sprint_labels):
        if sprints[s_label]["status"] in ("active", "complete"):
            current_sprint = s_label
            break
    if not current_sprint and sprint_labels:
        current_sprint = sprint_labels[-1]

    sprint_data_list = [sprints[s] for s in sprint_labels if s in sprints]
    trends = build_trends(sprint_data_list, tracking, tracking.get("failure_history", []))

    all_sprint_changelogs = set()
    for sd in sprints.values():
        all_sprint_changelogs.update(sd["changelog_lines"])
    project_changelog = tracking.get("changelog_lines", [])

    hooks_status = collect_hooks_status(root)
    workflow_config = collect_workflow_config(root)
    knowledge = collect_knowledge(root)
    validation = collect_validation(root)

    return {
        "root": str(root),
        "project": {
            "current_focus": tracking.get("current_focus", "Unknown"),
            "working_context": tracking.get("working_context", {}),
            "session_notes": tracking.get("session_notes", []),
            "total_items": tracking["total_items"],
            "completed_items": tracking["completed_items"],
            "status_counts": tracking["status_counts"],
            "sprint_labels": sprint_labels,
            "current_sprint": current_sprint,
            "risks": tracking.get("risks", []),
            "dismissed_signals": tracking.get("dismissed_signals", []),
            "changelog_lines": project_changelog,
            "workflow_config": workflow_config,
            "retroactive_audits": tracking.get("retroactive_audits", []),
        },
        "sprints": sprints,
        "roadmap": roadmap,
        "trends": trends,
        "hooks": hooks_status,
        "knowledge": knowledge,
        "validation": validation,
    }


# ─── CLI Renderer ─────────────────────────────────────────────────────────────

class C:
    R = "\033[0m"; B = "\033[1m"; D = "\033[2m"
    GR = "\033[32m"; YE = "\033[33m"; RE = "\033[31m"
    BL = "\033[34m"; CY = "\033[36m"; MA = "\033[35m"
    @classmethod
    def off(cls):
        for a in ["R","B","D","GR","YE","RE","BL","CY","MA"]:
            setattr(cls, a, "")


def render_cli(data):
    proj = data.get("project", {})
    sprints = data.get("sprints", {})
    trends = data.get("trends", {})
    if not proj.get("total_items"):
        return f"{C.RE}No TRACKING.md found or empty project.{C.R}"

    L = []
    icons = {"verified": (C.GR, "\u2713"), "fixed": (C.CY, "\u25cf"), "in_progress": (C.YE, "\u25b6"),
             "open": (C.D, "\u25cc"), "blocked": (C.RE, "\u2717"), "deferred": (C.MA, "~")}

    total, done = proj["total_items"], proj["completed_items"]
    pct = int(done / total * 100) if total else 0
    color = C.GR if pct == 100 else C.YE if pct >= 60 else C.RE
    bar_w = 20
    filled = int(pct / 100 * bar_w)
    sc = proj["status_counts"]
    status_parts = []
    for s, (c, i) in icons.items():
        if sc.get(s, 0) > 0:
            status_parts.append(f"{c}{sc[s]}{s[0].upper()}{C.R}")
    wc_cfg = proj.get("workflow_config", {})
    mode_str = wc_cfg.get("workflow_mode", "")
    ver_str = wc_cfg.get("hooks_version", "")
    badge_parts = []
    if mode_str:
        mode_c = {"strict": C.RE, "standard": C.GR, "lite": C.YE, "freestyle": C.MA}.get(mode_str, C.D)
        badge_parts.append(f"{mode_c}{mode_str}{C.R}")
    if ver_str:
        badge_parts.append(f"{C.D}v{ver_str}{C.R}")
    badge_line = f"  [{' '.join(badge_parts)}]" if badge_parts else ""

    L.append(f"{C.B}{proj.get('current_focus', '')}{C.R}{badge_line}")
    L.append(f"{color}{'\u2588' * filled}{'\u2591' * (bar_w - filled)}{C.R} {pct}%  {' '.join(status_parts)}")

    wctx = proj.get("working_context", {})
    if wctx:
        ctx_parts = []
        doing = wctx.get("doing", "")
        if doing and doing not in WC_PLACEHOLDERS:
            ctx_parts.append(f"{C.CY}doing:{C.R} {doing}")
        blockers = wctx.get("blockers", "")
        if blockers and blockers not in WC_PLACEHOLDERS:
            ctx_parts.append(f"{C.RE}blocked:{C.R} {blockers}")
        if ctx_parts:
            L.append(f"  {' | '.join(ctx_parts)}")

    L.append("")
    phase_icons = {
        "planned": f"{C.D}plan{C.R}", "entry_gate": f"{C.BL}gate{C.R}",
        "impl_loop": f"{C.YE}impl{C.R}", "impl_done": f"{C.CY}done{C.R}",
        "close_gate": f"{C.MA}cgate{C.R}", "sprint_close": f"{C.BL}close{C.R}",
        "done": f"{C.GR}done{C.R}",
    }
    for s_label, sd in sprints.items():
        si = {"complete": f"{C.GR}\u2713", "active": f"{C.YE}\u25b6", "planned": f"{C.D}\u25cc"}.get(sd["status"], f"{C.D}?")
        phase = sd.get("phase", "")
        phase_str = phase_icons.get(phase, "")
        theme = sd.get("theme", "")
        ti, di = sd["total_items"], sd["completed_items"]
        g = sd.get("gates", {})
        gate_str = ""
        for gk, gl in [("entry", "E"), ("close", "C"), ("sprint_close", "SC")]:
            gd = g.get(gk, {})
            if gd.get("exists") and gd.get("approved"):
                gate_str += f"{C.GR}{gl}{C.R} "
            elif gd.get("exists"):
                gate_str += f"{C.YE}{gl}{C.R} "
            else:
                gate_str += f"{C.D}{gl}{C.R} "
        if ti:
            sp = int(di / ti * 100)
            sp_bar = int(sp / 100 * 10)
            item_str = f"{C.GR if sp == 100 else C.YE}{'\u2588' * sp_bar}{'\u2591' * (10 - sp_bar)}{C.R} {di}/{ti}"
        else:
            item_str = f"{C.D}sketch{C.R}"
        L.append(f"  {si}{C.R} {C.B}{s_label}{C.R} {phase_str} {theme[:25]:<25} {gate_str} {item_str}")

    current = proj.get("current_sprint")
    if current and current in sprints:
        sd = sprints[current]
        items = sd.get("items", [])
        if items:
            L.append(f"\n{C.B}{current} items:{C.R}")
            for item in items:
                st = item.get("status", "open").lower()
                c, i = icons.get(st, (C.D, "?"))
                eid = item.get("id", "")
                summ = item.get("summary", "")
                if len(summ) > 45:
                    summ = summ[:42] + "..."
                ev = f" {C.D}({item['evidence']}){C.R}" if st == "verified" and item.get("evidence") else ""
                L.append(f"  {c}{i}{C.R} {eid:<10} {summ}{ev}")

        cg = sd.get("gates", {}).get("close", {})
        fa = sd.get("failure_analysis", {})
        quality_parts = []
        if cg.get("exists") and "metrics_total" in cg:
            mp, mt = cg["metrics_pass"], cg["metrics_total"]
            mc = C.GR if mp == mt else C.YE
            quality_parts.append(f"{mc}{mp}/{mt} metrics{C.R}")
            if "tests_passed" in cg:
                tp, tt = cg["tests_passed"], cg["tests_total"]
                tc = C.GR if tp == tt else C.RE
                quality_parts.append(f"{tc}{tp}/{tt} tests{C.R}")
            if cg.get("findings"):
                quality_parts.append(f"{len(cg['findings'])} findings")
        if fa.get("total_predicted", 0) > 0 or fa.get("total_occurred", 0) > 0:
            fp = fa["total_predicted"]
            fo = fa["total_occurred"]
            fc = fa["predicted_and_caught"]
            fu = fa["unpredicted"]
            f_parts = [f"{C.D}{fp}P{C.R}"]
            if fo:
                f_parts.append(f"{C.YE}{fo}O{C.R}")
            if fc:
                f_parts.append(f"{C.GR}{fc}C{C.R}")
            if fu:
                f_parts.append(f"{C.RE}{fu}U{C.R}")
            quality_parts.append(f"failures:{'/'.join(f_parts)}")
            if fa.get("new_guardrails"):
                quality_parts.append(f"{C.CY}+{fa['new_guardrails']}G{C.R}")
        if quality_parts:
            L.append(f"\n{C.B}{current} quality:{C.R} {'  '.join(quality_parts)}")

    risks = proj.get("risks", [])
    if risks:
        L.append(f"\n{C.RE}risks:{C.R}")
        for r in risks[:3]:
            L.append(f"  {C.RE}!{C.R} {r.get('id', '')}: {r.get('risk', '')}")
        if len(risks) > 3:
            L.append(f"  {C.D}... +{len(risks) - 3} more{C.R}")

    trend_sprints = trends.get("sprints", [])
    if len(trend_sprints) > 1:
        pa = trends.get("prediction_accuracy", {})
        latest = trend_sprints[-1]
        t_parts = []
        if latest.get("first_pass_rate") is not None:
            t_parts.append(f"first-pass:{int(latest['first_pass_rate'] * 100)}%")
        if latest.get("finding_density") is not None:
            t_parts.append(f"density:{latest['finding_density']}")
        if pa.get("accuracy") is not None:
            t_parts.append(f"predict:{int(pa['accuracy'] * 100)}%")
        gv = trends.get("guardrail_velocity", 0)
        if gv:
            t_parts.append(f"{C.CY}{gv} guardrails{C.R}")
        if t_parts:
            L.append(f"\n{C.B}trends:{C.R} {'  '.join(t_parts)}")

    notes = proj.get("session_notes", [])
    if notes:
        note_icons = {"decision": f"{C.BL}D{C.R}", "attempt": f"{C.YE}A{C.R}",
                       "observation": f"{C.CY}O{C.R}", "side-effect": f"{C.RE}S{C.R}",
                       "artifact": f"{C.MA}F{C.R}"}
        L.append(f"\n{C.B}notes:{C.R} {C.D}({len(notes)} total){C.R}")
        for n in notes[-3:]:
            ni = note_icons.get(n.get("type", ""), f"{C.D}?{C.R}")
            txt = n.get("text", "")
            if len(txt) > 60:
                txt = txt[:57] + "..."
            L.append(f"  {ni} {txt}")

    infra_parts = []
    hooks_data = data.get("hooks", {})
    if hooks_data.get("total"):
        hc = C.GR if hooks_data["enabled"] == hooks_data["total"] else C.YE
        infra_parts.append(f"{hc}{hooks_data['enabled']}/{hooks_data['total']} hooks{C.R}")
    know = data.get("knowledge", {})
    if know.get("guardrails"):
        infra_parts.append(f"{C.CY}{know['guardrails']} guardrails{C.R}")
    if know.get("index_entries"):
        infra_parts.append(f"{C.BL}{know['index_entries']} index{C.R}")
    val = data.get("validation", {})
    if val.get("available") and val.get("total"):
        vc = C.GR if val["failed"] == 0 else C.RE
        infra_parts.append(f"{vc}{val['passed']}/{val['total']} validation{C.R}")
    if infra_parts:
        L.append(f"\n{C.B}infra:{C.R} {'  '.join(infra_parts)}")

    cl = proj.get("changelog_lines", [])
    if cl:
        L.append(f"\n{C.D}recent:{C.R}")
        for e in cl[-3:]:
            L.append(f"  {C.D}\u2022{C.R} {e}")

    L.append(f"\n{C.D}Run with --serve for full interactive dashboard{C.R}")

    return "\n".join(L)
