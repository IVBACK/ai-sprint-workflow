<instructions>

# Parallel Execution Guide

**CRITICAL: Commit after EVERY wave before launching next. Uncommitted work is invisible to worktree-based agents.**
**CRITICAL: Max 2-3 items per agent. 4+ items degrades quality.**
**CRITICAL: Coordinator greps ALL callers for API signature changes. Do NOT delegate caller discovery to agents.**

Layers parallel execution on top of sequential WORKFLOW.md. Read relevant gate section in WORKFLOW.md first. Sub-agents never read this document -- they receive preflight packets.

**Loading rule:** Load only when user requests parallel execution OR accepts AI suggestion at Entry Gate step 11 (4+ independent items). Read only the relevant section.

---

## 1. When to Parallelize

| Condition | Decision |
|-----------|----------|
| 4+ independent items, separate files | Good fit |
| Most items share files or sequential deps | Poor fit |
| Architectural sprint (shared core refactor) | Poor fit |
| <=3 Must items (abbreviated gate) | Not worth it |
| 5+ overlapping files between items | Poor fit -- merge overhead eats savings |

IF dependency graph shows mostly sequential items:
  Work sequentially. Parallelization adds 30-45% merge overhead with file overlap.

### Token Trade-off

- Parallel: ~2-3x total tokens (duplicated preflight per agent), but ~40% less coordinator context
- Serial with 5+ items risks context overflow -> session splits cost ~30-50K tokens each
- 4+ independent items: time savings outweigh token overhead
- <=3 items or budget-constrained: serial is cheaper

---

## 2. Core Concepts

### Coordinator vs Agent

| Role | Responsibility |
|------|----------------|
| **Coordinator** | Launch waves, merge results, cross-item decisions, write shared files |
| **Agent** | Execute scoped task, narrow context, return structured output |

Agents NEVER write shared files (TRACKING.md, Roadmap.md, CLAUDE.md). Only coordinator writes these.

### Agent Output Contract

```
## Agent Report -- [task]
STATUS: PASS | WARN | FAIL
ITEMS_ANALYZED: [CORE-### IDs]
FINDINGS:
  - [finding] (max 10)
BLOCKERS:
  - [blocker, if any]
RAW_DETAIL: [full analysis]
```

Rollup: any FAIL -> gate blocked. Any WARN -> coordinator reviews.

### Preflight Context Packet (6 items per agent)

1. **File list** -- pre-discovered via grep/glob
2. **Relevant guardrail sections** -- only rules for this item's domain
3. **Relevant contracts** -- density, buffer, API contracts
4. **Neighbor awareness** -- files other parallel agents touch (read-only)
5. **Entry Gate data** -- failure modes, metrics, verification plan for this item
6. **API caller list** -- IF item changes public API signature: coordinator greps ALL callers (including tests). Include in packet. Do NOT delegate to agent.

### Shared File Registry

```
CORE-350 -> writes: src/cave.rs, src/cave_test.rs
CORE-349 -> writes: src/ore.rs, src/ore_test.rs
CORE-348 -> writes: src/cave.rs (CONFLICT with CORE-350)
```

IF 0 shared files -> parallel
ELIF 1 shared file -> partition scope or move to next wave
ELIF 2+ shared files -> group into SAME agent

### Inter-Wave Commit (Mandatory)

Sub-agents never commit. Coordinator MUST commit after each wave.

```
sprint-N-impl: --[wave1]--[wave2]--[wave3]--CG-- squash merge to main
```

Worktree agents fork from committed state. Uncommitted Wave 1 = invisible to Wave 2.
Coordinator announces commit, does not wait for approval (structural necessity).

---

## 3. Coordinator Pre-Launch Checklist

Run before EVERY wave. Do not skip steps.

