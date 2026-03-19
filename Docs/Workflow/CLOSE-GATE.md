<instructions>

# CRITICAL — Top-of-file rules
- Mandatory user approval: Close Gate verdict ONLY. All other "present to user" steps are transparency checkpoints, not approval gates.
- AI MUST write the Close Gate report to `Docs/Planning/S<N>_CLOSE_GATE.md` BEFORE presenting verdict to user. The file is the record — verbal presentation alone is not sufficient. Evidence MUST include commit hashes. Note: after squash merge, `sprint-tools git merge` auto-updates evidence to the squash hash.
- Clean/minimal findings: batch into one combined report, do not pause.
- Significant findings (blocker, regression, MISSED failure mode): stop, present, ask.
- AI does NOT decide alone on deferrals, escalations, or Critical Axis findings.

# Close Gate — Sprint-End Audit

**Prereq:** IMPL-LOOP.md completed. **Next:** SPRINT-CLOSE.md after verdict approved.

> Parallel execution: IF user requests parallel, see PARALLEL-EXECUTION.md section Close Gate. Do not auto-load.

Read TRACKING.md Sprint Board and Entry Gate report before starting.

## Phase 0 — Metric Gate Check

1. For each sprint metric: verify measurability + evidence exists.
2. Failure mode coverage per modified subsystem:
   - 3 categories: direct / interaction / stress-edge
   - Each has metric or test. Missing: add or document as known gap with target sprint.
3. Verify all Entry Gate metrics. Status per metric: Met / Partially Met / Not Met / Deferred.
4. Unmet metric escalation (DEFERRED or MISSING):
   ```
   IF metric DEFERRED or MISSING:
     1. Explain — what blocks completion?
     2. Trace — blocker in roadmap (CORE-### entry)?
        IF not tracked → propose adding with sprint + priority
        IF tracked but no sprint → propose target sprint
     3. Recommend — gap analysis + concrete proposal to user
     4. User decides target sprint + priority
     5. `sprint-tools item CORE-NNN deferred "reason — target S[N]"`
   ```
5. Present full Metric Verification table to user (mandatory, regardless of path taken).
6. Log compact summary to TRACKING.md (NOT full table):
   `**Metric Verification:** X/Y PASS, Z DEFERRED (item-id reason -> S<N>, ...)`

## Phase 1a — Automated Scan

1. Run `Tools/sprint-audit.sh`.
2. Handle exit codes:
   ```
   IF exit_code == 2 (setup error):
     Fix script config. Do NOT skip scan.
     IF script cannot be adapted → present to user, get approval, log reason in TRACKING.md
   ELIF exit_code == 1 (findings):
     Review each finding. Fix immediately or log with target sprint (user decides).
     Blocker findings (e.g. UNTRACKED_DEBT — naked TODO/FIXME/HACK without CORE-ID):
       Must resolve before gate pass.
       Options: formalize as `// TEMP(CORE-NNN): [reason]` + TRACKING.md entry, or resolve now.
     False positive review: matching is case-sensitive uppercase only (TODO, FIXME, HACK).
       camelCase (todoItems) not caught. SCREAMING_CASE (TODO_ITEMS) caught.
       Dismiss false positives with note in scan summary.
   ELIF exit_code == 0:
     Proceed (note "clean" to user).
   ```
3. Present scan summary to user before Phase 1b.

## Phase 1b — Spec-driven Audit

Load before starting:
- TRACKING.md section Predicted Failure Modes (Entry Gate 9a)
- S<N>_ENTRY_GATE.md verification plan per item (Entry Gate 9b invariants)

```
IF TRACKING.md Change Log shows "Entry Gate (abbreviated)":
  Skip step b for all items (no failure mode predictions written).
  Step c (verification plan 9b-lite) still applies.
ELSE:
  Run steps a, b, c for each item.
```

For each completed item (Must + Should + Could):

a. **Find implementing files:**
   - git: `git diff` filtered by item context
   - no VCS: read Entry Gate notes. If insufficient, ask user: "For [CORE-###], which files?" Log answer in TRACKING.md.

b. **Predicted failure modes — verify each individually:**
   - For each row in TRACKING §Predicted Failure Modes:
     Was the detection plan executed? (test exists and ran? code guard added?)
     IF detection plan NOT executed → finding (MISSED), not "handled"
   - Direct: breaks on its own? (null ref, off-by-one, wrong calc, missing guard)
   - Interaction: combining with other systems? (timing, shared state, dispatch order)
   - Stress/edge: extreme input/load/timing? (pool exhaustion, rapid oscillation, cascade)

c. **Verification plan invariants** (Entry Gate 9b): do they hold in implementation?

**Supplemental per-file check** (outside item scope):
1. Resource/memory leaks
2. Missing observability (logging, profiling)
3. Dead code and orphan scaffolding
4. Debug path parity with production

**Output:** per-item summary: `CORE-### -> failure modes: HANDLED / MISSED / N/A` + supplemental findings.
- HANDLED = applicable and addressed
- MISSED = applicable but not addressed — must fix or defer
- N/A = not applicable (justify; use sparingly)

