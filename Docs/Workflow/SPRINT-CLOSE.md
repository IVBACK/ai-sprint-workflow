<instructions>

# CRITICAL — Read First

- **Prerequisite:** CLOSE-GATE.md verdict approved before starting.
- Every `[ ]` item requires action — NEVER silently skip.
- Empty evidence column = item CANNOT be marked `verified`. No exceptions.
- Do NOT invent fake baselines. Do NOT prune guardrails automatically. Do NOT skip user handoff.

---

# Sprint Close — Post-Gate Finalization

## 1. Roadmap Checkmarks

Run `sprint-audit.sh`. Focus on Section 11 output. Fix all mismatches before ticking.

```
[x] = TRACKING.md verified (gate evidence logged)
[~] = skipped + reason documented inline
[ ] = not verified (open, in_progress, or fixed without evidence)
```

IF item is `[ ]`:
  Apply unmet-metric escalation from Close Gate Phase 0
  (explain gap, trace blocker, propose target sprint, user decides).
  IF gap unacceptable AND cannot be deferred:
    Reopen Close Gate Phase 0 for that item.
    Do NOT mark sprint done until resolved or user-accepted.

After all checkmarks applied:
- Archive completed sprint sections older than 1 sprint to `Docs/Archive/roadmap-archive.md`.
- Keep active sprint + 1 previous sprint in `Roadmap.md`.
- Sprint Overview table stays in `Roadmap.md`.

## 2. TRACKING.md `fixed → verified` Transition

For each item being marked `verified`, confirm:
- Evidence column filled (test file:line or run reference from Close Gate Phase 4b).
- Status was `fixed` (not `open` or `in_progress`).

IF evidence column empty:
  Return to Close Gate Phase 4b → re-run Phase 3 → return here.
  IF returned to Phase 4b twice, still no evidence:
    Escalate to user: "(1) mark untestable — stays `fixed`, document rationale, (2) defer with target sprint."

Use `sprint-tools item CORE-NNN verified "evidence"` for each transition. Update completed Should/Could the same way.

## 3. CLAUDE.md Checkpoint

Run: `sprint-tools checkpoint "Sprint N closed. Next: [focus]"`

## 4. Changelog Archive

Run: `sprint-tools close N` (handles archive + cleanup).

## 5. Performance Baseline Capture

> **Automation:** `Tools/sprint-tools baseline <metric> <value> <unit> <method>` for baselines, `Tools/sprint-tools close <N>` for archive/cleanup.

Record measurable metrics. Compare vs previous sprint.

IF regression detected:
  Surface to user: "Performance regression: [metric] was [X] in Sprint N-1, now [Y].
  (1) fix now — reopen Close Gate Phase 2, (2) accept and log in Open Risks with target sprint."
  IF user accepts intentional regression:
    Add new row to Performance Baseline Log with accepted value (resets comparison baseline).

IF no measurable metrics yet:
  Log: "Performance baseline: not yet established. Target: [metrics] by Sprint [N]."
  Do NOT invent fake baselines.

## 6. Workflow Integrity Check

- **Open Risks cleanup:** Review each R-### entry. Resolved → mark "RESOLVED — [date]." Do NOT delete. Entries older than 3 sprints + RESOLVED → may archive to `Docs/Archive/`.
- **Document Contract refs:** CLAUDE.md target files/sections exist?
- **Guardrails consistency:** Entry Gate / Close Gate consistent with `Docs/Workflow/` procedures?
- **Step verification:** Verify each numbered step in `Docs/Workflow/` has a corresponding action. Do NOT manually count steps/phases.
- IF mismatch: fix before closing. IF irreconcilable: document in TRACKING.md Open Risks with target sprint.

## 7. Failure Mode Retrospective

IF no failures occurred: state so, skip analysis.

IF failures occurred, analyze each:
- Predicted in Entry Gate failure modes? (compare Predicted vs Encounters)
- Category: direct bug / interaction issue / stress-edge case
- Root cause: missing test / wrong assumption / incomplete spec
- Add unpredicted patterns as guardrail rules (with user approval)
- Transfer each Failure Encounter row to §Failure Mode History. During transfer, add:
  Root Cause (one sentence), Guardrail (rule reference or "none"), Escalate? (yes/no).
  Use consistent category naming (type:subsystem format, e.g., null-ref:Renderer).

