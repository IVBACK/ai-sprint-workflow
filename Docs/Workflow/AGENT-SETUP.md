# Agent Setup Guide

Common setup steps for using the AI Sprint Workflow with any agent. Platform-specific details are in [playbooks/](../../playbooks/).

## 1. Bootstrap

Tell your AI agent:

```
Read WORKFLOW.md and bootstrap this project.
```

Bootstrap runs 5 sequential phases (scan → research → plan → review → approve) then creates files. The agent creates: `CLAUDE.md`, `TRACKING.md`, `Docs/Workflow/`, `Docs/Systems/`, `Docs/Planning/`, `Tools/`, and more.

> **Claude Code users:** Hooks are set up automatically at Step 8.5 of bootstrap.
> **Other agents:** Skip Step 8.5 — use your platform's rule/instruction system instead (see your playbook).

## 2. Rule File Content

Whatever your platform calls it (`.cursor/rules/`, `.clinerules/`, `.windsurf/rules/`, `copilot-instructions.md`, `AGENTS.md`, `GEMINI.md`), your rule file should include these sections:

### Session Start Protocol

```
At the start of every session:
1. Read Docs/Workflow/AGENT-RULES.md — operational rules (tool usage, evidence standards, context loading)
2. Read TRACKING.md — Current Focus, Sprint Board, Working Context, Blockers
3. Read the active sprint section from Docs/Planning/Roadmap.md
4. State what sprint you're in and what items are in progress

Alternative: run `sprint-tools state` for a 23-line digest that replaces steps 2-3.
```

### Protected Files

```
- NEVER overwrite CLAUDE.md entirely. Use Edit to modify sections, or use `sprint-tools checkpoint`.
- NEVER modify Docs/Workflow/ files without explicit user permission.
```

### Status Tracking

```
- Use `sprint-tools item ID status` for status transitions (NOT manual TRACKING.md edits)
- Valid statuses: open → in_progress → fixed → verified (also: deferred, blocked)
- fixed → verified requires VERIFIED-level evidence (test output with file:line or run confirmation)
- deferred requires reason + target sprint
```

### Sprint Boundaries

```
- Entry Gate and Close Gate are user-initiated only. Never suggest them unprompted.
- After completing Entry Gate: recommend starting a new session for implementation.
- Gate reports MUST be written to files (Docs/Planning/S<N>_ENTRY_GATE.md, S<N>_CLOSE_GATE.md)
  BEFORE presenting to user — verbal-only is not sufficient.
- Run Tools/sprint-audit.sh at Close Gate Phase 1a.
```

### Code Rules

```
- Read Docs/CODING_GUARDRAILS.md before writing new code
- Follow Immutable Contracts in CLAUDE.md — never change without revision procedure
```

### Working Context

```
- Update TRACKING.md Working Context after every significant decision or fix
- Format: Task / Doing / Decisions / Blockers (4 lines max)
- Use `sprint-tools checkpoint` to update both CLAUDE.md and Working Context together
```

## 3. Sprint Prompts

**Starting a sprint:**
```
Open Sprint N for [description]. Read Docs/Workflow/ENTRY-GATE.md and run
the full procedure. Present the gate assessment before writing any code.
```

**Continuing work:**
```
Resume Sprint N. Read TRACKING.md first, then continue with the next open
item in dependency order.
```

**Closing a sprint:**
```
Close Sprint N. Read Docs/Workflow/CLOSE-GATE.md. Read TRACKING.md and
the Entry Gate report before making any assessments.
```

**Running audit:**
```
Run Tools/sprint-audit.sh and show the results.
```

## 4. Sprint Tools (CLI)

All tools work with any agent that has terminal access. No external dependencies.

### Anytime Commands

| Command | Purpose |
|---|---|
| `sprint-tools state` | Sprint digest (≤23 lines) — replaces manual TRACKING.md reads |
| `sprint-tools note <type> "text"` | Session journal (decision/attempt/observation/side-effect/artifact) |
| `sprint-tools learn "text"` | Classify + route finding (guardrail/index/risk) |
| `sprint-tools review <file>` | Blind review via external LLM |

### Workflow Commands

| Command | Purpose |
|---|---|
| `sprint-tools item ID status` | Status transition + changelog (batch: `ID1,ID2 status`) |
| `sprint-tools checkpoint` | Update CLAUDE.md Last Checkpoint + TRACKING.md Working Context |
| `sprint-tools baseline` | Record performance metric to baseline log |
| `sprint-tools metrics S<N>` | Extract Entry Gate metrics |
| `sprint-tools verify ITEM` | Generate verification checklist for fixed item |
| `sprint-tools close <N>` | Sprint close archive + cleanup |
| `sprint-tools index` | Rebuild SPRINT-INDEX.md |
| `sprint-tools git <cmd>` | Git ceremony wrapper (init/commit/push/merge/abort) |
| `sprint-tools migrate` | Upgrade from older workflow version (v2.x → v3.x) |

Dashboard: `python3 dashboard/sprint-status.py` (CLI summary, `--serve` for web, `-w` for watch mode)

## 5. Hook Equivalents

Claude Code has 14 hooks that mechanically enforce the workflow. Other platforms can approximate these through rules (advisory) or native hooks (if supported).

| Claude Code Hook | What It Does | Rule Equivalent |
|---|---|---|
| `session-start.sh` | Loads TRACKING.md at session start | Rule: session start protocol |
| `memory-sync.sh` | Syncs TRACKING.md at start/stop/compact | Rule: read TRACKING.md first, update at end |
| `protect-claude.sh` | Blocks CLAUDE.md overwrites | Rule: "NEVER overwrite CLAUDE.md" |
| `protect-secrets.sh` | Blocks reading .env/credentials | Rule: "NEVER read or commit secrets" |
| `validate-tracking.sh` | Validates TRACKING.md structure | `sprint-audit.sh` catches structural issues |
| `validate-id-uniqueness.sh` | Catches orphan/duplicate IDs | `sprint-audit.sh` Section 11 |
| `entry-gate-session.sh` | Recommends new session after gate | Rule: recommend new session after Entry Gate |
| `detect-test-regression.sh` | Flags test regressions | Manual: run tests after each item |
| `detect-audit-signals.sh` | Flags metric regressions | Manual: check baselines at Entry Gate |
| `validate-close-gate.sh` | Validates Close Gate report | Manual: follow Close Gate in CLOSE-GATE.md |
| `validate-sprint-close.sh` | Validates Sprint Close | Manual: follow Sprint Close in SPRINT-CLOSE.md |
| `bootstrap-guard.sh` | Enforces bootstrap phase order | Rule: complete each bootstrap phase sequentially |
| `bootstrap-phase-gate.sh` | Validates phase transitions | Rule: do not skip bootstrap phases |
| `cross-llm-audit.sh` | External LLM code review | Manual: use `sprint-tools review` |

## 6. Reference Example

See [examples/demo-todo-app/](../../examples/demo-todo-app/) for a fully worked Sprint 1 showing all artifacts: CLAUDE.md, TRACKING.md, Entry Gate report, Close Gate report, Sprint Close report.
