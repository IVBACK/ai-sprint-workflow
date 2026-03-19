#!/usr/bin/env python3
"""Knowledge classification + routing — deterministic keyword-based finding router.

Usage:
    sprint-learn.py <text> [--type guardrail|index|risk] [--item CORE-NNN] [--dry-run]
    sprint-learn.py --classify <text>

Examples:
    sprint-learn.py "Never parse JSON with regex — use json.loads" --item CORE-012
    sprint-learn.py --classify "Connection pooling prevents timeout under load"
    sprint-learn.py "Nullable FK causes cascade delete" --type guardrail --dry-run
"""

import argparse
import re
import sys
from pathlib import Path

from sprint_lib.utils import find_project_root, find_tracking_file
from sprint_lib import tracking_parser, writers
from sprint_lib.errors import SetupError


# ---------------------------------------------------------------------------
# Keyword-based classifier (deterministic, no LLM)
# ---------------------------------------------------------------------------

GUARDRAIL_KEYWORDS = {
    "never", "always", "must not", "do not", "wrong", "correct",
    "anti-pattern", "bug", "regression", "crash", "leak", "vulnerability",
    "xss", "injection", "race condition", "deadlock", "null", "undefined",
    "error handling", "validation", "sanitize", "escape",
}

INDEX_KEYWORDS = {
    "decision", "chose", "strategy", "architecture", "design",
    "baseline", "benchmark", "performance", "migration", "api",
    "integration", "protocol", "format", "schema", "convention",
}

RISK_KEYWORDS = {
    "risk", "blocker", "dependency", "external", "breaking change",
    "deprecation", "security", "compliance", "deadline", "bottleneck",
}


def classify_finding(text: str) -> str:
    """Classify a finding into guardrail, index, or risk based on keywords.

    Returns the most likely category. Ties broken by priority: guardrail > risk > index.
    """
    text_lower = text.lower()
    scores = {
        "guardrail": sum(1 for kw in GUARDRAIL_KEYWORDS if kw in text_lower),
        "risk": sum(1 for kw in RISK_KEYWORDS if kw in text_lower),
        "index": sum(1 for kw in INDEX_KEYWORDS if kw in text_lower),
    }

    # Priority order for ties
    for category in ("guardrail", "risk", "index"):
        if scores[category] > 0 and scores[category] >= max(scores.values()):
            return category

    # Default to index if no keywords match
    return "index"


def _extract_sprint_info(data):
    """Extract sprint number and label from tracking data."""
    sprint_n = 0
    if data.current_focus:
        m = re.search(r"Sprint\s+(\d+)", data.current_focus)
        if m:
            sprint_n = int(m.group(1))
    return sprint_n, f"S{sprint_n}" if sprint_n > 0 else "S0"


def _check_duplicate(text: str, tracking_path: Path) -> bool:
    """Simple duplicate check — does the text already appear in TRACKING notes or changelog?"""
    content = tracking_path.read_text(encoding="utf-8")
    # Normalize for comparison
    text_normalized = " ".join(text.lower().split())
    # Check if a substantial substring already exists
    words = text_normalized.split()
    if len(words) >= 4:
        # Check for 4-word subsequences
        for i in range(len(words) - 3):
            chunk = " ".join(words[i:i+4])
            if chunk in content.lower():
                return True
    return False


# ---------------------------------------------------------------------------
# Route actions
# ---------------------------------------------------------------------------

GUARDRAILS_CANDIDATES = [
    Path("Docs") / "CODING_GUARDRAILS.md",
    Path("CODING_GUARDRAILS.md"),
]

INDEX_PATH = Path("Docs") / "SPRINT-INDEX.md"


def route_guardrail(root: Path, text: str, item: str, sprint_key: str, dry_run: bool) -> str:
    """Route finding to CODING_GUARDRAILS.md as a new quick-reference entry."""
    guardrails_path = None
    for candidate in GUARDRAILS_CANDIDATES:
        full = root / candidate
        if full.exists():
            guardrails_path = full
            break

    if guardrails_path is None:
        return "SKIP: No CODING_GUARDRAILS.md found"

    if dry_run:
        return f"DRY RUN: Would append to {guardrails_path.name}: {text}"

    # Append as quick-reference entry at end of file
    lines = guardrails_path.read_text(encoding="utf-8").splitlines(keepends=True)
    item_ref = f" ({item})" if item else ""
    entry = f"- **{sprint_key}{item_ref}:** {text}\n"

    # Find or create §Quick Reference section
    qr_idx = None
    for idx, line in enumerate(lines):
        if "Anti-Pattern Quick Reference" in line or "Quick Reference" in line:
            qr_idx = idx
            break

    if qr_idx is not None:
        # Append after last entry in section
        insert_at = qr_idx + 1
        for idx in range(qr_idx + 1, len(lines)):
            stripped = lines[idx].strip()
            if stripped.startswith("- "):
                insert_at = idx + 1
            elif stripped.startswith("#"):
                break
        lines.insert(insert_at, entry)
    else:
        # Append at end
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        lines.append(entry)

    guardrails_path.write_text("".join(lines), encoding="utf-8")
    return f"Added to {guardrails_path.name}"


