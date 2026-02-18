# Scenario Acceptance Tests — WORKFLOW.md
#
# Usage (LLM): Read this file + WORKFLOW.md, then verify each scenario below.
#   For each scenario confirm:
#   1. The evidence_pattern is present in WORKFLOW.md
#   2. The described behavior is correctly and completely specified
#   3. No ambiguity, dead-end, or missing branch exists
#
# Usage (script): validate-scenarios.sh uses the mutation_target field to run
#   mutation tests — removes that text from a temp WORKFLOW.md and confirms
#   the evidence_pattern no longer matches. If it still matches, the scenario
#   has no "bite" and the test fails (false sense of coverage).
#
# Format per scenario:
#   id              — stable identifier (never reuse after deprecation)
#   category        — entry_gate | close_gate | impl_loop | mid_sprint |
#                     sprint_abort | session_recovery
#   title           — one-line description of the situation being tested
#   situation       — the trigger context ("When X happens...")
#   required        — what WORKFLOW.md MUST specify to handle this correctly
#   evidence_pattern — ERE pattern that must match in WORKFLOW.md
#   mutation_target  — literal text whose removal should break evidence_pattern
#                     (used by validate-scenarios.sh)
#
# Mutation test logic:
#   Remove mutation_target → evidence_pattern must NO LONGER match → scenario has bite
#   If evidence_pattern still matches after removal → test fails (scenario is trivially satisfied)

---

## ENTRY GATE SCENARIOS

---

### EG-S01
- id: EG-S01
- category: entry_gate
- title: Step 12e — User does not approve final sprint plan

**Situation:** The AI presents the final sprint plan at Entry Gate step 12e. The user
does not approve — they have blocking concerns.

**Required behavior:**
- WORKFLOW.md must instruct the AI to identify the blocking concern
- Must direct rework to the relevant phase (Phase 0 for scope, Phase 3 for strategy/metrics)
- Must offer Sprint Abort as an option if the sprint direction is fundamentally wrong
- AI must NOT proceed to implementation without approval

**Evidence pattern:**
```
return to the relevant phase
```

**Mutation target:**
```
return to the relevant phase
```

---

### EG-S02
- id: EG-S02
- category: entry_gate
- title: Step 8 — Strategic alignment fails, all 4 options must be offered

**Situation:** During Entry Gate step 8 (strategic alignment check), an item is flagged
as misaligned. The AI must present the user with all four resolution options.

**Required behavior:**
- Must offer: keep (unchanged), modify (update roadmap), defer (TRACKING + roadmap [~]),
  and remove (delete from Roadmap + TRACKING.md)
- AI must NOT unilaterally choose any option
- All 4 branches must have defined next-actions in WORKFLOW.md

**Evidence pattern:**
```
keep → item unchanged
```

**Mutation target:**
```
item unchanged, continue gate.
```

---

### EG-S03
- id: EG-S03
- category: entry_gate
- title: Step 8 — Remove option must specify deletion from both Roadmap AND TRACKING.md

**Situation:** User chooses "remove" at step 8. Both the Roadmap and TRACKING.md must
be updated — removing from only one creates dangling references.

**Required behavior:**
- The "remove" branch must explicitly name BOTH Roadmap and TRACKING.md as targets
- Must log removal in Change Log

**Evidence pattern:**
```
remove.*delete from Roadmap.*log removal in Change Log
```

**Mutation target:**
```
delete from Roadmap + TRACKING.md, log removal in Change Log.
```

---

### EG-S04
- id: EG-S04
- category: entry_gate
- title: Phase 0e — User does not approve scope → rework required

**Situation:** At Entry Gate Phase 0e, the user reviews the scope and does not approve.
The AI must NOT proceed to subsequent phases.

**Required behavior:**
- Must identify concerns
- Must rework phases 0b–0d before re-presenting
- Must not silently proceed to Phase 3

**Evidence pattern:**
```
does not approve.*identify concerns.*rework 0b-0d
```

**Mutation target:**
```
User does not approve → identify concerns → rework 0b-0d → re-present.
```

---

### EG-S05
- id: EG-S05
- category: entry_gate
- title: Step 10 — 0 Must items: sprint is empty, explicit paths defined

**Situation:** After Entry Gate step 10 scope check, zero Must items remain. The sprint
is empty and cannot proceed to implementation.

**Required behavior:**
- Must explicitly identify "0 Must → sprint is empty"
- Must offer redesign path (return to Phase 0 step 0b)
- Must offer Sprint Abort as alternative

**Evidence pattern:**
```
0 Must.*sprint is empty.*Present options
```

**Mutation target:**
```
sprint is empty. Present options:
```

---

### EG-S06
- id: EG-S06
- category: entry_gate
- title: Must item flagged as potential Should — user decides, AI does not demote unilaterally

