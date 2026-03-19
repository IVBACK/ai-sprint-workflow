# Todo API — Tracking

## Working Context

Task: —
Doing: —
Decisions: —
Blockers: —

## Current Focus

Sprint 1: Core CRUD API with persistence, validation, and pagination (COMPLETE)

## Sprint Board

| ID | Summary | Status | Sprint | Evidence |
|----|---------|--------|--------|----------|
| CORE-001 | CRUD endpoints (GET/POST/PUT/DELETE /api/todos) | verified | S1 | 12/12 endpoint tests pass |
| CORE-002 | SQLite persistence (better-sqlite3, WAL mode) | verified | S1 | DB read/write tests pass, WAL confirmed |
| CORE-003 | Input validation (title required, max 200 chars) | verified | S1 | 8/8 validation tests pass |
| CORE-004 | Pagination (limit/offset, default 20) | verified | S1 | 6/6 pagination tests pass |

## Open Risks / Blockers

| ID | Risk | Mitigation | Sprint |
|----|------|------------|--------|

## Predicted Failure Modes — Current Sprint

| Item | Category | Predicted Mode | Detection Plan |
|------|----------|---------------|----------------|
| CORE-001 | direct | Wrong HTTP status codes for edge cases | Test each status code explicitly |
| CORE-002 | direct | DB lock under concurrent access | Stress test with parallel writes |
| CORE-002 | interaction | Schema migration breaks existing data | Test with pre-populated DB file |
| CORE-003 | direct | Validation bypass via extra fields | Fuzz with unexpected payloads |
| CORE-003 | interaction | Validation errors not in envelope format | Assert error responses match `{ data, error, meta }` |
| CORE-004 | stress-edge | Large offset causes slow query | Test with 10k rows, measure response time |

## Failure Mode History

| Sprint | Category | Predicted? | Detection | Mode | Impact | Root Cause | Guardrail | Escalate? |
|--------|----------|------------|-----------|------|--------|------------|-----------|-----------|
| S1 | db-lock:SQLite | Yes (CORE-002 direct) | test | WAL mode not enabled, concurrent writes fail | Medium — data loss on parallel requests | Default journal mode is DELETE, not WAL | G-SQL: Enable WAL mode at DB init | No |

## Failure Encounters — Current Sprint

| Item | Category | Failure Description | Detection | Date |
|------|----------|-------------------|-----------|------|
| CORE-002 | direct | SQLite default journal mode caused SQLITE_BUSY on concurrent writes. Fixed by enabling WAL mode at connection init. | test | 2025-01-16 |

## Performance Baseline Log

| Sprint | Metric | Value | Unit | Method |
|--------|-----------------|-------|------|----------------|
| S1 | GET /api/todos p95 | 12 | ms | autocannon 10s burst |
| S1 | POST /api/todos p95 | 18 | ms | autocannon 10s burst |
| S1 | test count | 26 | count | jest --verbose |
| S1 | test pass rate | 100 | % | jest exit code 0 |

## Retroactive Audits

| Audit # | Target Sprint | Status | Trigger | Classification | Resolution | Closed |
|---------|--------------|--------|---------|----------------|------------|--------|

## Dismissed Signals

| Date | Checkpoint | System / Metric | Signal Summary | User Decision | Dismissal # | Suppressed? | Revisit Sprint |
|------|-----------|----------------|---------------|---------------|-------------|-------------|----------------|

## Session Notes

| # | Type | Item | Note | Time |
|---|------|------|------|------|

## Change Log

### Sprint 1

- [2025-01-15] Bootstrap: CLAUDE.md, TRACKING.md, Roadmap.md, CODING_GUARDRAILS.md created from skeleton templates.
- [2025-01-15] Entry Gate: Sprint 1 plan confirmed. 3 Must + 1 Should. Implementation order: CORE-002 -> CORE-001 -> CORE-003 -> CORE-004. S1_ENTRY_GATE.md written.
- [2025-01-15] CORE-002: in_progress — SQLite schema + connection setup.
- [2025-01-16] CORE-002: fixed — persistence layer complete. Encountered SQLITE_BUSY under concurrent writes; enabled WAL mode to resolve.
- [2025-01-16] CORE-002: verified — 4/4 DB tests pass, WAL mode confirmed via PRAGMA check.
- [2025-01-16] CORE-001: in_progress — CRUD route handlers.
- [2025-01-16] CORE-001: fixed — all endpoints return correct status codes + envelope.
- [2025-01-16] CORE-001: verified — 12/12 endpoint tests pass.
- [2025-01-16] CORE-003: in_progress — request validation middleware.
- [2025-01-16] CORE-003: fixed — title required, max 200 chars, unknown fields stripped.
- [2025-01-16] CORE-003: verified — 8/8 validation tests pass (including envelope format for errors).
- [2025-01-17] CORE-004: in_progress — pagination query params.
- [2025-01-17] CORE-004: fixed — limit/offset with defaults (20/0), meta.total in response.
- [2025-01-17] CORE-004: verified — 6/6 pagination tests pass (including 10k row stress check < 50ms).
- [2025-01-17] Close Gate: sprint-audit.sh clean (16/16 sections). Manual spec-driven audit passed. Verdict: PASS.
- [2025-01-17] Sprint Close: retrospective written, baselines recorded, branch squash-merged to main, S1_CLOSE_GATE.md archived.
