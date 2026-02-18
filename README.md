# AI Sprint Workflow

A sprint workflow template designed for human + AI coding agent collaboration.

Drop `TEMPLATE.md` into any project and the AI agent bootstraps the full structure:
tracking, guardrails, audit scripts, and sprint gates — all adapted to your stack.

Works with existing projects and greenfield (empty) projects alike.

### Compatibility

| Agent | Status |
|-------|--------|
| **Claude Code** | Tested |
| Cursor | Should work (untested) |
| GitHub Copilot | Should work (untested) |
| Windsurf | Should work (untested) |
| Any agent that reads markdown | Should work (untested) |

> The workflow uses plain markdown files and bash scripts — no agent-specific APIs.
> Any AI coding agent that can read files and follow instructions should work.
> PRs with confirmed test results for other agents are welcome.

## Is This For You?

**Good fit:**
- You're building something that will run for multiple sprints (not a one-off script)
- You work with an AI coding agent across multiple sessions and lose context between them
- Mistakes compound — a wrong decision in Sprint 1 causes pain in Sprint 4
- You want the AI to plan and verify, not just generate code

**Not a good fit:**
- Quick prototype or throwaway experiment (overhead exceeds value)
- Single session, clear scope, no follow-up sprints
- You just want code generated fast without process

When in doubt: try it on one sprint. If the Entry Gate feels like bureaucracy for your project size, you're probably in the "not a good fit" category.

## Why This Exists

AI coding agents (Claude Code, Cursor, Copilot, etc.) are powerful but stateless.
Every session starts from zero. This workflow solves three problems:

1. **Context loss** — Structured files (`CLAUDE.md`, `TRACKING.md`, `GUARDRAILS.md`) give the agent instant context on every session start.
2. **Quality drift** — Three gates (Entry, Self-Verification, Close) catch mistakes before they compound.
3. **Scope creep** — Must/Should/Could prioritization and strategic alignment checks keep sprints focused.

## How It Works

```
                  ┌──────────────┐
                  │  ENTRY GATE  │  "Are we building the right thing?"
                  │(ph0-3,12 st)│  Sprint detail + alignment + dependency check
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ IMPLEMENTATION│  "Are we building it correctly?"
                  │    LOOP      │  Pre-code guardrails → code → self-verify → test → run all tests
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │  CLOSE GATE  │  "Did we build it correctly?"
                  │  (6 phases)  │  Automated scan + spec-driven audit + item-level tests
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ SPRINT CLOSE │  Checkmarks, archive, baseline, retrospective, user handoff
                  └──────────────┘
```

## Quick Start

1. Download `TEMPLATE.md` into your project root:
   ```bash
   curl -O https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/TEMPLATE.md
   ```
2. Start an AI coding session
3. Tell the agent: "Read TEMPLATE.md and bootstrap this project"
4. The agent will:
   - Scan your project (language, framework, build system, test framework — large projects capped at 50 files)
   - Ask 14 discovery questions (skipping ones it can infer from project files)
   - Create `CLAUDE.md`, `TRACKING.md`, `Docs/CODING_GUARDRAILS.md`, `Docs/Planning/Roadmap.md`, `Tools/sprint-audit.sh`
   - If no sprint plan exists: run Initial Planning (decompose goal into phases, detail Sprint 1 only)
   - Adapt audit script patterns to your detected language (multi-language projects supported)
   - Create `Docs/SPRINT_WORKFLOW.md` from `TEMPLATE.md` (strips bootstrap-only sections for a lean ~550-line workflow reference)
   - Confirm the setup with you before writing any feature code
5. Start your first sprint — the agent will ask before running Entry Gate
6. For subsequent sessions: tell the agent **"Continue sprint N"** or **"Resume"**

### Bootstrap Steps (9 total)

```
1. Scan project     → detect language, framework, build system, test framework
2. Discovery Q's    → 14 questions (batch, skip inferrable ones)
3. Create structure → CLAUDE.md, TRACKING.md, GUARDRAILS.md, Roadmap.md, Tools/
4. Initial Planning → if no sprint plan exists: goal → phases → detail S1 → contracts
5. Populate CLAUDE.md with project context
6. Populate GUARDRAILS.md with framework-specific rules
7. Adapt audit script to detected language
8. TEMPLATE.md → Docs/SPRINT_WORKFLOW.md (strip bootstrap sections)
9. Confirm with user
```

Empty project? Step 1 is skipped — Discovery Questions cover language/framework.

