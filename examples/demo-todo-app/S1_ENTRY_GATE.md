# Sprint 1 — Entry Gate Report

**Date:** 2025-01-15
**Sprint Goal:** Deliver a working Todo CRUD API with persistent storage, input validation, and pagination.

## Phase 0 — Pre-check

- Previous sprint: N/A (first sprint)
- Deferred items: none
- Performance baselines: none (first sprint)

## Phase 1 — Sprint Board

| ID | Summary | Priority | Effort Est. |
|----|---------|----------|-------------|
| CORE-002 | SQLite persistence (better-sqlite3, WAL mode) | Must | M |
| CORE-001 | CRUD endpoints (GET/POST/PUT/DELETE /api/todos) | Must | M |
| CORE-003 | Input validation (title required, max 200 chars) | Must | S |
| CORE-004 | Pagination (limit/offset, default 20) | Should | S |

**Implementation Order:** CORE-002 -> CORE-001 -> CORE-003 -> CORE-004
**Rationale:** Persistence first (CORE-001 depends on it). Validation and pagination layer on top of working endpoints.

## Phase 2 — Failure Mode Analysis

### CORE-002: SQLite persistence
| Category | Predicted Mode | Detection Plan |
|----------|---------------|----------------|
| direct | Schema creation fails silently | Assert table exists after init |
| direct | DB lock under concurrent access | Stress test with parallel writes |
| interaction | Schema migration breaks existing data | Test with pre-populated DB file |

### CORE-001: CRUD endpoints
| Category | Predicted Mode | Detection Plan |
|----------|---------------|----------------|
| direct | Wrong HTTP status codes for edge cases (e.g., DELETE nonexistent) | Test each status code explicitly |
| direct | PUT partial update overwrites unset fields with null | Test partial vs. full update |
| interaction | Endpoint returns raw data, not envelope | Assert `{ data, error, meta }` shape in every test |

### CORE-003: Input validation
| Category | Predicted Mode | Detection Plan |
|----------|---------------|----------------|
| direct | Validation bypass via extra fields | Fuzz with unexpected payloads |
| interaction | Validation errors not in envelope format | Assert error responses match `{ data, error, meta }` |
| stress-edge | Very long title (10k chars) causes memory spike | Test with boundary input, measure response time |

### CORE-004: Pagination
| Category | Predicted Mode | Detection Plan |
|----------|---------------|----------------|
| direct | Negative offset/limit not rejected | Test with -1 values |
| stress-edge | Large offset causes slow query on big table | Test with 10k rows, measure response time |
| interaction | meta.total missing or incorrect after filtering | Verify total count matches DB row count |

## Phase 3 — Metric Gates

| Metric | Target | Method |
|--------|--------|--------|
| Test pass rate | 100% | jest exit code 0 |
| GET /api/todos p95 | < 50ms | autocannon 10s burst |
| POST /api/todos p95 | < 100ms | autocannon 10s burst |

## AI Assessment

- **Scope:** 4 items (3 Must + 1 Should) is well-sized for a 2-day sprint.
- **Risk:** CORE-002 concurrent access is the highest-risk area. WAL mode should mitigate, but stress tests are essential.
- **Dependencies:** CORE-001 depends on CORE-002; no circular dependencies.
- **Confidence:** High — well-understood stack, clear acceptance criteria.
