# Contributing

Contributions are welcome! This workflow improves when people share what works
in their real projects.

## What to Contribute

### Language/Framework Patterns

The `sprint-audit-template.sh` and `TEMPLATE.md` include patterns for 7 languages.
If your stack isn't covered, add it:

- Add grep patterns to the Language-Specific Pattern Examples table in `TEMPLATE.md`
- Add commented examples to `sprint-audit-template.sh`
- Languages we'd love to see: Swift/iOS, Flutter/Dart, Kotlin, PHP/Laravel, Ruby/Rails, Elixir

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
- Every pattern must come from real experience. No hypothetical rules.
- English for all content (docs, comments, code).
- Test your changes — if you add patterns, run the audit script to verify they work.