**Situation:** The AI suspects a Must item should be a Should. It must present this
to the user as a question, not act on it alone.

**Required behavior:**
- Must surface the question to the user explicitly
- AI must not demote the item without user approval

**Evidence pattern:**
```
should it be Should[?]
```

**Mutation target:**
```
should it be Should?
```

---

## CLOSE GATE SCENARIOS

---

### CG-S01
- id: CG-S01
- category: close_gate
- title: Phase -1 is mandatory before EVERY Close Gate — no exceptions

**Situation:** The AI starts a Close Gate. Phase -1 (state recovery) must ALWAYS run first,
regardless of session history or prior context.

**Required behavior:**
- Phase -1 must be labeled "mandatory"
- Must explicitly block proceeding to Phase 0 without completing Phase -1
- Must label skipping as a protocol violation

**Evidence pattern:**
```
mandatory.*run before every Close Gate
```

**Mutation target:**
```
run before every Close Gate
```

---

### CG-S02
- id: CG-S02
- category: close_gate
- title: ALL metrics DEFERRED → gate is blocked, Sprint Abort triggered

**Situation:** Close Gate Phase 0 metric table shows every metric as DEFERRED.
This means no verified work was accomplished.

**Required behavior:**
- Must explicitly block the gate (not just warn)
- Must trigger Sprint Abort procedure

**Evidence pattern:**
```
ALL metrics are DEFERRED.*gate blocked
```

**Mutation target:**
```
Guard: if ALL metrics are DEFERRED → gate blocked. At least one metric must PASS.
```

---

### CG-S03
- id: CG-S03
- category: close_gate
- title: FAIL or MISSING metric → gate blocked, must escalate (not silently skip)

**Situation:** During Phase 0 metric verification, a metric row is FAIL or MISSING.
The AI must not simply mark it and move on.

**Required behavior:**
- FAIL or MISSING must explicitly block the gate
- Must require escalation before closing

**Evidence pattern:**
```
MISSING/FAIL.*gate blocked
```

**Mutation target:**
```
Rule: every row must be PASS or DEFERRED (with escalation). MISSING/FAIL → gate blocked.
```

---

### CG-S04
- id: CG-S04
- category: close_gate
- title: Close Gate verdict — pre-verdict 7-point checklist is mandatory

**Situation:** The AI is about to issue a Close Gate verdict. It must not skip
the 7-phase checklist.

**Required behavior:**
- Must enumerate all phases in a mandatory checklist before verdict
- "Sprint looks done" response without checklist = protocol violation

**Evidence pattern:**
```
ALL of the following phases were explicitly completed
```

**Mutation target:**
```
that ALL of the following phases were explicitly completed in this session:
```

---

### CG-S05
- id: CG-S05
- category: close_gate
- title: Critical Axis finding cannot be silently deferred

**Situation:** During Close Gate Phase 2 (fix), a finding touches the project's Critical Axis
(e.g., security for a payment system). The user proposes deferring it.

**Required behavior:**
- Must stop and present explicitly to user
- Must offer 3 options: fix now / defer with rationale / Sprint Abort
- AI must not decide alone

**Evidence pattern:**
```
cannot be silently deferred
```

**Mutation target:**
```
Any finding that touches the Critical Axis domain cannot be silently deferred.
```

---

### CG-S06
- id: CG-S06
- category: close_gate
- title: Abbreviated Close Gate — skip indicator must be logged so next Close Gate knows

**Situation:** Entry Gate was run in abbreviated mode (step 12d note). The Close Gate
must know to apply the abbreviated variant and skip the failure mode history step.

**Required behavior:**
- Must identify that abbreviated mode skips specific steps
- Logging at step 12d must persist as the record

**Evidence pattern:**
```
step 12d logs.*Entry Gate.*abbreviated.*Close Gate
```

**Mutation target:**
```
step 12d logs "Entry Gate (abbreviated)" so Close Gate knows.
```

---

## IMPLEMENTATION LOOP SCENARIOS

---

### IL-S01
- id: IL-S01
- category: impl_loop
- title: Self-verify checklist fails 3+ times → escalate to user, do not loop infinitely

**Situation:** Step C (self-verify) fails. The AI fixes and rechecks. After 3 rounds,
the checklist still fails. The AI must NOT continue looping.

**Required behavior:**
- Must cap at 3 rounds explicitly
- Must escalate to user if still failing after 3 rounds (not proceed silently)

**Evidence pattern:**
```
Max 3 rounds.*Still failing after 3.*stop and present
```

**Mutation target:**
```
Max 3 rounds. Still failing after 3
```

---

### IL-S02
- id: IL-S02
- category: impl_loop
- title: D.6 incremental test — regression on previous item's test → fix before writing more code

**Situation:** During D.6 incremental test run, a test for a previously completed item
fails. This is a regression.

