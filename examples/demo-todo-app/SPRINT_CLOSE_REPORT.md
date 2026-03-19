# Sprint 1 — Close Report

**Sprint Close:** 2025-01-17, steps 1-11 complete.

## User Handoff

### CORE-001: CRUD Endpoints
- **Before:** No API routes existed.
- **After:** GET/POST/PUT/DELETE on `/api/todos` with full envelope responses.
- **Where:** `src/routes/todos.ts`, `src/controllers/todoController.ts`
- **Verify:** `npm test -- --testPathPattern=todos.test`

### CORE-002: SQLite Persistence
- **Before:** No data storage.
- **After:** SQLite via better-sqlite3 with WAL mode, schema auto-creation on startup.
- **Where:** `src/db/database.ts`, `src/db/schema.sql`
- **Verify:** `npm test -- --testPathPattern=database.test`

### CORE-003: Input Validation
- **Before:** Raw request bodies accepted without checks.
- **After:** Title required (1-200 chars), unknown fields stripped, errors returned in envelope format.
- **Where:** `src/middleware/validate.ts`
- **Verify:** `npm test -- --testPathPattern=validate.test`

### CORE-004: Pagination
- **Before:** GET /api/todos returned all rows.
- **After:** `?limit=N&offset=N` support (default 20/0), `meta.total` in response.
- **Where:** `src/routes/todos.ts` (query param handling), `src/db/database.ts` (COUNT query)
- **Verify:** `npm test -- --testPathPattern=pagination.test`

## Failure Mode Retrospective

| Item | Predicted Mode | Occurred? | Actual Outcome |
|------|---------------|-----------|----------------|
| CORE-002 direct: DB lock | Yes | **Yes** | SQLITE_BUSY on concurrent writes. Fixed by enabling WAL mode. |
| CORE-002 direct: Schema fails silently | Yes | No | Schema creation verified by assertion test. |
| CORE-002 interaction: Migration breaks data | Yes | No | N/A — first sprint, no existing data. |
| CORE-001 direct: Wrong status codes | Yes | No | All codes correct on first pass. |
| CORE-003 direct: Validation bypass | Yes | No | Extra fields stripped by middleware. |
| CORE-003 interaction: Error not in envelope | Yes | No | Error middleware returns envelope. |
| CORE-004 stress-edge: Slow large offset | Yes | No | 10k row test completed in < 50ms. |

**Hit rate:** 1 predicted failure occurred out of 7 predicted (CORE-002 DB lock).
**Unpredicted failures:** 0.

## Performance Baseline

| Metric | Value | Unit | Method |
|--------|-------|------|--------|
| GET /api/todos p95 | 12 | ms | autocannon 10s burst |
| POST /api/todos p95 | 18 | ms | autocannon 10s burst |
| Test count | 26 | count | jest --verbose |
| Test pass rate | 100 | % | jest exit code 0 |

## Guardrail Added

- **G-SQL:** "Enable WAL mode at DB init" — added to CODING_GUARDRAILS.md after CORE-002 failure encounter.

## Git

- Sprint branch `sprint-1-impl` squash-merged to `main`.
- 4 commits (one per item) squashed into single merge commit.
