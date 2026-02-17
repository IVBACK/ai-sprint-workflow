# AI-Assisted Sprint Workflow Template

A project-agnostic sprint workflow designed for human + AI agent collaboration.
Copy this file into any project and follow the setup instructions.
The AI agent reads this document and bootstraps the project structure automatically.

---

## Quick Start — AI Agent Bootstrap

**When an AI agent encounters this file in a new project, execute these steps:**

1. Scan the project to determine: language, framework, build system, test framework
   *(Empty project? Skip to step 2 — Discovery Questions will cover language/framework.)*
2. Ask the Discovery Questions below (skip any already answered by project files)
3. Create the file structure listed in §Setup below (skip files that already exist)
4. If Roadmap.md is empty or has no sprint items, run Initial Planning:
   a. Ask user to describe project goal (1-3 sentences)
   b. Propose high-level phases (titles only, 3-6 phases)
   c. Detail Sprint 1 only: Must items with CORE-### IDs
      (later sprints stay as one-line sketches — they will be detailed when reached)
   d. Identify immutable contracts discovered during planning
      → feed into CLAUDE.md §Immutable Contracts
   e. Present plan to user for approval before proceeding
5. Populate CLAUDE.md with project-specific context discovered during scan + answers
6. Populate CODING_GUARDRAILS.md with framework-specific rules
7. Adapt `Tools/sprint-audit.sh`: uncomment checks for the detected language, set `SRC_DIR`, `TEST_DIR`, `EXT`
8. Move this file to `Docs/SPRINT_WORKFLOW.md` (it becomes the workflow reference; bootstrap steps are kept for future re-bootstrapping)
9. Confirm the setup with the user before writing any feature code

```
AI reads this file
       │
       ▼
┌──────────────────┐     ┌──────────────────┐
│ Scan project     │────►│ Detect:          │
│ (files, configs, │     │  - Language       │
│  build system)   │     │  - Framework      │
└──────────────────┘     │  - Test framework │
                         │  - Build tool     │
                         │  - VCS (git?)     │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Discovery Q's    │
                         │ (ask user)       │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Create structure: │
                         │  CLAUDE.md        │
                         │  TRACKING.md      │
                         │  GUARDRAILS.md    │
                         │  Roadmap.md       │
                         │  Tools/           │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Greenfield?      │
                         │ YES → plan S1    │
                         │  (detail S1 only,│
                         │   sketch rest)   │
                         │ NO → skip        │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Adapt audit script│
                         │ to detected lang  │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Move TEMPLATE.md │
                         │ → Docs/SPRINT_   │
                         │   WORKFLOW.md     │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Confirm with user │
                         └──────────────────┘
```

### Discovery Questions

Ask these before creating project files. Skip any that can be inferred from
existing project files (e.g., `package.json` reveals language + test framework).

**Project Shape:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 0 | Language and framework? | Audit script patterns, guardrail rules, test conventions | Auto-detect from project files; if empty project, ask explicitly |
| 1 | Solo developer or team? | Commit policy (monolithic vs atomic), review gate | Solo |
| 2 | Sprint scope size? (small: 3-5 items / medium: 5-8 / large: 8-12) | Entry gate scope check threshold, close gate frequency | Medium (5-8) |
| 3 | Is there an existing roadmap or task list? | Avoid creating duplicate planning docs | No → create Roadmap.md |
| 4 | Performance-sensitive project? (game, real-time, HFT) | Profiling rules, budget caps, hot path checks | No |
| 5 | Target platforms? (web, mobile, desktop, embedded) | Platform-specific guardrails | Desktop |

> **Note on sprint duration:** With AI-assisted development, calendar time is
> unreliable for scoping. A "1-week sprint" may complete in hours with an AI agent.
> Sprints are defined by **scope** (number of Must items + complexity), not by
> calendar time. The close gate runs when Must items are done, regardless of
> whether that took 2 hours or 2 weeks.

