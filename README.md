# AI Sprint Workflow

A sprint workflow template designed for human + AI coding agent collaboration.

Drop `TEMPLATE.md` into any project and the AI agent bootstraps the full structure:
tracking, guardrails, audit scripts, and sprint gates — all adapted to your stack.

Works with existing projects and greenfield (empty) projects alike.

### Compatibility

| Agent | Status |
|-------|--------|
| **Claude Code** | Tested |
| Cursor | Should work (untested) |
| GitHub Copilot | Should work (untested) |
| Windsurf | Should work (untested) |
| Any agent that reads markdown | Should work (untested) |

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

When in doubt: try it on one sprint. If the Entry Gate feels like bureaucracy for your project size, you're probably in the "not a good fit" category.

## Why This Exists

AI coding agents (Claude Code, Cursor, Copilot, etc.) are powerful but stateless.
Every session starts from zero. This workflow solves three problems:

1. **Context loss** — Structured files (`CLAUDE.md`, `TRACKING.md`, `GUARDRAILS.md`) give the agent instant context on every session start.
2. **Quality drift** — Three gates (Entry, Self-Verification, Close) catch mistakes before they compound.
3. **Scope creep** — Must/Should/Could prioritization and strategic alignment checks keep sprints focused.

## How It Works

```
                  ┌──────────────┐
                  │  ENTRY GATE  │  "Are we building the right thing?"
                  │(ph0-3,12 st)│  Sprint detail + alignment + dependency check
                  └──────┬───────┘  ◄─── Auto-Detection Checkpoint 1 (metric regression)
                         │               Auto-Detection Checkpoint 2 (failure pattern)
                         ▼
                  ┌──────────────┐
                  │ IMPLEMENTATION│  "Are we building it correctly?"
                  │    LOOP      │  Pre-code guardrails → code → self-verify → test → run all tests
                  └──────┬───────┘  ◄─── Auto-Detection Checkpoint 3 (broken past-sprint output)
                         │
                         ▼
                  ┌──────────────┐
                  │  CLOSE GATE  │  "Did we build it correctly?"
                  │  (5 phases)  │  Automated scan + spec-driven audit + item-level tests
                  └──────┬───────┘  ◄─── Auto-Detection Checkpoint 4 (Must item unverifiable)
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

**Rewrite or complex project with prior experience?** Start with `ROADMAP-DESIGN-PROMPT.md` → then bootstrap. See [Want a richer roadmap?](#want-a-richer-roadmap-design-it-first) below.
**Everything else:** Go straight to bootstrap.

**Already in an AI session (recommended):**

Tell the agent:
> "Fetch https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/TEMPLATE.md and bootstrap this project."

The agent fetches the file and runs the bootstrap directly — no manual download needed.

**Prefer to download first:**
```bash
curl -O https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/TEMPLATE.md
```
Then tell the agent: "Read TEMPLATE.md and bootstrap this project."

**Either way, the agent will:**
- Detect whether this is a greenfield or existing project (Step 0)
- Scan your project (language, framework, build system, test framework — large projects capped at 50 files)
- Ask 15 discovery questions (skipping ones it can infer from project files)
- Create `CLAUDE.md`, `TRACKING.md`, `Docs/CODING_GUARDRAILS.md`, `Docs/Planning/Roadmap.md`, `Tools/sprint-audit.sh`
  - Existing project: skips files that already exist; asks before touching `TRACKING.md`, `Roadmap.md`, `GUARDRAILS.md`
- If no sprint plan exists: run Initial Planning (decompose goal into phases, detail Sprint 1 only)
  - Existing project: whatever you're currently working on becomes Sprint 1 — no retrospective reconstruction
- Adapt audit script patterns to your detected language (multi-language projects supported)
- Create `Docs/SPRINT_WORKFLOW.md` from `TEMPLATE.md` (strips bootstrap-only sections; AI reads section-by-section at sprint boundaries, not all at once)
- Confirm the setup with you before writing any feature code

Start your first sprint — the agent will ask before running Entry Gate.
For subsequent sessions: tell the agent **"Continue sprint N"** or **"Resume"**.

### Want a richer roadmap? Design it first.

The bootstrap produces a lean roadmap skeleton. For complex projects (rewrites, large scope, prior
lessons to capture), design the roadmap in a separate focused session before bootstrapping:

1. Tell the agent:
   > "Fetch https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/ROADMAP-DESIGN-PROMPT.md and design the roadmap."
   — Agent asks about goals, prior learnings, locked contracts, performance targets, phases
   — Produces a rich `Docs/Planning/Roadmap.md` through conversation
2. Then bootstrap:
   > "Fetch https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/TEMPLATE.md and bootstrap this project."
   — Bootstrap detects the existing `Roadmap.md` → skips Initial Planning automatically

### Bootstrap Steps (10 total: Step 0 + steps 1–9)

```
0. Detect state    → source code or workflow files? → Greenfield or Migration mode
                     Migration: read conflict rules before touching any file
1. Scan project    → detect language, framework, build system, test framework
2. Discovery Q's   → 15 questions (batch, skip inferrable ones)
3. Create structure→ CLAUDE.md, TRACKING.md, GUARDRAILS.md, Roadmap.md, Tools/
                     Migration: skip files that already exist; ask before touching
4. Initial Planning→ if no sprint plan exists: goal → phases → detail S1 → contracts
                     Migration: current work = Sprint 1 (no retrospective)
5. Populate CLAUDE.md with project context
6. Populate GUARDRAILS.md with framework-specific rules
7. Adapt audit script to detected language
                     Migration: call existing CI commands, don't duplicate checks
