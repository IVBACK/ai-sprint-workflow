<instructions>

# File Templates

CRITICAL: Use these templates exactly during bootstrap. All templates contain required structure — do not omit sections.

---

## 1. CLAUDE.md Template

**Skeleton file:** `Docs/Workflow/Skeletons/CLAUDE.md` — pre-shipped during install.
Static sections (Document Contract, Operational Rules, Available Tools, Quick Start) are
already complete. At bootstrap, only fill `[REQUIRED: ...]` placeholders.
Do NOT rewrite or regenerate static sections — they are the authoritative source.

Full reference template below (for migration and manual setup):

```markdown
# [Project Name] — AI Session Context

This file provides quick context for every AI session.

## Document Contract

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

Rule: Bug and sprint status is NOT duplicated here; only short references.

## Project Summary

[One paragraph: language, framework, architecture, target platform, key goals]
VCS: [git | svn | none]
Critical Axis: [security | performance | reliability | correctness | other: ...]
Team: [solo | names — e.g., "Dev-A, Dev-B"]

## Immutable Contracts

[List things that MUST NOT change without explicit architectural revision]
- [Data format: ...]
- [API contract: ...]
- [Convention: ...]
- [Build target: ...]

## Operational Rules

- Use `sprint-tools item` for status transitions (NOT manual TRACKING edit). See §Available Tools.
- `fixed → verified` transition requires evidence (test output or pass confirmation). Full flow: open → in_progress → fixed → verified.
- Check `Docs/CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Roadmap checkbox `[x]` only when item is `verified` in TRACKING.md. `[~]` only when `deferred`. Intermediate states (in_progress, fixed-untested) are not shown in roadmap — TRACKING.md is the single source. `sprint-audit.sh` Section 11 catches mismatches automatically.
- Close Gate is user-initiated only. AI never asks "shall we close the sprint?" unprompted.
  Reading all items as `verified` in TRACKING.md is not a trigger — it is just state.
- Sprint close gate:
  - Run `Tools/sprint-audit.sh` (automated scan, 17 sections).
  - Manual review (see `CODING_GUARDRAILS.md` §Close Gate).
- Session boundaries: at known heavy-context transition points (after Entry Gate, before Close Gate),
  AI MUST explicitly recommend starting a new session. AI cannot assess its own context usage —
  this recommendation is mandatory, not optional. User decides whether to follow it.
- All code, comments in [English/language].
- Commit policy (if VCS in use): sprint branch (`sprint-N-impl` solo / `sprint-N-name-impl` team), commit after each item's D.7, squash merge to main after Close Gate (solo: local merge, team: PR-based merge — see [TEAM-GUIDE.md](Docs/Workflow/TEAM-GUIDE.md) §Pull Request Integration). Commit style: [conventional/free-form]. Commit messages in [English/language]. If VCS=none: skip.

## Last Checkpoint

