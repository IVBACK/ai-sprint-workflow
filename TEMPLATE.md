# AI-Assisted Sprint Workflow Template

A project-agnostic sprint workflow designed for human + AI agent collaboration.
Copy this file into any project and follow the setup instructions.
The AI agent reads this document and bootstraps the project structure automatically.

---

## Quick Start — AI Agent Bootstrap

**When an AI agent encounters this file in a new project, execute these steps:**

1. Scan the project to determine: language, framework, build system, test framework
   *(Empty project? Skip to step 2 — Discovery Questions will cover language/framework.)*
   *(Large project (100+ files)? Limit scan to root configs, top-level directories, and up to 50 source files. Infer stack from config files (`package.json`, `Cargo.toml`, `pom.xml`, etc.) — do not read every file.)*
2. Ask the Discovery Questions below (skip any already answered by project files)
3. Create the file structure listed in §Setup below (skip files that already exist)
4. If Roadmap.md is empty or has no sprint items, run Initial Planning:
   a. Ask user to describe project goal (1-3 sentences).
      If goal is too vague to decompose (e.g., "make something cool"), ask follow-up:
      "What problem does this solve?" / "Who is the user?" / "What is the core interaction?"
      Minimum viable goal: a subject ("who"), an action ("does what"), and a constraint ("using/for").
   b. Propose high-level phases (titles only, 3-6 phases)
      Each phase should be: independently deliverable (something works at the end),
      user-visible or measurably different from the previous phase, and roughly similar in scope.
      If a phase only "prepares" for the next with nothing to show → merge or split differently.
   c. Detail Sprint 1 only: Must/Should/Could items with CORE-### IDs
      (later sprints stay as one-line sketches — they will be detailed when reached)
      Must/Should/Could criteria:
      - Must: without this item, the sprint goal is not met. Sprint does not close without it.
      - Should: improves quality or completeness, but sprint ships without it if time runs out.
      - Could: nice to have, first to drop. No Must item depends on it.
      Item granularity rule: if an item needs more than one focused session to implement,
      consider splitting. If two items are meaningless without each other, consider merging.
   d. Identify immutable contracts discovered during planning
      → feed into CLAUDE.md §Immutable Contracts
      *(Greenfield/early project with no clear contracts yet? Write "None identified yet — to be discovered during Sprint 1." This is valid. Do not invent artificial contracts.)*
   e. Present plan to user for approval before proceeding
5. Populate CLAUDE.md with project-specific context discovered during scan + answers
6. Populate CODING_GUARDRAILS.md with framework-specific rules
7. Adapt `Tools/sprint-audit.sh`: uncomment checks for the detected language, set `SRC_DIR`, `TEST_DIR`, `EXT`
   *(Multi-language project? Set `EXT` to the primary language. Add secondary language checks as additional `check` calls with explicit `--include` patterns. Use separate `SRC_DIR_*` variables if source trees differ.)*
8. Create `Docs/SPRINT_WORKFLOW.md` from this file:
   - Copy this file to `Docs/SPRINT_WORKFLOW.md`
   - Strip these bootstrap-only sections (no longer needed after setup):
     • "Quick Start — AI Agent Bootstrap" (including Discovery Questions)
     • "File Templates" (all sub-templates — real files already exist)
     • "Generic sprint-audit.sh Template" (already copied to Tools/)
     • "Checklist — Is Your Project Set Up?"
   - Keep everything else (Setup, Complete Flow, Entry/Close Gate, Sprint Close, Operational Rules, etc.)
   - Result: ~550 lines (lean workflow reference) instead of ~1400 lines (full template)
   - Need to re-bootstrap later? Re-download the original TEMPLATE.md.
9. Confirm the setup with the user before writing any feature code
   Present a brief summary: files created, Sprint 1 scope (Must items), and next step.
   Format: "Bootstrap complete. Here's what was set up: [file list]. Sprint 1 has [N] Must items: [titles].
   Ready to run Entry Gate for Sprint 1 — shall I proceed?"
   Do NOT silently start Entry Gate. Wait for explicit user confirmation.

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
                         │ TEMPLATE.md →    │
                         │ SPRINT_WORKFLOW  │
                         │ (strip bootstrap)│
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
| 0 | Language and framework? ¹ | Audit script, guardrails, test conventions | Auto-detect; empty project → ask explicitly ¹ |
| 1 | Solo developer or team? | Commit policy, review gate | Solo |
| 2 | Sprint scope size? (small: 3-5 / medium: 5-8 / large: 8-12) — an item = one deliverable behavior (a feature, a fix, a refactor), not a subtask ² | Entry gate scope threshold | Medium (5-8) |
| 3 | Existing roadmap or task list? (No / Yes / Scattered) ³ | Avoid duplicate planning docs | No → create Roadmap.md; Yes → validate format, convert to Must/Should/Could if needed ³ |
| 4 | Performance-sensitive? (game, real-time, HFT) | Profiling rules, hot path checks | No |
| 5 | Target platforms? (web, mobile, desktop, embedded) | Platform-specific guardrails | Desktop |

> ¹ **Q0 details:** Multi-language projects: list primary + secondary. If user is undecided,
> propose 2-3 options with trade-offs and let user choose. Do not proceed without a language
> decision — it gates audit script, guardrails, and test setup.
>
> ² **Q2 details:** An "item" = one deliverable behavior (a feature, a fix, a refactor).
> Not a subtask or a line of code.
>
> ³ **Q3 details:** "Scattered" (across GitHub Issues, Notion, etc.) → AI extracts items
> from user-provided source, converts to Must/Should/Could format in Roadmap.md, user confirms.

> **Note on sprint duration:** With AI-assisted development, calendar time is
> unreliable for scoping. A "1-week sprint" may complete in hours with an AI agent.
> Sprints are defined by **scope** (number of Must items + complexity), not by
> calendar time. The close gate runs when Must items are done, regardless of
> whether that took 2 hours or 2 weeks.

**Infrastructure:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 6 | CI/CD pipeline exists? (GitHub Actions, Jenkins, etc.) | Wire sprint-audit.sh into CI or keep manual | No → manual only |
| 7 | Test framework in use? (Jest, pytest, NUnit, etc.) ⁴ | Test coverage gap check pattern | Auto-detect from config ⁴ |
| 8 | Existing coding standards or linter config? | Avoid conflicting guardrails | No → start fresh |
| 9 | Any known tech debt or recurring bugs? | Seed initial guardrails from real issues | No → guardrails start empty |

> ⁴ **Q7 details:** If none detected and none specified → ask user: "Set up [recommended
> framework for detected language] now, or defer testing to Sprint 2?" If deferred: Close
> Gate Phase 4 logs "no test framework" as known gap with target sprint.

> **VCS auto-detect:** Scan for `.git`, `.svn`, `.hg` at project root.
> Record result as `VCS: git | svn | none` in CLAUDE.md §Project Summary.
> If VCS=none: skip Q11 (commit style); Phase 1b uses Entry Gate notes
> instead of `git diff`; TRACKING.md recovery falls back to user verification.

**Workflow Preferences:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 10 | Language for docs and commit messages? | Consistency across project | English |
| 11 | Preferred commit style? (conventional, free-form) ⁵ | Commit message format in rules | Free-form — **skip if VCS=none** |
| 12 | Anything that must NEVER change? (API contracts, data formats) | Seed "Immutable Contracts" in CLAUDE.md | None → discover during implementation ⁶ |
| 13 | Anything else the AI should know? (e.g., recurring pain points, integration constraints, team conventions, things that burned you before) | Catch requirements not covered above | None |
| 14 | What is this project's #1 non-negotiable quality axis? (security / performance / reliability / correctness / other: ...) | Sets Critical Axis — findings in this category can never be silently deferred | Infer from domain: payment/auth → security; game/realtime → performance; medical/finance → correctness |

> ⁵ **Q11 details:** Only ask if VCS≠none. If VCS=none, skip entirely — no commits exist.
>
> ⁶ **Q12 details:** "None identified yet — to be discovered during implementation" is valid
> for greenfield projects. Do not invent artificial contracts.

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
│   │   ├── Roadmap.md                 # Sprint plan with Must/Should/Could
│   │   └── S<N>_ENTRY_GATE.md         # Entry Gate report (temporary, deleted at Sprint Close)
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

