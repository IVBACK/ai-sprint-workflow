<instructions>

# CRITICAL: Entry Gate Rules

- AI MUST NOT unilaterally change sprint scope -- user decides all keep/modify/defer/remove.
- AI MUST recommend new session after gate completes (user may override).
- AI MUST write the Entry Gate report to `Docs/Planning/S<N>_ENTRY_GATE.md` BEFORE presenting to user. The file is the record — verbal presentation alone is not sufficient.
- Log each completed phase to TRACKING.md Change Log for session recovery.
- ALL actionable items (Must, Should, Could) require metric gates and failure modes.

---

# Entry Gate -- Pre-Sprint Review

**Prereq:** AGENT-RULES.md read. **Next:** IMPL-LOOP.md after passing gate.

> Parallel execution: IF user requests it, see PARALLEL-EXECUTION.md. Do not auto-load.

## Abbreviated Mode

IF item_count <= 3 AND no cross-sprint dependencies:
  Ask user: "Abbreviated (faster) or full gate (more thorough)?"
  IF no response or unclear -> full gate.
  Run: Phase 0 (type + detail) -> 0pre -> 1-2 -> 8 (quick) -> 9b-lite -> 10 -> 12.
  Skip: 3-4, Phase 2 (5-7), 9a, 9c (incl. fitness check), 11.
  After step 2: Clear Predicted Failure Modes and Failure Encounters sections.
  9b-lite: per item answer only "what will be tested?" + "what input/output?"
  Impl Loop D.7 (AC exit check) still runs in abbreviated mode.
  Step 12d logs "Entry Gate (abbreviated)".
  When in doubt -> full gate.

---

## Phase 0 -- Sprint Detail (conditional)

### Sprint Type Detection (always runs)

Read Roadmap description + items. Classify:
- **Feature sprint** (default): new functionality. Standard rigor.
- **Hardening sprint**: debt/stabilization/perf on existing code.

IF hardening:
  Metric gates focus on regression prevention ("no worse than baseline").
  Close Gate 1c focuses on robustness, not completeness.
  New features discovered -> log to TRACKING.md Change Log as opportunities, not scope.

Log sprint type in Entry Gate report (step 12a).

### Sprint Decomposition

IF sprint already has Must/Should/Could items -> skip to Phase 1.

ELIF sprint is one-line sketch:
  0a. Read sketch + previous sprint outcomes.
  0b. Decompose into Must/Should/Could with CORE-### IDs.
      Format: `- [ ] CORE-###: [description]` -- checkbox mandatory.
  0c. Add metric gates for each item (all priorities).
  0d. Assign priorities. Promote items blocking Must items to Must.
  0e. Present plan to user for approval.
      IF rejected -> rework 0b-0d -> re-present.
      IF rejected 2x -> ask: "Continue reworking or Sprint Abort?"
      IF fundamentally wrong -> Sprint Abort.
  IF items exceed scope limit -> apply Scope Negotiation.

---

## Phase 1 -- State Review

### 0pre. Roadmap Sanity Check

- All CORE-### IDs in Roadmap have TRACKING.md entries? (orphan detection)
- All TRACKING.md items in Roadmap? (reverse orphan)
- Checkbox states match statuses? (`[x]`=verified, `[~]`=deferred)
- Mismatches -> fix now (ask user if ambiguous).
- IF `Tools/sprint-audit.sh` exists -> run Section 11 now.

### 0. Previous Sprint Close Check

Read TRACKING.md Change Log for "Sprint Close: complete -- Sprint N".
IF not found:
  Warn user: Sprint Close incomplete, guardrails may be missing.
  Ask: "Complete Sprint Close first, or proceed anyway?"
  IF proceeding -> log to Open Risks: "R-###: Sprint N Sprint Close incomplete."

### 1-2. Read State (parallel)

- TRACKING.md -> open items, blockers, in_progress.
  Do NOT clear Predicted Failure Modes or Failure Encounters yet (cleared at 9a).
- Roadmap -> Must/Should/Could for this sprint.

> Automation: `Tools/sprint-tools state` for compact digest.

### 3. Previous Sprint Carryovers

Per non-terminal status:
- `blocked`: blocker resolved? -> set `open`. Still blocked -> carry or drop (user decides). Drop = delete + Change Log. Ensure R-### in Open Risks.
- `deferred`: still relevant? Carry or drop (user decides).
- `open`/`in_progress`: still in scope? (user decides).
- `fixed` (unverified): verify now or carry forward (user decides).

