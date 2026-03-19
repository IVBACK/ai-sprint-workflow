# Demo: Todo API — Sprint 1 Complete

This is an end-to-end walkthrough of the AI Sprint Workflow (v3.1) showing the **final state** after completing Sprint 1. All files represent what your project looks like when a sprint is done.

## What This Demonstrates

A solo developer uses the workflow to build a Todo API (TypeScript/Express/SQLite) across one sprint. The sprint covers 4 items: CRUD endpoints, SQLite persistence, input validation, and pagination. One real failure is encountered (SQLite WAL mode) and handled through the workflow's failure tracking system.

## Timeline

| Phase | Date | What happened | Files affected |
|-------|------|---------------|----------------|
| Bootstrap | 2025-01-15 | Project scanned, files created | CLAUDE.md, TRACKING.md, Roadmap.md, CODING_GUARDRAILS.md |
| Entry Gate | 2025-01-15 | Sprint plan reviewed, failure modes analyzed | S1_ENTRY_GATE.md, TRACKING.md |
| Implementation | 2025-01-15-17 | 4 items implemented and tested | TRACKING.md |
| Close Gate | 2025-01-17 | Automated + manual audit passed | S1_CLOSE_GATE.md, TRACKING.md |
| Sprint Close | 2025-01-17 | Retrospective, baseline, archive | SPRINT_CLOSE_REPORT.md, CLAUDE.md, Roadmap.md, TRACKING.md |

## File Guide

| File | Purpose |
|------|---------|
| `CLAUDE.md` | AI session context — project summary, rules, last checkpoint |
| `TRACKING.md` | Single source of truth — item statuses, failure log, baselines, change log |
| `Roadmap.md` | Sprint plan with priorities and metric gates |
| `CODING_GUARDRAILS.md` | Engineering rules the AI checks before writing code |
| `S1_ENTRY_GATE.md` | Entry gate report — failure mode analysis, implementation order |
| `S1_CLOSE_GATE.md` | Close gate report — audit results, metric verification, verdict |
| `SPRINT_CLOSE_REPORT.md` | User handoff — before/after per item, retrospective, baselines |

## Important Notes

**Gate report retention:** In a real project, `S1_ENTRY_GATE.md` is deleted at Sprint Close (TRACKING.md's gate log section is the permanent record). It is kept here for demonstration purposes so you can see what an entry gate report looks like.

**Flat structure:** These files live in a single directory — the same structure your project will have. There are no stage subfolders. A real project has these files at the repository root (or in the configured docs directory), alongside your source code.

## How to Use This Example

1. Read the files in timeline order (Bootstrap -> Entry Gate -> Close Gate -> Sprint Close) to understand the workflow progression.
2. Notice how TRACKING.md's Change Log tells the full story of the sprint.
3. See how a failure (SQLite WAL mode) flows through the system: Failure Encounters -> Failure Mode History -> Guardrail added -> CODING_GUARDRAILS.md updated.
4. Compare the Entry Gate's predicted failure modes against the Sprint Close retrospective.

For the full workflow documentation, see the `Docs/Workflow/` directory in the main repository.
