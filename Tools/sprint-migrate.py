#!/usr/bin/env python3
"""Migrate sprint workflow from v2.1 to v3.1.

Usage:
    python3 sprint-migrate.py                    # interactive migration
    python3 sprint-migrate.py --dry-run          # preview only
    python3 sprint-migrate.py --rollback <dir>   # restore from backup
"""

import json
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

TARGET_VERSION = "3.1"
SUPPORTED_SOURCES = {"2.0", "2.1", "3.0"}


# ── Section templates (v3.1) ───────────────────────────────────────────

NEW_DOCUMENT_CONTRACT = """\
- `TRACKING.md` (or `TRACKING-[name].md` if team — see [TEAM-GUIDE.md](Docs/Workflow/TEAM-GUIDE.md)): single source of truth for item status (ID-###, open/in_progress/fixed/verified; special: deferred, blocked).
- `Docs/Planning/Roadmap.md`: sprint plan (Must/Should/Could per sprint).
- `Docs/CODING_GUARDRAILS.md`: engineering rules (check before writing code).
- `Docs/Workflow/ENTRY-GATE.md`: Entry Gate — read at sprint start.
- `Docs/Workflow/IMPL-LOOP.md`: Implementation Loop — read when writing code.
- `Docs/Workflow/CLOSE-GATE.md`: Close Gate — read at sprint end.
- `Docs/Workflow/SPRINT-CLOSE.md`: Sprint Close — read after close gate verdict.
- `Docs/Workflow/PROCEDURES.md`: scope change, abort, audit — read when needed.
- `Docs/Workflow/AGENT-RULES.md`: agent operational rules — read every session.
- `Docs/SPRINT-INDEX.md`: cross-sprint topic-first lookup (read at Entry Gate step 9a, updated at Sprint Close step 7b).
- `Docs/Workflow/PARALLEL-EXECUTION.md`: parallel wave execution patterns (optional — loaded when user triggers parallel mode at Entry Gate step 11).
- `Docs/Workflow/TEAM-GUIDE.md`: team topologies, cross-sprint dependencies, PR integration, CI/CD (team only — skip if solo).
- `Docs/Workflow/UNITY-GUIDE.md`: Unity-specific git, LFS, scene ownership rules (Unity projects only — skip otherwise).
- `CLAUDE.md` (this file): operational rules + checkpoint summary.

Rule: Bug and sprint status is NOT duplicated here; only short references."""

SPRINT_TOOLS_RULE = "- Use `sprint-tools item` for status transitions (NOT manual TRACKING edit). See §Available Tools."

AVAILABLE_TOOLS_SECTION = """\
## Available Tools

```
Anytime:
  sprint-tools state          — sprint digest (items, risks, phase, Working Context)
  sprint-tools note <type> "text" — session journal (decision/attempt/observation/side-effect/artifact)
  sprint-tools learn "text"       — classify + route finding (guardrail/index/risk, --dry-run default)
  sprint-tools review <file>  — blind review via external LLM

Workflow steps:
  sprint-tools item ID status — status transition + changelog
  sprint-tools checkpoint     — update Last Checkpoint
  sprint-tools baseline       — record performance metric
  sprint-tools metrics S<N>   — extract Entry Gate metrics
  sprint-tools close <N>      — sprint close archive + cleanup
  sprint-tools index          — rebuild SPRINT-INDEX.md
  sprint-tools git            — git ceremony (init/commit/push/merge/abort)
  sprint-tools migrate        — upgrade from older workflow version (v2.x → v3.x)
```"""

NEW_QUICK_START = """\
New session sequence:
1. Read `Docs/Workflow/AGENT-RULES.md` — your operational rules (tool usage, context loading, Working Context)
2. If `Team:` lists multiple names → ask: "Which team member are you?" to determine which
   `TRACKING-[name].md` to read. Solo → read `TRACKING.md` directly.
3. Read your TRACKING file → Current Focus + Sprint Board + Working Context + Blockers
4. `Docs/Planning/Roadmap.md` → active sprint section
→ Then tell the AI: **"Continue sprint N"** or **"Resume"** — AI runs Session Start Protocol automatically.

Sprint start (new sprint transition):
- `Docs/Workflow/ENTRY-GATE.md` (phases 0-3, 12 steps) — read and execute. No code before plan is confirmed.

Implementation:
- `Docs/Workflow/IMPL-LOOP.md` — read and execute. Use sprint-tools for status transitions (see §Available Tools).

Sprint close:
- `Docs/Workflow/CLOSE-GATE.md` (phases 0-4) — read and execute.
- `Docs/Workflow/SPRINT-CLOSE.md` — finalize after close gate verdict.

Before writing code:
- `Docs/CODING_GUARDRAILS.md` → Section Index → relevant sections only"""

