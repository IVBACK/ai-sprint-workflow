# AI Sprint Workflow

A sprint workflow framework for human + AI coding agent collaboration.
Drop it into any project — the AI agent bootstraps tracking, guardrails, audit scripts, and sprint gates adapted to your stack.

## Why

AI coding agents are powerful but stateless. Every session starts from zero.

| Problem | How this workflow solves it |
|---------|---------------------------|
| **Context loss** | `CLAUDE.md` + `TRACKING.md` give instant context every session |
| **Quality drift** | Three gates (Entry, Close, Sprint Close) catch mistakes early |
| **Scope creep** | Must/Should/Could prioritization keeps sprints focused |
| **Cross-sprint amnesia** | Sprint index tracks past failures so they don't repeat |

## Quick Start

Tell your AI agent:

> "Set up sprint workflow from https://github.com/IVBACK/ai-sprint-workflow"

The agent installs workflow files, scans your codebase, asks what you're building, and starts your first sprint.

## Requirements

- Bash 4+ (macOS users: `brew install bash`)
- Python 3.10+
- git
- Unix / macOS / WSL (Windows: requires WSL or Git Bash)
- Optional: jq (for hook enforcement)

## How It Works

```
  ENTRY GATE        →  "Are we building the right thing?"
       ↓                Decomposition, failure modes, metrics
  IMPLEMENTATION    →  "Are we building it correctly?"
       ↓                Guardrails → code → test → verify
  CLOSE GATE        →  "Did we build it correctly?"
       ↓                Automated scan + spec audit + fitness review
  SPRINT CLOSE      →  Archive, baseline, retrospective
```

Four [workflow modes](Docs/Workflow/WORKFLOW-MODES.md) from zero-overhead to full rigor: **Freestyle** (safety only), **Lite** (basic gates), **Standard** (default, full workflow), **Strict** (no overrides, enforce-block). See [WORKFLOW-MODES.md](Docs/Workflow/WORKFLOW-MODES.md) for the full comparison table.

## Documentation

| Topic | Document |
|-------|----------|
| System architecture | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Design rationale (50+ decisions) | [DESIGN.md](DESIGN.md) |
| Project setup & bootstrap | [Docs/Workflow/BOOTSTRAP.md](Docs/Workflow/BOOTSTRAP.md) |
| Entry Gate (pre-sprint review) | [Docs/Workflow/ENTRY-GATE.md](Docs/Workflow/ENTRY-GATE.md) |
| Implementation loop | [Docs/Workflow/IMPL-LOOP.md](Docs/Workflow/IMPL-LOOP.md) |
| Close Gate (sprint-end audit) | [Docs/Workflow/CLOSE-GATE.md](Docs/Workflow/CLOSE-GATE.md) |
| Sprint Close (finalization) | [Docs/Workflow/SPRINT-CLOSE.md](Docs/Workflow/SPRINT-CLOSE.md) |
| Scope change, abort, audit | [Docs/Workflow/PROCEDURES.md](Docs/Workflow/PROCEDURES.md) |
| AI agent rules | [Docs/Workflow/AGENT-RULES.md](Docs/Workflow/AGENT-RULES.md) |
| Hook enforcement (Claude Code) | [Docs/Systems/HOOKS.md](Docs/Systems/HOOKS.md) |
| Automation tools (Claude Code) | [Docs/Systems/TOOLS.md](Docs/Systems/TOOLS.md) |
| Cross-LLM audit | [Docs/Workflow/CROSS-LLM-AUDIT.md](Docs/Workflow/CROSS-LLM-AUDIT.md) |
| Parallel execution | [Docs/Workflow/PARALLEL-EXECUTION.md](Docs/Workflow/PARALLEL-EXECUTION.md) |
| Team topologies | [Docs/Workflow/TEAM-GUIDE.md](Docs/Workflow/TEAM-GUIDE.md) |
| Adaptation & upgrade | [Docs/Workflow/ADAPTATION.md](Docs/Workflow/ADAPTATION.md) |
| Self-validation (contributors) | [validation/](validation/) |
| Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) |

## Is This For You?

**Good fit:** Multi-sprint projects where context loss between sessions hurts, and mistakes compound over time.

**Not a good fit:** One-off scripts, single-session tasks, or "just generate code fast" workflows. When in doubt, try one sprint in [Lite mode](Docs/Workflow/WORKFLOW-MODES.md).

## Agent Support

**Works with:** Claude Code (tested) | Cursor | GitHub Copilot | Windsurf | Cline | Codex CLI | Gemini CLI | any markdown-reading agent.

| Capability | Claude Code | Other Agents |
|-----------|:-----------:|:------------:|
| Core workflow (gates, tracking, audit) | Full | Full (untested) |
| Sprint-tools CLI | Full | Full* (untested) |
| Sprint dashboard | Full | Full* (untested) |
| Hook enforcement (mechanical) | Full | — |
| Parallel execution (sub-agents) | Full | — |
| Workflow mode enforcement | Full | — |
| Cross-session memory | Full | Varies** (untested) |

All agents get the full sprint methodology. Claude Code adds mechanical enforcement — rules that are advisory for other agents become hard gates. See agent-specific adaptation guides in [`playbooks/`](playbooks/) for native rule files and hook-mapping workarounds.

\* Requires shell/terminal access. GitHub Copilot has limited terminal integration.
\** Windsurf/Cline/Codex/Gemini: partial (file-based). Copilot: none (session-scoped only).
Adaptation guides: [Cursor](playbooks/cursor-playbook/) · [Copilot](playbooks/copilot-playbook/) · [Windsurf](playbooks/windsurf-playbook/) · [Cline](playbooks/cline-playbook/) · [Codex](playbooks/codex-playbook/) · [Gemini](playbooks/gemini-playbook/)

## Measured Performance

Same task (Bookmark REST API), same model, automated multi-turn sessions:

| Metric | Without Workflow | With Workflow |
|--------|-----------------|---------------|
| Tokens | 9K | 26K |
| Duration | 3 min | 10 min |

The workflow adds ~3x token and time overhead per sprint. That cost pays for structured gates, failure mode tracking, and cross-sprint learning — things that prevent compounding mistakes across sessions.

> Single-run measurement. Directional, not statistically significant.

### Known Trade-offs

- **Sprint overhead:** ~3x tokens and duration vs free-form coding — amortized over project lifetime by fewer regressions and less rework.
- **Not for throwaway code:** If the project won't survive past one session, the overhead exceeds the value.

## Origin

This workflow was developed during a production project. It evolved over multiple sprints, accumulating guardrail rules, automated audit scripts, and hundreds of AI agent sessions.

## License

MIT — see [LICENSE](LICENSE).
