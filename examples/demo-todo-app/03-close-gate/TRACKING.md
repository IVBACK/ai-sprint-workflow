# TODO API — Tracking

## Current Focus
Sprint 1: Basic TODO API with CRUD operations and persistent storage — Close Gate passed

## Sprint Board

| ID | Summary | Status | Sprint | Evidence |
|----|---------|--------|--------|----------|
| CORE-001 | Project setup + Express server scaffold | fixed | S1 | tests/health.test.ts:12 |
| CORE-002 | SQLite database layer with migrations | fixed | S1 | tests/database.test.ts:8 |
| CORE-003 | CRUD endpoints (GET/POST/PUT/DELETE) | fixed | S1 | tests/todos.test.ts:15 |
| CORE-004 | Input validation + error handling | fixed | S1 | tests/validation.test.ts:10 |
| CORE-005 | Pagination for GET /todos | fixed | S1 | tests/pagination.test.ts:8 |
| CORE-006 | Filter by completion status | fixed | S1 | tests/filter.test.ts:9 |

## Open Risks / Blockers

| ID | Risk | Mitigation | Sprint |
|----|------|------------|--------|

## Predicted Failure Modes — Current Sprint

| Item | Category | Predicted Mode | Detection Plan |
|------|----------|---------------|----------------|
| CORE-001 | Direct | Server fails to start on occupied port | Test: start server, check response |
| CORE-001 | Stress | Concurrent requests during startup | Test: rapid requests after server.listen |
| CORE-002 | Direct | Schema migration fails silently | Test: verify table structure after init |
| CORE-002 | Interaction | Database locked during concurrent writes | Test: parallel insert operations |
| CORE-002 | Stress | Large dataset degrades query performance | Manual: benchmark with 10K rows |
| CORE-003 | Direct | DELETE returns 200 for non-existent ID | Test: delete with invalid ID → 404 |
| CORE-003 | Interaction | Create + immediate read returns stale data | Test: POST then GET same ID |
| CORE-003 | Direct | PUT with partial body clears unset fields | Test: PUT with only title → completed unchanged |
| CORE-004 | Direct | Missing title field accepted | Test: POST without title → 400 |
| CORE-004 | Direct | Malformed JSON body returns 500 instead of 400 | Test: send invalid JSON → 400 |
| CORE-004 | Interaction | Validation error leaks internal stack trace | Test: check error response has no stack |
| CORE-005 | Direct | Page 0 or negative page crashes | Test: page=0 → 400 or default to 1 |
| CORE-005 | Stress | limit=999999 returns all rows (no server cap) | Test: verify server-side max limit |
| CORE-006 | Direct | completed=invalid accepted as valid filter | Test: completed=banana → 400 |

## Failure Mode History

| Sprint | Category | Predicted? | Detection | Mode | Impact | Root Cause | Guardrail | Escalate? |
|--------|----------|------------|-----------|------|--------|------------|-----------|-----------|

## Failure Encounters — Current Sprint

| Item | Category | Failure Description | Detection | Date |
|------|----------|-------------------|-----------|------|
| CORE-004 | direct | Malformed JSON body returned 500 with stack trace instead of 400 | test | 2025-01-16 |

## Performance Baseline Log

| Sprint | Metric | Value | Unit | Method |
|--------|--------|-------|------|--------|

## Change Log

### Sprint 1
- 2025-01-15 Bootstrap complete
- 2025-01-15 Entry Gate: phases 0-3 ✓
- 2025-01-16 CORE-001 through CORE-006: implemented and tested (18/18 tests pass)
- 2025-01-16 Close Gate Phase -1: complete — 4 Must, 2 Should, 6 metrics listed
- 2025-01-16 Close Gate Phase 0: complete — 6/6 metrics PASS
- 2025-01-16 Close Gate Phase 1a: complete — sprint-audit.sh ran (2 findings, resolved)
- 2025-01-16 Close Gate Phase 1b: complete — all failure modes HANDLED
- 2025-01-16 Close Gate Phase 2: complete — 3 findings fixed, 0 deferred
- 2025-01-16 Close Gate Phase 3: complete — 18/18 tests PASS
- 2025-01-16 Close Gate Phase 4: complete — no coverage gaps
- 2025-01-16 Close Gate verdict: PASSED — user approved
