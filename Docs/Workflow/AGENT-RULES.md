<instructions>
# AI Agent Operational Rules

> Read at every session start. Related: [STATE-TRANSITIONS.md](STATE-TRANSITIONS.md)

<critical-rules>
## Critical Rules (always active)

- Read guardrails BEFORE writing code, not after
- Discover → Write → Continue. Never defer writing findings
- Entry Gate and Close Gate are user-initiated only — never start unprompted
- Gate reports MUST be written as files: `Docs/Planning/S<N>_ENTRY_GATE.md` and `S<N>_CLOSE_GATE.md`. Verbal-only is not sufficient — the file is the audit record
- Run ALL tests after each item — never accumulate failures
- Use sprint-tools for TRACKING updates (NOT manual edit) — see §Tool Usage
</critical-rules>

## Session Start

```
LOAD ORDER (sequential):
1. CLAUDE.md           → project context, contracts, last checkpoint
2. TRACKING.md         → current state, items, blockers
   IF malformed (broken table, parse errors):
     → reconstruct from git history (VCS=git) or ask user to verify
3. Roadmap.md          → current sprint scope (Must/Should/Could)

IF sprint-tools available:
  steps 2-3 covered by auto-injected state digest

DECIDE MODE:
IF no in_progress items AND previous sprint done:
  → inform user Entry Gate needed, WAIT
  → trigger: "Open Sprint N for X"
ELIF in_progress or open items exist:
  → resume from TRACKING.md
ELIF in_progress items but no context:
  → verify code matches TRACKING, ask if ambiguous
ELIF all Must verified but no Sprint Close log:
  → report state, WAIT — do NOT suggest Close Gate
```

> **Other agents:** Run `sprint-tools state` manually at session start to get the same digest.

## Context Loading (2-Layer Model)

```
LAYER 1 — Always-on (session start, auto-loaded):
  - CLAUDE.md — project context, contracts, checkpoint
  - TRACKING.md — sprint board, Working Context, risks
  - Guardrails §Index → only relevant sections per task (NOT full file)

LAYER 2 — On-demand (AI pulls when needed):
  - Roadmap.md — sprint plans
  - project_*.md, user_*.md — memory files
  - feedback_*.md — lessons, corrections
  - Docs/Archive/ — past sprint data
  - Docs/Workflow/ files — only the one needed for current task

SESSION BOUNDARIES (mandatory recommendations — user decides):
  After Entry Gate  → new session for implementation
  Before Close Gate → new session for audit
  Close + Sprint Close → same session fine
```

> **Other agents:** `project_*.md`, `feedback_*.md`, `user_*.md` are Claude Code memory file conventions. Use your agent's own memory/context system for equivalent functionality.

## Working Context (TRACKING.md §Working Context)

```
UPDATE WHEN:
  - Starting a new task
  - Making an important decision (framework choice, architecture)
  - Changing direction (plan B)
  - Hitting a blocker

FORMAT (4 lines max):
  Task: [item ID + description]
  Doing: [current file/action]
  Decisions: [key choices made and why]
  Blockers: [current blocks or "—"]

DO NOT WRITE:
  - Tool outputs (re-runnable)
  - Code snippets (in files already)
  - General knowledge (not project-specific)

TASK SWITCH:
  - Before overwriting Working Context for a new task:
    Copy current Decisions line to Changelog entry.
  - This preserves decision rationale across tasks.

CROSS-SESSION:
  - Previous session's Working Context persists in TRACKING.md
  - On new session: read it, continue naturally
  - It updates organically — no "reset or continue?" prompt needed
```

## Tool Usage (MANDATORY when sprint-tools available)

```
USE sprint-tools instead of manual file editing:

  Status transitions:
    sprint-tools item CORE-NNN in_progress    — NOT manual Edit of TRACKING.md
    sprint-tools item CORE-NNN fixed "note"   — handles: status + evidence + changelog + roadmap sync
    sprint-tools item CORE-NNN verified "evidence"

  Sprint operations:
    sprint-tools checkpoint "status"   — NOT manual Edit of CLAUDE.md Last Checkpoint
    sprint-tools baseline metric val unit method — NOT manual Edit of baseline table
    sprint-tools close N               — NOT manual archive + cleanup
    sprint-tools git commit ITEM "msg" — NOT manual git add + commit

  Session context:
    sprint-tools note <type> "text"    — session journal (decision/attempt/observation/side-effect/artifact)
    sprint-tools learn "text"          — classify + route finding (guardrail/index/risk)

  Review:
    sprint-tools review file.md        — blind external LLM review
    sprint-tools state                 — sprint digest (verify your own work)

WHY mandatory:
  Tools do atomic multi-step operations (status + evidence + changelog + roadmap).
  Manual editing skips steps → missing evidence, stale roadmap, inconsistent changelog.
  E2E testing showed: manual editing produces 5x more observer findings than tool usage.

Working Context: use `sprint-tools checkpoint` with --task/--doing flags.
```

## Interruption Handling