**Infrastructure:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 6 | CI/CD pipeline exists? (GitHub Actions, Jenkins, etc.) | Wire sprint-audit.sh into CI or keep manual | No → manual only |
| 7 | Test framework in use? (Jest, pytest, NUnit, etc.) | Test coverage gap check pattern | Auto-detect from config |
| 8 | Existing coding standards or linter config? | Avoid conflicting guardrails | No → start fresh |
| 9 | Any known tech debt or recurring bugs? | Seed initial guardrails from real issues | No → guardrails start empty |

**Workflow Preferences:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 10 | Language for docs and commit messages? | Consistency across project | English |
| 11 | Preferred commit style? (conventional, free-form) | Commit message format in rules | Free-form |
| 12 | Anything that must NEVER change? (API contracts, data formats) | Seed "Immutable Contracts" in CLAUDE.md | None → discover over time |
| 13 | Anything else the AI should know? (context, constraints, preferences not covered above) | Catch requirements that don't fit predefined categories | None |

**Rule: Ask all questions in a single batch. Do not drip-feed one at a time.**
If a question can be answered by scanning project files (e.g., `tsconfig.json`
exists → TypeScript, `jest` in `package.json` → Jest), state the inferred answer
and ask the user to confirm rather than asking from scratch.

---

## Setup — File Structure

Create these files at the project root. Each file has a specific role.
Do NOT merge them — separation enables focused reads and smaller context loads.

```
project-root/
├── CLAUDE.md                          # AI session context (auto-loaded)
├── TRACKING.md                        # Single source of truth for status
├── Docs/
│   ├── CODING_GUARDRAILS.md           # Engineering rules (never-again list)
│   ├── SPRINT_WORKFLOW.md             # This file (or project-specific copy)
│   ├── LESSONS_INDEX.md               # Bug → rule traceability
│   ├── Planning/
│   │   └── Roadmap.md                 # Sprint plan with Must/Should/Could
│   └── Archive/
│       └── changelog-S1-S2.md         # Archived sprint changelogs
└── Tools/
    └── sprint-audit.sh                # Automated close gate checks
```

### Why separate files?

```
┌─────────────────────────────────────────────────────────────┐
│ AI agent context window is finite.                          │
│                                                             │
│ Single mega-file = must read everything every session       │
│ Separated files  = read only what's needed per task         │
│                                                             │
│ CLAUDE.md   → always loaded (system prompt, ~100 lines)     │
│ TRACKING.md → loaded at session start (~50-100 lines)       │
│ GUARDRAILS  → loaded per-section via index (~20-40 lines)   │
│ Roadmap     → loaded per-sprint (~30-50 lines)              │
│                                                             │
│ Total per session: ~200-300 lines vs ~2000+ in single file  │
└─────────────────────────────────────────────────────────────┘
```

---

## File Templates

### CLAUDE.md Template

```markdown
# [Project Name] — AI Session Context

This file provides quick context for every AI session.

## Document Contract

- `TRACKING.md`: single source of truth for item status (ID-###, open/fixed/verified).
- `Docs/Planning/Roadmap.md`: sprint plan (Must/Should/Could per sprint).
- `Docs/CODING_GUARDRAILS.md`: engineering rules (check before writing code).
- `Docs/SPRINT_WORKFLOW.md`: sprint lifecycle (Entry Gate, Close Gate, Sprint Close) — read at sprint boundaries.
- `Docs/LESSONS_INDEX.md`: RuleID → root cause → target file mapping.
- `CLAUDE.md` (this file): operational rules + checkpoint summary.

Rule: Bug and sprint status is NOT duplicated here; only short references.

## Project Summary

[One paragraph: language, framework, architecture, target platform, key goals]

## Immutable Contracts

[List things that MUST NOT change without explicit architectural revision]
- [Data format: ...]
- [API contract: ...]
- [Convention: ...]
- [Build target: ...]

## Operational Rules

- Update `TRACKING.md` after every significant fix/decision.
- `fixed → verified` transition requires evidence (test run ID + results).
- Check `Docs/CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Sprint close gate:
  - Run `Tools/sprint-audit.sh` (automated scan).
  - Manual review (see `CODING_GUARDRAILS.md` §Close Gate).
