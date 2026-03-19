# Memory / State Persistence System

How information survives across sessions and context compaction.

## 1. Overview

All state is file-based — no database, no vector store. The system uses two layers:
always-on context (loaded every session) and on-demand context (pulled when needed).
State lives in markdown files parsed by `Tools/sprint_lib/tracking_parser.py` and
injected by `.claude/hooks/memory-sync.sh` (Claude Code) or read manually via
`sprint-tools state` (any agent).

## 2. Two-Layer Context Model

Defined in `Docs/Workflow/AGENT-RULES.md` (section "Context Loading").

**Layer 1 — Always-on (session start, auto-loaded):**

| File | Content | Update frequency |
|------|---------|-----------------|
| `CLAUDE.md` | Project identity, contracts, Last Checkpoint | Sprint boundaries |
| `TRACKING.md` | Sprint board, Working Context, risks, changelog | Every commit / decision point |
| `CODING_GUARDRAILS.md` (index only) | Relevant sections per task | After bug fixes (Update Rule) |

**Layer 2 — On-demand (AI pulls when needed):**

| File | Content | When loaded |
|------|---------|-------------|
| `Roadmap.md` | Sprint plans (Must/Should/Could) | Session start (step 3), Entry Gate |
| `feedback_*.md`, `project_*.md`, `user_*.md` | Claude Code memory files (see note below) | When topic arises |
| `Docs/Archive/` | Closed sprint gate reports | Cross-sprint investigation |
| `Docs/SPRINT-INDEX.md` | Topic-first cross-sprint lookup | Entry Gate step 9a, research |
| `Docs/Workflow/` files | Procedure docs | Only the one needed for current task |

> **Other agents:** `feedback_*.md`, `project_*.md`, `user_*.md` are Claude Code memory file conventions. Use your agent's own memory/context system for equivalent functionality.

## 3. TRACKING.md Anatomy

Template defined in `Docs/Workflow/TEMPLATES.md` (section 2). Parsed by
`Tools/sprint_lib/tracking_parser.py` into `TrackingData` (see `models.py`).

| Section | What it stores | Lifetime | Model field |
|---------|---------------|----------|-------------|
| **Working Context** | Task, Doing, Decisions, Blockers (4 lines) | Task-scoped, overwritten on task switch | `WorkingContext` |
| **Current Focus** | Sprint N + one-line description | Sprint-scoped | `current_focus: str` |
| **Sprint Board** | Item ID, summary, status, sprint, evidence | Sprint-scoped | `items: list[Item]` |
| **Open Risks / Blockers** | Risk ID, description, mitigation, sprint | Sprint-scoped | `risks: list[Risk]` |
| **Predicted Failure Modes** | Per-item predictions from Entry Gate step 9a | Sprint-scoped (replaced each sprint) | `predicted_failures: list[FailureMode]` |
| **Failure Encounters** | Bugs logged during implementation | Sprint-scoped (replaced each sprint) | `failure_encounters: list[FailureEncounter]` |
| **Failure Mode History** | Retrospective from Sprint Close step 7 | Cross-sprint (accumulates) | `failure_history: list[FailureHistory]` |
| **Performance Baseline Log** | Metric, value, unit, method per sprint | Cross-sprint (accumulates) | `baselines: list[BaselineEntry]` |
| **Dismissed Signals** | Audit proposals user said NO to | Cross-sprint | `dismissed_signals: list[DismissedSignal]` |
| **Change Log** | Dated entries per sprint | Sprint-scoped (archived at close) | `changelog_entries: dict[str, list[str]]` |

Valid item statuses: `open`, `in_progress`, `fixed`, `verified`, `deferred`, `blocked`.
Transitions enforced by `VALID_TRANSITIONS` in `models.py`.

## 4. Working Context

Defined in `AGENT-RULES.md` (section "Working Context"). Lives inside `TRACKING.md`.

**Format (4 lines max):**
```
Task: [item ID + description]
Doing: [current file/action]
Decisions: [key choices made and why]
Blockers: [current blocks or "---"]
```

**Update triggers:** starting a new task, making a key decision, changing direction, hitting a blocker.

**DO NOT WRITE:** tool outputs (re-runnable), code snippets (in files already), general knowledge (not project-specific).

**TASK SWITCH rule:** Before overwriting Working Context for a new task, copy the current `Decisions` line to a Change Log entry. This preserves decision rationale across tasks. Defined in `AGENT-RULES.md` section "TASK SWITCH".

**Cross-session:** Previous session's Working Context persists in TRACKING.md on disk. New session reads it, continues naturally — no "reset or continue?" prompt.

## 5. State Survival Mechanisms

The conceptual requirement is that sprint state must survive across five boundaries: normal session end, mid-session compaction, crashes, session restarts, and sprint transitions. The mechanisms below ensure no state is lost at any boundary.

> **Other agents:** The concepts (dirty-state detection, compaction recovery, crash recovery, session bootstrap, sprint archival) are universal. Claude Code automates them via hooks; other agents achieve the same by running the equivalent `sprint-tools` commands manually or integrating them into their own lifecycle hooks.

### Claude Code Automation

All hooks are in `.claude/hooks/memory-sync.sh`. Activation requires `HOOK_MEMORY_SYNC=true` in `hooks-config.sh`.

