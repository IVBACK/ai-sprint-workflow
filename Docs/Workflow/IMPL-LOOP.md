<instructions>

# CRITICAL RULES (read first)
- NEVER silently expand scope. Flag to user if >5 files or cross-system effects.
- NEVER proceed past a failing step without user decision after 3 attempts.
- NEVER write a fix for an unconfirmed problem. Evidence required first.
- Partial fix (one site fixed, others left) is a BLOCKER.
- Close Gate is always user-initiated. AI does not ask "shall we close?" unprompted.
- Naked `// TODO` / `// FIXME` / `// HACK` without CORE-ID are flagged at Close Gate.

# Implementation Loop

**Prerequisite:** ENTRY-GATE.md completed.
**Next:** CLOSE-GATE.md when all items done.

IF user requests parallel execution:
  → See PARALLEL-EXECUTION.md. Do not load automatically.

## Sprint Branch (VCS=git only)

IF VCS=none: skip all branch/commit/merge steps. Traceability via TRACKING.md only.

```bash
git tag sprint-N-start          # tag on main before branching
git checkout -b sprint-N-impl
```

All commits go to `sprint-N-impl`. Main stays clean until Close Gate passes.

## Commit Rules

Commit after each item completes D.7 (AC exit check):
```
sprint-tools git commit CORE-### "one-line summary"
```

IF Q11 = conventional:
```
type(scope): subject
# type: feat|fix|refactor|test|docs|perf|chore
# scope: CORE-### or module name
# subject: imperative, lowercase, no period, max 72 chars
```
<examples>
feat(CORE-045): add terrain LOD hysteresis
fix(CORE-112): correct depth comparison in ocean pass
refactor(CORE-080): extract grid mapping to shared include
</examples>

IF Q11 = free-form: no enforced format, but reference CORE-ID.

## Merge Ceremony (after Close Gate, before Sprint Close step 1)

```bash
sprint-tools git merge N
```

- Push after merge (solo) or after PR approval (team — see TEAM-GUIDE.md)
- Conflicts: rebase sprint branch on main, resolve, re-verify affected items
- Push tags `sprint-N-start` and `sprint-N-close` to remote; delete remote sprint branch after merge

---

## Per-Item Loop (Must items in dependency order)

### A. Pre-code Check

1. Mark item `in_progress`:
   - Run: `Tools/sprint-tools item CORE-NNN in_progress` (do NOT edit TRACKING.md manually)
2. Read GUARDRAILS: §Index → §TL;DR for relevant sections → full section only if writing code in that area

3. **Observable evidence gate** (bug/quality/fix items only):
   - Confirm problem exists at runtime. Accepted: screenshot/video, profiler output, test failure, GPU/API readback, user report, reproducible error log.
   - Pure code analysis is NOT sufficient.
   - IF evidence cannot be produced → narrow scope to "investigate & reproduce" first.
   - Log: `"Evidence gate: CORE-### — [evidence type]: [summary]"`
   - SKIP IF: new feature (not a fix), or Entry Gate already documented evidence.

4. **Impact analysis** — answer before coding:
   1. What files will this touch?
   2. What behaviors change?
   3. How will you verify it works?
   - IF >5 files or cross-system effects not predicted at Entry Gate 9a → flag to user.
   - SKIP IF: trivially obvious (typo fix, config value change).

5. **Uncertainty check** (T7/T8 — all items):
   - T7: Rate confidence in chosen approach (0-100%). IF <70% → flag: `"Confidence gap: CORE-### — [area], [%]. Research? [y/N]"`
   - T8: IF domain was last researched >2 sprints ago OR API has known breaking changes → flag: `"Stale knowledge: CORE-### — [topic], last S<N>. Research? [y/N]"`
   - IF both clear → proceed silently. No log needed.
   - Reference: `AGENT-RULES.md §Research Triggers` for full T1-T8 list.

### A.5 Domain Research (conditional)

IF Entry Gate completed research for this item:
  → Read `Docs/Planning/S<N>_DOMAIN_RESEARCH.md` and summary in `S<N>_ENTRY_GATE.md` §Domain Research.
  → Verify findings still applicable. Proceed to B.

