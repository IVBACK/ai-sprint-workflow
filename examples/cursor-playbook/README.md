# Cursor Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [Cursor](https://cursor.com).

## Status: Community-tested patterns

These are practical adaptation patterns. PRs with confirmed test results are welcome.

## Setup

### 1. Bootstrap

In Cursor chat (Cmd+L), paste:

```
Read WORKFLOW.md and bootstrap this project.
```

Cursor will create the same file structure as any other agent:
`CLAUDE.md`, `TRACKING.md`, `Docs/`, `Tools/`.

> **Note:** Skip step 8.5 (`.claude/` hooks) — those are Claude Code-specific.
> Use `.cursor/rules/` for equivalent enforcement (see below).

### 2. Create Cursor Rules

Cursor uses `.cursor/rules/*.mdc` files for persistent project instructions.
Each rule file has YAML frontmatter controlling when it loads.

> **Legacy note:** `.cursorrules` (single file in project root) still works but is deprecated.
> Migrate to `.cursor/rules/` for granular control.

Create `.cursor/rules/workflow.mdc`:

```
---
description: AI Sprint Workflow rules
alwaysApply: true
---

# AI Sprint Workflow — Cursor Rules

## Session Start Protocol
At the start of every session:
1. Read CLAUDE.md — check Project Summary, Immutable Contracts, Last Checkpoint
2. Read TRACKING.md — check Current Focus, Sprint Board, Open Risks
3. Read the active sprint section from Docs/Planning/Roadmap.md
4. State what sprint you're in and what items are in progress

## File Protection
- NEVER overwrite CLAUDE.md. Use Edit to append or modify sections.
- NEVER modify Docs/SPRINT_WORKFLOW.md without explicit user permission.

## Status Tracking
- Update TRACKING.md after every significant fix or decision
- Valid statuses: open, in_progress, fixed, verified, deferred, blocked
- fixed → verified requires evidence (test file:line or run confirmation)
- deferred requires reason + target sprint

## Sprint Boundaries
- After completing Entry Gate: recommend starting a new session for implementation
- Close Gate is user-initiated only. Never ask "shall we close?" unprompted
- Run Tools/sprint-audit.sh at Close Gate Phase 1a

## Code Rules
- Check Docs/CODING_GUARDRAILS.md before writing new code
- Follow Immutable Contracts in CLAUDE.md — never change without revision procedure
```

**Why `alwaysApply: true`?** This injects the rules into every conversation automatically — equivalent to how Claude Code auto-reads `CLAUDE.md`. Without it, the AI only loads the rule when it deems relevant.

**Rule file limit:** 6,000 characters per `.mdc` file. The workflow rules above fit within this limit. If you need more (e.g., adding guardrail patterns), split into multiple rule files.

### 3. Workflow-aware prompts

Use these prompts in Cursor Agent mode (Cmd+I) for multi-file operations:

**Starting a sprint:**
```
Open Sprint N for [description]. Follow the Entry Gate procedure in
Docs/SPRINT_WORKFLOW.md — phases 0-3, 12 steps. Do not write code
until the gate is approved.
```

**Continuing work:**
```
Resume Sprint N. Read TRACKING.md first, then continue with the next
open item in dependency order.
```

**Closing a sprint:**
```
Close Sprint N. Follow Close Gate in Docs/SPRINT_WORKFLOW.md —
Phase −1 through verdict. Run sprint-audit.sh first.
```

## Hook Equivalents

| Claude Code Hook | Cursor Equivalent |
|-----------------|-------------------|
| `protect-claude.sh` | Rule: "NEVER overwrite CLAUDE.md" |
| `validate-tracking.sh` | Rule: status validation |
| `session-start.sh` | Rule: session start protocol (reads CLAUDE.md + TRACKING.md) |
| `validate-id-uniqueness.sh` | `sprint-audit.sh` Section 11 catches orphans at Close Gate |
| `entry-gate-session.sh` | Rule: recommend new session after Entry Gate |
| `detect-test-regression.sh` | Manual: run tests after each item, check for regressions |
| `validate-close-gate.sh` | Manual: follow Close Gate checklist in SPRINT_WORKFLOW.md |
| `validate-sprint-close.sh` | Manual: follow Sprint Close checklist in SPRINT_WORKFLOW.md |
| `detect-audit-signals.sh` | Manual: check §Performance Baseline Log at Entry Gate |

**Key difference:** Claude Code hooks run automatically on every tool call.
Cursor rules are instructions the AI follows — they depend on the model's
compliance rather than mechanical enforcement.

## Tips

1. **Use Agent mode for multi-file operations.** Entry Gate and Sprint Close
   touch multiple files. Agent mode handles this better than inline chat.

2. **Pin TRACKING.md as context.** Use `@TRACKING.md` in your prompts to
   ensure the AI always has current sprint state.

3. **Add guardrail patterns as a separate rule.** Create `.cursor/rules/guardrails.mdc`
   with `alwaysApply: true` for project-specific forbidden patterns from
   `CODING_GUARDRAILS.md`.

4. **Restart session at gate boundaries.** Cursor chat accumulates context
   quickly. Start a fresh chat after Entry Gate and before Close Gate.

## Known Limitations

- No mechanical hook enforcement (rules are advisory, not blocking)
- Cursor may not read long files completely — keep TRACKING.md concise
- Agent mode context window is smaller than Claude Code's — break large
  operations into smaller steps
- Rule file limit: 6,000 characters per `.mdc` file
