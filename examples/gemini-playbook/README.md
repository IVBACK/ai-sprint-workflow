# Gemini CLI Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [Gemini CLI](https://github.com/google-gemini/gemini-cli).

## Status: Community-tested patterns

These are practical adaptation patterns. PRs with confirmed test results are welcome.

## Setup

### 1. Configure Gemini to read `CLAUDE.md`

Gemini CLI reads `GEMINI.md` by default, but can be configured to recognize
additional filenames. Add to your Gemini CLI `settings.json`:

```json
{
  "context": {
    "fileName": ["GEMINI.md", "CLAUDE.md"]
  }
}
```

With this config, Gemini automatically reads `CLAUDE.md` at session start
and discovers it dynamically (JIT) as it accesses new directories.

> **Alternative:** Use `@import` syntax in `GEMINI.md` to reference `CLAUDE.md`
> (see Step 3 below).

### 2. Bootstrap

In Gemini CLI, run:

```
Read WORKFLOW.md and bootstrap this project.
```

Gemini will create the same file structure as any other agent:
`CLAUDE.md`, `TRACKING.md`, `Docs/`, `Tools/`.

> **Note:** Skip step 8.5 (`.claude/` hooks) — those are Claude Code-specific.

### 3. Create `GEMINI.md` (optional)

If you want Gemini-native instructions alongside `CLAUDE.md`, create `GEMINI.md`
at the project root. You can use `@import` to include `CLAUDE.md` directly:

```markdown
# AI Sprint Workflow — Gemini Rules

@./CLAUDE.md

## Session Start Protocol
At the start of every session:
1. CLAUDE.md is loaded above — check Project Summary, Immutable Contracts, Last Checkpoint
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
- After completing Entry Gate: recommend starting a new session
- Close Gate is user-initiated only. Never suggest closing unprompted.
- Run Tools/sprint-audit.sh at Close Gate Phase 1a

## Before Writing Code
- Check Docs/CODING_GUARDRAILS.md for relevant sections
- Follow Immutable Contracts in CLAUDE.md — never change without revision procedure
```

The `@./CLAUDE.md` import brings in the full project context without duplication.
When `CLAUDE.md` is updated (e.g., Last Checkpoint at Sprint Close), Gemini
picks up the change automatically via JIT re-discovery.

### 4. Gemini Prompts

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

**Checking loaded context:**
```
/memory show
```

## Hook Equivalents

| Claude Code Hook | Gemini Equivalent |
|-----------------|------------------|
| `protect-claude.sh` | `GEMINI.md` rule: "NEVER overwrite CLAUDE.md" |
| `validate-tracking.sh` | `GEMINI.md` rule: status validation |
| `session-start.sh` | Automatic: `CLAUDE.md` loaded via config or `@import` |
| `validate-id-uniqueness.sh` | `sprint-audit.sh` Section 11 at Close Gate |
| `entry-gate-session.sh` | `GEMINI.md` rule: new session after Entry Gate |
| `detect-test-regression.sh` | Manual: run tests after each item |
| `validate-close-gate.sh` | Manual: Close Gate checklist |
| `validate-sprint-close.sh` | Manual: Sprint Close checklist |
| `detect-audit-signals.sh` | Manual: check baselines at Entry Gate |

## Gemini-Specific Strengths

1. **`@import` syntax.** `@./CLAUDE.md` in `GEMINI.md` includes the full project
   context without copying. Updates to `CLAUDE.md` flow through automatically.

2. **JIT discovery.** Gemini dynamically discovers `GEMINI.md` files in directories
   as it accesses them during work. Subdirectory-specific rules activate automatically.

3. **`/memory` commands.** `/memory show` displays all loaded context,
   `/memory refresh` forces a re-scan, `/memory add` appends to global rules.

4. **Large context window.** Gemini models support up to 1M+ tokens, so
   `CLAUDE.md` + `TRACKING.md` + `CODING_GUARDRAILS.md` all fit comfortably.

5. **Global rules.** `~/.gemini/GEMINI.md` provides default sprint workflow rules
   across all projects without per-project setup.

## Tips

1. **Use `@import` for zero duplication.** Rather than copying `CLAUDE.md`
   content into `GEMINI.md`, import it. One source of truth, always current.

2. **Use `/memory show` to verify context.** Check that `CLAUDE.md` and
   `GEMINI.md` are both loaded before starting sprint operations.

3. **Use `/memory refresh` after gate operations.** Sprint Close updates
   `CLAUDE.md` Last Checkpoint — refresh to ensure Gemini sees the change
   without restarting the session.

4. **Use global `GEMINI.md` for shared rules.** If you use the sprint workflow
   across multiple projects, put the Session Start Protocol in
   `~/.gemini/GEMINI.md` and keep only project-specific rules local.

## Known Limitations

- No mechanical hook enforcement (rules are advisory)
- `@import` paths must be relative or absolute — no glob patterns
- JIT discovery relies on Gemini accessing the directory — rules in
  untouched directories won't load until referenced
- No documented size limit, but extremely large context files may
  affect response quality
