# Decision Paths — WORKFLOW.md Reference

All decision points, loops, and gate guards in the workflow.
Source line numbers refer to WORKFLOW.md.
Reference for logic review — each row can be challenged with "is this correct?"

---

## Symbols

- **Decides:** `user` / `AI` / `both` — who makes the decision?
- **?** — ambiguity / gap / potential issue

---

## 1. Bootstrap (Lines 12–148)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| B-01 | Project state detection | No source code and no workflow files? | Greenfield → continue to step 1 / Migration → read Migration Rules, then step 1 | AI | "Any workflow file" = CLAUDE.md, TRACKING.md, Roadmap.md. What if only one exists? |
| B-02 | Step 4: Roadmap.md status | Roadmap empty / no sprint items? | Run Initial Planning / Skip if design-first path exists / Migration → "what are you currently working on?" | AI | What triggers design-first path? Should user declare it, or should AI detect it? |
| B-03 | Discovery Q3 | Existing roadmap/task list? | No → create Roadmap.md / Yes → validate format, convert / Scattered → user provides source, AI extracts | AI + user | What does "validate format" mean? Which formats are unacceptable? |
| B-04 | Discovery Q0 | Language unclear and project empty? | Suggest 2-3 options → user picks | user | What if user doesn't pick? Q0 note says "do not proceed without" but no enforcement. |
| B-05 | Discovery Q7: test framework | Not detected and not specified? | Install now → recommended framework / Defer to Sprint 2 → log known gap at Close Gate Phase 4 | user | Who determines "recommended framework"? |
| B-06 | Step 9: Setup confirmation | Setup completed | Confirm to user → wait / Start Entry Gate | user | What form does "explicit confirmation" take? Any message? |

---

## 2. Entry Gate — Phase 0: Sprint Detail (Lines 419–443)

*(Conditional: runs if sprint is still a one-line sketch)*

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| EG0-01 | Phase 0 activation | Sprint has Must/Should/Could? | Yes → skip Phase 0 / No/Sketch → run Phase 0 | AI | Where is the boundary between "one-line sketch" and "partial decomposition"? |
| EG0-02 | 0d Pass 1: Distribution check | All items in Must? / Should/Could zero? / Must item lacks dependency and metric? | Flag to user → user decides final placement | user | AI "flags" but with what evidence? |
| EG0-03 | 0d Pass 2: Dependency promotion | If this Should/Could item is removed, will a Must item's metric gate FAIL? | YES → promote to Must / NO → keep current priority | AI | How does AI detect this dependency? What if metric gate definition is incomplete? |
| EG0-04 | 0e: User approval | User does not approve sprint plan | Identify concerns → redo 0b-0d → re-present / Sprint direction fundamentally wrong → Sprint Abort | user | No criteria for "fundamentally wrong." Who decides? Always user, but trigger is ambiguous. |
| EG0-05 | Scope limit exceeded | Item count exceeds scope limit? | Apply §Scope Negotiation | AI + user | How does the Phase 0 loop close after going to Scope Negotiation? |

---

## 3. Entry Gate — Phase 1: State Review (Lines 445–470)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| EG1-00 | Step 0: Sprint Close completion check | TRACKING.md §Change Log has "Sprint Close: complete" for previous sprint? | Yes → continue / No → warn user, ask whether to proceed; if proceeding → log in §Open Risks | user | Does not block — user can override. Risk: guardrails from previous sprint may be missing. |
| EG1-01 | `blocked` item | Blocker still active? | No longer active → update status to `open` / Still active → carry as `blocked` or drop | user | Who decides to drop? Left open. |
| EG1-02 | `blocked` item | §Open Risks has R-### entry? | Yes → continue / No → create now (ID, Risk, Mitigation, Target Sprint) | AI | How is new R-### ID assigned? No rule. |
| EG1-03 | `deferred` item | Still valid? | Carry / drop | user | No decision criteria. |
| EG1-04 | `open` / `in_progress` item | Still in scope? | Carry | user | Only "user decides" — no recommendation. |
| EG1-05 | `fixed` (not verified) | What to do? | Verify now / Carry for verification | user | Does "verify now" happen at this gate? Or after Implementation Loop? Depends on context. |
| EG1-06 | §Open Risks: Architecture Review Required flag | Present? | Process at step 9a as Priority 1 — run Architecture Review first | AI | Does this flag block Entry Gate? Or just set priority? Doesn't block but critical — ambiguous. |
| EG1-07 | §Change Log: deferred metric from prior Close Gate | Present and sprint number matches? | Ask user: resolvable this sprint? / Still deferred → update target sprint | user | What criteria for "resolvable"? Without AI recommendation, what info does user have to decide? |
| EG1-08 | §Performance Baseline: CP1 signal | Significant regression compared to past metric? | ⚠ AUDIT SIGNAL → surface, suggest Retroactive Audit | AI | Does Entry Gate pause when signal fires? Or continue and defer to later? |

