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
- `fixed → verified` transition requires evidence (test output or pass confirmation). Full flow: open → in_progress → fixed → verified.
- Check `Docs/CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Roadmap checkbox `[x]` only when item is `verified` in TRACKING.md. `[~]` only when `deferred`.
- Close Gate is user-initiated only. AI never asks "shall we close the sprint?" unprompted.
- Sprint close gate: Run `Tools/sprint-audit.sh` (automated scan).
- Session boundaries: at known heavy-context transition points (after Entry Gate, before Close Gate), AI MUST explicitly recommend starting a new session.
- All code, comments in English.
- Commit policy: atomic commits preferred, free-form messages.

## Last Checkpoint

- Date: 2025-01-15
- Active focus: Sprint 1 — TODO API CRUD + persistence
- Status: Bootstrap complete, ready for Entry Gate
- Next step: Open Sprint 1

## Quick Start

New session sequence:
1. `TRACKING.md` → Current Focus + Sprint Board + Blockers
2. `Docs/Planning/Roadmap.md` → active sprint section
→ Then tell the AI: **"Continue sprint N"** or **"Resume"**

Sprint start (new sprint transition):
- `Docs/SPRINT_WORKFLOW.md` §Entry Gate (phases 0-3, 12 steps)

Sprint close:
- `Docs/SPRINT_WORKFLOW.md` §Close Gate (5 phases) + §Sprint Close

Before writing code:
- `Docs/CODING_GUARDRAILS.md` → Section Index → relevant sections only
