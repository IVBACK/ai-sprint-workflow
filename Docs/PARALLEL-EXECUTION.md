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
| 5+ overlapping files between items | Poor fit — merge overhead eats time savings |

**Rule: Don't force it.** If the dependency graph shows mostly sequential items,
work normally. Parallelization adds coordination overhead (merge = 30-45% of wave
time when file overlap exists) — it must earn its keep.

### Token Cost Trade-off

Parallel execution trades tokens for time and context quality:

| Factor | Serial | Parallel | Impact |
|--------|--------|----------|--------|
| Total token consumption | 1x | ~2-3x | Each agent gets its own context with duplicated preflight data |
| Coordinator context size | Full (all items) | ~40% less (merge + decisions only) | Coordinator stays focused |
| Per-agent context | N/A | Narrow (2-3 items + packet) | Better attention per item |
| Context overflow risk | High on 5+ items | Low (split across agents) | Serial often needs session splits anyway |
| Duplicated information | None | Guardrails, contracts, Entry Gate data copied per agent | ~30-50% of agent tokens are shared context |
| Merge overhead | None | 30-45% of wave time | Grows with file overlap — budget explicitly |

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

**Production benchmark (13 items, 3 waves):**

| Wave | Agents | Execution | Merge | Issues |
|------|--------|-----------|-------|--------|
| 1 | 3 parallel | ~8 min | ~5 min | 1 (missed test callers) |
| 2 | 2 parallel | ~9 min | ~12 min | 1 (file overwrite) |
| 3 | 3 parallel | ~5 min | ~1 min | 0 (clean base after commit) |
| **Total** | | **~35 min** | | **Serial estimate: 90+ min → ~2.5x speedup** |

Wave 3's zero-issue result directly followed inter-wave commit discipline + zero file overlap.

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

Sub-agents are not just for speed. They also keep implementation noise out of
the coordinator's context, allowing it to stay aligned with sprint rules, scope
boundaries, verification requirements, and final quality control. A coordinator
that reviews diffs is sharper than one that wrote the code itself.

### Coordinator Pre-Launch Checklist

Run before **every** wave launch. Do not skip steps — Wave 1-2 production bugs
all traced to skipped checklist items (see L7, L8).

```
PRE-LAUNCH CHECKLIST (per wave)
──────────────────────────────────────────────────────────────────
□ 1. PREVIOUS WAVE COMMITTED?
     Wave 1: skip (no previous wave)
     Wave 2+: verify git log shows previous wave's commit on sprint branch.
     If not committed → commit now. Do not launch agents on uncommitted state.

□ 2. FILE DISCOVERY — per item
     For each item in this wave: grep/glob to find which files will be modified.
     Don't guess — actually grep. Include test files.

□ 3. API CALLER SCAN — per item
     Does this item change a public API signature (params, return type, constants)?
     YES → grep the old signature across the FULL codebase (including test files).
           Include ALL callers in the agent's preflight packet.
           Do NOT delegate caller discovery to the agent.
     NO  → skip.

□ 4. FILE OVERLAP MATRIX
     Cross-reference step 2 results across all items in this wave.
     - 0 shared files → proceed
     - 1 shared file → partition scope (agent A edits lines 1-50, agent B edits 60-100)
       or move one item to next wave
     - 2+ shared files → group those items into the SAME agent
     Document the matrix before launching.

□ 5. EDIT-NOT-COPY RULE — per shared file
     For files touched by previous waves: instruct agents to use Edit (line-level)
     not Write (full file copy). A full copy from worktree overwrites previous wave's
     changes even after commit — because the worktree's copy was forked before those
     changes existed in that file's non-committed form.
     Explicit in prompt: "Edit lines X-Y only. Do not rewrite the full file."

□ 6. PREFLIGHT PACKET COMPLETE? — per agent
     Each agent's packet has all 6 items from §Preflight Context Packet?
     - [ ] File list (from step 2)
     - [ ] Guardrail sections
     - [ ] Relevant contracts
     - [ ] Neighbor awareness (which files other agents in this wave touch)
     - [ ] Entry Gate data (failure modes, verification plan for these items)
     - [ ] API callers (from step 3, if applicable)

□ 7. LAUNCH WAVE
──────────────────────────────────────────────────────────────────
```

