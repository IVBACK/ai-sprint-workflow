# Windsurf Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [Windsurf](https://windsurf.com) (Cascade).

## Status: Community-tested patterns

These are practical adaptation patterns. PRs with confirmed test results are welcome.

## Setup

### 1. Bootstrap

In Windsurf Cascade chat, paste:

```
Read WORKFLOW.md and bootstrap this project.
```

Cascade has full codebase awareness — it will index your project automatically.

> **Note:** Skip step 8.5 (`.claude/` hooks) — those are Claude Code-specific.
> Use `.windsurf/rules/` for equivalent enforcement (see below).

### 2. Create Windsurf Rules

Windsurf uses `.windsurf/rules/*.md` files for persistent workspace rules.
Rules are auto-discovered from the `.windsurf/rules/` directory.

> **Legacy note:** `.windsurfrules` (single file in project root) still works but is legacy.
> Migrate to `.windsurf/rules/` for the current format.

Create `.windsurf/rules/workflow.md`:

```markdown
# AI Sprint Workflow — Windsurf Rules

## Session Start Protocol
At the start of every Cascade session:
1. Read CLAUDE.md — check Project Summary, Immutable Contracts, Last Checkpoint
2. Read TRACKING.md — check Current Focus, Sprint Board, Open Risks
3. Read the active sprint section from Docs/Planning/Roadmap.md
4. State what sprint you're in and what items are in progress

## Protected Files
- NEVER overwrite CLAUDE.md. Edit specific sections only.
- NEVER modify Docs/SPRINT_WORKFLOW.md without explicit user permission.

## Status Tracking
- Update TRACKING.md after every significant fix or decision
- Valid statuses: open, in_progress, fixed, verified, deferred, blocked
- fixed → verified requires evidence (test file:line or confirmation)
- deferred requires reason + target sprint

## Sprint Flow
- After completing Entry Gate: recommend starting a new Cascade session
- Close Gate is user-initiated only. Never suggest closing unprompted.
- Run Tools/sprint-audit.sh at Close Gate Phase 1a

## Before Writing Code
- Check Docs/CODING_GUARDRAILS.md for relevant sections
- Follow Immutable Contracts in CLAUDE.md
```

**Rule file limit:** 6,000 characters per file, 12,000 total combined (global + workspace).

### 3. Cascade Prompts

Cascade excels at multi-file operations. Use these prompts:

**Starting a sprint:**
```
Open Sprint N for [description]. Read Docs/SPRINT_WORKFLOW.md Entry Gate
section and run the full procedure (phases 0-3, 12 steps). Present the
gate assessment before writing any code.
```

**Continuing work:**
```
Resume Sprint N. Read TRACKING.md first, then continue implementing
the next open item in dependency order from the Entry Gate report.
```

**Closing a sprint:**
```
Close Sprint N. Read Docs/SPRINT_WORKFLOW.md Close Gate section.
Start with Phase −1 (state recovery) — read TRACKING.md and the
Entry Gate report before making any assessments.
```

## Hook Equivalents

| Claude Code Hook | Windsurf Equivalent |
|-----------------|---------------------|
| `protect-claude.sh` | Rule: "NEVER overwrite CLAUDE.md" |
| `validate-tracking.sh` | Rule: status validation |
| `session-start.sh` | Rule: session start protocol (reads CLAUDE.md + TRACKING.md) |
| `validate-id-uniqueness.sh` | `sprint-audit.sh` Section 11 at Close Gate |
| `entry-gate-session.sh` | Rule: new session after Entry Gate |
| `detect-test-regression.sh` | Cascade: run tests after each item |
| `validate-close-gate.sh` | Manual: Close Gate checklist |
| `validate-sprint-close.sh` | Manual: Sprint Close checklist |
| `detect-audit-signals.sh` | Manual: check baselines at Entry Gate |

## Cascade-Specific Strengths

1. **Full codebase awareness.** Cascade indexes the entire project by default.
   No need for `@workspace` or `#file:` prefixes.

2. **Multi-step flows.** Cascade handles the implementation loop (A→E per item)
   well because it maintains longer context within a single flow.

3. **Tool use.** Cascade can read files, write files, and run terminal commands.
   Entry Gate and Close Gate procedures work naturally.

4. **Auto-memories.** Cascade can autonomously store and recall important context
   across sessions (toggle in Windsurf settings). This complements the explicit
   context in `CLAUDE.md` and `TRACKING.md`.

## Tips

1. **Use Flows for gate operations.** Cascade Flows maintain context across
   multiple steps. Start a new Flow for Entry Gate and another for Close Gate.

2. **Restart Cascade at gate boundaries.** Start fresh after Entry Gate and
   before Close Gate to avoid context pollution.

3. **Keep TRACKING.md concise.** Cascade reads full files — a 200-line
   TRACKING.md is fine, but archive older sections per the workflow spec.

4. **Use write mode for implementation.** Cascade's write mode handles
   the code → test → verify loop efficiently.

## Known Limitations

- No mechanical hook enforcement (rules are advisory)
- Cascade may occasionally skip steps in complex procedures — break into
  phases and verify each phase completed
- Flow context can become stale in very long sessions
- Rule file limit: 6,000 chars/file, 12,000 total
