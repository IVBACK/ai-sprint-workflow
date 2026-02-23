# Contributing

Contributions are welcome! This workflow improves when people share what works
in their real projects.

## What to Contribute

### Language/Framework Patterns

The `sprint-audit-template.sh` and `WORKFLOW.md` include patterns for 7 languages.
If your stack isn't covered, add it:

- Add grep patterns to the Language-Specific Pattern Examples table in `WORKFLOW.md`
- Add commented examples to `sprint-audit-template.sh`
- Add a modular adapter to `checks/` (see below)
- Languages we'd love to see: Swift/iOS, Flutter/Dart, Kotlin, PHP/Laravel, Ruby/Rails, Elixir

### Language Audit Adapters

The `checks/` directory contains modular audit adapters that `sprint-audit.sh`
can load with `--modular`. To add a new adapter:

1. Create `checks/your-language.sh` following the pattern in existing adapters
2. Source `common.sh` helpers (`check`, `check_blocker`, `check_multi`)
3. Add the EXT-to-adapter mapping in `sprint-audit-template.sh`'s `case` statement
4. Test with: `EXT=your-ext bash sprint-audit-template.sh --modular`

### Agent Playbooks

Adaptation guides for specific AI agents live in `examples/[agent]-playbook/`.
To contribute a playbook:

1. Create `examples/your-agent-playbook/README.md`
2. Include: setup steps, hook equivalents table, session prompts, known limitations
3. Include the agent's native rule file (e.g., `.cursor/rules/*.mdc`, `.clinerules`, `.windsurfrules`)
4. Add "Read CLAUDE.md" to the session start protocol in the rule file
5. Update the compatibility table in `README.md`

Existing playbooks: Cursor, GitHub Copilot, Windsurf, Cline, OpenAI Codex CLI, Gemini CLI.

### Agent Compatibility Reports

If you've tested this workflow with an agent other than Claude Code,
open a PR updating the compatibility table in `README.md` with your results.

Include:
- Agent name and version
- What worked well
- What needed adjustment (if anything)

### Real-World Examples

Add your project as an anonymized example in `examples/`:

```
examples/
├── unity-csharp/        # existing
├── your-stack/          # new
│   └── README.md        # discovery answers, guardrail examples, adaptations
```

Keep it anonymized — no proprietary code, project names, or internal URLs.

### Bug Fixes and Improvements

- Fix typos, broken formatting, unclear instructions
- Improve the bootstrap flow based on real experience
- Add missing edge cases to the workflow

## How to Submit

1. Fork the repo
2. Create a branch (`feature/swift-patterns`, `fix/typo-in-template`, etc.)
3. Make your changes
4. Open a PR with a short description of what you changed and why

## Guidelines

- Keep it simple. This is a workflow template, not a framework.
- Every pattern must trace to a concrete source — bootstrap scan of real code or a production bug. No hypothetical rules.
- English for all content (docs, comments, code).
- Test your changes — if you add patterns, run the audit script to verify they work.
