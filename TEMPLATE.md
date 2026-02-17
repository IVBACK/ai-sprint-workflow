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
   c. Detail Sprint 1 only: Must items with CORE-### IDs
      (later sprints stay as one-line sketches — they will be detailed when reached)
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
| 2 | Sprint scope size? (small: 3-5 / medium: 5-8 / large: 8-12) ² | Entry gate scope threshold | Medium (5-8) |
| 3 | Existing roadmap or task list? (No / Yes / Scattered) ³ | Avoid duplicate planning docs | No → create Roadmap.md ³ |
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

**Workflow Preferences:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 10 | Language for docs and commit messages? | Consistency across project | English |
| 11 | Preferred commit style? (conventional, free-form) | Commit message format in rules | Free-form |
| 12 | Anything that must NEVER change? (API contracts, data formats) | Seed "Immutable Contracts" in CLAUDE.md | None → discover during implementation ⁵ |
| 13 | Anything else the AI should know? | Catch requirements not covered above | None |

> ⁵ **Q12 details:** "None identified yet — to be discovered during implementation" is valid
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

## Immutable Contracts

[List things that MUST NOT change without explicit architectural revision]
- [Data format: ...]
- [API contract: ...]
- [Convention: ...]
- [Build target: ...]

## Operational Rules

- Update `TRACKING.md` after every significant fix/decision.
- `fixed → verified` transition requires evidence (test run ID + results). Full flow: open → in_progress → fixed → verified.
- Check `Docs/CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Roadmap checkbox `[x]` only when item is `verified` in TRACKING.md. `[~]` only when `deferred`. Intermediate states (in_progress, fixed-untested) are not shown in roadmap — TRACKING.md is the single source. `sprint-audit.sh` Section 11 catches mismatches automatically.
- Sprint close gate:
  - Run `Tools/sprint-audit.sh` (automated scan, 11 sections).
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
- `Docs/SPRINT_WORKFLOW.md` §Entry Gate (4 phases, 12 steps) — read and execute. No code before plan is confirmed.

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

Written at Entry Gate step 9d. Read at Sprint Close step 7 (retrospective comparison).
Replace this section at each new sprint's Entry Gate.

| Item | Category | Predicted Mode | Detection Plan |
|------|----------|---------------|----------------|

## Failure Mode History

Written at Sprint Close step 7 (retrospective). Read at Entry Gate step 9d (failure mode analysis).
Pattern rules:
- Same category 2+ times in last 3 sprints → Architecture Review Required at next Entry Gate.
- Same detection=user-visual 2+ times → "Can an automated proxy test replace visual check?" mandatory question at next Entry Gate.

| Sprint | Category | Predicted? | Detection | Mode | Impact | Root Cause | Guardrail | Escalate? |
|--------|----------|------------|-----------|------|--------|------------|-----------|-----------|

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

**Phase 0 — Sprint Detail (conditional):**
*(Skip if this sprint already has Must/Should/Could items in the Roadmap.)*
If the sprint is still a one-line sketch from Initial Planning:
0a. Read the sketch description + previous sprint's outcomes
0b. Decompose into Must/Should/Could items with CORE-### IDs
0c. Add metric gates for each Must item
0d. Priority & rigor review — two passes:
    **Pass 1 — Distribution check (on initial 0b decomposition, before any promotions):**
    - All items in Must? → decomposition didn't actually prioritize — re-sort.
    - Zero Should/Could? → check if Must includes nice-to-haves that should move down.
    - Must item has no dependencies and no metric? → should it be Should?
    Flag misplacements to user with reasoning. User decides final placement.
    **Pass 2 — Should/Could rigor scan (after distribution is validated):**
    Q1: Would removing this item cause a Must item's metric gate to FAIL?
        YES → promote to Must. It was misclassified — it's a real dependency.
        NO  → continue to Q2.
    Q2: Does this item have its own metric gate, complex failure modes (multi-step,
        cross-system), or interact with Must items in non-trivial ways?
        YES → mark as **Must-gated** (★). Stays Should/Could (not sprint-blocking)
              but receives Must-level Entry Gate rigor (steps 8, 9c, 9d apply).
        NO  → normal Should/Could. Light gate only.
    Post-promotion Must count may exceed initial count — this is valid.
    These are verified dependencies, not lazy grouping.
0e. Present detailed sprint plan to user for approval before proceeding to Phase 1
This is the same process as Initial Planning step 4, applied to the next sprint.
If items exceed scope limit → apply §Scope Negotiation.

**Phase 1 — State Review (read-only):**
1. Read TRACKING.md → open items, blockers, in_progress items from interrupted sessions
2. Read Roadmap → Must/Should/Could for this sprint
3. Check deferred/blocked items from previous sprints — carry forward or drop (user decides)
4. Identify applicable GUARDRAILS sections

**Phase 2 — Dependency Verification (read-only):**
*(Sprint 1: skip this phase — no prior sprints exist.)*
5. Verify dependency sprints are closed.
   Partial completion rule: if a dependency sprint has `deferred` items, check whether
   the current sprint actually depends on those specific items. If not → dependency met.
   If yes → flag to user: "Sprint N depends on [deferred item] — resolve before proceeding?"
6. Read dependency API source files, confirm contracts match
7. List open architectural decisions

**Phase 3 — Strategic Validation & Confirmation:**
8. Strategic alignment check — for each Must item + Must-gated Should/Could:
   a. Still relevant? (superseded, already delivered?)
   b. Goal alignment? (does it serve core project goals?)
   c. Approach still valid? (has new info invalidated the method?)
   d. Metrics still appropriate? (measuring the right thing?)
   Non-gated Should/Could: quick relevance check only (a. still relevant?).
   If any fails → flag to user with evidence + options (keep/modify/defer/remove).
   AI does not unilaterally change sprint scope — user decides.
9. Verification plan:
   a. Can all metrics be measured by sprint end?
   b. For each item: how will behavior be verified? (unit test / integration test / manual + screenshot)
      Algorithmic items: what invariants must hold? (mathematical properties, reference output, determinism)
      "It runs" ≠ "it is correct".
   c. Item has no metric gate? Propose one and add to roadmap. User approves before sprint starts.
      Applies to: all Must items + Must-gated Should/Could. Non-gated Should/Could: skip.
   d. Failure mode analysis (per Must item + Must-gated Should/Could):
      First: read TRACKING.md §Failure Mode History — which categories failed before?
      Then: list known failure modes in 3 categories:
      - Direct: item breaks on its own (wrong calc, null ref, off-by-one)
      - Interaction: 2+ systems combine to fail (pool + dispatch + timing)
      - Stress/edge: invisible in normal use (rapid oscillation, pool exhaustion, cascade)
      Each category: >=1 mode. Each mode: metric or test that detects it? Missing → add to plan.
      Write predictions to TRACKING.md §Predicted Failure Modes (step 7 reads this).
10. Is scope realistic? (1-8 Must items. 0 Must → sprint is empty, redesign or skip.)
11. Produce dependency-ordered implementation list
12. Gate assessment, report & user approval
    a. Write full Entry Gate report to `Docs/Planning/S<N>_ENTRY_GATE.md`
       Contains: complete analysis from phases 0-3 (state review, dependency/API checks,
       strategic alignment, failure modes, implementation order, etc.)
       This file serves as a living reference during the sprint and is deleted at Sprint Close.
    b. Add reference to TRACKING.md: "Entry Gate report: Docs/Planning/S<N>_ENTRY_GATE.md"
    c. AI provides its own gate assessment before asking for approval:
       - **Blocker summary:** any step that failed or raised concerns? (list or "none")
       - **Risk assessment:** clean / attention points exist (list them) / blocker found
       - **Scope assessment:** conservative / reasonable / aggressive
       - **Key watch items:** implementation-time risks that aren't gate blockers
         but require careful attention (e.g., specific interaction risks from Architecture Review)
       - **Recommendation:** "Gate passed — recommend proceeding" or "Gate blocked by [X]"
    d. Log to TRACKING.md: "Entry Gate: [date], phases 0-3 ✓ (steps executed: [list])"
    e. User approves before coding begins

---

## Close Gate — Sprint-End Audit

**Phase 0 — Metric gate check:**
- Can each metric be measured? Evidence exists? (Must items + Must-gated Should/Could)
- Failure mode coverage: for each modified subsystem, are failure modes listed in 3 categories (direct / interaction / stress-edge)? Each has a metric or test? Missing → add, or document as known gap with target sprint.
- Unmet metric escalation — when a metric is partially met or blocked:
  Do NOT silently mark `[ ]` and move on. Required steps:
  1. **Explain** — what is blocking completion? (missing data, unfinished prerequisite, external dependency)
  2. **Trace** — is the blocker tracked in the roadmap? (has a CORE-### entry?)
     - Not tracked → propose adding it with a recommended sprint and priority level.
     - Tracked but no sprint assigned → propose a target sprint with reasoning.
  3. **Recommend** — present the gap analysis and a concrete proposal to the user.
     Include: what's done, what's missing, which sprint should finish it, and why.
  4. **User decides** — user picks target sprint and priority. Agent does not decide alone.
  5. **Log** — TRACKING.md: status = `deferred`, reason + target sprint documented.

**Phase 1a — Automated scan:**
- Run `Tools/sprint-audit.sh`
- Exit code 2 (setup error): fix script configuration (paths, patterns) before proceeding.
  Do not skip the automated scan — fix the script first.
- Exit code 1 (findings): review each finding, fix immediately or log with target sprint.
- Exit code 0 (clean): proceed.

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

## Sprint Close — Post-Gate

1. Roadmap checkmarks
   Run `sprint-audit.sh` Section 11 (Roadmap ↔ TRACKING sync).
   Fix all mismatches before ticking.
   [x] = TRACKING.md verified (gate evidence logged)
   [~] = skipped + reason documented inline
   [ ] = not verified (open, in_progress, or fixed without evidence)
   Every [ ] item requires action — do NOT silently skip:
   → apply the unmet-metric escalation from Close Gate Phase 0
     (explain gap, trace blocker, propose target sprint, user decides).
2. TRACKING.md update (all Must verified with evidence)
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
   - Mismatch → fix before closing sprint
7. Failure mode retrospective:
   - Read TRACKING.md §Predicted Failure Modes (written at 9d)
   - Compare: predicted vs actually encountered
   - Add row to TRACKING.md §Failure Mode History (include Detection: test / user-visual / profiler)
   - Unpredicted failure → new guardrail rule
   - Same category 2+ times in last 3 sprints → Architecture Review Required at next Entry Gate
   - Same detection=user-visual 2+ times → "Can automated proxy test replace visual check?" at next Entry Gate
8. Failure Mode History maintenance:
   - If §Failure Mode History exceeds 30 rows: archive rows older than 5 sprints
     to Docs/Archive/failure-history-S1-S[N].md. Keep last 5 sprints in TRACKING.md.
   - Entry Gate 9d only needs recent history (last 3 sprints) for pattern detection.
9. Entry Gate report cleanup:
   - Delete `Docs/Planning/S<N>_ENTRY_GATE.md` — its purpose (sprint-scoped reference) is fulfilled.
   - The gate execution log in TRACKING.md (from Entry Gate step 12d) persists as the permanent record.
10. Sprint "done"
    Log to TRACKING.md: "Sprint Close: [date], steps 1-10 ✓"

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
5. Update sprint-audit.sh if pattern is grep-detectable
```