8. TEMPLATE.md → Docs/SPRINT_WORKFLOW.md (strip bootstrap sections)
9. Confirm with user
```

Empty project? Step 1 is skipped — Discovery Questions cover language/framework.

### Discovery Questions (15)

Questions are asked in a single batch. Answers inferrable from project files
(e.g., `package.json` → TypeScript + Jest) are stated as inferred and confirmed.

| Category | Questions |
|----------|-----------|
| **Project Shape** | Q0: Language/framework, Q1: Solo or team, Q2: Sprint scope size, Q3: Existing roadmap, Q4: Performance-sensitive, Q5: Target platforms |
| **Infrastructure** | Q6: CI/CD pipeline, Q7: Test framework, Q8: Existing linter/standards, Q9: Known tech debt |
| **Workflow Preferences** | Q10: Docs language, Q11: Commit style (skipped if VCS=none), Q12: Immutable contracts, Q13: Anything else the AI should know, Q14: Critical Axis |

Q0 auto-detects from project files; asks explicitly if the project is empty. If user is undecided, AI proposes options with trade-offs.
VCS is auto-detected (`.git`, `.svn`, `.hg`). Result recorded in `CLAUDE.md`. If VCS=none: Q11 skipped, Close Gate Phase 1b uses Entry Gate implementation notes instead of `git diff`, TRACKING.md recovery falls back to user verification.
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

```
your-project/
├── CLAUDE.md                     # AI session context (auto-loaded every session)
├── TRACKING.md                   # Single source of truth for item status
├── Docs/
│   ├── CODING_GUARDRAILS.md      # Engineering rules from real bugs
│   ├── LESSONS_INDEX.md          # Bug → rule traceability (starts empty)
│   ├── SPRINT_WORKFLOW.md        # Workflow reference (moved from TEMPLATE.md)
│   └── Planning/
│       ├── Roadmap.md            # Sprint plan (Must/Should/Could)
│       └── S<N>_ENTRY_GATE.md    # Entry Gate report (lives during sprint, deleted at close)
└── Tools/
    └── sprint-audit.sh           # Automated close gate checks
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
- **Guardrails grow from bugs.** No hypothetical rules. Every guardrail traces to a real production issue.
- **Any starting point.** Works with existing codebases and empty projects alike. Existing project: agent wraps workflow structure around existing code without overwriting. Empty project: Initial Planning decomposes the goal into phases and details Sprint 1.
- **Workflow evolution guard.** Before adding any new step or check: does it catch a real observed failure no existing mechanism catches? Is that failure worth the per-sprint overhead? Complexity is a cost paid on every sprint.

→ Full design rationale (35 decisions): [DESIGN.md](DESIGN.md)

## Self-Validation

The workflow validates itself at three levels:

| Level | Script | What it catches | When to run |
|-------|--------|----------------|-------------|
| **Structural** | `bash validate-workflow.sh` | Cross-file references, numeric claims, status values, content parity, ROADMAP-DESIGN-PROMPT.md integrity, audit script content (26 checks) | After any edit to TEMPLATE.md, README.md, sprint-audit-template.sh, or ROADMAP-DESIGN-PROMPT.md |
| **Path simulation** | `bash validate-paths.sh` | Decision paths exist, gap fixes intact, state transitions complete, design-first path (44 checks) | Same as above |
| **Negative tests** | `bash validate-paths.sh --self-test` | Gap detection still works — intentionally breaks each fix, verifies script catches it (12 tests) | After changing validate-paths.sh or gap-related TEMPLATE.md text |
| **Semantic** | Copy `verify-workflow-semantic.md` into an AI session | Logic gaps, dead ends, missing user approvals, information flow, state machine coverage (31 questions) | After major workflow changes or periodically |

CI runs structural + path checks on every push/PR to `master`. Exit code 2 (FAIL) blocks merge; exit code 1 (WARN) is non-blocking.

```bash
# Quick local check (< 5 seconds)
bash validate-workflow.sh && bash validate-paths.sh

# Full local check including negative tests
bash validate-workflow.sh && bash validate-paths.sh && bash validate-paths.sh --self-test
```

## Supported Languages

The template includes audit patterns for 7 languages.
Scaffolding detection (TODO, HACK, FIXME, TEMP tags) is language-agnostic — no comment prefix required.

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
| Commits | Monolithic OK (with TRACKING traceability) | Atomic required |
| Review | Self-verify + AI agent | Peer review + AI agent |
| Entry Gate | Abbreviated if ≤3 Must + no deps; full otherwise | Full (phases 0-3) |
| Close Gate | Full | Full + peer sign-off |

| Starting Point | What Happens |
|---|---|
| **Existing project** (has code) | Migration mode: agent reads existing files, appends workflow structure without overwriting source code or CLAUDE.md. Whatever you're currently working on becomes Sprint 1 — no retrospective reconstruction of past work. |
| **Empty project** (no code) | Agent asks Q0 explicitly, runs Initial Planning to create first sprint |
| **Greenfield** ("make me X") | Agent decomposes goal into phases, details Sprint 1, discovers contracts |

## Examples

See [`examples/`](examples/) for real-world adaptations:

- [`unity-csharp/`](examples/unity-csharp/) — Unity 6 + URP game project (anonymized)

## Origin

This workflow was developed during a 24-sprint procedural planet generation project
(Unity 6 + URP, SDF + Marching Cubes). It evolved over 50+ guardrail rules,
3 automated audit scripts, and several hundred AI agent sessions.

## License

MIT — see [LICENSE](LICENSE).
