# Todo API — Roadmap

## Sprint Overview

| Sprint | Focus | Dependencies | Status |
|--------|-------|-------------|--------|
| S1 | Core CRUD + persistence + validation | — | done |
| S2 | Auth + filtering + rate limiting | S1 | planned |

---

## Sprint 1 — Core API Foundation

**Goal:** Deliver a working Todo CRUD API with persistent storage, input validation, and pagination.

**Must:**
- [x] CORE-001 CRUD endpoints (GET/POST/PUT/DELETE /api/todos)
- [x] CORE-002 SQLite persistence (better-sqlite3, WAL mode)
- [x] CORE-003 Input validation (title required, max 200 chars)

**Should:**
- [x] CORE-004 Pagination (limit/offset, default 20)

**Could:**
(none planned)

**Metric gates:**
- All tests pass: 26/26 (jest exit code 0)
- GET p95 < 50ms: actual 12ms
- POST p95 < 100ms: actual 18ms

**Dependencies:** none

---

## Sprint 2 — Auth & Filtering (sketch)

**Goal:** Add API key authentication, todo filtering by status, and basic rate limiting.

**Must:**
- [ ] AUTH-001 API key middleware
- [ ] FILT-001 Filter by status (completed/pending)
- [ ] RATE-001 Rate limiting (100 req/min per key)

**Should:**
- [ ] FILT-002 Search by title substring

**Could:**
- [ ] AUDIT-001 Request logging to SQLite

**Metric gates:**
- All tests pass (jest exit code 0)
- Auth overhead < 5ms p95

**Dependencies:** S1 complete
