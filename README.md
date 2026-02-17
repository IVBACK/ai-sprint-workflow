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
                  │  (12 steps)  │  Strategic alignment + dependency check
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ IMPLEMENTATION│  "Are we building it correctly?"
                  │    LOOP      │  Pre-code guardrails → code → self-verify → test
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │  CLOSE GATE  │  "Did we build it correctly?"
                  │  (5 phases)  │  Automated scan + manual audit + item-level tests
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ SPRINT CLOSE │  Archive, baseline capture, next sprint
                  └──────────────┘
```

## Quick Start

1. Download `TEMPLATE.md` into your project root:
   ```bash
   curl -O https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/TEMPLATE.md
   ```
2. Start an AI coding session
3. Tell the agent: "Read TEMPLATE.md and bootstrap this project"
4. The agent will:
   - Scan your project (language, framework, build system, test framework)
   - Ask 14 discovery questions (skipping ones it can infer from project files)
   - Create `CLAUDE.md`, `TRACKING.md`, `Docs/CODING_GUARDRAILS.md`, `Docs/Planning/Roadmap.md`, `Tools/sprint-audit.sh`
   - If no sprint plan exists: run Initial Planning (decompose goal into phases, detail Sprint 1 only)
   - Adapt audit script patterns to your detected language
   - Move `TEMPLATE.md` to `Docs/SPRINT_WORKFLOW.md` as the permanent workflow reference
   - Confirm the setup with you before writing any feature code
5. Start your first sprint

### Bootstrap Steps (9 total)

```
1. Scan project     → detect language, framework, build system, test framework
2. Discovery Q's    → 14 questions (batch, skip inferrable ones)
3. Create structure → CLAUDE.md, TRACKING.md, GUARDRAILS.md, Roadmap.md, Tools/
4. Initial Planning → if no sprint plan exists: goal → phases → detail S1 → contracts
5. Populate CLAUDE.md with project context
6. Populate GUARDRAILS.md with framework-specific rules
7. Adapt audit script to detected language
8. Move TEMPLATE.md → Docs/SPRINT_WORKFLOW.md
9. Confirm with user
```

Empty project? Step 1 is skipped — Discovery Questions cover language/framework.

### Discovery Questions (14)

Questions are asked in a single batch. Answers inferrable from project files
(e.g., `package.json` → TypeScript + Jest) are stated as inferred and confirmed.

| Category | Questions |
|----------|-----------|
| **Project Shape** | Q0: Language/framework, Q1: Solo or team, Q2: Sprint scope size, Q3: Existing roadmap, Q4: Performance-sensitive, Q5: Target platforms |
| **Infrastructure** | Q6: CI/CD pipeline, Q7: Test framework, Q8: Existing linter/standards, Q9: Known tech debt |
| **Workflow Preferences** | Q10: Docs language, Q11: Commit style, Q12: Immutable contracts, Q13: Anything else the AI should know |

Q0 auto-detects from project files; asks explicitly if the project is empty.
Q13 is an open-ended catch-all for context that doesn't fit the predefined categories.

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
│       └── Roadmap.md            # Sprint plan (Must/Should/Could)
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

## Key Design Decisions

- **AI flags, user decides.** When a gate check fails, the AI presents evidence and options. It never unilaterally changes sprint scope.
- **Sprint scope, not duration.** A sprint is 3-12 items, not a calendar week. AI can finish a "sprint" in hours.
- **Guardrails grow from bugs.** No hypothetical rules. Every guardrail traces to a real production issue.
- **Automated + manual review.** `sprint-audit.sh` catches grep-detectable patterns (~30 lines of output). Manual review catches semantic issues (logic errors, resource leaks, design flaws).
- **Any starting point.** Works with existing codebases (scans and wraps structure around existing code) and empty projects alike. If no sprint plan exists, an Initial Planning step decomposes the goal into phases, details Sprint 1, and discovers immutable contracts.
- **Metric gap detection.** Entry Gate step 9c: if a roadmap item has no metric gate, the AI proposes one before the sprint starts. No item ships without a measurable success criterion.
- **Item-level test coverage.** Close Gate Phase 4b: every completed item (Must + Should + Could) must have a behavioral test — not just file-level test existence. Missing test → write one or document why untestable.
- **Performance baseline tracking.** Sprint Close step 5: key metrics are recorded to `TRACKING.md` each sprint. Regressions vs. the previous sprint are flagged automatically.
- **Algorithmic invariant checks.** Entry Gate step 9b: for items involving algorithms or mathematical systems, the verification plan must include invariant tests (properties that must always hold), not just "does it run?" checks.
- **Failure mode analysis.** Entry Gate step 9d + Close Gate Phase 0: every Must item's failure modes are categorized as direct (item-internal), interaction (cross-system), or stress/edge-case (extreme-condition). Each category requires at least one identified mode with a corresponding metric or test. "Has a metric" ≠ "has the right metrics."
- **Single source of truth for gates.** `SPRINT_WORKFLOW.md` is the authoritative source for Entry Gate, Close Gate, and Sprint Close procedures. `CLAUDE.md` references it directly at sprint boundaries. `CODING_GUARDRAILS.md` keeps a brief pointer, not a duplicate.

## Supported Languages

The template includes audit patterns for 7 languages.
Scaffolding detection (TODO, HACK, FIXME, TEMP tags) is language-agnostic — no comment prefix required.

| Language | Hot Path Alloc | Cached Ref | Anti-Pattern |
|----------|---------------|-----------|-------------|
| **C#/Unity** | `new List<`, `new Dictionary<` | `Camera.main`, `GetComponent` | `AppendStructuredBuffer` |
| **TypeScript** | `new Array(`, spread in render | `querySelector` in loop | `dangerouslySetInnerHTML`, `any` |
| **Python** | list comprehension in hot loop | repeated `os.path.exists` | `eval()`, bare `except:` |
| **Java** | `new ArrayList<>` in loop | repeated `getBean()` | `e.printStackTrace()` |
| **Go** | `append` in tight loop | repeated `os.Getenv` | `panic()` in library code |
| **Rust** | `.clone()` in hot path | repeated `.unwrap()` | `unsafe` without comment |
| **C++** | `new`/`malloc` in loop | repeated `dynamic_cast` | raw `new` without smart ptr |

## Adaptation

| Project Size | Recommendation |
|---|---|
| **Small** (1-5 files) | Skip Entry Gate Phase 2, skip sprint-audit.sh |
| **Medium** (5-50 files) | Full workflow. Audit script valuable at ~10+ files |
| **Large** (50+ files) | Add CI integration, per-subsystem guardrails |

| Aspect | Solo | Team |
|---|---|---|
| Commits | Monolithic OK (with TRACKING traceability) | Atomic required |
| Review | Self-verify + AI agent | Peer review + AI agent |
| Entry Gate | Abbreviated (Phase 1 + 3) | Full (all 3 phases) |
| Close Gate | Full | Full + peer sign-off |

| Starting Point | What Happens |
|---|---|
| **Existing project** (has code) | Agent scans files, infers answers, creates structure around existing code |
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