```
IF user asks question mid-task:
  → answer fully
  → state: "I was at [step/item/phase]. Continue?"
  → WAIT for confirmation

IF AI restarted (same session):
  → read TRACKING.md, verify code state matches
  → ask if ambiguous

IF new session (context lost):
  → follow Session Start above
  → CLAUDE.md checkpoint + TRACKING = authoritative
  → in_progress with no context → restart item from step A
```

## During Implementation

- Read guardrails BEFORE writing code (3-layer: §Index → §TL;DR → full section only if writing code in that area)
- Self-verify EVERY code block
- Run ALL tests after each item (D.6)
- Never skip verification to "save time"
- Before fixing a bug: write root cause in one sentence. Can't? Investigate more.
- When stuck: apply Approach Escalation (IMPL-LOOP.md §B.2) — do not repeat the same approach.

## Evidence Standards

```
CONFIDENCE LEVELS (prefix evidence string when running sprint-tools item ... verified):

  VERIFIED  — direct observation: test ran + passed, runtime output checked, manual review
              Example: sprint-tools item CORE-NNN verified "VERIFIED: pytest 14/14 passed"
  INFERRED  — indirect signal: grep confirmed, static analysis, code review without execution
              Example: sprint-tools item CORE-NNN verified "INFERRED: grep shows function in 3 callers"
  UNCERTAIN — not independently checked, infrastructure unavailable
              Example: sprint-tools item CORE-NNN verified "UNCERTAIN: prod env not available, staging only"

FORMAT: Always prefix the evidence string with the confidence level.

RULES:
  Must items  → VERIFIED only (enforced by sprint-tools — wrong level exits with error).
  Should items → VERIFIED or INFERRED.
  Could items  → any level, but state it explicitly.
  UNCERTAIN alone is never sufficient for Must or Should items.

  sprint-tools enforcement: missing prefix → warning (advisory). Wrong level for
  priority → hard block (exit 2). Unknown priority → treated as must (fail-closed).

  IF VERIFIED is impossible (no test infra, non-executable item like docs/config):
    VERIFIED means: manual review confirms change matches AC. State review method.
    Example: "VERIFIED: manual review — README install steps match new CLI flags"
    Do NOT downgrade to INFERRED — instead, use VERIFIED with the review method.
    For pending infrastructure: mark item "pending" per IMPL-LOOP §D.6.

WHY: "grep found it" ≠ "it works." Stating confidence level forces the question:
     "Did I actually run this, or am I assuming?"
```

## CP3 Response (test failure detected)

```
ON CP3 AUDIT SIGNAL (injected by detect-test-regression hook):
  1. Spawn diagnostic sub-agent (worktree isolation) with:
     - Failing test output (from CP3 signal)
     - Stack trace / relevant source files
     - Task: identify root cause + propose fix (do NOT apply)
     - Return: root_cause, proposed_fix, confidence
  2. Review sub-agent diagnosis, then apply fix and re-run tests.
  3. If no sub-agent capability: diagnose in-context using §B.2 escalation.

  NEVER: ignore CP3 and continue to next item.
  NEVER: retry the same fix without understanding root cause first.
  Apply Approach Escalation (IMPL-LOOP §B.2) across retries.
```

## Auto-Detection

```
WATCH FOR at these points:
  Entry Gate:      metric regression vs baseline, failure pattern convergence
  Implementation:  broken past-sprint APIs, tests, profiler readings
  Close Gate:      Must items unverifiable due to past-sprint issues

IF signal detected:
  → flag to user immediately
  → do NOT silently continue
  → do NOT open audit without user confirmation
```

## Finding Externalization

```
RULE: Discover → Write → Continue

ROUTING:
  Bug / new work       → TRACKING.md (item or risk)
  Engineering lesson   → CODING_GUARDRAILS.md (rule)
  Architecture decision → CLAUDE.md (constraint)
  Scope change         → Roadmap.md (item)
  Domain topic         → Docs/SPRINT-INDEX.md
  Research finding     → relevant doc or TRACKING.md risk
  Session context      → sprint-tools note (decision/attempt/observation/side-effect)
  Long-form analysis   → sprint-tools note --artifact (saves to Docs/Artifacts/)

Write BEFORE continuing. Do not batch. Do not defer.
Unsure if worth persisting? Persist it. Disk is cheap, lost context is expensive.

SIGNS OF ACCUMULATION:
  - Said "I noticed X" but didn't open a file
  - Listed findings in chat without Write/Edit calls
  - Deferred: "I'll update TRACKING after finishing this"
```

## Research-to-Action

```
1. FRAME: "The problem is ___. We'll know the answer when ___."
2. LIST all questions up front — do not discover sequentially
3. RESEARCH in parallel (one round, all questions)
4. SYNTHESIZE → DECIDE → ACT (write decision to TRACKING/Roadmap)
5. IMPLEMENT smallest useful version immediately
6. MEASURE after implementation — only valid reason for round 2

ANTI-PATTERNS:
  ✗ research → research → research (no implementation between)
  ✗ design → revise → revise (implement after first design)
  ✗ "let me also check..." (not in original list → skip)
  ✗ sequential questions (ask all at once)

MECHANICAL vs SEMANTIC:
  Deterministic (paths, formats, enums) → code/hook/validation
  Semantic (importance, quality, intent) → clear instruction
```

