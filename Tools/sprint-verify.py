#!/usr/bin/env python3
"""Sprint item verification — generates verification checklist from Entry Gate data.

Prepares a structured verification packet for an item marked 'fixed'.
The agent (or a sub-agent) uses this checklist to verify the item before
transitioning to 'verified'.

Usage:
  sprint-verify.py CORE-NNN [--auto-apply] [--json]

Output:
  Verification checklist with:
  - Item summary and current status
  - Failure modes from Entry Gate (if available)
  - Verification plan from Entry Gate (if available)
  - Files changed (git diff)
  - Test commands to run
  - Evidence template

The agent reviews the checklist, runs the tests, and marks verified:
  sprint-tools item CORE-NNN verified "VERIFIED: <evidence>"
"""

import re
import sys
import json
import subprocess
from pathlib import Path

from sprint_lib.utils import find_project_root, find_tracking_file
from sprint_lib import tracking_parser
from sprint_lib.errors import ItemNotFoundError, SetupError

def _find_default_branch(root: Path) -> str | None:
    """Discover the default branch name (main or master)."""
    # Try remote HEAD first (most reliable)
    try:
        result = subprocess.run(
            ["git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD"],
            capture_output=True, text=True, cwd=root, timeout=5,
        )
        if result.returncode == 0:
            # Returns e.g. "origin/main" — strip the remote prefix
            ref = result.stdout.strip()
            return ref.split("/", 1)[-1] if "/" in ref else ref
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    # Fall back to checking local branches
    for branch in ("main", "master"):
        result = subprocess.run(
            ["git", "rev-parse", "--verify", branch],
            capture_output=True, text=True, cwd=root, timeout=5,
        )
        if result.returncode == 0:
            return branch
    return None


def _git_diff_files(root: Path, item_id: str) -> list[str]:
    """Find files changed in commits mentioning this item ID."""
    try:
        # Find commits mentioning this item (--fixed-strings to avoid regex interpretation)
        result = subprocess.run(
            ["git", "log", "--all", "--oneline", "--fixed-strings",
             "--grep", item_id, "--format=%H"],
            capture_output=True, text=True, cwd=root, timeout=10,
        )
        commits = result.stdout.strip().splitlines() if result.returncode == 0 else []
        if not commits:
            # Fallback: diff against default branch
            default_branch = _find_default_branch(root)
            if not default_branch:
                return []
            result = subprocess.run(
                ["git", "diff", "--name-only", f"{default_branch}...HEAD"],
                capture_output=True, text=True, cwd=root, timeout=10,
            )
            if result.returncode != 0:
                return []
            return result.stdout.strip().splitlines()[:20]

        # Get files from those commits
        all_files = set()
        for commit in commits[:5]:
            result = subprocess.run(
                ["git", "diff-tree", "--no-commit-id", "-r", "--name-only", commit],
                capture_output=True, text=True, cwd=root, timeout=10,
            )
            all_files.update(result.stdout.strip().splitlines())
        return sorted(all_files)[:20]
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []


def _find_gate_report(root: Path) -> Path | None:
    """Find the most recent Entry Gate report."""
    planning_dir = root / "Docs" / "Planning"
    if not planning_dir.exists():
        return None
    candidates = sorted(planning_dir.glob("S*_ENTRY_GATE.md"), reverse=True)
    return candidates[0] if candidates else None


def _extract_item_gate_data(gate_path: Path | None, item_id: str) -> dict:
    """Extract failure modes and verification plan for an item from gate report."""
    data = {"failure_modes": [], "verification_plan": [], "metrics": []}
    if not gate_path or not gate_path.exists():
        return data

    text = gate_path.read_text(encoding="utf-8", errors="replace")

    # Simple extraction: find sections mentioning the item ID
    lines = text.splitlines()
    in_item_section = False
    section_type = None

    for line in lines:
        line_upper = line.upper()

        # Detect item-relevant sections (word-boundary match to avoid CORE-1 matching CORE-10)
        if re.search(rf'\b{re.escape(item_id.upper())}\b', line_upper):
            in_item_section = True
            if "FAILURE" in line_upper or "FAIL" in line_upper:
                section_type = "failure_modes"
            elif "VERIF" in line_upper:
                section_type = "verification_plan"
            elif "METRIC" in line_upper:
                section_type = "metrics"
            # Don't continue — the line may contain content to collect

        # End of item section
        if in_item_section and line.startswith("#"):
            if not re.search(rf'\b{re.escape(item_id.upper())}\b', line_upper):
                in_item_section = False
                section_type = None
                continue

        # Collect lines
        if in_item_section and section_type and line.strip():
            stripped = line.strip().lstrip("- ").lstrip("* ")
            if stripped and not stripped.startswith("|--"):
                data[section_type].append(stripped)

    # Limit output
    for key in data:
        data[key] = data[key][:10]

    return data


