# Todo API — Coding Guardrails

## Section Index

| ID | Rule | Scope |
|----|------|-------|
| G-ENV | Response Envelope | All endpoints |
| G-ERR | Error Handling | All routes, middleware |
| G-SQL | SQL Safety | All DB queries |
| G-TYPE | Type Strictness | All TypeScript files |

---

## G-ENV: Response Envelope

All HTTP responses MUST use the standard envelope:

```typescript
interface ApiResponse<T> {
  data: T | null;
  error: string | null;
  meta: Record<string, unknown>;
}
```

- Success: `{ data: <payload>, error: null, meta: { ... } }`
- Error: `{ data: null, error: "<message>", meta: {} }`
- Never return raw arrays or bare objects.

**Why:** Consistent parsing for all consumers. Prevents client-side type guessing.

---

## G-ERR: Error Handling

- Express error middleware catches all thrown/next(err) errors.
- Never expose stack traces in production (`NODE_ENV !== 'development'`).
- Use HTTP status codes correctly: 400 (validation), 404 (not found), 500 (server error).
- Always return error in envelope format (see G-ENV).

**Why:** Unhandled errors leak internals. Envelope consistency means clients handle errors uniformly.

---

## G-SQL: SQL Safety

- Use parameterized queries for ALL user input. Never interpolate strings into SQL.
- Enable WAL mode at database initialization: `PRAGMA journal_mode=WAL`.
- Wrap multi-statement writes in explicit transactions.
- Schema changes require a migration file (not inline ALTER).

**Why:** SQL injection is the #1 API vulnerability. WAL prevents SQLITE_BUSY under concurrent reads/writes (discovered Sprint 1, CORE-002).

---

## G-TYPE: Type Strictness

- `strict: true` in tsconfig.json (includes noImplicitAny, strictNullChecks).
- No `any` type — use `unknown` + type guards when type is genuinely unknown.
- Define interfaces for all request bodies and DB row shapes.
- Prefer `readonly` for data that should not be mutated after creation.

**Why:** TypeScript's value is in its type system. Loose types defeat the purpose and hide bugs at compile time.

---

## Close Gate Checklist

Before sprint close, manually verify:
1. All responses conform to G-ENV envelope (spot-check 3 endpoints).
2. No raw SQL string concatenation in codebase (search: `db.exec(`).
3. `tsconfig.json` has `strict: true`.
4. Error middleware returns envelope format for 400, 404, 500.