**Required behavior:**
- Must identify this as a regression
- Must require fixing before writing any more code (not just logging)
- Must cap fix attempts at 3 before escalating

**Evidence pattern:**
```
FAIL on previous item.*regression.*fix before writing
```

**Mutation target:**
```
fix before writing any more code
```

---

### IL-S03
- id: IL-S03
- category: impl_loop
- title: Visual verification — Max 3 attempts, then log as known gap (not infinite retry)

**Situation:** An item was marked "manual+screenshot" in Entry Gate 9b. During D.5
visual verification, the user repeatedly reports problems.

**Required behavior:**
- Must cap at 3 attempts
- After 3 failures, must log as known gap with target sprint (not keep asking)

**Evidence pattern:**
```
Max 3 attempts.*if still failing.*log visual gap
```

**Mutation target:**
```
Max 3 attempts; if still failing: log visual gap in
```

---

## MID-SPRINT SCENARIOS

---

### MS-S01
- id: MS-S01
- category: mid_sprint
- title: Scope change — AI never initiates; only user can request

**Situation:** An urgent item needs to be added mid-sprint. The AI must not propose
or initiate this on its own.

**Required behavior:**
- Must state that only the user can request scope changes
- AI must present options, not decide

**Evidence pattern:**
```
AI never initiates scope changes unilaterally
```

**Mutation target:**
```
User requests scope change (AI never initiates scope changes unilaterally)
```

---

### MS-S02
- id: MS-S02
- category: mid_sprint
- title: Mid-sprint scope change — all 4 options must be offered to user

**Situation:** A scope change is requested mid-sprint. The AI must present all 4 options
(not just the convenient ones).

**Required behavior:**
- Must offer: add as Must / add Must + defer existing Must / hotfix outside scope /
  defer to next sprint
- All 4 must have defined follow-on actions

**Evidence pattern:**
```
hotfix outside sprint scope
```

**Mutation target:**
```
Add as hotfix outside sprint scope
```

---

## SPRINT ABORT SCENARIOS

---

### SA-S01
- id: SA-S01
- category: sprint_abort
- title: Sprint Abort — only user can initiate, AI never triggers it alone

**Situation:** Conditions suggest the sprint should be aborted (wrong direction,
requirements changed). The AI must not unilaterally abort.

**Required behavior:**
- Must state user initiates abort
- AI cannot invoke Sprint Abort without user request

**Evidence pattern:**
```
User requests abort.*AI never initiates abort
```

**Mutation target:**
```
1. User requests abort (AI never initiates abort)
```

---

### SA-S02
- id: SA-S02
- category: sprint_abort
- title: Sprint Abort — verified items preserved, non-verified deferred (not deleted)

**Situation:** Sprint Abort is triggered. Previously verified items must not be lost.
Unfinished items must be deferred, not deleted.

**Required behavior:**
- Verified items keep their `verified` status
- Non-verified items → `deferred` with reason (sprint aborted)
- Work is not lost

**Evidence pattern:**
```
abort.*failure.*[Vv]erified work persists|abort.*not.*failure
```

**Mutation target:**
```
Rule: abort ≠ failure. Verified work persists, unfinished work is deferred, not deleted.
```

---

## SESSION RECOVERY SCENARIOS

---

### SR-S01
- id: SR-S01
- category: session_recovery
- title: Mid-sprint session recovery — resume from TRACKING.md, not start over

**Situation:** A session is interrupted mid-sprint (in_progress items exist). When the
AI resumes, it must not restart Entry Gate or lose prior state.

**Required behavior:**
- Must identify the "mid-sprint" recovery path explicitly
- Must resume from TRACKING.md (not start fresh)

**Evidence pattern:**
```
Mid-sprint.*in_progress.*resume from TRACKING\.md
```

**Mutation target:**
```
   b. Mid-sprint (in_progress or open items exist) → resume from TRACKING.md
```

---

## RETROACTIVE SPRINT AUDIT SCENARIOS

---

### RA-S01
- id: RA-S01
- category: retroactive_audit
- title: Retroactive Audit — AI proposes, user confirms; never opens unilaterally

**Situation:** A detection signal fires (e.g., a later sprint finds broken output from a
prior sprint). The AI must surface this to the user, not silently open an audit.

**Required behavior:**
- Must state that AI cannot open an audit unilaterally
- Must propose the audit and wait for user confirmation

**Evidence pattern:**
```
never opens an audit unilaterally.*proposes.*user confirms
```

**Mutation target:**
```
AI never opens an audit unilaterally — it proposes; the user confirms.
```

---

### RA-S02
- id: RA-S02
- category: retroactive_audit
- title: Retroactive Audit — detection signal must be surfaced, never silently dismissed

**Situation:** A detection signal fires during a workflow checkpoint (CP1-CP4). The AI
must not suppress or ignore it even if it seems minor.

