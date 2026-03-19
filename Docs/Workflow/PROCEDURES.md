<instructions>

# CRITICAL: AI never initiates scope changes, aborts, or contract revisions. User decides.

# Procedures — Special Operations

## 1. Mid-Sprint Scope Change

```
1. User requests scope change
2. AI assesses impact:
   a. Conflicts with in-progress items?
   b. Invalidates verified items?
      IF yes → regression. Re-assess failure mode, define verification test,
      log in TRACKING.md. Full Entry Gate NOT required.
   c. Pushes sprint over scope limit?
3. AI presents options:
   - Add as Must item (may push Should/Could to next sprint)
   - Add as Must + defer existing Must (user picks which).
     Deferred: `sprint-tools item CORE-NNN deferred "reason — target S[N]"` (handles Roadmap sync)
   - Add as hotfix (no ID, no gate — emergency only)
   - Defer to next sprint (log in Roadmap as sketch item)
4. User decides
5. Log in TRACKING.md Change Log:
   "Scope change: [date] — added [ID]. Reason: [why]. Impact: [what shifted]."
6. IF new Must added → `sprint-tools item CORE-NNN open` (creates entry + adds to Roadmap)
```

### Hotfix Criteria
```
IF critical bug OR security fix that cannot wait → eligible
ELIF new feature OR non-critical bug OR nice-to-have → NOT eligible
  AI flags: "Does not qualify as hotfix. Recommend adding as Must item."
  User may override.
Hotfix requires: TRACKING Change Log entry, test if testable,
  inclusion in Sprint Close step 7 retrospective.
  Only formal ID + gate process skipped.
```

**Rule:** Scope change != new Entry Gate. Existing plan stays valid; only added/removed items change.

## 2. Scope Negotiation

Trigger: features exceed sprint scope limit (Q2 at Initial Planning or Phase 0).

```
1. AI sorts features by dependency order + user priority
2. First N features (N = scope limit) → Must items
3. Remaining:
   IF critical but can't fit → ask: "Increase scope or defer?"
     Scope increase applies THIS sprint only. Permanent change requires
     explicit user request → log in CLAUDE.md §Operational Rules.
   ELIF nice-to-have → propose Should/Could or later sprint.
     User confirms before AI moves item.
4. Present allocation to user
5. User may override any placement (Must/Should/Could/later)
6. After approval → return to triggering step and continue
```

**Rule:** AI proposes, user disposes. Never silently drop features.

## 3. Immutable Contract Revision

Trigger: user explicitly requests change to a listed contract. AI never initiates.

```
1. Identify all code, tests, items depending on the contract
2. Identify blast radius (do NOT change any status yet):
   - Verified items invalidated?
   - In-progress items affected?
   - Guardrail rules referencing contract?
3. Present: "Changing [contract] affects [N] files, [M] verified items, [K] rules."
4. User confirms
5. `sprint-tools item CORE-NNN open "regression: contract change"` for each affected item
6. `sprint-tools checkpoint "Contract revised: [old] → [new]"`
7. Log TRACKING.md Change Log:
   "Contract revised: [date] — [old] → [new]. Reason: [why]. Affected: [list]."
8. Update/remove affected guardrail rules
```

## 4. Sprint Abort

Trigger: user requests abort. AI never initiates.

```
1. User requests abort
2. `sprint-tools item CORE-NNN deferred "sprint aborted — [reason]"` for each non-verified item
3. Verified items keep status (work not lost)
4. Branch cleanup (VCS=git only):
   IF verified items exist:
     git checkout main
     git tag sprint-N-pre-cherry-pick
     git cherry-pick <verified-commits>
     Run tests.
     IF tests fail → git reset --hard sprint-N-pre-cherry-pick
       git tag -d sprint-N-pre-cherry-pick
       Investigate: retry selectively or defer all.
     git tag sprint-N-abort
     git branch -D sprint-N-impl
   ELIF no verified items:
     git checkout main
     git tag sprint-N-abort
     git branch -D sprint-N-impl
   IF branch was pushed: git push origin --delete sprint-N-impl
5. Skip Close Gate
6. Run abbreviated Sprint Close: steps 1-4 + 6 + 9 only.
   Skip: 5, 7-8, 10, 11.
7. Log TRACKING.md Change Log:
   "Sprint aborted: [date] — Reason: [why]. Verified: [list]. Deferred: [list]."
8. Next sprint Entry Gate runs normally — deferred items reviewed at step 3
```

**Rule:** Abort != failure. Verified work persists, unfinished work deferred, not deleted.

## 5. Roadmap Realignment

Trigger: Roadmap.md/TRACKING.md/reality have drifted. User initiates. AI may suggest if drift detected at Entry Gate Phase 1.

