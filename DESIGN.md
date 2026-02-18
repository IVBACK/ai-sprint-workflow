# AI Sprint Workflow — Design Decisions

Rationale behind key design choices. For the workflow itself, see [TEMPLATE.md](TEMPLATE.md).

## Key Design Decisions

- **User-activated, not automatic.** The agent knows the workflow via `CLAUDE.md` but will not self-invoke Entry Gate on a plain feature request. Explicit trigger phrases are required (see [Effective Prompts](README.md#effective-prompts)).
- **AI flags, user decides.** When a gate check fails, the AI presents evidence and options. It never unilaterally changes sprint scope.
- **Sprint scope, not duration.** A sprint is 1-8 Must items (+ optional Should/Could), not a calendar week. AI can finish a "sprint" in hours.
- **Guardrails grow from bugs.** No hypothetical rules. Every guardrail traces to a real production issue.
- **Automated + spec-driven audit.** `sprint-audit.sh` catches grep-detectable patterns (~30 lines of output) including metric-vs-test coverage (Section 12). Close Gate Phase 1b is spec-driven: it loads Entry Gate failure mode predictions (9a) and verification plan invariants (9b), then checks per item whether predicted failure modes are handled in code. Generic checks (resource leaks, dead code, observability) run as supplemental. Output is per-item (HANDLED/MISSED/N/A), not per-file. Significant findings pause the gate; clean phases are batched into one report — no approval fatigue on clean sprints.
- **Any starting point.** Works with existing codebases (scans and wraps structure around existing code) and empty projects alike. If no sprint plan exists, an Initial Planning step decomposes the goal into phases, details Sprint 1, and discovers immutable contracts.
- **Rich item status model.** Items track `open → in_progress → fixed → verified`, plus `blocked` and `deferred` statuses. `in_progress` prevents wasted rework after session interruptions. Reverse transition `verified → open` is allowed for regressions.
- **Sprint detail on demand.** Entry Gate Phase 0: if a sprint is still a one-line sketch from Initial Planning, decompose it into Must/Should/Could before proceeding. Later sprints are detailed only when reached — not up front.
- **Mid-sprint scope changes.** Urgent items (critical bugs, security fixes) can be added mid-sprint with a documented procedure. AI never initiates scope changes — user decides. Hotfixes skip formal gates but still require Change Log entry, test, and retrospective inclusion.
- **Immutable contract revision.** Contracts are not truly permanent — they have an explicit revision procedure when project direction changes, including blast radius assessment and regression tracking.
- **Metric sufficiency check.** Entry Gate step 9c: if a roadmap item has no metric gate, the AI proposes one before the sprint starts. For each metric, four checks: measurable by sprint end? Test scenario defined? Threshold non-trivial (can it pass while the system is broken)? Every failure mode from 9a covered? No item ships without sufficient success criteria.
- **Structured metric verification.** Close Gate Phase 0 requires a filled Metric Verification table — every sprint metric must be explicitly marked PASS, DEFERRED, FAIL, or MISSING with evidence or escalation reason. Each metric also records the action taken (existing, written, fixed, revised, added, escalated) so the user sees the journey, not just the final state. Empty cells block the gate. All-DEFERRED also blocks the gate — at least one metric must PASS for the sprint to close. A compact summary line is logged to TRACKING.md (not the full table — tests in the codebase are the persistent evidence). `sprint-audit.sh` Section 12 cross-checks roadmap metrics against test files — unmatched metrics cannot be marked as false positives.
- **Unmet-metric escalation.** Close Gate Phase 0 + Sprint Close step 1: when a metric is partially met or blocked by an unfinished prerequisite, the AI must not silently mark `[ ]` and move on. Required: explain the gap, check if the blocker is tracked in the roadmap, propose a target sprint with reasoning, and get user approval before deferring.
- **Item-level test coverage.** Close Gate Phase 4b: every completed item (Must + Should + Could) must have a behavioral test — not just file-level test existence. Missing test → write one or document why untestable.
- **Performance baseline tracking.** Sprint Close step 5: key metrics are recorded to `TRACKING.md` each sprint. Regressions vs. the previous sprint are flagged automatically. Early sprints with no measurable metrics log a target sprint for establishing baselines.
- **Algorithmic invariant checks.** Entry Gate step 9b: for items involving algorithms or mathematical systems, the verification plan must include invariant tests (properties that must always hold), not just "does it run?" checks.
- **Priority & rigor review.** Entry Gate Phase 0 challenges the Must/Should/Could breakdown: all items receive metric gates and full planning rigor regardless of priority. Should/Could items that would cause a Must metric to fail are promoted to Must. Misplacements in either direction are flagged to the user. Priority determines sprint-blocking status, not rigor level.
- **Step 8 outcome mechanics.** Entry Gate step 8: user reviews each item with four explicit responses — keep (unchanged), modify (re-run 9a-9c), defer (with reason + target sprint), or remove (delete from Roadmap + TRACKING.md). No implicit pass-through.
- **Failure mode analysis.** Entry Gate step 9a + Close Gate Phase 0: every item's failure modes are categorized as direct (item-internal), interaction (cross-system), or stress/edge-case (extreme-condition). Each category requires at least one identified mode with a corresponding metric or test. Failure modes are analyzed first (9a) so they drive metric requirements (9c). "Has a metric" ≠ "has the right metrics."
- **Gate execution evidence.** Entry Gate step 12 logs which steps were executed and what was decided. The log goes to `TRACKING.md` so future sessions can verify the gate actually ran — not just that the sprint started.
- **AI gate assessment.** Both gates end with an AI assessment before user approval. Entry Gate step 12b: blocker/risk/scope assessment + recommendation. Close Gate verdict: metric summary with action breakdown (how many existing, written, fixed, revised, added, escalated), findings summary, risk assessment, and recommendation. The user gets a reasoned opinion at both boundaries, not just a "ready?" prompt. If the user does not approve, the AI returns to the relevant phase for rework; if the direction is fundamentally wrong, the Sprint Abort procedure applies.
- **Sprint-scoped Entry Gate report.** The full Entry Gate analysis is written to `Docs/Planning/S<N>_ENTRY_GATE.md` as a living reference during the sprint. Implementation sessions can check API readiness, failure modes, or architecture decisions without re-reading source files. Deleted at Sprint Close — `TRACKING.md` gate log persists as the permanent record.
- **Workflow self-audit.** Sprint Close step 6: cross-reference integrity check. Do `CLAUDE.md` references match their target files? Catches the workflow's own drift before it causes skipped checks.
- **Failure mode retrospective.** Sprint Close step 7: structured retrospective table (every predicted mode answered, every actual failure listed) is filled and presented to the user. Unpredicted failures trigger the Update Rule (7 steps including LESSONS_INDEX.md entry). Same category 2+ sprints triggers Architecture Review with root cause tracing across sprints.
- **Failure encounter logging.** Implementation loop step E: failures encountered during coding are logged to `TRACKING.md §Failure Encounters` with category and detection metadata. Sprint Close step 7a reads this structured data instead of reconstructing from memory.
- **Cross-sprint learning loop.** `TRACKING.md §Failure Mode History` accumulates failure mode data across sprints. Entry Gate step 9a reads this history before predicting new modes and checks for escalation triggers (Architecture Review, proxy test questions). Sprint Close step 7 writes to it after comparing predictions vs reality. History is archived after 5 sprints to prevent TRACKING.md bloat.
- **Incremental testing.** Implementation loop step D.6: after each item, all tests written so far (current + previous items) are run before moving to the next item. Regressions are caught immediately — not accumulated until Close Gate. Tests that need unavailable infrastructure are marked "pending" and run at Close Gate Phase 3.
- **Verification plan quality gate.** Entry Gate step 12c: user reviews each item's test scenario before coding begins. Trivial scenarios ("it runs", "no crash") are sent back for revision. Acceptable scenario must specify inputs, expected outputs or invariants, and at least one failure-inducing case. Prevents the chain from starting with weak verification.
- **User handoff summary.** Sprint Close step 10: before marking the sprint done, the AI presents each completed item with before/after behavior, one-sentence implementation summary, where to find it, what to verify in the running application, and what should not have changed. Invisible sprints (no visual change) include explicit diagnostic instructions. Never skipped — serves as both explanation and session handoff record.
- **Critical Axis enforcement.** Every project declares a #1 non-negotiable quality axis (security, performance, reliability, correctness) at Bootstrap. Recorded in `CLAUDE.md`. Entry Gate 9a requires deeper failure mode coverage for items touching this axis. Close Gate Phase 2 cannot silently defer findings in this domain — the AI stops, presents options (fix now / defer with explicit rationale / Sprint Abort), and waits for user decision. Prevents an AI agent from treating a payment security gap the same as a missing log line.
- **Retroactive Sprint Audit.** When a completed sprint's output is found broken or inconsistent with its Close Gate claims, a 7-phase audit procedure opens: evidence collection from the original Close Gate record, current state measurement, gap analysis (5% tolerance on continuous metrics; 0 vs non-zero is always a gap), root cause classification (REGRESSION / INTEGRATION_GAP / FALSE_VERIFICATION / COLD_STATE / SCOPE_DRIFT / ENVIRONMENT_DELTA), dependency impact assessment, resolution plan, and audit close written to `TRACKING.md §Retroactive Audits`. The AI actively watches for suspicious signals at 4 checkpoints — Entry Gate (metric regression, failure pattern), Implementation session (broken past-sprint API or failing test), and Close Gate (Must item unverifiable due to past-sprint dependency). When a signal fires, the AI must surface it to the user — it cannot silently continue. Dismissed signals are logged and re-surfaced next sprint; dismissed twice for the same system, they are suppressed (but Checkpoint 3 and 4 are never suppressed by prior dismissals). COLD_STATE classification is valid for a maximum of 2 consecutive sprints — after that, a warm-start measurement is mandatory.
- **Workflow evolution guard.** AI Agent Operational Rules: before adding any new step or check to the workflow, three questions must pass — does it catch a real observed failure no existing mechanism catches? Is that failure worth the per-sprint overhead? Does it verify a new class of failure rather than just confirming a previous check ran? The last question is the "who watches the watchers" test. Complexity is a cost paid on every sprint.
- **Guardrail traceability.** `Docs/LESSONS_INDEX.md` maps every guardrail rule to its root cause, source item, and sprint. The Update Rule checks it before creating new rules to prevent duplicates. Grows organically alongside `CODING_GUARDRAILS.md`.
- **Single source of truth for gates.** `SPRINT_WORKFLOW.md` is the authoritative source for Entry Gate, Close Gate, and Sprint Close procedures. `CLAUDE.md` references it directly at sprint boundaries. `CODING_GUARDRAILS.md` keeps a brief pointer, not a duplicate.
- **Orphan detection.** `sprint-audit.sh` Section 11b: detects items that exist in TRACKING.md but not in Roadmap.md (or vice versa), catching cross-file inconsistencies.
- **Sprint abort.** When a sprint is going in the wrong direction, the user can abort. Verified work persists, unfinished items become `deferred`, and an abbreviated Sprint Close archives the sprint without running full gates.
- **Abbreviated Entry Gate.** Small sprints (≤3 Must items, no cross-sprint dependencies) run a lighter gate: Phase 0 → state review → strategic alignment → test plan (9b-lite) → scope check → approval. Skips failure mode analysis, metric sufficiency deep check, dependency verification, and implementation ordering. Close Gate Phase 1b adapts automatically — failure mode check is skipped when 9a data is absent. Logged as "Entry Gate (abbreviated)" so the audit trail is clear.
- **Interruption handling.** Three cases defined: (1) user asks a question mid-task — AI answers, then states where it left off and waits for confirmation before resuming; (2) AI stopped and restarted in the same session — AI reads TRACKING.md, states the in_progress item and best sub-step estimate, verifies code matches status; (3) session fully closed — Session Start Protocol reconstructs from CLAUDE.md Last Checkpoint + TRACKING.md statuses; if sub-step is ambiguous, item restarts from step A rather than guessing mid-item state.

---

## Bootstrap Flow — Visual Reference

Visual overview of the bootstrap procedure. Authoritative text: `## Quick Start — AI Agent Bootstrap` in TEMPLATE.md.

```
AI reads this file
       │
       ▼
┌──────────────────────────────────┐
│ Step 0: Detect project state     │
│  Source code or workflow files?  │
│  NO  → Greenfield: go to step 1  │
│  YES → Migration: read rules     │
│         above, then go to step 1 │
└────────────────┬─────────────────┘
                 │
                 ▼
┌──────────────────┐     ┌──────────────────┐
│ 1. Scan project  │────►│ Detect:          │
│ (files, configs, │     │  - Language       │
│  build system)   │     │  - Framework      │
└──────────────────┘     │  - Test framework │
                         │  - Build tool     │
                         │  - VCS (git?)     │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ 2. Discovery Q's  │
                         │ (ask user)        │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ 3. Create files:  │
                         │  CLAUDE.md        │
                         │  TRACKING.md      │
                         │  GUARDRAILS.md    │
                         │  Roadmap.md       │
                         │  Tools/           │
                         │ (skip if exists)  │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ 4. Initial Plan   │
                         │ if no sprint plan │
                         │ Migration:        │
                         │  now = Sprint 1   │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ 7. Adapt audit   │
                         │ to detected lang  │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ 8. TEMPLATE.md → │
                         │ SPRINT_WORKFLOW  │
                         │ (strip bootstrap)│
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ 9. Confirm        │
                         └──────────────────┘
```

---

## Retroactive Audit Flow — Visual Reference

Visual overview of the 7-phase audit. Authoritative text: `#### Phase 0 — Audit Setup` through `#### Phase 7 — Audit Close` in TEMPLATE.md.

```
Trigger observed
      │
      ▼
Phase 0: Setup
  ├── identify target sprint + symptom + Close Gate claim
  └── estimate blast radius → user confirms → audit opens
      │
      ▼
Phase 1: Evidence Collection
  └── read all Close Gate artifacts for target sprint
      │
      ▼
Phase 2: Current State Assessment
  └── run same measurements as Close Gate today
      │
      ▼
Phase 3: Gap Analysis
  └── compare claim vs current → produce gap table
      │
      ▼
Phase 4: Root Cause Classification
  └── classify each gap: REGRESSION / INTEGRATION_GAP / FALSE_VERIFICATION /
                         COLD_STATE / SCOPE_DRIFT / ENVIRONMENT_DELTA
      │
      ▼
Phase 5: Dependency Impact Assessment
  └── which subsequent sprints are affected? → mark re-verification required
      │
      ▼
Phase 6: Resolution Plan
  └── for each gap: fix now / fix next sprint / accept+document / rollback
      │
      ▼
Phase 7: Audit Close
  └── write to TRACKING.md §Retroactive Audits → present to user → resume current work
```

---

## Sprint Workflow — Complete Flow

Visual overview of the full sprint lifecycle. Authoritative text: `## Entry Gate`, `## Implementation Loop`, `## Close Gate`, `## Sprint Close` in TEMPLATE.md.

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
              ┌────────────────────────┐
              │ ≤3 Must + no cross-    │──YES──► Abbreviated mode:
              │ sprint dependencies?   │         Ph0 → 1-2 → 8 → 9b-lite
              └────────────┬───────────┘         → 10 → 12
                           │ NO
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 0 — Sprint Detail (conditional)                          │
│  Skip if sprint already has Must/Should/Could items.            │
│  If sprint is a one-line sketch:                                │
│    0a. Read sketch + previous sprint outcomes                   │
│    0b. Decompose into Must/Should/Could with IDs                │
│    0c. Add metric gates (all items)                             │
│    0d. Priority & rigor review (2 passes):                      │
│        Pass 1: distribution check (all Must? re-sort)           │
│        Pass 2: dependency promotion (Should/Could → Must?)       │
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
│                                                                 │
│  ⚠ AUTO-DETECTION CP1: while reading §Performance Baseline Log  │
│    Past sprint claimed metric X → baseline now shows gap ≥20%   │
│    AND current sprint did not modify the responsible system?     │
│    → surface ⚠ AUDIT SIGNAL to user; user decides YES/NO        │
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
│  For each item (Must, Should, Could), 4-question check:         │
│  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌─────────────────┐    │
│  │ Still    │ │ Goal      │ │ Approach │ │ Metrics still   │    │
│  │ relevant?│ │ aligned?  │ │ valid?   │ │ appropriate?    │    │
│  └──────────┘ └───────────┘ └──────────┘ └─────────────────┘    │
│                                                                 │
│  Then:                                                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 9. Verification plan:                                     │  │
│  │    a. Failure modes (3 types per item):                   │  │
│  │       Read TRACKING §Failure Mode History first           │  │
│  │       Check escalation triggers (category 2+/3 sprints    │  │
│  │       → Architecture Review; visual 2+ → proxy test)      │  │
│  │       • Direct  • Interaction  • Stress/edge              │  │
│  │       >=1 per category, each with metric or test          │  │
│  │       Write to TRACKING §Predicted Failure Modes          │  │
│  │                                                           │  │
│  │       ⚠ AUTO-DETECTION CP2: same failure category in 2+   │  │
│  │         sprints AND pattern converges on one past sprint?  │  │
│  │         → surface ⚠ AUDIT SIGNAL to user                  │  │
│  │    b. How verified? (unit/integration/manual, invariants) │  │
│  │    c. Metric sufficiency (measurable? non-trivial? 9a     │  │
│  │       coverage? gap → add metric, update roadmap)         │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────────────────────┐ │
│  │ 10.Scope │ │ 11.Impl  │ │ 12. Gate assessment + report:     ││
│  │ check    │ │ order    │ │  a. Write S<N>_ENTRY_GATE.md     │ │
│  └──────────┘ └──────────┘ │  b. AI own assessment + recommend│ │
│                             │  c. User approves — reviews 9b   ││
│                             │     quality ("trivial?" → revise)││
│                             │  d. Log + update (post-approval) ││
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
│  │              │  (max 3 rounds;  │                      │    │
│  │              │   still failing → │                      │    │
│  │              │   escalate to     │                      │    │
│  │              │   user)           │                      │    │
│  │              │  YES ↓            │                      │    │
│  │              └───────────────────┘                      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  D. Write tests                                         │    │
│  │     ┌────────────────────────────────────────────┐      │    │
│  │     │ Unit-testable logic ────► Unit test        │      │    │
│  │     │ Integration/async ──────► Integration test │      │    │
│  │     │ Visual/UI ────────────► Manual + screenshot│      │    │
│  │     │                                            │      │    │
│  │     │ Each test must encode Entry Gate 9b        │      │    │
│  │     │ invariants. Trivial tests ("it runs",      │      │    │
│  │     │ "no exception") are not acceptable —       │      │    │
│  │     │ apply same criteria as Entry Gate 12c.     │      │    │
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
│  │     │    ask user again (resolved = user         │      │    │
│  │     │    confirms "OK"; max 3 attempts, then     │      │    │
│  │     │    log as known gap with target sprint)    │      │    │
│  │     │ 3. Automated proxy test exists?            │      │    │
│  │     │    → still ask user for visual confirm     │      │    │
│  │     └────────────────────────────────────────────┘      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  D.6 Incremental test run                               │    │
│  │     Run ALL tests written so far (this item +           │    │
│  │     all previous items in this sprint).                 │    │
│  │     ┌────────────────────────────────────────────┐      │    │
│  │     │ PASS → proceed to E                    │      │    │
│  │     │ FAIL (new test) → fix impl, rerun     │      │    │
│  │     │ FAIL (prev item test) → regression:   │      │    │
│  │     │   fix before adding more code         │      │    │
│  │     │ max 3 fix attempts → escalate to user │      │    │
│  │     │                                       │      │    │
│  │     │ Test needs unavailable infra?         │      │    │
│  │     │ → mark "pending" in TRACKING.md       │      │    │
│  │     │ → run at Close Gate Phase 3           │      │    │
│  │     └────────────────────────────────────────┘      │    │
│  │                        │                                │    │
│  │                        ▼                                │    │
│  │  E. Update TRACKING.md                                  │    │
│  │     Mark item fixed (in_progress → fixed), log decisions│    │
│  │     If bugs/failures encountered during this item:      │    │
│  │     → log to §Failure Encounters (item, category,       │    │
│  │       description, detection method)                    │    │
│  │                                                         │    │
│  │     ⚠ AUTO-DETECTION CP3: during any implementation     │    │
│  │       step — past sprint API missing/broken, test       │    │
│  │       from past sprint now FAIL, profiler contradicts   │    │
│  │       past metric by >20% (and current sprint did not   │    │
│  │       modify that system)?                              │    │
│  │       → surface ⚠ AUDIT SIGNAL to user                  │    │
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
│  PRESENTATION RULE                                              │
│  Phases 0/1a/1b/2/4 = transparency checkpoints, not approvals  │
│  Clean/minimal → batch into one report, no pause needed         │
│  Blocker/regression/MISSED → stop, present, ask                 │
│  Mandatory approval: verdict only                               │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 0 — Metric Gate Sufficiency                              │
│                                                                 │
│  For each sprint metric (every item has a metric gate):          │
│  □ Measurable with current infrastructure?                      │
│  □ Test evidence sufficient?                                    │
│  □ Threshold reasonable for current scale?                      │
│  □ Failure mode coverage per modified subsystem?                │
│    • Direct (item-internal) — >=1 identified?                   │
│    • Interaction (cross-system) — >=1 identified?               │
│    • Stress/edge (extreme-condition) — >=1 identified?          │
│    Each mode has metric or test? Missing → add or document gap  │
│                                                                 │
│  OUTPUT: Structured Metric Verification table                   │
│  Every metric → PASS / DEFERRED / FAIL / MISSING                │
│  Empty cells or MISSING/FAIL → gate BLOCKED (cannot proceed)    │
│  Present completed table to user before proceeding to Phase 1a  │
│  Log compact summary to TRACKING (not full table):              │
│    "Metric Verification: X/Y PASS, Z DEFERRED (id → S<N>)"     │
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
│  │ 11c.Checkbox format (CORE-### without - [ ] syntax)        │ │
│  │ 12. Metric coverage (roadmap metric ↔ test evidence)      │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Exit codes: 0=clean, 1=findings, 2=setup error (fix script)    │
│  Output: WARN (dismissible) + BLOCKER (non-dismissible)          │
│  BLOCKER = metric without test (Section 12) — cannot mark as FP  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1b — Spec-driven Audit (semantic, script can't catch)    │
│                                                                 │
│  Load Entry Gate data first:                                    │
│  → TRACKING §Predicted Failure Modes (Entry Gate 9a)            │
│  → S<N>_ENTRY_GATE.md verification plan per item (9b)           │
│                                                                 │
│  Per completed item (Must + Should + Could):                    │
│  a. Find implementing files (git diff if VCS=git, else Entry    │
│     Gate notes / user confirmation if VCS=none)                 │
│  b. Predicted failure modes → handled in code?                  │
│     • Direct (item-internal): null ref, off-by-one, wrong calc  │
│     • Interaction (cross-system): timing, shared state, order   │
│     • Stress/edge: exhaustion, cascade, rapid oscillation       │
│  c. Entry Gate 9b invariants → enforced in implementation?      │
│                                                                 │
│  Supplemental per-file (issues outside item scope):             │
│  1. Resource/memory leaks                                       │
│  2. Missing observability (logging, profiling)                  │
│  3. Dead code / orphan scaffolding                              │
│  4. Debug/prod path parity                                      │
│                                                                 │
│  OUTPUT: per-item (CORE-### → modes: HANDLED/MISSED/N/A)        │
│          + supplemental findings per file                       │
│  Present to user before proceeding to Phase 2                   │
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
│  All tests PASS after Phase 2 fixes (no regressions).           │
│  Include any tests marked "pending" during D.6 that can         │
│  now execute (infra available at Close Gate).                   │
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
              │  (max 2 full re-runs; still │
              │   failing → escalate to user│
              │   with remaining findings)  │
              │  YES ↓                      │
              └──────────────┬──────────────┘
                             │
                             ▼
              ┌──────────────────────────────┐
              │ Close Gate verdict:          │
              │  AI assessment (metrics,     │
              │  findings, risk, recommend)  │
              │  User approves → close       │
              │  User rejects → rework phase │
              │                              │
              │  ⚠ AUTO-DETECTION CP4:       │
              │  Any Must item unverifiable  │
              │  because a past sprint's     │
              │  output is not working as    │
              │  claimed?                    │
              │  → surface ⚠ AUDIT SIGNAL    │
              └──────────────┬──────────────┘
                             │
           ══════════════════╪═══════════════
                    SPRINT CLOSE
           ══════════════════╪═══════════════
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. Roadmap checkmarks                                          │
│     → Run sprint-audit.sh (focus on Section 11 sync output)     │
│     → Fix all mismatches before ticking                         │
│     [x] = TRACKING.md verified (gate evidence logged)           │
│     [~] = skipped + reason documented inline                    │
│     [ ] = not verified (open, in_progress, or fixed)            │
│                                                                 │
│  2. TRACKING.md update                                          │
│     All Must verified; completed Should/Could also updated      │
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
│     a. Reconstruct actual failures from Sprint Board +          │
│        Change Log + §Failure Encounters                         │
│     b. Read TRACKING §Predicted Failure Modes (from 9a)         │
│     c. Fill structured retrospective table:                     │
│        predicted mode + actual? + detection + root cause        │
│        Every predicted mode answered. Every failure listed.     │
│     d. Transfer to TRACKING §Failure Mode History               │
│     e. Unpredicted → new guardrail (follow §Update Rule)        │
│     f. Check escalation triggers → flag in §Open Risks:         │
│        same category 2+/3 sprints → Architecture Review         │
│        same visual 2+ → proxy test question                     │
│     g. Present retrospective table to user                      │
│                                                                 │
│  8. Failure Mode History maintenance                            │
│     → >30 rows? Archive older entries to Docs/Archive/          │
│                                                                 │
│  9. Entry Gate report cleanup                                   │
│     → Delete Docs/Planning/S<N>_ENTRY_GATE.md                   │
│     → TRACKING.md gate log persists as permanent record         │
│                                                                 │
│ 10. User handoff summary (per completed item):                  │
│     → Before/after: behavior change (1-2 sentences)            │
│     → How: implementation in one sentence (user-level)          │
│     → Where: file / Inspector path                              │
│     → Verify: runtime action + expected result                  │
│     → Should NOT change: regression check                       │
│     Invisible sprint? → state explicitly + name diagnostic      │
│     Present before marking done. Never skip.                    │
│                                                                 │
│ 11. Sprint "done"                                               │
│     Log: "Sprint Close: [date], steps 1-11 ✓"                   │
│     ──────────► next sprint Entry Gate                          │
└─────────────────────────────────────────────────────────────────┘

           When any ⚠ AUDIT SIGNAL fires (user says YES):
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  RETROACTIVE SPRINT AUDIT  (optional — triggered by signal)     │
│                                                                 │
│  Ph 0: Setup                                                    │
│     → target sprint + symptom + Close Gate claim questioned     │
│     → blast radius estimate (which sprints depend on target?)   │
│     → user confirms → audit opens                               │
│                                                                 │
│  Ph 1: Evidence Collection                                      │
│     → S<N>_CLOSE_GATE.md / TRACKING §Sprint N / git log         │
│     → sprint-audit.sh output at close / failure retrospective   │
│                                                                 │
│  Ph 2: Current State Assessment                                 │
│     → same measurements as Close Gate, taken today             │
│     → kill-switch ON? warm-start vs cold-start distinguished?   │
│                                                                 │
│  Ph 3: Gap Analysis                                             │
│     → per-item: Close Gate claim vs today's measurement         │
│     → per-metric: delta (< 5% = variance; ≥ 5% = gap;          │
│       0 vs non-zero = always a gap)                             │
│                                                                 │
│  Ph 4: Root Cause Classification                                │
│     ┌─────────────────┬──────────────────────────────────────┐  │
│     │ REGRESSION      │ Post-N commit broke verified behavior │  │
│     │ INTEGRATION_GAP │ Never wired into runtime path        │  │
│     │ FALSE_VERIF.    │ Close Gate test missed failure mode   │  │
│     │ COLD_STATE      │ Correct for current conditions       │  │
│     │ SCOPE_DRIFT     │ Later sprint changed the contract    │  │
│     │ ENVIRON_DELTA   │ Engine/platform change since Sprint N │  │
│     └─────────────────┴──────────────────────────────────────┘  │
│     Priority: REGRESSION > INTEGRATION_GAP > FALSE_VERIF. >     │
│               COLD_STATE > SCOPE_DRIFT > ENVIRON_DELTA          │
│     COLD_STATE staleness: valid max 2 sprints; 3rd → warm-start │
│                                                                 │
│  Ph 5: Dependency Impact Assessment                             │
│     → which subsequent sprints are affected? → mark open        │
│     → ≥3 items across sprints → "Re-verification Cluster"       │
│     → guardrails that should have caught this → add if missing  │
│                                                                 │
│  Ph 6: Resolution Plan                                          │
│     Fix now / Fix next sprint / Accept+document / Rollback /    │
│     Quarantine — user decides                                   │
│     Blocker rule: REGRESSION or INTEGRATION_GAP affecting a     │
│     current Must item → automatic blocker                       │
│                                                                 │
│  Ph 7: Audit Close                                              │
│     → write to TRACKING §Retroactive Audits                     │
│     → update Close Gate metric gate if FALSE_VERIF. found       │
│     → run §Update Rule if new guardrail needed                  │
│     → present summary to user → resume current sprint           │
│                                                                 │
│  Dismissed signal rule:                                         │
│     User says NO → log to TRACKING §Dismissed Signals           │
│     Dismissed twice (same checkpoint + same system) → suppress  │
│     Suppression scope: Entry Gate only (CP1/CP2)                │
│     CP3 (Implementation) and CP4 (Close Gate) are NEVER         │
│     suppressed by prior dismissals                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Guardrail Evolution — Visual Reference

Visual overview of the guardrail update process. Authoritative text: `## Update Rule` in TEMPLATE.md.

```
Bug discovered
      │
      ▼
┌──────────────┐     ┌────────────────────┐
│ Fix the bug  │────►│ Check: rule exists │
└──────────────┘     │ in LESSONS_INDEX?  │
                     └────────┬───────────┘
                      no      │      yes
                 ┌────────────┴────────────┐
                 ▼                         ▼
        ┌────────────────────┐   ┌─────────────────┐
        │ Add guardrail rule │   │ Strengthen       │
        │ (never-again)      │   │ existing rule    │
        └────────┬───────────┘   └─────────────────┘
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
        └────────┬───────────┘
                 │
                 ▼
        ┌────────────────────┐
        │ Add entry to       │
        │ LESSONS_INDEX.md   │
        └────────────────────┘

Guardrails grow organically from real bugs.
Never add hypothetical rules — only rules from production experience.
```