## Research Triggers

```
Formal trigger list — referenced by ENTRY-GATE §Domain Research and IMPL-LOOP §A.5.

DOMAIN TRIGGERS (T1-T6) — fire at Entry Gate or IMPL-LOOP A.5:
  T1  New API/SDK       — item uses API/SDK not yet called in this project
  T2  Compliance/Legal  — item touches auth, PII, licensing, or regulated data
  T3  Perf-critical     — item has latency/throughput/memory SLA or benchmark
  T4  New algorithm     — item requires algorithm agent hasn't implemented before
  T5  Platform-specific — item depends on OS/GPU/browser behavior not in codebase
  T6  Data format       — item parses/generates format without existing parser

CONFIDENCE TRIGGERS (T7-T8) — fire at IMPL-LOOP §A.2.5 per-item:
  T7  Confidence gap    — agent rates own confidence <70% on approach correctness
  T8  Knowledge stale   — domain last researched >2 sprints ago OR API has known breaking changes

ESCALATION:
  T1-T6 match → prompt user for domain research (see ENTRY-GATE / IMPL-LOOP A.5)
  T7-T8 match → micro-gate: log trigger + ask user before proceeding (see IMPL-LOOP A.2.5)
  No match    → proceed without asking

DELEGATION (context preservation):
  T1-T6 (domain triggers) → prefer sub-agent delegation:
    Spawn research sub-agent with: trigger type, item description, relevant file paths.
    Task: research + return structured findings (max 20 lines).
    Main agent: receives findings, continues with clean context.
  T7-T8 (confidence triggers) → in-context OK (small scope).
  IF no sub-agent capability: proceed in-context but externalize findings to
    sprint-tools note immediately — do not accumulate research in conversation.
  WHY: domain research (T1-T6) consumes significant context. Delegation keeps
    main context focused on implementation.
```

## Blind Review

```
WHEN (workflow steps):
  Entry Gate:    review report before presenting (step 12a)
  Implementation: review item diff after D.7, before marking done
  Close Gate:    review verdict before presenting

WHEN (general — use anytime):
  Complex decision with high blast radius → review the plan/design
  Critical code (security, data, auth) → review the diff
  Uncertain about approach → review with specific --question

HOW: sprint-tools review <file> [-c "context"] [-q "question"]
  or: git diff | sprint-tools review --stdin

IF no API key configured → skip, proceed normally

ON FEEDBACK:
  Agree → fix before presenting
  Disagree → note to user: "Reviewer flagged X, I disagree because Y"
```

## Workflow Evolution

```
Before adding any step, check, or verification layer:

1. Does it catch a REAL, OBSERVED failure no existing mechanism catches?
   NO → do not add

2. Is the failure worth the overhead on EVERY future sprint?
   NO → do not add

3. Does it verify a previous check RAN, not catch a new failure class?
   YES → do not add ("who watches the watchers")

Complexity is a cost on every sprint. Minimum viable process.
```

## Entry Gate Quality Checklist

```
Verify BEFORE user approval:

Step 9a — Failure Modes (per item):
  ✓ Direct: ≥1 (breaks in isolation)
  ✓ Interaction: ≥1 (breaks with other systems)
  ✓ Stress/Edge: ≥1 (extreme load or input)
  ✓ Critical axis: ≥2 in relevant domain
  ✗ "No failure modes" never acceptable for Must items

Step 9b — Verification (per item):
  ✓ Testable inputs/outputs or invariants
  ✓ Specific enough to detect failure modes from 9a

Step 9c — Metrics (per Must):
  ✓ ≥1 measurable metric with numeric threshold
  ✓ Testable at Close Gate

Step 10 — Scope:
  ✓ Must items: 1-8 (hard limit)
  ✓ Each item has priority
```

## Sprint Close Quality Checklist

```
Verify BEFORE user handoff:

Step 7 — Retrospective:
  ✓ Predicted failures listed with outcome
  ✓ Unpredicted failures documented with root cause
  ✓ No failures → state explicitly

Step 5 — Baseline:
  ✓ Metrics with Sprint N values
  ✓ Comparison with N-1 if exists

Step 10 — Handoff:
  ✓ Per item: before → after
  ✓ How to verify (commands, URLs, steps)
  ✓ Known limitations / deferred items
```

## Update Rule

```
1. Check GUARDRAILS anti-pattern table → existing rule?
   YES → strengthen. NO → continue
2. Identify root cause
3. Add rule to relevant section (include "why" — root cause in one line)
4. Add to anti-pattern table
5. Reference in code comment
6. Update sprint-audit.sh if grep-detectable
```

<critical-rules>
## Critical Rules (repeated — recency reinforcement)

- Read guardrails BEFORE writing code, not after
- Discover → Write → Continue. Never defer writing findings
- Entry Gate and Close Gate are user-initiated only
- Run ALL tests after each item
- Use sprint-tools for TRACKING updates (NOT manual edit) — see §Tool Usage
- Before presenting important output → run blind review
</critical-rules>

</instructions>
