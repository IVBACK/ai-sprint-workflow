# TODO API — AI Session Context

This file provides quick context for every AI session.

## Document Contract

- `TRACKING.md`: single source of truth for item status (CORE-###, open/in_progress/fixed/verified; special: deferred, blocked).
- `Docs/Planning/Roadmap.md`: sprint plan (Must/Should/Could per sprint).
- `Docs/CODING_GUARDRAILS.md`: engineering rules (check before writing code).
- `Docs/SPRINT_WORKFLOW.md`: sprint lifecycle (Entry Gate, Close Gate, Sprint Close) — read at sprint boundaries.
- `Docs/LESSONS_INDEX.md`: RuleID → root cause → target file mapping.
- `CLAUDE.md` (this file): operational rules + checkpoint summary.

Rule: Bug and sprint status is NOT duplicated here; only short references.

## Project Summary

TypeScript/Express REST API for TODO management. SQLite for persistence via
better-sqlite3. Jest + Supertest for testing. Target: Node.js 20+ on Linux/macOS.
VCS: git
Critical Axis: correctness

## Immutable Contracts

- API response format: `{ success: boolean, data?: T, error?: string }`
- Database schema: `todos(id INTEGER PRIMARY KEY, title TEXT NOT NULL, completed BOOLEAN DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP)`
- HTTP status codes: 200 (success), 201 (created), 400 (bad request), 404 (not found), 500 (server error)

## Operational Rules

- Update `TRACKING.md` after every significant fix/decision.
- `fixed → verified` transition requires evidence (test output or pass confirmation).
- Check `Docs/CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Roadmap checkbox `[x]` only when item is `verified` in TRACKING.md.
- Close Gate is user-initiated only.
- All code, comments in English.
- Commit policy: atomic commits preferred, free-form messages.

## Last Checkpoint

- Date: 2025-01-16
- Active focus: Sprint 1 complete — ready for Sprint 2
- Status: 6/6 items verified, 18 tests passing, 1 new guardrail (G-006)
- Next step: Open Sprint 2 for authentication

## Quick Start

New session sequence:
1. `TRACKING.md` → Current Focus + Sprint Board + Blockers
2. `Docs/Planning/Roadmap.md` → active sprint section
→ Then tell the AI: **"Continue sprint N"** or **"Resume"**