```
PRE-LAUNCH CHECKLIST (per wave)
-------------------------------------------------
[] 1. PREVIOUS WAVE COMMITTED?
     Wave 1: skip. Wave 2+: verify git log. If not committed -> commit now.

[] 2. FILE DISCOVERY -- per item
     grep/glob to find which files will be modified. Include test files.

[] 3. API CALLER SCAN -- per item
     IF item changes public API signature (params, return type, constants):
       grep old signature across FULL codebase (including tests).
       Include ALL callers in preflight packet.
     ELSE: skip.

[] 4. FILE OVERLAP MATRIX
     Cross-reference step 2 across all wave items.
     IF 0 shared files -> proceed
     ELIF 1 shared file -> partition scope or defer item
     ELIF 2+ shared files -> group into same agent

[] 5. EDIT-NOT-COPY RULE -- per shared file
     Files from previous waves: instruct "Edit lines X-Y only. Do not rewrite full file."
     Full-file Write overwrites previous wave changes.

[] 6. PREFLIGHT PACKET COMPLETE? -- per agent
     All 6 items from Preflight Context Packet present?

[] 7. LAUNCH WAVE
-------------------------------------------------
```

~3-5 min per wave. Prevents 10-15 min merge rework per missed step.

---

## 4. Entry Gate -- Parallel Pattern

Phase 0 sequential (sprint detail, type detection, scope negotiation).

### Wave 1 -- Read-Only Reconnaissance (parallel)

| Agent | Task | Output |
|-------|------|--------|
| A | TRACKING.md state review | Item status, blockers, carry-forwards |
| B | Roadmap scope + dependency map | Dependency graph, scope assessment |
| C | `roadmap-sanity.sh` + guardrails index | Orphan IDs, stale checkboxes, drift |
| D | Dependency API verification | Contract match status |

Optional background: smoke test / build verification.

Coordinator merge: combine into 30-line summary -> resolve conflicts -> present to user.

### Wave 2 -- Per-Item Analysis (parallel)

Each agent handles 2-3 items. Steps 8a-d (alignment) + 9a-c (failure modes, verification, metrics).

Output per item: alignment recommendation, failure modes (3 categories), verification plan, metric sufficiency, fitness check.

Coordinator merge: step 10 (scope check) -> step 11 (dependency-ordered list) -> step 12 (full report).

---

## 5. Implementation Loop -- Parallel Pattern

### Wave Planning (from Entry Gate step 11)

```
Wave 1 (independent): CORE-350, CORE-349, CORE-354
Wave 2 (depends on 1): CORE-348, CORE-351
Wave 3 (depends on 2): CORE-353
```

### Per-Item Agent Execution

Each agent runs full A-E loop:
- A: Pre-code check (impact, guardrails)
- A.5/A.6: Domain research / approach selection (if needed)
- B: Write code
- C: Self-verify (5-point checklist)
- D: Tests + D.6 incremental run + D.6b external review + D.7 AC exit check (MANDATORY -- include file:line evidence)
- E: Report (not write TRACKING.md)

