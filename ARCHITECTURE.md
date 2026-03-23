# Architecture

AI Sprint Workflow is a sprint methodology framework for human + AI coding agent collaboration. It provides structured markdown files (workflow docs, tracking, guardrails) that any AI coding agent reads and follows, plus an optional automation layer (hooks + CLI tools) for Claude Code. The core workflow is agent-agnostic plain markdown; the enforcement layer is Claude Code-specific.

## System Map

```
                         ┌─────────────────────────┐
                         │     AI Coding Agent      │
                         │ (Claude Code / Cursor /  │
                         │  Copilot / any agent)    │
                         └────┬──────────┬──────────┘
                              │          │
                reads/follows │          │ triggers
                              ▼          ▼
          ┌───────────────────────┐  ┌──────────────────────────┐
          │   Workflow Docs       │  │   Hook System            │
          │   Docs/Workflow/      │  │   .claude/hooks/         │
          │                       │  │   (Claude Code only)     │
          │ ENTRY-GATE.md         │  │                          │
          │ IMPL-LOOP.md          │  │ settings.json  → wiring  │
          │ CLOSE-GATE.md         │  │ hooks-config.sh→ toggles │
          │ SPRINT-CLOSE.md       │  │ 14 hooks + 4 aux→ enforce│
          │ AGENT-RULES.md        │  └──────────┬───────────────┘
          │ PROCEDURES.md         │             │
          │ STATE-TRANSITIONS.md  │        reads/writes
          │ TEMPLATES.md          │             │
          │ ADAPTATION.md         │             ▼
          └───────────────────────┘  ┌──────────────────────────┐
                                     │   Memory / State         │
          ┌───────────────────────┐  │                          │
          │   Tool System         │  │ CLAUDE.md    → context   │
          │   Tools/sprint-tools  │  │ TRACKING.md  → status    │
          │   (any agent w/ shell)│  │ Roadmap.md   → plan      │
          │                       │  │ GUARDRAILS.md→ rules     │
          │ sprint-state.py       │  │ SPRINT-INDEX → lookup    │
          │ sprint-item.py        │  └──────────────────────────┘
          │ sprint-git.py         │
          │ + 10 more tools       │  ┌──────────────────────────┐
          │ sprint_lib/ (shared)  │  │   Validation             │
          └───────────────────────┘  │   validation/            │
                                     │                          │
                                     │ validate-structure.sh    │
                                     │ validate-model.sh        │
                                     │ validate-artifacts.sh    │
                                     │ workflow-model.yaml      │
                                     └──────────────────────────┘
```

## Hook System

14 event-driven bash hooks triggered by Claude Code lifecycle events (SessionStart, PreToolUse, PostToolUse, PreCompact, Stop), plus 4 auxiliary scripts (shared library, pre-merge audit, evidence verification, health check). Each hook reads `hooks-config.sh` for its toggle flag. Four workflow modes (freestyle/lite/standard/strict) set which hooks are active. Settings wired in `.claude/settings.json`.

- Detail: [Docs/Systems/HOOKS.md](Docs/Systems/HOOKS.md)
- Config: [.claude/hooks-config.sh](.claude/hooks-config.sh)
- Hooks: [.claude/hooks/](.claude/hooks/)

## Tool System

`Tools/sprint-tools` is a bash dispatcher that routes subcommands (state, item, git, checkpoint, baseline, metrics, close, index, review, verify, learn, note, migrate) to single-responsibility Python scripts. All tools share `sprint_lib/` -- a typed library with markdown parsers, in-place writers, and data models. Zero external dependencies (stdlib only).

- Detail: [Docs/Systems/TOOLS.md](Docs/Systems/TOOLS.md)
- Dispatcher: [Tools/sprint-tools](Tools/sprint-tools)
- Library: [Tools/sprint_lib/](Tools/sprint_lib/)

## Memory System

Session context flows through four files. `CLAUDE.md` provides project context, contracts, and last checkpoint -- auto-loaded every session. `TRACKING.md` is the single source of truth for item status, risks, failure modes, and Working Context. `Docs/Planning/Roadmap.md` holds the sprint plan. `Docs/CODING_GUARDRAILS.md` holds engineering rules. The `memory-sync.sh` hook enforces read-at-start and update-before-stop.

- Detail: [Docs/Systems/MEMORY.md](Docs/Systems/MEMORY.md)
- Hook: [.claude/hooks/memory-sync.sh](.claude/hooks/memory-sync.sh)
- Models: [Tools/sprint_lib/models.py](Tools/sprint_lib/models.py)

## Validation

Self-validation for the workflow template itself (not user projects). Three levels: structure checks (numeric claims, cross-references, hook parity), formal model checks (FSM reachability, loop termination, guard blocking), and artifact compliance checks (runtime TRACKING.md validation). Negative self-tests verify the validators catch intentional breaks.

- Scripts: [validation/](validation/)

## Workflow Docs

Split workflow documentation in `Docs/Workflow/` -- one file per phase/concern. The AI loads only the file relevant to its current task, not all at once.

- Directory: [Docs/Workflow/](Docs/Workflow/)

## File Map

```
.claude/
  settings.json            Hook event → script wiring
  hooks-config.sh          Feature flags, mode presets, audit config
  setup-audit.sh           Interactive cross-LLM audit setup
  hooks/                   14 event-driven hooks + 4 auxiliary scripts (see §Hook System)
Tools/
  sprint-tools             Bash dispatcher → 13 Python subcommands
  sprint-{state,item,git,checkpoint,baseline,metrics,close,index,review,verify,learn,note,migrate}.py
  sprint_lib/              Shared library (models, parsers, writers)
Docs/Systems/
  HOOKS.md                 Hook system internals
  TOOLS.md                 Sprint-tools automation reference
  MEMORY.md                Memory/state persistence architecture
Docs/Workflow/
  BOOTSTRAP.md             Project setup orchestrator (reads phases 1-5)
  BOOTSTRAP-PHASE{1..5}.md Five sequential bootstrap phases
  BOOTSTRAP-PHASE4B.md     Cross-audit offer (between 4a and 5)
  BOOTSTRAP-SETUP.md       File creation (steps 3-10)
  ENTRY-GATE.md            Pre-sprint review (phases 0-3, 12 steps)
  IMPL-LOOP.md             Implementation loop
  CLOSE-GATE.md            Sprint-end audit (phases 0-4)
  SPRINT-CLOSE.md          Post-gate finalization
  PROCEDURES.md            Scope change, abort, audit procedures
  AGENT-RULES.md           AI agent operational rules
  STATE-TRANSITIONS.md     Item/sprint lifecycle states
  TEMPLATES.md             File templates (CLAUDE.md, TRACKING.md, etc.)
  ADAPTATION.md            Project size adaptation + upgrade
  HOOK-TEMPLATES.md        Hook & audit file templates
  WORKFLOW-MODES.md        Four rigor presets (freestyle/lite/standard/strict)
  CROSS-LLM-AUDIT.md       External LLM review integration
  PARALLEL-EXECUTION.md    Wave-based parallel agent coordination
  TEAM-GUIDE.md            Multi-agent topologies, PR integration
  UNITY-GUIDE.md           Unity-specific git, LFS, scene ownership
  AGENT-SETUP.md           Non-Claude platform adaptation
  Skeletons/               Pre-shipped skeleton files (CLAUDE.md, TRACKING.md, etc.)
validation/
  validate-structure.sh    Cross-reference and numeric claim checks
  validate-model.sh        FSM reachability and formal model checks
  validate-artifacts.sh    Runtime artifact compliance
  workflow-model.yaml      Formal workflow model definition
```
