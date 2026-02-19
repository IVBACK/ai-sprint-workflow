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

### EG-S07
- id: EG-S07
- category: entry_gate
- title: Phase 1 Step 0 — Sprint Close completion check before Entry Gate proceeds

**Situation:** Entry Gate Phase 1 begins. The previous sprint's Sprint Close may not
have been completed, meaning the failure mode retrospective (Step 7) and any resulting
guardrail updates may be missing.

**Required behavior:**
- Must check TRACKING.md §Change Log for Sprint Close completion entry before proceeding
- If entry is missing: must warn the user explicitly (not silently skip)
- Must ask user whether to proceed or complete Sprint Close first
- If proceeding: must log the gap in §Open Risks

**Evidence pattern:**
```
Check previous sprint.*Sprint Close completion|Sprint Close.*complete.*Change Log
```

**Mutation target:**
```
Check previous sprint's Sprint Close completion:
```

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

### IL-S05
- id: IL-S05
- category: impl_loop
- title: Implementation Loop A — guardrails must be read BEFORE writing code, not after

**Situation:** The AI is about to start implementing a sprint item. It must read the
relevant CODING_GUARDRAILS.md sections before writing any code — not after.
This is the retrieval step that makes the memory system work.

**Required behavior:**
- Must read guardrail sections identified in Entry Gate Phase 1 step 4
- Must happen in step A (Pre-code check), before step B (Write code)
- Reading after writing defeats the purpose — bugs may already be introduced

**Evidence pattern:**
```
Read the GUARDRAILS sections identified in Entry Gate Phase 1
```

**Mutation target:**
```
Read the GUARDRAILS sections identified in Entry Gate Phase 1 step 4 (relevant to this task type)
```

---

### IL-S04
- id: IL-S04
- category: impl_loop
- title: Implementation Loop B — scope-outside fix must be logged in Change Log immediately

**Situation:** During implementation, the AI fixes a bug in a system that is NOT the
current sprint item (a side fix). This fix is outside sprint scope and will not appear
in the Close Gate audit unless explicitly logged.

**Required behavior:**
- Must log the fix immediately in TRACKING.md §Change Log with "Side fix:" prefix
- Must include: system name, what was wrong, what was changed
- Must note that this is not a sprint item (so Sprint Close Step 7 can include it)

**Evidence pattern:**
```
scope-outside fix.*immediately log|immediately log.*TRACKING.*Change Log
```

**Mutation target:**
```
immediately log it in TRACKING.md §Change Log:
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

## GUARDRAIL UPDATE SCENARIOS

---

### GU-S01
- id: GU-S01
- category: guardrail_update
- title: Sprint Close Step 7e — unpredicted failure must not silently become a guardrail; user approves first

**Situation:** Sprint Close Step 7 retrospective identifies an unpredicted failure.
The AI wants to add a new guardrail rule to CODING_GUARDRAILS.md.

**Required behavior:**
- Must present the proposed rule to the user before adding it
- Must NOT add the guardrail silently
- User approves → then follow §Update Rule (7 steps)
- User rejects → no guardrail added

**Evidence pattern:**
```
present proposed rule to user
```

**Mutation target:**
```
Before adding: present proposed rule to user
```

---

### GU-S02
- id: GU-S02
- category: guardrail_update
- title: Update Rule — full 7-step chain must include sprint-audit.sh update and LESSONS_INDEX entry

**Situation:** A guardrail rule is being added via §Update Rule. The chain must be
complete — stopping at step 5 leaves the rule unenforced by automated scanning and
untraceable in LESSONS_INDEX.md.

**Required behavior:**
- Step 6: update sprint-audit.sh if pattern is grep-detectable
- Step 7: add entry to LESSONS_INDEX.md (RuleID, root cause, section, sprint, source)
- Both steps are mandatory — skipping either breaks traceability and automation

**Evidence pattern:**
```
Update sprint-audit.sh if pattern is grep-detectable
```

**Mutation target:**
```
6. Update sprint-audit.sh if pattern is grep-detectable
```

---

### AR-S01
- id: AR-S01
- category: architecture_review
- title: Failure Mode History — same category 2+ times triggers Architecture Review Required flag

**Situation:** Sprint Close Step 7f checks Failure Mode History. The same failure
category has appeared 2+ times in the last 3 sprints.

**Required behavior:**
- Must flag "Architecture Review Required" at next Entry Gate
- Must record the flag in TRACKING.md §Open Risks (so Entry Gate 9a picks it up)
- Must NOT silently note and move on

**Evidence pattern:**
```
Same category 2\+ times in last 3 sprints.*flag.*Architecture Review Required
```

**Mutation target:**
```
Same category 2+ times in last 3 sprints → flag "Architecture Review Required" at next Entry Gate
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

