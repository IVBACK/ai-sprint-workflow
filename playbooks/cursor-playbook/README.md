# Cursor Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [Cursor](https://cursor.com).

> **Common setup steps** (bootstrap, rule content, prompts, sprint tools, hook equivalents): see [AGENT-SETUP.md](../../Docs/Workflow/AGENT-SETUP.md).
> This playbook covers Cursor-specific differences only.

## Setup

### 1. Bootstrap

In Cursor Agent mode (Cmd+I), paste:

```
Read WORKFLOW.md and bootstrap this project.
```

> Skip Step 8.5 (`.claude/` hooks) — use `.cursor/rules/` instead.

### 2. Create Cursor Rules

Create `.cursor/rules/workflow.mdc` with the rule content from [AGENT-SETUP.md §2](../../Docs/Workflow/AGENT-SETUP.md#2-rule-file-content):

```
---
description: AI Sprint Workflow rules
alwaysApply: true
---

[Paste rule content from AGENT-SETUP.md §2]
```

> **Legacy note:** `.cursorrules` (single file in root) still works but is deprecated. Use `.cursor/rules/` for granular control.

**Why `alwaysApply: true`?** This injects rules into every conversation — equivalent to Claude Code auto-reading `CLAUDE.md`.

For larger projects, split into multiple rule files:
- `.cursor/rules/workflow.mdc` — sprint rules
- `.cursor/rules/guardrails.mdc` — project-specific forbidden patterns from `CODING_GUARDRAILS.md`

### 3. Hook Enforcement (Native)

Cursor supports hooks natively since v1.7. Configure `.cursor/hooks.json` for mechanical enforcement equivalent to Claude Code hooks. This project does not yet provide Cursor hook scripts — [contributions welcome](../../CONTRIBUTING.md).

## Cursor-Specific Tips

1. **Use Agent mode for gate operations.** Entry Gate and Sprint Close touch multiple files. Agent mode handles this better than inline chat.

2. **Pin TRACKING.md as context.** Use `@TRACKING.md` in prompts to ensure current sprint state is always loaded.

3. **Restart session at gate boundaries.** Start a fresh chat after Entry Gate and before Close Gate to avoid context pollution.

4. **Sub-agents.** Cursor supports sub-agents (v2.4+) and background agents. These can parallelize sprint work — see [PARALLEL-EXECUTION.md](../../Docs/Workflow/PARALLEL-EXECUTION.md).

## Known Limitations

- Cursor supports hooks natively but this project does not yet provide Cursor-specific hook scripts
- Agent mode context window is smaller than Claude Code's — break large operations into smaller steps