**Time cost:** ~3-5 minutes per wave. **Savings:** prevents 10-15 minute merge rework
per missed step. Every production bug observed (L1, L4, L5, L8) would have been caught
by this checklist.

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
   return type, uniform/constant names), the **coordinator** must grep all callers
   (including test files) and include them in the packet before launching the agent.
   Do not delegate caller discovery to the agent — agents in narrow context tend to
   be conservative ("that might be another agent's file") and skip callers. The
   coordinator has full project visibility; the agent does not.
   Missing callers are the #1 source of post-wave test failures (see L1, L8).

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
- **1 shared file** → sequential execution, or explicit scope partitioning
- **2+ shared files** → group overlapping items into the same agent (merge overhead
  grows faster than execution time savings — 5 overlapping files ≈ merge taking
  30-45% of total wave time)
- Coordinator resolves conflicts before launching the wave
- **"Zero conflict" is unrealistic** in tightly coupled codebases. Minimize overlap
  through grouping, but plan merge strategy rather than expecting zero conflicts.

### Watchdog Pattern

Do not fire-and-forget agents. The coordinator:
1. Launches a wave of agents
2. Reviews each agent's output as it completes
3. Course-corrects early if an agent drifted off-track
4. Cheaper than discovering errors after full wave completion

### Inter-Wave Commit (Mandatory)

Sub-agents never commit autonomously. But the coordinator **must commit after each wave**
before launching the next wave. Reason: worktree-based agents fork from the last
committed state — uncommitted Wave 1 changes are invisible to Wave 2 agents,
causing silent state loss and duplicate/conflicting edits.

All inter-wave commits happen on a **sprint branch**, not main:

```
main:              ──A──B──────────────────────────────────── merge ←
sprint-N-impl:          └──[wave1]──[wave2]──[wave3]──CG──┘

Wave 1 agents complete → coordinator merges + tests pass
  → coordinator informs user: "Wave 1 complete, committing to sprint branch."
  → coordinator commits on sprint-N-impl branch
  → Wave 2 agents fork from committed state → see Wave 1's work
  → ...
  → Close Gate passes → merge sprint branch to main
```

**Why a branch:**
- main stays clean — no half-sprint commits pollute history
- Sprint abort → delete branch, main untouched
- Close Gate is the merge gate — nothing reaches main without passing audit
- **Squash merge to main** — wave commits are implementation detail, not history.
  Wave-by-wave history stays on the branch if needed for forensics.

**Merge ceremony (after Close Gate verdict, before Sprint Close step 1):**
```bash
# Close Gate Phase 2 fixes are committed to sprint-N-impl (not main)
git checkout main
git merge --squash sprint-N-impl
git commit -m "Sprint N: [summary]"
git branch -d sprint-N-impl          # cleanup — forensic history in reflog if needed
```
All Close Gate Phase 2 fixes must be committed to sprint-N-impl before the squash merge.
The merge happens **between Close Gate approval and Sprint Close step 1** — Sprint Close
runs on main with all sprint code already merged.

**Claude Code worktree integration:** The `isolation: "worktree"` parameter on the
Agent tool maps directly to this model. Coordinator works on `sprint-N-impl` branch →
each agent launched with `isolation: "worktree"` automatically forks from the branch's
current committed state → agent works in isolation → coordinator merges result back →
commits to sprint branch → next wave's worktrees see the previous wave's work.
No manual branch management needed — the tool handles worktree creation and cleanup.

The coordinator creates the sprint branch at the start of the first implementation
wave (not at Entry Gate — the branch contains only implementation commits).
The coordinator announces each commit but does not wait for approval — inter-wave
commits are a structural necessity, not a discretionary action.

Skipping the inter-wave commit is the #1 source of cross-wave bugs.

**Sequential fallback:** If the user declines parallel execution (Entry Gate step 11),
no sprint branch is created. Sequential implementation commits directly to the current
branch as items are completed. The sprint branch model applies **only** to parallel execution.

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

**Max 2-3 items per agent.** 4+ items per agent degrades quality — blast radius
scanning becomes incomplete, edge cases get missed. If you have 8 items, use 3-4
agents rather than 2 overloaded ones.

### Dedicated Test Agent (optional)

For sprints with 4+ items, a separate test agent can:
- Write cross-item integration tests after each wave
- Handle test files (no conflict risk — test files are separate from implementation)
- Run the full test suite after each wave to catch regressions

### Coordinator Between Waves

After each wave completes, the coordinator does a **lightweight review** — not a
line-by-line code review, but a structural sanity check. The goal is to catch
obvious breakage early (cheap to fix now) rather than letting it propagate to
the next wave (expensive to fix at Close Gate).

1. Review all agent outputs (watchdog)
2. Resolve any file conflicts discovered (expect merge overhead: 30-45% of wave time
   when file overlap exists — budget for this)
3. **API signature audit** — for each agent that changed a public API: did the agent
   update all callers? Grep for the old signature across the full codebase (including
   test files). Missing updates → fix before proceeding.