def route_index(root: Path, text: str, item: str, sprint_key: str, dry_run: bool) -> str:
    """Route finding to SPRINT-INDEX.md as a tagged entry."""
    index_path = root / INDEX_PATH
    if not index_path.exists():
        return "SKIP: No SPRINT-INDEX.md found"

    if dry_run:
        return f"DRY RUN: Would append to SPRINT-INDEX.md: {text}"

    # Determine topic from text (first significant word)
    lines = index_path.read_text(encoding="utf-8").splitlines(keepends=True)
    item_ref = f" {item}" if item else ""
    entry = f"- {sprint_key}:{item_ref} {text}\n"

    # Append at end of file
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    lines.append(entry)
    index_path.write_text("".join(lines), encoding="utf-8")
    return "Added to SPRINT-INDEX.md"


def route_risk(root: Path, text: str, item: str, sprint_key: str, dry_run: bool, tracking_path: Path) -> str:
    """Route finding to TRACKING.md §Open Risks."""
    if dry_run:
        return f"DRY RUN: Would add risk to TRACKING.md: {text}"

    # Generate risk ID
    data = tracking_parser.parse(tracking_path)
    max_id = 0
    for r in data.risks:
        m = re.search(r"R-(\d+)", r.id)
        if m:
            max_id = max(max_id, int(m.group(1)))
    new_id = f"R-{max_id + 1:03d}"

    writers.add_risk(tracking_path, new_id, text, "TBD", sprint_key)
    return f"Added risk {new_id} to TRACKING.md"


def main():
    parser = argparse.ArgumentParser(
        description="Knowledge classification + routing.",
    )
    parser.add_argument(
        "text", nargs="?", default="",
        help="Finding text to classify and route",
    )
    parser.add_argument(
        "--classify", metavar="TEXT",
        help="Classify only (no routing) — print category",
    )
    parser.add_argument(
        "--type", choices=["guardrail", "index", "risk"],
        help="Override automatic classification",
    )
    parser.add_argument(
        "--item", default="",
        help="Link to CORE-NNN item",
    )
    parser.add_argument(
        "--dry-run", action="store_true", default=True,
        help="Show what would happen without writing (default: true)",
    )
    parser.add_argument(
        "--apply", action="store_true",
        help="Actually write changes (overrides --dry-run)",
    )

    args = parser.parse_args()

    # Classify-only mode
    if args.classify:
        category = classify_finding(args.classify)
        print(f"Classification: {category}")
        print(f"  Text: {args.classify}")
        return

    if not args.text:
        parser.print_help()
        sys.exit(1)

    # Find project root
    try:
        root = find_project_root()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    tracking_path = find_tracking_file(root)
    if not tracking_path.exists():
        raise SetupError(f"Tracking file not found: {tracking_path}")

    data = tracking_parser.parse(tracking_path)
    _, sprint_key = _extract_sprint_info(data)

    # Classify
    category = args.type or classify_finding(args.text)
    dry_run = not args.apply

    # Duplicate check
    if _check_duplicate(args.text, tracking_path):
        print(f"SKIP: Possible duplicate — similar text already exists in tracking")
        return

    # Route
    print(f"Classification: {category}")
    if category == "guardrail":
        result = route_guardrail(root, args.text, args.item, sprint_key, dry_run)
    elif category == "risk":
        result = route_risk(root, args.text, args.item, sprint_key, dry_run, tracking_path)
    else:
        result = route_index(root, args.text, args.item, sprint_key, dry_run)

    print(f"  {result}")

    # Also log as session note
    if not dry_run:
        writers.append_session_note(
            tracking_path,
            note_type="observation",
            text=f"[learn→{category}] {args.text}",
            item=args.item,
        )


if __name__ == "__main__":
    try:
        main()
    except (SetupError,) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(getattr(e, "exit_code", 1))
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)
