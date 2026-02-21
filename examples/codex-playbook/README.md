# OpenAI Codex CLI Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [OpenAI Codex CLI](https://github.com/openai/codex).

## Status: Community-tested patterns

These are practical adaptation patterns. PRs with confirmed test results are welcome.

## Setup

### 1. Configure Codex to read `CLAUDE.md`

Codex CLI reads `AGENTS.md` by default, but can be configured to read `CLAUDE.md`
as a fallback. Add to `~/.codex/config.toml` (or `$CODEX_HOME/config.toml`):

```toml
project_doc_fallback_filenames = ["CLAUDE.md"]
```

With this config, Codex automatically reads `CLAUDE.md` at session start —
no separate `AGENTS.md` file needed. The workflow's `CLAUDE.md` (with Project Summary,
Immutable Contracts, Last Checkpoint) becomes Codex's project context directly.

> **Alternative:** If you prefer the Codex-native approach, create `AGENTS.md`
> alongside `CLAUDE.md` and reference it (see Step 2 alternative below).

### 2. Bootstrap

In Codex CLI, run:

```
Read WORKFLOW.md and bootstrap this project.
```

Codex will create the same file structure as any other agent:
`CLAUDE.md`, `TRACKING.md`, `Docs/`, `Tools/`.

> **Note:** Skip step 8.5 (`.claude/` hooks) — those are Claude Code-specific.

### 3. Create `AGENTS.md` (optional)

If you want Codex-native instructions alongside `CLAUDE.md`, create `AGENTS.md`
at the project root. This file handles sprint workflow rules while `CLAUDE.md`
handles project context.

```markdown
# AI Sprint Workflow — Codex Rules

## Session Start Protocol
At the start of every session:
1. CLAUDE.md is already loaded (via fallback config) — check Last Checkpoint
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

**Size limit:** 32 KiB combined across all loaded instruction files (configurable
via `project_doc_max_bytes` in `config.toml`).

### 4. Codex Prompts

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

## Hook Equivalents

| Claude Code Hook | Codex Equivalent |
|-----------------|-----------------|
| `protect-claude.sh` | `AGENTS.md` rule: "NEVER overwrite CLAUDE.md" |
| `validate-tracking.sh` | `AGENTS.md` rule: status validation |
| `session-start.sh` | Automatic: `CLAUDE.md` loaded via fallback config |
| `validate-id-uniqueness.sh` | `sprint-audit.sh` Section 11 at Close Gate |
| `entry-gate-session.sh` | `AGENTS.md` rule: new session after Entry Gate |
| `detect-test-regression.sh` | Manual: run tests after each item |
| `validate-close-gate.sh` | Manual: Close Gate checklist |
| `validate-sprint-close.sh` | Manual: Sprint Close checklist |
| `detect-audit-signals.sh` | Manual: check baselines at Entry Gate |

## Codex-Specific Strengths

1. **Direct `CLAUDE.md` support.** With one config line, Codex reads `CLAUDE.md`
   natively — no translation layer or separate rule file needed.

2. **Directory-scoped overrides.** `AGENTS.override.md` in subdirectories can
   override parent rules for specific subsystems (e.g., different guardrails
   for frontend vs backend).

3. **Sandbox execution.** Codex runs commands in a sandbox by default,
   providing safe execution for `sprint-audit.sh` and test runs.

4. **Full autonomy mode.** Codex's `full-auto` mode can handle the
   implementation loop (A→E per item) without interruption.

## Tips

1. **Use the fallback config.** `project_doc_fallback_filenames = ["CLAUDE.md"]`
   is the simplest setup — it makes `CLAUDE.md` work as-is without creating
   a separate `AGENTS.md`.

2. **Use `/init` to scaffold.** Codex's `/init` command generates a starter
   `AGENTS.md` — customize it with the sprint workflow rules above.

3. **Keep combined size under 32 KiB.** `CLAUDE.md` + `AGENTS.md` + any
   subdirectory files must fit within the limit. Archive older sprint sections.

4. **Restart sessions at gate boundaries.** Start a new Codex session
   after Entry Gate and before Close Gate.

## Known Limitations

- No mechanical hook enforcement (instructions are advisory)
- 32 KiB combined limit on instruction files (configurable but still bounded)
- Codex loads instructions once per session — mid-session `CLAUDE.md` updates
  require a session restart to take effect
- Sandbox restrictions may affect some `sprint-audit.sh` operations