- All code, comments, commit messages in [English/language].
- Commit policy: atomic commits preferred (one logical change per commit).

## Last Checkpoint

- Date: [YYYY-MM-DD]
- Active focus: [Sprint N status]
- Status: [Key items completed]
- Next step: [What's next]

## Quick Start

New session sequence:
1. `TRACKING.md` → Current Focus + Sprint Board + Blockers
2. `Docs/Planning/Roadmap.md` → active sprint section

Sprint start (new sprint transition):
- `Docs/SPRINT_WORKFLOW.md` §Entry Gate (3 phases, 12 steps) — read and execute. No code before plan is confirmed.

Sprint close:
- `Docs/SPRINT_WORKFLOW.md` §Close Gate (5 phases) + §Sprint Close — read and execute.

Before writing code:
- `Docs/CODING_GUARDRAILS.md` → Section Index → relevant sections only
```

### TRACKING.md Template

```markdown
# [Project Name] — Tracking

## Current Focus
Sprint [N]: [one-line description]

## Sprint Board

| ID | Summary | Status | Sprint | Evidence |
|----|---------|--------|--------|----------|
| CORE-001 | [description] | open | S1 | |
| CORE-002 | [description] | fixed | S1 | |
| CORE-003 | [description] | verified | S1 | RUN-001 |

Status values: `open` → `fixed` → `verified`

## Open Risks / Blockers

| ID | Risk | Mitigation | Sprint |
|----|------|------------|--------|
| R-001 | [description] | [plan] | S1 |

## Change Log

[Sprint-scoped entries. Archived to Docs/Archive/ at sprint close.]

### Sprint [N]
- [date] [ID]: [what changed]
```

### CODING_GUARDRAILS.md Template

```markdown
# [Project Name] — Coding Guardrails

Engineering rules derived from real bugs. Review before writing code.

## Section Index — Read by Task Type

| Task | Read sections |
|------|---------------|
| [task type 1] | §1, §2 |
| [task type 2] | §1, §3 |
| Sprint workflow | §Entry Gate, §Close Gate |
| Anti-pattern quick check | §Anti-Patterns |

---

## 1. [Domain-Specific Rules]

### 1.1 [Rule Title]

[Code example: WRONG vs CORRECT]

- **Root cause:** [why this rule exists]
- **Scope:** [where it applies]
- **Reference:** [sprint/bug ID]

---

## Entry Gate — Pre-Sprint Review

Before writing code for a new sprint:

**Phase 1 — State Review (read-only):**
1. Read TRACKING.md → open items, blockers
2. Read Roadmap → Must/Should/Could for this sprint
3. Check deferred items from previous sprints
4. Identify applicable GUARDRAILS sections

**Phase 2 — Dependency Verification (read-only):**
*(Sprint 1: skip this phase — no prior sprints exist.)*
5. Verify dependency sprints are closed + verified
6. Read dependency API source files, confirm contracts match
7. List open architectural decisions

**Phase 3 — Strategic Validation & Confirmation:**
8. Strategic alignment check — for each Must item:
   a. Still relevant? (superseded, already delivered?)
   b. Goal alignment? (does it serve core project goals?)
   c. Approach still valid? (has new info invalidated the method?)
   d. Metrics still appropriate? (measuring the right thing?)
   If any fails → flag to user with evidence + options (keep/modify/defer/remove).
   AI does not unilaterally change sprint scope — user decides.
9. Verification plan:
   a. Can all metrics be measured by sprint end?
   b. For each item: how will behavior be verified? (unit test / integration test / manual + screenshot)
      Algorithmic items: what invariants must hold? (mathematical properties, reference output, determinism)
      "It runs" ≠ "it is correct".
   c. Item has no metric gate? Propose one and add to roadmap. User approves before sprint starts.
10. Is scope realistic? (<=8 Must items)
11. Produce dependency-ordered implementation list
12. Present plan to user for approval

---

## Close Gate — Sprint-End Audit

**Phase 0 — Metric gate check:**
- Can each metric be measured? Evidence exists?

**Phase 1a — Automated scan:**
- Run `Tools/sprint-audit.sh`
- Review findings, fix or forward-note each

**Phase 1b — Manual audit:**
1. Memory/resource leaks
2. Unnecessary allocations in hot paths
3. O(n) → O(1) opportunities
4. Missing null/bounds guards
5. Duplicate logic
6. Missing observability (logging, profiling)
7. Dead code and orphan scaffolding
8. Debug path parity with production

**Phase 2 — Fix:**
- Fix immediately or log with target sprint

**Phase 3 — Regression test:**
- All tests must PASS after fixes

**Phase 4 — Test coverage gap:**
- 4a. File-level: new/modified code → matching test file exists?
- 4b. Item-level: every completed item (Must+Should+Could) → behavioral test exists?
  Log item → test mapping in TRACKING.md evidence. No test → write one or document why untestable.
- Final test run PASS

---

## Anti-Pattern Quick Reference

| # | Anti-Pattern | Correct Approach | Ref |
|---|-------------|-----------------|-----|
| 1 | [pattern] | [correct] | §X.Y |

---

## Update Rule

1. Identify root cause of bug
2. Add rule to relevant section
3. Add to anti-pattern table
4. Reference in code comment
```

### Roadmap.md Template

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

**Could:** (stretch goals)
- [ ] CORE-004: [item description]

**Metric gates:**
- [metric name]: [threshold] (how measured)

**Dependencies:** [list or "none"]

---

## Sprint 2 — [Title]

[Same structure as Sprint 1]
```

Checkbox notation:
- `- [ ]` = not started
- `- [x]` = done + verified (evidence in TRACKING.md)
- `- [~]` = skipped / deferred (reason documented inline)

### LESSONS_INDEX.md Template

```markdown
# [Project Name] — Lessons Index

Maps bug root causes to guardrail rules. Grows as bugs are found and fixed.

| RuleID | Root Cause | Guardrail Section | Sprint | Source |
|--------|-----------|-------------------|--------|--------|
| G-001 | [what went wrong] | §1.1 | S1 | CORE-001 |

This file starts empty on new projects. Add entries when:
1. A bug is fixed and a guardrail rule is created
2. A known anti-pattern from a previous project is imported
```

---

## Sprint Workflow — Complete Flow

```
╔══════════════════════════════════════════════════════════════════╗
║                      SPRINT LIFECYCLE                           ║
╚══════════════════════════════════════════════════════════════════╝

                    ┌──────────────┐
                    │  SPRINT N-1  │
                    │  COMPLETED   │
                    └──────┬───────┘
                           │
           ════════════════╪════════════════
                    ENTRY GATE
           ════════════════╪════════════════
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1 — State & Context Review (read-only)                   │
│                                                                 │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐  ┌──────────────┐  │
│  │TRACKING │  │ Roadmap  │  │  Deferred  │  │  Guardrails  │  │
│  │  .md    │  │ sprint N │  │  items     │  │  §Index      │  │
│  └────┬────┘  └────┬─────┘  └─────┬──────┘  └──────┬───────┘  │
│       └────────────┴──────────────┴─────────────────┘          │
│                            │                                    │
│                     "What exists now?"                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2 — Dependency & API Verification (read-only)            │
│  (Sprint 1: skip — no prior sprints exist)                      │
│                                                                 │
│  ┌────────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ Dep sprints    │  │ API source   │  │ Open decisions     │  │
│  │ closed?        │  │ files match? │  │ (arch choices)     │  │
│  └────────────────┘  └──────────────┘  └────────────────────┘  │
│                                                                 │
│                     "Can we build on this?"                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3 — Strategic Validation & Confirmation                  │
│                                                                 │
│  For each Must item, 4-question check:                          │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌─────────────────┐  │
│  │ Still    │ │ Goal      │ │ Approach │ │ Metrics still   │  │
│  │ relevant?│ │ aligned?  │ │ valid?   │ │ appropriate?    │  │
│  └──────────┘ └───────────┘ └──────────┘ └─────────────────┘  │
│                                                                 │
│  Then:                                                          │
│  ┌───────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐  │
│  │ Verif.    │ │ Scope    │ │ Impl.    │ │ Present plan   │  │
│  │ plan      │ │ check    │ │ order    │ │ → confirm      │  │
│  └───────────┘ └──────────┘ └──────────┘ └────────────────┘  │
│                                                                 │
│                "Should we build this, this way?"                │
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │ Any check fails?            │
              │  YES → flag to user with    │
              │        evidence + options,  │
              │        user decides action  │
              │  NO  → proceed              │
              └──────────────┬──────────────┘
                             │
           ══════════════════╪═══════════════
                  IMPLEMENTATION LOOP
           ══════════════════╪═══════════════
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  For each Must item (dependency order):                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                         │   │
│  │  A. Pre-code check                                      │   │
│  │     Read guardrails sections relevant to task type       │   │
│  │                        │                                │   │
│  │                        ▼                                │   │
│  │  B. Write code                                          │   │
│  │     Follow guardrails + immutable contracts             │   │
│  │                        │                                │   │
│  │                        ▼                                │   │
│  │  C. Self-verify (5-point checklist)                     │   │
│  │     ┌──────────────────────────────────────────────┐    │   │
│  │     │ □ Compiles?                                  │    │   │
│  │     │ □ Matches spec?                              │    │   │
│  │     │ □ No duplication?                            │    │   │
│  │     │ □ Follows conventions?                       │    │   │
│  │     │ □ Tech debt? → fix now or document           │    │   │
│  │     └──────────────────────────────────────────────┘    │   │
│  │                        │                                │   │
│  │              ┌─────────┴─────────┐                      │   │
│  │              │ All pass?         │                      │   │
│  │              │  NO → fix, recheck│                      │   │
│  │              │  YES ↓            │                      │   │
│  │              └───────────────────┘                      │   │
│  │                        │                                │   │
│  │                        ▼                                │   │
│  │  D. Write tests                                         │   │
│  │     ┌────────────────────────────────────────────┐      │   │
│  │     │ Unit-testable logic ────► Unit test        │      │   │
│  │     │ Integration/async ──────► Integration test │      │   │
│  │     │ Visual/UI ──────────────► Manual + screenshot│    │   │
│  │     └────────────────────────────────────────────┘      │   │
│  │                        │                                │   │
│  │                        ▼                                │   │
│  │  E. Update TRACKING.md                                  │   │
│  │     Mark item fixed, log decisions                      │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                             │                                   │
│                    ┌────────┴────────┐                           │
│                    │ All Must done?  │                           │
│                    │  NO → next item │────► loop back            │
│                    │  YES ↓          │                           │
│                    └─────────────────┘                           │
│                             │                                   │
│                    ┌────────┴────────┐                           │
│                    │ Budget left?    │                           │
│                    │ (scope items    │                           │
│                    │  remaining in   │                           │
│                    │  sprint plan)   │                           │
│                    │  YES → Should/  │────► same loop            │
│                    │        Could    │                           │
│                    │  NO → close     │                           │
│                    └─────────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
                             │
           ══════════════════╪═══════════════
                     CLOSE GATE
           ══════════════════╪═══════════════
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 0 — Metric Gate Sufficiency                              │
│                                                                 │
│  For each sprint metric:                                        │
│  □ Measurable with current infrastructure?                      │
│  □ Test evidence sufficient?                                    │
│  □ Threshold reasonable for current scale?                      │
│                                                                 │
│  FAIL: unmeasurable + no evidence → fix scope                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1a — Automated Scan                                      │
│                                                                 │
│  Run: Tools/sprint-audit.sh                                     │
│                                                                 │
│  Checks (adapt per project):                                    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  1. Scaffolding tags (// TEMP, // TODO, // HACK)          │ │
│  │  2. Observability coverage (logging/profiling in key ops) │ │
│  │  3. Hot path allocations (new T[] in loops/update)        │ │
│  │  4. Cached reference violations (repeated lookups)        │ │
│  │  5. Framework anti-patterns (language/framework-specific) │ │
│  │  6. Resource guard (close/dispose/cleanup missing)        │ │
│  │  7. Contract violations (project-specific forbidden API)  │ │
│  │  8. String allocation in hot paths                        │ │
│  │  9. Test coverage gap (source file ↔ test file match)     │ │
│  │ 10. API parity (same config set at all call sites)        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Output: WARN candidates — review each, fix or mark FP         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1b — Manual Audit (semantic, script can't catch)         │
│                                                                 │
│  Read each modified file:                                       │
│  1. Resource/memory leaks                                       │
│  2. Unnecessary allocations in hot paths                        │
│  3. O(n) → O(1) opportunities                                   │
│  4. Missing guards (null, bounds, state validation)             │
│  5. Duplicate logic (single source of truth violations)         │
│  6. Missing observability (logging, metrics, profiling)         │
│  7. Dead code (unused, orphan scaffolding, output-discarded)    │
│  8. Debug/test path parity with production                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2 — Fix                                                  │
│  Fix immediately OR log with target sprint (forward note)       │
│                                                                 │
│  PHASE 3 — Regression Test                                      │
│  All tests PASS after Phase 2 fixes                             │
│                                                                 │
│  PHASE 4 — Test Coverage Gap                                    │
│  4a. File-level: new/modified code → test file exists?          │
│  4b. Item-level: every completed item → behavioral test exists? │
│      Log: ID → test name(s) in TRACKING.md evidence             │
│  Final test run PASS.                                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │ All phases pass?            │
              │  NO  → fix, re-run          │
              │  YES → sprint close         │
              └──────────────┬──────────────┘
                             │
           ══════════════════╪═══════════════
                    SPRINT CLOSE
           ══════════════════╪═══════════════
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. Roadmap checkmarks                                          │
│     [x] done + verified    [~] skipped + reason                 │
│                                                                 │
│  2. TRACKING.md update                                          │
│     Sprint board: all Must verified with evidence               │
│                                                                 │
│  3. CLAUDE.md checkpoint update                                 │
│     Date, status, next sprint focus                             │
│                                                                 │
│  4. Changelog archive                                           │
│     Move entries to Docs/Archive/changelog-S<N>.md              │
│                                                                 │
│  5. Performance baseline capture (if applicable)                │
│     Record key metrics to TRACKING.md, compare vs previous      │
│     sprint. Flag regressions. Skip metrics not yet measurable.  │
│                                                                 │
│  6. Sprint "done" ──────────► next sprint Entry Gate            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Generic sprint-audit.sh Template

Adapt this script to any language/framework. Replace grep patterns with
project-specific equivalents.

```bash
#!/usr/bin/env bash
set -euo pipefail

# sprint-audit.sh — Automated sprint close gate checks
# Adapt the patterns below to your project's language and framework.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/src"         # ← adjust to your source directory
TEST_DIR="$ROOT/tests"      # ← adjust to your test directory

total=0

check() {
  local name="$1" pattern="$2" dir="${3:-$SRC_DIR}"
  local results count
  results=$(grep -rn "$pattern" --include="*.${EXT:-*}" "$dir" 2>/dev/null || true)
  count=$(echo "$results" | grep -c . 2>/dev/null || echo 0)
  if [[ $count -gt 0 ]]; then
    echo "WARN  $name — $count finding(s):"
    echo "$results" | head -20
    total=$((total + count))
  else
    echo "PASS  $name"
  fi
}

# ── Adapt these checks to your project ──

# 1. Scaffolding tags (language-agnostic: no comment prefix needed)
check "TEMP_TAGS" "TODO\|HACK\|FIXME\|TEMP(S"

# 2. Hot path allocations (example: Java/C#/TypeScript)
# check "HOT_ALLOC" "new ArrayList\|new HashMap\|new List<"

# 3. Cached reference violations
# check "UNCACHED" "getElementById\|querySelector" # web
# check "UNCACHED" "GetComponent\|Camera.main"      # Unity

# 4. Framework anti-patterns
# check "ANTIPATTERN" "dangerouslySetInnerHTML"     # React
# check "ANTIPATTERN" "AppendStructuredBuffer"      # Unity compute

# 5. Resource guard
# check "RESOURCE" "new FileStream\|new SqlConnection" # check for using/dispose

# 6. Test coverage gap
echo ""
echo "TEST COVERAGE:"
missing=0
while IFS= read -r f; do
  base=$(basename "$f" ".${f##*.}")
  if ! find "$TEST_DIR" -name "${base}*test*" -o -name "${base}*spec*" \
       -o -name "test_${base}*" -o -name "*${base}Test*" 2>/dev/null | grep -q .; then
    echo "  NO TEST: $base"
    missing=$((missing + 1))
  fi
done < <(find "$SRC_DIR" -name "*.${EXT:-*}" -not -path "*/test*" 2>/dev/null)
total=$((total + missing))

# ── Summary ──
echo ""
if [[ $total -eq 0 ]]; then
  echo "Sprint audit CLEAN — 0 findings."
  exit 0
else
  echo "Sprint audit: $total finding(s) — review needed."
  exit 1
fi
```

### Language-Specific Pattern Examples

| Language | Hot Path Alloc | Cached Ref | Anti-Pattern |
|----------|---------------|-----------|-------------|
| **C#/Unity** | `new List<`, `new Dictionary<` | `Camera.main`, `GetComponent` | `AppendStructuredBuffer`, `SetFloats` |
| **TypeScript/React** | `new Array(`, `[...spread]` in render | `document.querySelector` in loop | `dangerouslySetInnerHTML`, `any` type |
| **Python** | list comprehension in hot loop | repeated `os.path.exists` | `eval()`, `exec()`, bare `except:` |
| **Java** | `new ArrayList<>` in loop | repeated `getBean()` | `e.printStackTrace()`, raw types |
| **Go** | `append` in tight loop (pre-alloc) | repeated `os.Getenv` | `panic()` in library code, `interface{}` |
| **Rust** | `.clone()` in hot path | repeated `.unwrap()` | `unsafe` without comment, `.expect("")` |
| **C++** | `new`/`malloc` in loop | repeated `dynamic_cast` | raw `new` without smart pointer |

---

## AI Agent Operational Rules

These rules govern how an AI agent interacts with this workflow.

### Session Start Protocol

```
1. CLAUDE.md is auto-loaded (contains checkpoint + contracts)
2. Read TRACKING.md → understand current state
3. Read Roadmap → understand current sprint scope
4. If new sprint: run Entry Gate (full 3-phase, 12-step)
5. If mid-sprint: resume from TRACKING.md open items
```

### During Implementation

```
- Read guardrails BEFORE writing code (not after)
- Self-verify EVERY code block (5-point checklist)
- Update TRACKING.md after every significant change
- Never skip self-verification to "save time"
```

### Context Window Management

```
┌─────────────────────────────────────────────────────────┐
│ AI context is finite. Optimize what you load.           │
│                                                         │
│ DO:                                                     │
│   Read CLAUDE.md (always, it's the system prompt)       │
│   Read TRACKING.md (once, at session start)             │
│   Read Guardrails §Index → only relevant sections       │
│   Run sprint-audit.sh → read 30-line report             │
│   Read only flagged files for deep review               │
│                                                         │
│ DON'T:                                                  │
│   Read all guardrails every session                     │
│   Read every source file for mechanical checks          │
│   Duplicate information across documents                │
│   Store detailed tech notes in CLAUDE.md                │
└─────────────────────────────────────────────────────────┘
```

### Guardrail Evolution

```
Bug discovered
      │
      ▼
┌──────────────┐     ┌────────────────────┐
│ Fix the bug  │────►│ Add guardrail rule │
└──────────────┘     │ (never-again)      │
                     └────────┬───────────┘
                              │
                              ▼
                     ┌────────────────────┐
                     │ Add to anti-pattern│
                     │ quick-ref table    │
                     └────────┬───────────┘
                              │
                              ▼
                     ┌────────────────────┐
                     │ Update sprint-audit│
                     │ if grep-detectable │
                     └────────────────────┘

Guardrails grow organically from real bugs.
Never add hypothetical rules — only rules from production experience.
```

---

## State Transitions

### Item Lifecycle

```
  open ──── implementation done ────► fixed ──── test evidence ────► verified
                                       │                               │
                                       │ (no evidence provided)        │
                                       └── stays fixed (blocks close) ─┘
```

### Sprint Lifecycle

```
  planned → entry gate PASS → in progress → Must done → close gate PASS → done
                │                                            │
                │ (fail)                                     │ (fail)
                └── flag to user, user decides              └── fix, re-run
```

### Document Update Triggers

```
┌──────────────────┬────────────────────────────────────────┐
│ Event            │ Update                                 │
├──────────────────┼────────────────────────────────────────┤
│ Bug fixed        │ TRACKING.md (status → fixed)           │
│ Bug verified     │ TRACKING.md (status → verified + evidence) │
│ New rule found   │ GUARDRAILS.md (rule + anti-pattern)    │
│ Sprint starts    │ TRACKING.md (Current Focus)            │
│ Sprint closes    │ Roadmap (checkmarks), CLAUDE.md (checkpoint) │
│ Sprint archived  │ Docs/Archive/changelog-S<N>.md         │
│ Decision made    │ TRACKING.md (change log)               │
│ Tech debt found  │ TRACKING.md (new ID, forward note)     │
└──────────────────┴────────────────────────────────────────┘
```

---

## Checklist — Is Your Project Set Up?

Use this checklist when bootstrapping a new project:

```
□ CLAUDE.md exists with:
    □ Project summary (1 paragraph)
    □ Immutable contracts (things that don't change)
    □ Operational rules
    □ Last checkpoint
    □ Quick start sequence

□ TRACKING.md exists with:
    □ Current Focus section
    □ Sprint Board table (ID, summary, status, sprint, evidence)
    □ Open Risks / Blockers table
    □ Change Log section

□ Docs/CODING_GUARDRAILS.md exists with:
    □ Section Index (task type → sections to read)
    □ At least one real rule (from first bug found)
    □ Entry Gate procedure
    □ Close Gate procedure
    □ Anti-pattern quick reference table

□ Docs/Planning/Roadmap.md exists with:
    □ Sprint list with Must/Should/Could per sprint
    □ Dependencies between sprints noted

□ Tools/sprint-audit.sh exists and is:
    □ Executable (chmod +x)
    □ Adapted to project language/framework
    □ Has at least: scaffolding tags, test coverage gap checks

□ .gitignore includes:
    □ AI-generated analysis reports (session artifacts)
    □ Build artifacts, IDE files
```

---

## Adaptation Guide

### Small Project (1-5 files)

Skip: Entry Gate Phase 2 (no dependencies), sprint-audit.sh (too few files).
Keep: Self-verification loop, close gate manual audit, TRACKING.md.

### Medium Project (5-50 files)

Use full workflow. Sprint-audit.sh becomes valuable at ~10+ source files.
Guardrails will naturally grow to 10-20 rules.

### Large Project (50+ files, multiple contributors)

Add: strict atomic commits (no monolithic allowed), code review gate,
CI integration for sprint-audit.sh and ci-guardrail-check.sh.
Consider: separate guardrails per subsystem (linked from main index).

### Solo vs Team

| Aspect | Solo | Team |
|--------|------|------|
| Commits | Monolithic OK (with TRACKING traceability) | Atomic required |
| Review | Self-verify + AI agent | Peer review + AI agent |
| Entry Gate | Abbreviated (Phase 1 + 3) | Full (all 3 phases) |
| Close Gate | Full (quality is non-negotiable) | Full + peer sign-off |