Note: cross-llm-audit hook is skipped in sub-agent worktrees (by design — narrow scope, results don't reach coordinator). Sub-agents run `sprint-tools review <file>` manually for D.6b instead.

Items without AC evidence -> sent back.

### Coordinator Between Waves

1. Review all agent outputs (watchdog)
2. Evidence verification: `bash .claude/hooks/verify-evidence.sh < agent-report.txt`
   IF invalid references → send agent back
3. Pre-merge audit (if cross-audit enabled): `bash .claude/hooks/pre-merge-audit.sh <worktree>`
   IF BLOCK → do not merge. IF PASS/WARN → proceed.
4. Resolve file conflicts (budget 30-45% wave time for overlap)
5. API signature audit: grep old signature across full codebase. Missing updates → fix.
6. Run full test suite
7. Quick sanity scan: broken imports, removed deps, deleted function refs. NOT deep review.
8. COMMIT (mandatory before next wave)
9. Update TRACKING.md (triggers wave-review hook — reviews the committed merge diff)
10. Launch next wave (agents fork from committed state)

### Decision Framework

**Early completion:**
```
IF agent PASS with AC evidence -> merge immediately, don't wait
ELIF WARN -> coordinator fixes during wait
ELIF FAIL -> re-launch with feedback while others run
```

**Course correction (act immediately):**
- Agent asks question -> answer (agent is blocked)
- Agent STATUS: FAIL -> assess re-launch vs wave abort
- Agent touches file outside preflight -> flag
- Agent wrong approach -> correct
- Two agents conflict on shared state -> pause both, resolve

**Pre-merge BLOCK:**
```
IF factual bug -> do not merge, re-launch
ELIF severity dispute -> merge with WARN, track for Close Gate
ELIF false positive -> merge, document in commit message
```

**Agent SLA:**
- Running 3x longer than peers -> check, consider terminating
- Same error 3+ times -> terminate, investigate manually
- Partial completion -> merge completed items, reassign rest

### Review Layers

| Layer | When | Checks | Depth |
|-------|------|--------|-------|
| Evidence verification | Between waves | file:line refs valid | Automated |
| Pre-merge audit | Between waves | Code quality pre-merge | Medium, per-agent |
| Coordinator between-wave | After each wave | Tests pass, imports resolve | Surface |
| Per-item audit | Close Gate Wave 2 | Failure modes, fitness | Deep, per-item |
| Cross-cut review | Close Gate Wave 2 | API consistency, types, style | Deep, cross-item |
| sprint-audit.sh | Close Gate Wave 1 | Orphan IDs, format, policy | Automated |
| Sprint Close step 6 | Sprint Close | Cross-reference integrity | Automated |

---

## 6. Close Gate -- Parallel Pattern

Phase -1 sequential: `git checkout sprint-N-impl` + state recovery (TRACKING.md + Entry Gate).

### Wave 1 -- Automated Checks (parallel)

| Agent | Task | Output |
|-------|------|--------|
| A | `sprint-audit.sh` | Exit code + findings |
| B-N | Per-item metric verification | PASS/FAIL/DEFERRED/MISSING per metric |

Coordinator merge: compile metric table -> review audit findings -> present to user.

### Wave 2 -- Per-Item Audit (parallel)

| Agent | Task |
|-------|------|
| Per-item (1-2 items) | Phase 1b: failure modes vs implementation + Phase 1c: fitness review |
| Cross-cut (1 agent) | Full sprint diff: API consistency, type alignment, style, interactions |

Coordinator merge (sequential): Phase 2 fix -> Phase 3 regression test -> Phase 4 coverage -> verdict.

---

## 7. Sprint Close

NOT parallelized. Mostly shared-file writes (TRACKING.md, Roadmap.md, CLAUDE.md). Run sequentially.

---

## 8. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Same-file edits | Shared File Registry pre-launch |
| Guardrail ignorance | Preflight packet includes relevant rules |
| Cross-item inconsistency | Two-layer: coordinator surface check + Close Gate cross-cut deep review |
| Agent off-track | Watchdog pattern |
| Stale agent context | Coordinator provides previous wave summary |
| Race on shared files | Only coordinator writes TRACKING/Roadmap/CLAUDE |
| Incomplete API updates | Preflight item 6 + post-wave signature audit |
| Cross-wave state loss | Inter-wave commit mandatory |
| Merge overhead | Group 2+ overlapping files same agent; budget 30-45% wave time |
| Agent scope too wide | Max 2-3 items per agent |

---

## Quick Reference

```
ENTRY GATE
  Phase 0 --- sequential (coordinator + user)
  Wave 1  --- parallel: state review, roadmap, sanity, API verify
  Merge   --- 30-line summary -> user decisions
  Wave 2  --- parallel: per-item alignment + failure modes + metrics
  Merge   --- steps 10-12 -> report -> user approval

IMPLEMENTATION (sprint-N-impl branch)
  PRE-LAUNCH CHECKLIST (every wave)
  Wave N  --- parallel: agents run full A-E loop (max 2-3 items/agent)
  Between --- verify-evidence -> pre-merge-audit -> merge -> test -> COMMIT
  Wave N+1 -- checklist -> launch (forks from committed state)

CLOSE GATE (sprint-N-impl branch)
  Phase -1 -- sequential (checkout + state recovery)
  Wave 1   -- parallel: sprint-audit.sh + per-item metrics
  Merge    -- metric table + audit summary -> user
  Wave 2   -- parallel: per-item FM/fitness + cross-cut review
  Merge    -- fix -> test -> coverage -> verdict

MERGE: checkout main -> merge --squash sprint-N-impl -> commit -> delete branch

SPRINT CLOSE: sequential (coordinator only, on main)
```

**CRITICAL: Commit after EVERY wave before launching next. Uncommitted work is invisible to worktree-based agents.**
**CRITICAL: Max 2-3 items per agent. 4+ items degrades quality.**
**CRITICAL: Coordinator greps ALL callers for API signature changes. Do NOT delegate caller discovery to agents.**

</instructions>