ELIF research trigger (T1-T6) now matches but was not caught at Entry Gate (T7/T8 already handled in A.2.5):
  → ASK user: "CORE-### needs domain research: [trigger, reason]. Research now? [y/N]"
  IF approved:
    1. Search authoritative sources (papers, specs, reference implementations).
    2. Document exact formulas, algorithms, specifications.
    3. Cross-reference with 2+ sources.
    4. Append to `Docs/Planning/S<N>_DOMAIN_RESEARCH.md` (create if needed).
    5. Log in TRACKING.md §Change Log: `"Domain research for CORE-###: [topic] — sources: [list]"`
  IF declined:
    → Log `"Domain research: skipped by user"`, proceed.

ELSE (well-known patterns, no T1-T6 trigger, or research already done and valid):
  → Skip without asking.

### A.6 Approach Selection (conditional)

TRIGGER: multiple viable strategies AND choice significantly affects quality/performance/maintainability.

1. Identify 2+ candidate approaches.
2. Compare on: correctness/quality, project context fit (Critical Axis, architecture), implementation cost.
3. State selected approach with one-line rationale.
4. Log: `"Approach selection for CORE-###: chose [X] over [Y] — [reason]"`

SKIP IF: obvious single approach (CRUD, config change, test addition), or Entry Gate already specified.

### B. Write Code

- Follow guardrails and immutable contracts.
- IF scope-outside fix occurs → immediately log in TRACKING.md §Change Log:
  `"Side fix: [system] — [what wrong] — [what changed] — not a sprint item."`

### B.1 Fix Parity Check (after writing code)

IF change fixes a pattern (bug, anti-pattern, convention violation, missing guard):
  1. Re-run Q1 search that identified affected files.
  2. Verify every matching site received the same fix.
  3. IF remaining matches → apply fix to ALL before proceeding.
  - Partial fix = BLOCKER.

SKIP IF: new feature with no existing pattern, or Q1 found only one site.

### B.2 Approach Escalation Protocol

Applies to ALL retry loops in this document (§C self-verify, §D.5 visual, §D.6 test run).

```
WITHIN each attempt — approach escalation:
  L1: Direct fix — obvious solution, apply immediately
  L2: Alternative approach — same goal, different means
  L3: Deep investigation — read source, add logging, isolate variable
  L4: Decompose — break problem into smaller testable pieces
  L5: Escalate to user — present attempts + findings, ask direction

  RULE: Move to next level after ONE failed attempt with the SAME strategy.
        A substantively different fix at the same level is a new attempt at that level,
        not a reason to escalate. Max 2 attempts at any single level before moving up.
  ANTI-PATTERN: Repeating the same L1 fix hoping for a different result.
  Log transitions: sprint-tools note attempt "L1→L2: [reason]"

  L5 AND ATTEMPT COUNTER:
    L5 escalation does NOT consume an attempt. User direction starts a new attempt at L1.
    The 3-strike counter (§C, §D.6) increments only when an attempt concludes with
    a failed fix (code changed, result still wrong). For attempt limits and user options,
    see the calling section (§C, §D.5, or §D.6).
```

### C. Self-verify (5-point checklist)

Run before writing tests:
- [ ] Builds/parses without errors?
- [ ] Matches spec from Entry Gate?
- [ ] No duplication with existing code?
- [ ] Follows project conventions?
- [ ] Tech debt introduced? → fix now or document. Use `// TEMP(CORE-NNN): [reason]` format.

IF any fails: fix and recheck. Max 3 rounds. Apply Approach Escalation (§B.2) within each round.

**Research fallback (before 3rd attempt):** IF failure suggests incorrect domain knowledge (wrong values, math errors, spec non-compliance) → return to A.5 before 3rd attempt. Log: `"Research fallback triggered for CORE-### at self-verify round [N]"`

IF still failing after 3 → present to user:
  "(1) accept as known tech debt — log and continue,
   (2) block — do not proceed until resolved,
   (3) Sprint Abort if critical,
   (4) domain research — investigate root cause (resets attempt counter)."

### D. Write Tests

Match test type to Entry Gate 9b:
- Unit-testable logic → unit test
- Integration/async → integration test
- Visual/UI → manual check + screenshot

Each test must encode invariants from Entry Gate 9b.
Trivial tests ("it runs", "no exception") are NOT acceptable — apply Entry Gate step 12c criteria.

### D.5 Visual Verification (visual items only)

TRIGGER: item marked "manual+screenshot" in Entry Gate 9b.

1. Ask user specific visual questions about what to look for.
2. User responds:
   - "OK" → proceed to D.6
   - "Problem: [description]" → log, fix, ask again. Apply Approach Escalation (§B.2) within each attempt.
   - Max 3 attempts. IF still failing → log `"visual unconfirmed — target sprint [N]"` in evidence column. Mark `fixed` with caveat. Continue to D.6.