### Phase 1 — Snapshot Reality
```
1. Open TRACKING.md Sprint Board
2. For each item, determine ACTUAL status:
   IF code exists and works → verified (add evidence)
   ELIF code exists but broken/incomplete → open or in_progress
   ELIF intentionally skipped → deferred (add reason + target sprint)
   ELIF abandoned → remove from Board, log in Change Log
3. Use `sprint-tools item CORE-NNN <status> "evidence"` for each transition. Check code — do not guess.
```

### Phase 2 — Sync Roadmap to TRACKING
```
4. Update Roadmap Sprint Overview Status column:
   IF all items verified → completed
   ELIF some items open → in_progress
   ELIF aborted → aborted
5. Walk each Roadmap sprint section:
   - TRACKING verified → Roadmap [x]
   - TRACKING deferred → Roadmap [~] + target sprint
   - TRACKING removed → delete from Roadmap
   - In TRACKING but missing from Roadmap → add
   - In Roadmap but missing from TRACKING → add to TRACKING or delete
6. Verify: every CORE-### appears in both files. No orphans.
```

### Phase 3 — Repair Forward Plan
```
7. Find items (open/in_progress/deferred) with no sprint or assigned to past sprint
8. User decides per item: assign next sprint / future sprint / drop (log removal)
9. IF next sprint overloaded → run Scope Negotiation
```

### Phase 4 — Log and Checkpoint
```
10. Log TRACKING.md Change Log:
    "Roadmap realignment: [date] — Reason: [why]. Moved: [list]. Removed: [list]. Added: [list]."
11. `sprint-tools checkpoint "Roadmap realignment complete — [summary]"`
12. Proceed to normal Entry Gate
```

## 6. Finding Materialization

Write findings to persistent files IMMEDIATELY. Never leave in conversation context only.

```
1. Classify:
   Bug/task/risk/blocker       → TRACKING.md
   Engineering lesson           → CODING_GUARDRAILS.md
   Arch decision/constraint     → CLAUDE.md §Immutable Contracts or §Operational Rules
   Scope change/deferred work   → Roadmap.md
   New domain topic             → SPRINT-INDEX.md
   Rule-to-sprint traceability  → CODING_GUARDRAILS.md (why note per rule)

2. Write immediately. Do not wait for session end, commit, or Close Gate.

3. Log source: "Source: cross-LLM audit WARN" / "Source: CP2 signal" /
   "Source: implementation observation" / "Source: Entry Gate research"

4. IF multiple findings at once → write ALL before continuing.
   IF > 3 items → use TodoWrite to track completion.
```

## 7. Retroactive Sprint Audit

Trigger (any one): runtime metric contradicts Close Gate verdict, later sprint can't build on output, guardrail regresses on verified code, user observes contradicting behavior, failure pattern traces to specific sprint.

Initiator: user or AI. AI proposes when detection signal fires; user confirms. One audit at a time. Max 3 months back.

```
1. Pin symptom + target sprint. Ask user: "Sprint N output appears broken: [symptom]. Proceed?"
2. Collect evidence: TRACKING verified items + metrics, Close Gate reports, Roadmap, git log
3. Re-run Close Gate measurements. Compare current vs claimed.
   IF PASS→FAIL or >20% delta → confirmed gap
   IF <5% delta → measurement variance, not gap
4. Classify root cause (exactly one per gap):
   REGRESSION | INTEGRATION_GAP | FALSE_VERIFICATION |
   COLD_STATE | SCOPE_DRIFT | ENVIRONMENT_DELTA
5. Create fix items via Mid-Sprint Scope Change or defer if non-blocking.
   IF gap affects current Must → blocker, resolve before Close Gate.
   Mark dependent items as `open (regression)` in TRACKING.
6. Log TRACKING.md Change Log:
   "Retroactive audit [date]: Sprint N — [count] gaps. Classifications: [list]. Fixes: [list]. Status: CLOSED."
```

### Auto-Detection Checkpoints

```
CP1 — Entry Gate: verified metric from past sprint now >5% worse,
       current sprint hasn't touched that system.
CP2 — Entry Gate: same failure category in 2+ recent sprints
       traces to a specific past sprint's output.
CP3 — Implementation: past-sprint API/buffer/output missing, wrong-shaped,
       or unexpected despite being marked verified.
CP4 — Close Gate: current Must item unverifiable because past-sprint
       dependency not working as claimed.
```

When checkpoint fires: describe observation, past claim, current state. Ask user whether to open audit.

### Integration Points

- **Entry Gate step 3:** Check TRACKING §Retroactive Audits for `open (regression)` items.
- **Entry Gate step 9a:** Include audits closed in last 3 sprints in pattern analysis. Multiple same-category → "Architecture Review Required".
- **Close Gate Phase 1b:** Verify dependencies use post-audit (corrected) state.
- **Sprint Close step 7:** Cross-ref: did a past audit predict this gap category?
- **Sprint Close step 6:** §Retroactive Audits exists and is current? Unclosed audits → resolve before "done".

# CRITICAL: AI never initiates scope changes, aborts, or contract revisions. User decides.

</instructions>