### Mid-Sprint Scope Change

When an urgent item (critical bug, security fix, user-requested change) must enter a sprint
that has already passed Entry Gate:

```
1. User requests scope change (AI never initiates scope changes unilaterally)
2. AI assesses impact:
   a. Does the new item conflict with in-progress items?
   b. Does it invalidate any verified items? (if yes → regression, see §State Transitions)
   c. Will it push the sprint over scope limit?
3. AI presents options to user:
   - Add as new Must item (may push Should/Could to next sprint)
   - Add as new Must item + defer an existing Must item to make room (user picks which)
   - Add as hotfix outside sprint scope (no ID, no gate — emergency only)
   - Defer to next sprint
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
- [ ] CORE-004: ★ [item description] — Must-gated (has metric / affects Must / complex failure modes)

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
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 0 — Sprint Detail (conditional)                          │
│  Skip if sprint already has Must/Should/Could items.            │
│  If sprint is a one-line sketch:                                │
│    0a. Read sketch + previous sprint outcomes                   │
│    0b. Decompose into Must/Should/Could with IDs                │
│    0c. Add metric gates (Must items)                            │
│    0d. Priority & rigor review (2 passes):                      │
│        Pass 1: distribution check (all Must? re-sort)           │
│        Pass 2: Q1 promote / Q2 ★ Must-gate Should/Could         │
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
│  For each Must item + ★ Must-gated, 4-question check:           │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌─────────────────┐    │
│  │ Still    │ │ Goal      │ │ Approach │ │ Metrics still   │    │
│  │ relevant?│ │ aligned?  │ │ valid?   │ │ appropriate?    │    │
│  └──────────┘ └───────────┘ └──────────┘ └─────────────────┘    │
│                                                                 │
│  Then:                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 9. Verification plan:                                     │  │
│  │    a. Metrics measurable?   b. How verified? (invariants) │  │
│  │    c. Metric gap? → add    d. Failure modes? (3 types):   │  │
│  │       Read TRACKING §Failure Mode History first           │  │
│  │       • Direct  • Interaction  • Stress/edge              │  │
│  │       >=1 per category, each with metric or test          │  │
│  │       Write to TRACKING §Predicted Failure Modes          │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────────────────────┐ │
│  │ 10.Scope │ │ 11.Impl  │ │ 12. Gate assessment + report:     ││
│  │ check    │ │ order    │ │  a. Write S<N>_ENTRY_GATE.md     │ │
│  └──────────┘ └──────────┘ │  b. Ref in TRACKING.md           │ │
│                             │  c. AI own assessment + recommend││
│                             │  d. Log gate execution           ││
│                             │  e. User approves before coding  ││
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
│  │              │  YES ↓            │                      │    │
│  │              └───────────────────┘                      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  D. Write tests                                         │    │
│  │     ┌────────────────────────────────────────────┐      │    │
│  │     │ Unit-testable logic ────► Unit test        │      │    │
│  │     │ Integration/async ──────► Integration test │      │    │
│  │     │ Visual/UI ────────────► Manual + screenshot│      │    │
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
│  │     │    ask user again (loop until resolved)    │      │    │
│  │     │ 3. Automated proxy test exists?            │      │    │
│  │     │    → still ask user for visual confirm     │      │    │
│  │     └────────────────────────────────────────────┘      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  E. Update TRACKING.md                                  │    │
│  │     Mark item fixed (in_progress → fixed), log decisions│    │
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
│  PHASE 0 — Metric Gate Sufficiency                              │
│                                                                 │
│  For each sprint metric (Must + ★ Must-gated):                  │
│  □ Measurable with current infrastructure?                      │
│  □ Test evidence sufficient?                                    │
│  □ Threshold reasonable for current scale?                      │
│  □ Failure mode coverage per modified subsystem?                │
│    • Direct (item-internal) — >=1 identified?                   │
│    • Interaction (cross-system) — >=1 identified?               │
│    • Stress/edge (extreme-condition) — >=1 identified?          │
│    Each mode has metric or test? Missing → add or document gap  │
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
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Exit codes: 0=clean, 1=findings, 2=setup error (fix script)    │
│  Output: WARN candidates — review each, fix or mark FP          │
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
│  Each finding: fix immediately OR log with target sprint        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3 — Regression Test                                      │
│  All tests PASS after Phase 2 fixes (no regressions)            │
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
│     → Run sprint-audit.sh Section 11 (Roadmap ↔ TRACKING sync)  │
│     → Fix all mismatches before ticking                         │
│     [x] = TRACKING.md verified (gate evidence logged)           │
│     [~] = skipped + reason documented inline                    │
│     [ ] = not verified (open, in_progress, or fixed)            │
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
│  6. Workflow integrity check                                    │
│     → CLAUDE.md refs match target file sections?                │
│     → Guardrails pointer matches workflow content?              │
│     → Verify numbered steps have corresponding actions          │
│     → Mismatch → fix before closing sprint                      │
│                                                                 │
│  7. Failure mode retrospective                                  │
│     → Read TRACKING §Predicted Failure Modes (from 9d)          │
│     → Compare predictions vs actual failures                    │
│     → Add row to TRACKING.md §Failure Mode History              │
│       (Detection column: test / user-visual / profiler)         │
│     → Unpredicted → new guardrail rule                          │
│     → Same category 2+/3 sprints → Architecture Review Required │
│     → Same detection=user-visual 2+ → proxy test question       │
│                                                                 │
│  8. Failure Mode History maintenance                            │
│     → >30 rows? Archive older entries to Docs/Archive/          │
│                                                                 │
│  9. Entry Gate report cleanup                                   │
│     → Delete Docs/Planning/S<N>_ENTRY_GATE.md                   │
│     → TRACKING.md gate log persists as permanent record         │
│                                                                 │
│ 10. Sprint "done"                                               │
│     Log: "Sprint Close: [date], steps 1-10 ✓"                   │
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
fi
total=$((total + sync))

# ── Summary ──
echo ""
if [[ $errors -gt 0 ]]; then
  echo "Sprint audit: $errors setup error(s) — fix script configuration before audit."
  exit 2
elif [[ $total -eq 0 ]]; then
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
Document loading order (sequential — each step depends on the previous):

1. CLAUDE.md is auto-loaded (contains checkpoint + contracts)
   → Tells you: project context, immutable contracts, what happened last session
2. Read TRACKING.md → understand current state
   → Tells you: which items are open/in_progress/blocked, current sprint, blockers
   → If TRACKING.md is malformed (broken table, parse errors):
     reconstruct from last known good state (git history) or ask user to verify.
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
  open ─── work started ───► in_progress ─── implementation done ───► fixed ─── test evidence ───► verified
                                  │                                     │                              │
                                  │ (external blocker)                  │ (no evidence provided)       │ (regression found)
                                  ▼                                     └── stays fixed (blocks close) │
                              blocked                                                                  │
                                  │ (blocker resolved)                                                 │
                                  └──► in_progress                        open ◄───────────────────────┘
                                                                          (log reason in Change Log)
  Any status ──► deferred (intentional skip, requires reason + target sprint)
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
┌──────────────────┬───────────────────────────────────────────────┐
│ Event            │ Update                                        │
├──────────────────┼───────────────────────────────────────────────┤
│ Work started     │ TRACKING.md (status → in_progress)            │
│ Bug fixed        │ TRACKING.md (status → fixed)                  │
│ Bug verified     │ TRACKING.md (status → verified + evidence)    │
│ Item blocked     │ TRACKING.md (status → blocked + risk entry)   │
│ Item deferred    │ TRACKING.md (status → deferred + reason)      │
│ Regression found │ TRACKING.md (verified → open + change log)    │
│ New rule found   │ GUARDRAILS.md (rule + anti-pattern)           │
│ Sprint starts    │ TRACKING.md (Current Focus)                   │
│ Sprint closes    │ Roadmap (checkmarks), CLAUDE.md (checkpoint)  │
│ Sprint archived  │ Docs/Archive/changelog-S<N>.md                │
│ Decision made    │ TRACKING.md (change log)                      │
│ Tech debt found  │ TRACKING.md (new ID, forward note)            │
│ Scope change     │ TRACKING.md (change log + new/modified items) │
│ Contract revised │ CLAUDE.md §Immutable Contracts + change log   │
│ Sprint aborted   │ TRACKING.md (items → deferred + change log)   │
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

Abbreviated Entry Gate for small projects:
- Phase 0: run if sprint is a sketch (same as full workflow)
- Phase 1: steps 1-2 only (read TRACKING + Roadmap). Skip deferred item review and guardrails index.
- Phase 2: skip entirely
- Phase 3: steps 8 + 10 + 12 only (strategic alignment, scope check, confirm).
  Skip failure mode analysis (step 9d) — overhead exceeds value for <=5 items.
  Skip verification plan detail (step 9a-c) — cover in self-verify during implementation.

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
| Entry Gate | Abbreviated (Phase 0 + 1 + 3) | Full (all 4 phases) |
| Close Gate | Full (quality is non-negotiable) | Full + peer sign-off |
