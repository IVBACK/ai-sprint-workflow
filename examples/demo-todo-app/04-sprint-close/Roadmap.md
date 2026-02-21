# TODO API — Roadmap

## Sprint Overview

| Sprint | Theme | Status |
|--------|-------|--------|
| S1 | Basic CRUD API + persistence | Complete ✓ |
| S2 | Authentication + authorization | Planned (sketch) |
| S3 | Bulk operations + search | Planned (sketch) |

## Sprint 1 — Basic TODO API

**Goal:** Functional REST API with CRUD operations and persistent SQLite storage.

### Must

- [x] CORE-001: Project setup + Express server scaffold
  - **Metric:** Server starts and responds to GET /health with `{ success: true }`

- [x] CORE-002: SQLite database layer with migrations
  - **Metric:** Database file created, schema matches contract, migrations run idempotently

- [x] CORE-003: CRUD endpoints (GET/POST/PUT/DELETE /todos)
  - **Metric:** Each endpoint returns correct status code and response format per contract

- [x] CORE-004: Input validation + error handling
  - **Metric:** Invalid input returns 400 with descriptive error; malformed JSON returns 400 (not 500)

### Should

- [x] CORE-005: Pagination for GET /todos
  - **Metric:** Pagination returns correct subset; out-of-range page returns empty data (not error)

- [x] CORE-006: Filter by completion status
  - **Metric:** Filter returns only matching items; invalid filter value returns 400

## Sprint 2 — Authentication (sketch)

JWT-based auth, user registration/login, todo ownership

## Sprint 3 — Bulk Operations (sketch)

Batch create/update/delete, full-text search on todo titles
