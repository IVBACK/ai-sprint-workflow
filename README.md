# AI Sprint Workflow

A sprint workflow framework (methodology + tooling) for human + AI coding agent collaboration.

Drop `WORKFLOW.md` into any project and the AI agent bootstraps the full structure:
tracking, guardrails, audit scripts, and sprint gates — all adapted to your stack.

Works with existing projects and greenfield (empty) projects alike.

### Compatibility

| Agent | Status | Notes |
|-------|--------|-------|
| **Claude Code** | Tested | Full support + optional [hook enforcement layer](#claude-code-hook-enforcement-optional) (11 hooks, secret protection, cross-LLM audit) |
| Cursor | Playbook available | [Adaptation guide](examples/cursor-playbook/) with `.cursor/rules/` |
| GitHub Copilot | Playbook available | [Adaptation guide](examples/copilot-playbook/) with `copilot-instructions.md` |
| Windsurf | Playbook available | [Adaptation guide](examples/windsurf-playbook/) with `.windsurf/rules/` |
| Cline | Playbook available | [Adaptation guide](examples/cline-playbook/) with `.clinerules` |
| OpenAI Codex CLI | Playbook available | [Adaptation guide](examples/codex-playbook/) with `AGENTS.md` (reads `CLAUDE.md` via fallback config) |
| Gemini CLI | Playbook available | [Adaptation guide](examples/gemini-playbook/) with `GEMINI.md` (`@import` for `CLAUDE.md`) |
| Any agent that reads markdown | Should work | Core workflow is plain markdown — no agent-specific APIs |

> The workflow uses plain markdown files and bash scripts — no agent-specific APIs.
> Any AI coding agent that can read files and follow instructions should work.
> PRs with confirmed test results for other agents are welcome.

## Is This For You?

**Good fit:**
- You're building something that will run for multiple sprints (not a one-off script)
- You work with an AI coding agent across multiple sessions and lose context between them
- Mistakes compound — a wrong decision in Sprint 1 causes pain in Sprint 4
- You want the AI to plan and verify, not just generate code

**Not a good fit:**
- Quick prototype or throwaway experiment (overhead exceeds value)
- Single session, clear scope, no follow-up sprints
- You just want code generated fast without process

When in doubt: try it on one sprint. If the Entry Gate feels like bureaucracy for your project size, try [Lite mode](#workflow-modes) before dropping the workflow entirely.

## Why This Exists

AI coding agents (Claude Code, Cursor, Copilot, etc.) are powerful but stateless.
Every session starts from zero. This workflow solves three problems:

1. **Context loss** — Structured files (`CLAUDE.md`, `TRACKING.md`, `CODING_GUARDRAILS.md`) give the agent instant context on every session start.
2. **Quality drift** — Three gates (Entry Gate, Close Gate, Sprint Close) catch mistakes before they compound.
3. **Scope creep** — Must/Should/Could prioritization and strategic alignment checks keep sprints focused.
4. **Cross-sprint amnesia** — Sprint index (`SPRINT-INDEX.md`) provides topic-first lookup of past failures, decisions, and regressions so the agent doesn't repeat mistakes.

## How It Works

```
                  ┌──────────────┐
                  │  ENTRY GATE  │  "Are we building the right thing?"
                  │(ph0-3,13 st)│  Sprint detail + alignment + dependency check
                  └──────┬───────┘  ◄─── Auto-Detection Checkpoint 1 (metric regression)
                         │               Auto-Detection Checkpoint 2 (failure pattern)
                         │               ║ Step 11: 4+ independent items? → AI suggests parallel ║
                         ▼
                  ┌──────────────┐
                  │ IMPLEMENTATION│  "Are we building it correctly?"
                  │    LOOP      │  Pre-code guardrails → code → self-verify → test → run all tests
                  └──────┬───────┘  ◄─── Auto-Detection Checkpoint 3 (broken past-sprint output)
                         │               ║ Parallel: per-item agents in dependency waves ║
                         ▼
                  ┌──────────────┐
                  │  CLOSE GATE  │  "Did we build it correctly?"
                  │  (6 phases)  │  Automated scan + spec-driven audit + fitness review + item-level tests
                  └──────┬───────┘  ◄─── Auto-Detection Checkpoint 4 (Must item unverifiable)
                                         ║ Parallel: metric + audit waves ║
                         │
                         ▼
                  ┌──────────────┐
                  │ SPRINT CLOSE │  Checkmarks, archive, baseline, retrospective, user handoff
                  └──────────────┘

                         ┌────────────────────────────────────────────┐
        When any         │  RETROACTIVE SPRINT AUDIT  (optional)      │
        checkpoint  ───► │  7-phase archaeology of a completed sprint  │
        fires:           │  when its output is found broken or         │
                         │  inconsistent with Close Gate claims        │
                         │                                            │
                         │  Phase 0: Setup (target sprint + symptom)  │
                         │  Phase 1: Evidence collection              │
                         │  Phase 2: Current state measurement        │
                         │  Phase 3: Gap analysis (5% tolerance rule) │
                         │  Phase 4: Classification                   │
                         │    REGRESSION / INTEGRATION_GAP /          │
                         │    FALSE_VERIFICATION / COLD_STATE /       │
                         │    SCOPE_DRIFT / ENVIRONMENT_DELTA         │
                         │  Phase 5: Dependency impact assessment     │
                         │  Phase 6: Resolution plan                  │
                         │  Phase 7: Audit close → TRACKING.md        │
                         └────────────────────────────────────────────┘
```

## Quick Start

**Any agent** — install CLI + interactive setup:

```bash
curl -fsSL https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/sprint-workflow -o ~/.local/bin/sprint-workflow && chmod +x ~/.local/bin/sprint-workflow
sprint-workflow init
```

The CLI walks you through:
1. **Install** — copies `WORKFLOW.md`, hooks, reference docs, dashboard (skips repo infrastructure)
2. **Agent selection** — Claude Code, Cursor, Copilot, Windsurf, Cline, Codex CLI, Gemini CLI
3. **Workflow mode** — Lite / Standard / Strict
4. **Cross-LLM audit** — optional second AI code reviewer (Claude Code only)
5. **Launch** — optionally design a [roadmap](#want-a-richer-roadmap-design-it-first) first, then bootstrap. Choose CLI or Editor launch; extension-only agents get the prompt copied to clipboard

After setup, the agent bootstraps your project: scans your codebase, asks discovery questions, creates `CLAUDE.md` + tracking files, and sets up the first sprint. Existing `.claude/` hooks are detected and preserved — you get the exact tested implementations (11 hooks including secret protection, cross-LLM audit, validation gates).

### CLI Reference

| Command | Description |
|---------|-------------|
| `sprint-workflow init` | Install + interactive onboarding + launch AI bootstrap |
| `sprint-workflow config` | View all settings |
| `sprint-workflow config mode lite` | Set workflow mode (lite/standard/strict) |
| `sprint-workflow config hook.protect-claude true` | Toggle a specific hook |
| `sprint-workflow config audit.wave-size 10` | Set audit wave size |
| `sprint-workflow log` | View last 10 audit log entries |
| `sprint-workflow log --errors` | Filter to errors only |
| `sprint-workflow log --success -n 5` | Last 5 successful audits |
| `sprint-workflow audit-setup` | Configure cross-LLM audit (interactive) |
| `sprint-workflow status` | Sprint dashboard (CLI, watch mode, or web) |
| `sprint-workflow upgrade` | Update workflow to latest version |
| `sprint-workflow doctor` | Health check (hooks, config, permissions, version) |
| `sprint-workflow completions bash` | Generate shell completions (bash/zsh/fish) |

**Non-interactive mode** (CI, scripting, automated setup):

```bash
sprint-workflow init --auto                              # defaults: claude-code, standard, no audit
sprint-workflow init --agent cursor --mode lite --no-audit  # explicit options
sprint-workflow init --lang tr                            # Turkish UI
```

**Shell completion** (add to your shell rc file):

```bash
eval "$(sprint-workflow completions bash)"    # bash → ~/.bashrc
eval "$(sprint-workflow completions zsh)"     # zsh  → ~/.zshrc
sprint-workflow completions fish > ~/.config/fish/completions/sprint-workflow.fish
```

**What the agent does during bootstrap:**
- Detect whether this is a greenfield or existing project (Step 0)
- Scan your project (language, framework, build system, test framework — large projects capped at 50 files)
- Ask 16 discovery questions (skipping ones it can infer from project files)
- Create `CLAUDE.md`, `TRACKING.md`, `Docs/CODING_GUARDRAILS.md`, `Docs/LESSONS_INDEX.md`, `Docs/SPRINT-INDEX.md`, `Docs/Planning/Roadmap.md`, `Tools/sprint-audit.sh`, `.claude/setup-audit.sh` (Claude Code only)
  - Existing project: skips files that already exist; asks before touching `TRACKING.md`, `Roadmap.md`, `CODING_GUARDRAILS.md`
- If no sprint plan exists: run Initial Planning (decompose goal into phases, detail Sprint 1 only)
  - Existing project: whatever you're currently working on becomes Sprint 1 — no retrospective reconstruction
- Adapt audit script patterns to your detected language (multi-language projects supported; modular adapters in `checks/` can be loaded with `--modular` flag)
- Create `Docs/SPRINT_WORKFLOW.md` from `WORKFLOW.md` (strips bootstrap-only sections; AI reads section-by-section at sprint boundaries, not all at once)
- **[Claude Code only]** Detect existing `.claude/` hooks or create hook infrastructure (step 8.5) — enforces workflow rules mechanically; see [Claude Code: Hook Enforcement](#claude-code-hook-enforcement-optional) below
- Confirm the setup with you before writing any feature code

After setup is confirmed, start your first sprint:

```
"Open Sprint 1 for [brief description of what you're building]."
```

The agent runs the Entry Gate — you review the plan, then implementation begins.
For subsequent sessions: tell the agent `"Continue sprint N"` or `"Resume"`.

### Want a richer roadmap? Design it first.

The bootstrap produces a lean roadmap skeleton. For complex projects (rewrites, large scope, prior
lessons to capture), design the roadmap in a separate focused session before bootstrapping.

**Via `sprint-workflow init` (recommended):** Step 5 asks "Design a roadmap before bootstrap?" — say yes. The CLI launches a guided roadmap session (3-batch conversation: foundation → domain knowledge → plan). When done, it continues to bootstrap automatically. Bootstrap detects the existing `Roadmap.md` → skips Initial Planning.

**Manual (without CLI):**
1. Tell the agent:
   > "Fetch https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/ROADMAP-DESIGN-PROMPT.md and design the roadmap."
2. Then bootstrap: *"Read WORKFLOW.md and bootstrap this project."*
   — Bootstrap detects the existing `Roadmap.md` → skips Initial Planning automatically

### Bootstrap Steps (10 total: Step 0 + steps 1–9)

```
0. Detect state    → source code or workflow files? → Greenfield or Migration mode
                     Migration: read conflict rules before touching any file
1. Scan project    → detect language, framework, build system, test framework
2. Discovery Q's   → 16 questions (batch, skip inferrable ones)
3. Create structure→ CLAUDE.md, TRACKING.md, CODING_GUARDRAILS.md, LESSONS_INDEX.md, Roadmap.md, Tools/
                     Migration: skip files that already exist; ask before touching
4. Initial Planning→ if no sprint plan exists: goal → phases → detail S1 → contracts
                     Migration: current work = Sprint 1 (no retrospective)
5. Populate CLAUDE.md with project context
6. Populate CODING_GUARDRAILS.md — project-aware guardrail scan (3 layers: stack/domain/codebase)
7. Adapt audit script to detected language
                     Migration: call existing CI commands, don't duplicate checks
8. WORKFLOW.md → Docs/SPRINT_WORKFLOW.md (strip bootstrap sections)
8.5 [Claude Code only] Create .claude/ hook infrastructure → see below
9. Confirm with user
```

### Claude Code: Hook Enforcement (Optional)

If you use Claude Code, the bootstrap (step 8.5) creates a `.claude/` hook layer that enforces workflow rules mechanically — without relying on the agent reading and remembering them.

**How to get the hooks:**
- **Bootstrap (recommended):** The agent creates all hook files automatically during bootstrap (step 8.5) — file contents are embedded in WORKFLOW.md's File Templates section, no separate download needed.
- **Manual:** Clone this repo and copy the `.claude/` directory into your project.

| Hook | Trigger | What it enforces |
|------|---------|-----------------|
| `protect-claude.sh` | Before any `Write` | Hard-blocks overwriting `CLAUDE.md` |
| `protect-secrets.sh` | Before any `Read`/`Bash` | Hard-blocks reading `.env`, `*.key`, `*.pem`, `credentials.json`, `secrets.yaml` — 6-layer bypass prevention |
| `validate-tracking.sh` | After `TRACKING.md` edit | Illegal status values, missing evidence on `verified`, missing reason on `deferred` |
| `validate-id-uniqueness.sh` | After `TRACKING.md` edit | Duplicate `CORE-###` IDs |
| `session-start.sh` | Every session start | Injects "read TRACKING.md first" protocol into agent context |
| `entry-gate-session.sh` | After Entry Gate report written | Injects mandatory session boundary recommendation |
| `detect-audit-signals.sh` | Session start + TRACKING.md edit (CP1-CP2) | Metric regression ≥`AUDIT_CP1_THRESHOLD` (default 20%) between sprints; repeated failure categories across ≥`AUDIT_CP2_MIN_SPRINTS` (default 2) sprints; warns when structured tables are missing |
| `detect-test-regression.sh` | After `Bash` (test runs) (CP3) | Surfaces test failure signals instead of silently continuing |
| `validate-close-gate.sh` | After Close Gate report written (CP4) | Unverified items, 8-point pre-verdict checklist, all-DEFERRED guard |
| `validate-sprint-close.sh` | After Sprint Close report written | Failure mode retrospective, performance baseline, user handoff presence |
| `cross-llm-audit.sh` | After `Edit`/`Write` (source, gates, TRACKING) | **Optional.** Sends diff to external LLM (OpenAI, Anthropic, GitHub Models, Ollama) for independent review. Four modes: per-edit, wave-review (parallel merge checkpoint), Close Gate holistic, Entry Gate plan review |

All hooks are individually toggleable via `.claude/hooks-config.sh`. Set any flag to `"false"` to disable a specific hook, or set `WORKFLOW_MODE` to `lite`/`standard`/`strict` to apply a preset (see [Workflow Modes](#workflow-modes)).

**Changing settings (3 ways):**
1. Edit `_D_*` defaults in `.claude/hooks-config.sh` — applies to whole team (git-tracked)
2. Put overrides in `.claude/hooks-config.local.sh` — personal, git-ignored
3. Export as env var: `export CROSS_AUDIT_WAVE_SIZE=10` — temporary, current shell

**Cross-LLM Audit (optional, Claude Code only):** Send code changes to a second LLM for independent review. Supports OpenAI-compatible APIs (OpenAI, GitHub Models, Ollama, etc.) and native Anthropic API. Four audit modes: per-edit (source changes), wave-review (parallel merge checkpoint — fires when TRACKING.md is updated after wave merge, reviews cross-item integration), Close Gate (holistic sprint review), Entry Gate (plan review). Sub-agents in worktrees are auto-skipped (coordinator reviews the merged result instead). Disabled by default — setup: `bash .claude/setup-audit.sh` (interactive, collects API key securely via hidden input). API key stored in `.env` (git-ignored), mechanically protected by `protect-secrets.sh` hook — the AI never sees the key. Optional `CROSS_AUDIT_ENFORCE_BLOCK=true` mechanically blocks commits when the reviewer returns a BLOCK verdict (default: advisory only). See [Docs/CROSS-LLM-AUDIT.md](Docs/CROSS-LLM-AUDIT.md).

Other agents (Cursor, Copilot, Windsurf, Cline, Codex CLI, Gemini CLI, etc.) are unaffected — `.claude/` is Claude Code-specific and invisible to them.

Empty project? Step 1 is skipped — Discovery Questions cover language/framework.

### Discovery Questions (16)

Questions are asked in a single batch. Answers inferrable from project files
(e.g., `package.json` → TypeScript + Jest) are stated as inferred and confirmed.

| Category | Questions |
|----------|-----------|
| **Project Shape** | Q0: Language/framework, Q1: Solo or team, Q2: Sprint scope size, Q3: Existing roadmap, Q4: Performance-sensitive, Q5: Target platforms |
| **Infrastructure** | Q6: CI/CD pipeline, Q7: Test framework, Q8: Existing linter/standards, Q9: Known tech debt |
| **Workflow Preferences** | Q10: Docs language, Q11: Commit style (skipped if VCS=none), Q12: Immutable contracts, Q13: Anything else the AI should know, Q14: Critical Axis, Q15: Enable Cross-LLM Audit *(Claude Code only)* |

Q0 auto-detects from project files; asks explicitly if the project is empty. If user is undecided, AI proposes options with trade-offs.
VCS is auto-detected (`.git`, `.svn`, `.hg`). Result recorded in `CLAUDE.md`. If VCS=none: Q11 skipped, Close Gate Phase 1b uses Entry Gate implementation notes instead of `git diff`, TRACKING.md recovery falls back to user verification.
Q12 (Immutable contracts): technical constraints that must never change mid-sprint — e.g. "API response format X", "must support offline mode". Recorded in `CLAUDE.md §Immutable Contracts` and enforced at every Entry Gate. "None yet" is a valid answer — contracts are discovered during implementation.
Q13 is an open-ended catch-all for context that doesn't fit the predefined categories.
Q14 (Critical Axis): the project's #1 non-negotiable quality concern — security, performance, reliability, correctness, or other. If unanswered, inferred from domain (payment/auth → security; game/realtime → performance; medical/finance → correctness). Recorded in `CLAUDE.md`. Entry Gate 9a requires deeper failure mode coverage for items touching this axis; Close Gate Phase 2 prevents silent deferral of findings in this domain.

## Effective Prompts

The workflow is **user-activated**, not self-executing. The agent reads `CLAUDE.md` on every session start and knows the workflow exists — but a plain `"I want a new feature"` may bypass the workflow and go straight to code generation. Use explicit trigger phrases:

**Starting new work:**
- `"Open Sprint N for X."` — triggers Entry Gate before any code is written
- `"Add X to the roadmap."` — adds item to Roadmap.md without starting a sprint yet

**Continuing existing work:**
- `"Resume Sprint N. [symptom] for several sessions."` — enters workflow properly; auto-detection checkpoints fire

**Learning from failures:**
- `"Learn from this bug."` — documents lessons to `CODING_GUARDRAILS.md`
- `"Why didn't tests catch this?"` — triggers test gap analysis; regression test added

## What Gets Created

Core structure (all agents):

```
your-project/
├── CLAUDE.md                     # AI session context (auto-loaded every session)
├── TRACKING.md                   # Single source of truth for item status
├── Docs/
│   ├── CODING_GUARDRAILS.md      # Engineering rules from real bugs
│   ├── LESSONS_INDEX.md          # Bug → rule traceability (starts empty)
│   ├── SPRINT_WORKFLOW.md        # Workflow reference (copied from WORKFLOW.md)
│   ├── PARALLEL-EXECUTION.md    # Parallel wave patterns (optional, for sub-agent capable tools)
│   ├── SPRINT-INDEX.md          # Topic-first cross-sprint retrieval index
│   ├── CROSS-LLM-AUDIT.md      # Cross-LLM audit setup guide (optional)
│   ├── WORKFLOW-MODES.md        # Lite/Standard/Strict mode details
│   ├── TEAM-GUIDE.md            # Team topologies, dependencies, PR/CI (team only)
│   ├── UNITY-GUIDE.md           # Unity-specific git/LFS/scene rules (optional)
│   ├── Archive/                  # Archived sprint changelogs and failure history
│   └── Planning/
│       ├── Roadmap.md            # Sprint plan (Must/Should/Could)
│       └── S<N>_ENTRY_GATE.md    # Entry Gate report (lives during sprint, deleted at close)
├── Tools/
│   └── sprint-audit.sh           # Automated close gate checks
├── dashboard/                    # Sprint dashboard (optional, standalone)
│   ├── sprint-status             # Bash wrapper (called by sprint-workflow status)
│   └── sprint-status.py          # CLI + web dashboard (zero dependencies, stdlib only)
└── .claude/                      # Claude Code hooks (Step 8.5, skip for other agents)
    ├── hooks-config.sh           # Centralized config (hooks, audit, thresholds, limits)
    ├── hooks-config.local.sh     # Personal overrides (git-ignored, optional)
    ├── settings.json             # Hook registrations
    ├── setup-audit.sh            # Interactive cross-LLM audit setup
    └── hooks/
        ├── session-start.sh           # Session start protocol injection
        ├── protect-claude.sh          # Block Write to CLAUDE.md
        ├── protect-secrets.sh         # Block Read/Bash on .env, *.key, *.pem
        ├── validate-tracking.sh       # Validate TRACKING.md status values
        ├── validate-id-uniqueness.sh  # Detect duplicate CORE-### IDs
        ├── entry-gate-session.sh      # Mandatory session boundary after Entry Gate
        ├── detect-audit-signals.sh    # CP1+CP2: metric regression detection
        ├── detect-test-regression.sh  # CP3: test failure surfacing
        ├── validate-close-gate.sh     # CP4: Close Gate validation
        ├── validate-sprint-close.sh   # Sprint Close report validation
        └── cross-llm-audit.sh        # External LLM code review (optional)
```

### Why Separate Files?

```
Single mega-file  = AI reads everything every session  (~2000+ lines)
Separated files   = AI reads only what's needed        (~200-300 lines)
```

Context window is finite. Separation lets the agent load CLAUDE.md (always),
TRACKING.md (session start), guardrails sections (per-task), and
SPRINT_WORKFLOW.md (sprint boundaries only) — not the entire project history.

Selective loading rules keep context lean as the project grows:
- `CODING_GUARDRAILS.md`: §Index read first → only the relevant section loaded per task (~20-40 lines), not the full file
- `S<N>_ENTRY_GATE.md`: loaded per-item during Close Gate audit, not the full report at once
- `TRACKING.md §Failure Mode History`: archived after 5 sprints to prevent bloat
- `S<N>_ENTRY_GATE.md`: deleted at Sprint Close — `TRACKING.md` gate log is the permanent record
- Roadmap: only the active sprint section loaded, not the full multi-phase plan

A 24-sprint project stays at ~200-300 lines per session. Files grow on disk; context stays small.

## Key Design Decisions

- **User-activated, not automatic.** The agent knows the workflow via `CLAUDE.md` but will not self-invoke Entry Gate on a plain feature request. Explicit trigger phrases are required (see [Effective Prompts](#effective-prompts)).
- **AI flags, user decides.** When a gate check fails, the AI presents evidence and options. It never unilaterally changes sprint scope.
- **Sprint scope, not duration.** A sprint is 1-8 Must items (+ optional Should/Could), not a calendar week. AI can finish a "sprint" in hours.
- **Guardrails grow from bugs and project scans.** Bootstrap seeds rules by scanning the codebase for real anti-patterns (3 layers: stack, domain, codebase). Post-bootstrap, new rules come from real incidents only. Every guardrail traces to a concrete source — bootstrap scan or production bug.
- **Any starting point.** Works with existing codebases and empty projects alike. Existing project: agent wraps workflow structure around existing code without overwriting. Empty project: Initial Planning decomposes the goal into phases and details Sprint 1.
- **Workflow evolution guard.** Before adding any new step or check: does it catch a real observed failure no existing mechanism catches? Is that failure worth the per-sprint overhead? Complexity is a cost paid on every sprint.
- **Parallel execution as optional layer.** Core workflow stays sequential and agent-agnostic. Agents with sub-agent support can layer parallel waves on top (~2-3x tokens for ~40-50% faster sprints on 4+ independent items). Serial hidden costs (context overflow → session splits) partially close the token gap.

→ Full design rationale (40 decisions): [DESIGN.md](DESIGN.md)

## For Contributors — Self-Validation

> These scripts validate the workflow template itself. Skip this section unless you're contributing to or modifying `WORKFLOW.md`.

The workflow validates itself at six levels. All scripts live in `validation/`.

| Level | Script | What it catches | When to run |
|-------|--------|----------------|-------------|
| **Structural** | `bash validation/validate-workflow.sh` | Cross-file references, numeric claims, status values, content parity, ROADMAP-DESIGN-PROMPT.md integrity, audit script content, modular adapters, workflow modes (29 checks) | After any edit to WORKFLOW.md, README.md, sprint-audit-template.sh, or ROADMAP-DESIGN-PROMPT.md |
| **Path simulation** | `bash validation/validate-paths.sh` | Decision paths exist, gap fixes intact, state transitions complete, design-first path (62 checks) | Same as above |
| **Formal model** | `bash validation/validate-model.sh` | FSM reachability/traps, decision point locations, loop termination, guard blocking (58 checks) | After adding/changing a decision point, loop, or guard in WORKFLOW.md — also update `validation/workflow-model.yaml` |
| **Cascade** | `bash validation/validate-cascade.sh` | Version consistency (workflow-version, HOOKS_VERSION, changelog), hook count parity across docs, template sync (session-start.sh, hooks-config.sh), cross-file references (18 checks) | After any edit to hooks, hook configs, README.md, DESIGN.md, or WORKFLOW-MODES.md |
| **Scenario mutation** | `bash validation/scenarios/validate-scenarios.sh` | Critical text removal detection — mutates WORKFLOW.md and verifies evidence patterns break (46 mutation tests) | After changing scenario-related WORKFLOW.md text |
| **Negative tests** | `bash validation/validate-paths.sh --self-test` and `bash validation/validate-model.sh --self-test` | Gap detection still works — intentionally breaks each fix, verifies scripts catch it (30+8 tests) | After changing validation scripts or gap-related WORKFLOW.md text |
| **Semantic** | Copy `validation/verify-workflow-semantic.md` into an AI session | Intent correctness, dead ends, user gate enforcement, data provenance (~27 questions; C and F automated, skip those) | After major workflow changes or periodically |

CI runs structural + path + model + cascade + scenario checks on every push/PR to `master`. Exit code 2 (FAIL) blocks merge; exit code 1 (WARN) is non-blocking.

```bash
# Quick local check (< 5 seconds)
bash validation/validate-workflow.sh && bash validation/validate-paths.sh && bash validation/validate-model.sh && bash validation/validate-cascade.sh && bash validation/scenarios/validate-scenarios.sh

# Full local check including negative tests
bash validation/validate-workflow.sh && bash validation/validate-paths.sh && bash validation/validate-paths.sh --self-test && bash validation/validate-model.sh && bash validation/validate-model.sh --self-test && bash validation/validate-cascade.sh && bash validation/scenarios/validate-scenarios.sh
```

## Supported Languages

The template includes audit patterns for 7 languages, available both inline in `sprint-audit-template.sh` and as modular adapters in [`checks/`](checks/).
Run `sprint-audit-template.sh --modular` to use the adapter system (auto-detects language from `EXT` variable).
Debt detection is two-tier: formalized debt (`TEMP(CORE-NNN)`, `TEMP(S…)`) is flagged as a warning; naked `TODO`/`HACK`/`FIXME` without a CORE-ID is a Close Gate blocker. Both checks are language-agnostic — no comment prefix required.

| Language | Hot Path Alloc | Cached Ref | Anti-Pattern |
|----------|---------------|-----------|-------------|
| **C#/Unity** | `new List<`, `new Dictionary<` | `Camera.main`, `GetComponent` | `AppendStructuredBuffer` |
| **TypeScript/React** | `new Array(`, spread in render | `querySelector` in loop | `dangerouslySetInnerHTML`, `any` |
| **Python** | list comprehension in hot loop | repeated `os.path.exists` | `eval()`, bare `except:` |
| **Java** | `new ArrayList<>` in loop | repeated `getBean()` | `e.printStackTrace()` |
| **Go** | `append` in tight loop | repeated `os.Getenv` | `panic()` in library code |
| **Rust** | `.clone()` in hot path | repeated `.unwrap()` | `unsafe` without comment |
| **C++** | `new`/`malloc` in loop | repeated `dynamic_cast` | raw `new` without smart ptr |

## Adaptation

| Project Size | Recommendation |
|---|---|
| **Small** (1-5 files) | Abbreviated Entry Gate (≤3 Must items, no cross-sprint deps): Phase 0 → steps 1-2 → 8 → 9b-lite → 10 → 12. Skips failure mode analysis (9a), metric sufficiency (9c), Phase 2. sprint-audit.sh optional. |
| **Medium** (5-50 files) | Full workflow. Audit script valuable at ~10+ files |
| **Large** (50+ files) | Add CI integration, per-subsystem guardrails |

| Aspect | Solo | Team |
|---|---|---|
| Branch | Sprint branch (same model) | Sprint branch (same model) |
| Commits | Per-item after D.7 (monolithic OK with TRACKING traceability) | Atomic required (per-item after D.7) |
| Review | Self-verify + AI agent | Peer review + AI agent |
| Entry Gate | Abbreviated if ≤3 Must + no deps; full otherwise | Full (phases 0-3) |
| Close Gate | Full | Full + peer sign-off |

| Starting Point | What Happens |
|---|---|
| **Existing project** (has code) | Migration mode: agent reads existing files, appends workflow structure without overwriting source code or CLAUDE.md. Whatever you're currently working on becomes Sprint 1 — no retrospective reconstruction of past work. |
| **Empty project** (no code) | Agent asks Q0 explicitly, runs Initial Planning to create first sprint |
| **Greenfield** ("make me X") | Agent decomposes goal into phases, details Sprint 1, discovers contracts |

## Workflow Modes

The same template supports three rigor levels:

| Mode | Target | Entry Gate | Hooks | Overhead |
|------|--------|-----------|-------|----------|
| **Lite** | Solo dev, small projects | Abbreviated only | Core safety (5/11) | ~5 min/gate |
| **Standard** | Most projects (default) | Full or abbreviated | All hooks (11/11) | ~15 min/gate |
| **Strict** | Teams, critical systems | Full always | All, overrides disabled | ~25 min/gate |

Set `WORKFLOW_MODE` in `.claude/hooks-config.sh`. For non-Claude agents, state the mode at session start.

> Full details: [Docs/WORKFLOW-MODES.md](Docs/WORKFLOW-MODES.md)

### Upgrading

The workflow uses a version system (v2.1+) to detect when hooks are outdated.

- **WORKFLOW.md** has `<!-- workflow-version: X.Y -->` — the canonical version.
- **`.claude/hooks-config.sh`** has `HOOKS_VERSION="X.Y"` — the installed version.
- **`session-start.sh`** compares the two at session start and warns the AI if they differ.

**To upgrade:** replace `WORKFLOW.md` with the latest version (or tell the AI: *"Update the workflow from [GitHub link]"*). The AI reads the §Changelog, backs up modified files, applies changes, and bumps `HOOKS_VERSION`. Pre-version-system projects are treated as v1.0.

> Full procedure: [WORKFLOW.md §Upgrade](WORKFLOW.md#upgrade--updating-from-a-previous-version)

### Parallel Execution (Optional)

Agents with sub-agent support (Claude Code Agent tool, etc.) can run gate phases and
implementation items in parallel waves — a coordinator delegates analysis to narrow-context
agents, then merges results.

| Phase | Serial | Parallel | Token cost |
|-------|--------|----------|------------|
| Entry Gate (per-item analysis) | ~40-60% of gate time | Wave 1 read-only + Wave 2 per-item | ~2-3x tokens |
| Implementation (independent items) | Sequential A→E per item | Per-item agents in dependency waves | ~2-3x tokens |
| Close Gate (per-item audit) | ~35-50% of gate time | Wave 1 metrics + Wave 2 FM/fitness | ~2-3x tokens |
| Sprint Close | Sequential | Not parallelized (shared-file writes) | 1x |

**Good fit:** 4+ independent items touching separate files. **Poor fit:** ≤3 items, shared-file refactors.
The AI suggests parallel execution at Entry Gate step 11 when 4+ independent items are detected — no need to remember to ask.
Sub-agents also keep implementation noise out of the coordinator's context, letting it stay focused on sprint rules, scope, and quality control.

All sprints (sequential and parallel) run on a sprint branch (`sprint-N-impl`) — main stays clean until Close Gate passes.
Parallel adds mandatory inter-wave commits. Merge overhead: 30-45% of wave time when files overlap — budget explicitly.

> Full guide: [Docs/PARALLEL-EXECUTION.md](Docs/PARALLEL-EXECUTION.md)

## Sprint Dashboard (Optional)

A standalone CLI + web dashboard for visualizing sprint status. Zero external dependencies — pure Python stdlib.

**Usage:**
```bash
sprint-workflow status              # CLI summary (one-shot snapshot)
sprint-workflow status -w           # CLI watch mode (live, auto-refreshes on file changes)
sprint-workflow status --serve      # Web dashboard (live, http://127.0.0.1:8384)
sprint-workflow status --json       # Machine-readable JSON output
sprint-workflow status /path/to/project   # Explicit project root
```

The dashboard reads `TRACKING.md`, `Roadmap.md`, and gate reports — no configuration needed. Works with any project that uses this workflow, regardless of which AI agent produced the files.

**What it shows:**
- Sprint progress (items, status counts, completion %)
- Gate status (Entry Gate, Close Gate, Sprint Close)
- Quality metrics (verification results, test coverage, findings)
- Failure analysis (predicted vs occurred, guardrail effectiveness)
- Cross-sprint trends (rework rate, prediction accuracy, performance baselines)
- Priority distribution from Roadmap (Must/Should/Could)

The web dashboard (`--serve`) auto-refreshes every 2 seconds. CLI watch mode (`-w`) refreshes on file changes.

## Examples

See [`examples/`](examples/) for adaptations and playbooks:

- [`demo-todo-app/`](examples/demo-todo-app/) — **End-to-end sprint walkthrough** with all output files (TypeScript/Express)
- [`unity-csharp/`](examples/unity-csharp/) — Real-world C#/Unity game project
- [`cursor-playbook/`](examples/cursor-playbook/) — Cursor adaptation with `.cursor/rules/*.mdc`
- [`copilot-playbook/`](examples/copilot-playbook/) — GitHub Copilot adaptation with `copilot-instructions.md`
- [`windsurf-playbook/`](examples/windsurf-playbook/) — Windsurf/Cascade adaptation with `.windsurf/rules/*.md`
- [`cline-playbook/`](examples/cline-playbook/) — Cline adaptation with `.clinerules`
- [`codex-playbook/`](examples/codex-playbook/) — OpenAI Codex CLI adaptation with `AGENTS.md` + `CLAUDE.md` fallback
- [`gemini-playbook/`](examples/gemini-playbook/) — Gemini CLI adaptation with `GEMINI.md` + `@import`

## Observed Results

Measurements from real projects using this workflow.

| Metric | Before | After | Source |
|--------|--------|-------|--------|
| Close Gate AI context | ~4000 lines | ~500 lines | sprint-audit.sh pre-filters mechanical issues |
| Unintended scope changes | Frequent | 0 | "AI flags, user decides" rule |
| Obsolete item detection | Manual review | Automatic | Entry Gate Step 8 strategic alignment |
| Repeat bugs from known issues | Recurring | 0 after guardrail | Prior experience encoded as Day 0 rules |
### Known Trade-offs

- **Token cost per session start:** +2-3% of 200K context window at S20 (plateaus due to archive rules)
- **Bootstrap overhead:** ~15-30 min for first sprint setup (front-loaded, amortized over project lifetime)
- **Gate overhead:** ~5-25 min per gate depending on mode (Lite → Strict)
- **Parallel execution token cost:** ~2-3x total tokens vs serial (mitigated by avoided session splits on long sprints)
- **Parallel merge overhead:** 30-45% of wave time when file overlap exists (group overlapping items to minimize)
- **Learning curve:** Agent needs ~1 sprint to internalize the workflow patterns
- **Not for throwaway code:** If the project won't survive past one session, the overhead exceeds the value

> These results are from the origin project. More data points welcome — submit results via PR.

## Origin

This workflow was developed during a production project.
It evolved over multiple sprints, accumulating guardrail rules,
automated audit scripts, and hundreds of AI agent sessions.

## License

MIT — see [LICENSE](LICENSE).
