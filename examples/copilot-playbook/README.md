# GitHub Copilot Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [GitHub Copilot](https://github.com/features/copilot) Chat.

## Status: Community-tested patterns

These are practical adaptation patterns. PRs with confirmed test results are welcome.

## Setup

### 1. Bootstrap

In Copilot Chat (VS Code: Ctrl+Shift+I), paste:

```
@workspace Read WORKFLOW.md and bootstrap this project.
```

The `@workspace` participant ensures Copilot indexes your project files.

> **Note:** Skip step 8.5 (`.claude/` hooks) — those are Claude Code-specific.
> Use `.github/copilot-instructions.md` for equivalent enforcement (see below).

### 2. Create `.github/copilot-instructions.md`

Copilot reads this file automatically for workspace-level custom instructions.
It is injected into every Copilot Chat request — no manual reference needed.

```markdown
# AI Sprint Workflow Instructions

## Session Start
1. Read CLAUDE.md — check Project Summary, Immutable Contracts, Last Checkpoint
2. Read TRACKING.md for current sprint status
3. Read the active sprint section in Docs/Planning/Roadmap.md
4. State what sprint is active and what's in progress

## Protected Files
- Never overwrite CLAUDE.md entirely — only append or edit sections
- Never modify Docs/SPRINT_WORKFLOW.md without user permission

## Status Rules
- Update TRACKING.md after every fix or decision
- Valid statuses: open → in_progress → fixed → verified (also: deferred, blocked)
- verified requires test evidence
- deferred requires reason + target sprint

## Before Writing Code
- Read relevant sections of Docs/CODING_GUARDRAILS.md
- Follow Immutable Contracts in CLAUDE.md

## Sprint Boundaries
- Close Gate is user-initiated only
- After Entry Gate: recommend starting a new chat session
- At Close Gate: run Tools/sprint-audit.sh first
```

**Path-specific instructions:** For file-type-specific rules, create
`.github/instructions/<name>.instructions.md` with an `applyTo` frontmatter
field (e.g., `applyTo: "**/*.ts"`) for glob-scoped instructions.

### 3. Copilot Chat Prompts

**Starting a sprint:**
```
@workspace Open Sprint N for [description]. Read Docs/SPRINT_WORKFLOW.md
Entry Gate section. Run phases 0-3 before writing any code.
```

**Continuing work:**
```
@workspace Resume Sprint N. Check TRACKING.md for current status,
then continue with the next open item.
```

**Closing a sprint:**
```
@workspace Close Sprint N. Run the Close Gate from Docs/SPRINT_WORKFLOW.md.
Start with Phase −1 state recovery.
```

**Running audit:**
```
Run Tools/sprint-audit.sh and show the results.
```

## Hook Equivalents

| Claude Code Hook | Copilot Equivalent |
|-----------------|-------------------|
| `protect-claude.sh` | Instruction rule: "Never overwrite CLAUDE.md" |
| `validate-tracking.sh` | Instruction rule + manual review |
| `session-start.sh` | Instruction: "Read CLAUDE.md + TRACKING.md at session start" |
| `validate-id-uniqueness.sh` | `sprint-audit.sh` Section 11 at Close Gate |
| `entry-gate-session.sh` | Instruction: "Recommend new session after Entry Gate" |
| `detect-test-regression.sh` | Manual: run tests incrementally |
| `validate-close-gate.sh` | Manual: Close Gate checklist |
| `validate-sprint-close.sh` | Manual: Sprint Close checklist |
| `detect-audit-signals.sh` | Manual: review §Performance Baseline Log |

## Tips

1. **Use `@workspace` prefix.** This gives Copilot access to your full project
   context. Without it, Copilot only sees the current file.

2. **Reference files explicitly.** Use `#file:TRACKING.md` or
   `#file:Docs/Planning/Roadmap.md` to ensure Copilot loads specific files.

3. **Break gate operations into steps.** Copilot Chat has a shorter context
   window. Run Entry Gate phases one at a time rather than all at once.

4. **Use inline chat for implementation.** Copilot's inline chat (Ctrl+I)
   works well for the implementation loop (steps A-E per item).

5. **Copilot Edits for multi-file changes.** Use Copilot Edits mode for
   Sprint Close operations that touch multiple files simultaneously.

## Known Limitations

- No mechanical enforcement (instructions are advisory)
- Copilot Chat context is limited — may lose sprint context in long sessions
- `@workspace` indexing may miss deeply nested files
- Multi-file operations are less reliable than single-file edits
- Copilot may not follow complex multi-step procedures consistently
  — break into smaller prompts