### 7a. Escalation Triggers

Check Failure Mode History:
- Same category 2+ times in last 3 sprints → flag "Architecture Review Required" at next Entry Gate.
- Same `detection=user-visual` 2+ times → flag "Can automated proxy test replace visual check?" at next Entry Gate.
- Record flags in TRACKING.md Open Risks (Entry Gate 9a picks them up).

### 7b. Sprint Index Update

Update `Docs/SPRINT-INDEX.md`:
- Scan TRACKING.md for significant entries (failures, decisions, guardrails).
- Add one-line summary under relevant topic heading, newest first.
- Before creating new topic heading: scan existing headings for synonyms (e.g. `auth` vs `authentication`). Reuse existing name.

### 7c. Memory Consolidation (Episodic → Procedural)

Consolidate feedback memories accumulated during the sprint. This prevents unbounded growth.

```
Step 1 — Inventory:
  List all feedback_*.md files.
  For each: topic, date created.

Step 2 — Pattern detection:
  Group feedback pointing to same root cause (same module, same error type).
  IF 2+ feedback on same pattern → candidate for promotion.

Step 3 — Promotion:
  IF pattern is general (applies beyond this sprint):
    → Write as GUARDRAILS rule (what + why + how)
    → Delete promoted feedback files
    → Remove from MEMORY.md index
  ELSE (one-off, context-specific):
    → Keep, proceed to Step 4

Step 4 — Retention check:
  Use git log to find which feedback files were read in last 3 sprints.
  IF not read in 3 sprints → DELETE (stale)
  IF read recently → KEEP
  Clean up MEMORY.md index for deleted files.

Step 5 — Index hygiene:
  Verify MEMORY.md has no orphan links (index entry but file missing).
  Verify MEMORY.md is under 200 lines.
```

### 7d. Guardrail Hygiene

IF `Docs/CODING_GUARDRAILS.md` > 800 lines:
  Flag to user: "Guardrails file is [N] lines — consider pruning."
  Pruning options (user decides):
  - Root cause descriptions → one sentence max
  - Code examples → one WRONG + one CORRECT pair per rule
  - Over-engineering notes → move to DESIGN.md or remove
  - Deduplicate between Anti-Pattern Quick Reference and domain sections
  Do NOT prune automatically.

IF file <= 800 lines OR no guardrails file: skip.

## 8. Archival Maintenance

Archive TRACKING.md sections exceeding 50 lines or data older than 5 sprints to `Docs/Archive/tracking-S<N>-<section>.md`.

Covers: Failure Mode History, Sprint Board, Performance Baseline Log, Retroactive Audits (CLOSED only), Dismissed Signals (non-suppressed never archived). OPEN/IN_PROGRESS retroactive audits are NEVER archived.

## 9. Entry Gate Report Cleanup

Delete `Docs/Planning/S<N>_ENTRY_GATE.md`. Gate execution log in TRACKING.md persists as permanent record.

## 10. User Handoff Summary

For each completed item present to user:
- **Before/after:** behavior change (1-2 sentences, non-technical)
- **How:** implementation approach (one sentence, user-level)
- **Where:** file name / Inspector path
- **Verify:** specific runtime action + expected result
- **Should NOT change:** what to check for regressions

IF invisible sprint (no visual change):
  State: "No visible change — verify via [specific diagnostic/counter/log]"

Present BEFORE marking sprint done. Do NOT skip — serves as session handoff record.

## 11. Sprint "Done"

Log to TRACKING.md: `"Sprint Close: [date], steps 1-11 ✓"`

---

# CRITICAL — Reminders (End-of-doc Reinforcement)

- Every `[ ]` item requires action — NEVER silently skip.
- Empty evidence = CANNOT mark `verified`.
- Do NOT invent fake baselines. Do NOT prune guardrails automatically.
- Present user handoff BEFORE marking done. NEVER skip it.

</instructions>