### 5a. Normal session end

TRACKING.md is on disk with current state. The Stop hook blocks session end if
TRACKING has not been updated (checks for today's date in changelog, uncommitted
non-TRACKING changes, or commits today without a TRACKING update).

### 5b. Context compaction (mid-session)

`PreCompact` event fires. Hook writes `additionalContext` telling the AI:
"Context is being compacted. After compaction, read TRACKING.md to restore sprint
state and Working Context." This is a pull-based strategy — the hook gives a short
directive, AI reads the full file.

### 5c. Crash / abnormal termination

Last git commit is the recovery point. Post-commit hook (PostToolUse/Bash) detects
successful `git commit` output and reminds AI to update TRACKING. If session dies
before next commit, the committed TRACKING state is the recovery baseline.

### 5d. Session boundary

`CLAUDE.md` Last Checkpoint + TRACKING.md together are authoritative.
`SessionStart` hook injects: "Read TRACKING.md for sprint state, Working Context,
and risks." plus available tool hints. AI follows Session Start protocol from
`AGENT-RULES.md`.

### 5e. Sprint transition

`sprint-tools close N` archives sprint sections to `Docs/Archive/`, cleans up
TRACKING.md, updates CLAUDE.md checkpoint. SPRINT-INDEX.md carries cross-sprint
topic lookup forward.

## 6. Memory Consolidation

Defined in `Docs/Workflow/SPRINT-CLOSE.md` step 7c ("Memory Consolidation: Episodic to Procedural").

Runs at sprint close. Five steps:

1. **Inventory** — List all `feedback_*.md` files with topic and creation date.
2. **Pattern detection** — Group feedback pointing to same root cause. 2+ feedback on same pattern = promotion candidate.
3. **Promotion** — General patterns become `CODING_GUARDRAILS.md` rules (what + why + how). Promoted feedback files are deleted and removed from MEMORY.md index.
4. **Retention check** — Use `git log` to find which feedback files were read in last 3 sprints. Not read in 3 sprints = delete (stale).
5. **Index hygiene** — Verify MEMORY.md has no orphan links. Verify MEMORY.md is under 200 lines.

## 7. Sprint Digest

Built by `Tools/sprint-state.py`, function `build_digest()`. Invoked via `sprint-tools state`.

### What it reads

1. `TRACKING.md` — parsed via `tracking_parser.parse()` into `TrackingData`
2. `Roadmap.md` — parsed for item priorities and active sprint detection
3. Entry/Close Gate files — checked for existence and verdict (via `gate_parser`)
4. `hooks-config.sh` — for workflow mode and sprint type

### What it produces

`SprintDigest` dataclass (`models.py`) containing:

| Field | Source |
|-------|--------|
| `sprint_n` | Extracted from Current Focus or Roadmap |
| `sprint_type` | `hooks-config.sh` SPRINT_TYPE (default: "feature") |
| `items` | Sprint Board filtered to active sprint, enriched with Roadmap priorities |
| `risks` | Open Risks table |
| `recurring_failure_categories` | Failure Mode History scanned for categories appearing in 2+ sprints |
| `latest_baselines` | Most recent sprint's baseline entries |
| `entry_gate_exists` | Whether gate file found on disk |
| `phase` | Inferred from items + gate files + changelog (7 values: planned, entry_gate, impl_loop, impl_done, close_gate, sprint_close, done) |
| `working_context` | Working Context section (Task/Doing/Decisions/Blockers) |

### How it's injected

Text format via `format_text()` — compact block (target <=23 lines) showing sprint
header, item list sorted by priority, risk count, Working Context summary, baseline
values, and recurring failure warnings. Also available as JSON via `--json` flag.

> **Other agents:** Run `sprint-tools state` (or `sprint-tools state --json`) at session start to get this digest. No hooks required -- the command works standalone.

#### Claude Code Automation

The `SessionStart` hook in `memory-sync.sh` tells the AI that `sprint-tools state`
is available. When sprint-tools is installed, the session start protocol in
`AGENT-RULES.md` notes: "IF sprint-tools available: steps 2-3 covered by
auto-injected state digest."

## 8. File Reference

| File | Role in memory system |
|------|----------------------|
| `.claude/hooks/memory-sync.sh` | Hook: SessionStart/PreCompact/PostToolUse/Stop event handling |
| `Tools/sprint-state.py` | Builds SprintDigest from project files |
| `Tools/sprint_lib/tracking_parser.py` | Parses TRACKING.md into TrackingData |
| `Tools/sprint_lib/models.py` | Data models: TrackingData, SprintDigest, WorkingContext, Item, etc. |
| `Docs/Workflow/AGENT-RULES.md` | Context Loading rules, Working Context protocol, TASK SWITCH |
| `Docs/Workflow/TEMPLATES.md` | TRACKING.md template (all sections) |
| `Docs/Workflow/SPRINT-CLOSE.md` | Step 7c: Memory Consolidation procedure |
| `CLAUDE.md` (per-project) | Last Checkpoint, Document Contract, project identity |
| `TRACKING.md` (per-project) | Sprint state: board, Working Context, risks, changelog, baselines, failures |
