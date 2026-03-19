# [Project Name] — Tracking

## Working Context

Task: —
Doing: —
Decisions: —
Blockers: —

## Current Focus
<!-- FILL: Sprint [N]: [one-line description] -->

## Sprint Board

| ID | Summary | Status | Sprint | Evidence |
|----|---------|--------|--------|----------|
<!-- FILL: Add items during Entry Gate -->

Status values: `open` → `in_progress` → `fixed` → `verified`
Special statuses:
- `deferred`: item intentionally skipped (maps to roadmap `[~]`). Requires reason + target sprint.
- `blocked`: item cannot proceed due to external dependency. Requires linked blocker in §Open Risks.
  Format: `blocked by [CORE-### | external description]`. Log block reason in Change Log:
  `[date] CORE-###: blocked — depends on [CORE-### / description]. Expected resolution: [date/sprint].`
  When unblocked: `[date] CORE-###: unblocked — [dependency resolved / reason].` Transition to `open`.
Reverse transition: `verified` → `open` is allowed ONLY when a regression is discovered.
  Log reason in Change Log: "[date] CORE-###: reopened — regression found in [context]"

## Open Risks / Blockers

| ID | Risk | Mitigation | Sprint |
|----|------|------------|--------|

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
Category naming: use `type:subsystem` format (e.g. `null-ref:Renderer`, `mem-leak:AudioPool`).
Generic categories (`null-ref`, `crash`) cause CP2 false positives across unrelated subsystems.

| Sprint | Category | Predicted? | Detection | Mode | Impact | Root Cause | Guardrail | Escalate? |
|--------|----------|------------|-----------|------|--------|------------|-----------|-----------|

## Failure Encounters — Current Sprint

Log failures as they are discovered during implementation (bugs, test failures, unexpected behavior).
Sprint Close step 7a reads this for retrospective comparison. Replace at each new sprint.

| Item | Category | Failure Description | Detection | Date |
|------|----------|-------------------|-----------|------|

Category: direct / interaction / stress-edge.
Detection: test / user-visual / profiler / code-review.

## Performance Baseline Log

Recorded at Sprint Close step 5. Read at Entry Gate Phase 1 step 3 (CP1).
New row per sprint per tracked metric. Deltas are derived on demand from adjacent rows.
`Value` must be a plain number (no unit suffix) — unit goes in the `Unit` column.
This format is required for automated CP1 regression detection.

| Sprint | Metric          | Value | Unit | Method         |
|--------|-----------------|-------|------|----------------|

## Retroactive Audits

Written at Retroactive Sprint Audit Phase 7. Read at Entry Gate step 3 (deferred items)
and Entry Gate step 9a (pattern analysis). Audits without `status: CLOSED` block Sprint Close step 6.

| Audit # | Target Sprint | Status | Trigger | Classification | Resolution | Closed |
|---------|--------------|--------|---------|----------------|------------|--------|

Category values: REGRESSION / INTEGRATION_GAP / FALSE_VERIFICATION / COLD_STATE / SCOPE_DRIFT / ENVIRONMENT_DELTA

## Dismissed Signals

Written when user says NO to an audit proposal. Re-surfaced at next Entry Gate if condition
persists (same system, same checkpoint). Suppressed after 2 dismissals — but CP3 and CP4
signals are never suppressed by prior dismissals.
Suppressed signal reactivates if the underlying condition worsens: metric delta increases,
or a new failure is logged in the same system. Dismissal counter resets to 0.

| Date | Checkpoint | System / Metric | Signal Summary | User Decision | Dismissal # | Suppressed? | Revisit Sprint |
|------|-----------|----------------|---------------|---------------|-------------|-------------|----------------|

Checkpoint: CP1=Entry Gate metric; CP2=Entry Gate failure pattern; CP3=Implementation; CP4=Close Gate.

## Session Notes

Append-only journal for session-internal context. Written via `sprint-tools note`.
Cleared at sprint close (archived to `Docs/Archive/session-notes-S<N>.md`).
PreCompact hook injects last 5 notes into context after compaction.

| # | Type | Item | Note | Time |
|---|------|------|------|------|

Types: `decision` | `attempt` | `side-effect` | `observation` | `artifact`
- **decision**: Approach chosen + why (e.g., "keyword matching over LLM — deterministic, zero cost")
- **attempt**: What was tried + outcome (e.g., "regex parser — too brittle for nested tables")
- **side-effect**: Unintended change noticed (e.g., "fixing parser also broke CSV export")
- **observation**: Context worth preserving (e.g., "PreCompact destroys ~60% of context")
- **artifact**: Pointer to long-form content in `Docs/Artifacts/` (auto-created by `sprint-tools note --artifact`)

## Change Log

[Sprint-scoped entries. Archived to Docs/Archive/ at sprint close.]

Tag significant entries for sprint index retrieval (see TEMPLATES.md §Sprint Index Tagging).

### Sprint 1
<!-- FILL: Add entries as work progresses -->