Check Open Risks for "Architecture Review Required" flags.
IF found -> ask user: review now (recommended) or defer to 9a?

Check Change Log for `DEFERRED -> S<N>` metrics from prior Close Gate.
IF found -> surface each with context. User decides: resolve or re-defer.

Check Performance Baseline Log for regressions vs past claims (CP1 Auto-Detection).
IF regression detected AND current sprint didn't modify responsible system:
  Present: "(1) Open Retroactive Audit now, (2) Log and continue." User decides.

### 4. Identify Applicable GUARDRAILS Sections

Consumed by Implementation Loop step A.

---

## Phase 2 -- Dependency Verification (read-only)

IF Sprint 1 -> skip Phase 2.

5. Verify dependency sprints closed.
   IF dependency sprint has deferred items -> check if current sprint depends on those specific items.
   IF yes -> flag to user. IF undocumented dependency -> confirm with user.
6. Read dependency API source files, confirm contracts match.
7. List open architectural decisions -> include in 12a report.
   IF any affects scope/approach -> flag at step 8.

---

## Phase 3 -- Strategic Validation & Confirmation

### 8. Strategic Alignment Check (per item)

For each item evaluate:
  a. Still relevant? (superseded/delivered?)
  b. Goal alignment?
  c. Approach still valid?
  d. Metrics appropriate?
  e. Rough impact scope? (which modules -- ballpark)
  f. Redundancy risk? (framework/engine/prior sprint overlap?)

IF a-d fails -> flag with evidence + options (keep/modify/defer/remove).
IF e reveals wide blast radius -> flag before proceeding.
IF f reveals overlap -> flag: "may overlap with [existing]. Confirm scope or narrow to delta."

User response actions:
- keep -> unchanged.
- modify -> update Roadmap, re-run 9a-9c for that item.
- defer -> `sprint-tools item CORE-NNN deferred "reason — target S[N]"` (handles TRACKING + Roadmap sync).
- remove -> delete from Roadmap + TRACKING.md, log in Change Log.

IF Must count exceeds scope limit after review -> apply Scope Negotiation.

### Domain Research (per item, before step 9)

IF item touches unfamiliar domain — check triggers T1-T6 (`AGENT-RULES.md §Research Triggers`):
  T1 New API/SDK | T2 Compliance | T3 Perf-critical | T4 New algorithm | T5 Platform | T6 Data format
  Ask: "CORE-### may benefit from domain research: [trigger, reason]. Research now? [y/N]"

  IF approved:
    1. Search authoritative sources (papers, specs, reference impls).
    2. Extract exact formulas/algorithms/specs.
    3. Cross-reference >= 2 independent sources.
    4. Write to `Docs/Planning/S<N>_DOMAIN_RESEARCH.md` + summarize in 12a.

<examples>

Research report format (`Docs/Planning/S<N>_DOMAIN_RESEARCH.md`):
```markdown
# Domain Research -- Sprint N

## CORE-### -- [topic]
**Trigger:** [which matched]
**Question:** [what needed answering]

### Findings
[formulas, algorithms, specs, API signatures]

### Sources
1. [source] -- [URL] -- [what extracted]
2. [source] -- [URL] -- [cross-reference]

### Implementation Notes
[how findings map to code -- files, functions, constraints]
```

</examples>

  IF declined:
    Log: "Domain research: skipped by user ([trigger] flagged)"

  IF no trigger (T1-T6) matches AND well-known patterns -> skip without asking.

  Flag researched items as `research: done` in Entry Gate report.

### 9. Verification Plan

**9a. Failure Mode Analysis (per item -- all priorities):**

1. Read `Docs/SPRINT-INDEX.md` for relevant topics.
2. Read TRACKING.md Failure Mode History.
3. Check escalation triggers:
   - Same category 2+ times in 3 sprints -> Architecture Review Required.
   - Same detection=user-visual 2+ times -> propose automated proxy test.
     IF triggered -> ask user: add to current sprint, defer as Must, or accept manual.
     Accept manual -> log in Dismissed Signals (CP2). After 2 dismissals: suppressed.