### SB-S01
- id: SB-S01
- category: session_boundary
- title: Entry Gate complete — new session recommended (mandatory)

**Situation:** Entry Gate Phase 3 step 12e has just approved the sprint. The AI is
writing the final Entry Gate summary and approval record.

**Required behavior:**
- Must recommend starting a new session before implementation begins
- This is mandatory — user may choose to continue but AI must make the recommendation
- The same rule applies after Close Gate (recommend new session before Close Gate runs)

**Evidence pattern:**
```
AI MUST recommend starting a new session
```

**Mutation target:**
```
AI MUST recommend starting a new session for implementation ("Continue sprint N").
```

---

### IL-S06
- id: IL-S06
- category: impl_loop
- title: Must items done — Close Gate must NOT be auto-suggested by AI

**Situation:** Implementation Loop: all Must items have been verified. The AI is
deciding what to present to the user next (Should/Could prompt).

**Required behavior:**
- AI must offer Should/Could continuation prompt only
- AI must NOT ask "shall we close the sprint?" unprompted
- Close Gate is always user-initiated — the user opens it when ready

**Evidence pattern:**
```
Close Gate is always user-initiated.*AI does not ask
```

**Mutation target:**
```
Close Gate is always user-initiated — AI does not ask "shall we close?" unprompted.
```

---

### CG-S07
- id: CG-S07
- category: close_gate
- title: Retroactive audit — REGRESSION/INTEGRATION_GAP on Must item is an automatic blocker

**Situation:** A retroactive sprint audit finds a gap classified as REGRESSION or
INTEGRATION_GAP that affects a current sprint Must item.

**Required behavior:**
- Gap must be automatically elevated to a sprint blocker
- AI must present the blocker to the user before continuing with other sprint items
- Gap cannot be silently deferred or classified as non-blocking

**Evidence pattern:**
```
automatically a blocker
```

**Mutation target:**
```
the gap is automatically a blocker. It must be resolved before the current sprint's Close Gate.
```

---

### EG-S08
- id: EG-S08
- category: entry_gate
- title: Bootstrap — VCS=none uses Entry Gate notes as Phase 1b fallback

**Situation:** During bootstrap, the user answers that the project has no VCS (VCS=none).

**Required behavior:**
- Phase 1b must NOT attempt to run git diff
- Phase 1b must fall back to Entry Gate implementation plan notes
- Q11 (commit style) must be skipped entirely

**Evidence pattern:**
```
VCS=none.*Phase 1b|Phase 1b uses Entry Gate notes
```

**Mutation target:**
```
If VCS=none: skip Q11 (commit style); Phase 1b uses Entry Gate notes
```

---

### SC-S01
- id: SC-S01
- category: sprint_close
- title: Sprint Close — Failure Encounters must be transferred to Failure Mode History

**Situation:** Sprint Close step 7: the AI is processing the retrospective and
has filled the Failure Encounters table from the sprint.

**Required behavior:**
- Rows must be explicitly transferred to TRACKING.md §Failure Mode History
- Transfer must include the Detection column (test / user-visual / profiler)
- Empty Failure Encounters table → step is incomplete, not skipped

**Evidence pattern:**
```
Transfer rows to TRACKING.*Failure Mode History
```

**Mutation target:**
```
Transfer rows to TRACKING.md §Failure Mode History (include Detection column:
```

---

### AS-S01
- id: AS-S01
- category: audit_signal
- title: Audit signal fires — AI MUST surface immediately and wait for YES/NO

**Situation:** During any checkpoint, an audit signal condition is detected
(e.g., metric regression, new failure category).