**Required behavior:**
- Must surface the signal to the user explicitly
- Cannot dismiss signals silently

**Evidence pattern:**
```
never silently dismisses a detection signal
```

**Mutation target:**
```
AI never silently dismisses a detection signal — if signal fires, it must surface it.
```

---

## CONTRACT REVISION SCENARIOS

---

### CR-S01
- id: CR-S01
- category: contract_revision
- title: Contract Revision — only user can initiate; AI never starts unprompted

**Situation:** An API or data contract needs to change. The AI must not propose or
initiate a revision on its own initiative.

**Required behavior:**
- Must state that revision is triggered by user request only
- AI must not modify contracts unprompted

**Evidence pattern:**
```
AI never initiates contract revision unprompted
```

**Mutation target:**
```
AI never initiates contract revision unprompted.
```

---

## SCOPE NEGOTIATION SCENARIOS

---

### SN-S01
- id: SN-S01
- category: scope_negotiation
- title: Scope Negotiation — features must never be silently dropped

**Situation:** Features exceed the sprint scope limit during Entry Gate Phase 0 or
Initial Planning Q2. The AI must show where every feature went.

**Required behavior:**
- AI proposes allocation, user decides
- No feature may be silently dropped — all must appear somewhere (Must/Should/later sprint)

**Evidence pattern:**
```
Never silently drop features
```

**Mutation target:**
```
Never silently drop features — always show where they went.
```

---

## PERFORMANCE BASELINE SCENARIOS

---

### PB-S01
- id: PB-S01
- category: performance_baseline
- title: Performance Baseline — must not be invented when no real data exists

**Situation:** Sprint Close step 5 requires recording performance metrics. No measurable
data is available yet.

**Required behavior:**
- Must log "not yet established" with target sprint, NOT fabricate numbers
- Explicit prohibition on invented baselines

**Evidence pattern:**
```
Do not invent fake baselines
```

**Mutation target:**
```
Do not invent fake baselines.
```

---

## FAILURE MODE HISTORY SCENARIOS

---

### FM-S01
- id: FM-S01
- category: failure_mode_history
- title: Failure Mode History — 3-category analysis required per item

**Situation:** During Entry Gate step 9a (failure mode analysis), the AI lists failure
modes for each sprint item.

**Required behavior:**
- Must cover all 3 categories: Direct, Interaction, Stress/Edge
- Single-category analysis is insufficient

**Evidence pattern:**
```
failure modes in 3 categories
```

**Mutation target:**
```
list known failure modes in 3 categories:
```

---

## SUMMARY

| ID     | Category         | Title                                              |
|--------|------------------|----------------------------------------------------|
| EG-S01 | entry_gate       | Step 12e rejection → rework path exists            |
| EG-S02 | entry_gate       | Step 8 keep option specified                       |
| EG-S03 | entry_gate       | Step 8 remove option targets both Roadmap+TRACKING |
| EG-S04 | entry_gate       | Phase 0e non-approval → rework required            |
| EG-S05 | entry_gate       | Step 10 empty sprint → explicit paths              |
| EG-S06 | entry_gate       | Must→Should demotion requires user approval        |
| CG-S01 | close_gate       | Phase -1 mandatory, no exceptions                  |
| CG-S02 | close_gate       | ALL DEFERRED → gate blocked + Sprint Abort         |
| CG-S03 | close_gate       | FAIL/MISSING → gate blocked, not skipped           |
| CG-S04 | close_gate       | Pre-verdict checklist mandatory                    |
| CG-S05 | close_gate       | Critical Axis finding cannot be silently deferred  |
| CG-S06 | close_gate       | Abbreviated mode logged for Close Gate             |
| IL-S01 | impl_loop        | Self-verify: 3 rounds max then escalate            |
| IL-S02 | impl_loop        | D.6 regression: fix before more code              |
| IL-S03 | impl_loop        | Visual verify: 3 attempts max then gap log         |
| MS-S01 | mid_sprint       | Scope change: user-only initiation                 |
| MS-S02 | mid_sprint       | Scope change: all 4 options offered                |
| SA-S01 | sprint_abort       | Abort: user-only initiation                        |
| SA-S02 | sprint_abort       | Abort: verified work preserved                     |
| SR-S01 | session_recovery   | Mid-sprint recovery: resume from TRACKING.md       |
| RA-S01 | retroactive_audit  | Audit: AI proposes, user confirms                  |
| RA-S02 | retroactive_audit  | Audit: signal must be surfaced, not dismissed      |
| CR-S01 | contract_revision  | Contract revision: user-only initiation            |
| SN-S01 | scope_negotiation  | Scope: features never silently dropped             |
| PB-S01 | perf_baseline      | Baseline: never invent when no data exists         |
| FM-S01 | failure_modes      | Failure modes: 3-category analysis required        |