4. Run full test suite (catch cross-item regressions)
5. **Quick sanity scan** — skim diffs for obvious issues: broken imports, removed
   code that other items depend on, test files that reference deleted functions.
   This is NOT a deep review — that's the cross-cut agent's job at Close Gate.
6. Update TRACKING.md with all items from this wave
7. **Commit** — mandatory before launching next wave (see §Inter-Wave Commit)
8. Launch next wave with updated context (agents fork from committed state)

**Two-layer review model:**
- **Here (between waves):** coordinator catches surface-level breakage fast. If
  tests pass and imports resolve, proceed. Don't spend 20 minutes reading code —
  that defeats the purpose of delegation.
- **Close Gate Wave 2:** cross-cut review agent does the deep, systematic check
  (API consistency, type alignment, style, inter-item interactions) with full
  sprint diff context. This is where subtle cross-item issues get caught.

### Review Layers at a Glance

Five review points exist in the workflow. Each has a distinct scope — if two
reviews start doing the same thing, one should be removed.

| Layer | When | What it checks | Depth | Who |
|-------|------|----------------|-------|-----|
| Coordinator between-wave | After each impl wave | Tests pass, imports resolve, no obvious breakage | Surface — seconds, not minutes | Coordinator |
| Per-item audit | Close Gate Wave 2 | Failure modes handled? Fitness questions pass? | Deep, per-item scope | Sub-agent (1-2 items each) |
| Cross-cut review | Close Gate Wave 2 | API consistency, type alignment, style, inter-item interactions | Deep, cross-item scope | Sub-agent (full sprint diff) |
| sprint-audit.sh | Close Gate Wave 1 | Orphan IDs, untracked debt, format, mechanical rules | Automated, policy | Script |
| Sprint Close step 6 | Sprint Close | Cross-reference integrity (CLAUDE.md ↔ target files) | Automated, structural | Coordinator |

**Rule of thumb:** if you can't explain in one sentence what a review layer
catches that no other layer catches, it shouldn't exist.

---

## Close Gate — Parallel Pattern

Sequential workflow: Phases −1 through 4 run in one context.
Parallel workflow: split into two waves after Phase −1.

**Phase −1 (state recovery) runs sequentially** — mandatory coordinator task.
Must read TRACKING.md + Entry Gate report and state items/metrics before proceeding.

**Branch checkout:** If Close Gate runs in a fresh session (recommended by WORKFLOW.md),
the coordinator must `git checkout sprint-N-impl` before starting Phase −1. All Close Gate
work (including Phase 2 fixes) happens on the sprint branch. Squash merge to main happens
after Close Gate verdict, before Sprint Close.

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
| Cross-cut review agent (1) | Cross-item consistency check (optional but recommended) | Full sprint diff (`git diff main...sprint-N-impl`) |

Each per-item agent handles 1-2 items and returns:
- Per-item failure mode status (HANDLED / MISSED / N/A per mode)
- Per-item fitness verdict (PASS / CONCERN with explanation)
- Supplemental findings (leaks, dead code, observability gaps)