---

## 4. Entry Gate — Phase 2: Dependency Verification (Lines 472–479)

*(Skip in Sprint 1)*

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| EG2-01 | Dependency sprint check | Dependent sprint has `deferred` items? | Current sprint depends on those specific items? → Yes: flag to user / No: dependency satisfied | AI | How is "depends on" determined? Is dependency always explicitly documented in Roadmap? |

---

## 5. Entry Gate — Phase 3: Strategic Validation (Lines 482–569)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| EG3-01 | Step 8: Strategic alignment | Item no longer valid? | keep / modify / defer / remove | user | Are all 4 options available for every item? "remove" vs "defer": remove is permanent, defer is not. |
| EG3-02 | Step 8: modify | Item updated | Re-run 9a-9c for this item | AI | If Must count changes after modify, does it loop back to step 10? Not explicit. |
| EG3-03 | Step 9a: Failure Mode History pattern | Same category 2+ times in last 3 sprints? | Architecture Review Required → run step 9a procedure | AI | Does Architecture Review block Entry Gate? Or just add a step? Added to process but blocking is unclear. |
| EG3-04 | Step 9a: user-visual detection pattern | Same detection=user-visual 2+ times? | Suggest proxy test → current sprint Must / next sprint Must / accept manual (write rationale) | user | If user selects "accept manual," does the same flag fire again next sprint? Infinite loop risk. |
| EG3-05 | Step 10: Must item count | 0 Must? | Return to Phase 0 step 0b (redesign scope) / §Sprint Abort (goal no longer viable) | user | Who decides: redesign or abort? No criteria — just "if sprint goal is no longer viable." |
| EG3-06 | Step 10: Must item count | 1-8 Must: normal | Continue | — | Upper limit is 8. What if user chose different scope size at Q2? (small: 3-5, large: 8-12) Is limit fixed at 8, or tied to Q2? |
| EG3-07 | Step 9b: metric threshold | Metric passes but system may be broken? | Tighten threshold / add scenario constraint | AI + user | Is this step mandatory? Or only "if found"? |
| EG3-08 | Step 12c: User does not approve | General disapproval | Identify concern → return to Phase 0 (scope issue) / return to Phase 3 (strategic/metric issue) / Sprint Abort | user | Return target for Phase 1 or Phase 2 issues is undefined. |
| EG3-09 | Step 12c: Test scenario quality | Trivial scenario ("it runs") | Send back to 9b | user | No max round count for this loop. |
| EG3-10 | Abbreviated gate trigger | ≤3 Must items AND no cross-sprint dependency | Abbreviated (fast) / Full (comprehensive) | user | AI cannot choose abbreviated without approval — correct. If user doesn't respond or is ambiguous → full gate runs. ✓ |
| EG3-11 | Priority & rigor: Should → Must? | Must item lacks dependency and metric? | "should it be Should?" flag | AI | This flag also exists at step 0d (Pass 1). Is it checked again at step 9a? Duplicate check? |
| EG3-12 | Domain Research (conditional) | Item requires domain-specific knowledge (math, protocols, algorithms)? AI uncertain about correctness? | Research (search authoritative sources, extract formulas, cross-reference 2+ sources, record in Entry Gate report) / Skip (well-known patterns, already verified) | AI | How does AI reliably self-assess "uncertain"? Trigger is subjective. Mitigated by reactive fallback in IL. |

---