WORKING_CONTEXT_TEMPLATE = """\
## Working Context

Task: —
Doing: —
Decisions: —
Blockers: —
"""

# Files that moved or were deleted in v3.1
OLD_FILES_TO_DELETE = [
    "Docs/CROSS-LLM-AUDIT.md",
    "Docs/PARALLEL-EXECUTION.md",
    "Docs/TEAM-GUIDE.md",
    "Docs/UNITY-GUIDE.md",
    "Docs/WORKFLOW-MODES.md",
    "Docs/SPRINT_WORKFLOW.md",
    "Docs/LESSONS_INDEX.md",
]


# ── Helpers ─────────────────────────────────────────────────────────────

def detect_version(root: Path) -> str | None:
    """Detect installed workflow version."""
    # Try hooks-config.sh
    hc = root / ".claude" / "hooks-config.sh"
    if hc.exists():
        for line in hc.read_text().splitlines():
            m = re.match(r'^HOOKS_VERSION="([^"]+)"', line)
            if m:
                return m.group(1)
    # Try WORKFLOW.md
    wf = root / "WORKFLOW.md"
    if wf.exists():
        for line in wf.read_text().splitlines()[:5]:
            m = re.search(r"workflow-version:\s*([0-9.]+)", line)
            if m:
                return m.group(1)
    return None


def split_sections(text: str) -> list[tuple[str, str]]:
    """Split markdown into (heading, body) tuples. First entry may have empty heading (preamble)."""
    parts: list[tuple[str, str]] = []
    lines = text.splitlines(keepends=True)
    current_heading = ""
    current_body: list[str] = []

    for line in lines:
        if re.match(r"^##\s+", line):
            parts.append((current_heading, "".join(current_body)))
            current_heading = line.strip()
            current_body = []
        else:
            current_body.append(line)

    parts.append((current_heading, "".join(current_body)))
    return parts


def reassemble(sections: list[tuple[str, str]]) -> str:
    """Reassemble sections into markdown text."""
    result = []
    for heading, body in sections:
        if heading:
            result.append(heading + "\n")
        result.append(body)
    return "".join(result)


def find_section_index(sections: list[tuple[str, str]], name: str) -> int:
    """Find index of section by partial heading match."""
    for i, (heading, _) in enumerate(sections):
        if name.lower() in heading.lower():
            return i
    return -1


# ── CLAUDE.md Migration ────────────────────────────────────────────────

def migrate_claude_md(path: Path, dry_run: bool) -> list[str]:
    """Migrate CLAUDE.md from v2.1 to v3.1. Returns list of changes."""
    text = path.read_text(encoding="utf-8")
    sections = split_sections(text)
    changes: list[str] = []

    # 1. Update Document Contract
    idx = find_section_index(sections, "Document Contract")
    if idx >= 0:
        old_body = sections[idx][1]
        if "Docs/SPRINT_WORKFLOW.md" in old_body or "Docs/Workflow/ENTRY-GATE.md" not in old_body:
            sections[idx] = (sections[idx][0], "\n" + NEW_DOCUMENT_CONTRACT + "\n\n")
            changes.append("Updated §Document Contract (old refs → 12 new workflow file refs)")

    # 2. Patch Operational Rules — add sprint-tools line
    idx = find_section_index(sections, "Operational Rules")
    if idx >= 0:
        body = sections[idx][1]
        if "sprint-tools item" not in body:
            # Insert sprint-tools rule as first bullet
            body = "\n" + SPRINT_TOOLS_RULE + "\n" + body.lstrip("\n")
            sections[idx] = (sections[idx][0], body)
            changes.append("Added sprint-tools item rule to §Operational Rules")

    # 3. Insert Available Tools section (before Quick Start)
    if find_section_index(sections, "Available Tools") < 0:
        qs_idx = find_section_index(sections, "Quick Start")
        insert_idx = qs_idx if qs_idx >= 0 else len(sections)
        sections.insert(insert_idx, ("## Available Tools", "\n" + AVAILABLE_TOOLS_SECTION.split("\n", 1)[1] + "\n\n"))
        changes.append("Added §Available Tools section (sprint-tools commands)")

    # 4. Update Quick Start
    idx = find_section_index(sections, "Quick Start")
    if idx >= 0:
        old_body = sections[idx][1]
        if "SPRINT_WORKFLOW.md" in old_body or "AGENT-RULES.md" not in old_body:
            sections[idx] = (sections[idx][0], "\n" + NEW_QUICK_START + "\n")
            changes.append("Updated §Quick Start (new workflow file paths)")

    if changes and not dry_run:
        path.write_text(reassemble(sections), encoding="utf-8")

    return changes


