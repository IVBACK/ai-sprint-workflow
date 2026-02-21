# TODO API — Roadmap

## Sprint Overview

| Sprint | Theme | Status |
|--------|-------|--------|
| S1 | Basic CRUD API + persistence | Active |
| S2 | Authentication + authorization | Planned (sketch) |
| S3 | Bulk operations + search | Planned (sketch) |

## Sprint 1 — Basic TODO API

**Goal:** Functional REST API with CRUD operations and persistent SQLite storage.

### Must

- [ ] CORE-001: Project setup + Express server scaffold
  - TypeScript project with tsconfig strict mode, Express server on configurable port
  - **Metric:** Server starts and responds to GET /health with `{ success: true }`

- [ ] CORE-002: SQLite database layer with migrations
  - better-sqlite3 integration, schema creation on first run, connection management
  - **Metric:** Database file created, schema matches contract, migrations run idempotently

- [ ] CORE-003: CRUD endpoints (GET/POST/PUT/DELETE /todos)
  - Full lifecycle: create, read (single + list), update, delete
  - **Metric:** Each endpoint returns correct status code and response format per contract

- [ ] CORE-004: Input validation + error handling
  - Validate required fields (title: non-empty string), reject malformed JSON, global error handler
  - **Metric:** Invalid input returns 400 with descriptive error; malformed JSON returns 400 (not 500)

### Should

- [ ] CORE-005: Pagination for GET /todos
  - `?page=1&limit=10` query params, default limit=20, return total count in response
  - **Metric:** Pagination returns correct subset; out-of-range page returns empty data (not error)

- [ ] CORE-006: Filter by completion status
  - `?completed=true|false` query param on GET /todos
  - **Metric:** Filter returns only matching items; invalid filter value returns 400

### Could

*(No Could items for Sprint 1)*

## Sprint 2 — Authentication (sketch)

JWT-based auth, user registration/login, todo ownership

## Sprint 3 — Bulk Operations (sketch)

Batch create/update/delete, full-text search on todo titles
