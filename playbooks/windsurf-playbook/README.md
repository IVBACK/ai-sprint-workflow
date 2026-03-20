# Windsurf Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [Windsurf](https://windsurf.com) (Cascade).

> **Common setup steps** (bootstrap, rule content, prompts, sprint tools, hook equivalents): see [AGENT-SETUP.md](../../Docs/Workflow/AGENT-SETUP.md).
> This playbook covers Windsurf-specific differences only.

## Setup

### 1. Bootstrap

In Windsurf Cascade chat, paste:

```
Read WORKFLOW.md and bootstrap this project.
```

Cascade has full codebase awareness — it indexes your project automatically.

> Skip Step 8.5 (`.claude/` hooks) — use `.windsurf/rules/` instead.

### 2. Create Windsurf Rules

Create `.windsurf/rules/workflow.md` with the rule content from [AGENT-SETUP.md §2](../../Docs/Workflow/AGENT-SETUP.md#2-rule-file-content).

> **Legacy note:** `.windsurfrules` (single file in root) still works but is legacy. Use `.windsurf/rules/` for the current format.

### 3. Hook Enforcement (Native)

Windsurf supports hooks natively (12 events, `.windsurf/hooks.json`). Pre-hooks can block actions via exit code 2. Enterprise deployment via Cloud Dashboard or MDM. This project does not yet provide Windsurf hook scripts — [contributions welcome](../../CONTRIBUTING.md).

## Windsurf-Specific Tips

1. **Auto-memories complement the workflow.** Cascade can autonomously store and recall context across sessions (toggle in Windsurf settings). This works alongside `CLAUDE.md` and `TRACKING.md`.

2. **Use Flows for gate operations.** Cascade Flows maintain context across multiple steps. Start a new Flow for Entry Gate and another for Close Gate.

3. **Full codebase awareness.** No need for `@workspace` or `#file:` prefixes — Cascade indexes everything by default.

4. **Parallel sessions.** Windsurf supports parallel Cascade sessions in separate git worktrees (Wave 13+).

## Known Limitations

- Windsurf supports hooks natively but this project does not yet provide Windsurf-specific hook scripts
- No background agents — Cascade runs in foreground only
- Flow context can become stale in very long sessions