# ── TRACKING.md Migration ──────────────────────────────────────────────

def migrate_tracking_md(path: Path, dry_run: bool) -> list[str]:
    """Migrate TRACKING.md — add Working Context if missing."""
    text = path.read_text(encoding="utf-8")
    changes: list[str] = []

    if "## Working Context" not in text:
        # Insert after title (first line starting with #) and before first ## section
        lines = text.splitlines(keepends=True)
        insert_pos = 0
        for i, line in enumerate(lines):
            if line.startswith("# ") and i == 0:
                insert_pos = i + 1
                continue
            if line.startswith("## "):
                insert_pos = i
                break

        wc_lines = ["\n"] + [l + "\n" for l in WORKING_CONTEXT_TEMPLATE.splitlines()] + ["\n"]
        lines[insert_pos:insert_pos] = wc_lines
        changes.append("Added §Working Context section")

        if not dry_run:
            path.write_text("".join(lines), encoding="utf-8")

    return changes


# ── Framework Files ────────────────────────────────────────────────────

def find_template_source() -> Path | None:
    """Find template source directory (the repo itself or a temp clone)."""
    # Check if we're running from within the template repo
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent
    if (repo_root / "Docs" / "Workflow" / "AGENT-RULES.md").exists():
        return repo_root
    return None


def copy_framework_files(root: Path, source: Path, dry_run: bool) -> list[str]:
    """Copy framework files from template source to project."""
    actions: list[str] = []

    # Directories to copy entirely
    dirs_to_copy = [
        ("Docs/Workflow", "Docs/Workflow"),
        ("Docs/Systems", "Docs/Systems"),
        ("Tools/sprint_lib", "Tools/sprint_lib"),
    ]

    for src_rel, dst_rel in dirs_to_copy:
        src = source / src_rel
        dst = root / dst_rel
        if src.exists():
            if dry_run:
                actions.append(f"Copy {src_rel}/ ({len(list(src.rglob('*')))} files)")
            else:
                if dst.exists():
                    shutil.rmtree(dst)
                shutil.copytree(src, dst)
                actions.append(f"Copied {src_rel}/")

    # Individual files to copy
    files_to_copy = [
        "Tools/sprint-tools",
        "Tools/sprint-item.py",
        "Tools/sprint-state.py",
        "Tools/sprint-checkpoint.py",
        "Tools/sprint-baseline.py",
        "Tools/sprint-close.py",
        "Tools/sprint-git.py",
        "Tools/sprint-index.py",
        "Tools/sprint-metrics.py",
        "Tools/sprint-note.py",
        "Tools/sprint-learn.py",
        "Tools/sprint-review.py",
        "Tools/sprint-migrate.py",
        "Tools/pyproject.toml",
        "WORKFLOW.md",
        ".claude/hooks-config.sh",
        ".claude/setup-audit.sh",
    ]

    for rel in files_to_copy:
        src = source / rel
        dst = root / rel
        if src.exists():
            if dry_run:
                actions.append(f"Copy {rel}")
            else:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)

    # Hook scripts — copy all
    hooks_src = source / ".claude" / "hooks"
    hooks_dst = root / ".claude" / "hooks"
    if hooks_src.exists():
        if dry_run:
            actions.append(f"Copy .claude/hooks/ ({len(list(hooks_src.glob('*.sh')))} scripts)")
        else:
            hooks_dst.mkdir(parents=True, exist_ok=True)
            for sh in hooks_src.glob("*.sh"):
                shutil.copy2(sh, hooks_dst / sh.name)
            actions.append("Copied .claude/hooks/")

    # settings.json — merge (add new hooks, preserve user custom hooks)
    settings_src = source / ".claude" / "settings.json"
    settings_dst = root / ".claude" / "settings.json"
    if settings_src.exists():
        if dry_run:
            actions.append("Merge .claude/settings.json")
        else:
            merge_settings_json(settings_src, settings_dst)
            actions.append("Merged .claude/settings.json")

    # sprint-audit.sh — copy only if not user-modified
    audit_src = source / "Tools" / "sprint-audit.sh"
    audit_dst = root / "Tools" / "sprint-audit.sh"
    if audit_src.exists():
        if not audit_dst.exists():
            if not dry_run:
                shutil.copy2(audit_src, audit_dst)
            actions.append("Copied Tools/sprint-audit.sh (new)")
        else:
            actions.append("Skipped Tools/sprint-audit.sh (user-modified, manual review needed)")

    # Docs that should only be created if missing
    for rel in ["Docs/SPRINT-INDEX.md"]:
        src = source / rel
        dst = root / rel
        if src.exists() and not dst.exists():
            if not dry_run:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
            actions.append(f"Created {rel}")

    # Deploy skeleton files (only if target doesn't exist)
    skel_dir = source / "Docs" / "Workflow" / "Skeletons"
    if skel_dir.is_dir():
        skel_map = {
            "CLAUDE.md": root / "CLAUDE.md",
            "TRACKING.md": root / "TRACKING.md",
            "SPRINT-INDEX.md": root / "Docs" / "SPRINT-INDEX.md",
            "gitignore": root / ".gitignore",
        }
        for skel_name, dst in skel_map.items():
            src = skel_dir / skel_name
            if src.exists() and not dst.exists():
                if not dry_run:
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, dst)
                actions.append(f"Deployed skeleton {skel_name} → {dst.relative_to(root)}")

    return actions