## 6. Implementation Loop (Lines 575–636)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| IL-00 | A.5 Domain Research (conditional) | Item flagged `research: done` at Entry Gate, OR AI encounters uncertainty during pre-code check | Read Entry Gate §Domain Research / Execute new research (search, extract, cross-ref, log) / Skip (well-known patterns) | AI | Reactive fallback also triggers at self-verify (2 failed attempts suggesting knowledge gap). |
| IL-01 | C. Self-verify checklist | Any item fails | Fix → recheck / Max 3 rounds, still failing → escalate | user (escalation) | What does "escalate" mean? What does user do? Continue? Sprint Abort? Accept as debt? Undefined. |
| IL-02 | D. Test type selection | What was specified at Entry Gate 9b? | Unit / Integration / Manual+screenshot | AI | What if multiple types were specified at 9b? |
| IL-03 | D.5: Visual verification | User "OK" / "Problem: [desc]" | OK → proceed to D.6 / Problem → fix, ask again / Max 3 attempts → known gap (target sprint) | user | After max 3 attempts, is item marked `fixed`? Or another status? Does "known gap" affect item status? |
| IL-04 | D.6: Incremental test | All PASS / FAIL new / FAIL previous | All PASS → continue to E / FAIL new → fix, rerun / FAIL previous (regression) → fix before writing more code | AI | Max 3 fix attempts → escalate. But "escalate" is also undefined here. |
| IL-05 | D.6: Test infrastructure missing | Tests cannot run locally | Mark as "pending" → will run at Close Gate Phase 3 | AI | What if it fails at Close Gate Phase 3? Phase 3 only says "all tests PASS" — is this blocking for pending tests? |
| IL-06 | After all Must items | Must items completed | Continue with Should/Could / Close the sprint | user | This prompt only fires "when AI completes." If TRACKING shows verified at session start, it doesn't fire. ✓ |
| IL-07 | CP3: Auto-detection | Past API missing/broken, past test FAIL, metric >20% regression | ⚠ AUDIT SIGNAL → surface, do not silently continue | AI | Does implementation pause when signal fires? Or is it just a notification? |

---

