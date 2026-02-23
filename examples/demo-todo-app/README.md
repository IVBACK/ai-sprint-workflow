# Demo: End-to-End Sprint — TODO API

A complete walkthrough of one sprint cycle using a simple TypeScript/Express
TODO API. Every output file is included so you can see exactly what the
workflow produces at each stage.

## Project Setup

- **Language:** TypeScript
- **Framework:** Express.js
- **Tests:** Jest + Supertest
- **Developer:** Solo + AI agent
- **Critical Axis:** Correctness

## Sprint 1 Goal

> "Build a basic TODO API with CRUD operations and persistent storage."

## Walkthrough

### Stage 0 — Bootstrap

The AI reads `WORKFLOW.md` and runs the 10-step bootstrap.

**Output files:** [`00-bootstrap-output/`](00-bootstrap-output/)

| File | Purpose |
|------|---------|
| [`CLAUDE.md`](00-bootstrap-output/CLAUDE.md) | AI session context |
| [`TRACKING.md`](00-bootstrap-output/TRACKING.md) | Sprint board (empty, pre-Entry Gate) |
| [`CODING_GUARDRAILS.md`](00-bootstrap-output/CODING_GUARDRAILS.md) | Engineering rules |
| [`Roadmap.md`](00-bootstrap-output/Roadmap.md) | Sprint plan with Must/Should/Could |

**What happened:**
1. AI detected greenfield project (no source code)
2. Scanned — no existing configs
3. Asked 15 discovery questions → answers inferred + confirmed
4. Created file structure
5. Ran Initial Planning → Sprint 1 decomposed into 4 Must + 2 Should items
6. Populated CLAUDE.md, scanned codebase for guardrails (stack-specific rules for TypeScript/Express)
7. Adapted sprint-audit.sh for TypeScript

---

### Stage 1 — Entry Gate

The user said: `"Open Sprint 1 for basic TODO API with CRUD and persistence."`

**Output files:** [`01-entry-gate/`](01-entry-gate/)

| File | Purpose |
|------|---------|
| [`S1_ENTRY_GATE.md`](01-entry-gate/S1_ENTRY_GATE.md) | Full Entry Gate report |
| [`TRACKING.md`](01-entry-gate/TRACKING.md) | Sprint board after gate (items = open) |

**What happened:**
1. **Phase 0:** Sprint already detailed in Roadmap → skipped
2. **Phase 1:** No prior sprints → clean state
3. **Phase 2:** Sprint 1 → no dependencies → skipped
4. **Phase 3:**
   - Step 8: All items still relevant → keep
   - Step 9a: Failure modes predicted (direct/interaction/stress per item)
   - Step 9b: Verification plan with specific test scenarios
   - Step 9c: Metrics verified — all measurable, non-trivial
   - Step 10: 4 Must items — within scope limit
5. **Step 12:** AI recommendation: "Gate passed — recommend proceeding"
6. User approved → implementation session recommended

---

### Stage 2 — Implementation

The user said: `"Continue sprint 1"` in a new session.

**Output files:** [`02-implementation/`](02-implementation/)

| File | Purpose |
|------|---------|
| [`TRACKING.md`](02-implementation/TRACKING.md) | Sprint board after implementation (items = fixed) |

**What happened (per item, in dependency order):**

For each Must item (CORE-001 → CORE-004):
1. **A.** Marked `in_progress`, read guardrails
2. **B.** Wrote code following conventions
3. **C.** Self-verify checklist (all 5 points PASS on first round)
4. **D.** Wrote tests matching Entry Gate 9b scenarios
5. **D.6** Ran all tests incrementally — all PASS
6. **E.** Marked `fixed`, logged completion

After all Must items: AI asked "Must items done. Continue with Should/Could?"
→ User chose to continue with Should items → CORE-005 and CORE-006 implemented.

---

### Stage 3 — Close Gate

The user said: `"Close sprint 1"`

**Output files:** [`03-close-gate/`](03-close-gate/)

| File | Purpose |
|------|---------|
| [`CLOSE_GATE_REPORT.md`](03-close-gate/CLOSE_GATE_REPORT.md) | Full Close Gate report |
| [`TRACKING.md`](03-close-gate/TRACKING.md) | Sprint board after Close Gate |

**What happened:**
1. **Phase −1:** State recovery — read TRACKING.md + Entry Gate report. Listed 4 Must + 2 Should items, 6 metrics.
2. **Phase 0:** Metric verification table filled — 6/6 PASS. All tests linked.
3. **Phase 1a:** `sprint-audit.sh` → 2 findings (1 SCAFFOLDING tag, 1 uncached ref). Both fixed.
4. **Phase 1b:** Spec-driven audit per item — all failure modes HANDLED.
5. **Phase 2:** No Critical Axis findings.
6. **Phase 3:** All 18 tests PASS after fixes.
7. **Phase 4:** Coverage gap check — all items have behavioral tests.
8. **Verdict:** "Gate passed — recommend closing sprint." User approved.

---

### Stage 4 — Sprint Close

Ran immediately after Close Gate approval (same session).

**Output files:** [`04-sprint-close/`](04-sprint-close/)

| File | Purpose |
|------|---------|
| [`TRACKING.md`](04-sprint-close/TRACKING.md) | Final state — all items verified |
| [`CLAUDE.md`](04-sprint-close/CLAUDE.md) | Updated checkpoint |
| [`Roadmap.md`](04-sprint-close/Roadmap.md) | Checkmarks applied |
| [`SPRINT_CLOSE_REPORT.md`](04-sprint-close/SPRINT_CLOSE_REPORT.md) | Retrospective + handoff |

**What happened:**
1. Roadmap checkmarks: 6/6 `[x]`
2. TRACKING.md: all items `verified` with evidence
3. CLAUDE.md checkpoint updated
4. Changelog archived
5. Performance baseline: response time 12ms (GET /todos), 15ms (POST)
6. Failure mode retrospective: 1 unpredicted failure (JSON parse error on malformed input) → new guardrail added
7. User handoff: before/after + where to verify for each item

---

## Timeline

```
Session 1:  Bootstrap (10 min)
Session 2:  Entry Gate (15 min)
Session 3:  Implementation — 4 Must + 2 Should items (45 min)
Session 4:  Close Gate + Sprint Close (20 min)
            ─────────────────────────────────
            Total: ~90 min for 1 complete sprint cycle
```

## Key Observations

1. **Context stays small.** CLAUDE.md is ~80 lines. TRACKING.md is ~60 lines at sprint end. AI reads only what's needed per session.

2. **Gates catch real issues.** sprint-audit.sh found a scaffolding tag and an uncached reference that would have shipped otherwise. The spec-driven audit confirmed all failure modes were handled.

3. **Retrospective creates value.** The unpredicted JSON parse failure became a guardrail rule — future sprints won't repeat this mistake.

4. **Overhead is front-loaded.** Bootstrap + first Entry Gate = ~25 min. Subsequent sprints: Entry Gate = ~10 min (state exists, patterns established).