The cross-cut review agent runs in parallel with per-item agents and checks:
- **API contract consistency** — if one item changed a function signature, do all
  callers (including other items' code) use the new signature?
- **Type/interface alignment** — shared types modified by one item still match
  usage in other items' files
- **Style consistency** — naming conventions, error handling patterns, log formats
  across all changed files
- **Unintended interactions** — two items touching adjacent code that may conflict
  at runtime even without merge conflicts

Cross-cut agent returns a structured report:

```
## Cross-Cut Review — Sprint N

### API Consistency: PASS / ISSUE
[details if ISSUE]

### Type Alignment: PASS / ISSUE
[details if ISSUE]

### Style Consistency: PASS / CONCERN
[details if CONCERN]

### Interaction Risks: NONE / FOUND
[details if FOUND]
```

← **Coordinator merge (sequential from here):**
- Phase 2: fix findings from per-item audits AND cross-cut review (coordinator
  decides priority — cross-cut issues often have higher blast radius)
- Phase 3: regression test run (coordinator — full suite)
- Phase 4: test coverage gap check (coordinator — cross-cut review may have
  already flagged gaps, reducing coordinator's work here)
- Compile verdict, present to user

**Why this works:** Per-item audits are completely independent — each item
examines its own implementing files against its own failure modes. The cross-cut
agent covers the gap that per-item agents cannot see: inter-item consistency.
The coordinator merges all results for Phase 2 decisions without having to read
implementation code itself.

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
| Cross-item inconsistency | Two-layer review: coordinator lightweight check between waves + cross-cut agent deep review at Close Gate Wave 2 |
| Agent going off-track | Watchdog pattern catches early (review as agents complete) |
| Context pollution | Each agent gets narrow context — no full-project dump |
| Stale agent context | Coordinator provides Wave 1 summary to Wave 2 agents |
| Race on shared files | Only coordinator writes TRACKING.md, Roadmap.md, CLAUDE.md |
| Incomplete API updates | Preflight packet §6 (API caller list) + coordinator post-wave signature audit |
| Cross-wave state loss | Inter-wave commit mandatory — Wave 2 worktrees must fork from committed state |
| Merge overhead eating time savings | Group 2+ overlapping files into same agent; budget 30-45% of wave time for merge |
| Agent scope too wide | Max 2-3 items per agent; 4+ items degrades blast radius scanning quality |
| Cross-file caller miss | Not an isolation problem — caused by coordinator skipping caller grep; solved by §Preflight Packet item 6 (see L7, L8) |
| Coordinator prompt errors | Both observed wave bugs traced to coordinator prompts, not agent execution; invest time in preflight research (see L8) |
| Cross-cut agent coverage gap | Large diffs may exceed agent attention — coordinator's between-wave sanity check (step 5) is the first line of defense; test suite catches runtime issues that static diff review misses |

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

### L2: Worktree Isolation Helps but Doesn't Eliminate Merge Work

**Observed:** Two agents modified different sections of the same compute shader file.
Worktree isolation (each agent in its own git worktree) meant both agents worked on
clean copies. Coordinator merged changes without conflict in that case.

**However:** In a 13-item sprint with 5 overlapping files, merge overhead consumed
30-45% of total wave time. `git apply --3way` partially failed because Wave 1 was
in uncommitted state. Each overlapping file required manual read + edit.

**Takeaway:** Worktree isolation is better than no isolation, but "eliminates merge
problems" is too optimistic for tightly coupled codebases. Group items that share
2+ files into the same agent. Budget merge time explicitly.

### L3: Wave-End Test Suite Is Non-Negotiable

**Observed:** All individual agent tests passed in isolation, but the combined wave
had 5 failures due to the missed API callers (L1). The wave-end full test suite
caught this immediately.

**Takeaway:** Never skip the coordinator's post-wave test suite run, even when all
agents report success. Cross-agent interactions are invisible to individual agents.

### L4: Cross-Wave State Loss from Uncommitted Work

**Observed:** Wave 2 Agent D's worktree forked from last commit. Wave 1 Agent C had
added a new method (ComputeNormSum) but it was uncommitted. Agent D copied a helper
file from committed state — silently dropping Agent C's method. Tests caught it, but
the root cause was structural: worktrees don't see uncommitted changes.

**Same sprint:** Agent C missed 3 test file callers for a new uniform because its
preflight packet lacked full caller discovery. Both bugs share the same pattern —
incomplete visibility of Wave 1's actual state.

**Fix:** Inter-wave commit is now mandatory (see §Inter-Wave Commit). Wave N must be
committed before Wave N+1 agents are launched.

**Takeaway:** "Fire and merge later" doesn't work. Each wave boundary needs a commit
checkpoint to give the next wave a clean, complete starting point.

### L5: Agent Quality Degrades at 4+ Items

**Observed:** In a 5-agent wave, agents handling 1-2 items (shader optimization, GC
allocation fixes) produced clean, hatasız output. The agent handling 4 Should items
missed blast radius on one item — 3 test callers were not updated.

**Takeaway:** Cap agents at 2-3 items. More items = wider context = weaker attention
per item. If you have 8 items, use 3-4 agents, not 2.

### L6: Merge Overhead Is 30-45% of Wall-Clock Time

**Observed:** In a 13-item, 2-wave sprint: agent execution ~17 min, merge + conflict
resolution ~15 min. Merge overhead was not a rounding error — it was nearly half the
total time. 5 overlapping files between waves drove most of the merge cost.

**Follow-up (3-wave sprint):** Wave 3 had 1 minute merge and 0 issues. Two factors contributed:
1. **Inter-wave commit** (always reproducible) — committed Wave 1+2 before Wave 3,
   giving worktrees a clean base. This eliminated the "agent silently drops previous
   wave's work" class of bugs entirely. Applicable to every sprint regardless of coupling.
2. **Zero file overlap** (situation-dependent) — Wave 3's 3 Could items touched completely
   separate files, making merge trivial. But in Wave 1-2, Must+Should items all touched
   central files — zero overlap was not achievable there.

Don't conflate the two. Commit discipline is a process fix you always control. File overlap
depends on the codebase — minimize it via grouping, but expect it on tightly coupled items.

**Takeaway:** Two levers for merge overhead: (1) inter-wave commit — always use, eliminates
state loss bugs; (2) file overlap grouping — use when possible, but budget merge time when
overlap is unavoidable.

### L7: Isolation Improves Quality — When Coordinator Does Its Job

**Observed (Wave 1-2):** Agents with narrow scope (1-2 files) produced cleaner, faster
output than serial execution. Agent A finished 2 shader findings in 74 seconds with 0
errors. But Agent C skipped 3 test file callers — not because isolation hurt quality,
but because the coordinator didn't include those callers in the preflight packet.

**Observed (Wave 3):** Coordinator traced caller chains, specified exact file ownership,
used zero-overlap grouping. Result: 0 issues across 3 agents. Per-file quality stayed
high AND cross-file blast radius was fully covered.

**Initial (wrong) conclusion:** "Isolation helps per-file, hurts cross-file — net neutral."
**Corrected conclusion:** Cross-file quality drop was caused by coordinator prep failure,
not by isolation itself. When the coordinator properly greps callers and includes them
in the preflight packet (§6), isolation provides a net quality improvement — agents get
focused context without missing cross-file dependencies.

**Takeaway:** Isolation is a quality win, not a trade-off — but only if the coordinator
invests in preflight research. The fix is in §Preflight Context Packet item 6 and L8.

### L8: Coordinator Prompt Quality Is the #1 Success Factor

**Observed:** Both Wave 1-2 bugs traced to coordinator prompt errors, not agent errors:
- Agent C missed test callers → coordinator didn't grep callers before writing the prompt
- Agent D overwrote Wave 1's method → coordinator gave the file as a copy instead of
  instructing Edit-only on specific lines

Agents executed their prompts correctly. The prompts were wrong.

**Wave 3 (after learning):** Coordinator traced caller chains, specified exact file
ownership, used zero-overlap grouping. Result: 0 issues across 3 agents.

**Takeaway:** Parallel execution quality is bounded by coordinator preparation quality.
Time spent on preflight packet assembly (caller grep, overlap analysis, explicit file
ownership) pays back 10x in avoided merge rework. The coordinator's job is not "delegate
and wait" — it is "research, plan, delegate precisely."

The §Coordinator Pre-Launch Checklist formalizes this. Every observed bug maps to a
skipped checklist step: step 3 catches caller misses, step 5 catches file overwrites,
step 1 catches uncommitted state.

### L9: "Already Implemented" Detection Is a Parallel Bonus

**Observed:** Agent assigned to CORE-359 determined in 40 seconds that CORE-335 (previous
sprint) had already implemented the same functionality. Serial investigation would have
taken 10+ minutes of manual grep and diff analysis.

**Takeaway:** Parallel agents are efficient scouts. If an item might already be done,
assigning an agent to verify is cheaper than investigating manually. The agent either
confirms "already done" (saving the item's full implementation time) or proceeds with
implementation.

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

IMPLEMENTATION (on sprint-N-impl branch)
  Create sprint branch at first wave
  ┌─ PRE-LAUNCH CHECKLIST (§Coordinator Pre-Launch Checklist)
  │  □ Previous wave committed? □ File discovery □ API caller scan
  │  □ Overlap matrix □ Edit-not-copy rule □ Packets complete
  └─
  Wave N ─┬─ Agent/item: full A-E loop (max 2-3 items/agent)
           ├─ Agent/item: ...
           └─ (optional: dedicated test agent)
  Coordinator ──── merge, resolve conflicts, test suite, TRACKING.md update
                   COMMIT to sprint branch (mandatory before next wave)
  Wave N+1 ──── PRE-LAUNCH CHECKLIST → launch (forks from committed state)

CLOSE GATE (on sprint-N-impl branch)
  Phase −1 ─────── sequential (checkout sprint-N-impl + state recovery)
  Wave 1 ─┬─ Agent A: sprint-audit.sh
           └─ Agent B-N: per-item metric verification
  Coordinator ──── merge → metric table + audit summary → user
  Wave 2 ─┬─ Agent/item: Phase 1b predicted FM vs actual
           ├─ Agent/item: Phase 1c fitness review
           └─ Cross-cut agent: API consistency, type alignment, style, interactions
  Coordinator ──── Phase 2 fix (per-item + cross-cut findings) → Phase 3 test → Phase 4 coverage → verdict

MERGE (between Close Gate verdict and Sprint Close)
  git checkout main → git merge --squash sprint-N-impl → git commit → git branch -d sprint-N-impl

SPRINT CLOSE
  Sequential (coordinator only, on main)
```