- `TRACKING.md`: single source of truth for item status (ID-###, open/in_progress/fixed/verified; special: deferred, blocked).
- `Docs/Planning/Roadmap.md`: sprint plan (Must/Should/Could per sprint).
- `Docs/CODING_GUARDRAILS.md`: engineering rules (check before writing code).
- `Docs/SPRINT_WORKFLOW.md`: sprint lifecycle (Entry Gate, Close Gate, Sprint Close) — read at sprint boundaries.
- `Docs/LESSONS_INDEX.md`: RuleID → root cause → target file mapping.
- `CLAUDE.md` (this file): operational rules + checkpoint summary.

Rule: Bug and sprint status is NOT duplicated here; only short references.

## Project Summary

[One paragraph: language, framework, architecture, target platform, key goals]
VCS: [git | svn | none]
Critical Axis: [security | performance | reliability | correctness | other: ...]

## Immutable Contracts

[List things that MUST NOT change without explicit architectural revision]
- [Data format: ...]
- [API contract: ...]
- [Convention: ...]
- [Build target: ...]

## Operational Rules

- Update `TRACKING.md` after every significant fix/decision.
- `fixed → verified` transition requires evidence (test output or pass confirmation). Full flow: open → in_progress → fixed → verified.
- Check `Docs/CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Roadmap checkbox `[x]` only when item is `verified` in TRACKING.md. `[~]` only when `deferred`. Intermediate states (in_progress, fixed-untested) are not shown in roadmap — TRACKING.md is the single source. `sprint-audit.sh` Section 11 catches mismatches automatically.
- Sprint close gate:
  - Run `Tools/sprint-audit.sh` (automated scan, 12 sections).
  - Manual review (see `CODING_GUARDRAILS.md` §Close Gate).
- All code, comments in [English/language].
- Commit policy (if VCS in use): atomic commits preferred (one logical change per commit); commit messages in [English/language]. If VCS=none: skip.

## Last Checkpoint

- Date: [YYYY-MM-DD]
- Active focus: [Sprint N status]
- Status: [Key items completed]
- Next step: [What's next]

## Quick Start

New session sequence:
1. `TRACKING.md` → Current Focus + Sprint Board + Blockers
2. `Docs/Planning/Roadmap.md` → active sprint section
→ Then tell the AI: **"Continue sprint N"** or **"Resume"** — AI runs Session Start Protocol automatically.

Sprint start (new sprint transition):
- `Docs/SPRINT_WORKFLOW.md` §Entry Gate (phases 0-3, 12 steps) — read and execute. No code before plan is confirmed.

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
| CORE-002 | [description] | in_progress | S1 | |
| CORE-003 | [description] | fixed | S1 | |
| CORE-004 | [description] | verified | S1 | RUN-001 |
| CORE-005 | [description] | deferred | S1 | reason: [why] → target S2 |

Status values: `open` → `in_progress` → `fixed` → `verified`
Special statuses:
- `deferred`: item intentionally skipped (maps to roadmap `[~]`). Requires reason + target sprint.
- `blocked`: item cannot proceed due to external dependency. Requires linked blocker in §Open Risks.
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

| Sprint | Category | Predicted? | Detection | Mode | Impact | Root Cause | Guardrail | Escalate? |
|--------|----------|------------|-----------|------|--------|------------|-----------|-----------|

## Failure Encounters — Current Sprint

Log failures as they are discovered during implementation (bugs, test failures, unexpected behavior).
Sprint Close step 7a reads this for retrospective comparison. Replace at each new sprint.

| Item | Category | Failure Description | Detection | Date |
|------|----------|-------------------|-----------|------|

Category: direct / interaction / stress-edge.
Detection: test / user-visual / profiler / code-review.

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
| Anti-pattern quick check | §Anti-Pattern Quick Reference |

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

**Abbreviated mode** (≤3 Must items AND no cross-sprint dependencies):
Run: Phase 0 (if needed) → steps 1-2 → step 8 (quick pass) → step 9b-lite → step 10 → step 12.
Skip: steps 3-4, Phase 2 (steps 5-7), step 9a, step 9c, step 11.
Step 9b-lite: for each item, answer only "what will be tested?" and "what input/output?"
— skip failure mode categories, invariant depth, and metric sufficiency analysis.
When in doubt → run full gate. Abbreviated saves time; full catches more.
Log difference: step 12d logs "Entry Gate (abbreviated)" so Close Gate knows.

**Phase 0 — Sprint Detail (conditional):**
*(Skip if this sprint already has Must/Should/Could items in the Roadmap.)*
If the sprint is still a one-line sketch from Initial Planning:
0a. Read the sketch description + previous sprint's outcomes
0b. Decompose into Must/Should/Could items with CORE-### IDs
    Format: `- [ ] CORE-###: [description]` — checkbox is mandatory.
    Plain bullets break close gate tracking (sprint-audit.sh Section 11).
0c. Add metric gates for each item (Must, Should, and Could — all get metrics)
0d. Priority & rigor review — two passes:
    **Pass 1 — Distribution check (on initial 0b decomposition, before any promotions):**
    - All items in Must? → decomposition didn't actually prioritize — re-sort.
    - Zero Should/Could? → check if Must includes nice-to-haves that should move down.
    - Must item has no dependencies and no metric? → should it be Should?
    Flag misplacements to user with reasoning. User decides final placement.
    **Pass 2 — Dependency promotion (after distribution is validated):**
    Q: Would removing this Should/Could item cause a Must item's metric gate to FAIL?
       YES → promote to Must. It was misclassified — it's a real dependency.
       NO  → stays at current priority.
    Post-promotion Must count may exceed initial count — this is valid.
    These are verified dependencies, not lazy grouping.
0e. Present detailed sprint plan to user for approval before proceeding to Phase 1
    User does not approve → identify concerns → rework 0b-0d → re-present.
    If user decides the sprint direction is fundamentally wrong → §Sprint Abort procedure.
This is the same process as Initial Planning step 4, applied to the next sprint.
If items exceed scope limit → apply §Scope Negotiation.

**Phase 1 — State Review (read-only):**
1. Read TRACKING.md → open items, blockers, in_progress items from interrupted sessions
   Clear §Predicted Failure Modes and §Failure Encounters sections
   (replace previous sprint's content for the new sprint).
2. Read Roadmap → Must/Should/Could for this sprint
3. Check non-verified items from previous sprints (all non-terminal statuses):
   - `blocked`: is the blocker still active? Resolved → update status to `open`.
     Still blocked → carry forward as `blocked` or drop (user decides).
   - `deferred`: still relevant? Carry forward or drop (user decides).
   - `open` / `in_progress`: still in scope? Carry forward (user decides).
   - `fixed` (not yet verified): verify now or carry forward for verification (user decides).
   Check §Open Risks for Architecture Review Required flags from previous sprints.
   If found → treat as Priority 1 in step 9a (before analyzing current sprint items):
   run the Architecture Review procedure at step 9a before listing new failure modes.
4. Identify applicable GUARDRAILS sections (consumed by implementation loop step A)

**Phase 2 — Dependency Verification (read-only):**
*(Sprint 1: skip this phase — no prior sprints exist.)*
5. Verify dependency sprints are closed.
   Partial completion rule: if a dependency sprint has `deferred` items, check whether
   the current sprint actually depends on those specific items. If not → dependency met.
   If yes → flag to user: "Sprint N depends on [deferred item] — resolve before proceeding?"
6. Read dependency API source files, confirm contracts match
7. List open architectural decisions — include in step 12a report.
   If any decision directly affects this sprint's scope or approach, flag in step 8.

**Phase 3 — Strategic Validation & Confirmation:**
8. Strategic alignment check — for each item (Must, Should, Could):
   a. Still relevant? (superseded, already delivered?)
   b. Goal alignment? (does it serve core project goals?)
   c. Approach still valid? (has new info invalidated the method?)
   d. Metrics still appropriate? (measuring the right thing?)
   If any fails → flag to user with evidence + options (keep/modify/defer/remove).
   User response mechanics:
   - keep → item unchanged, continue gate.
   - modify → update item description/scope/metrics in Roadmap, re-run steps 9a-9c for that item.
   - defer → TRACKING.md status `deferred` + roadmap `[~]`, requires reason + target sprint.
   - remove → delete from Roadmap + TRACKING.md, log removal in Change Log.
   AI does not unilaterally change sprint scope — user decides.
9. Verification plan:
   a. Failure mode analysis (per item — Must, Should, and Could):
      First: read TRACKING.md §Failure Mode History — which categories failed before?
      Check for escalation triggers in §Failure Mode History and §Open Risks:
      - Same category 2+ times in last 3 sprints → Architecture Review Required (see below).
      - Same detection=user-visual 2+ times → propose automated proxy test before proceeding.
          If triggered: propose adding a proxy test as a Must item in this sprint or the next.
          "A test that passes only when the visual check would also pass."
          Present options to user: add to current sprint scope, defer to next sprint as Must,
          or accept manual check (document rationale in §Open Risks). User decides.
      If Architecture Review triggered:
        1. Identify the recurring category (direct/interaction/stress-edge)
        2. Trace root causes across sprints — are they symptoms of the same design flaw?
        3. Propose architectural fix (not per-sprint patch) with scope and effort estimate
        4. Present to user: "Category [X] has failed [N] times across sprints [list].
           Root causes: [list]. Proposed architectural fix: [description]. Proceed or defer?"
        5. User decides: fix now (add to sprint scope) or defer (log with target sprint)
      Then: list known failure modes in 3 categories:
      - Direct: item breaks on its own (wrong calc, null ref, off-by-one)
      - Interaction: 2+ systems combine to fail (pool + dispatch + timing)
      - Stress/edge: invisible in normal use (rapid oscillation, pool exhaustion, cascade)
      Each category: >=1 mode.
      Critical Axis scrutiny: read CLAUDE.md §Project Summary → Critical Axis.
      For items that touch the Critical Axis domain: require >=2 predicted failure modes
      in that axis's most relevant category. Example: security axis → >=2 Direct modes
      covering attack surfaces. Performance axis → >=2 Stress/edge modes covering load scenarios.
      Write predictions to TRACKING.md §Predicted Failure Modes (step 7 reads this).
   b. For each item: how will behavior be verified? (unit test / integration test / manual + screenshot)
      Algorithmic items: what invariants must hold? (mathematical properties, reference output, determinism)
      "It runs" ≠ "it is correct".
   c. Metric sufficiency (per item — Must, Should, and Could):
      Item has no metric gate? Propose one.
      For each metric, all four must hold:
      - Measurable by sprint end?
      - Test scenario defined? (inputs, environment, data size, repetition count)
      - Threshold non-trivial? (construct a scenario where metric passes but system is broken
        — if one exists, tighten threshold or add scenario constraints)
      - Coverage: every failure mode from 9a maps to a metric or test? Missing → add.
      Any change (new metric, revised threshold, added test scenario) → propose in Entry Gate
      report (step 12a). Do NOT update roadmap yet — user approves metric changes at step 12c.
      If approved → update roadmap. If rejected → rework at step 9c, re-present.
10. Is scope realistic? (1-8 Must items. 0 Must → sprint is empty: return to Phase 0 step 0b
    to redesign scope, or run §Sprint Abort if the sprint goal is no longer viable.)
11. Produce dependency-ordered implementation list
12. Gate assessment, report & user approval
    a. Write full Entry Gate report to `Docs/Planning/S<N>_ENTRY_GATE.md`
       Contains: complete analysis from phases 0-3 (state review, dependency/API checks,
       strategic alignment, failure modes, implementation order, etc.)
       Must include a Metric Changes section from step 9c: for each metric that was added, revised,
       or had test scenarios defined — show before/after and rationale.
       This file serves as a living reference during the sprint and is deleted at Sprint Close.
    b. AI provides its own gate assessment before asking for approval:
       - **Blocker summary:** any step that failed or raised concerns? (list or "none")
       - **Risk assessment:** clean / attention points exist (list them) / blocker found
       - **Scope assessment:** conservative / reasonable / aggressive
       - **Key watch items:** implementation-time risks that aren't gate blockers
         but require careful attention (e.g., specific interaction risks from Architecture Review)
       - **Recommendation:** "Gate passed — recommend proceeding" or "Gate blocked by [X]"
    c. User approves before coding begins
       User specifically reviews verification plan quality (step 9b):
         For each item's test scenario — "Would this test pass even if the item is broken?"
         Trivial scenario (e.g., "it runs", "no crash", "no exception") → send back to step 9b for revision.
         Acceptable scenario: specifies inputs, expected outputs or invariants, and at least one failure-inducing case.
       User does not approve → identify blocking concerns → return to the relevant phase
       (Phase 0 for scope issues, Phase 3 for strategic/metric issues) → rework → re-present.
       If user decides the sprint direction is fundamentally wrong → §Sprint Abort procedure.
    d. After approval: log to TRACKING.md: "Entry Gate: [date], phases 0-3 ✓ (steps executed: [list])"
       Add reference to TRACKING.md: "Entry Gate report: Docs/Planning/S<N>_ENTRY_GATE.md"
       Update roadmap with any metric changes approved at step c.
       Update CLAUDE.md §Last Checkpoint: "Entry Gate complete — Sprint N approved, ready for implementation."
       Session recommendation: Entry Gate consumes significant context. If context is limited,
       recommend starting a new session for implementation ("Continue sprint N").
       If context is ample (long context window), continuing in the same session is fine.

---

## Close Gate — Sprint-End Audit

**Presentation rule:**
Interim "present to user" steps (Phase 0, 1a, 1b, 2, 4) are transparency checkpoints, not approval gates.
- Clean / minimal findings → batch into one combined report, do not pause for confirmation.
- Significant findings (blocker, regression, MISSED failure mode) → stop at that phase, present and ask.
- Mandatory user approval: Close Gate verdict only (final step before Sprint Close).

**Phase 0 — Metric gate check:**
- Can each metric be measured? Evidence exists? (all sprint metrics — every item has a metric gate)
- Failure mode coverage: for each modified subsystem, are failure modes listed in 3 categories (direct / interaction / stress-edge)? Each has a metric or test? Missing → add, or document as known gap with target sprint.
- **Structured metric verification** — fill this table for EVERY metric in the sprint.
  Empty cells = gate cannot close.
  ```
  ## Metric Verification — Sprint N
  | #  | Item(s)             | Metric              | Action Taken         | Status   | Evidence / Escalation                   |
  |----|---------------------|---------------------|----------------------|----------|-----------------------------------------|
  | 1  | CORE-001            | [metric from roadmap] | [what was done]    | ?        | [test link / escalation reason]         |
  | ...| ...                 | ...                 | ...                  | ...      | ...                                     |
  Action Taken values:
    existing   = test already existed and passed — no action needed
    written    = new test written this sprint
    fixed      = test existed but failed — code fixed to pass
    revised    = metric threshold or definition revised (note original → new)
    added      = metric was missing at sprint start — added during Entry/Close Gate
    escalated  = could not resolve — escalated as DEFERRED with reason
  Status values:
    PASS     = test exists + passes (link to test file:line)
    DEFERRED = blocked by prerequisite (must follow escalation below)
    FAIL     = test exists but fails (fix before closing; if unfixable → escalate as DEFERRED)
    MISSING  = no test exists (write one; if untestable → escalate as DEFERRED with reason)
  Rule: every row must be PASS or DEFERRED (with escalation). MISSING/FAIL → gate blocked.
  If a FAIL/MISSING metric cannot be resolved: escalate to user — present options
  (accept gap with target sprint, or §Sprint Abort if the metric is critical).
  Guard: if ALL metrics are DEFERRED → gate blocked. At least one metric must PASS.
  A sprint with zero verified metrics accomplished no verified work → §Sprint Abort procedure.
  ```
- Unmet metric escalation — when a metric is DEFERRED or MISSING:
  Do NOT silently mark `[ ]` and move on. Required steps:
  1. **Explain** — what is blocking completion? (missing data, unfinished prerequisite, external dependency)
  2. **Trace** — is the blocker tracked in the roadmap? (has a CORE-### entry?)
     - Not tracked → propose adding it with a recommended sprint and priority level.
     - Tracked but no sprint assigned → propose a target sprint with reasoning.
  3. **Recommend** — present the gap analysis and a concrete proposal to the user.
     Include: what's done, what's missing, which sprint should finish it, and why.
  4. **User decides** — user picks target sprint and priority. Agent does not decide alone.
  5. **Log** — TRACKING.md: status = `deferred`, reason + target sprint documented.
- **Present completed table to user** — after all metrics are resolved (PASS or DEFERRED),
  present the full Metric Verification table to the user before proceeding to Phase 1a.
  This is mandatory regardless of which path was taken (test written or escalated).
  User sees every metric's final status and evidence. No silent close.
- **Log compact summary to TRACKING.md** — do NOT copy the full table.
  Write a one-line summary: `**Metric Verification:** X/Y PASS, Z DEFERRED (item-id reason → S<N>, ...)`
  The full table lives in the session; tests in the codebase are the persistent evidence.
  DEFERRED items already have their target sprint logged via the escalation procedure above.

**Phase 1a — Automated scan:**
- Run `Tools/sprint-audit.sh`
- Exit code 2 (setup error): fix script configuration (paths, patterns) before proceeding.
  Do not skip the automated scan — fix the script first.
  If the script cannot be adapted (unsupported language, missing tooling): skip automated scan,
  log `sprint-audit.sh: not applicable — [reason]` in TRACKING.md Change Log, and rely on
  Phase 1b (manual audit) for full coverage.
- Exit code 1 (findings): review each finding, fix immediately or log with target sprint
  (user decides which findings to defer — same principle as Phase 2).
  Present automated scan summary to user before proceeding to Phase 1b.
- Exit code 0 (clean): proceed (note "clean" to user before Phase 1b).

**Phase 1b — Spec-driven audit:**
Load Entry Gate data before starting:
- TRACKING.md §Predicted Failure Modes (written at Entry Gate 9a)
- S<N>_ENTRY_GATE.md verification plan per item (Entry Gate 9b invariants)

Abbreviated gate check (do this first):
- Is TRACKING.md Change Log entry for Entry Gate marked "Entry Gate (abbreviated)"?
  YES → §Predicted Failure Modes is empty (9a was skipped). Skip step b for all items.
        Verification plan (9b-lite) still applies to step c.
  NO  → proceed normally (steps a, b, c for each item).

For each completed item (Must + Should + Could):
  a. Find implementing files:
     - VCS=git: `git diff` filtered by item context
     - VCS=none: read Entry Gate implementation plan notes for the item.
       If notes are insufficient or ambiguous: ask user explicitly —
       "For [CORE-###], which files did you modify?" — review those files.
       Log the user-provided file list in TRACKING.md Change Log for audit trail.
  b. Predicted failure modes → is each mode handled in code?
     - Direct: does the item break on its own? (null ref, off-by-one, wrong calc, missing guard)
     - Interaction: does combining with other systems cause failure? (timing, shared state, dispatch order)
     - Stress/edge: does extreme input/load/timing expose a break? (pool exhaustion, rapid oscillation, cascade)
  c. Verification plan invariants (from Entry Gate 9b) → do they hold in the implementation?
     ("Algorithmic items: what invariants must hold?" — if 9b specified them, check they are enforced in code)

Supplemental per-file check (issues outside item scope):
1. Resource/memory leaks
2. Missing observability (logging, profiling)
3. Dead code and orphan scaffolding
4. Debug path parity with production

Output: per-item summary (CORE-### → failure modes: HANDLED / MISSED / N/A)
        + supplemental findings per file.
  HANDLED = mode is applicable and addressed in code.
  MISSED  = mode is applicable but not addressed — must fix or defer.
  N/A     = mode is not applicable to this item's domain
            (e.g., stress/edge for a pure UI label item).
            Use sparingly: justify why it cannot apply.
Present summary to user before proceeding to Phase 2.
Do not declare "audit complete" without per-item acknowledgment.

**Phase 2 — Fix:**
- Fix immediately or log with target sprint (user decides which findings to defer).
- Critical Axis rule: read CLAUDE.md §Project Summary → Critical Axis.
  Any finding that touches the Critical Axis domain cannot be silently deferred.
  If deferral is proposed for a Critical Axis finding:
    → Stop. Present to user explicitly: "This finding touches [Critical Axis].
       Deferring [security/performance/...] findings is high risk in this project.
       Options: (1) fix now, (2) defer with explicit written rationale + target sprint,
       (3) invoke Sprint Abort if the risk is unacceptable."
    → User must choose explicitly. AI does not decide alone.
- After Phase 2: present fix/defer summary to user before proceeding to Phase 3.
  Show: which findings were fixed, which logged to target sprint with reason.
  Flag any deferred Critical Axis findings separately.

**Phase 3 — Regression test:**
- All tests must PASS after fixes
- Include any tests marked "pending" during D.6 that can now execute (infra available at Close Gate)

**Phase 4 — Test coverage gap:**
- 4a. File-level: new/modified code → matching test file exists?
- 4b. Item-level: every completed item (Must+Should+Could) → behavioral test exists?
  Log item → test mapping in TRACKING.md evidence. No test → write one or document why untestable.
- Present coverage gap summary to user before final test run:
  Show: which gaps were found, which tests were written, which items documented as untestable.
- Final test run PASS

**Close Gate verdict & user approval:**
- AI provides close gate assessment:
  - **Metric summary:** X/Y PASS, Z DEFERRED (list deferred items + target sprints).
    Include action breakdown: N existing, M written, K fixed, J revised, L added, P escalated.
  - **Findings summary:** N fixed, M deferred to target sprint, K untestable items
  - **Risk assessment:** clean / attention points exist (list them)
  - **Recommendation:** "Gate passed — recommend closing sprint" or "Gate blocked by [X]"
- User approves before Sprint Close begins.
  User does not approve → identify concern → return to the relevant phase for rework.
- After approval: Update CLAUDE.md §Last Checkpoint: "Close Gate complete — Sprint N approved, starting Sprint Close."
  Session recommendation: Implementation session is heavily consumed by the time Close Gate runs.
  If context is limited, recommend starting a fresh session to run Close Gate ("Run Close Gate, sprint N").
  Close Gate + Sprint Close can run in the same session — Sprint Close is lightweight.
  If context is ample (long context window), continuing from the implementation session is fine.

---

## Sprint Close — Post-Gate

1. Roadmap checkmarks
   Run `sprint-audit.sh` (full script runs — focus on Section 11 output for sync).
   Fix all mismatches before ticking.
   [x] = TRACKING.md verified (gate evidence logged)
   [~] = skipped + reason documented inline
   [ ] = not verified (open, in_progress, or fixed without evidence)
   Every [ ] item requires action — do NOT silently skip:
   → apply the unmet-metric escalation from Close Gate Phase 0
     (explain gap, trace blocker, propose target sprint, user decides).
2. TRACKING.md update (all Must verified with evidence;
   completed Should/Could also updated with final status and evidence)
3. CLAUDE.md checkpoint update (date, status, next focus)
4. Changelog archive (move entries to Docs/Archive/)
5. Performance baseline capture:
   - Record measurable metrics, compare vs previous sprint, flag regressions.
   - No measurable metrics yet? Log: "Performance baseline: not yet established.
     Target: [which metrics to set up] by Sprint [N]." This is valid for early sprints.
     Do not invent fake baselines.
6. Workflow integrity check:
   - CLAUDE.md §Document Contract references → do target files and sections exist?
   - Guardrails §Entry Gate / §Close Gate → consistent with SPRINT_WORKFLOW.md procedures?
   - Do not manually count steps/phases. Instead: verify that each numbered step in
     SPRINT_WORKFLOW.md has a corresponding action (not that counts match across files).
   - Mismatch → fix before closing sprint.
     If irreconcilable → document discrepancy in TRACKING.md §Open Risks with target sprint.
7. Failure mode retrospective:
   a. Reconstruct actual failures: review Sprint Board for items that went through fix cycles,
      Change Log for bug-related entries, and §Failure Encounters (if logged during implementation).
      List every failure encountered with: Item, Category (direct/interaction/stress-edge), Detection method.
   b. Read TRACKING.md §Predicted Failure Modes (written at 9a).
   c. **Fill structured retrospective table** — one row per predicted mode + one row per actual failure:
      ```
      ## Failure Mode Retrospective — Sprint N
      | Predicted Mode | Predicted? | Actually Occurred? | Detection | Impact | Root Cause | New Guardrail? |
      |---------------|------------|-------------------|-----------|--------|------------|----------------|
      Every predicted mode must have an "Actually Occurred?" answer (yes/no).
      Every actual failure must appear — including unpredicted ones (Predicted? = no).
      Empty rows = step incomplete.
      ```
   d. Transfer rows to TRACKING.md §Failure Mode History (include Detection column: test / user-visual / profiler).
   e. Unpredicted failure → new guardrail rule. Follow CODING_GUARDRAILS.md §Update Rule
      (7 steps: dedup check, root cause, rule, anti-pattern, code comment, sprint-audit.sh, LESSONS_INDEX.md).
   f. Check §Failure Mode History for escalation triggers:
      - Same category 2+ times in last 3 sprints → flag "Architecture Review Required" at next Entry Gate
      - Same detection=user-visual 2+ times → flag "Can automated proxy test replace visual check?" at next Entry Gate
      Record flags in TRACKING.md §Open Risks so Entry Gate 9a picks them up.
   g. **Present completed retrospective table to user** before proceeding to step 8.
8. Failure Mode History maintenance:
   - If §Failure Mode History exceeds 30 rows: archive rows older than 5 sprints
     to Docs/Archive/failure-history-S1-S[N].md. Keep last 5 sprints in TRACKING.md.
   - Entry Gate 9a only needs recent history (last 3 sprints) for pattern detection.
9. Entry Gate report cleanup:
   - Delete `Docs/Planning/S<N>_ENTRY_GATE.md` — its purpose (sprint-scoped reference) is fulfilled.
   - The gate execution log in TRACKING.md (from Entry Gate step 12d) persists as the permanent record.
10. User handoff summary:
    For each completed item, present to user:
    - **Before/after:** what changed in behavior (1-2 sentences, non-technical)
    - **How:** implementation approach in one sentence (user-level, not method names)
    - **Where:** file name / Inspector path so user can find it
    - **Verify:** specific runtime action + expected result
    - **Should NOT change:** what to check for regressions
    Invisible sprint (no visual change)? State explicitly:
    "No visible change — verify via [specific diagnostic/counter/log]"
    Present before marking sprint done. Do not skip if user "already knows" —
    the summary serves as a session handoff record, not just explanation.
11. Sprint "done"
    Log to TRACKING.md: "Sprint Close: [date], steps 1-11 ✓"

---

## Anti-Pattern Quick Reference

| # | Anti-Pattern | Correct Approach | Ref |
|---|-------------|-----------------|-----|
| 1 | [pattern] | [correct] | §X.Y |

---

## Update Rule

1. Check LESSONS_INDEX.md and anti-pattern table — does a rule for this root cause already exist?
   Yes → strengthen existing rule (tighten scope, add example). No → continue.
2. Identify root cause of bug
3. Add rule to relevant section
4. Add to anti-pattern table
5. Reference in code comment
6. Update sprint-audit.sh if pattern is grep-detectable
7. Add entry to Docs/LESSONS_INDEX.md (RuleID, root cause, guardrail section, sprint, source item)
```

### Mid-Sprint Scope Change

When an urgent item (critical bug, security fix, user-requested change) must enter a sprint
that has already passed Entry Gate:

```
1. User requests scope change (AI never initiates scope changes unilaterally)
2. AI assesses impact:
   a. Does the new item conflict with in-progress items?
   b. Does it invalidate any verified items? (if yes → regression, see §State Transitions;
      if no → no regression impact, continue to next check)
   c. Will it push the sprint over scope limit?
3. AI presents options to user:
   - Add as new Must item (may push Should/Could to next sprint)
   - Add as new Must item + defer an existing Must item to make room (user picks which).
     Deferred item: TRACKING.md status → `deferred` + reason, Roadmap → `[~]`.
   - Add as hotfix outside sprint scope (no ID, no gate — emergency only).
     Hotfix still requires: TRACKING.md Change Log entry with description,
     test if testable, and inclusion in Sprint Close step 7 retrospective.
     Only the formal ID assignment and gate process are skipped.
   - Defer to next sprint (item not added now: log in Roadmap as future sprint sketch item)
4. User decides
5. Log decision in TRACKING.md Change Log:
   "Scope change: [date] — added [ID] mid-sprint. Reason: [why]. Impact: [what shifted]."
6. If new Must item added: create TRACKING.md entry (status: open), add to Roadmap
```

Rule: a scope change is NOT a new Entry Gate. The existing sprint plan stays valid;
only the added/removed items change.

### Scope Negotiation

When features exceed the sprint scope limit (Q2 at Initial Planning, or Phase 0 decomposition):

```
1. AI sorts features by dependency order + user-stated priority
2. First N features (where N = scope limit) become Must items for the sprint
3. Remaining features:
   a. If the feature is critical but can't fit → ask user: "Increase scope size, or defer?"
   b. If the feature is nice-to-have → assign to Should/Could or later sprint sketch
4. Present the allocation to user for approval
5. User can override any placement (move items between Must/Should/Could/later sprint)
```

Rule: AI proposes, user disposes. Never silently drop features — always show where they went.

### Immutable Contract Revision

Immutable contracts (in CLAUDE.md §Immutable Contracts) are not truly permanent —
they require explicit revision when project direction changes.

```
Revision trigger: user explicitly requests a change to a listed contract.
AI never initiates contract revision unprompted.

Revision procedure:
1. AI identifies all code, tests, and items that depend on the contract
2. AI assesses blast radius:
   - Which verified items become invalid? (mark as `open` — regression)
   - Which in-progress items are affected?
   - Which guardrail rules reference the contract?
3. AI presents impact summary to user:
   "Changing [contract] affects [N] files, [M] verified items, [K] guardrail rules."
4. User confirms revision
5. Update CLAUDE.md §Immutable Contracts (old value → new value, date, reason)
6. Log in TRACKING.md Change Log:
   "Contract revised: [date] — [old] → [new]. Reason: [why]. Affected items: [list]."
7. Affected verified items → status `open` (regression)
8. Affected guardrail rules → update or remove
```

### Sprint Abort

When the user decides to abandon a sprint mid-way (wrong direction, requirements changed drastically):

```
1. User requests abort (AI never initiates abort)
2. Mark all non-verified items as `deferred` with reason: "sprint aborted — [reason]"
3. Verified items keep their status (work is not lost)
4. Skip Close Gate (no items to audit)
5. Run abbreviated Sprint Close: steps 1-4 + step 9 (checkmarks, TRACKING update,
   checkpoint, changelog archive, Entry Gate report cleanup).
   Skip steps 5-8 and 10 (no baselines, no FM retrospective for an aborted sprint).
6. Log in TRACKING.md Change Log:
   "Sprint aborted: [date] — Reason: [why]. Verified: [list]. Deferred: [list]."
7. Next sprint Entry Gate runs normally — deferred items are reviewed at step 3
```

Rule: abort ≠ failure. Verified work persists, unfinished work is deferred, not deleted.

### Retroactive Sprint Audit

**Purpose:** Systematically audit a completed sprint when its output is found to be broken,
non-functional, or inconsistent with Close Gate claims in a later session.
This is evidence-based archaeology — not a blame exercise. Goal: locate the gap, classify it,
and resolve it with minimal disruption to the current sprint.

**Triggers — any one is sufficient to open an audit:**
- A runtime metric contradicts a Close Gate verdict
  (e.g., cache hit rate = 0% when Close Gate logged "verified"; FPS budget exceeded when sprint claimed "< Xms")
- A later sprint cannot build on a completed sprint's output (integration failure, API mismatch, missing output)
- A guardrail check now fails on code that was verified in the target sprint (sprint-audit.sh regression)
- A profiler shows a system that should be active is not running (cost = 0 → system is off, not optimized)
- User observes behavior that explicitly contradicts a verified item ("this was supposed to work")
- §Failure Mode History shows the same category 2+ times in recent sprints, tracing back to a specific earlier sprint
- Entry Gate §Open Risks contains a flag pointing at a specific past sprint's output

**Who initiates:** User or AI. AI may propose opening an audit if a trigger is observed during implementation;
the user decides whether to proceed. AI never opens an audit without user confirmation.

**Scope rule:** One audit open at a time. If symptoms span multiple sprints, open the oldest
implicated sprint first. Resolve before opening the next.

**Audit depth limit:** Maximum 3 months back. For older sprints, use §Rollback Plan instead.

**Current sprint impact:** An audit does not pause the current sprint. Resolution items are added
to the current sprint (via Mid-Sprint Scope Change) or the next sprint's backlog.

```
Trigger observed
      │
      ▼
Phase 0: Setup
  ├── identify target sprint + symptom + Close Gate claim
  └── estimate blast radius → user confirms → audit opens
      │
      ▼
Phase 1: Evidence Collection
  └── read all Close Gate artifacts for target sprint
      │
      ▼
Phase 2: Current State Assessment
  └── run same measurements as Close Gate today
      │
      ▼
Phase 3: Gap Analysis
  └── compare claim vs current → produce gap table
      │
      ▼
Phase 4: Root Cause Classification
  └── classify each gap: REGRESSION / INTEGRATION_GAP / FALSE_VERIFICATION /
                         COLD_STATE / SCOPE_DRIFT / ENVIRONMENT_DELTA
      │
      ▼
Phase 5: Dependency Impact Assessment
  └── which subsequent sprints are affected? → mark re-verification required
      │
      ▼
Phase 6: Resolution Plan
  └── for each gap: fix now / fix next sprint / accept+document / rollback
      │
      ▼
Phase 7: Audit Close
  └── write to TRACKING.md §Retroactive Audits → present to user → resume current work
```

---

#### Phase 0 — Audit Setup

Before doing any file reading or measurement, establish:

```
1. Target sprint number: S[N]
2. Symptom (observable, measurable — not vague):
   BAD:  "S6 cache seems broken"
   GOOD: "S6 SDF Cache: Hit=0, Miss=122, Rate=0% — Close Gate claimed 'cache verified'"
3. Close Gate claim being questioned:
   Quote the exact verified item or metric from TRACKING.md or S<N>_CLOSE_GATE.md.
   If no record exists → this becomes a FALSE_VERIFICATION finding immediately (Phase 4).
4. Blast radius estimate:
   List sprints that depend on target sprint's output (from Roadmap dependency map).
   Example: S6 (SDF Cache) → S7 (Streaming depends on cache), S8 (profiler uses cache stats)
5. Present setup summary to user:
   "Opening Retroactive Audit for S[N]. Symptom: [X]. Claim questioned: [Y]. Depends-on chain: [Z].
    Proceeding with Phase 1 evidence collection."
   Wait for user confirmation before proceeding.
```

---

#### Phase 1 — Evidence Collection

Read all available artifacts from the target sprint in this order:

```
1. S<N>_CLOSE_GATE.md (Docs/Planning/) — if it still exists
   → read Phase 1b audit table, Phase 2 verdict, all metrics
   → if deleted (Sprint Close step 9 ran): proceed to TRACKING.md

2. TRACKING.md §Sprint N
   → all verified items (status = verified) with their evidence logs
   → all metric gate values recorded
   → Failure Mode Retrospective for Sprint N
   → Change Log entries dated within Sprint N

3. Roadmap.md Sprint N section
   → which items are [x] (verified) vs [~] (deferred)?
   → note any items that were silently [~] without documented reason

4. Git log for target sprint
   → git log --oneline <phase-tag-before>...<phase-tag-after> (if tags exist)
   → git log --oneline --since="[sprint start date]" --until="[sprint end date]"
   → look for: last-minute commits, hotfix commits, revert commits

5. sprint-audit.sh output (if preserved in TRACKING.md or Docs/)
   → section 11 output: were all items verified?
   → any check that was WARN or SKIP at close?

6. CODING_GUARDRAILS.md rules added during Sprint N
   → what rules existed at Sprint N time? (git blame or log)

7. Failure Mode History entries from Sprint N
   → what was predicted? what actually occurred?
```

Evidence collection output — fill before proceeding to Phase 2:
```
## Audit Evidence — Sprint N
Close Gate record found: YES / NO (if NO → FALSE_VERIFICATION likely)
Verified items at Close Gate: [list of CORE-### with their claimed evidence]
Metric gates at Close Gate: [list of metric name + value]
Git commits in sprint: [count] — notable: [any reversions/hotfixes]
sprint-audit.sh at close: PASS / WARN / SKIP / not preserved
Failure modes predicted: [list]
Failure modes that actually occurred: [list]
```

---

#### Phase 2 — Current State Assessment

Measure the system as it stands today — using the same measurement method as Close Gate.

```
1. Run sprint-audit.sh (full run)
   → record which sections PASS / FAIL / WARN vs Close Gate state

2. Run the target system's specific measurement:
   → If performance claim: profiler capture in relevant test scene (same camera, same conditions)
   → If test claim: re-run the exact test suite that was verified
   → If integration claim: trace the data flow from entry point to output
   → If metric claim: reproduce the metric (frame count, cache rate, memory, etc.)

3. Enable diagnostic output if available:
   → debug overlays, log verbose, counters, HUD metrics
   → capture: screenshots, log excerpts, profiler screenshots

4. Check kill-switch state:
   → Is the system enabled? (PlanetProfile toggle, feature flag, build define)
   → Is it conditionally disabled? (scene-only, platform-only, requires init sequence?)

5. Check initialization sequence:
   → Does the system require warm-up frames before metrics are meaningful?
   → If yes: measure after warm-up (document warm-up frame count)

6. Dependency check:
   → Does the system depend on a previous system's output?
   → If yes: verify that previous system is running and producing output
```

Current state output — fill before proceeding to Phase 3:
```
## Current State — Sprint N Audit
Date of measurement: [date]
sprint-audit.sh result: [PASS/FAIL, section list]
System enabled (kill-switch): YES / NO / N/A
Measurements:
  [metric name]: [current value] (method: [how measured])
  [metric name]: [current value] (method: [how measured])
Dependency systems running: YES / NO / PARTIAL
Notes: [anything unusual about measurement conditions]
```

---

#### Phase 3 — Gap Analysis

Compare Phase 1 (Close Gate claims) vs Phase 2 (current measurements) systematically.

**Item-level comparison:**

```
For each verified item [x] in the target sprint:
```

| Item ID | Close Gate Claim | Current State | Match? | Notes |
|---------|-----------------|---------------|--------|-------|
| CORE-### | [exact claim from evidence] | [current observation] | YES / NO | [discrepancy detail] |

**Metric-level comparison:**

| Metric | Close Gate Value | Current Value | Delta | Within Tolerance? |
|--------|-----------------|---------------|-------|-------------------|
| [name] | [value at close] | [value now] | [±%] | YES / NO |

**Gap tolerance rules:**
```
Continuous metrics (ms, MB, %, count):
  < 5% delta    → measurement variance; note but do not classify as gap
  5-20% delta   → borderline; classify as gap, investigate root cause
  > 20% delta   → definitive gap; classify and resolve
  0 vs non-zero → always a gap (system on vs off is not variance)

Binary metrics (PASS/FAIL, exists/missing):
  Any difference → gap; no tolerance

Edge case — warm-start vs cold-start:
  If metric requires warm-up (e.g., cache hit rate needs N frames to populate):
  Measure at warm-start. If warm-start also fails → gap. If only cold-start fails → COLD_STATE.
```

**Gap summary table (fill before Phase 4):**
```
## Gap Summary — Sprint N Audit
Total items compared: [N]
Items with NO match: [list of CORE-###]
Metrics with gap: [list]
Items with YES match (confirmed working): [list]
```

---

#### Phase 4 — Root Cause Classification

For each gap identified in Phase 3, assign exactly one category:

| Category | Definition | Key Question |
|----------|-----------|-------------|
| **REGRESSION** | Was working at Close Gate; broken by code merged in a subsequent sprint | "Which commit after Sprint N broke this?" |
| **INTEGRATION_GAP** | Worked in isolation (sandbox/EditMode test) but was never wired into the runtime path | "Does the system actually get called in the live game loop?" |
| **FALSE_VERIFICATION** | Close Gate metrics were insufficient: test measured the wrong thing, or passed a cherry-picked case | "Would the Close Gate metric have caught this failure if it occurred then?" |
| **COLD_STATE** | Current behavior is correct for the current conditions (cache empty after clean build, kill-switch OFF, first run) | "Is this the expected state given current conditions?" |
| **SCOPE_DRIFT** | A later sprint changed requirements or contracts that made the earlier implementation invalid | "Did a later sprint's design decision break this retroactively?" |
| **ENVIRONMENT_DELTA** | Works in original environment; fails due to engine version, platform, or dependency change since Sprint N | "Did anything in the build environment change between Sprint N and now?" |

**Classification priority rule:**
If multiple categories could apply, choose the earliest in this order:
`REGRESSION > INTEGRATION_GAP > FALSE_VERIFICATION > COLD_STATE > SCOPE_DRIFT > ENVIRONMENT_DELTA`

**Classification procedure for each gap:**
```
1. REGRESSION check:
   → git log --oneline <sprint-N-tag>..HEAD -- [affected files]
   → Did any commit after Sprint N modify the affected system?
   → If yes → candidate for REGRESSION. Identify the responsible commit.

2. INTEGRATION_GAP check:
   → Trace the call chain from the game loop entry point to the system.
   → Is there a missing hook, missing registration, or path that never reaches the system?
   → If yes → INTEGRATION_GAP.

3. FALSE_VERIFICATION check:
   → Read the Close Gate evidence for the item.
   → Would that evidence have caught the current failure mode at Sprint N time?
   → If not → FALSE_VERIFICATION.

4. COLD_STATE check:
   → What conditions would make the current behavior correct?
   → Are those conditions present? (kill-switch, cold cache, first run, missing asset)
   → If yes → COLD_STATE. Document expected behavior explicitly.

5. SCOPE_DRIFT check:
   → Did a subsequent sprint change an interface, format, or contract that this system depends on?
   → Check: Roadmap.md for contract revisions, TRACKING.md Change Log after Sprint N.
   → If yes → SCOPE_DRIFT.

6. ENVIRONMENT_DELTA check:
   → Engine/SDK/package version changes since Sprint N?
   → Platform target changes?
   → If yes → ENVIRONMENT_DELTA.
```

**Classification output:**
```
## Classification — Sprint N Audit
| Gap | Category | Evidence for Classification |
|-----|----------|-----------------------------|
| CORE-### [description] | REGRESSION | Commit [hash] on [date] modified [file] |
| [metric] gap | FALSE_VERIFICATION | Close Gate tested [X], current failure is [Y] — different scenario |
```

---

#### Phase 5 — Dependency Impact Assessment

For each gap classified as REGRESSION, INTEGRATION_GAP, FALSE_VERIFICATION, or SCOPE_DRIFT:

```
1. List all subsequent sprints that depend on the target sprint's output:
   → Use Roadmap.md dependency map (or TRACKING.md if dependency is documented there)

2. For each dependent sprint:
   a. Identify which of its verified items rely on the broken output
   b. Answer: does the gap affect the dependent item's correctness?
      - YES → mark that item as `open (regression)` in TRACKING.md
              Add note: "Re-verification required — see Retroactive Audit Sprint N, [date]"
      - NO  → document: "unaffected — gap is in [subsystem X], Sprint M used [subsystem Y]"

3. Re-verification scope rule:
   If ≥ 3 items require re-verification across dependent sprints →
   flag "Sprint Re-verification Cluster" in TRACKING.md §Open Risks.
   Present to user: "This gap affects [N] verified items across [M] sprints.
   Recommend scheduling a dedicated re-verification sprint."

4. Guardrail coverage check:
   For each classified gap: which guardrail rule should have prevented this?
   - Rule exists → was it present at Sprint N time? If not → when was it added?
   - Rule does not exist → create now (follow §Update Rule 7-step process)
   - Rule exists but was not enforced → add enforcement to sprint-audit.sh

5. Test coverage check:
   - Was there an automated test for the broken behavior?
   - If yes: why did it not catch the gap? (wrong assertion, wrong scenario, not run at gate)
   - If no: would one have been feasible? If yes → add as Must item for resolution sprint
```

**Dependency impact output:**
```
## Dependency Impact — Sprint N Audit
| Sprint | Dependent Item | Affected? | Action |
|--------|---------------|-----------|--------|
| S[M] | CORE-### [description] | YES | Mark open (regression) |
| S[M] | CORE-### [description] | NO | Unaffected — [reason] |

Re-verification cluster: YES (N items) / NO
New guardrail rules needed: [list or "none"]
New automated tests needed: [list or "none"]
```

---

#### Phase 6 — Resolution Plan

For each classified gap, define exactly one resolution path. Present all options to user; user decides.

**Resolution options:**

| Option | When to Use | Process |
|--------|------------|---------|
| **Fix now (current sprint)** | Gap is a blocker for current or next sprint's Must items | Add via §Mid-Sprint Scope Change as Must item |
| **Fix next sprint** | Gap is important but not immediately blocking | Add to next sprint Entry Gate backlog; log in TRACKING.md §Open Risks |
| **Accept + document** | Gap is COLD_STATE or acceptable limitation; no code change needed | Document expected behavior in TRACKING.md; update Close Gate metric definition |
| **Revert target sprint** | Gap is fundamental; fix would require redoing Sprint N from scratch | Follow §Rollback Plan for target sprint's phase |
| **Quarantine** | Gap affects untested future scope only; no current sprint is broken | Add guard comment in code; flag at relevant future sprint's Entry Gate |

**Resolution output (one row per gap):**
```
## Resolution Plan — Sprint N Audit
| Gap | Category | Resolution Option | Target Sprint | Must-item ID | Blocker? |
|-----|----------|--------------------|--------------|--------------|---------|
| [description] | REGRESSION | Fix now | Current | CORE-[new] | YES |
| [description] | FALSE_VERIFICATION | Accept + document | Immediate | N/A | NO |
| [metric] gap | COLD_STATE | Accept + document | Immediate | N/A | NO |
```

**Blocking escalation rule:**
If a gap is REGRESSION or INTEGRATION_GAP and affects any current sprint Must item →
the gap is automatically a blocker. It must be resolved before the current sprint's Close Gate.
Present to user: "This audit found a blocker for the current sprint.
Recommend addressing [gap] before continuing with CORE-###."

---

#### Phase 7 — Audit Close

Required before marking audit complete and returning to current work:

```
1. Write audit summary to TRACKING.md §Retroactive Audits:

   ## Retroactive Audit — Sprint N
   Opened: [date] | Closed: [date]
   Trigger: [exact symptom that opened audit]
   Gaps found: [count]
   Classifications:
     REGRESSION: [count] — [brief description of each]
     INTEGRATION_GAP: [count] — [brief description]
     FALSE_VERIFICATION: [count] — [brief description]
     COLD_STATE: [count] — [brief description]
     SCOPE_DRIFT: [count] — [brief description]
     ENVIRONMENT_DELTA: [count] — [brief description]
   Items requiring re-verification: [list of CORE-### or "none"]
   New guardrail rules added: [list of rule IDs or "none"]
   New tests added: [list or "none"]
   Resolution: [summary — what was fixed now, what is deferred, what was accepted]
   Audit status: CLOSED

2. If FALSE_VERIFICATION found:
   Update Close Gate metric gate definition for Sprint N in TRACKING.md:
   "Metric gate updated post-audit [date]: [old gate] → [new gate]. Reason: [why original was insufficient]."
   Add improved metric to CODING_GUARDRAILS.md as a mandatory gate check.

3. If REGRESSION found:
   Add to TRACKING.md Change Log:
   "Regression identified [date]: Sprint N [system] broken by Sprint M commit [hash].
    Fix: [approach]. Responsible item: CORE-[new]."

4. If new guardrail rules created:
   Complete §Update Rule 7-step process for each rule.

5. If ≥ 1 item marked `open (regression)`:
   Ensure Entry Gate for next sprint will surface these at step 3 (deferred items review).

6. Present audit summary to user:
   "Audit closed. Found [N] gaps: [classification breakdown].
    [X] items need re-verification. [Y] new guardrail rules added.
    Resolution: [brief]. Resuming current sprint at [CORE-###]."

7. Resume current sprint work.
```

---

#### Integration with Existing Workflow

**Entry Gate step 3** (deferred items review):
→ Check TRACKING.md §Retroactive Audits for pending re-verification items.
   Items marked `open (regression)` from a past audit appear here as deferred items.

**Entry Gate step 9a** (failure mode history):
→ Audits closed in last 3 sprints are included in pattern analysis.
   Multiple audits of same category → "Architecture Review Required" flag.

**Close Gate Phase 1b** (abbreviated check):
→ If any current sprint item depends on an audited sprint's output:
   verify the dependency is using the corrected post-audit state, not the broken pre-audit state.

**Sprint Close step 7** (failure mode retrospective):
→ Cross-reference: if a gap was found via Close Gate (not audit),
   did a past audit predict this category? Pattern tracking.

**Sprint Close step 6** (workflow integrity check):
→ §Retroactive Audits section exists in TRACKING.md and is current?
   Audits without `status: CLOSED` → must be resolved before sprint marks "done".

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

Checkbox notation:
- `- [ ]` = not verified (open, in_progress, or fixed — no gate evidence yet)
- `- [x]` = verified (TRACKING.md status = verified, gate evidence logged)
- `- [~]` = skipped / deferred (TRACKING.md status = deferred, reason documented inline)

Rule: checkbox tracks TRACKING.md status.
- `[x]` ↔ `verified`, `[~]` ↔ `deferred`. All other statuses → `[ ]`.
- Intermediate states (in_progress, fixed-untested) are NOT shown in roadmap.
- Checkbox format is mandatory. Plain bullets (`- CORE-###: ...`) break close gate tracking —
  `sprint-audit.sh` Section 11a/11c will not find them. Always use `- [ ] CORE-###: ...`.
- `sprint-audit.sh` Section 11 catches mismatches (including `[~]` ↔ `deferred` sync) automatically.

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
              ┌────────────────────────┐
              │ ≤3 Must + no cross-    │──YES──► Abbreviated mode:
              │ sprint dependencies?   │         Ph0 → 1-2 → 8 → 9b-lite
              └────────────┬───────────┘         → 10 → 12
                           │ NO
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 0 — Sprint Detail (conditional)                          │
│  Skip if sprint already has Must/Should/Could items.            │
│  If sprint is a one-line sketch:                                │
│    0a. Read sketch + previous sprint outcomes                   │
│    0b. Decompose into Must/Should/Could with IDs                │
│    0c. Add metric gates (all items)                             │
│    0d. Priority & rigor review (2 passes):                      │
│        Pass 1: distribution check (all Must? re-sort)           │
│        Pass 2: dependency promotion (Should/Could → Must?)       │
│    0e. User approves detailed plan                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1 — State & Context Review (read-only)                   │
│                                                                 │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐  ┌──────────────┐    │
│  │TRACKING │  │ Roadmap  │  │  Deferred  │  │  Guardrails  │    │
│  │  .md    │  │ sprint N │  │  items     │  │  §Index      │    │
│  └────┬────┘  └────┬─────┘  └─────┬──────┘  └──────┬───────┘    │
│       └────────────┴──────────────┴─────────────────┘           │
│                            │                                    │
│                     "What exists now?"                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2 — Dependency & API Verification (read-only)            │
│  (Sprint 1: skip — no prior sprints exist)                      │
│                                                                 │
│  ┌────────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │ Dep sprints    │  │ API source   │  │ Open decisions     │   │
│  │ closed?        │  │ files match? │  │ (arch choices)     │   │
│  └────────────────┘  └──────────────┘  └────────────────────┘   │
│                                                                 │
│                     "Can we build on this?"                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3 — Strategic Validation & Confirmation                  │
│                                                                 │
│  For each item (Must, Should, Could), 4-question check:         │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌─────────────────┐    │
│  │ Still    │ │ Goal      │ │ Approach │ │ Metrics still   │    │
│  │ relevant?│ │ aligned?  │ │ valid?   │ │ appropriate?    │    │
│  └──────────┘ └───────────┘ └──────────┘ └─────────────────┘    │
│                                                                 │
│  Then:                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 9. Verification plan:                                     │  │
│  │    a. Failure modes (3 types per item):                   │  │
│  │       Read TRACKING §Failure Mode History first           │  │
│  │       Check escalation triggers (category 2+/3 sprints    │  │
│  │       → Architecture Review; visual 2+ → proxy test)      │  │
│  │       • Direct  • Interaction  • Stress/edge              │  │
│  │       >=1 per category, each with metric or test          │  │
│  │       Write to TRACKING §Predicted Failure Modes          │  │
│  │    b. How verified? (unit/integration/manual, invariants) │  │
│  │    c. Metric sufficiency (measurable? non-trivial? 9a     │  │
│  │       coverage? gap → add metric, update roadmap)         │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────────────────────┐ │
│  │ 10.Scope │ │ 11.Impl  │ │ 12. Gate assessment + report:     ││
│  │ check    │ │ order    │ │  a. Write S<N>_ENTRY_GATE.md     │ │
│  └──────────┘ └──────────┘ │  b. AI own assessment + recommend│ │
│                             │  c. User approves — reviews 9b   ││
│                             │     quality ("trivial?" → revise)││
│                             │  d. Log + update (post-approval) ││
│                             └──────────────────────────────────┘│
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
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  A. Pre-code check                                      │    │
│  │     Mark item `in_progress` in TRACKING.md              │    │
│  │     Read guardrails sections relevant to task type      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  B. Write code                                          │    │
│  │     Follow guardrails + immutable contracts             │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  C. Self-verify (5-point checklist)                     │    │
│  │     ┌──────────────────────────────────────────────┐    │    │
│  │     │ □ Builds/parses without errors? *            │    │    │
│  │     │ □ Matches spec?                              │    │    │
│  │     │ □ No duplication?                            │    │    │
│  │     │ □ Follows conventions?                       │    │    │
│  │     │ □ Tech debt? → fix now or document           │    │    │
│  │     │                                              │    │    │
│  │     │ * compiled: compiles; interpreted: linter/   │    │    │
│  │     │   syntax check; no tooling: manual review    │    │    │
│  │     └──────────────────────────────────────────────┘    │    │
│  │                        │                                │    │
│  │              ┌─────────┴─────────┐                      │    │
│  │              │ All pass?         │                      │    │
│  │              │  NO → fix, recheck│                      │    │
│  │              │  (max 3 rounds;  │                      │    │
│  │              │   still failing → │                      │    │
│  │              │   escalate to     │                      │    │
│  │              │   user)           │                      │    │
│  │              │  YES ↓            │                      │    │
│  │              └───────────────────┘                      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  D. Write tests                                         │    │
│  │     ┌────────────────────────────────────────────┐      │    │
│  │     │ Unit-testable logic ────► Unit test        │      │    │
│  │     │ Integration/async ──────► Integration test │      │    │
│  │     │ Visual/UI ────────────► Manual + screenshot│      │    │
│  │     │                                            │      │    │
│  │     │ Each test must encode Entry Gate 9b        │      │    │
│  │     │ invariants. Trivial tests ("it runs",      │      │    │
│  │     │ "no exception") are not acceptable —       │      │    │
│  │     │ apply same criteria as Entry Gate 12c.     │      │    │
│  │     └────────────────────────────────────────────┘      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  D.5 Visual Verification (visual items only)            │    │
│  │     Trigger: item marked "manual+screenshot" in 9b      │    │
│  │     ┌────────────────────────────────────────────┐      │    │
│  │     │ 1. AI asks specific visual questions       │      │    │
│  │     │ 2. User runs, responds:                    │      │    │
│  │     │    "OK" → proceed                          │      │    │
│  │     │    "Problem" → log CORE-###, AI fixes,     │      │    │
│  │     │    ask user again (resolved = user         │      │    │
│  │     │    confirms "OK"; max 3 attempts, then     │      │    │
│  │     │    log as known gap with target sprint)    │      │    │
│  │     │ 3. Automated proxy test exists?            │      │    │
│  │     │    → still ask user for visual confirm     │      │    │
│  │     └────────────────────────────────────────────┘      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  D.6 Incremental test run                               │    │
│  │     Run ALL tests written so far (this item +           │    │
│  │     all previous items in this sprint).                 │    │
│  │     ┌────────────────────────────────────────────┐      │    │
│  │     │ PASS → proceed to E                    │      │    │
│  │     │ FAIL (new test) → fix impl, rerun     │      │    │
│  │     │ FAIL (prev item test) → regression:   │      │    │
│  │     │   fix before adding more code         │      │    │
│  │     │ max 3 fix attempts → escalate to user │      │    │
│  │     │                                       │      │    │
│  │     │ Test needs unavailable infra?         │      │    │
│  │     │ → mark "pending" in TRACKING.md       │      │    │
│  │     │ → run at Close Gate Phase 3           │      │    │
│  │     └────────────────────────────────────────┘      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  E. Update TRACKING.md                                  │    │
│  │     Mark item fixed (in_progress → fixed), log decisions│    │
│  │     If bugs/failures encountered during this item:      │    │
│  │     → log to §Failure Encounters (item, category,       │    │
│  │       description, detection method)                    │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                             │                                   │
│                    ┌────────┴────────┐                          │
│                    │ All Must done?  │                          │
│                    │  NO → next item │────► loop back           │
│                    │  YES ↓          │                          │
│                    └─────────────────┘                          │
│                             │                                   │
│                    ┌────────┴────────┐                          │
│                    │ Budget left? *  │                          │
│                    │  YES → Should/  │────► same loop           │
│                    │        Could    │                          │
│                    │  NO → close     │                          │
│                    └─────────────────┘                          │
│                                                                 │
│  * Budget = user willingness to continue. Ask: "Must items      │
│    done. Should/Could, or close sprint?" User decides.          │
└─────────────────────────────────────────────────────────────────┘
                             │
           ══════════════════╪═══════════════
                     CLOSE GATE
           ══════════════════╪═══════════════
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PRESENTATION RULE                                              │
│  Phases 0/1a/1b/2/4 = transparency checkpoints, not approvals  │
│  Clean/minimal → batch into one report, no pause needed         │
│  Blocker/regression/MISSED → stop, present, ask                 │
│  Mandatory approval: verdict only                               │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 0 — Metric Gate Sufficiency                              │
│                                                                 │
│  For each sprint metric (every item has a metric gate):          │
│  □ Measurable with current infrastructure?                      │
│  □ Test evidence sufficient?                                    │
│  □ Threshold reasonable for current scale?                      │
│  □ Failure mode coverage per modified subsystem?                │
│    • Direct (item-internal) — >=1 identified?                   │
│    • Interaction (cross-system) — >=1 identified?               │
│    • Stress/edge (extreme-condition) — >=1 identified?          │
│    Each mode has metric or test? Missing → add or document gap  │
│                                                                 │
│  OUTPUT: Structured Metric Verification table                   │
│  Every metric → PASS / DEFERRED / FAIL / MISSING                │
│  Empty cells or MISSING/FAIL → gate BLOCKED (cannot proceed)    │
│  Present completed table to user before proceeding to Phase 1a  │
│  Log compact summary to TRACKING (not full table):              │
│    "Metric Verification: X/Y PASS, Z DEFERRED (id → S<N>)"     │
│                                                                 │
│  FAIL: unmeasurable + no evidence → fix scope                   │
│  PARTIAL: blocked by unfinished prerequisite?                   │
│  → escalate: explain gap, propose target sprint, user decides   │
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
│  │  1. Scaffolding tags (// TEMP, // TODO, // HACK)           │ │
│  │  2. Observability coverage (logging/profiling in key ops)  │ │
│  │  3. Hot path allocations (new T[] in loops/update)         │ │
│  │  4. Cached reference violations (repeated lookups)         │ │
│  │  5. Framework anti-patterns (language/framework-specific)  │ │
│  │  6. Resource guard (close/dispose/cleanup missing)         │ │
│  │  7. Contract violations (project-specific forbidden API)   │ │
│  │  8. String allocation in hot paths                         │ │
│  │  9. Test coverage gap (source file ↔ test file match)      │ │
│  │ 10. API parity (same config set at all call sites)         │ │
│  │ 11a.Roadmap sync (item ID ↔ checkbox status)               │ │
│  │ 11b.Orphan detection (items in one file but not other)     │ │
│  │ 11c.Checkbox format (CORE-### without - [ ] syntax)        │ │
│  │ 12. Metric coverage (roadmap metric ↔ test evidence)      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Exit codes: 0=clean, 1=findings, 2=setup error (fix script)    │
│  Output: WARN (dismissible) + BLOCKER (non-dismissible)          │
│  BLOCKER = metric without test (Section 12) — cannot mark as FP  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1b — Spec-driven Audit (semantic, script can't catch)    │
│                                                                 │
│  Load Entry Gate data first:                                    │
│  → TRACKING §Predicted Failure Modes (Entry Gate 9a)            │
│  → S<N>_ENTRY_GATE.md verification plan per item (9b)           │
│                                                                 │
│  Per completed item (Must + Should + Could):                    │
│  a. Find implementing files (git diff if VCS=git, else Entry    │
│     Gate notes / user confirmation if VCS=none)                 │
│  b. Predicted failure modes → handled in code?                  │
│     • Direct (item-internal): null ref, off-by-one, wrong calc  │
│     • Interaction (cross-system): timing, shared state, order   │
│     • Stress/edge: exhaustion, cascade, rapid oscillation       │
│  c. Entry Gate 9b invariants → enforced in implementation?      │
│                                                                 │
│  Supplemental per-file (issues outside item scope):             │
│  1. Resource/memory leaks                                       │
│  2. Missing observability (logging, profiling)                  │
│  3. Dead code / orphan scaffolding                              │
│  4. Debug/prod path parity                                      │
│                                                                 │
│  OUTPUT: per-item (CORE-### → modes: HANDLED/MISSED/N/A)        │
│          + supplemental findings per file                       │
│  Present to user before proceeding to Phase 2                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2 — Fix                                                  │
│  Each finding: fix immediately OR log with target sprint        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3 — Regression Test                                      │
│  All tests PASS after Phase 2 fixes (no regressions).           │
│  Include any tests marked "pending" during D.6 that can         │
│  now execute (infra available at Close Gate).                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 4 — Test Coverage Gap                                    │
│  4a. File-level: new/modified code → test file exists?          │
│  4b. Item-level: every completed item → behavioral test exists? │
│      Log: ID → test name(s) in TRACKING.md evidence             │
│  Final test run PASS (including new tests).                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │ All phases pass?            │
              │  NO  → fix, re-run          │
              │  (max 2 full re-runs; still │
              │   failing → escalate to user│
              │   with remaining findings)  │
              │  YES ↓                      │
              └──────────────┬──────────────┘
                             │
                             ▼
              ┌──────────────────────────────┐
              │ Close Gate verdict:          │
              │  AI assessment (metrics,     │
              │  findings, risk, recommend)  │
              │  User approves → close       │
              │  User rejects → rework phase │
              └──────────────┬──────────────┘
                             │
           ══════════════════╪═══════════════
                    SPRINT CLOSE
           ══════════════════╪═══════════════
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. Roadmap checkmarks                                          │
│     → Run sprint-audit.sh (focus on Section 11 sync output)     │
│     → Fix all mismatches before ticking                         │
│     [x] = TRACKING.md verified (gate evidence logged)           │
│     [~] = skipped + reason documented inline                    │
│     [ ] = not verified (open, in_progress, or fixed)            │
│                                                                 │
│  2. TRACKING.md update                                          │
│     All Must verified; completed Should/Could also updated      │
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
│  6. Workflow integrity check                                    │
│     → CLAUDE.md refs match target file sections?                │
│     → Guardrails pointer matches workflow content?              │
│     → Verify numbered steps have corresponding actions          │
│     → Mismatch → fix before closing sprint                      │
│                                                                 │
│  7. Failure mode retrospective                                  │
│     a. Reconstruct actual failures from Sprint Board +          │
│        Change Log + §Failure Encounters                         │
│     b. Read TRACKING §Predicted Failure Modes (from 9a)         │
│     c. Fill structured retrospective table:                     │
│        predicted mode + actual? + detection + root cause        │
│        Every predicted mode answered. Every failure listed.     │
│     d. Transfer to TRACKING §Failure Mode History               │
│     e. Unpredicted → new guardrail (follow §Update Rule)        │
│     f. Check escalation triggers → flag in §Open Risks:         │
│        same category 2+/3 sprints → Architecture Review         │
│        same visual 2+ → proxy test question                     │
│     g. Present retrospective table to user                      │
│                                                                 │
│  8. Failure Mode History maintenance                            │
│     → >30 rows? Archive older entries to Docs/Archive/          │
│                                                                 │
│  9. Entry Gate report cleanup                                   │
│     → Delete Docs/Planning/S<N>_ENTRY_GATE.md                   │
│     → TRACKING.md gate log persists as permanent record         │
│                                                                 │
│ 10. User handoff summary (per completed item):                  │
│     → Before/after: behavior change (1-2 sentences)            │
│     → How: implementation in one sentence (user-level)          │
│     → Where: file / Inspector path                              │
│     → Verify: runtime action + expected result                  │
│     → Should NOT change: regression check                       │
│     Invisible sprint? → state explicitly + name diagnostic      │
│     Present before marking done. Never skip.                    │
│                                                                 │
│ 11. Sprint "done"                                               │
│     Log: "Sprint Close: [date], steps 1-11 ✓"                   │
│     ──────────► next sprint Entry Gate                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Generic sprint-audit.sh Template

Adapt this script to any language/framework. Replace grep patterns with
project-specific equivalents.

```bash
#!/usr/bin/env bash
set -uo pipefail
# Note: -e is intentionally omitted. Individual check failures should not abort
# the entire audit. Each section handles its own errors with || true.

# sprint-audit.sh — Automated sprint close gate checks
# Adapt the patterns below to your project's language and framework.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/src"         # ← adjust to your source directory
TEST_DIR="$ROOT/tests"      # ← adjust to your test directory

total=0
errors=0
blockers=0    # Non-dismissible findings (cannot be marked as false positive)

# Verify required directories exist
for dir_var in SRC_DIR TEST_DIR; do
  dir_val="${!dir_var}"
  if [[ ! -d "$dir_val" ]]; then
    echo "ERROR  $dir_var ($dir_val) does not exist. Adjust path in script header."
    errors=$((errors + 1))
  fi
done

check() {
  local name="$1" pattern="$2" dir="${3:-$SRC_DIR}"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP  $name — directory $dir not found"
    return
  fi
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

# 11. Roadmap ↔ TRACKING.md sync
echo ""
echo "ROADMAP SYNC:"
TRACKING_FILE="$ROOT/TRACKING.md"
ROADMAP_FILE="$ROOT/Docs/Planning/Roadmap.md"  # ← adjust path
ID_PATTERN="CORE-[0-9]+"                        # ← adjust to your item ID format
sync=0

if [[ -f "$TRACKING_FILE" ]] && [[ -f "$ROADMAP_FILE" ]]; then
  declare -A tracking_status
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    if [[ -n "$item_id" ]]; then
      if echo "$line" | grep -qiw "verified"; then
        tracking_status["$item_id"]="verified"
      elif echo "$line" | grep -qiw "fixed"; then
        tracking_status["$item_id"]="fixed"
      elif echo "$line" | grep -qiw "in_progress"; then
        tracking_status["$item_id"]="in_progress"
      elif echo "$line" | grep -qiw "blocked"; then
        tracking_status["$item_id"]="blocked"
      elif echo "$line" | grep -qiw "deferred"; then
        tracking_status["$item_id"]="deferred"
      elif echo "$line" | grep -qiw "open"; then
        tracking_status["$item_id"]="open"
      fi
    fi
  done < <(grep -E "$ID_PATTERN" "$TRACKING_FILE" | grep -E "open|in_progress|fixed|verified|deferred|blocked" || true)

  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    is_checked=false
    is_skipped=false
    echo "$line" | grep -qE "^\s*-\s*\[x\]" && is_checked=true
    echo "$line" | grep -qE "^\s*-\s*\[~\]" && is_skipped=true
    t_status="${tracking_status[$item_id]:-unknown}"
    if $is_checked && [[ "$t_status" != "verified" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[x] but TRACKING=$t_status (premature tick)"
      sync=$((sync + 1))
    elif ! $is_checked && ! $is_skipped && [[ "$t_status" == "verified" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[ ] but TRACKING=verified (forgotten tick)"
      sync=$((sync + 1))
    elif $is_skipped && [[ "$t_status" != "deferred" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[~] but TRACKING=$t_status (should be deferred)"
      sync=$((sync + 1))
    elif ! $is_skipped && [[ "$t_status" == "deferred" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[ ] but TRACKING=deferred (missing [~] mark)"
      sync=$((sync + 1))
    fi
  done < <(grep -E "\- \[.\].*$ID_PATTERN" "$ROADMAP_FILE" || true)
  [[ $sync -eq 0 ]] && echo "  All checkboxes consistent."

  # 11b. Orphan detection — items in one file but not the other
  echo ""
  echo "ORPHAN CHECK:"
  orphans=0

  # Items in TRACKING but not in Roadmap
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    if ! grep -q "$item_id" "$ROADMAP_FILE" 2>/dev/null; then
      echo "  ORPHAN $item_id: exists in TRACKING but not in Roadmap"
      orphans=$((orphans + 1))
    fi
  done < <(grep -E "$ID_PATTERN" "$TRACKING_FILE" 2>/dev/null | head -200 || true)

  # Items in Roadmap but not in TRACKING
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    if ! grep -q "$item_id" "$TRACKING_FILE" 2>/dev/null; then
      echo "  ORPHAN $item_id: exists in Roadmap but not in TRACKING"
      orphans=$((orphans + 1))
    fi
  done < <(grep -E "$ID_PATTERN" "$ROADMAP_FILE" 2>/dev/null | head -200 || true)

  [[ $orphans -eq 0 ]] && echo "  No orphan items found."
  total=$((total + orphans))

  # 11c. Checkbox format check — detect CORE-### items without checkbox
  echo ""
  echo "CHECKBOX FORMAT CHECK:"
  fmt_errors=0
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    # Skip lines that already have checkbox format
    echo "$line" | grep -qE "^\s*-\s*\[.\]" && continue
    echo "  FORMAT $item_id: missing checkbox — use '- [ ] $item_id: ...' (breaks close gate tracking)"
    fmt_errors=$((fmt_errors + 1))
  done < <(grep -E "$ID_PATTERN" "$ROADMAP_FILE" 2>/dev/null | grep -E "^\s*-\s" | head -200 || true)
  [[ $fmt_errors -eq 0 ]] && echo "  All roadmap items have checkbox format."
  total=$((total + fmt_errors))
fi
total=$((total + sync))

# 12. Metric ↔ Test Coverage
# Each roadmap metric must have a matching test in TEST_DIR.
# Handles two formats:
#   Format A: "Metric: description" or "**Metric:** description"
#   Format B: Bullet lines under "**Metric gates:**" header
echo ""
echo "METRIC COVERAGE:"
metric_gaps=0

if [[ -f "$ROADMAP_FILE" ]]; then
  metric_lines=$(awk '
    /[Mm]etric[s]?[[:space:]]*[:：]/ && !/[Mm]etric[[:space:]]+gate/ { print; next }
    /[Mm]etric[[:space:]]+gate/ { in_gate=1; next }
    in_gate && /^[[:space:]]*-[[:space:]]/ { print; next }
    in_gate && /^[[:space:]]*$/ { next }
    in_gate { in_gate=0 }
  ' "$ROADMAP_FILE" 2>/dev/null)

  if [[ -z "$metric_lines" ]]; then
    echo "  (no metric lines found in Roadmap — check format)"
  else
    while IFS= read -r mline; do
      if echo "$mline" | grep -qiE "[Mm]etric[s]?\s*[:：]"; then
        metric_desc=$(echo "$mline" | sed -E 's/.*[Mm]etric[s]?\s*[:：]\s*//' | sed 's/[*`]//g' | xargs)
      else
        metric_desc=$(echo "$mline" | sed -E 's/^\s*-\s*//' | sed 's/[*`]//g' | xargs)
      fi
      [[ -z "$metric_desc" ]] && continue
      keywords=$(echo "$metric_desc" | tr '[:upper:]' '[:lower:]' | \
        sed -E 's/[^a-z0-9 ]/ /g' | tr ' ' '\n' | \
        grep -vE '^(the|a|an|is|are|be|to|of|in|for|and|or|no|not|with|must|should|each|per|all|any|same|than|from|has|have|does|when|will|can|at|by)$' | \
        grep -E '.{3,}' | sort -u | head -8)
      found=false
      for kw in $keywords; do
        if grep -rli "$kw" "$TEST_DIR" --include="*.${EXT:-*}" 2>/dev/null | grep -q .; then
          found=true; break
        fi
      done
      if ! $found; then
        echo "  BLOCKER  NO TEST: $metric_desc"
        metric_gaps=$((metric_gaps + 1))
      fi
    done <<< "$metric_lines"
  fi
  [[ $metric_gaps -eq 0 ]] && echo "  All metrics have test coverage."
  [[ $metric_gaps -gt 0 ]] && echo "  $metric_gaps BLOCKER(s) — not false-positive-eligible. Write tests or escalate."
fi
total=$((total + metric_gaps))
blockers=$((blockers + metric_gaps))

# ── Summary ──
echo ""
if [[ $errors -gt 0 ]]; then
  echo "Sprint audit: $errors setup error(s) — fix script configuration before audit."
  exit 2
elif [[ $total -eq 0 ]]; then
  echo "Sprint audit CLEAN — 0 findings."
  exit 0
elif [[ $blockers -gt 0 ]]; then
  echo "Sprint audit: $total finding(s), $blockers BLOCKER(s) — gate cannot close."
  echo "BLOCKER findings require action (write test or escalate). Cannot be dismissed."
  exit 1
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
Document loading order (sequential — each step depends on the previous):

1. CLAUDE.md is auto-loaded (contains checkpoint + contracts)
   → Tells you: project context, immutable contracts, what happened last session
2. Read TRACKING.md → understand current state
   → Tells you: which items are open/in_progress/blocked, current sprint, blockers
   → If TRACKING.md is malformed (broken table, parse errors):
     reconstruct from last known good state (git history if VCS=git) or ask user to verify.
3. Read Roadmap → understand current sprint scope
   → Tells you: Must/Should/Could for current sprint
4. Decide session mode:
   a. New sprint (no in_progress items, previous sprint done) → run Entry Gate
   b. Mid-sprint (in_progress or open items exist) → resume from TRACKING.md
   c. Interrupted session (in_progress items exist) → verify code state matches
      TRACKING status. If code was written but TRACKING not updated, update status.

Do NOT read SPRINT_WORKFLOW.md every session — only at sprint boundaries (Entry/Close Gate).
Do NOT read GUARDRAILS.md in full — only §Index → relevant sections per task.
```

### Interruption Handling

```
Three interruption types and how to handle each:

1. User asks a question mid-task (same session, context intact)
   → Answer the question fully.
   → Then state explicitly: "I was at [step / item / phase]. Continue?"
   → Wait for user confirmation before resuming.
   → Do NOT silently resume — the user may have changed direction.

2. AI stopped and restarted (same session, context intact)
   → Read TRACKING.md to confirm last recorded status.
   → State what was in_progress and what sub-step you were on (best estimate).
   → Verify code state matches TRACKING status before continuing.
   → If ambiguous: ask user rather than guess.

3. Session closed (context lost — new session)
   → Follow Session Start Protocol above.
   → CLAUDE.md Last Checkpoint + TRACKING.md item statuses are the
     authoritative record. Code on disk is the ground truth.
   → If TRACKING shows in_progress but you have no context about
     which sub-step: start that item's implementation loop from step A
     (read guardrails) — safer than guessing mid-item state.
```

### During Implementation

```
- Read guardrails BEFORE writing code (not after)
- Self-verify EVERY code block (5-point checklist)
- Run ALL tests written so far after each item (D.6) — do not accumulate failures across items
- Update TRACKING.md after every significant change
- Never skip self-verification or D.6 incremental test run to "save time"
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
│   Load all of S<N>_ENTRY_GATE.md at once — read        │
│   only the relevant item's section per task             │
└─────────────────────────────────────────────────────────┘

Session boundaries:
  Entry Gate    → heavy context use (analysis + source reads)
  Implementation → light start (CLAUDE.md + TRACKING.md only)
  Close Gate    → heavy context use (audit reads source + entry gate data)
  Sprint Close  → lightweight (file updates, archive, retrospective)

  Recommended transitions (if context is limited):
    After Entry Gate approval  → new session for implementation ("Continue sprint N")
    Before Close Gate          → new session ("Run Close Gate, sprint N")
    Close Gate + Sprint Close  → same session is fine (Sprint Close is lightweight)
  Long context window? Same session throughout is fine.
  S<N>_ENTRY_GATE.md persists on disk — no context loss across sessions.
```

### Guardrail Evolution

```
Bug discovered
      │
      ▼
┌──────────────┐     ┌────────────────────┐
│ Fix the bug  │────►│ Check: rule exists │
└──────────────┘     │ in LESSONS_INDEX?  │
                     └────────┬───────────┘
                      no      │      yes
                 ┌────────────┴────────────┐
                 ▼                         ▼
        ┌────────────────────┐   ┌─────────────────┐
        │ Add guardrail rule │   │ Strengthen       │
        │ (never-again)      │   │ existing rule    │
        └────────┬───────────┘   └─────────────────┘
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
        └────────┬───────────┘
                 │
                 ▼
        ┌────────────────────┐
        │ Add entry to       │
        │ LESSONS_INDEX.md   │
        └────────────────────┘

Guardrails grow organically from real bugs.
Never add hypothetical rules — only rules from production experience.
```

### Workflow Evolution — "Who Watches the Watchers?"

```
AI will always find something to improve in this workflow.
That is not sufficient reason to change it.

Before adding any new step, check, or verification layer:

  1. Does it catch a real, observed failure that NO existing
     mechanism currently catches?
     NO → do not add it.

  2. Is the failure it catches worth the overhead it adds
     to every future sprint?
     NO → do not add it.

  3. Does it verify that a previous check RAN,
     rather than catching a new class of failure?
     YES → do not add it. This is "who watches the watchers."

Complexity is a cost paid on every sprint.
The right amount is the minimum that handles real, observed problems.

If the user asks "can we improve X?":
  → First ask: what real failure would this prevent?
  → If no concrete answer exists → the answer is no.

When running a gap analysis or workflow review:
  → Apply the 3-question test to EACH finding before presenting it.
  → Do not surface a finding that fails any of the 3 questions.
  → Present only findings that represent real, observable failures
    with clear overhead justification.
  → Filtering is the AI's job — not the user's.
```

---

## State Transitions

### Item Lifecycle

```
  open ─── work started ───► in_progress ─── implementation done ───► fixed ─── test evidence ───► verified
    │                             │                                     │                              │
    │ (dependency                 │ (external blocker)                  │ (rework needed               │ (regression found)
    │  discovered)                ▼                                     │  before verification)        │
    │                         blocked                                   ▼                              │
    │                             │ (blocker resolved)              in_progress                        │
    └──► blocked                  └──► in_progress                  (re-fix cycle)                    │
                                                                                                      │
                                                                        open ◄────────────────────────┘
                                                                        (log reason in Change Log)
  Any status ──► deferred (intentional skip, requires reason + target sprint)
```

### Sprint Lifecycle

```
  planned → entry gate PASS → in progress → Must done → close gate PASS → done → next sprint (planned)
                │                   │                        │
                │ (fail)            │ (user aborts)          │ (fail)
                └── flag to user,   └──► aborted             └── fix, re-run
                    user decides         (abbreviated close)
```

### Document Update Triggers

```
┌──────────────────┬───────────────────────────────────────────────┐
│ Event            │ Update                                        │
├──────────────────┼───────────────────────────────────────────────┤
│ Work started     │ TRACKING.md (status → in_progress)            │
│ Bug fixed        │ TRACKING.md (status → fixed)                  │
│ Bug verified     │ TRACKING.md (status → verified + evidence)    │
│ Item blocked     │ TRACKING.md (status → blocked + risk entry)   │
│ Item deferred    │ TRACKING.md (status → deferred + reason)      │
│ Regression found │ TRACKING.md (verified → open + change log)    │
│ New rule found   │ GUARDRAILS.md (rule + anti-pattern) +         │
│                  │ LESSONS_INDEX.md (traceability entry)          │
│ Sprint starts    │ TRACKING.md (Current Focus)                   │
│ Sprint closes    │ Roadmap (checkmarks), CLAUDE.md (checkpoint)  │
│ Sprint archived  │ Docs/Archive/changelog-S<N>.md                │
│ Decision made    │ TRACKING.md (change log)                      │
│ Tech debt found  │ TRACKING.md (new ID, forward note)            │
│ Scope change     │ TRACKING.md (change log + new/modified items) │
│ Contract revised │ CLAUDE.md §Immutable Contracts + change log   │
│ Sprint aborted   │ TRACKING.md (items → deferred + change log)   │
│ Entry Gate run   │ Docs/Planning/S<N>_ENTRY_GATE.md (created)    │
│ Sprint closed    │ Docs/Planning/S<N>_ENTRY_GATE.md (deleted)    │
│ Failure logged   │ TRACKING.md §Failure Encounters               │
│ Perf baseline    │ TRACKING.md (metrics recorded, compare prev)  │
└──────────────────┴───────────────────────────────────────────────┘
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
    □ Predicted Failure Modes section (Entry Gate 9a writes, Sprint Close 7 reads)
    □ Failure Encounters section (implementation logging, Sprint Close 7a reads)
    □ Failure Mode History section (Sprint Close 7d writes, Entry Gate 9a reads)
    □ Change Log section

□ Docs/CODING_GUARDRAILS.md exists with:
    □ Section Index (task type → sections to read)
    □ At least one real rule (from first bug found)
    □ Entry Gate procedure
    □ Close Gate procedure
    □ Anti-pattern quick reference table

□ Docs/LESSONS_INDEX.md exists with:
    □ RuleID / Root Cause / Guardrail Section / Sprint / Source table
    □ Starts empty on new projects (grows as bugs are found)

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

Abbreviated Entry Gate for small projects:
- Phase 0: run if sprint is a sketch (same as full workflow)
- Phase 1: steps 1-2 only (read TRACKING + Roadmap). Skip deferred item review and guardrails index.
- Phase 2: skip entirely
- Phase 3: steps 8 + 10 + 12 only (strategic alignment, scope check, confirm).
  Skip failure mode analysis (step 9a) — overhead exceeds value for <=5 items.
  Skip verification plan detail (step 9b-c) — cover in self-verify during implementation.

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
| Entry Gate | Abbreviated (Phase 0 + 1 + 3) | Full (phases 0-3) |
| Close Gate | Full (quality is non-negotiable) | Full + peer sign-off |