def _detect_test_commands(root: Path) -> list[str]:
    """Detect available test commands from project files."""
    commands = []
    indicators = {
        "pytest.ini": "pytest",
        "pyproject.toml": "pytest",
        "setup.cfg": "pytest",
        "package.json": "npm test",
        "Cargo.toml": "cargo test",
        "go.mod": "go test ./...",
        "Makefile": "make test",
        "build.gradle": "gradle test",
        "pom.xml": "mvn test",
    }
    for filename, cmd in indicators.items():
        if (root / filename).exists() and cmd not in commands:
            commands.append(cmd)
    return commands or ["(no test runner detected — run tests manually)"]


BOOTSTRAP_CHECKS = 13


def _verify_bootstrap(root: Path) -> list[dict]:
    """Run 13-point bootstrap self-check. Returns list of findings."""
    findings = []

    def _check(condition: bool, message: str, severity: str = "warn"):
        if not condition:
            findings.append({"severity": severity, "message": message})

    # 1. CLAUDE.md exists and no [REQUIRED] placeholders
    claude_md = root / "CLAUDE.md"
    if claude_md.exists():
        content = claude_md.read_text(encoding="utf-8", errors="replace")
        if "[REQUIRED" in content:
            placeholders = [l.strip() for l in content.splitlines() if "[REQUIRED" in l]
            _check(False, f"CLAUDE.md has {len(placeholders)} unfilled [REQUIRED] placeholder(s)")
    else:
        _check(False, "CLAUDE.md not found", "error")

    # 2. CLAUDE.md §Available Tools intact
    if claude_md.exists():
        _check("sprint-tools state" in content and "sprint-tools item" in content,
               "CLAUDE.md §Available Tools may be missing or truncated")

    # 3. TRACKING.md exists with Sprint Board
    tracking = root / "TRACKING.md"
    if tracking.exists():
        t_content = tracking.read_text(encoding="utf-8", errors="replace")
        _check("## Sprint Board" in t_content, "TRACKING.md missing §Sprint Board section")
        _check("## Current Focus" in t_content, "TRACKING.md missing §Current Focus section")
    else:
        _check(False, "TRACKING.md not found", "error")

    # 4. SPRINT-INDEX.md exists
    sprint_index = root / "Docs" / "SPRINT-INDEX.md"
    _check(sprint_index.exists(), "Docs/SPRINT-INDEX.md not found")

    # 5. .gitignore with secret patterns
    gitignore = root / ".gitignore"
    if gitignore.exists():
        gi_content = gitignore.read_text(encoding="utf-8", errors="replace")
        _check(".env" in gi_content, ".gitignore missing .env pattern (secrets risk)")
    else:
        _check(False, ".gitignore not found")

    # 6. CODING_GUARDRAILS.md exists
    guardrails = root / "Docs" / "CODING_GUARDRAILS.md"
    _check(guardrails.exists(), "Docs/CODING_GUARDRAILS.md not found")

    # 7. Roadmap.md with Sprint 1
    roadmap_candidates = [
        root / "Docs" / "Planning" / "Roadmap.md",
        root / "Docs" / "Roadmap.md",
        root / "Roadmap.md",
    ]
    roadmap = next((r for r in roadmap_candidates if r.exists()), None)
    if roadmap:
        r_content = roadmap.read_text(encoding="utf-8", errors="replace")
        _check("Sprint 1" in r_content or "sprint 1" in r_content.lower(),
               "Roadmap.md exists but no Sprint 1 section found")
    else:
        _check(False, "Roadmap.md not found")

    # 8. sprint-tools dispatcher + subcommands
    tools_dir = root / "Tools"
    dispatcher = tools_dir / "sprint-tools"
    _check(dispatcher.exists(), "Tools/sprint-tools dispatcher not found", "error")

    expected_tools = [
        "sprint-state.py", "sprint-item.py", "sprint-git.py",
        "sprint-checkpoint.py", "sprint-baseline.py", "sprint-metrics.py",
        "sprint-close.py", "sprint-index.py", "sprint-review.py",
        "sprint-verify.py", "sprint-learn.py", "sprint-note.py",
        "sprint-migrate.py",
    ]
    missing_tools = [t for t in expected_tools if not (tools_dir / t).exists()]
    _check(not missing_tools,
           f"Missing tool(s): {', '.join(missing_tools)}" if missing_tools else "")

    # 9. sprint_lib/ complete
    lib_dir = tools_dir / "sprint_lib"
    expected_modules = [
        "__init__.py", "models.py", "tracking_parser.py",
        "writers.py", "gate_parser.py", "roadmap_parser.py",
        "utils.py", "errors.py",
    ]
    missing_modules = [m for m in expected_modules if not (lib_dir / m).exists()]
    _check(not missing_modules,
           f"sprint_lib/ missing: {', '.join(missing_modules)}" if missing_modules else "")

    # 10. sprint-audit.sh exists
    audit_script = tools_dir / "sprint-audit.sh"
    if not audit_script.exists():
        audit_script = root / "sprint-audit-template.sh"
    _check(audit_script.exists(), "sprint-audit.sh not found (Tools/ or root)")

    # 11. checks/ directory
    checks_dir = tools_dir / "checks"
    if not checks_dir.exists():
        checks_dir = root / "checks"
    _check(checks_dir.exists(), "checks/ directory not found")

    # 12. dashboard/ present
    _check((root / "dashboard").exists(), "dashboard/ directory not found")

    # 13. No template-repo leaks
    leaks = []
    for suspect in ["validation/"]:
        suspect_path = root / suspect
        if suspect_path.exists():
            leaks.append(suspect)
    _check(not leaks,
           f"Template-repo files leaked: {', '.join(leaks)}" if leaks else "")
    # Informational: files that may be legitimate user files or template leaks
    for maybe in ["DESIGN.md", "CONTRIBUTING.md", "examples/"]:
        if (root / maybe).exists():
            findings.append({
                "severity": "info",
                "message": f"{maybe} exists — if this is your own file, ignore; if leaked from template, remove."
            })

    return findings