def merge_settings_json(src: Path, dst: Path) -> None:
    """Merge template settings.json into user's, preserving user custom hooks."""
    try:
        new = json.loads(src.read_text())
    except (json.JSONDecodeError, FileNotFoundError):
        return

    if dst.exists():
        try:
            old = json.loads(dst.read_text())
        except json.JSONDecodeError:
            old = {}
    else:
        old = {}

    # Merge hooks: keep user's custom entries, add new template entries
    new_hooks = new.get("hooks", {})
    old_hooks = old.get("hooks", {})

    for event, entries in new_hooks.items():
        if event not in old_hooks:
            old_hooks[event] = entries
        else:
            # Add entries from new that aren't in old (by command string)
            old_commands = {h.get("hooks", [{}])[0].get("command", "") for entry in old_hooks[event] for h in [entry]}
            for entry in entries:
                cmd = entry.get("hooks", [{}])[0].get("command", "")
                if cmd and cmd not in str(old_hooks[event]):
                    old_hooks[event].append(entry)

    old["hooks"] = old_hooks

    # Preserve env settings from new template
    if "env" in new:
        old.setdefault("env", {}).update(new["env"])

    dst.write_text(json.dumps(old, indent=2) + "\n")


def merge_hooks_config(root: Path, source: Path, dry_run: bool) -> list[str]:
    """Merge hooks-config.sh: preserve user overrides, bump version."""
    dst = root / ".claude" / "hooks-config.sh"
    src = source / ".claude" / "hooks-config.sh"
    if not src.exists():
        return []

    changes: list[str] = []
    user_overrides: dict[str, str] = {}

    # Extract user overrides from old file
    if dst.exists():
        for line in dst.read_text().splitlines():
            # Lines that are uncommented and set by user (not defaults)
            if re.match(r'^(WORKFLOW_MODE|HOOK_\w+|CROSS_AUDIT_\w+|ENABLE_\w+)=', line):
                key = line.split("=", 1)[0]
                user_overrides[key] = line

    if not dry_run:
        # Copy new template
        shutil.copy2(src, dst)
        # Re-apply user overrides
        if user_overrides:
            text = dst.read_text()
            for key, override_line in user_overrides.items():
                # Find the default line and replace with user override
                text = re.sub(rf'^{key}=.*$', override_line, text, flags=re.MULTILINE)
            dst.write_text(text)
            changes.append(f"Merged hooks-config.sh (preserved {len(user_overrides)} user overrides)")
        else:
            changes.append("Copied hooks-config.sh (no user overrides)")
    else:
        if user_overrides:
            changes.append(f"Merge hooks-config.sh (preserve {len(user_overrides)} user overrides)")
        else:
            changes.append("Copy hooks-config.sh")

    return changes