### Discovery Questions (14)

Questions are asked in a single batch. Answers inferrable from project files
(e.g., `package.json` → TypeScript + Jest) are stated as inferred and confirmed.

| Category | Questions |
|----------|-----------|
| **Project Shape** | Q0: Language/framework, Q1: Solo or team, Q2: Sprint scope size, Q3: Existing roadmap, Q4: Performance-sensitive, Q5: Target platforms |
| **Infrastructure** | Q6: CI/CD pipeline, Q7: Test framework, Q8: Existing linter/standards, Q9: Known tech debt |
| **Workflow Preferences** | Q10: Docs language, Q11: Commit style (skipped if VCS=none), Q12: Immutable contracts, Q13: Anything else the AI should know |

Q0 auto-detects from project files; asks explicitly if the project is empty. If user is undecided, AI proposes options with trade-offs.
VCS is auto-detected (`.git`, `.svn`, `.hg`). Result recorded in `CLAUDE.md`. If VCS=none: Q11 skipped, Close Gate Phase 1b uses Entry Gate implementation notes instead of `git diff`, TRACKING.md recovery falls back to user verification.
Q13 is an open-ended catch-all for context that doesn't fit the predefined categories.

## What Gets Created

```
your-project/
├── CLAUDE.md                     # AI session context (auto-loaded every session)
├── TRACKING.md                   # Single source of truth for item status
├── Docs/
│   ├── CODING_GUARDRAILS.md      # Engineering rules from real bugs
│   ├── LESSONS_INDEX.md          # Bug → rule traceability (starts empty)
│   ├── SPRINT_WORKFLOW.md        # Workflow reference (moved from TEMPLATE.md)
│   └── Planning/
│       ├── Roadmap.md            # Sprint plan (Must/Should/Could)
│       └── S<N>_ENTRY_GATE.md    # Entry Gate report (lives during sprint, deleted at close)
└── Tools/
    └── sprint-audit.sh           # Automated close gate checks
```

### Why Separate Files?

```
Single mega-file  = AI reads everything every session  (~2000+ lines)
Separated files   = AI reads only what's needed        (~200-300 lines)
```

Context window is finite. Separation lets the agent load CLAUDE.md (always),
TRACKING.md (session start), guardrails sections (per-task), and
SPRINT_WORKFLOW.md (sprint boundaries only) — not the entire project history.

## Key Design Decisions

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
- **Workflow evolution guard.** AI Agent Operational Rules: before adding any new step or check to the workflow, three questions must pass — does it catch a real observed failure no existing mechanism catches? Is that failure worth the per-sprint overhead? Does it verify a new class of failure rather than just confirming a previous check ran? The last question is the "who watches the watchers" test. Complexity is a cost paid on every sprint.
- **Guardrail traceability.** `Docs/LESSONS_INDEX.md` maps every guardrail rule to its root cause, source item, and sprint. The Update Rule checks it before creating new rules to prevent duplicates. Grows organically alongside `CODING_GUARDRAILS.md`.
- **Single source of truth for gates.** `SPRINT_WORKFLOW.md` is the authoritative source for Entry Gate, Close Gate, and Sprint Close procedures. `CLAUDE.md` references it directly at sprint boundaries. `CODING_GUARDRAILS.md` keeps a brief pointer, not a duplicate.
- **Orphan detection.** `sprint-audit.sh` Section 11b: detects items that exist in TRACKING.md but not in Roadmap.md (or vice versa), catching cross-file inconsistencies.
- **Sprint abort.** When a sprint is going in the wrong direction, the user can abort. Verified work persists, unfinished items become `deferred`, and an abbreviated Sprint Close archives the sprint without running full gates.
- **Abbreviated Entry Gate.** Small sprints (≤3 Must items, no cross-sprint dependencies) run a lighter gate: Phase 0 → state review → strategic alignment → test plan (9b-lite) → scope check → approval. Skips failure mode analysis, metric sufficiency deep check, dependency verification, and implementation ordering. Close Gate Phase 1b adapts automatically — failure mode check is skipped when 9a data is absent. Logged as "Entry Gate (abbreviated)" so the audit trail is clear.
- **Interruption handling.** Three cases defined: (1) user asks a question mid-task — AI answers, then states where it left off and waits for confirmation before resuming; (2) AI stopped and restarted in the same session — AI reads TRACKING.md, states the in_progress item and best sub-step estimate, verifies code matches status; (3) session fully closed — Session Start Protocol reconstructs from CLAUDE.md Last Checkpoint + TRACKING.md statuses; if sub-step is ambiguous, item restarts from step A rather than guessing mid-item state.

