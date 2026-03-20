# OpenAI Codex CLI Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [OpenAI Codex CLI](https://github.com/openai/codex).

> **Common setup steps** (bootstrap, rule content, prompts, sprint tools, hook equivalents): see [AGENT-SETUP.md](../../Docs/Workflow/AGENT-SETUP.md).
> This playbook covers Codex-specific differences only.

## Setup

### 1. Configure CLAUDE.md Recognition

Codex reads `AGENTS.md` by default. Add to `~/.codex/config.toml`:

```toml
project_doc_fallback_filenames = ["CLAUDE.md"]
```

This makes Codex automatically read `CLAUDE.md` at session start — no separate `AGENTS.md` needed.

### 2. Bootstrap

```
Read WORKFLOW.md and bootstrap this project.
```

> Skip Step 8.5 (`.claude/` hooks) — Codex does not support hooks.

### 3. Create AGENTS.md (Optional)

If you prefer the Codex-native approach, create `AGENTS.md` at the project root with the rule content from [AGENT-SETUP.md §2](../../Docs/Workflow/AGENT-SETUP.md#2-rule-file-content). This handles sprint rules while `CLAUDE.md` handles project context.

**Size limit:** 32 KiB combined across all loaded instruction files (configurable via `project_doc_max_bytes`).

## Codex-Specific Tips

1. **Direct CLAUDE.md support.** With the fallback config, Codex reads `CLAUDE.md` natively — no translation layer needed.

2. **Directory-scoped overrides.** `AGENTS.override.md` in subdirectories can override parent rules for specific subsystems.

3. **Sandbox execution.** Codex runs commands in a sandbox by default — safe execution for `sprint-audit.sh` and tests.

4. **Full autonomy mode.** Codex's `full-auto` mode handles the implementation loop (code → test → verify) without interruption.

## Known Limitations

- No hook support — instructions are advisory
- No sub-agent spawning or parallel execution
- 32 KiB combined limit on instruction files
- Instructions load once per session — mid-session CLAUDE.md updates require restart
- Sandbox restrictions may affect some audit operations
