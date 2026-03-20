<instructions>

# CRITICAL: Never overwrite custom logic. Always show diff and ask user: replace / keep / merge.
# CRITICAL: settings.json and hooks-config.sh — MERGE, never replace. Preserve all existing entries.
# CRITICAL: Apply changelog entries oldest to newest. Verify after every upgrade.

# Adaptation & Upgrade Guide

## Project Size Adaptation

### Small Project (1-5 files)

1. Skip: Entry Gate Phase 2, sprint-audit.sh
2. Keep: Self-verification loop, close gate manual audit, TRACKING.md
3. Abbreviated Entry Gate:
   - Phase 0: run if sprint is sketch (same as full)
   - Phase 1: steps 1-2 only (read TRACKING + Roadmap)
   - Phase 2: skip entirely
   - Phase 3: steps 8 + 10 + 12 only (strategic alignment, scope check, confirm)
   - Skip failure mode analysis (9a) and verification plan detail (9b-c)

### Medium Project (5-50 files)

Use full workflow. sprint-audit.sh valuable at 10+ source files.

### Large Project (50+ files)

Add: strict atomic commits, code review gate on sprint branch, CI for sprint-audit.sh and ci-guardrail-check.sh.
Consider: separate guardrails per subsystem.

### Solo vs Team

Default = solo. Team adds coordination only; core workflow unchanged.
- Team guide: [TEAM-GUIDE.md](TEAM-GUIDE.md)
- Unity projects: [UNITY-GUIDE.md](UNITY-GUIDE.md)

---

## Upgrade Procedure

### Version System

```
WORKFLOW.md line 2: <!-- workflow-version: X.Y -->   (canonical)
.claude/hooks-config.sh: HOOKS_VERSION="X.Y"        (installed)
session-start.sh compares both at every session start.
```

### Option A: Manual Upgrade (Re-clone + Copy)

```bash
git clone --depth 1 https://github.com/IVBACK/ai-sprint-workflow /tmp/sprint-workflow-src
```

Steps:
1. Clone the latest template repo (shallow clone, temporary)
2. Compare versions; stop if matching
3. Backup hooks-config.sh.bak + settings.json.bak
4. Copy updated workflow docs from `/tmp/sprint-workflow-src/Docs/` to your project
5. Copy updated hook scripts from `/tmp/sprint-workflow-src/.claude/hooks/` (framework code, always replaced)
6. Merge settings.json manually (add new hooks, preserve user custom hooks)
7. Preserve all user overrides (WORKFLOW_MODE, HOOK_*, ENABLE_*, CROSS_AUDIT_ENFORCE_BLOCK)
8. Bump HOOKS_VERSION to upstream version
9. `rm -rf /tmp/sprint-workflow-src`

Safety guarantees: no config lost, custom hooks preserved, .env never touched, .bak files for recovery.

### Option B: AI-Driven Upgrade

**Step 1 — Detect versions**
```
IF HOOKS_VERSION matches target: "Already up to date." STOP.
ELIF HOOKS_VERSION exists but differs: proceed Step 2.
ELIF HOOKS_VERSION missing: treat as v1.0, proceed Step 2.
ELIF hooks-config.sh missing: fresh bootstrap, not upgrade. Run bootstrap procedure (see BOOTSTRAP.md). STOP.
```

**Step 2 — Read Changelog (cumulative)**
```
Read Changelog in WORKFLOW.md.
Collect ALL entries NEWER than current HOOKS_VERSION.
Present change list to user before proceeding.
```

**Step 3 — Backup**
```
For each file to modify:
  cp file file.backup-vX.Y
Log all backup paths.
```

**Step 4 — Apply Changes (oldest to newest)**
```
IF prefix "New hook: X":     Create from templates. Register in settings.json.
ELIF prefix "Updated hook: X":
  IF file matches template: regenerate.
  ELSE: show diff, ask user: replace / keep / merge.
ELIF prefix "New config: X": Add variable to hooks-config.sh. Preserve existing overrides.
ELIF prefix "Updated: X":    Apply specific change described.
ELIF prefix "New doc: X":    Create if missing. Never overwrite existing.
ELIF prefix "Doc: X":        Informational only, no file changes.
```

**Step 5 — Bump Version**
```
Parse top Changelog entry -> extract vX.Y.
Update HOOKS_VERSION in hooks-config.sh.
Update workflow-version in WORKFLOW.md line 2.
```

**Step 6 — Verify**
```
Run: bash validation/validate-structure.sh && bash validation/validate-model.sh
IF all pass: proceed to summary.
ELSE: fix failing check, re-run.
Start new session to confirm session-start.sh runs clean.
```

**Step 7 — Summary**
```
Report: upgraded vX.Y -> vZ.W, files created, files updated,
custom changes preserved, backup paths, validation results, manual steps needed.
```

### Changelog Prefix Reference

