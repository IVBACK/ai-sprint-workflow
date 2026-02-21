# TODO API — Coding Guardrails

Engineering rules derived from real bugs. Review before writing code.

## Section Index — Read by Task Type

| Task | Read sections |
|------|---------------|
| API endpoint work | §1, §2 |
| Database work | §1, §3 |
| Test writing | §1 |
| Sprint workflow | §Entry Gate, §Close Gate |
| Anti-pattern quick check | §Anti-Pattern Quick Reference |

---

## 1. General TypeScript Rules

### 1.1 Strict null checks

Always enable `strict: true` in tsconfig.json. Never use `as any` or `!` non-null assertions without a comment explaining why.

- **Root cause:** Runtime null/undefined errors in production
- **Scope:** All TypeScript files
- **Reference:** Industry best practice

### 1.2 Error handling

Express route handlers must have try/catch or use an error middleware. Never let unhandled rejections crash the server.

- **Root cause:** Unhandled promise rejections crash Node.js
- **Scope:** All route handlers and async middleware
- **Reference:** Express.js error handling guide

---

## 2. API Design Rules

### 2.1 Response format

All API responses must use the standard format: `{ success: boolean, data?: T, error?: string }`.
Never return raw data without the wrapper.

- **Root cause:** Inconsistent API responses break client integrations
- **Scope:** All route handlers
- **Reference:** CLAUDE.md §Immutable Contracts

### 2.2 HTTP status codes

Use correct status codes: 200 (OK), 201 (Created), 400 (Bad Request), 404 (Not Found), 500 (Internal Error). Never return 200 for errors.

- **Root cause:** Clients can't distinguish success/failure programmatically
- **Scope:** All route handlers
- **Reference:** CLAUDE.md §Immutable Contracts

---

## 3. Database Rules

### 3.1 Parameterized queries

Always use parameterized queries (prepared statements). Never concatenate user input into SQL strings.

- **Root cause:** SQL injection
- **Scope:** All database access code
- **Reference:** OWASP Top 10

### 3.2 Transaction boundaries

Multi-step writes must be wrapped in a transaction. better-sqlite3 supports `db.transaction()`.

- **Root cause:** Partial writes leave database in inconsistent state
- **Scope:** Any operation with 2+ write queries
- **Reference:** Database ACID principles

---

## Entry Gate — Pre-Sprint Review

Before writing code for a new sprint:
- Read `Docs/SPRINT_WORKFLOW.md` §Entry Gate
- Run phases 0-3 for full gate, or abbreviated if ≤3 Must + no deps

## Close Gate — Sprint End Review

- Run `Tools/sprint-audit.sh`
- Read `Docs/SPRINT_WORKFLOW.md` §Close Gate
- Manual review per this file's rules

---

## Anti-Pattern Quick Reference

| # | Anti-Pattern | Correct Approach | Ref |
|---|-------------|-----------------|-----|
| 1 | `as any` type cast | Proper type definition or generic | §1.1 |
| 2 | Raw SQL string concatenation | Parameterized queries | §3.1 |
| 3 | Return raw data without wrapper | Use `{ success, data, error }` format | §2.1 |
| 4 | 200 status for error responses | Use appropriate 4xx/5xx codes | §2.2 |
| 5 | Unhandled async errors in routes | try/catch + error middleware | §1.2 |
