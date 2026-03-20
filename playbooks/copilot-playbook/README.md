# GitHub Copilot Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [GitHub Copilot](https://github.com/features/copilot).

> **Common setup steps** (bootstrap, rule content, prompts, sprint tools, hook equivalents): see [AGENT-SETUP.md](../../Docs/Workflow/AGENT-SETUP.md).
> This playbook covers Copilot-specific differences only.

## Setup

### 1. Bootstrap

In Copilot Agent mode, paste:

```
@workspace Read WORKFLOW.md and bootstrap this project.
```

The `@workspace` participant ensures Copilot indexes your project files.

> Skip Step 8.5 (`.claude/` hooks) — use `.github/copilot-instructions.md` instead.

### 2. Create Instructions

Create `.github/copilot-instructions.md` with the rule content from [AGENT-SETUP.md §2](../../Docs/Workflow/AGENT-SETUP.md#2-rule-file-content). Copilot reads this file automatically — no manual reference needed.

**Path-specific instructions:** Create `.github/instructions/<name>.instructions.md` with an `applyTo` frontmatter field (e.g., `applyTo: "**/*.ts"`) for glob-scoped rules.

### 3. Copilot Prompts

Use `@workspace` prefix in all prompts to ensure full project context. Use `#file:TRACKING.md` to explicitly load specific files.

## Model Selection Note

Copilot supports multiple models (Claude, GPT-4o, Gemini, etc.). Using Claude as the model improves instruction compliance — Claude follows complex multi-step procedures more reliably. However, **the model does not change the platform's capabilities.** Copilot with Claude still lacks hook enforcement, auto-memory, sub-agents, and automatic CLAUDE.md loading. These are platform features (Claude Code), not model features (Claude). For full mechanical enforcement, use Claude Code directly.

## Copilot-Specific Tips

1. **Use Agent mode for multi-step operations.** Entry Gate, Close Gate, and Sprint Close all need Agent mode for file creation and terminal access.

2. **Reference files explicitly.** Use `#file:TRACKING.md` or `#file:Docs/Planning/Roadmap.md` to ensure Copilot loads specific files.

3. **Break gate operations into steps.** Copilot Chat has a shorter context window. Run Entry Gate phases one at a time.

4. **Background coding agent.** Copilot's coding agent runs on GitHub Actions — assign issues to `@copilot` for autonomous work on well-scoped tasks.

## Known Limitations

- No hook support on platform — all enforcement is advisory
- No sub-agent spawning or parallel execution
- Context is limited — may lose sprint context in long sessions
- `@workspace` indexing may miss deeply nested files
- No persistent cross-session memory (session-scoped only)
