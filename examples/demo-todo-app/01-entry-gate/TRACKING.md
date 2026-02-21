# TODO API — Tracking

## Current Focus
Sprint 1: Basic TODO API with CRUD operations and persistent storage

## Sprint Board

| ID | Summary | Status | Sprint | Evidence |
|----|---------|--------|--------|----------|
| CORE-001 | Project setup + Express server scaffold | open | S1 | |
| CORE-002 | SQLite database layer with migrations | open | S1 | |
| CORE-003 | CRUD endpoints (GET/POST/PUT/DELETE) | open | S1 | |
| CORE-004 | Input validation + error handling | open | S1 | |
| CORE-005 | Pagination for GET /todos | open | S1 | |
| CORE-006 | Filter by completion status | open | S1 | |

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

## Performance Baseline Log

| Sprint | Metric | Value | Unit | Method |
|--------|--------|-------|------|--------|

## Retroactive Audits

| Audit # | Target Sprint | Status | Trigger | Classification | Resolution | Closed |
|---------|--------------|--------|---------|----------------|------------|--------|

## Dismissed Signals

| Date | Checkpoint | System / Metric | Signal Summary | User Decision | Dismissal # | Suppressed? | Revisit Sprint |
|------|-----------|----------------|---------------|---------------|-------------|-------------|----------------|

## Change Log

### Sprint 1
- 2025-01-15 Bootstrap complete. Files created: CLAUDE.md, TRACKING.md, CODING_GUARDRAILS.md, Roadmap.md, sprint-audit.sh
- 2025-01-15 Entry Gate Phase 1: complete — steps 1-4 executed
- 2025-01-15 Entry Gate Phase 3: complete — steps 8-12 executed
- 2025-01-15 Entry Gate: phases 0-3 ✓ (steps executed: 1,2,3,4,8,9a,9b,9c,10,11,12). Phase 0 skipped (already detailed), Phase 2 skipped (S1, no deps)
- 2025-01-15 Entry Gate report: Docs/Planning/S1_ENTRY_GATE.md
