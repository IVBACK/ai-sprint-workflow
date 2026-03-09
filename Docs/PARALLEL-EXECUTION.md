# Parallel Execution Guide

Optional parallelization patterns for AI agents that support sub-agent spawning.
Core workflow (WORKFLOW.md) remains sequential and agent-agnostic — this document
layers parallel execution on top for agents that can coordinate multiple sub-agents.

**Supported agents:** Claude Code (Agent tool — tested in VS Code extension; CLI
should work identically as the Agent tool is the same), any agent framework with
sub-agent orchestration. Agents without sub-agent support ignore this document
and follow the sequential workflow.

**Prerequisite:** Read the relevant gate section in WORKFLOW.md first. This document
does not redefine gate phases — it reorganizes their execution into parallel waves.

**Loading rule:** This document is NOT read on every session start. It is loaded
only when (a) the user explicitly requests parallel execution (e.g., "run this wave
in parallel", "use parallel agents for implementation"), or (b) the user accepts the
AI's suggestion at Entry Gate step 11 (AI suggests when 4+ independent items exist).
The coordinator reads only the relevant section (Entry Gate / Implementation / Close
Gate), not the full document. Sub-agents never read this document — they receive a
preflight packet instead.

---

## When to Parallelize

Evaluate at Entry Gate via the dependency graph:

| Condition | Parallel? |
|-----------|-----------|
| 4+ independent items touching separate files | Good fit |
| Most items share files or have sequential deps | Poor fit — sequential is fine |
| Architectural sprint (shared core refactor) | Poor fit — overhead not worth it |
| ≤3 Must items (abbreviated gate) | Usually not worth it |

**Rule: Don't force it.** If the dependency graph shows mostly sequential items,
work normally. Parallelization adds coordination overhead — it must earn its keep.

### Token Cost Trade-off

Parallel execution trades tokens for time and context quality:

| Factor | Serial | Parallel | Impact |
|--------|--------|----------|--------|
| Total token consumption | 1x | ~2-3x | Each agent gets its own context with duplicated preflight data |
| Coordinator context size | Full (all items) | ~40% less (merge + decisions only) | Coordinator stays focused |
| Per-agent context | N/A | Narrow (2-3 items + packet) | Better attention per item |
| Context overflow risk | High on 5+ items | Low (split across agents) | Serial often needs session splits anyway |
| Duplicated information | None | Guardrails, contracts, Entry Gate data copied per agent | ~30-50% of agent tokens are shared context |

**When token cost is justified:**
- 4+ independent items — time savings outweigh token overhead
- Sprint approaching context window limits — serial would need session splits (state recovery = hidden token cost)
- Items requiring deep analysis (failure modes, metric sufficiency) — attention quality improvement prevents rework

**When token cost is NOT justified:**
- ≤3 items or abbreviated gate — overhead exceeds savings
- Short items with obvious implementations — agents add ceremony without benefit
- Budget-constrained runs — serial with session boundaries is cheaper

**Hidden serial costs to consider:** Context overflow forces session splits → state recovery
(re-reading TRACKING.md, Entry Gate report, re-establishing context) costs ~30-50K tokens
per split. A sprint with 7 items might need 2-3 session splits serially, partially closing
the token gap with parallel execution.

---

## Concepts

### Coordinator vs Agent

| Role | Responsibility |
|------|----------------|
| **Coordinator** | Launches waves, merges results, makes cross-item decisions, writes shared files |
| **Agent** | Executes a scoped task with a narrow context, returns structured output |

The coordinator never does heavy analysis — it delegates, merges, and decides.
Agents never write to shared files (TRACKING.md, Roadmap.md, CLAUDE.md) — only
the coordinator does.

### Agent Output Contract

Every agent returns output in this format:

```
## Agent Report — [task description]
STATUS: PASS | WARN | FAIL
ITEMS_ANALYZED: [list of CORE-### IDs]
FINDINGS:
  - [finding 1]
  - [finding 2]
  - ... (max 10 per agent)
BLOCKERS:
  - [blocker 1, if any]
RAW_DETAIL: [full analysis — coordinator includes selectively in final report]
```

Coordinator merges agent reports into the gate report. Agent STATUS values roll up:
any FAIL → gate blocked. Any WARN → coordinator reviews before proceeding.

### Preflight Context Packet

Before launching an agent, the coordinator assembles a scoped context packet:

1. **Relevant file list** — pre-discovered via grep/glob (not "read everything")
2. **Relevant guardrail sections** — only rules that apply to this item's domain
3. **Relevant contracts** — density conventions, buffer rules, API contracts
4. **Neighbor awareness** — which files other parallel agents are touching (read-only)
5. **Entry Gate data** — failure modes, metrics, verification plan for this item only
6. **API caller list** — if this item changes a public API signature (function params,
   return type, uniform/constant names), grep all callers (including test files) and
   include them in the packet. Agent must update every caller, not just the ones it
   initially planned to touch. Missing callers are the #1 source of post-wave test failures.

This prevents agents from consuming full project context. Narrow context = better focus.

### Shared File Registry

Before launching parallel agents, the coordinator maps file ownership:

```
CORE-350 → writes: src/cave.rs, src/cave_test.rs
CORE-349 → writes: src/ore.rs, src/ore_test.rs
CORE-354 → writes: src/hardness.rs, src/hardness_test.rs
CORE-348 → writes: src/cave.rs (CONFLICT with CORE-350)
```

- **No conflict** → agents run in parallel
- **Same file** → sequential execution, or explicit scope partitioning
- Coordinator resolves conflicts before launching the wave

### Watchdog Pattern

Do not fire-and-forget agents. The coordinator:
1. Launches a wave of agents
2. Reviews each agent's output as it completes
3. Course-corrects early if an agent drifted off-track
4. Cheaper than discovering errors after full wave completion

### No Auto-Commit

Agents write code and pass tests. The coordinator merges and verifies cross-item
consistency. The **user** decides when to commit. No agent commits autonomously.

---

## Entry Gate — Parallel Pattern

Sequential workflow: Phases 0-3 run in one context, steps 1-12 sequentially.
Parallel workflow: split into two waves after Phase 0.

**Phase 0 runs sequentially** — sprint detail, type detection, scope negotiation.
These require coordinator judgment and user interaction.

### Wave 1 — Read-Only Reconnaissance (parallel)

All agents are read-only. No file writes, no state changes.

| Agent | Task | Reads | Output |
|-------|------|-------|--------|
| A | State review | TRACKING.md → open items, blockers, carry-forwards | Item status summary, deferred metrics, open risks |
| B | Roadmap analysis | Roadmap.md → sprint scope, dependency map | Dependency graph, cross-sprint deps, scope assessment |
| C | Sanity check | `roadmap-sanity.sh` + CODING_GUARDRAILS.md §Index | Orphan IDs, stale checkboxes, cross-file drift |
| D | API verification | Dependency API source files (Phase 2, steps 5-7) | Contract match status, open architectural decisions |

**Optional background task:** smoke test / build verification runs in parallel
with Wave 1. Result available by Wave 2.

← **Coordinator merge:**
- Combine agent outputs into a 30-line state summary
- Resolve conflicts between agents (e.g., agent A says item blocked, agent B says dependency met)
- Identify items needing user decision (carry-forward, deferred metrics, scope changes)
- Present consolidated summary to user (Phase 1-2 combined)
- Apply user decisions

### Wave 2 — Per-Item Analysis (parallel)

Each agent handles 2-3 items. Fully independent — each item analyzes different files.

| Agent | Task | Input |
|-------|------|-------|
| Per-item agent | Steps 8a-d (strategic alignment) + 9a-c (failure modes, verification plan, metric sufficiency) | Preflight packet for assigned items + Wave 1 summary |

Each agent outputs per-item:
- Alignment check results (keep/modify/defer/remove recommendation)
- Failure modes (3 categories: direct, interaction, stress-edge)
- Verification plan (test scenarios, invariants)
- Metric sufficiency assessment (4 checks per metric)
- Fitness check results

← **Coordinator merge:**
- Step 10: scope check (realistic? within limits?)
- Step 11: dependency-ordered implementation list (cross-item, only coordinator can do this)
- Step 12: compile full Entry Gate report, AI assessment, present to user

**Why this works:** Steps 8-9 per item are completely independent. Item A's failure
modes don't depend on item B's alignment check. The coordinator only needs all
results together for steps 10-12.

---

## Implementation Loop — Parallel Pattern

The implementation loop already supports parallelization via the dependency graph
from Entry Gate step 11.

### Wave Planning

At Entry Gate step 11, the coordinator produces a wave plan:

```
Wave 1 (independent): CORE-350, CORE-349, CORE-354  (parallel agents)
Wave 2 (depends on Wave 1): CORE-348 (depends on 350), CORE-351
Wave 3 (depends on Wave 2): CORE-353
```

### Per-Item Agent Execution

Each agent in a wave runs the full Implementation Loop (A → E) for its assigned item:
- A: Pre-code check (impact analysis, guardrails)
- A.5/A.6: Domain research / approach selection (if needed)
- B: Write code
- C: Self-verify (5-point checklist)
- D: Write tests + D.6 incremental test run
- E: Report back (not write to TRACKING.md — coordinator does that)

**Agent writes code + tests. Coordinator writes TRACKING.md.**

### Dedicated Test Agent (optional)

For sprints with 4+ items, a separate test agent can:
- Write cross-item integration tests after each wave
- Handle test files (no conflict risk — test files are separate from implementation)
- Run the full test suite after each wave to catch regressions

### Coordinator Between Waves

After each wave completes:
1. Review all agent outputs (watchdog)
2. **API signature audit** — for each agent that changed a public API: did the agent
   update all callers? Grep for the old signature across the full codebase (including
   test files). Missing updates → fix before proceeding.
3. Run full test suite (catch cross-item regressions)
4. Update TRACKING.md with all items from this wave
5. Resolve any file conflicts discovered
6. Launch next wave with updated context

---

## Close Gate — Parallel Pattern

Sequential workflow: Phases −1 through 4 run in one context.
Parallel workflow: split into two waves after Phase −1.

**Phase −1 (state recovery) runs sequentially** — mandatory coordinator task.
Must read TRACKING.md + Entry Gate report and state items/metrics before proceeding.

### Wave 1 — Automated Checks (parallel)

| Agent | Task | Output |
|-------|------|--------|
| A | `sprint-audit.sh` execution | Exit code + findings list |
| B-N | Per-item metric verification (Phase 0) | Metric status per item (PASS/FAIL/DEFERRED/MISSING) |

Each metric verification agent:
- Takes one item's metrics from the Entry Gate report
- Checks if tests exist, pass, and match thresholds
- Returns structured metric row for the verification table

← **Coordinator merge:**
- Compile Metric Verification table from per-item results
- Review sprint-audit.sh findings
- Present Phase 0 + 1a combined to user
- Handle FAIL/MISSING escalations (user decisions)

### Wave 2 — Per-Item Audit (parallel)

| Agent | Task | Input |
|-------|------|-------|
| Per-item agent | Phase 1b: predicted failure modes vs implementation | Item's predicted modes + implementing files |
| Per-item agent | Phase 1c: fitness review (3 fitness questions) | Item's implementation + Critical Axis |

Each agent handles 1-2 items and returns:
- Per-item failure mode status (HANDLED / MISSED / N/A per mode)
- Per-item fitness verdict (PASS / CONCERN with explanation)
- Supplemental findings (leaks, dead code, observability gaps)

← **Coordinator merge (sequential from here):**
- Phase 2: fix findings (coordinator — may require cross-item judgment)
- Phase 3: regression test run (coordinator — full suite)
- Phase 4: test coverage gap check (coordinator — cross-item view needed)
- Compile verdict, present to user

**Why this works:** Phase 1b/1c per item are completely independent — each item
examines its own implementing files against its own failure modes. The coordinator
only needs all results for Phase 2 decisions.

---

## Sprint Close — Not Parallelized

Sprint Close (steps 1-15) is mostly shared-file writes:
- TRACKING.md updates (checkmarks, status, baselines, retrospective)
- Roadmap.md updates (next sprint sketch)
- CLAUDE.md §Last Checkpoint update

Parallelization would risk write conflicts for ~10-20% time savings.
Not worth it. Run sequentially.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Same-file edits | Shared File Registry prevents conflicts before launch |
| Guardrail ignorance | Preflight packet includes relevant rules per agent |
| Cross-item inconsistency | Coordinator reviews + test suite after each wave |
| Agent going off-track | Watchdog pattern catches early (review as agents complete) |
| Context pollution | Each agent gets narrow context — no full-project dump |
| Stale agent context | Coordinator provides Wave 1 summary to Wave 2 agents |
| Race on shared files | Only coordinator writes TRACKING.md, Roadmap.md, CLAUDE.md |
| Incomplete API updates | Preflight packet §6 (API caller list) + coordinator post-wave signature audit |

---

## Observed Lessons

Patterns confirmed through production use of the parallel execution system.

### L1: API Signature Changes Have Hidden Blast Radius

**Observed:** Agent changed a shared library's function signature (added a parameter).
Agent updated 3/6 callers — the 3 it knew about from its preflight packet. 3 test files
that also called the function were not in the packet → 5 tests failed post-wave.

**Root cause:** Preflight packet listed "relevant files" but not "all callers of modified APIs."

**Fix:** Preflight Context Packet item §6 (API caller list) now requires a grep for all
callers when an API signature changes. Coordinator post-wave audit (step 2) verifies
no callers were missed.

**Takeaway:** Narrow context is correct for analysis, but API changes require full-codebase
caller discovery. The preflight packet must expand dynamically when the item's scope
includes signature changes.

### L2: Worktree Isolation Prevents File Conflicts

**Observed:** Two agents modified different sections of the same compute shader file.
Worktree isolation (each agent in its own git worktree) meant both agents worked on
clean copies. Coordinator merged changes without conflict.

**Takeaway:** For agents that support worktree isolation, prefer it over file-level
partitioning. It is simpler and eliminates an entire class of merge problems.

### L3: Wave-End Test Suite Is Non-Negotiable

**Observed:** All individual agent tests passed in isolation, but the combined wave
had 5 failures due to the missed API callers (L1). The wave-end full test suite
caught this immediately.

**Takeaway:** Never skip the coordinator's post-wave test suite run, even when all
agents report success. Cross-agent interactions are invisible to individual agents.

---

## Quick Reference — Wave Structure

```
ENTRY GATE
  Phase 0 ──────── sequential (coordinator + user)
  Wave 1 ─┬─ Agent A: TRACKING.md state review
           ├─ Agent B: Roadmap scope + deps
           ├─ Agent C: sanity checks + guardrails
           ├─ Agent D: API source verification
           └─ (background: smoke test)
  Coordinator ──── merge → 30-line summary → user decisions
  Wave 2 ─┬─ Agent/item: 8a-d alignment + 9a-c failure modes + metrics
           ├─ Agent/item: (2-3 items per agent)
           └─ Agent/item: ...
  Coordinator ──── steps 10-12 → report → user approval

IMPLEMENTATION
  Wave plan from Entry Gate step 11
  Wave N ─┬─ Agent/item: full A-E loop
           ├─ Agent/item: ...
           └─ (optional: dedicated test agent)
  Coordinator ──── review, test suite, TRACKING.md update
  Wave N+1 ──── ...

CLOSE GATE
  Phase −1 ─────── sequential (coordinator state recovery)
  Wave 1 ─┬─ Agent A: sprint-audit.sh
           └─ Agent B-N: per-item metric verification
  Coordinator ──── merge → metric table + audit summary → user
  Wave 2 ─┬─ Agent/item: Phase 1b predicted FM vs actual
           └─ Agent/item: Phase 1c fitness review
  Coordinator ──── Phase 2 fix → Phase 3 test → Phase 4 coverage → verdict

SPRINT CLOSE
  Sequential (coordinator only)
```