**Required behavior:**
- AI must surface the signal to the user immediately using the ⚠ AUDIT SIGNAL format
- AI must NOT silently continue past the signal
- AI must wait for explicit user YES/NO before proceeding

**Evidence pattern:**
```
Surface it to the user immediately using.*AUDIT SIGNAL
```

**Mutation target:**
```
Surface it to the user immediately using the ⚠ AUDIT SIGNAL format
```

---

### SC-S02
- id: SC-S02
- category: sprint_close
- title: Sprint Close — Entry Gate report file must be deleted

**Situation:** Sprint Close: the sprint has been closed and the Entry Gate report
file (S<N>_ENTRY_GATE.md) still exists on disk.

**Required behavior:**
- File must be deleted as part of Sprint Close
- It is a sprint-scoped temporary artifact — its purpose is fulfilled at close
- Deletion must be an explicit step, not assumed

**Evidence pattern:**
```
Delete.*ENTRY_GATE
```

**Mutation target:**
```
its purpose (sprint-scoped reference) is fulfilled.
```

---

### AS-S02
- id: AS-S02
- category: audit_signal
- title: Dismissed signal threshold — twice dismissed suppresses re-surface

**Situation:** An audit signal has been dismissed by the user twice for the same
system. The condition persists. At the next checkpoint, the same signal would fire again.

**Required behavior:**
- Signal dismissed twice for the same system must NOT be re-surfaced again
- Re-surface only if a new trigger fires (new data, new sprint item, etc.)
- This prevents alert fatigue from repeatedly surfacing ignored signals

**Evidence pattern:**
```
dismissed twice.*not re-surfaced
```

**Mutation target:**
```
A signal dismissed twice for the same system is not re-surfaced unless a new trigger fires.
```

---

### IL-S07
- id: IL-S07
- category: impl_loop
- title: D.6 incremental test run — previous item test FAIL is a regression

**Situation:** Implementation Loop D.6: after implementing a new item, the AI runs
all tests written so far. A test from a previous sprint item fails.

**Required behavior:**
- Previous item test failure = regression — must be fixed before writing any more code
- AI must NOT continue to the next item or skip the failure
- Max 3 fix attempts, then present options to user

**Evidence pattern:**
```
Run ALL tests written so far — current item
```

**Mutation target:**
```
Run ALL tests written so far — current item + all previous items in this sprint:
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
| EG-S07 | entry_gate       | Phase 1 Step 0: Sprint Close completion check      |
| IL-S01 | impl_loop        | Self-verify: 3 rounds max then escalate            |
| IL-S02 | impl_loop        | D.6 regression: fix before more code              |
| IL-S03 | impl_loop        | Visual verify: 3 attempts max then gap log         |
| IL-S04 | impl_loop        | Side fix: must be logged in Change Log immediately |
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
| IL-S05 | impl_loop          | Guardrails read before writing code (step A)       |
| GU-S01 | guardrail_update   | Unpredicted failure: user approves before guardrail added |
| GU-S02 | guardrail_update   | Update Rule: sprint-audit.sh + LESSONS_INDEX mandatory |
| AR-S01 | architecture_review| Same category 2+ times → Architecture Review flag  |
| FM-S01 | failure_modes      | Failure modes: 3-category analysis required        |
| SB-S01 | session_boundary   | Entry Gate complete: new session recommended (mandatory) |
| IL-S06 | impl_loop          | Must items done: Close Gate not auto-suggested     |
| CG-S07 | close_gate         | REGRESSION/INTEGRATION_GAP on Must item → automatic blocker |
| EG-S08 | entry_gate         | Bootstrap: VCS=none → Phase 1b uses Entry Gate notes |
| SC-S01 | sprint_close       | Failure Encounters transferred to Failure Mode History |
| AS-S01 | audit_signal       | Signal fires: surface immediately, wait for YES/NO |
| SC-S02 | sprint_close       | Sprint Close: Entry Gate report file deleted       |
| AS-S02 | audit_signal       | Signal dismissed twice: not re-surfaced without new trigger |
| IL-S07 | impl_loop          | D.6: previous item test FAIL = regression, fix before continuing |