## Self-Validation

The workflow validates itself at three levels:

| Level | Script | What it catches | When to run |
|-------|--------|----------------|-------------|
| **Structural** | `bash validate-workflow.sh` | Cross-file references, numeric claims, status values, content parity (19 checks) | After any edit to TEMPLATE.md, README.md, or sprint-audit-template.sh |
| **Path simulation** | `bash validate-paths.sh` | Decision paths exist, gap fixes intact, state transitions complete (40 checks) | Same as above |
| **Negative tests** | `bash validate-paths.sh --self-test` | Gap detection still works — intentionally breaks each fix, verifies script catches it (7 tests) | After changing validate-paths.sh or gap-related TEMPLATE.md text |
| **Semantic** | Copy `verify-workflow-semantic.md` into an AI session | Logic gaps, dead ends, missing user approvals, information flow, state machine coverage (31 questions) | After major workflow changes or periodically |

CI runs structural + path checks on every push/PR to `master`. Exit code 2 (FAIL) blocks merge; exit code 1 (WARN) is non-blocking.

```bash
# Quick local check (< 5 seconds)
bash validate-workflow.sh && bash validate-paths.sh

# Full local check including negative tests
bash validate-workflow.sh && bash validate-paths.sh && bash validate-paths.sh --self-test
```

## Supported Languages

The template includes audit patterns for 7 languages.
Scaffolding detection (TODO, HACK, FIXME, TEMP tags) is language-agnostic — no comment prefix required.

| Language | Hot Path Alloc | Cached Ref | Anti-Pattern |
|----------|---------------|-----------|-------------|
| **C#/Unity** | `new List<`, `new Dictionary<` | `Camera.main`, `GetComponent` | `AppendStructuredBuffer` |
| **TypeScript/React** | `new Array(`, spread in render | `querySelector` in loop | `dangerouslySetInnerHTML`, `any` |
| **Python** | list comprehension in hot loop | repeated `os.path.exists` | `eval()`, bare `except:` |
| **Java** | `new ArrayList<>` in loop | repeated `getBean()` | `e.printStackTrace()` |
| **Go** | `append` in tight loop | repeated `os.Getenv` | `panic()` in library code |
| **Rust** | `.clone()` in hot path | repeated `.unwrap()` | `unsafe` without comment |
| **C++** | `new`/`malloc` in loop | repeated `dynamic_cast` | raw `new` without smart ptr |

## Adaptation

| Project Size | Recommendation |
|---|---|
| **Small** (1-5 files) | Abbreviated Entry Gate (≤3 Must items, no cross-sprint deps): Phase 0 → steps 1-2 → 8 → 9b-lite → 10 → 12. Skips failure mode analysis (9a), metric sufficiency (9c), Phase 2. sprint-audit.sh optional. |
| **Medium** (5-50 files) | Full workflow. Audit script valuable at ~10+ files |
| **Large** (50+ files) | Add CI integration, per-subsystem guardrails |

| Aspect | Solo | Team |
|---|---|---|
| Commits | Monolithic OK (with TRACKING traceability) | Atomic required |
| Review | Self-verify + AI agent | Peer review + AI agent |
| Entry Gate | Abbreviated if ≤3 Must + no deps; full otherwise | Full (phases 0-3) |
| Close Gate | Full | Full + peer sign-off |

| Starting Point | What Happens |
|---|---|
| **Existing project** (has code) | Agent scans files, infers answers, creates structure around existing code. Sprint 1 typically focuses on stabilization: tests for critical existing paths, guardrails from known bugs (Q9), then new features from Sprint 2 onward. |
| **Empty project** (no code) | Agent asks Q0 explicitly, runs Initial Planning to create first sprint |
| **Greenfield** ("make me X") | Agent decomposes goal into phases, details Sprint 1, discovers contracts |

## Examples

See [`examples/`](examples/) for real-world adaptations:

- [`unity-csharp/`](examples/unity-csharp/) — Unity 6 + URP game project (anonymized)

## Origin

This workflow was developed during a 24-sprint procedural planet generation project
(Unity 6 + URP, SDF + Marching Cubes). It evolved over 50+ guardrail rules,
3 automated audit scripts, and several hundred AI agent sessions.

## License

MIT — see [LICENSE](LICENSE).
