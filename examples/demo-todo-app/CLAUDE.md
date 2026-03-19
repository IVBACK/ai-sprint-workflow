# Todo API — AI Session Context

This file provides quick context for every AI session.

## Document Contract

- `TRACKING.md`: single source of truth for item status.
- `Roadmap.md`: sprint plan (Must/Should/Could per sprint).
- `CODING_GUARDRAILS.md`: engineering rules (check before writing code).
- `CLAUDE.md` (this file): operational rules + checkpoint summary.

Rule: Bug and sprint status is NOT duplicated here; only short references.

## Project Summary

A RESTful Todo API built with TypeScript, Express, and SQLite. Provides CRUD operations for todo items with input validation, pagination, and persistent storage. Targets Node.js 20+ as a backend service. Key goals: correctness, consistent JSON envelope, zero-downtime data persistence.

VCS: git
Critical Axis: correctness
Team: solo

## Immutable Contracts

- JSON response envelope: `{ data, error, meta }` — all endpoints.
- SQLite as sole storage engine — no ORM, direct `better-sqlite3`.
- REST resource naming: `/api/todos` (plural, lowercase).

## Operational Rules

- Use `sprint-tools item` for status transitions (NOT manual TRACKING edit). See Available Tools.
- `fixed` to `verified` transition requires evidence (test output or pass confirmation). Full flow: open -> in_progress -> fixed -> verified.
- Check `CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Roadmap checkbox `[x]` only when item is `verified` in TRACKING.md. `[~]` only when `deferred`.
- Close Gate is user-initiated only. AI never asks "shall we close the sprint?" unprompted.
- Sprint close gate:
  - Run `Tools/sprint-audit.sh` (automated scan, 16 sections).
  - Manual review (see `CODING_GUARDRAILS.md` Close Gate).
- Session boundaries: at known heavy-context transition points (after Entry Gate, before Close Gate), AI MUST explicitly recommend starting a new session.
- All code, comments in English.
- Commit policy: sprint branch (`sprint-N-impl`), commit after each item's D.7, squash merge to main after Close Gate. Commit style: conventional. Commit messages in English.

## Last Checkpoint

- Date: 2025-01-17
- Active focus: Sprint 1 complete
- Status: All 4 items verified. Close Gate passed. Sprint closed.
- Next step: Ready for Sprint 2 Entry Gate

## Available Tools

```
Anytime:
  sprint-tools state          — sprint digest (items, risks, phase, Working Context)
  sprint-tools note <type> "text" — session journal (decision/attempt/observation/side-effect/artifact)
  sprint-tools learn "text"       — classify + route finding (guardrail/index/risk, --dry-run default)
  sprint-tools review <file>  — blind review via external LLM

Workflow steps:
  sprint-tools item ID[,ID,...] status — status transition + changelog (batch supported)
  sprint-tools checkpoint     — update Last Checkpoint + Working Context
  sprint-tools baseline       — record performance metric
  sprint-tools metrics S<N>   — extract Entry Gate metrics
  sprint-tools close <N>      — sprint close archive + cleanup
  sprint-tools index          — rebuild SPRINT-INDEX.md
  sprint-tools git            — git ceremony (init/commit/push/merge/abort)
  sprint-tools migrate        — upgrade from older workflow version (v2.x -> v3.x)
```

## Quick Start

New session sequence:
1. Read `TRACKING.md` -> Current Focus + Sprint Board + Working Context + Blockers
2. Read `Roadmap.md` -> active sprint section
3. Tell the AI: **"Continue sprint N"** or **"Resume"**
