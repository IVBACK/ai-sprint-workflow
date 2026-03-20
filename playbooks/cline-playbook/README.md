# Cline Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [Cline](https://cline.bot).

> **Common setup steps** (bootstrap, rule content, prompts, sprint tools, hook equivalents): see [AGENT-SETUP.md](../../Docs/Workflow/AGENT-SETUP.md).
> This playbook covers Cline-specific differences only.

## Setup

### 1. Bootstrap

In Cline chat, paste:

```
Read WORKFLOW.md and bootstrap this project.
```

Cline can create files, run terminal commands, and manage the full setup.

> Skip Step 8.5 (`.claude/` hooks) — use `.clinerules/` instead.

### 2. Create Cline Rules

Create `.clinerules` in your project root (or `.clinerules/workflow.md` as a directory) with the rule content from [AGENT-SETUP.md §2](../../Docs/Workflow/AGENT-SETUP.md#2-rule-file-content).

> **Note:** The old "Custom Instructions" text box in Cline settings is deprecated. Use `.clinerules` files — they're version-controllable and shareable.

**Directory format** for larger projects:
```
.clinerules/
├── workflow.md        # Sprint workflow rules
├── guardrails.md      # Project-specific forbidden patterns
└── conventions.md     # Code style and naming rules
```

Cline also auto-detects `.cursorrules`, `.windsurfrules`, and `AGENTS.md`.

### 3. Hook Enforcement (Native)

Cline supports hooks natively since v3.36 (8 events). Hooks return JSON with `{"cancel": true}` to block actions. This project does not yet provide Cline hook scripts — [contributions welcome](../../CONTRIBUTING.md).

## Cline-Specific Tips

1. **Approval workflow is a natural checkpoint.** Cline asks for user approval before file writes and terminal commands — this complements the workflow's gate system.

2. **Use task boundaries as session boundaries.** Start a new Cline task after Entry Gate and before Close Gate.

3. **Sub-agents (read-only).** Cline supports sub-agents for parallel codebase analysis. Enable in settings.

4. **Multi-model support.** Cline works with Claude, GPT, Gemini, and local models. Claude models follow complex multi-step procedures more reliably.

5. **Auto-approve for implementation.** During the implementation loop, auto-approve mode speeds up the code → test → verify cycle. Disable during gate operations.

## Known Limitations

- Cline supports hooks natively (v3.36+) but this project does not yet provide Cline-specific hook scripts
- Rules are not hot-reloaded mid-task — changes take effect on next task
- Model compliance varies — Claude models follow complex instructions more reliably than smaller models