| Prefix | AI Action |
|--------|-----------|
| `New hook:` | Create from template + register in settings.json |
| `Updated hook:` | Diff check -> replace or merge |
| `New:` | Create file or add feature |
| `Updated:` | Apply specific change |
| `New doc:` | Create if missing |
| `Doc:` | Informational only |

### Upgrade via GitHub Link

Preferred: re-clone template repo + copy updated files (see Option A above).

Alternative (AI-driven):
1. Fetch new WORKFLOW.md from repo (curl or WebFetch)
2. Save to project root
3. Optionally update .claude/hooks/ from repo
4. Run AI-Driven Upgrade (Steps 1-7)

Edge cases:
```
IF no .claude/ directory: fresh project. Run bootstrap procedure (see BOOTSTRAP.md). STOP.
ELIF .claude/ exists but no HOOKS_VERSION: pre-version (v1.0). Apply all from v2.0 onward.
ELIF custom hooks not in template: leave untouched (user extensions).
```

### Important Upgrade Rules

1. Never overwrite custom logic — show diff, ask user
2. settings.json: merge, not replace. Add new matchers, never remove
3. hooks-config.sh: merge, not replace. Preserve WORKFLOW_MODE + all HOOK_* overrides
4. Apply changelog oldest to newest (newer entries may depend on older)
5. Verify after upgrade: run validate-structure.sh + validate-model.sh + new session test

---

## Changelog

<!-- Add new versions at top. AI reads during upgrade. -->

### v3.1 (2026-03-17)
- **Updated hook:** `session-start.sh` — detects missing §Available Tools in CLAUDE.md, injects warning
- **Updated hook:** `validate-tracking.sh` — warns on manual Sprint Board edits without sprint-tools
- **New audit:** `sprint-audit.sh` §17 — BLOCKER if CLAUDE.md missing §Available Tools
- **Updated doc:** `TEMPLATES.md` — §Available Tools marked CRITICAL (do not omit during bootstrap)
- **Required CLAUDE.md change:** Append §Available Tools section from `Docs/Workflow/TEMPLATES.md` if missing. This section lists sprint-tools commands — without it, AI agents will not use sprint-tools and will manually edit TRACKING.md, causing format drift.

### v3.0 (2026-03-14)
- **Breaking:** WORKFLOW.md split into 11 files under `Docs/Workflow/`
- **Removed:** `Docs/SPRINT_WORKFLOW.md` copy step
- **Updated:** CLAUDE.md routes to individual workflow files
- **Updated:** Validation scripts use `resolve-workflow.sh` (backward compatible)
- **Updated:** `session-start.sh` references `Docs/Workflow/ADAPTATION.md`
- **Updated:** README file tree, bootstrap, context separation docs

### v2.1 (2026-03-11)
- **New:** Version system (workflow-version, HOOKS_VERSION, mismatch detection)
- **New:** Upgrade procedure (AI-driven via changelog)
- **New hook:** `protect-secrets.sh` (6-layer Bash protection)
- **Updated hook:** `session-start.sh` (first-run, cross-audit status, version mismatch)
- **Updated:** `setup-audit.sh` (3-layer safety, retry loop, error handling)
- **Updated:** `hooks-config.sh` (HOOK_PROTECT_SECRETS, HOOKS_VERSION, local overrides)
- **Updated:** `.gitignore` template (secret patterns)
- **Updated:** Bootstrap Step 3 (.gitignore secrets)
- **Updated:** Discovery Q15 (Claude Code prerequisite)
- **Doc:** `CROSS-LLM-AUDIT.md` (safety layers, config reference)
- **Updated hook:** `cross-llm-audit.sh` (wave-review, worktree detection)
- **Updated hook:** `detect-audit-signals.sh` (PostToolUse filter, missing section warnings)
- **Updated:** `CROSS-LLM-AUDIT.md` (four audit modes, sub-agent skip)

### v2.0 (2026-03-01)
- **New:** Cross-LLM audit system
- **New hook:** `cross-llm-audit.sh` (wave/item trigger)
- **New:** `setup-audit.sh` (7 providers, API key via read -s)
- **New:** `.env.example`
- **New:** Team topology support
- **New:** Sprint branch isolation, pre-code safety checks
- **New:** Sprint index with structured tagging
- **Doc:** `CROSS-LLM-AUDIT.md`, `TEAM-GUIDE.md`, `WORKFLOW-MODES.md`

### v1.0
- Initial release: Entry Gate, Close Gate, Sprint Close, Implementation Loop
- 8 hooks: protect-claude, validate-tracking, session-start, id-uniqueness, entry-gate-session, detect-test-regression, validate-close-gate, validate-sprint-close
- Templates: sprint-audit.sh, CODING_GUARDRAILS.md
- Modes: Lite, Standard, Strict
- detect-audit-signals.sh (CP1+CP2, TRACKING.md edits)

# CRITICAL: Never overwrite custom logic. Always show diff and ask user: replace / keep / merge.
# CRITICAL: settings.json and hooks-config.sh — MERGE, never replace.
# CRITICAL: Apply changelog oldest to newest. Verify after every upgrade.

</instructions>
