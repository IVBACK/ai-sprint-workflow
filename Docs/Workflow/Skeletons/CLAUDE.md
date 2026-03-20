# [Project Name] — AI Session Context

This file provides quick context for every AI session.

## Document Contract

- `TRACKING.md` (or `TRACKING-[name].md` if team — see [TEAM-GUIDE.md](Docs/Workflow/TEAM-GUIDE.md)): single source of truth for item status (ID-###, open/in_progress/fixed/verified; special: deferred, blocked).
- `Docs/Planning/Roadmap.md`: sprint plan (Must/Should/Could per sprint).
- `Docs/CODING_GUARDRAILS.md`: engineering rules (check before writing code).
- `Docs/Workflow/ENTRY-GATE.md`: Entry Gate — read at sprint start.
- `Docs/Workflow/IMPL-LOOP.md`: Implementation Loop — read when writing code.
- `Docs/Workflow/CLOSE-GATE.md`: Close Gate — read at sprint end.
- `Docs/Workflow/SPRINT-CLOSE.md`: Sprint Close — read after close gate verdict.
- `Docs/Workflow/PROCEDURES.md`: scope change, abort, audit — read when needed.
- `Docs/Workflow/AGENT-RULES.md`: agent operational rules — read every session.
- `Docs/SPRINT-INDEX.md`: cross-sprint topic-first lookup (read at Entry Gate step 9a, updated at Sprint Close step 7b).
- `Docs/Workflow/PARALLEL-EXECUTION.md`: parallel wave execution patterns (optional — loaded when user triggers parallel mode at Entry Gate step 11).
- `Docs/Workflow/TEAM-GUIDE.md`: team topologies, cross-sprint dependencies, PR integration, CI/CD (team only — skip if solo).
- `Docs/Workflow/UNITY-GUIDE.md`: Unity-specific git, LFS, scene ownership rules (Unity projects only — skip otherwise).
- `CLAUDE.md` (this file): operational rules + checkpoint summary.

Rule: Bug and sprint status is NOT duplicated here; only short references.

## Project Summary

[REQUIRED: One paragraph describing language, framework, architecture, target platform, key goals]
VCS: [REQUIRED: git | svn | none]
Critical Axis: [REQUIRED: security | performance | reliability | correctness | other: ...]
Team: [REQUIRED: solo | names — e.g., "Dev-A, Dev-B"]

## Immutable Contracts

[REQUIRED: List things that MUST NOT change without explicit architectural revision]
- [REQUIRED: Data format, API contract, Convention, Build target...]

## Operational Rules

- Use `sprint-tools item` for status transitions (NOT manual TRACKING edit). See §Available Tools.
- `fixed → verified` transition requires evidence (test output or pass confirmation). Full flow: open → in_progress → fixed → verified.
- Check `Docs/CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Roadmap checkbox `[x]` only when item is `verified` in TRACKING.md. `[~]` only when `deferred`. Intermediate states (in_progress, fixed-untested) are not shown in roadmap — TRACKING.md is the single source. `sprint-audit.sh` Section 11 catches mismatches automatically.
- Close Gate is user-initiated only. AI never asks "shall we close the sprint?" unprompted.
  Reading all items as `verified` in TRACKING.md is not a trigger — it is just state.
- Sprint close gate:
  - Run `Tools/sprint-audit.sh` (automated scan, 17 sections).
  - Manual review (see `Docs/CODING_GUARDRAILS.md` §Close Gate).
- Session boundaries: at known heavy-context transition points (after Entry Gate, before Close Gate),
  AI MUST explicitly recommend starting a new session. AI cannot assess its own context usage —
  this recommendation is mandatory, not optional. User decides whether to follow it.
- All code, comments in [REQUIRED: English | language].
- Commit policy (if VCS in use): sprint branch (`sprint-N-impl` solo / `sprint-N-name-impl` team), commit after each item's D.7, squash merge to main after Close Gate (solo: local merge, team: PR-based merge — see [TEAM-GUIDE.md](Docs/Workflow/TEAM-GUIDE.md) §Pull Request Integration). Commit style: [REQUIRED: conventional | free-form]. Commit messages in [REQUIRED: English | language]. If VCS=none: skip.

## Last Checkpoint

- Date: [REQUIRED]
- Active focus: [REQUIRED]
- Status: [REQUIRED]
- Next step: [REQUIRED]

## Available Tools

CRITICAL: This section MUST be included in CLAUDE.md during bootstrap. Do not omit — without it, the AI will not know sprint-tools exist and will manually edit files instead.

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
  sprint-tools migrate        — upgrade from older workflow version (v2.x → v3.x)
```

## Quick Start

New session sequence:
1. Read `Docs/Workflow/AGENT-RULES.md` — your operational rules (tool usage, context loading, Working Context)
2. If `Team:` lists multiple names → ask: "Which team member are you?" to determine which
   `TRACKING-[name].md` to read. Solo → read `TRACKING.md` directly.
3. Read your TRACKING file → Current Focus + Sprint Board + Working Context + Blockers
4. `Docs/Planning/Roadmap.md` → active sprint section
→ Then tell the AI: **"Continue sprint N"** or **"Resume"** — AI runs Session Start Protocol automatically.

Sprint start (new sprint transition):
- `Docs/Workflow/ENTRY-GATE.md` (phases 0-3, 12 steps) — read and execute. No code before plan is confirmed.

Implementation:
- `Docs/Workflow/IMPL-LOOP.md` — read and execute. Use sprint-tools for status transitions (see §Available Tools).

Sprint close:
- `Docs/Workflow/CLOSE-GATE.md` (phases 0-4) — read and execute.
- `Docs/Workflow/SPRINT-CLOSE.md` — finalize after close gate verdict.

Before writing code:
- `Docs/CODING_GUARDRAILS.md` → Section Index → relevant sections only
