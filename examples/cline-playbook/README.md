# Cline Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [Cline](https://cline.bot).

## Status: Community-tested patterns

These are practical adaptation patterns. PRs with confirmed test results are welcome.

## Setup

### 1. Bootstrap

In Cline chat, paste:

```
Read WORKFLOW.md and bootstrap this project.
```

Cline will read the file and run the bootstrap procedure. It can create files,
run terminal commands, and manage the full setup.

> **Note:** Skip step 8.5 (`.claude/` hooks) — those are Claude Code-specific.
> Use `.clinerules` for equivalent enforcement (see below).

### 2. Create `.clinerules`

Cline reads `.clinerules` at the project root (or `.clinerules/*.md` as a directory
of rule files) automatically at the start of every task.

> **Note:** The old "Custom Instructions" text box in Cline settings is deprecated.
> Use `.clinerules` files instead — they're version-controllable and shareable.

Create `.clinerules` in your project root:

```markdown
# AI Sprint Workflow — Cline Rules

## Session Start Protocol
At the start of every task:
1. Read CLAUDE.md — check Project Summary, Immutable Contracts, Last Checkpoint
2. Read TRACKING.md — check Current Focus, Sprint Board, Open Risks
3. Read the active sprint section from Docs/Planning/Roadmap.md
4. State what sprint you're in and what items are in progress

## Protected Files
- NEVER overwrite CLAUDE.md entirely. Edit specific sections only.
- NEVER modify Docs/SPRINT_WORKFLOW.md without explicit user permission.

## Status Tracking
- Update TRACKING.md after every significant fix or decision
- Valid statuses: open, in_progress, fixed, verified, deferred, blocked
- fixed → verified requires evidence (test file:line or confirmation)
- deferred requires reason + target sprint

## Sprint Flow
- After completing Entry Gate: recommend starting a new task for implementation
- Close Gate is user-initiated only. Never suggest closing unprompted.
- Run Tools/sprint-audit.sh at Close Gate Phase 1a

## Before Writing Code
- Check Docs/CODING_GUARDRAILS.md for relevant sections
- Follow Immutable Contracts in CLAUDE.md — never change without revision procedure
```

**Directory format:** For larger projects, use `.clinerules/` as a directory:
```
.clinerules/
├── workflow.md        # Sprint workflow rules (above)
├── guardrails.md      # Project-specific forbidden patterns
└── conventions.md     # Code style and naming rules
```

All `.md` files in the directory are loaded automatically.

### 3. Cline Prompts

**Starting a sprint:**
```
Open Sprint N for [description]. Read Docs/SPRINT_WORKFLOW.md Entry Gate
section and run the full procedure (phases 0-3, 12 steps). Present the
gate assessment before writing any code.
```

**Continuing work:**
```
Resume Sprint N. Read TRACKING.md first, then continue implementing
the next open item in dependency order.
```

**Closing a sprint:**
```
Close Sprint N. Read Docs/SPRINT_WORKFLOW.md Close Gate section.
Start with Phase −1 (state recovery) — read TRACKING.md and the
Entry Gate report before making any assessments.
```

**Running audit:**
```
Run Tools/sprint-audit.sh and show the results.
```

## Hook Equivalents

| Claude Code Hook | Cline Equivalent |
|-----------------|-----------------|
| `protect-claude.sh` | `.clinerules`: "NEVER overwrite CLAUDE.md" |
| `validate-tracking.sh` | `.clinerules`: status validation rules |
| `session-start.sh` | `.clinerules`: session start protocol (reads CLAUDE.md + TRACKING.md) |
| `validate-id-uniqueness.sh` | `sprint-audit.sh` Section 11 at Close Gate |
| `entry-gate-session.sh` | `.clinerules`: recommend new task after Entry Gate |
| `detect-test-regression.sh` | Cline: run tests after each item |
| `validate-close-gate.sh` | Manual: follow Close Gate checklist |
| `validate-sprint-close.sh` | Manual: follow Sprint Close checklist |
| `detect-audit-signals.sh` | Manual: check §Performance Baseline Log at Entry Gate |

**Key difference:** Claude Code hooks run automatically on every tool call.
Cline rules are instructions loaded at task start — they depend on the model's
compliance rather than mechanical enforcement.

## Cline-Specific Strengths

1. **Tool use by default.** Cline can read files, write files, run terminal
   commands, and browse the web. Entry Gate and Close Gate procedures work
   naturally without special setup.

2. **Approval workflow.** Cline asks for user approval before file writes
   and terminal commands. This provides a natural checkpoint that complements
   the sprint workflow's gate system.

3. **Task-scoped context.** Each Cline task starts with `.clinerules` loaded
   fresh. This aligns well with the workflow's session boundary recommendations.

4. **Multi-model support.** Cline works with Claude, GPT, Gemini, and local
   models. The workflow is model-agnostic — any model that follows markdown
   instructions will work.

## Tips

1. **Use task boundaries as session boundaries.** Start a new Cline task
   after Entry Gate and before Close Gate. This keeps context clean.

2. **Pin CLAUDE.md at task start.** If Cline doesn't auto-read CLAUDE.md
   (model-dependent), include "Read CLAUDE.md first" in your opening message.

3. **Keep TRACKING.md concise.** Archive older sprint sections per the
   workflow spec to stay within context limits.

4. **Use auto-approve for implementation loop.** During the implementation
   loop (steps A-E), Cline's auto-approve mode can speed up the code → test
   → verify cycle. Disable it during gate operations for careful review.

## Known Limitations

- No mechanical hook enforcement (rules are advisory, not blocking)
- Rules are not hot-reloaded mid-task — changes take effect on next task
- Context can accumulate in long tasks — break gate operations into
  separate tasks
- Model compliance varies — Claude models follow complex multi-step
  instructions more reliably than smaller models