IF Architecture Review triggered:
  1. Identify recurring category (direct/interaction/stress-edge).
  2. Trace root causes across sprints.
  3. Propose architectural fix with scope + effort estimate.
  4. Present to user. User decides: fix now or defer.
  5. Defer -> log in Open Risks with target sprint.

List failure modes in 3 categories (>= 1 each):
- **Direct**: item breaks alone (wrong calc, null ref, off-by-one).
- **Interaction**: 2+ systems combine to fail.
- **Stress/edge**: invisible in normal use (rapid oscillation, pool exhaustion).

IF item touches Critical Axis (from CLAUDE.md): require >= 2 modes in most relevant category.

Clear Predicted Failure Modes + Failure Encounters. Write new predictions to TRACKING.md.

**9b. Verification Method (per item):**

Define: unit test / integration test / manual + screenshot.
Algorithmic items: define invariants (math properties, reference output, determinism).
Complex systems: note if dedicated test scene/sandbox would help.

**9c. Metric Sufficiency (per item -- all priorities):**

IF no metric gate -> propose one.

For each metric, all four must hold:
1. Measurable by sprint end?
2. Test scenario defined? (inputs, env, data size, repetition count)
3. Threshold non-trivial? (construct scenario where metric passes but system broken -- if exists, tighten)
4. Coverage: every 9a failure mode maps to metric/test? Missing -> add.

**Fitness check:** IF "all tests pass" is only success criterion -> add fitness-level metric (integration behavior, real-world scenario, or Critical Axis compliance).

Propose changes in 12a report. Do NOT update roadmap yet -- user approves at 12c.

### 10. Scope Check

Scope limit (from Q2): small=5, medium=8, large=12 Must items.
IF 0 Must -> ask: "(1) Return to Phase 0, (2) Sprint Abort." User decides.
IF return to Phase 0 twice and still 0 -> Sprint Abort (user confirms).

### 11. Dependency-Ordered Implementation List

Produce dependency graph.
IF 4+ independent items -> suggest parallel execution:
  "This sprint has [N] independent items. Load parallel execution guide?"
  IF declined or no response -> continue sequentially. Do not ask again.

### 12. Gate Assessment, Report & Approval

**12a.** Write report to `Docs/Planning/S<N>_ENTRY_GATE.md`.
  Run `sprint-tools review S<N>_ENTRY_GATE.md` (blind review). Fix issues, then present.
  Include: phases 0-3 analysis, Metric Changes section (before/after + rationale).

**12b.** AI gate assessment:
  - Blocker summary (list or "none")
  - Risk: clean / attention points / blocker found
  - Scope: conservative / reasonable / aggressive
  - Key watch items (not blockers but need attention)
  - Recommendation: "Gate passed" or "Gate blocked by [X]"

**12c.** User approval required before coding.
  User reviews verification plan (9b): "Would this test pass even if item is broken?"
  IF trivial scenario -> revise at 9b.
  IF trivial after 2 revisions -> flag options: (1) accept with rationale, (2) mark untestable for manual Close Gate verify, (3) Sprint Abort if critical.

  IF rejected -> return to relevant phase, rework, re-present.
  IF rejected 2x -> ask: "(1) Targeted rework, (2) Sprint Abort." User decides.

**12d.** Phase logging:
  - WRITE `Docs/Planning/S<N>_ENTRY_GATE.md` — the file IS the record.
    Content: sprint type, items (Must/Should/Could), metric gates, failure modes, research flags.
    This is NOT optional — Close Gate reads this file. Missing file = audit FAIL.
  - Each phase completion -> TRACKING.md Change Log: "Entry Gate Phase [X]: complete -- [date]"
  - After approval -> log: "Entry Gate: [date], phases 0-3 done (steps: [list])"
  - Add ref: "Entry Gate report: Docs/Planning/S<N>_ENTRY_GATE.md"
  - Update roadmap with approved metric changes.
  - `sprint-tools checkpoint "Entry Gate complete -- Sprint N approved"`
  - RECOMMEND new session for implementation ("Continue sprint N").

---

# CRITICAL: Reminders (reinforcement)

- AI MUST NOT change sprint scope unilaterally -- user decides ALL keep/modify/defer/remove.
- Log EVERY phase to TRACKING.md Change Log (session recovery).
- ALL items need metric gates + failure modes -- no exceptions.
- After gate: RECOMMEND new session for implementation.

</instructions>