## 7. Close Gate (Lines 639–817)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| CG-01 | Phase -1: State recovery | Files missing / state ambiguous? | Ask user before continuing | user | Which missing files constitute "ambiguous state"? Only TRACKING.md? Roadmap.md too? |
| CG-02 | Phase -1: Entry Gate report missing | S\<N\>_ENTRY_GATE.md not found | Roadmap.md sprint section + TRACKING.md §Sprint Board → fallback source | AI | Fallback metric gate definitions in Roadmap may lack detail. Is this a risk? |
| CG-03 | Phase 0: Metric status | For each metric: PASS / DEFERRED / FAIL / MISSING | PASS → continue / DEFERRED → escalation procedure / FAIL or MISSING → if unresolvable, escalate (accept gap or Sprint Abort) | user | DEFERRED metric escalation: user picks target sprint. But without AI recommendation, what info does user have to decide? |
| CG-04 | Phase 0 Guard: ALL metrics DEFERRED | All metrics are DEFERRED | Gate blocked → at least 1 metric must PASS | — | What happens next? Sprint Abort? Are options presented to user? Only says "gate blocked," next step is unclear. |
| CG-05 | Phase 1a: sprint-audit.sh | Exit code 0 / 1 / 2 | 0 → continue / 1 → review each finding, fix or log (user decides) / 2 → fix configuration, skip with log if needed | user (exit 1) / AI (exit 2) | Exit 2 can also be "skipped" (unsupported language case). Is this a security gap? |
| CG-06 | Phase 1b: Abbreviated gate check | TRACKING Change Log has "Entry Gate (abbreviated)"? | Yes → skip step b (predicted failure modes weren't written) / No → normal (a, b, c) | AI | Risk of this check producing false results? What if Change Log uses a different wording? |
| CG-07 | Phase 2: Finding | Fix / Defer | Fix / Defer (user decides) / Critical Axis finding → 3 options: fix, defer+rationale, Sprint Abort | user | Can user "defer" every finding? No restriction — only Critical Axis forces stop+confirm. |
| CG-08 | Phase 3: Regression tests | ALL PASS? | PASS → Phase 4 / FAIL → ? | — | What happens on FAIL? Return to Phase 2? Fix tests? This path is undefined. |
| CG-09 | Pre-verdict guard | All 7 phases completed? | Any NO → run that phase | AI | Checklist is self-filled by AI. If a phase was truly skipped, can AI remember? Context window concern. |
| CG-10 | Verdict: User does not approve | User rejects Close Gate | Identify concern → return to relevant phase | user | "Relevant phase" — which phase maps to which concern? Not as explicit as Entry Gate. |

---

## 8. Sprint Close (Lines 821–893)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| SC-01 | Step 1: Roadmap checkmarks | [ ] items exist? | Apply unmet-metric escalation (explain, trace, propose, user decides) | user | Can a new Sprint Abort be triggered at this point? Procedure doesn't say. |
| SC-02 | Step 2: `fixed → verified` | Evidence column empty? | Empty → cannot mark verified, return to Phase 4b | AI | Where does the Close Gate process resume when returning to Phase 4b? |
| SC-03 | Step 5: Performance baseline | Measurable metric exists? | Yes → record + compare for regression / No → log "not yet established" | AI | What if regression is detected? Is Sprint Close blocked? Not specified. |
| SC-04 | Step 7e: Unpredicted failure | Unpredicted failure discovered | Write new guardrail rule (7-step Update Rule) | AI | Does this step extend Sprint Close? Is user approval part of the 7-step process? |
| SC-05 | Step 7f: Escalation trigger | Same category 2+ times / Same user-visual 2+ times | Record "Architecture Review Required" / "Proxy test?" flag in §Open Risks | AI | Is this flag only written to §Open Risks? Will next Entry Gate step 3 catch it? ✓ |

---

## 9. Mid-Sprint Scope Change (Lines 916–944)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| MS-01 | Urgent item entry | Item strains sprint scope | Add as Must / Add Must + defer existing Must / Hotfix (no ID, no gate) / Defer to next sprint | user | AI performs impact assessment (conflict? invalidation? scope limit?) but presents options. User decides. ✓ |
| MS-02 | Hotfix selected | Emergency situation | No formal ID/gate, but: Change Log entry + test if testable + include in Sprint Close step 7 | AI | How is "emergency only" defined? Can AI unilaterally say "this is not an emergency"? |
| MS-03 | Scope change impact: verified item invalidation | New item invalidates existing verified item? | Regression → §State Transitions (verified → open) | AI | Does regression detection require Entry Gate? Or just re-verification? Unclear. |

---

## 10. Sprint Abort (Lines 987–1004)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| SA-01 | Abort request | Who initiates? | User only — AI can never initiate | user | Sprint Abort also exists at end of Entry Gate (Step 0e, 12c). Same procedure for that scenario? ✓ |
| SA-02 | Non-verified items | Each non-verified item | Mark `deferred` + reason: "sprint aborted — [reason]" | AI | Verified items' status does not change. ✓ |
| SA-03 | Abbreviated Sprint Close | Which steps run? | Steps 1-4 + step 6 + step 13. Steps 5, 7-12, and 14 are skipped (no baselines, no FM retrospective, no archive maintenance) | AI | |

---

## 11. Session Recovery (Lines 255–258 — CLAUDE.md template)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| SR-01 | New session start | Before sprint started? | Read TRACKING.md → Roadmap → "Continue sprint N" or "Resume" | user | |
| SR-02 | New session start | Mid-sprint (in_progress or open items exist) | Resume from TRACKING.md | AI | What if Entry Gate was interrupted? (e.g., cut off at Phase 1.) No recovery path covers this. |
| SR-03 | New session start | After Close Gate | "Run Close Gate, sprint N" | user | What if Close Gate was interrupted? Phase -1 state recovery partially covers this. |

---

## 12. Retroactive Sprint Audit (Lines 1006–1397)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| RA-01 | Audit opening | Who opens? | AI → suggests, user approves / User → always | user (approval) | "Any time a trigger is observed" — trigger list is comprehensive but "user observes" is subjective. |
| RA-02 | AI detection signal | Signal fired | Surface immediately — do not silently continue | AI | Does current task pause when signal fires? Or is it just a flag? |
| RA-03 | Audit depth limit | Sprint older than 3 months | Present findings → §Open Risks → accepted tech debt / if user wants manual code archaeology → out of scope | user | How is "3 months" calculated? Are sprint dates always present in TRACKING.md? |
| RA-04 | Phase 4: Classification | Multiple categories apply | Priority order: REGRESSION > INTEGRATION_GAP > FALSE_VERIFICATION > COLD_STATE > SCOPE_DRIFT > ENVIRONMENT_DELTA | AI | Is this ordering always correct? SCOPE_DRIFT + REGRESSION can co-occur — which takes priority? |
| RA-05 | COLD_STATE staleness | Same metric 3+ consecutive sprints COLD_STATE | Take warm-start measurement → pass: measurement protocol fix / fail: reclassify as INTEGRATION_GAP | AI | "Consecutive" = measured in every sprint? What if some sprints don't measure the system? |
| RA-06 | Phase 5: Impact ≥ 3 items | 3+ items need re-verification | "Sprint Re-verification Cluster" flag → suggest dedicated re-verification sprint | AI | This is not an automatic Sprint Abort — just a suggestion. What if user declines? |
| RA-07 | Phase 6: Blocking escalation | Gap affects current sprint Must item? | Automatic blocker → resolve before close gate | AI | Does this pause current sprint? Or proceed in parallel? "Does not pause current sprint" is stated but blocker found → contradiction. |
| RA-08 | Dismissed signals | User rejected audit suggestion | Record in §Dismissed Signals / Suppressed after 2 dismissals / CP3 and CP4 are never suppressed | user | Does a suppressed signal ever resurface? Only says "suppressed after 2" — nothing after that. |

---

## 13. Scope Negotiation (Lines 946–960)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| SN-01 | Item count exceeds scope limit | Critical feature doesn't fit | Increase scope limit / Defer | user | Does "increase scope limit" permanently change the Q2-defined limit, or only for this sprint? |
| SN-02 | Item count exceeds scope limit | Nice-to-have feature | Should/Could / Later sprint sketch | AI | Is AI's "nice-to-have" decision unilateral? |

---

## 14. Immutable Contract Revision (Lines 962–985)

| ID | Trigger | Condition | Options | Decides | ? |
|----|---------|-----------|---------|---------|---|
| CR-01 | Contract change request | Who initiates? | User only — AI can never initiate | user | ✓ |
| CR-02 | Blast radius calculation | Verified items invalidated | `verified → open` (regression) | AI | Is this automatic? Can AI change status without user approval? Procedure places re-opening after "user confirms" (step 4) but re-opening appears automatic. |

---

## 15. Loops (Loop Summary)

| ID | Location | Max | Escalation | Fallback | ? |
|----|----------|-----|------------|----------|---|
| L-01 | Entry Gate — 0e re-present | Unspecified | Sprint Abort | — | No max round. Infinite loop risk? In practice, terminates because user decides. |
| L-02 | Entry Gate — 12c re-present | Unspecified | Sprint Abort | — | Same. |
| L-03 | Entry Gate — 9b trivial scenario | Unspecified | — | — | No max round. No limit defined for trivial test loop. |
| L-04 | Implementation — Self-verify | 3 | Escalate to user (4 options: accept debt / block / Sprint Abort / domain research) | Research fallback before 3rd attempt if knowledge gap suspected | Domain research resets attempt counter. |
| L-05 | Implementation — Visual verification | 3 | Known gap (target sprint) | Item logged as known gap | What is the known gap item's status? `fixed`? `deferred`? |
| L-06 | Implementation — Incremental test fix | 3 | Escalate to user (4 options: accept gap / block / Sprint Abort / domain research) | — | Domain research option resets attempt counter. |
| L-07 | Close Gate — Fix loop | Unspecified | — | — | How many fix-retest cycles in Phase 2? No limit. |

---

## 16. Gate Guards

| ID | Gate | Blocking Condition | Override | ? |
|----|------|--------------------|----------|---|
| G-01 | Entry Gate | User does not approve (step 12c) | Sprint Abort | ✓ |
| G-02 | Entry Gate | 0 Must items | Return to Phase 0 or Sprint Abort | "Return to Phase 0" starts a loop — no limit. |
| G-03 | Close Gate | Phase -1 cannot complete | Ask user — what if still cannot complete after asking? | Full blocking condition is unclear. |
| G-04 | Close Gate | ALL metrics DEFERRED | Gate blocked — next step unclear | Should Sprint Abort be suggested? |
| G-05 | Close Gate | MISSING or FAIL metric | Sprint Abort option if unresolvable | ✓ |
| G-06 | Close Gate | Any NO in pre-verdict 7-item checklist | Run that phase | Unreliable if AI loses context. Context window concern. |
| G-07 | Sprint Close | Item with empty evidence column | Return to Phase 4b | No loop limit. |
| G-08 | Sprint Close | Open audit (status ≠ CLOSED) | Sprint Close step 6 blocked | ✓ |

---

## 17. Data Flow — What Goes Where

| Produced | Producing Step | Consuming Step | ? |
|----------|----------------|----------------|---|
| §Predicted Failure Modes | Entry Gate 9a | Close Gate Phase 1b (step b) + Sprint Close step 7b | Cleared in abbreviated gate — Close Gate Phase 1b accounts for this. ✓ |
| §Failure Encounters | Implementation step E | Sprint Close step 7a | |
| §Failure Mode History | Sprint Close step 7d | Entry Gate 9a (pattern detection) | |
| §Performance Baseline | Sprint Close step 5 | Entry Gate Phase 1 step 3 (CP1) | |
| S\<N\>_ENTRY_GATE.md | Entry Gate step 12a | Close Gate Phase -1, Phase 1b | Deleted at Sprint Close step 13. |
| §Retroactive Audits | Retroactive Audit Phase 7 | Entry Gate step 3 + Sprint Close step 6 | |
| §Dismissed Signals | Audit dismissal | Entry Gate — CP1/CP2/CP3/CP4 checkpoints | CP3 and CP4 are never suppressed. ✓ |
| CORE-### metric gate | Entry Gate step 9c → Roadmap | Close Gate Phase 0 | Metric gate change requires step 12c approval. ✓ |
| §Domain Research | Entry Gate (conditional block) | Implementation Loop A.5 + Entry Gate report 12a | Findings recorded in Entry Gate report; consumed by A.5 before coding. |
| §Open Risks R-### | Entry Gate Phase 1 / Sprint Close step 7f | Entry Gate step 3 (Architecture Review flag) | |

---

---

## 18. Agreed Fixes — Review Complete

All 17 sections reviewed, 49 fixes agreed upon.
Each fix was applied to WORKFLOW.md. Applied fixes are marked `[APPLIED]`.

### Bootstrap

| # | ID | Fix |
|---|---|---|
| 1 | B-03 | Narrow the Q3 "Yes" definition: "Roadmap.md exists with Must/Should/Could format and CORE-### IDs → validate format and IDs only." Any other source/format → Scattered. |

### Entry Gate — Phase 0

| # | ID | Fix |
|---|---|---|
| 2 | EG0-04 | After 2nd re-present with no approval, AI explicitly asks: "Should we continue fixing the sprint plan, or Sprint Abort?" User decides. |
| 3 | EG0-05 | Add to end of §Scope Negotiation: "After user approval: return to the step that triggered Scope Negotiation and continue." |

### Entry Gate — Phase 1

| # | ID | Fix |
|---|---|---|
| 4 | EG1-01/03 | Clarify "drop" definition: "drop → delete from Roadmap + TRACKING.md, log removal in Change Log (same as step 8 remove path)." Applies to both blocked and deferred items. |
| 5 | EG1-02 | Add R-### ID assignment rule: "Assign next available R-### ID (continue from highest existing ID in §Open Risks, never reuse)." |
| 6 | EG1-05 | Clarify "verify now": "verify now (if test already exists and can be run) or carry forward for verification in Implementation Loop (user decides)." |
| 7 | EG1-06 | When Architecture Review Required flag is found, ask user: "Run review before continuing Entry Gate, or proceed and review at step 9a? (Review first recommended — result may affect scope.)" |
| 8 | EG1-07 | Ask deferred metric question with context: "Metric [X] was deferred from Sprint M. Reason at deferral: [reason]. Is the blocker now resolved?" |
| 9 | EG1-08 | Present options after CP1 signal: "⚠ AUDIT SIGNAL: [metric] regressed since Sprint N. Options: (1) open Retroactive Audit now (Entry Gate pauses), (2) log and continue Entry Gate, audit after sprint planning. User decides." |

### Entry Gate — Phase 2

| # | ID | Fix |
|---|---|---|
| 10 | EG2-01 | Implicit dependency check: "If cross-sprint dependency is not explicitly documented in Roadmap.md: flag to user — 'Sprint N depends on Sprint M output. Confirm this dependency still holds before proceeding.'" |

### Entry Gate — Phase 3

| # | ID | Fix |
|---|---|---|
| 11 | EG3-02 | Add to end of step 8: "After all items reviewed: if Must count now exceeds scope limit → apply §Scope Negotiation before proceeding to step 9." |
| 12 | EG3-03 | Architecture Review deferral → mandatory logging: "User defers → log in §Open Risks: 'Architecture Review deferred — category [X], sprints [list], target sprint [N].' Entry Gate step 3 picks this up next sprint." |
| 13 | EG3-04 | Link "accept manual" decision to §Dismissed Signals (Checkpoint: CP2). Suppressed after 2 dismissals for this item. If new user-visual failure is added, counter resets. |
| 14 | EG3-05 | When 0 Must, AI presents options with explanation: "0 Must items remain. Options: (1) return to Phase 0 to redesign scope — sprint goal is still valid but scope needs rework; (2) Sprint Abort — sprint goal is no longer viable. Which applies?" |
| 15 | EG3-06 | Tie the "1-8" fixed limit at step 10 to Q2: "1 to scope limit set at Q2: small=5, medium=8, large=12 Must items." |
| 16 | EG3-08 | Complete phase mapping (Entry Gate 12c): "return to relevant phase: Phase 0 (scope issues) / Phase 1 (state review concerns) / Phase 2 (dependency issues) / Phase 3 (strategic or metric issues)." |
| 17 | EG3-09 | Trivial test loop: after 2 revisions AI flags — "Options: (1) accept with documented rationale, (2) mark as untestable at gate (verify manually at Close Gate), (3) Sprint Abort if untestable and critical." User decides. |

### Implementation Loop

| # | ID | Fix |
|---|---|---|
| 18 | IL-01 | Define self-verify escalation: after 3 rounds — "Options: (1) accept as known technical debt — log and continue, (2) block — do not proceed until resolved, (3) Sprint Abort if critical. User decides." |
| 19 | IL-03 | After max 3 visual verification attempts: log visual gap in TRACKING.md evidence ('visual unconfirmed — target sprint [N]'). Mark item `fixed` with caveat. Continue to D.6. Close Gate Phase 1b flags for re-verification. |
| 20 | IL-04 | Define incremental test escalation: after 3 fix attempts — "Options: (1) accept as known gap — log, mark test pending for Close Gate, (2) block — do not proceed, (3) Sprint Abort if critical. User decides." |
| 21 | IL-05 | Pending test fail at Close Gate Phase 3: treat as new Phase 2 finding — fix immediately or defer with user decision (same escalation as Phase 2). |
| 22 | IL-07 | Present options after CP3 signal: "⚠ AUDIT SIGNAL during implementation. Options: (1) pause implementation — open Retroactive Audit now, (2) log signal and continue — audit after sprint close. User decides." |

### Close Gate

| # | ID | Fix |
|---|---|---|
| 23 | CG-02 | Entry Gate report fallback warning: "Entry Gate report missing — metric verification will rely on Roadmap thresholds only. Test scenario details may be incomplete." |
| 24 | CG-04 | Present options after ALL DEFERRED: "All metrics deferred — no verified work. Options: (1) resolve at least one metric now, (2) Sprint Abort. User decides." |
| 25 | CG-05 | Tie sprint-audit.sh skip decision to user: "sprint-audit.sh cannot run ([reason]). Proceeding with manual audit only (Phase 1b). Confirm?" User approves. |
| 26 | CG-08 | Phase 3 fail path: "If any test fails: return to Phase 2 — treat as new finding (fix immediately or defer with user decision)." |
| 27 | CG-09 | Log after each Close Gate phase: "After completing each phase: log to TRACKING.md Change Log: 'Close Gate Phase [X]: complete — [date].'" |
| 28 | CG-10 | Complete phase mapping (Close Gate verdict): "Phase 0 (metric) / Phase 1a (automated scan) / Phase 1b (audit) / Phase 2 (fix/defer) / Phase 3 (regression) / Phase 4 (coverage)." |

### Sprint Close

| # | ID | Fix |
|---|---|---|
| 29 | SC-01 | Remove Sprint Abort option at Sprint Close step 1. Replace with: "If gap unacceptable and cannot be deferred: reopen Close Gate Phase 0 for that item." |
| 30 | SC-02 | No evidence → return point: "Return to Close Gate Phase 4b, then re-run Phase 3, then return to Sprint Close step 2." |
| 31 | SC-03 | Performance regression: "⚠ Options: (1) fix now — reopen Close Gate Phase 2, (2) accept and log in §Open Risks with target sprint. User decides." |
| 32 | SC-04 | User approval before §Update Rule step 3: "Unpredicted failure [X] suggests guardrail: [rule]. Add to CODING_GUARDRAILS.md?" User approves before steps 3-7. |

### Sprint Abort

| # | ID | Fix |
|---|---|---|
| 33 | SA-03 | Abbreviated Sprint Close includes step 6: "steps 1-4 + step 6 + step 13. Skip steps 5, 7-12, and 14." |

### Session Recovery

| # | ID | Fix |
|---|---|---|
| 34 | SR-02 | Entry Gate intermediate logging: "After completing each Entry Gate phase: log to TRACKING.md Change Log: 'Entry Gate Phase [X]: complete — [date], steps executed: [list].'" |

### Mid-Sprint Scope Change

| # | ID | Fix |
|---|---|---|
| 35 | MS-02 | Hotfix criteria: "Hotfix = critical bug or security fix. Not eligible: new features, non-critical bugs. AI flags if not qualifying. User overrides if needed." |
| 36 | MS-03 | Regression mini-analysis: "Before implementing fix — AI re-assesses: what failure mode? What test will verify? Log in TRACKING.md. Full Entry Gate not required." |

### Retroactive Sprint Audit

| # | ID | Fix |
|---|---|---|
| 37 | RA-04 | Secondary category: "If multiple categories apply: assign primary per priority order. Note secondary in evidence column." |
| 38 | RA-05 | COLD_STATE "consecutive" definition: "Consecutive = consecutive sprints in which this metric was measured. Unmeasured sprints don't count toward or reset counter." |
| 39 | RA-06 | Log re-verification cluster decline: "User declines → log in §Open Risks with item list. Entry Gate next sprint re-checks at step 3." |
| 40 | RA-07 | Clarify audit pause contradiction: "Audit does not pause implementation. However, if blocker for Must item found: gate blocked until resolved." |
| 41 | RA-08 | Suppress reset condition: "Suppressed signal reactivates if condition worsens: metric delta increases or new failure in same system. Counter resets to 0." |

### Scope Negotiation

| # | ID | Fix |
|---|---|---|
| 42 | SN-01 | Scope increase: "Increase scope: this sprint only. Q2 default unchanged. Permanent change: user explicitly requests, AI logs in CLAUDE.md §Operational Rules." |
| 43 | SN-02 | Nice-to-have: "AI proposes Should/Could or later sprint. User confirms placement before AI moves the item." |

### Immutable Contract Revision

| # | ID | Fix |
|---|---|---|
| 44 | CR-02 | Status change after approval only: "Step 2: identify (don't change status). Step 4: user confirms. After confirmation: mark verified → open + update contracts + log." |

### Loop Limits

| # | ID | Fix |
|---|---|---|
| 45 | L-02 | Entry Gate 12c loop limit: after 2nd rejection — "Options: (1) return to specific phase for targeted rework, (2) Sprint Abort. User decides." |
| 46 | L-07 | Close Gate fix loop: same finding fails 3 times → "Options: (1) defer with target sprint, (2) Sprint Abort if critical. User decides." |

### Gate Guards

| # | ID | Fix |
|---|---|---|
| 47 | G-02 | Step 10 loop limit: "Return to Phase 0 twice and still 0 Must → force Sprint Abort. User confirms." |
| 48 | G-07 | Evidence loop: "Return to Phase 4b twice, still no evidence → Options: (1) untestable — stays fixed not verified, (2) defer with target sprint. User decides." |

### Data Flow

| # | ID | Fix |
|---|---|---|
| 49 | DF-01 | §Open Risks cleanup: "At Sprint Close step 6: review R-### entries. Resolved → mark 'RESOLVED — [date]'. Don't delete. Older than 3 sprints + RESOLVED → archive to Docs/Archive/." |
