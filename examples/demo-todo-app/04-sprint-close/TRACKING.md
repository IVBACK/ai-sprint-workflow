# TODO API — Tracking

## Current Focus
Sprint 1: Complete ✓ — ready for Sprint 2

## Sprint Board

| ID | Summary | Status | Sprint | Evidence |
|----|---------|--------|--------|----------|
| CORE-001 | Project setup + Express server scaffold | verified | S1 | tests/health.test.ts:12 |
| CORE-002 | SQLite database layer with migrations | verified | S1 | tests/database.test.ts:8-35 |
| CORE-003 | CRUD endpoints (GET/POST/PUT/DELETE) | verified | S1 | tests/todos.test.ts:15-89 |
| CORE-004 | Input validation + error handling | verified | S1 | tests/validation.test.ts:10-52 |
| CORE-005 | Pagination for GET /todos | verified | S1 | tests/pagination.test.ts:8-41 |
| CORE-006 | Filter by completion status | verified | S1 | tests/filter.test.ts:9-38 |

## Open Risks / Blockers

| ID | Risk | Mitigation | Sprint |
|----|------|------------|--------|

## Predicted Failure Modes — Current Sprint

| Item | Category | Predicted Mode | Detection Plan |
|------|----------|---------------|----------------|

*(Cleared at Sprint Close — next sprint's Entry Gate writes new predictions)*

## Failure Mode History

| Sprint | Category | Predicted? | Detection | Mode | Impact | Root Cause | Guardrail | Escalate? |
|--------|----------|------------|-----------|------|--------|------------|-----------|-----------|
| S1 | direct:validation | yes | test | Malformed JSON → 500 with stack trace | medium | Express default error handler | G-006 | no |

## Failure Encounters — Current Sprint

| Item | Category | Failure Description | Detection | Date |
|------|----------|-------------------|-----------|------|

*(Cleared at Sprint Close)*

## Performance Baseline Log

| Sprint | Metric | Value | Unit | Method |
|--------|--------|-------|------|--------|
| S1 | GET /todos (empty) | 3 | ms | Supertest |
| S1 | GET /todos (100 items) | 12 | ms | Supertest |
| S1 | POST /todos | 15 | ms | Supertest |
| S1 | DB init | 8 | ms | Jest timer |

## Retroactive Audits

| Audit # | Target Sprint | Status | Trigger | Classification | Resolution | Closed |
|---------|--------------|--------|---------|----------------|------------|--------|

## Dismissed Signals

| Date | Checkpoint | System / Metric | Signal Summary | User Decision | Dismissal # | Suppressed? | Revisit Sprint |
|------|-----------|----------------|---------------|---------------|-------------|-------------|----------------|

## Change Log

### Sprint 1
- 2025-01-15 Bootstrap complete
- 2025-01-15 Entry Gate: phases 0-3 ✓
- 2025-01-16 CORE-001 through CORE-006: implemented and tested (18/18 tests pass)
- 2025-01-16 Close Gate: PASSED — 6/6 metrics PASS, 3 findings fixed
- 2025-01-16 Sprint Close: complete — Sprint 1