- Date: [YYYY-MM-DD]
- Active focus: [Sprint N status]
- Status: [Key items completed]
- Next step: [What's next]

## Available Tools

CRITICAL: This section MUST be included in CLAUDE.md during bootstrap. Do not omit — without it, the AI will not know sprint-tools exist and will manually edit files instead.

```
Anytime:
  sprint-tools state          — sprint digest (items, risks, phase, Working Context)
  sprint-tools note <type> "text" — session journal (decision/attempt/observation/side-effect/artifact)
  sprint-tools learn "text"       — classify + route finding (guardrail/index/risk, --dry-run default)
  sprint-tools review <file>  — blind review via external LLM

Workflow steps:
  sprint-tools item ID[,ID,...] status — status transition + changelog (batch supported)
  sprint-tools checkpoint     — update Last Checkpoint + Working Context
  sprint-tools baseline       — record performance metric
  sprint-tools metrics S<N>   — extract Entry Gate metrics
  sprint-tools close <N>      — sprint close archive + cleanup
  sprint-tools index          — rebuild SPRINT-INDEX.md
  sprint-tools git            — git ceremony (init/commit/push/merge/abort)
  sprint-tools migrate        — upgrade from older workflow version (v2.x → v3.x)
```

## Quick Start

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
- `Docs/CODING_GUARDRAILS.md` → Section Index → relevant sections only
```

## 2. TRACKING.md Template

**Skeleton file:** `Docs/Workflow/Skeletons/TRACKING.md` — pre-shipped during install.
All table structures, status rules, and section headers are pre-built.
At bootstrap, only fill `<!-- FILL: ... -->` placeholders (project name, sprint items).

Full reference template below (for migration and manual setup):

```markdown
# [Project Name] — Tracking

## Working Context

Task: —
Doing: —
Decisions: —
Blockers: —

## Current Focus
Sprint [N]: [one-line description]

## Sprint Board

| ID | Summary | Status | Sprint | Evidence |
|----|---------|--------|--------|----------|
| CORE-001 | [description] | open | S1 | |
| CORE-002 | [description] | in_progress | S1 | |
| CORE-003 | [description] | fixed | S1 | |
| CORE-004 | [description] | verified | S1 | RUN-001 |
| CORE-005 | [description] | deferred | S1 | reason: [why] → target S2 |

Status values: `open` → `in_progress` → `fixed` → `verified`
Special statuses:
- `deferred`: item intentionally skipped (maps to roadmap `[~]`). Requires reason + target sprint.
- `blocked`: item cannot proceed due to external dependency. Requires linked blocker in §Open Risks.
  Format: `blocked by [CORE-### | external description]`. Log block reason in Change Log:
  `[date] CORE-###: blocked — depends on [CORE-### / description]. Expected resolution: [date/sprint].`
  When unblocked: `[date] CORE-###: unblocked — [dependency resolved / reason].` Transition to `open`.
Reverse transition: `verified` → `open` is allowed ONLY when a regression is discovered.
  Log reason in Change Log: "[date] CORE-###: reopened — regression found in [context]"

## Open Risks / Blockers

| ID | Risk | Mitigation | Sprint |
|----|------|------------|--------|
| R-001 | [description] | [plan] | S1 |

## Predicted Failure Modes — Current Sprint

Written at Entry Gate step 9a. Read at Sprint Close step 7 (retrospective comparison).
Replace this section at each new sprint's Entry Gate.

| Item | Category | Predicted Mode | Detection Plan |
|------|----------|---------------|----------------|

## Failure Mode History

Written at Sprint Close step 7 (retrospective). Read at Entry Gate step 9a (failure mode analysis).
Pattern rules:
- Same category 2+ times in last 3 sprints → Architecture Review Required at next Entry Gate.
- Same detection=user-visual 2+ times → "Can an automated proxy test replace visual check?" mandatory question at next Entry Gate.
Category naming: use `type:subsystem` format (e.g. `null-ref:Renderer`, `mem-leak:AudioPool`).
Generic categories (`null-ref`, `crash`) cause CP2 false positives across unrelated subsystems.

| Sprint | Category | Predicted? | Detection | Mode | Impact | Root Cause | Guardrail | Escalate? |
|--------|----------|------------|-----------|------|--------|------------|-----------|-----------|

## Failure Encounters — Current Sprint

Log failures as they are discovered during implementation (bugs, test failures, unexpected behavior).
Sprint Close step 7a reads this for retrospective comparison. Replace at each new sprint.

| Item | Category | Failure Description | Detection | Date |
|------|----------|-------------------|-----------|------|

Category: direct / interaction / stress-edge.
Detection: test / user-visual / profiler / code-review.

## Performance Baseline Log

Recorded at Sprint Close step 5. Read at Entry Gate Phase 1 step 3 (CP1).
New row per sprint per tracked metric. Deltas are derived on demand from adjacent rows.
`Value` must be a plain number (no unit suffix) — unit goes in the `Unit` column.
This format is required for automated CP1 regression detection.

| Sprint | Metric          | Value | Unit | Method         |
|--------|-----------------|-------|------|----------------|
| S1     | [metric_name]   | 12    | ms   | [how measured] |

## Retroactive Audits

Written at Retroactive Sprint Audit Phase 7. Read at Entry Gate step 3 (deferred items)
and Entry Gate step 9a (pattern analysis). Audits without `status: CLOSED` block Sprint Close step 6.

| Audit # | Target Sprint | Status | Trigger | Classification | Resolution | Closed |
|---------|--------------|--------|---------|----------------|------------|--------|
| A-001 | S[N] | OPEN / IN_PROGRESS / CLOSED | [symptom] | [category] | [fix now / next sprint / accepted] | [date] |

Category values: REGRESSION / INTEGRATION_GAP / FALSE_VERIFICATION / COLD_STATE / SCOPE_DRIFT / ENVIRONMENT_DELTA

## Dismissed Signals

Written when user says NO to an audit proposal. Re-surfaced at next Entry Gate if condition
persists (same system, same checkpoint). Suppressed after 2 dismissals — but CP3 and CP4
signals are never suppressed by prior dismissals.
Suppressed signal reactivates if the underlying condition worsens: metric delta increases,
or a new failure is logged in the same system. Dismissal counter resets to 0.

| Date | Checkpoint | System / Metric | Signal Summary | User Decision | Dismissal # | Suppressed? | Revisit Sprint |
|------|-----------|----------------|---------------|---------------|-------------|-------------|----------------|
| [date] | CP1 / CP2 / CP3 / CP4 | [system name] | [what signal fired] | NO — [reason] | 1 / 2 | NO / YES | S[N+1] |

Checkpoint: CP1=Entry Gate metric; CP2=Entry Gate failure pattern; CP3=Implementation; CP4=Close Gate.

## Session Notes

Append-only journal for session-internal context. Written via `sprint-tools note`.
Cleared at sprint close (archived to `Docs/Archive/session-notes-S<N>.md`).
PreCompact hook injects last 5 notes into context after compaction.

| # | Type | Item | Note | Time |
|---|------|------|------|------|

Types: `decision` | `attempt` | `side-effect` | `observation` | `artifact`
- **decision**: Approach chosen + why (e.g., "keyword matching over LLM — deterministic, zero cost")
- **attempt**: What was tried + outcome (e.g., "regex parser — too brittle for nested tables")
- **side-effect**: Unintended change noticed (e.g., "fixing parser also broke CSV export")
- **observation**: Context worth preserving (e.g., "PreCompact destroys ~60% of context")
- **artifact**: Pointer to long-form content in `Docs/Artifacts/` (auto-created by `sprint-tools note --artifact`)

## Change Log

[Sprint-scoped entries. Archived to Docs/Archive/ at sprint close.]

Tag significant entries for sprint index retrieval (see §Sprint Index Tagging below).

### Sprint [N]
- [date] [ID]: [what changed]
```

## 3. Sprint Index Tagging

Tag significant TRACKING.md entries with HTML comments for cross-sprint retrieval. The sprint index (`Docs/SPRINT-INDEX.md`) aggregates these tags.

**Tag format:**
```
<!-- topics:auth,api type:failure sprint:5 item:CORE-220 -->
```

**Fields:**
- `topics`: comma-separated domain areas. Use project-specific terms. Multiple topics when entry spans domains.
- `type`: `failure` | `decision` | `regression` | `baseline` | `guardrail`
- `sprint`: sprint number (integer)
- `item`: CORE-ID (optional for non-item entries)

**Tag when:**
1. Failure Mode History entries (type: `failure`)
2. User decisions at Entry Gate step 8 or mid-sprint scope changes (type: `decision`)
3. Regressions at Close Gate or CP1 (type: `regression`)
4. Performance baselines established/changed (type: `baseline`)
5. New guardrail rules via Update Rule (type: `guardrail`)

**Do NOT tag:** routine Change Log entries, status transitions, archive operations.

**Sprint Index format** (`Docs/SPRINT-INDEX.md`):
```markdown
# Sprint Index

Topic-first lookup for cross-sprint retrieval. Most recent entries first per topic.
Updated at Sprint Close step 7b. Source of truth: tagged entries in TRACKING.md.

## auth
- S8: regression CORE-340 (session invalidation) → G-015
- S5: failure CORE-220 (token expiry) → G-012

## perf
- S7: regression (API p95 +40ms) → fixed CORE-310
- S3: baseline established (API p95: 120ms)

## db
- S6: decision CORE-280 (connection pooling strategy — chose pgBouncer over app-level)
```

**Rules:**
1. One line per entry, newest first within each topic
2. Include CORE-ID, brief description, guardrail reference if applicable
3. Topics with no entries in last 5 sprints → archive to `Docs/Archive/sprint-index-archive.md`

## 4. CODING_GUARDRAILS.md Template

```markdown
# [Project Name] — Coding Guardrails

Engineering rules derived from real bugs and project-specific risk scans.
Review relevant sections BEFORE writing code.

## How to Read This File

Three-layer progressive disclosure — read only what you need:
1. **§Section Index** → find which sections apply to your task (always read)
2. **§TL;DR** per section → one-line rule + key risk (read for quick check)
3. **Full section** → WRONG/CORRECT examples + root cause (read when writing code in that area)

## Section Index — Read by Task Type

| Task | Read sections | Key Risk |
|------|---------------|----------|
| [task type 1] | §1, §2 | [primary risk] |
| [task type 2] | §1, §3 | [primary risk] |
| Sprint workflow | §Entry Gate, §Close Gate | process skip |
| Anti-pattern quick check | §Anti-Pattern Quick Reference | — |

*(Bootstrap step 6 populates this file. Sections below are created per-project —
not copied from a generic template. Each rule comes from scanning this specific codebase.)*

**Format rules (keep file scannable — target ≤800 lines):**
- Each rule: max 20 lines (title + one WRONG/CORRECT pair + root cause + scope + reference)
- Root cause: one sentence. Full story lives in sprint archive, not here.
- Code examples: one WRONG + one CORRECT per rule. Extra edge cases → inline comment, not extra blocks.
- No design justification in guardrails. "Why we keep this despite over-engineering" → DESIGN.md.
- Sprint Close step 7d checks file size and flags if >800 lines.
- Each section MUST have a TL;DR block (checked by sprint-audit.sh).

---

## 1. [Section Title — generated by bootstrap scan]

> **TL;DR:** [One-line rule summary] — **Applies to:** [file patterns or modules] — **Key risk:** [what breaks]

### 1.1 [Rule Title]

```[language]
# WRONG — [what the scan found in this project]
[actual anti-pattern from codebase, with real file reference]

# CORRECT
[fix]
```

- **Root cause:** [one sentence — why this rule exists]
- **Scope:** [which files/modules in this project]
- **Reference:** bootstrap scan / [sprint/bug ID]
```

## 5. Roadmap.md Template

```markdown
# [Project Name] — Roadmap

## Sprint Overview

| Sprint | Focus | Dependencies | Status |
|--------|-------|-------------|--------|
| S1 | [focus area] | — | planned |
| S2 | [focus area] | S1 | planned |

---

## Sprint 1 — [Title]

**Goal:** [One sentence describing what this sprint achieves]

**Must:** (complete all before sprint is "done")
- [ ] CORE-001: [item description]
- [ ] CORE-002: [item description]

**Should:** (if budget remains after Must)
- [ ] CORE-003: [item description]
- [ ] CORE-004: [item description]

**Could:** (stretch goals)
- [ ] CORE-005: [item description]

**Metric gates:**
- [metric name]: [threshold] (how measured)

**Dependencies:** [list or "none"]

---

## Sprint 2 — [Title]

[Same structure as Sprint 1]
```

**Checkbox notation:**
- `- [ ]` = not verified (open, in_progress, or fixed)
- `- [x]` = verified (TRACKING.md status = verified, gate evidence logged)
- `- [~]` = deferred (TRACKING.md status = deferred, reason documented inline)

**Checkbox rules:**
1. `[x]` ↔ `verified`, `[~]` ↔ `deferred`. All other statuses → `[ ]`
2. Intermediate states (in_progress, fixed-untested) NOT shown in roadmap
3. Checkbox format mandatory. Plain bullets (`- CORE-###: ...`) break close gate tracking
4. `sprint-audit.sh` Section 11 catches mismatches automatically

CRITICAL: Use these templates exactly during bootstrap. All templates contain required structure — do not omit sections.

</instructions>