def delete_old_files(root: Path, dry_run: bool) -> list[str]:
    """Delete files that no longer exist in v3.1."""
    actions: list[str] = []
    for rel in OLD_FILES_TO_DELETE:
        f = root / rel
        if f.exists():
            if dry_run:
                actions.append(f"Delete {rel} (moved to Docs/Workflow/)")
            else:
                f.unlink()
                actions.append(f"Deleted {rel}")
    return actions


# ── Backup & Rollback ──────────────────────────────────────────────────

def create_backup(root: Path) -> Path:
    """Backup all files that will be touched. Returns backup dir path."""
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = root / f".sprint-migrate-backup-{ts}"
    backup_dir.mkdir()

    manifest = {"version_from": "", "version_to": TARGET_VERSION, "timestamp": ts, "files": {}}

    files_to_backup = [
        "CLAUDE.md", "WORKFLOW.md",
        ".claude/hooks-config.sh", ".claude/settings.json", ".claude/setup-audit.sh",
    ]
    # Add all tracking files
    for f in root.glob("TRACKING*.md"):
        files_to_backup.append(f.name)
    # Add old docs
    files_to_backup.extend(OLD_FILES_TO_DELETE)
    # Add hook scripts
    hooks_dir = root / ".claude" / "hooks"
    if hooks_dir.exists():
        for sh in hooks_dir.glob("*.sh"):
            files_to_backup.append(f".claude/hooks/{sh.name}")

    for rel in files_to_backup:
        src = root / rel
        if src.exists():
            dst = backup_dir / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            manifest["files"][rel] = {"action": "modified", "backup": rel}

    (backup_dir / ".manifest.json").write_text(json.dumps(manifest, indent=2))
    return backup_dir


def rollback(root: Path, backup_dir: Path) -> None:
    """Restore files from backup."""
    manifest_path = backup_dir / ".manifest.json"
    if not manifest_path.exists():
        print(f"Error: No manifest found in {backup_dir}", file=sys.stderr)
        sys.exit(1)

    manifest = json.loads(manifest_path.read_text())
    restored = 0

    for rel, info in manifest["files"].items():
        backup_file = backup_dir / info.get("backup", rel)
        target = root / rel
        if backup_file.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(backup_file, target)
            restored += 1

    print(f"Rollback complete: {restored} files restored from {backup_dir}")


# ── Validation ─────────────────────────────────────────────────────────

def validate(root: Path) -> list[tuple[str, bool, str]]:
    """Run post-migration validation checks."""
    checks: list[tuple[str, bool, str]] = []

    # 1. CLAUDE.md has Available Tools
    claude_md = root / "CLAUDE.md"
    if claude_md.exists():
        text = claude_md.read_text()
        checks.append(("CLAUDE.md §Available Tools", "## Available Tools" in text, ""))
        checks.append(("CLAUDE.md §Document Contract", "ENTRY-GATE.md" in text, "still references old paths"))
    else:
        checks.append(("CLAUDE.md exists", False, "file not found"))

    # 2. TRACKING.md has Working Context
    for t in root.glob("TRACKING*.md"):
        text = t.read_text()
        checks.append((f"{t.name} §Working Context", "## Working Context" in text, ""))

    # 3. Workflow files exist
    for doc in ["AGENT-RULES.md", "ENTRY-GATE.md", "IMPL-LOOP.md", "CLOSE-GATE.md", "SPRINT-CLOSE.md", "TEMPLATES.md"]:
        exists = (root / "Docs" / "Workflow" / doc).exists()
        checks.append((f"Docs/Workflow/{doc}", exists, ""))

    # 4. sprint-tools exists
    checks.append(("Tools/sprint-tools", (root / "Tools" / "sprint-tools").exists(), ""))

    # 5. No orphan old files
    for old in OLD_FILES_TO_DELETE:
        f = root / old
        checks.append((f"No orphan {old}", not f.exists(), "old file still exists"))

    # 6. Version updated
    v = detect_version(root)
    checks.append((f"Version = {TARGET_VERSION}", v == TARGET_VERSION, f"detected: {v}"))

    return checks