EVIDENCE_PREFIXES = ("VERIFIED:", "INFERRED:", "UNCERTAIN:")
PRIORITY_REQUIRED = {
    "must": ("VERIFIED:",),
    "should": ("VERIFIED:", "INFERRED:"),
}


def _audit_all_evidence(data) -> list[dict]:
    """Audit evidence confidence levels on all verified items. Returns findings."""
    findings = []
    for item in data.items:
        if item.status != "verified":
            continue
        evidence = item.evidence.strip()
        evidence_upper = evidence.upper()
        priority = (item.priority or "").lower().strip()

        # Fail-closed: unknown/empty priority treated as "must"
        if not priority or priority not in ("must", "should", "could"):
            priority = "must"

        has_prefix = any(evidence_upper.startswith(p) for p in EVIDENCE_PREFIXES)
        if not has_prefix:
            findings.append({
                "item_id": item.id, "priority": priority,
                "issue": "missing_prefix",
                "message": f"{item.id}: evidence missing confidence prefix (VERIFIED:/INFERRED:/UNCERTAIN:)",
            })
            continue

        required = PRIORITY_REQUIRED.get(priority)
        if required:
            prefix_used = next(p for p in EVIDENCE_PREFIXES if evidence_upper.startswith(p))
            if prefix_used not in required:
                findings.append({
                    "item_id": item.id, "priority": priority,
                    "issue": "wrong_level",
                    "message": f"{item.id}: {priority}-priority requires {' or '.join(required)}, got {prefix_used}",
                })
    return findings


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate verification checklist for a fixed item")
    parser.add_argument("item_id", nargs="?", help="Item ID (e.g., CORE-001)")
    parser.add_argument("--auto-apply", action="store_true",
                        help="If all checks pass, auto-mark as verified")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--audit-all", action="store_true",
                        help="Audit evidence confidence levels on all verified items")
    parser.add_argument("--bootstrap", action="store_true",
                        help="Verify bootstrap completion (13-point self-check)")
    args = parser.parse_args()

    if args.auto_apply:
        print("Note: --auto-apply is advisory only — agent must verify and apply manually.", file=sys.stderr)

    # --- Bootstrap verification mode ---
    if args.bootstrap:
        try:
            root = find_project_root()
        except FileNotFoundError:
            root = Path.cwd()
        findings = _verify_bootstrap(root)
        if args.json:
            print(json.dumps({"findings": findings, "count": len(findings)}, indent=2))
        elif not findings:
            print("Bootstrap verification: ALL CHECKS PASSED")
        else:
            passed = BOOTSTRAP_CHECKS - len(findings)
            print(f"Bootstrap verification: {passed}/{BOOTSTRAP_CHECKS} passed, {len(findings)} finding(s)\n")
            for f in findings:
                print(f"  {f['severity'].upper():5s}  {f['message']}")
        sys.exit(1 if findings else 0)

    # --- Audit-all mode ---
    if args.audit_all:
        try:
            root = find_project_root()
        except FileNotFoundError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
        tracking_path = find_tracking_file(root)
        if not tracking_path.exists():
            raise SetupError(f"Tracking file not found: {tracking_path}")
        data = tracking_parser.parse(tracking_path)
        findings = _audit_all_evidence(data)

        if args.json:
            print(json.dumps({"findings": findings, "count": len(findings)}, indent=2))
        elif not findings:
            print("All verified items have correct evidence confidence levels.")
        else:
            print(f"Evidence audit: {len(findings)} finding(s)\n")
            for f in findings:
                print(f"  WARN  {f['message']}")
        sys.exit(1 if findings else 0)

    # --- Single item mode ---
    if not args.item_id:
        parser.error("item_id is required (or use --audit-all)")

    item_id = args.item_id.upper()

    # Find project
    try:
        root = find_project_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    tracking_path = find_tracking_file(root)
    if not tracking_path.exists():
        raise SetupError(f"Tracking file not found: {tracking_path}")

    data = tracking_parser.parse(tracking_path)
    item = tracking_parser.get_item(data, item_id)
    if item is None:
        raise ItemNotFoundError(f"Item '{item_id}' not found in {tracking_path.name}")

    if item.status != "fixed":
        print(f"Error: {item_id} status is '{item.status}', expected 'fixed'.", file=sys.stderr)
        print(f"Only fixed items can be verified. Current flow: in_progress → fixed → verified.", file=sys.stderr)
        sys.exit(2)

    # Gather data
    changed_files = _git_diff_files(root, item_id)
    gate_path = _find_gate_report(root)
    gate_data = _extract_item_gate_data(gate_path, item_id)
    test_commands = _detect_test_commands(root)

    # Build checklist
    checklist = {
        "item_id": item_id,
        "summary": item.summary,
        "priority": item.priority,
        "status": item.status,
        "evidence_required": "VERIFIED" if (item.priority or "").lower() == "must" else "VERIFIED or INFERRED",
        "changed_files": changed_files,
        "failure_modes": gate_data["failure_modes"],
        "verification_plan": gate_data["verification_plan"],
        "metrics": gate_data["metrics"],
        "test_commands": test_commands,
        "gate_report": str(gate_path) if gate_path else None,
    }

    if args.json:
        print(json.dumps(checklist, indent=2))
        return

    # Human-readable output
    print(f"═══ Verification Checklist: {item_id} ═══")
    print(f"Summary:  {item.summary}")
    print(f"Priority: {item.priority}")
    print(f"Evidence: {checklist['evidence_required']} required")
    print()

    if changed_files:
        print("── Changed Files ──")
        for f in changed_files:
            print(f"  {f}")
        print()

    if gate_data["failure_modes"]:
        print("── Failure Modes (from Entry Gate) ──")
        for i, fm in enumerate(gate_data["failure_modes"], 1):
            print(f"  [ ] {i}. {fm}")
        print("  → Verify each failure mode is handled in the implementation.")
        print()

    if gate_data["verification_plan"]:
        print("── Verification Plan (from Entry Gate) ──")
        for i, vp in enumerate(gate_data["verification_plan"], 1):
            print(f"  [ ] {i}. {vp}")
        print()

    if gate_data["metrics"]:
        print("── Metrics ──")
        for m in gate_data["metrics"]:
            print(f"  [ ] {m}")
        print()

    print("── Test Commands ──")
    for cmd in test_commands:
        print(f"  $ {cmd}")
    print()

    print("── Verification Steps ──")
    print(f"  1. Run test commands above")
    print(f"  2. Check each failure mode is handled")
    print(f"  3. Follow verification plan steps")
    print(f"  4. Mark verified:")
    print(f"     sprint-tools item {item_id} verified \"VERIFIED: <test results + evidence>\"")
    print()

    if gate_path:
        print(f"── Gate Report: {gate_path.relative_to(root)} ──")
    print()

    # Sub-agent packet hint
    print("── Sub-Agent Packet (optional) ──")
    print(f"  To delegate verification to a sub-agent, pass this checklist + changed files.")
    print(f"  Task: run tests, verify failure modes, return verdict + evidence.")
    if args.auto_apply:
        print(f"  --auto-apply: agent will auto-run 'sprint-tools item {item_id} verified' on PASS.")


if __name__ == "__main__":
    try:
        main()
    except (ItemNotFoundError, SetupError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(getattr(e, "exit_code", 1))
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)