Present summary to user before Phase 1c. Do not declare "audit complete" without per-item acknowledgment.

## Phase 1c — Fitness Review

Read sprint type from Entry Gate report (step 12a).

```
IF sprint type == abbreviated-gate:
  Skip Phase 1c entirely (fitness metrics not set at Entry Gate 9c).
```

Per completed item, answer:
1. Implementation complete, or happy-path only?
2. Integrates correctly with rest of system (not just isolation)?
3. Meets project's Critical Axis standard (not just "no errors")?

```
IF sprint type == hardening:
  Q1 focus: robustness (edge cases, error paths) over feature completeness
  Q3 focus: "more robust than before" over "meets new thresholds"
```

Per-item verdict: PASS or CONCERN (with explanation).
IF all items CONCERN with no actionable fix: flag to user before proceeding.

## Phase 2 — Fix

1. Fix immediately or log with target sprint (user decides).
2. Critical Axis rule:
   ```
   IF finding touches Critical Axis (read CLAUDE.md -> Project Summary -> Critical Axis):
     Stop. Present to user:
       "This finding touches [Critical Axis]. Deferring is high risk.
        Options: (1) fix now, (2) defer with written rationale + target sprint,
        (3) Sprint Abort if risk unacceptable."
     User must choose explicitly.
   ```
3. Deferred findings MUST be added to Roadmap.md as items (see AGENT-RULES.md section Finding Materialization).
4. Present fix/defer summary to user. Flag deferred Critical Axis findings separately.

## Phase 3 — Regression Test

1. All tests must PASS after fixes.
2. Include tests marked "pending" during D.6 that can now execute.
3. ```
   IF test fails (including previously pending):
     Return to Phase 2 — treat as new finding.
   IF same finding fails 3 times after fix attempts:
     Escalate: "(1) defer with target sprint, (2) Sprint Abort if critical." User decides.
   ```

## Phase 4 — Test Coverage Gap

1. **4a File-level:** new/modified code has matching test file?
2. **4b Item-level:** every completed item (Must+Should+Could) has behavioral test?
   No test: write one or document why untestable.
3. Log item-to-test mapping in TRACKING.md evidence.
4. Present coverage gap summary to user.
5. Final test run PASS.

## Close Gate Verdict & User Approval

1. Run `sprint-tools review` on Close Gate report (blind review). Fix issues found.
2. Confirm all phases completed and all Must items verified.
3. Present assessment:
   - **Metric summary:** X/Y PASS, Z DEFERRED (list + target sprints). Action breakdown: N existing, M written, K fixed, J revised, L added, P escalated.
   - **Findings summary:** N fixed, M deferred to target sprint, K untestable.
   - **Fitness summary:** X/Y PASS, Z CONCERN (list). Omit if Phase 1c skipped.
   - **Risk assessment:** clean / attention points (list).
   - **Recommendation:** "Gate passed — recommend closing sprint" or "Gate blocked by [X]."
4. User approves before Sprint Close begins.
   ```
   IF user does NOT approve:
     Identify concern -> return to relevant phase:
       Phase 0 (metrics) / 1a (scan) / 1b (audit) / 1c (fitness) /
       2 (fix/defer) / 3 (regression) / 4 (coverage)
   ```
5. After approval: `sprint-tools checkpoint "Close Gate complete — Sprint N approved, starting Sprint Close"`
6. Session boundary (mandatory): recommend fresh session for Close Gate. User may override. Close Gate + Sprint Close can share a session.

# CRITICAL — Bottom-of-file reinforcement
- Mandatory user approval: Close Gate verdict ONLY.
- AI does NOT decide alone on deferrals or Critical Axis findings.
- Deferred findings MUST be materialized in Roadmap.md.
- Blocker findings (UNTRACKED_DEBT etc.) must be resolved before gate pass.

</instructions>
