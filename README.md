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
| Agent setup (non-Claude platforms) | [Docs/Workflow/AGENT-SETUP.md](Docs/Workflow/AGENT-SETUP.md) |
| Hook enforcement | [Docs/Systems/HOOKS.md](Docs/Systems/HOOKS.md) |
| Automation tools | [Docs/Systems/TOOLS.md](Docs/Systems/TOOLS.md) |
| Cross-LLM audit | [Docs/Workflow/CROSS-LLM-AUDIT.md](Docs/Workflow/CROSS-LLM-AUDIT.md) |
| Parallel execution | [Docs/Workflow/PARALLEL-EXECUTION.md](Docs/Workflow/PARALLEL-EXECUTION.md) |
| Team topologies | [Docs/Workflow/TEAM-GUIDE.md](Docs/Workflow/TEAM-GUIDE.md) |
| Adaptation & upgrade | [Docs/Workflow/ADAPTATION.md](Docs/Workflow/ADAPTATION.md) |
| Self-validation (contributors) | [validation/](validation/) |
| Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) |

## Dashboard

Live sprint dashboard that visualizes project status from your workflow artifacts (TRACKING.md, gate reports, roadmap).

```bash
# Web dashboard (recommended)
python3 dashboard/sprint-status.py your-project/ --serve

# Then open http://127.0.0.1:8384
```

Shows sprint progress, gate status, failure analysis, metrics, trends, and changelog — all parsed from your existing markdown files. Auto-refreshes when files change.

Other modes: CLI snapshot (no flags), watch mode (`-w`), JSON export (`--json`).

## Is This For You?

**Good fit:** Multi-sprint projects where context loss between sessions hurts, and mistakes compound over time.

**Not a good fit:** One-off scripts, single-session tasks, or "just generate code fast" workflows. When in doubt, try one sprint in [Lite mode](Docs/Workflow/WORKFLOW-MODES.md).

## Agent Support

**Works with any markdown-reading AI agent.** The core methodology is documented in markdown — any agent can read and follow it. Enforcement tooling (hooks, CLI, audit scripts) is additional. What varies is how much this project provides out of the box for each platform.

| Platform | Integration | What's Provided |
|---|---|---|
| **Claude Code** | Full (tested) | 14 hook scripts + 4 support scripts, sprint-tools CLI (13 commands), dashboard, cross-LLM audit, auto-memory sync |
| **Cursor** | [Playbook](playbooks/cursor-playbook/) | Adaptation guide, rule file examples. Platform supports hooks — community hook scripts welcome |
| **Windsurf** | [Playbook](playbooks/windsurf-playbook/) | Adaptation guide, rule file examples. Platform supports hooks — community hook scripts welcome |
| **Cline** | [Playbook](playbooks/cline-playbook/) | Adaptation guide, rule file examples. Platform supports hooks — community hook scripts welcome |
| **GitHub Copilot** | [Playbook](playbooks/copilot-playbook/) | Adaptation guide. No hook support on platform |
| **Codex CLI** | [Playbook](playbooks/codex-playbook/) | Adaptation guide |
| **Gemini CLI** | [Playbook](playbooks/gemini-playbook/) | Adaptation guide |

All agents get the full sprint methodology via markdown documentation. Claude Code is the only platform with ready-to-use mechanical enforcement (hook scripts that block gate violations). Cursor, Windsurf, and Cline support hooks natively — their hook scripts are not yet provided but [contributions are welcome](CONTRIBUTING.md).

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
