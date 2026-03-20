# Gemini CLI Playbook — AI Sprint Workflow

How to use the AI Sprint Workflow with [Gemini CLI](https://github.com/google-gemini/gemini-cli).

> **Common setup steps** (bootstrap, rule content, prompts, sprint tools, hook equivalents): see [AGENT-SETUP.md](../../Docs/Workflow/AGENT-SETUP.md).
> This playbook covers Gemini-specific differences only.

## Setup

### 1. Configure CLAUDE.md Recognition

Gemini reads `GEMINI.md` by default. Add to your Gemini CLI `settings.json`:

```json
{
  "context": {
    "fileName": ["GEMINI.md", "CLAUDE.md"]
  }
}
```

### 2. Bootstrap

```
Read WORKFLOW.md and bootstrap this project.
```

> Skip Step 8.5 (`.claude/` hooks) — Gemini does not support hooks.

### 3. Create GEMINI.md (Optional)

Create `GEMINI.md` at the project root. Use `@import` to include `CLAUDE.md` directly:

```markdown
# AI Sprint Workflow — Gemini Rules

@./CLAUDE.md

[Paste rule content from AGENT-SETUP.md §2]
```

The `@./CLAUDE.md` import brings in the full project context without duplication. When `CLAUDE.md` is updated, Gemini picks up the change via JIT re-discovery.

## Gemini-Specific Tips

1. **`@import` for zero duplication.** Rather than copying CLAUDE.md content, import it. One source of truth, always current.

2. **JIT discovery.** Gemini dynamically discovers `GEMINI.md` files in directories as it accesses them. Subdirectory-specific rules activate automatically.

3. **`/memory` commands.** `/memory show` displays loaded context, `/memory refresh` forces re-scan after gate operations update CLAUDE.md.

4. **Large context window.** Gemini supports 1M+ tokens — CLAUDE.md + TRACKING.md + CODING_GUARDRAILS.md all fit comfortably.

5. **Global rules.** `~/.gemini/GEMINI.md` provides default sprint workflow rules across all projects.

## Known Limitations

- No hook support — rules are advisory
- No sub-agent spawning or parallel execution
- `@import` paths must be relative or absolute — no glob patterns
- JIT discovery relies on directory access — rules in untouched directories won't load until referenced