3. Automated proxy tests do NOT replace visual confirmation.

### D.6 Incremental Test Run

Run ALL tests (current + previous items this sprint):
- All PASS → proceed to D.6b
- FAIL on new test → fix implementation, rerun
- FAIL on previous item's test → regression: fix before writing more code
- Apply Approach Escalation (§B.2) within each attempt.
- Max 3 fix attempts → present to user:
  "(1) accept as known gap — log, mark pending,
   (2) block until resolved,
   (3) Sprint Abort if critical,
   (4) domain research (resets attempt counter)."

IF test needs unavailable infrastructure → mark "pending" in TRACKING.md → runs at Close Gate Phase 3.

### D.6b External Review (only if API key configured)

**How findings arrive:**
- Claude Code: automatic via cross-llm-audit hook (`additionalContext` injection after Edit/Write)
- Other agents: run `sprint-tools review <file>` manually and read output
- Sub-agents (worktrees): hook is skipped — run `sprint-tools review` manually instead

**Handling findings:**
- BLOCK → present to user. Do not proceed until user decides.
- WARN → fix the issue, then re-review the same diff (blind review or cross-LLM).
  - If re-review returns PASS → proceed.
  - If re-review returns WARN again → fix and re-review (max 3 attempts total).
  - After 3 attempts still WARN → present to user with all findings. User decides.
  - This follows the same escalation pattern as §B.2 Approach Escalation.
- PASS → mention as confidence signal, continue.
- Conflicting opinions → present both perspectives. User decides. Do not silently override.

**Self-audit comparison (after external findings arrive):**
1. Run structured self-audit (8-item for BLOCK/WARN, 3-item for PASS) on same diff.
2. Decision matrix:
   - AGREE → fix, then re-review to confirm fix is correct.
   - DISAGREE on BLOCK → escalate (mandatory).
   - DISAGREE on WARN → log disagreement, continue.
3. PASS → lightweight self-audit (bug scan, security, AC), mention as confidence signal.

See CROSS-LLM-AUDIT.md for setup.

### D.7 Acceptance Criteria Exit Check

Read item's ACs from S<N>_ENTRY_GATE.md. Check each:
```
## CORE-NNN Exit Check
- [x] AC1: "description" → file:line evidence
- [x] AC2: "description" → test_name evidence
- [ ] AC3: "description" → NOT MET → reason
```

- Every AC must have verdict (met / not met).
- "Met" requires specific file:line or test name. Not "I implemented it."
- "Not met" requires explanation.
- All met → run `git diff | sprint-tools review --stdin`, fix issues, proceed to E.
- Any not met → fix now, or mark `partial` with explanation. User decides at Close Gate.

### E. Update TRACKING.md

1. Run: `sprint-tools item CORE-NNN fixed "key decisions"` (do NOT edit TRACKING.md manually).
   When later marking `verified`, include confidence level per AGENT-RULES.md §Evidence Standards (VERIFIED/INFERRED/UNCERTAIN).
2. Write engineering lessons to CODING_GUARDRAILS.md and architectural decisions to CLAUDE.md (see AGENT-RULES.md §Finding Materialization — do not defer).
3. IF bugs/failures encountered → log each to §Failure Encounters:
   `[item ID] | [category: direct/interaction/stress-edge] | [description] | [how detected]`

**AUTO-DETECTION CP3:** During any step — past sprint API missing/broken, past test now FAIL, profiler contradicts past metric by >20% (current sprint did not modify that system)?
  → Surface AUDIT SIGNAL to user immediately. Do not silently continue.
  → "(1) Pause — open Retroactive Audit now, (2) Log signal — audit after sprint close."

## After All Must Items

Ask user: "Must items done. Continue with Should/Could items, or close sprint?"
- Should/Could items run the same A-E loop.
- This prompt fires only when AI completed final Must item in current session.
- Reading `verified` status from TRACKING.md at session start does NOT trigger this prompt.

# CRITICAL RULES (reinforced)
- NEVER silently expand scope. Flag to user if >5 files or cross-system effects.
- NEVER proceed past a failing step without user decision after 3 attempts.
- NEVER write a fix for an unconfirmed problem. Evidence required first.
- Partial fix (one site fixed, others left) is a BLOCKER.
- Close Gate is always user-initiated. AI does not ask "shall we close?" unprompted.
- Naked `// TODO` / `// FIXME` / `// HACK` without CORE-ID are flagged at Close Gate.

</instructions>