# ── Main ───────────────────────────────────────────────────────────────

def main() -> None:
    args = sys.argv[1:]
    dry_run = "--dry-run" in args

    # Rollback mode
    if "--rollback" in args:
        idx = args.index("--rollback")
        if idx + 1 >= len(args):
            print("Usage: sprint-migrate.py --rollback <backup-dir>", file=sys.stderr)
            sys.exit(1)
        backup_dir = Path(args[idx + 1])
        root = Path.cwd()
        rollback(root, backup_dir)
        return

    # Find project root
    root = Path.cwd()
    if not (root / "CLAUDE.md").exists() and not (root / "WORKFLOW.md").exists():
        # Try parent dirs
        for p in root.parents:
            if (p / "CLAUDE.md").exists() or (p / "WORKFLOW.md").exists():
                root = p
                break

    # Detect version
    current = detect_version(root)
    if current is None:
        print("Error: Cannot detect workflow version. Is this a sprint-workflow project?", file=sys.stderr)
        sys.exit(1)

    if current == TARGET_VERSION:
        print(f"Already at v{TARGET_VERSION}. Nothing to do.")
        return

    if current not in SUPPORTED_SOURCES:
        print(f"Error: Migration from v{current} is not supported. Supported: {SUPPORTED_SOURCES}", file=sys.stderr)
        sys.exit(1)

    # Find template source
    source = find_template_source()
    if source is None:
        print("Error: Cannot find template source. Run from within the template repo or provide --source.", file=sys.stderr)
        sys.exit(1)

    # Preview
    print(f"\nMigration v{current} → v{TARGET_VERSION}")
    print("=" * 40)
    print()

    # Phase 1: Backup
    if not dry_run:
        backup_dir = create_backup(root)
        print(f"Backup: {backup_dir}")
    else:
        print("[DRY RUN] Would create backup")
    print()

    # Phase 2: CLAUDE.md
    claude_path = root / "CLAUDE.md"
    if claude_path.exists():
        claude_changes = migrate_claude_md(claude_path, dry_run)
        print("CLAUDE.md:")
        for c in claude_changes:
            print(f"  [{'PREVIEW' if dry_run else 'OK'}] {c}")
        if not claude_changes:
            print("  [OK] Already up to date")
    else:
        print("CLAUDE.md: not found (will be created at bootstrap)")
    print()

    # Phase 3: TRACKING.md
    tracking_files = list(root.glob("TRACKING*.md"))
    for t in tracking_files:
        tracking_changes = migrate_tracking_md(t, dry_run)
        print(f"{t.name}:")
        for c in tracking_changes:
            print(f"  [{'PREVIEW' if dry_run else 'OK'}] {c}")
        if not tracking_changes:
            print("  [OK] Already up to date")
    if not tracking_files:
        print("TRACKING.md: not found (will be created at bootstrap)")
    print()

    # Phase 4: Framework files
    print("Framework files:")
    framework_actions = copy_framework_files(root, source, dry_run)
    config_actions = merge_hooks_config(root, source, dry_run)
    for a in framework_actions + config_actions:
        print(f"  [{'PREVIEW' if dry_run else 'OK'}] {a}")
    print()

    # Phase 5: Cleanup old files
    print("Cleanup:")
    cleanup_actions = delete_old_files(root, dry_run)
    for a in cleanup_actions:
        print(f"  [{'PREVIEW' if dry_run else 'OK'}] {a}")
    if not cleanup_actions:
        print("  [OK] No old files to clean up")
    print()

    # Phase 6: Validation
    if not dry_run:
        print("Validation:")
        checks = validate(root)
        pass_count = sum(1 for _, ok, _ in checks if ok)
        for name, ok, detail in checks:
            status = "PASS" if ok else "FAIL"
            extra = f" — {detail}" if detail and not ok else ""
            print(f"  [{status}] {name}{extra}")
        print(f"\n  {pass_count}/{len(checks)} checks passed")

    # Summary
    print()
    if dry_run:
        print("Dry run complete. No files were modified.")
        print("Run without --dry-run to apply migration.")
    else:
        print(f"Migration complete: v{current} → v{TARGET_VERSION}")
        print(f"Rollback: python3 Tools/sprint-migrate.py --rollback {backup_dir}")


if __name__ == "__main__":
    main()
