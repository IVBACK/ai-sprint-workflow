# AI-Assisted Sprint Workflow Template
<!-- workflow-version: 2.1 -->

A project-agnostic sprint workflow designed for human + AI agent collaboration.
Copy this file into any project and follow the setup instructions.
The AI agent reads this document and bootstraps the project structure automatically.

> **Team convention:** All references to `TRACKING.md` throughout this document
> also apply to per-person tracking files (`TRACKING-[name].md`) when using
> team topology. Read your own tracking file unless stated otherwise.
> Similarly, `sprint-N-impl` branch references become `sprint-N-name-impl` in team mode.
> See [Docs/TEAM-GUIDE.md](Docs/TEAM-GUIDE.md) for details.

---

## Quick Start — AI Agent Bootstrap

0. Detect project state (before doing anything else):
   Check for: existing source code files, `CLAUDE.md`, `TRACKING.md`, `Docs/Planning/Roadmap.md`, CI/CD config, build files.
   - **No source code, no workflow files** → Greenfield mode: proceed to step 1.
   - **Source code exists or any workflow file exists** → Migration mode: read "Migration Rules" below, then proceed to step 1.

---

### Migration Rules (read before step 1 if existing project detected)

**File conflict rules — apply only when the file already exists:**
If a file does not exist, create it per step 3 — no confirmation needed.

| File | If it already exists |
|------|---------------------|
| `CLAUDE.md` | **Never overwrite.** Read it first. Warn if apparent secrets found (API keys, IPs) and confirm it is gitignored. Append only sprint sections not already present. Preserve all existing content. |
| `TRACKING.md` | Skip creation. Ask user before touching. If Q1 = team and only `TRACKING.md` exists (solo → team migration): ask user how to split existing items among team members, then create per-person files and migrate items accordingly. Keep original `TRACKING.md` as backup until first sprint completes. |
| `Docs/Planning/Roadmap.md` | Skip creation. Ask user before touching. |
| `Docs/CODING_GUARDRAILS.md` | Skip creation. Ask user before touching. |
| `Tools/sprint-audit.sh` | Skip creation. Ask user before replacing. |
| `Docs/SPRINT_WORKFLOW.md` | Skip if it exists. |

**Existing CI/CD:** Do NOT duplicate existing quality checks in `sprint-audit.sh`.
Call the existing build commands instead. Do not modify CI pipeline files without explicit user confirmation.

**Before creating any files:** If VCS exists, ask whether the new workflow files should be git-tracked or gitignored.

**Never:**
- Overwrite existing source code
- Overwrite `CLAUDE.md` without reading and preserving existing content
- Modify CI pipeline files without explicit user confirmation

---

1. Scan the project to determine: language, framework, build system, test framework
   *(Empty project? Skip to step 2 — Discovery Questions will cover language/framework.)*
   *(Large project (100+ files)? Limit scan to root configs, top-level directories, and up to 50 source files. Infer stack from config files (`package.json`, `Cargo.toml`, `pom.xml`, etc.) — do not read every file.)*
2. Ask the Discovery Questions below (skip any already answered by project files)
3. Create the file structure listed in §Setup below (skip files that already exist).
   If Q1 = team: see [Docs/TEAM-GUIDE.md](Docs/TEAM-GUIDE.md) §Bootstrap adjustment for per-person
   TRACKING files and branch naming. Solo: create a single `TRACKING.md`.
   **Ensure `.gitignore` includes secret file patterns** (create if missing, append if exists):
   ```
   .env
   .env.*
   !.env.example
   *.key
   *.pem
   *.p12
   credentials.json
   secrets.yaml
   secrets.yml
   .claude/hooks-config.local.sh
   .claude/hooks/*.local.sh
   ```
   This prevents API keys and secrets from being committed to git.
   If a `.gitignore` already exists, append only missing entries — do not overwrite.
4. If Roadmap.md is empty or has no sprint items, run Initial Planning:
   *(Design-first alternative: if the user ran a `ROADMAP-DESIGN-PROMPT.md` session beforehand,
   Roadmap.md already exists — skip this step entirely and proceed to step 5.)*
   **Exception — existing project (migration):** If the project has existing source code but no
   Roadmap.md, it was not using this workflow before. The workflow starts now — do not reconstruct
   past work. Whatever the user is currently working on becomes **Sprint 1**.
   a. Ask user to describe project goal
   b. Ask: "What are you working on right now?" and "What's next after that?"
   c. Propose high-level phases (titles only)
   d. Detail Sprint 1 only: Must/Should/Could items with CORE-### IDs
      (later sprints stay as one-line sketches — they will be detailed when reached)
      Team: mark items with assignee (`@name`).
   e. Assign CORE-### IDs. If TRACKING files already exist with CORE-### IDs, continue from the
      highest existing ID. Never reuse an existing ID.
      Roadmap.md covers Sprint 1 forward only — never backward.
   f. Identify immutable contracts → feed into CLAUDE.md §Immutable Contracts
   g. Present plan to user for approval before proceeding
   h. After approval: populate TRACKING file(s) with Sprint 1 items (status: `open`).
      Team: populate each person's TRACKING file with their assigned items only.
5. Populate CLAUDE.md with project-specific context discovered during scan + answers.
   §Project Summary `Team:` field: if Q1 = solo → `Team: solo`. If Q1 = team → `Team: [names]`
   (e.g., `Team: Dev-A, Dev-B`). The AI will ask which team member it's working with at each
   session start (see §Quick Start).
   §Project Summary `Cross-LLM Audit:` field: if Q15 = yes → `Cross-LLM Audit: enabled (run setup-audit.sh)`.
   If Q15 = no → `Cross-LLM Audit: disabled (enable later: bash .claude/setup-audit.sh)`.
   *(Design-first path: if step 4 was skipped, read Roadmap.md §Non-Negotiable Contracts → populate CLAUDE.md §Immutable Contracts.)*
6. Populate CODING_GUARDRAILS.md — project-aware guardrail seeding:
   a. Scan existing source code for concrete risk patterns in three layers:
      - **Stack-specific:** known footguns for the detected framework/language
        (e.g., Flask: `| safe` XSS, SQLAlchemy: N+1 lazy load, Rails: mass assignment,
         React: dangerouslySetInnerHTML, Go: unchecked error returns)
      - **Domain-specific:** risks inherent to the project's business domain
        (e.g., e-commerce: float money math, stock race conditions;
         healthcare: PII logging, consent tracking; fintech: idempotency, double-spend;
         SaaS: tenant isolation, rate limiting)
      - **Codebase-specific:** actual anti-patterns found in this project's code right now
        (grep for real instances — `except Exception`, hardcoded secrets, unbounded queries, etc.)
   b. For each finding, write a guardrail rule with a code example from this project
      (use actual file paths and patterns found in the scan — not generic placeholders)
   c. Only include rules relevant to code that exists or is planned for Sprint 1
      — do not preload rules for features that don't exist yet
   d. Present findings to user: "Found N risk patterns in [layer breakdown]. Review before proceeding?"
      User may remove rules they consider irrelevant. Do not silently populate.
      User may also skip the entire scan: "Skip — I'll add guardrails as bugs arise."
      If skipped: create CODING_GUARDRAILS.md with the structural template only (Section Index,
      Entry Gate / Close Gate pointers, empty Anti-Pattern Quick Reference table) — no rules.
      Log in TRACKING.md Change Log: "Bootstrap guardrail scan: skipped by user."
   e. Rules added at bootstrap are marked `source: "bootstrap scan"` in LESSONS_INDEX
      to distinguish them from incident-driven rules added during sprints
   *(Empty project with no source code? Write only stack-specific rules for the chosen framework.
   Domain-specific and codebase-specific layers are skipped — they will emerge during Sprint 1.)*
7. Adapt `Tools/sprint-audit.sh`: uncomment checks for the detected language, set `SRC_DIR`, `TEST_DIR`, `EXT`
   *(Multi-language project? Set `EXT` to the primary language. Add secondary language checks as additional `check` calls with explicit `--include` patterns. Use separate `SRC_DIR_*` variables if source trees differ.)*
8. Create `Docs/SPRINT_WORKFLOW.md` from this file:
   - Copy this file to `Docs/SPRINT_WORKFLOW.md`
   - Strip these bootstrap-only sections:
     • "Quick Start — AI Agent Bootstrap" (including Discovery Questions)
     • "File Templates"
     • "Generic sprint-audit.sh Template"
     • "Checklist — Is Your Project Set Up?"
8.5. **[Claude Code only — skip if using a different agent]** Create hook infrastructure:
   - `.claude/hooks-config.sh` — feature flags (enable/disable per hook)
   - `.claude/settings.json` — hook registrations
   - `.claude/hooks/protect-claude.sh` — blocks `Write` to `CLAUDE.md`
   - `.claude/hooks/protect-secrets.sh` — blocks `Read` and `Bash` access to `.env`, `.key`, `.pem`, `credentials.json` and other secret files. API keys are managed by hooks (e.g., `cross-llm-audit.sh`) — the AI must never see them directly.
   - `.claude/hooks/validate-tracking.sh` — validates TRACKING.md status values after every edit
   - `.claude/hooks/validate-id-uniqueness.sh` — detects duplicate `CORE-###` IDs
   - `.claude/hooks/session-start.sh` — injects session start protocol context
   - `.claude/hooks/entry-gate-session.sh` — injects mandatory session boundary after Entry Gate
   - `.claude/hooks/detect-audit-signals.sh` — CP1+CP2: metric regression and recurring failure detection at session start
   - `.claude/hooks/detect-test-regression.sh` — CP3: surfaces test failures from Bash output
   - `.claude/hooks/validate-close-gate.sh` — CP4: validates Close Gate report, checks for unverified must items
   - `.claude/hooks/validate-sprint-close.sh` — validates Sprint Close report sections (retrospective, baseline, handoff)
   - `.claude/hooks/cross-llm-audit.sh` — **(optional)** sends code changes to an external LLM for independent review. Disabled by default — requires `ENABLE_CROSS_AUDIT=true` + API key. If user answered Yes to Q15, remind them: *"Run `bash .claude/setup-audit.sh` in your terminal to complete cross-audit setup."* See [Docs/CROSS-LLM-AUDIT.md](Docs/CROSS-LLM-AUDIT.md).
   - `.claude/setup-audit.sh` — **(always create)** interactive terminal script for cross-LLM audit setup. Collects API key via hidden input (`read -s`), writes to `.env`. Even if the user said No to Q15 — include the script so they can enable it later without re-bootstrapping.
   Make all hook scripts executable (`chmod +x .claude/hooks/*.sh .claude/setup-audit.sh`).
   File contents: see §File Templates → "Claude Code Hook Templates".
   These hooks enforce WORKFLOW.md rules mechanically. Other agents are unaffected — `.claude/` is Claude Code-specific.
   **⚠ If Step 8.5 is skipped (non-Claude Code agent):** Do NOT set up cross-LLM audit (Q15).
   Without `protect-secrets.sh`, there is no mechanical barrier preventing the AI from reading
   `.env` and exposing the API key. Skip Q15 and do not create `setup-audit.sh`.
9. Confirm the setup with the user:
   - Verify against §Checklist — Is Your Project Set Up? (end of this file)
   - If Q15 = yes: remind user to run `bash .claude/setup-audit.sh` in their terminal
   - Do NOT silently start Entry Gate — wait for explicit confirmation.

### Discovery Questions

Ask these before creating project files. Skip any that can be inferred from
existing project files (e.g., `package.json` reveals language + test framework).

**Project Shape:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 0 | Language and framework? ¹ | Audit script, guardrails, test conventions | Auto-detect; empty project → ask explicitly ¹ |
| 1 | Solo developer or team? If team: how many people and their names? | Commit policy, review gate, TRACKING file naming | Solo |
| 2 | Sprint scope size? (small: 3-5 / medium: 5-8 / large: 8-12) — an item = one deliverable behavior (a feature, a fix, a refactor), not a subtask ² | Entry gate scope threshold | Medium (5-8) |
| 3 | Existing roadmap or task list? (No / Yes / Scattered) ³ | Avoid duplicate planning docs | No → create Roadmap.md; Yes → validate IDs only ³ |
| 4 | Performance-sensitive? (game, real-time, HFT) | Profiling rules, hot path checks | No |
| 5 | Target platforms? (web, mobile, desktop, embedded) | Platform-specific guardrails | Desktop |

> ¹ **Q0 details:** Multi-language projects: list primary + secondary. If user is undecided,
> propose 2-3 options with trade-offs and let user choose. Do not proceed without a language
> decision — it gates audit script, guardrails, and test setup.
>
> ² **Q2 details:** An "item" = one deliverable behavior (a feature, a fix, a refactor).
> Not a subtask or a line of code.
>
> ³ **Q3 details:**
> "Yes" = Roadmap.md already exists with Must/Should/Could format and CORE-### IDs → validate format and IDs only.
> "Scattered" = any other source or format (GitHub Issues, Notion, plain bullets, etc.) → AI extracts items
> from user-provided source, converts to Must/Should/Could format in Roadmap.md, user confirms.

> **Note on sprint duration:** With AI-assisted development, calendar time is
> unreliable for scoping. A "1-week sprint" may complete in hours with an AI agent.
> Sprints are defined by **scope** (number of Must items + complexity), not by
> calendar time. The close gate runs when Must items are done, regardless of
> whether that took 2 hours or 2 weeks.

**Infrastructure:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 6 | CI/CD pipeline exists? (GitHub Actions, Jenkins, etc.) | Wire sprint-audit.sh into CI or keep manual | No → manual only |
| 7 | Test framework in use? (Jest, pytest, NUnit, etc.) ⁴ | Test coverage gap check pattern | Auto-detect from config ⁴ |
| 8 | Existing coding standards or linter config? | Avoid conflicting guardrails | No → start fresh |
| 9 | Any known tech debt or recurring bugs? | Seed initial guardrails from real issues | No → guardrails start empty |

> ⁴ **Q7 details:** If none detected and none specified → ask user: "Set up [recommended
> framework for detected language] now, or defer testing to Sprint 2?" If deferred: Close
> Gate Phase 4 logs "no test framework" as known gap with target sprint.

> **VCS auto-detect:** Scan for `.git`, `.svn`, `.hg` at project root.
> Record result as `VCS: git | svn | none` in CLAUDE.md §Project Summary.
> If VCS=none: skip Q11 (commit style); Phase 1b uses Entry Gate notes
> instead of `git diff`; TRACKING.md recovery falls back to user verification.
>
> **VCS scope note:** All branch, commit, merge, and tag commands in this workflow are
> written for **git**. SVN and Hg are detected so VCS presence is recorded, but
> the workflow does not provide equivalent command sequences for them. SVN/Hg users
> should adapt the git commands to their VCS semantics (e.g., SVN branches as directory
> copies, Hg bookmarks for branch equivalents). Community contributions for SVN/Hg
> command mappings are welcome — see CONTRIBUTING.md.

**Workflow Preferences:**

| # | Question | Why it matters | Default if unanswered |
|---|----------|---------------|----------------------|
| 10 | Language for docs and commit messages? | Consistency across project | English |
| 11 | Preferred commit style? (conventional, free-form) ⁵ | Commit message format in rules | Free-form — **skip if VCS=none** |
| 12 | Anything that must NEVER change? (API contracts, data formats) | Seed "Immutable Contracts" in CLAUDE.md | None → discover during implementation ⁶ |
| 13 | Anything else the AI should know? (e.g., recurring pain points, integration constraints, team conventions, things that burned you before) | Catch requirements not covered above | None |
| 14 | What is this project's #1 non-negotiable quality axis? (security / performance / reliability / correctness / other: ...) | Sets Critical Axis — findings in this category can never be silently deferred | Infer from domain: payment/auth → security; game/realtime → performance; medical/finance → correctness |
| 15 | Enable Cross-LLM Audit? ⁷ *(Claude Code only — skip if Step 8.5 was skipped)* | Catches blind spots via independent review | No → skip. Yes → run `bash .claude/setup-audit.sh` after bootstrap ⁷ |

> ⁵ **Q11 details:** Only ask if VCS≠none. If VCS=none, skip entirely — no commits exist.
>
> ⁶ **Q12 details:** "None identified yet — to be discovered during implementation" is valid
> for greenfield projects. Do not invent artificial contracts.
>
> ⁷ **Q15 details:** **Prerequisite: Step 8.5 must have been completed** (Claude Code hooks
> are in place). Cross-LLM audit requires `protect-secrets.sh` to mechanically prevent
> the AI from reading `.env` (which contains the API key). Without this hook, there is
> no protection — the AI could read the key and expose it. If the user is not using
> Claude Code, skip Q15 entirely and do NOT create cross-LLM audit infrastructure.
>
> When asking Q15, **explain what it does before asking:**
> *"Cross-LLM Audit adds an automated second opinion to your workflow. Every ~5 code
> changes, a second AI (like GPT-4o, a local Ollama model, etc.) silently reviews the
> diff for bugs, security issues, and blind spots. Results appear inline — I'll present
> both my assessment and the external review, and you decide what to act on.
> Cost depends on the model — local models (Ollama, LM Studio) are free, cloud APIs
> charge per token (see your provider's pricing). Want to enable it?"*
>
> **API keys must NEVER be pasted into the AI conversation.** If the user says yes:
> *"Run this command in your terminal after bootstrap completes: `bash .claude/setup-audit.sh`
> — it will walk you through provider selection, explain each option, and securely
> collect your API key. The key never enters our conversation."*
> The setup script writes to `.env` (git-ignored). The AI never sees the key.
> See [Docs/CROSS-LLM-AUDIT.md](Docs/CROSS-LLM-AUDIT.md) for details.

**Workflow Mode Recommendation:** After collecting answers, recommend a workflow mode
based on project analysis. State the recommendation and let the user confirm:
- **Lite** → Solo dev + small project (≤10 files) or rapid prototyping
- **Standard** → Most projects (default)
- **Strict** → Team + production systems, high-risk domains

See [Docs/WORKFLOW-MODES.md](Docs/WORKFLOW-MODES.md) for full comparison.
Set the chosen mode in `.claude/hooks-config.sh` → `WORKFLOW_MODE`.

**Rule: Ask all questions in a single batch. Do not drip-feed one at a time.**
If a question can be answered by scanning project files (e.g., `tsconfig.json`
exists → TypeScript, `jest` in `package.json` → Jest), state the inferred answer
and ask the user to confirm rather than asking from scratch.

---

## Setup — File Structure

Create these files at the project root. Each file has a specific role.
Do NOT merge them — separation enables focused reads and smaller context loads.

```
project-root/
├── .gitignore                         # Must include .env, *.key, *.pem, secrets (step 3)
├── CLAUDE.md                          # AI session context (auto-loaded)
├── TRACKING.md                        # Single source of truth for status (solo)
├── TRACKING-[name].md                 # Per-person tracking (team — see Docs/TEAM-GUIDE.md)
├── Docs/
│   ├── CODING_GUARDRAILS.md           # Engineering rules (never-again list)
│   ├── SPRINT_WORKFLOW.md             # This file (or project-specific copy)
│   ├── LESSONS_INDEX.md               # Bug → rule traceability
│   ├── PARALLEL-EXECUTION.md         # Parallel wave patterns (optional, user-triggered)
│   ├── CROSS-LLM-AUDIT.md           # Cross-LLM audit setup guide (optional)
│   ├── WORKFLOW-MODES.md             # Lite/Standard/Strict mode details
│   ├── TEAM-GUIDE.md                 # Team topologies, dependencies, PR/CI (team only)
│   ├── UNITY-GUIDE.md                # Unity-specific git/LFS/scene rules (optional)
│   ├── SPRINT-INDEX.md               # Topic-first cross-sprint retrieval index
│   ├── Planning/
│   │   ├── Roadmap.md                 # Sprint plan with Must/Should/Could
│   │   └── S<N>_ENTRY_GATE.md         # Entry Gate report (temporary, deleted at Sprint Close)
│   └── Archive/
│       └── changelog-S1-S2.md         # Archived sprint changelogs
├── Tools/
│   └── sprint-audit.sh                # Automated close gate checks
└── .claude/                           # Claude Code hooks (Step 8.5, skip for other agents)
    ├── hooks-config.sh                # Feature flags (lite/standard/strict mode)
    ├── settings.json                  # Hook registrations
    ├── setup-audit.sh                 # Interactive cross-LLM audit setup (always create)
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
        └── cross-llm-audit.sh         # External LLM code review (optional)
```

### Why separate files?

```
┌─────────────────────────────────────────────────────────────┐
│ AI agent context window is finite.                          │
│                                                             │
│ Single mega-file = must read everything every session       │
│ Separated files  = read only what's needed per task         │
│                                                             │
│ CLAUDE.md   → always loaded (system prompt, ~100 lines)     │
│ TRACKING.md → loaded at session start (~50-100 lines)       │
│ GUARDRAILS  → loaded per-section via index (~20-40 lines)   │
│ Roadmap     → loaded per-sprint (~30-50 lines)              │
│                                                             │
│ Total per session: ~200-300 lines vs ~2000+ in single file  │
└─────────────────────────────────────────────────────────────┘
```

---

## File Templates

### CLAUDE.md Template

```markdown
# [Project Name] — AI Session Context

This file provides quick context for every AI session.

## Document Contract

- `TRACKING.md` (or `TRACKING-[name].md` if team — see [Docs/TEAM-GUIDE.md](Docs/TEAM-GUIDE.md)): single source of truth for item status (ID-###, open/in_progress/fixed/verified; special: deferred, blocked).
- `Docs/Planning/Roadmap.md`: sprint plan (Must/Should/Could per sprint).
- `Docs/CODING_GUARDRAILS.md`: engineering rules (check before writing code).
- `Docs/SPRINT_WORKFLOW.md`: sprint lifecycle (Entry Gate, Close Gate, Sprint Close) — read at sprint boundaries.
- `Docs/LESSONS_INDEX.md`: RuleID → root cause → target file mapping.
- `Docs/SPRINT-INDEX.md`: cross-sprint topic-first lookup (read at Entry Gate step 9a, updated at Sprint Close step 7h).
- `Docs/PARALLEL-EXECUTION.md`: parallel wave execution patterns (optional — loaded when user triggers parallel mode at Entry Gate step 11).
- `Docs/TEAM-GUIDE.md`: team topologies, cross-sprint dependencies, PR integration, CI/CD (team only — skip if solo).
- `Docs/UNITY-GUIDE.md`: Unity-specific git, LFS, scene ownership rules (Unity projects only — skip otherwise).
- `CLAUDE.md` (this file): operational rules + checkpoint summary.

Rule: Bug and sprint status is NOT duplicated here; only short references.

## Project Summary

[One paragraph: language, framework, architecture, target platform, key goals]
VCS: [git | svn | none]
Critical Axis: [security | performance | reliability | correctness | other: ...]
Team: [solo | names — e.g., "Dev-A, Dev-B"]

## Immutable Contracts

[List things that MUST NOT change without explicit architectural revision]
- [Data format: ...]
- [API contract: ...]
- [Convention: ...]
- [Build target: ...]

## Operational Rules

- Update `TRACKING.md` (or your `TRACKING-[name].md` if team) after every significant fix/decision.
- `fixed → verified` transition requires evidence (test output or pass confirmation). Full flow: open → in_progress → fixed → verified.
- Check `Docs/CODING_GUARDRAILS.md` before writing new code.
- Sprint `Must` items must be complete before sprint is "done".
- Roadmap checkbox `[x]` only when item is `verified` in TRACKING.md. `[~]` only when `deferred`. Intermediate states (in_progress, fixed-untested) are not shown in roadmap — TRACKING.md is the single source. `sprint-audit.sh` Section 11 catches mismatches automatically.
- Close Gate is user-initiated only. AI never asks "shall we close the sprint?" unprompted.
  Reading all items as `verified` in TRACKING.md is not a trigger — it is just state.
- Sprint close gate:
  - Run `Tools/sprint-audit.sh` (automated scan, 16 sections).
  - Manual review (see `CODING_GUARDRAILS.md` §Close Gate).
- Session boundaries: at known heavy-context transition points (after Entry Gate, before Close Gate),
  AI MUST explicitly recommend starting a new session. AI cannot assess its own context usage —
  this recommendation is mandatory, not optional. User decides whether to follow it.
- All code, comments in [English/language].
- Commit policy (if VCS in use): sprint branch (`sprint-N-impl` solo / `sprint-N-name-impl` team), commit after each item's D.7, squash merge to main after Close Gate (solo: local merge, team: PR-based merge — see [Docs/TEAM-GUIDE.md](Docs/TEAM-GUIDE.md) §Pull Request Integration). Commit style: [conventional/free-form]. Commit messages in [English/language]. If VCS=none: skip.

## Last Checkpoint

- Date: [YYYY-MM-DD]
- Active focus: [Sprint N status]
- Status: [Key items completed]
- Next step: [What's next]

## Quick Start

New session sequence:
1. If `Team:` lists multiple names → ask: "Which team member are you?" to determine which
   `TRACKING-[name].md` to read. Solo → read `TRACKING.md` directly.
2. Read your TRACKING file → Current Focus + Sprint Board + Blockers
3. `Docs/Planning/Roadmap.md` → active sprint section
→ Then tell the AI: **"Continue sprint N"** or **"Resume"** — AI runs Session Start Protocol automatically.

Sprint start (new sprint transition):
- `Docs/SPRINT_WORKFLOW.md` §Entry Gate (phases 0-3, 12 steps) — read and execute. No code before plan is confirmed.

Sprint close:
- `Docs/SPRINT_WORKFLOW.md` §Close Gate (5 phases) + §Sprint Close — read and execute.

Before writing code:
- `Docs/CODING_GUARDRAILS.md` → Section Index → relevant sections only
```

### TRACKING.md Template

```markdown
# [Project Name] — Tracking

## Current Focus
Sprint [N]: [one-line description]

## Sprint Board

| ID | Summary | Status | Sprint | Evidence |
|----|---------|--------|--------|----------|
| CORE-001 | [description] | open | S1 | |
| CORE-002 | [description] | in_progress | S1 | |
| CORE-003 | [description] | fixed | S1 | |
| CORE-004 | [description] | verified | S1 | RUN-001 |
| CORE-005 | [description] | deferred | S1 | reason: [why] → target S2 |

Status values: `open` → `in_progress` → `fixed` → `verified`
Special statuses:
- `deferred`: item intentionally skipped (maps to roadmap `[~]`). Requires reason + target sprint.
- `blocked`: item cannot proceed due to external dependency. Requires linked blocker in §Open Risks.
  Format: `blocked by [CORE-### | external description]`. Log block reason in Change Log:
  `[date] CORE-###: blocked — depends on [CORE-### / description]. Expected resolution: [date/sprint].`
  When unblocked: `[date] CORE-###: unblocked — [dependency resolved / reason].` Transition to `open`.
Reverse transition: `verified` → `open` is allowed ONLY when a regression is discovered.
  Log reason in Change Log: "[date] CORE-###: reopened — regression found in [context]"

## Open Risks / Blockers

| ID | Risk | Mitigation | Sprint |
|----|------|------------|--------|
| R-001 | [description] | [plan] | S1 |

## Predicted Failure Modes — Current Sprint

Written at Entry Gate step 9a. Read at Sprint Close step 7 (retrospective comparison).
Replace this section at each new sprint's Entry Gate.

| Item | Category | Predicted Mode | Detection Plan |
|------|----------|---------------|----------------|

## Failure Mode History

Written at Sprint Close step 7 (retrospective). Read at Entry Gate step 9a (failure mode analysis).
Pattern rules:
- Same category 2+ times in last 3 sprints → Architecture Review Required at next Entry Gate.
- Same detection=user-visual 2+ times → "Can an automated proxy test replace visual check?" mandatory question at next Entry Gate.
Category naming: use `type:subsystem` format (e.g. `null-ref:Renderer`, `mem-leak:AudioPool`).
Generic categories (`null-ref`, `crash`) cause CP2 false positives across unrelated subsystems.

| Sprint | Category | Predicted? | Detection | Mode | Impact | Root Cause | Guardrail | Escalate? |
|--------|----------|------------|-----------|------|--------|------------|-----------|-----------|

## Failure Encounters — Current Sprint

Log failures as they are discovered during implementation (bugs, test failures, unexpected behavior).
Sprint Close step 7a reads this for retrospective comparison. Replace at each new sprint.

| Item | Category | Failure Description | Detection | Date |
|------|----------|-------------------|-----------|------|

Category: direct / interaction / stress-edge.
Detection: test / user-visual / profiler / code-review.

## Performance Baseline Log

Recorded at Sprint Close step 5. Read at Entry Gate Phase 1 step 3 (CP1).
New row per sprint per tracked metric. Deltas are derived on demand from adjacent rows.
`Value` must be a plain number (no unit suffix) — unit goes in the `Unit` column.
This format is required for automated CP1 regression detection.

| Sprint | Metric          | Value | Unit | Method         |
|--------|-----------------|-------|------|----------------|
| S1     | [metric_name]   | 12    | ms   | [how measured] |

## Retroactive Audits

Written at Retroactive Sprint Audit Phase 7. Read at Entry Gate step 3 (deferred items)
and Entry Gate step 9a (pattern analysis). Audits without `status: CLOSED` block Sprint Close step 6.

| Audit # | Target Sprint | Status | Trigger | Classification | Resolution | Closed |
|---------|--------------|--------|---------|----------------|------------|--------|
| A-001 | S[N] | OPEN / IN_PROGRESS / CLOSED | [symptom] | [category] | [fix now / next sprint / accepted] | [date] |

Category values: REGRESSION / INTEGRATION_GAP / FALSE_VERIFICATION / COLD_STATE / SCOPE_DRIFT / ENVIRONMENT_DELTA

## Dismissed Signals

Written when user says NO to an audit proposal. Re-surfaced at next Entry Gate if condition
persists (same system, same checkpoint). Suppressed after 2 dismissals — but CP3 and CP4
signals are never suppressed by prior dismissals.
Suppressed signal reactivates if the underlying condition worsens: metric delta increases,
or a new failure is logged in the same system. Dismissal counter resets to 0.

| Date | Checkpoint | System / Metric | Signal Summary | User Decision | Dismissal # | Suppressed? | Revisit Sprint |
|------|-----------|----------------|---------------|---------------|-------------|-------------|----------------|
| [date] | CP1 / CP2 / CP3 / CP4 | [system name] | [what signal fired] | NO — [reason] | 1 / 2 | NO / YES | S[N+1] |

Checkpoint: CP1=Entry Gate metric; CP2=Entry Gate failure pattern; CP3=Implementation; CP4=Close Gate.

## Change Log

[Sprint-scoped entries. Archived to Docs/Archive/ at sprint close.]

Tag significant entries for sprint index retrieval (see §Sprint Index Tagging below).

### Sprint [N]
- [date] [ID]: [what changed]
```

### Sprint Index Tagging

Tag significant TRACKING.md entries (Change Log, Failure Mode History, Decisions) with
HTML comments so they can be found by topic across sprints. The sprint index
(`Docs/SPRINT-INDEX.md`) aggregates these tags into a topic-first lookup table.

**Tag format:**
```
<!-- topics:auth,api type:failure sprint:5 item:CORE-220 -->
```

Fields:
- `topics`: comma-separated domain areas (e.g. `auth`, `api`, `db`, `ui`, `perf`, `config`).
  Use project-specific terms — no fixed vocabulary. Multiple topics when an entry spans domains.
- `type`: one of `failure` | `decision` | `regression` | `baseline` | `guardrail`
- `sprint`: sprint number (integer)
- `item`: CORE-ID (optional for non-item entries like guardrails)

**When to tag:**
- Failure Mode History entries (type: `failure`)
- User decisions at Entry Gate step 8 or mid-sprint scope changes (type: `decision`)
- Regressions detected at Close Gate or CP1 (type: `regression`)
- Performance baselines established or changed (type: `baseline`)
- New guardrail rules added via Update Rule (type: `guardrail`)

**When NOT to tag:** routine Change Log entries ("started item", "tests pass"), status
transitions, archive operations. Only tag entries that future sprints would want to find.

**Sprint Index format** (`Docs/SPRINT-INDEX.md`):
```markdown
# Sprint Index

Topic-first lookup for cross-sprint retrieval. Most recent entries first per topic.
Updated at Sprint Close step 7h. Source of truth: tagged entries in TRACKING.md.

## auth
- S8: regression CORE-340 (session invalidation) → G-015
- S5: failure CORE-220 (token expiry) → G-012

## perf
- S7: regression (API p95 +40ms) → fixed CORE-310
- S3: baseline established (API p95: 120ms)

## db
- S6: decision CORE-280 (connection pooling strategy — chose pgBouncer over app-level)
```

Rules:
- One line per entry, newest first within each topic
- Include CORE-ID, brief description, guardrail reference if applicable
- Topics with no entries in last 5 sprints → archive to `Docs/Archive/sprint-index-archive.md`

### CODING_GUARDRAILS.md Template

```markdown
# [Project Name] — Coding Guardrails

Engineering rules derived from real bugs and project-specific risk scans.
Review relevant sections BEFORE writing code.

## Section Index — Read by Task Type

| Task | Read sections |
|------|---------------|
| [task type 1] | §1, §2 |
| [task type 2] | §1, §3 |
| Sprint workflow | §Entry Gate, §Close Gate |
| Anti-pattern quick check | §Anti-Pattern Quick Reference |

*(Bootstrap step 6 populates this file. Sections below are created per-project —
not copied from a generic template. Each rule comes from scanning this specific codebase.)*

**Format rules (keep file scannable — target ≤800 lines):**
- Each rule: max 20 lines (title + one WRONG/CORRECT pair + root cause + scope + reference)
- Root cause: one sentence. Full story lives in sprint archive, not here.
- Code examples: one WRONG + one CORRECT per rule. Extra edge cases → inline comment, not extra blocks.
- No design justification in guardrails. "Why we keep this despite over-engineering" → DESIGN.md.
- Sprint Close step 7i checks file size and flags if >800 lines.

---

## 1. [Section Title — generated by bootstrap scan]

### 1.1 [Rule Title]

```[language]
# WRONG — [what the scan found in this project]
[actual anti-pattern from codebase, with real file reference]

# CORRECT
[fix]
```

- **Root cause:** [one sentence — why this rule exists]
- **Scope:** [which files/modules in this project]
- **Reference:** bootstrap scan / [sprint/bug ID]

---

## Entry Gate — Pre-Sprint Review

> **Parallel execution (user-triggered):** If the user requests parallel execution,
> agents with sub-agent support can run Entry Gate phases in parallel waves —
> see [Docs/PARALLEL-EXECUTION.md](Docs/PARALLEL-EXECUTION.md) §Entry Gate. Do not load that document automatically.

Before writing code for a new sprint:

**Abbreviated mode** (≤3 Must items AND no cross-sprint dependencies):
AI must confirm with user before running abbreviated mode — do not choose unilaterally:
"Sprint N qualifies for abbreviated Entry Gate (≤3 Must items, no cross-sprint deps).
Run abbreviated (faster) or full gate (more thorough)?"
User decides. If user does not respond or is unclear → run full gate.
Run: Phase 0 (sprint type + detail if needed) → step 0pre → steps 1-2 → step 8 (quick pass) → step 9b-lite → step 10 → step 12.
Skip: steps 3-4, Phase 2 (steps 5-7), step 9a, step 9c (including fitness check), step 11.
After step 2 (abbreviated only): Clear §Predicted Failure Modes and §Failure Encounters now.
  Step 9a is skipped — these sections would otherwise contain previous sprint's stale data.
  Clearing without writing new predictions is correct; Close Gate Phase 1b accounts for this.
Step 9b-lite: for each item, answer only "what will be tested?" and "what input/output?"
— skip failure mode categories, invariant depth, and metric sufficiency analysis.
Implementation Loop D.7 (AC exit check) still runs in abbreviated mode — it is a self-verification
step, not a gate step. Skipping it defeats the purpose of having acceptance criteria.
When in doubt → run full gate. Abbreviated saves time; full catches more.
Log difference: step 12d logs "Entry Gate (abbreviated)" so Close Gate knows.

**Phase 0 — Sprint Detail (conditional):**

**Sprint type detection (always runs, even if sprint already has items):**
Determine the sprint type by reading the Roadmap description and items:
- **Feature sprint** (default): new functionality or enhancements. Standard gate rigor.
- **Hardening sprint**: debt clearance, stabilization, performance tuning on existing code.
  Characteristics: most items modify existing systems (not new files), focus is on
  quality improvement rather than new behavior.
  Adjusted rules for hardening sprints:
  - Metric gates focus on regression prevention ("no worse than baseline") rather than new thresholds.
  - Close Gate Phase 1c fitness review focuses on robustness (edge cases, error paths) rather than completeness.
  - New features discovered during hardening are logged to TRACKING.md §Change Log as
    opportunities, not added to sprint scope.
Log sprint type in Entry Gate report (step 12a). Close Gate Phase 1c reads this to adjust criteria.

*(Skip the rest of Phase 0 if this sprint already has Must/Should/Could items in the Roadmap.)*

If the sprint is still a one-line sketch from Initial Planning:
0a. Read the sketch description + previous sprint's outcomes
0b. Decompose into Must/Should/Could items with CORE-### IDs
    Format: `- [ ] CORE-###: [description]` — checkbox is mandatory.
    Plain bullets break close gate tracking (sprint-audit.sh Section 11).
0c. Add metric gates for each item (Must, Should, and Could — all get metrics)
0d. Priority & rigor review — two passes:
    **Pass 1 — Distribution check (on initial 0b decomposition, before any promotions):**
    - All items in Must? → decomposition didn't actually prioritize — re-sort.
    - Zero Should/Could? → check if Must includes nice-to-haves that should move down.
    - Must item has no dependencies and no metric? → should it be Should?
    Flag misplacements to user with reasoning. User decides final placement.
    If user demotes → move item to Should, re-run distribution check.
    If user keeps → item remains Must, continue to Pass 2.
    **Pass 2 — Dependency promotion (after distribution is validated):**
    Q: Would removing this Should/Could item cause a Must item's metric gate to FAIL?
       YES → promote to Must. It was misclassified — it's a real dependency.
       NO  → stays at current priority.
    Post-promotion Must count may exceed initial count — this is valid.
    These are verified dependencies, not lazy grouping.
0e. Present detailed sprint plan to user for approval before proceeding to Phase 1
    User does not approve → identify concerns → rework 0b-0d → re-present.
    After 2nd re-present without approval → AI asks explicitly:
    "Continue reworking the sprint plan, or Sprint Abort?" User decides.
    If user decides the sprint direction is fundamentally wrong → §Sprint Abort procedure.
This is the same process as Initial Planning step 4, applied to the next sprint.
If items exceed scope limit → apply §Scope Negotiation.

**Phase 1 — State Review (analysis + tracking corrections):**

0pre. Roadmap sanity check (quick — before reading state):
   - CORE-### IDs in Roadmap.md all have matching entries in TRACKING.md? (orphan detection)
   - TRACKING.md items all appear in Roadmap.md? (reverse orphan detection)
   - Roadmap checkbox states match TRACKING.md statuses? (`[x]` = verified, `[~]` = deferred)
   Mismatches → fix now (ask user if ambiguous). This prevents stale cross-references
   from corrupting the Entry Gate analysis.
   If `Tools/sprint-audit.sh` exists: its Section 11 (a/b/c) performs these checks automatically.
   Run it now for a quick sanity pass; the full audit runs at Close Gate.

0. Check previous sprint's Sprint Close completion:
   Read TRACKING.md §Change Log for entry: "Sprint Close: complete — Sprint N" (or equivalent).
   If not found → warn user before proceeding:
   "Sprint N Sprint Close has no completion entry in Change Log. This means the failure mode
   retrospective (Step 7) may not have run — guardrails from Sprint N bugs may be missing.
   Recommended: complete Sprint Close for Sprint N before opening Sprint N+1.
   Proceed anyway?" User decides.
   If proceeding without: log in TRACKING.md §Open Risks:
   "R-###: Sprint N Sprint Close incomplete — retrospective not confirmed, guardrails may be missing. Target: resolve before Sprint N+2."
1. Read TRACKING.md → open items, blockers, in_progress items from interrupted sessions
   Do NOT clear §Predicted Failure Modes or §Failure Encounters yet — they are cleared
   at step 9a when new predictions are written (clearing before 9a risks data loss if
   interrupted). Until then, treat them as read-only reference from the previous sprint.
2. Read Roadmap → Must/Should/Could for this sprint
3. Check non-verified items from previous sprints (all non-terminal statuses):
   - `blocked`: is the blocker still active? Resolved → update status to `open`.
     Still blocked → carry forward as `blocked` or drop (user decides).
     Drop = delete from Roadmap + TRACKING.md, log removal in Change Log (same as step 8 remove path).
     Either way: verify there is a corresponding R-### entry in §Open Risks.
     If not → create one now. Assign next available R-### ID (continue from highest existing
     ID in §Open Risks, never reuse).
   - `deferred`: still relevant? Carry forward or drop (user decides).
     Drop = delete from Roadmap + TRACKING.md, log removal in Change Log (same as step 8 remove path).
   - `open` / `in_progress`: still in scope? Carry forward (user decides).
   - `fixed` (not yet verified): verify now (if test already exists and can be run) or carry
     forward for verification in Implementation Loop (user decides).
   Check §Open Risks for Architecture Review Required flags from previous sprints.
   If found → surface to user: "Architecture Review Required flag found from Sprint N.
   Run review before continuing Entry Gate (recommended — result may affect scope),
   or proceed and review at step 9a?" User decides.
   If review now: run the Architecture Review procedure immediately, then continue Phase 1.
   If deferred to 9a: treat as Priority 1 in step 9a (before analyzing current sprint items).
   Check TRACKING.md §Change Log for metrics deferred to this sprint from a prior Close Gate
   (format: `DEFERRED → S<N>` where N matches the current sprint number).
   For each match: read deferral reason from TRACKING.md, then surface to user with context —
   "Metric [X] was deferred from Sprint M. Reason at deferral: [reason]. Is the blocker now
   resolved, or defer again to S<N+1>?" User decides. If resolvable: add to
   step 9c metric sufficiency review. If still deferred: log updated target sprint.
   Check TRACKING.md §Performance Baseline Log for metric regressions vs past sprint claims
   — see CP1 (Auto-Detection). Signal fires if a verified past metric is now measurably worse
   AND the current sprint did not modify the responsible system.
   If signal fires → present options: "⚠ AUDIT SIGNAL: [metric] regressed since Sprint N.
   (1) Open Retroactive Audit now (Entry Gate pauses), (2) Log and continue Entry Gate, audit
   after sprint planning." User decides.
4. Identify applicable GUARDRAILS sections (consumed by implementation loop step A)

**Phase 2 — Dependency Verification (read-only):**
*(Sprint 1: skip this phase — no prior sprints exist.)*
5. Verify dependency sprints are closed.
   Partial completion rule: if a dependency sprint has `deferred` items, check whether
   the current sprint actually depends on those specific items. If not → dependency met.
   If yes → flag to user: "Sprint N depends on [deferred item] — resolve before proceeding?"
   If cross-sprint dependency is not explicitly documented in Roadmap.md: flag to user —
   "Sprint N appears to depend on Sprint M output. Confirm this dependency still holds
   before proceeding."
6. Read dependency API source files, confirm contracts match
7. List open architectural decisions — include in step 12a report.
   If any decision directly affects this sprint's scope or approach, flag in step 8.

**Phase 3 — Strategic Validation & Confirmation:**
8. Strategic alignment check — for each item (Must, Should, Could):
   a. Still relevant? (superseded, already delivered?)
   b. Goal alignment? (does it serve core project goals?)
   c. Approach still valid? (has new info invalidated the method?)
   d. Metrics still appropriate? (measuring the right thing?)
   e. Rough impact scope? (which major areas/modules will this touch — ballpark, not file list)
   f. Redundancy risk? (does framework/engine/previous sprint already provide this?)
   If any of a-d fails → flag to user with evidence + options (keep/modify/defer/remove).
   If e reveals unexpectedly wide blast radius → flag before proceeding.
   If f reveals overlap → flag: "CORE-### may overlap with [existing]. Confirm scope or narrow to delta."
   User response mechanics:
   - keep → item unchanged, continue gate.
   - modify → update item description/scope/metrics in Roadmap, re-run steps 9a-9c for that item.
   - defer → TRACKING.md status `deferred` + roadmap `[~]`, requires reason + target sprint.
   - remove → delete from Roadmap + TRACKING.md, log removal in Change Log.
   AI does not unilaterally change sprint scope — user decides.
   After all items reviewed: if Must count now exceeds scope limit → apply §Scope Negotiation
   before proceeding to step 9.

**Domain Research (conditional — per item, before step 9):**
For each item, before writing the verification plan:
- Does this item require domain-specific knowledge? (mathematical formulas, protocol
  specifications, algorithm implementations, hardware/API behavior, specialized techniques)
- Is the AI confident it holds correct, verified knowledge — or is it working from
  approximate memory that could contain errors?

If uncertain or if the domain is specialized:
   1. **Research:** search for authoritative sources — academic papers (SIGGRAPH, GDC),
      official specifications, reference implementations from established engines/frameworks.
   2. **Extract:** document the exact formulas, algorithms, or specifications found.
   3. **Verify:** cross-reference at least 2 independent sources where possible.
   4. **Record:** write findings to the Entry Gate report (step 12a) under a
      "§Domain Research" section — sources, key formulas, and how they map to sprint items.

This step prevents trial-and-error implementation loops. The AI must treat
"I think the formula is roughly X" as a knowledge gap — not as sufficient basis for coding.

Skip when: item uses well-known patterns within the project's existing stack,
or the AI can point to a specific authoritative source it has already verified.

Flag items that required research as `research: done` in the Entry Gate report
so Implementation Loop step A.5 knows research is already complete.

9. Verification plan:
   a. Failure mode analysis (per item — Must, Should, and Could):
      First: read `Docs/SPRINT-INDEX.md` for relevant topics (match item's domain areas).
      Then: read TRACKING.md §Failure Mode History — which categories failed before?
      Check for escalation triggers in §Failure Mode History and §Open Risks:
      - Same category 2+ times in last 3 sprints → Architecture Review Required (see below).
      - Same detection=user-visual 2+ times → propose automated proxy test before proceeding.
          If triggered: propose adding a proxy test as a Must item in this sprint or the next.
          "A test that passes only when the visual check would also pass."
          Present options to user: add to current sprint scope, defer to next sprint as Must,
          or accept manual check. User decides.
          Accept manual → log in §Dismissed Signals (Checkpoint: CP2). After 2 dismissals:
          suppressed for this specific item. If a new user-visual failure is added to
          §Failure Mode History for this item: dismissal counter resets.
      If Architecture Review triggered:
        1. Identify the recurring category (direct/interaction/stress-edge)
        2. Trace root causes across sprints — are they symptoms of the same design flaw?
        3. Propose architectural fix (not per-sprint patch) with scope and effort estimate
        4. Present to user: "Category [X] has failed [N] times across sprints [list].
           Root causes: [list]. Proposed architectural fix: [description]. Proceed or defer?"
        5. User decides: fix now (add to sprint scope) or defer.
           Defer → log in §Open Risks: "Architecture Review deferred — category [X],
           sprints [list], target sprint [N]." Entry Gate step 3 picks this up next sprint.
      Then: list known failure modes in 3 categories:
      - Direct: item breaks on its own (wrong calc, null ref, off-by-one)
      - Interaction: 2+ systems combine to fail (pool + dispatch + timing)
      - Stress/edge: invisible in normal use (rapid oscillation, pool exhaustion, cascade)
      Each category: >=1 mode.
      Critical Axis scrutiny: read CLAUDE.md §Project Summary → Critical Axis.
      For items that touch the Critical Axis domain: require >=2 predicted failure modes
      in that axis's most relevant category. Example: security axis → >=2 Direct modes
      covering attack surfaces. Performance axis → >=2 Stress/edge modes covering load scenarios.
      Clear §Predicted Failure Modes and §Failure Encounters now — replace previous sprint
      content with new predictions (previous sprint data was archived at Sprint Close step 7).
      Write predictions to TRACKING.md §Predicted Failure Modes (step 7 reads this).
   b. For each item: how will behavior be verified? (unit test / integration test / manual + screenshot)
      Algorithmic items: what invariants must hold? (mathematical properties, reference output, determinism)
      "It runs" ≠ "it is correct".
      Complex or hard-to-isolate systems: would a dedicated test scene/sandbox accelerate
      development and verification? If so, note in the verification plan.
   c. Metric sufficiency (per item — Must, Should, and Could):
      Item has no metric gate? Propose one.
      For each metric, all four must hold:
      - Measurable by sprint end?
      - Test scenario defined? (inputs, environment, data size, repetition count)
      - Threshold non-trivial? (construct a scenario where metric passes but system is broken
        — if one exists, tighten threshold or add scenario constraints)
      - Coverage: every failure mode from 9a maps to a metric or test? Missing → add.
      **Fitness check:** For each item, verify that "all tests pass" is not the only success
      criterion. Ask: would a superficially correct implementation (tests green, but incomplete
      integration, missing edge handling, or poor fit for the project's use case) still pass
      these metrics? If yes → add at least one fitness-level metric (integration behavior,
      real-world usage scenario, or Critical Axis compliance).
      Any change (new metric, revised threshold, added test scenario) → propose in Entry Gate
      report (step 12a). Do NOT update roadmap yet — user approves metric changes at step 12c.
      If approved → update roadmap. If rejected → rework at step 9c, re-present.
10. Is scope realistic? (1 to scope limit from Q2: small=5, medium=8, large=12 Must items.)
    0 Must → sprint is empty. Present options: "(1) Return to Phase 0 to redesign scope —
    sprint goal is still valid but scope needs rework. (2) Sprint Abort — sprint goal is no
    longer viable. Which applies?" User decides.
    Return to Phase 0 twice and still 0 Must → Sprint Abort is the only option. User confirms.
11. Produce dependency-ordered implementation list
    After producing the dependency graph, if 4+ items have no mutual dependencies
    (can execute independently), suggest parallel execution to the user:
    "This sprint has [N] independent items — parallel execution could help.
    Want me to load the parallel execution guide?"
    If user accepts → load Docs/PARALLEL-EXECUTION.md and plan waves.
    If user declines or no response → continue sequentially. Do not ask again.
12. Gate assessment, report & user approval
    a. Write full Entry Gate report to `Docs/Planning/S<N>_ENTRY_GATE.md`
       Contains: complete analysis from phases 0-3 (state review, dependency/API checks,
       strategic alignment, failure modes, implementation order, etc.)
       Must include a Metric Changes section from step 9c: for each metric that was added, revised,
       or had test scenarios defined — show before/after and rationale.
       This file serves as a living reference during the sprint and is deleted at Sprint Close.
    b. AI provides its own gate assessment before asking for approval:
       - **Blocker summary:** any step that failed or raised concerns? (list or "none")
       - **Risk assessment:** clean / attention points exist (list them) / blocker found
       - **Scope assessment:** conservative / reasonable / aggressive
       - **Key watch items:** implementation-time risks that aren't gate blockers
         but require careful attention (e.g., specific interaction risks from Architecture Review)
       - **Recommendation:** "Gate passed — recommend proceeding" or "Gate blocked by [X]"
    c. User approves before coding begins
       User specifically reviews verification plan quality (step 9b):
         For each item's test scenario — "Would this test pass even if the item is broken?"
         Trivial scenario (e.g., "it runs", "no crash", "no exception") → send back to step 9b for revision.
         After 2 revisions of the same item's test scenario still trivial → AI flags:
         "Options: (1) accept current scenario with documented rationale, (2) mark item as
         untestable at gate — verify manually at Close Gate, (3) Sprint Abort if untestable
         and critical." User decides.
         Acceptable scenario: specifies inputs, expected outputs or invariants, and at least one failure-inducing case.
       User does not approve → identify blocking concerns → return to the relevant phase:
       Phase 0 (scope issues) / Phase 1 (state review concerns) / Phase 2 (dependency issues)
       / Phase 3 (strategic or metric issues) → rework → re-present.
       After 2nd rejection → AI asks explicitly: "Entry Gate rejected twice.
       (1) Return to specific phase for targeted rework, (2) Sprint Abort." User decides.
       If user decides the sprint direction is fundamentally wrong → §Sprint Abort procedure.
    d. Phase logging rule: after completing each Entry Gate phase, log to TRACKING.md Change Log:
       "Entry Gate Phase [X]: complete — [date], steps executed: [list]."
       This enables session recovery — if session is interrupted mid-gate, the next session
       can read Change Log and resume from the last completed phase.
       After approval: log to TRACKING.md: "Entry Gate: [date], phases 0-3 ✓ (steps executed: [list])"
       Add reference to TRACKING.md: "Entry Gate report: Docs/Planning/S<N>_ENTRY_GATE.md"
       Update roadmap with any metric changes approved at step c.
       Update CLAUDE.md §Last Checkpoint: "Entry Gate complete — Sprint N approved, ready for implementation."
       Session boundary (mandatory): Entry Gate consumes significant context.
       AI MUST recommend starting a new session for implementation ("Continue sprint N").
       User may choose to continue in the same session — that decision rests with the user.

---

## Implementation Loop

> **Parallel execution (user-triggered):** If the user requests parallel execution,
> independent items can run in parallel waves via sub-agents on a sprint branch
> (inter-wave commits mandatory, merge to main after Close Gate) —
> see [Docs/PARALLEL-EXECUTION.md](Docs/PARALLEL-EXECUTION.md) §Implementation Loop. Do not load that document automatically.

**Sprint branch (VCS=git only):**
Before writing any code, create a sprint branch from the current main branch:
```
git tag sprint-N-start    # tag on main before branching
git checkout -b sprint-N-impl
```
All implementation commits go to `sprint-N-impl` — main stays clean until Close Gate passes.
This applies to both sequential and parallel execution. Benefits:
- Sprint abort → delete branch, main untouched
- Close Gate fail → fixes stay on branch, main never sees broken code
- Clean history → squash merge gives main one summary commit per sprint

**Commit timing:** commit after each item completes D.7 (AC exit check):
```
git commit -m "CORE-###: [one-line summary]"
```
This ensures each item is an atomic, revertable unit. If D.7 reveals an issue and the item
needs rework, the commit has not happened yet. After D.7 passes → commit → next item.

**Commit message format (if Q11 = conventional):**
```
type(scope): subject

type:  feat | fix | refactor | test | docs | perf | chore
scope: CORE-### or module name
subject: imperative, lowercase, no period, max 72 chars

Examples:
  feat(CORE-045): add terrain LOD hysteresis
  fix(CORE-112): correct depth comparison in ocean pass
  refactor(CORE-080): extract grid mapping to shared include
```
If Q11 = free-form: no enforced format, but commit message must reference the CORE-ID.

**Merge ceremony (after Close Gate verdict, before Sprint Close step 1):**

Before merging, preserve per-item commit history for future regression analysis:
```bash
# Verify start tag exists (created during sprint branch creation)
if ! git rev-parse sprint-N-start >/dev/null 2>&1; then
  echo "WARNING: sprint-N-start tag missing. Using merge-base as fallback."
  git tag sprint-N-start "$(git merge-base main sprint-N-impl)"
fi
# Save per-item commit log before branch is deleted
git log --oneline sprint-N-start..sprint-N-impl > /tmp/sprint-N-commits.txt
```
Include this log in the squash merge commit message (see below).

Solo — local squash merge:
```bash
git checkout main
git merge --squash sprint-N-impl
# Include per-item commit history in merge message for regression traceability
git commit -m "$(cat <<EOF
Sprint N: [summary of sprint goal and completed items]

Items merged:
$(git log --oneline sprint-N-start..sprint-N-impl)
EOF
)"
git tag sprint-N-close
git branch -D sprint-N-impl   # -D required: squash merge is not tracked as a real merge, so -d refuses
```
Team — use PR-based flow instead (see [Docs/TEAM-GUIDE.md](Docs/TEAM-GUIDE.md) §Pull Request Integration).
Sprint Close runs on main with all sprint code merged.
If VCS=none: skip all branch/commit/merge steps — traceability via TRACKING.md only.

**Why preserve per-item commits in the merge message?**
Squash merge creates a clean main history (one commit per sprint) but destroys per-item
granularity. When a regression is found later, `git log` on main shows only "Sprint 7"
but not which item changed the affected file. Including the item commit list in the merge
message lets `git show <merge-commit>` reveal the full per-item breakdown without keeping
the branch alive.

**Push policy (VCS=git, remote configured):**
- **Solo:** Push sprint branch to remote as backup after first commit (`git push -u origin sprint-N-impl`).
  Subsequent pushes: after every 2-3 item commits or at session end — whichever comes first.
  Also push before context-heavy transitions (Entry Gate → implementation, implementation → Close Gate).
  No force push — if history diverges, investigate before resolving.
- **Team:** Push sprint branch to remote immediately after creation so teammates can see work in progress.
  Push after every item commit (post-D.7). Force push is **never allowed** on sprint branches
  that others may have pulled — rebase locally before pushing, or coordinate with team.
- **Main branch protection:** Never push directly to main. All code reaches main via squash merge
  after Close Gate. If remote supports branch protection rules, enable them.
- **Tag push:** Push all sprint tags to remote (both start and close) so regression analysis
  works from any machine:
  ```bash
  git push origin sprint-N-start sprint-N-close
  ```
- **Post-merge push:** After merge ceremony, push main and tags together:
  ```bash
  git push origin main
  git push origin sprint-N-start sprint-N-close
  ```
- **Branch cleanup (remote):** Delete remote sprint branch after successful merge:
  ```bash
  git push origin --delete sprint-N-impl
  ```
- **Tag cleanup:** Tags accumulate over time (~3 per sprint). To keep the tag list manageable:
  - Keep `sprint-N-close` tags permanently (needed for regression analysis).
  - `sprint-N-start` tags can be deleted after 10+ sprints since their info is in the merge message:
    ```bash
    git tag -d sprint-1-start sprint-2-start  # local
    git push origin --delete sprint-1-start sprint-2-start  # remote
    ```
  - `sprint-N-abort` and `sprint-N-pre-cherry-pick` tags: delete after the next successful sprint closes.
  - Never delete tags for the last 5 sprints — they may be needed for active regression analysis.

**Merge conflict resolution:**
- **Squash merge conflict (sprint branch → main):** If `git merge --squash` fails:
  1. Do NOT force or discard changes. Inspect conflicts file by file.
  2. Conflicts likely mean main was modified outside the sprint (hotfix, parallel sprint).
  3. Resolve conflicts preserving both sets of changes. Run full test suite after resolution.
  4. If resolution is non-trivial, log in TRACKING.md Change Log:
     `[date] Merge conflict resolved: sprint-N-impl → main. Files: [list]. Cause: [reason].`
  5. Re-run sprint-audit.sh after conflict resolution to catch regressions.
- **Team — concurrent sprints:** If multiple sprint branches target main:
  1. Merge in completion order (first to pass Close Gate merges first).
  2. Later sprints rebase onto updated main before their merge ceremony.
     **⚠ This is a destructive operation (rewrite + force-push). Before proceeding:**
     - Confirm with the other team member that they have no unpushed work on this branch.
     - Verify no open PRs reference the old commit hashes (they will become invalid).
     - Create a local backup tag: `git tag sprint-M-pre-rebase sprint-M-impl`
     ```bash
     git checkout main
     git pull origin main          # get the first sprint's merge commit
     git checkout sprint-M-impl
     git rebase main
     # If rebase succeeds — verify before force-pushing:
     git log --oneline sprint-M-impl   # sanity check: commits look correct?
     git diff main...sprint-M-impl --stat  # sanity check: changed files match expectations?
     # Update start tag to new base (old tag points to pre-rebase commit)
     git tag -f sprint-M-start main
     # Force-push rebased branch + updated tag (rebase rewrites history, regular push fails)
     git push --force-with-lease origin sprint-M-impl
     git push origin -f sprint-M-start
     # If something went wrong — restore from backup:
     #   git reset --hard sprint-M-pre-rebase
     #   git push --force-with-lease origin sprint-M-impl
     # Clean up backup tag after successful merge:
     git tag -d sprint-M-pre-rebase
     ```
     The tag update is critical: after rebase, `sprint-M-start` must point to the
     current main tip so that `git log sprint-M-start..sprint-M-impl` accurately
     reflects only the rebased sprint's commits.
  3. If rebase conflicts arise, resolve and re-run D.7 verification for affected items.
- **Parallel sub-agents (same sprint branch):** Inter-wave commits are sequential by design
  (wave N completes before wave N+1 starts). No merge conflicts within a sprint's parallel execution.

For each Must item (in dependency order from Entry Gate step 11):

**A. Pre-code check**
- Mark item `in_progress` in TRACKING.md
- Read the GUARDRAILS sections identified in Entry Gate Phase 1 step 4 (relevant to this task type)
- Observable evidence gate (bug/quality/fix items only):
  Before writing any fix code, confirm the problem exists at runtime — not just in theory.
  Accepted evidence: runtime visual (screenshot/video), profiler output, test failure output,
  GPU/API readback data, user report, or reproducible error log.
  Pure code analysis ("this could theoretically drift") is NOT sufficient evidence.
  If evidence cannot be produced → narrow scope to "investigate & reproduce" first. Do not write
  a fix for an unconfirmed problem. Log: "Evidence gate: CORE-### — [evidence type]: [summary]"
  Skip when: item is a new feature (not a fix), or Entry Gate already documented the evidence.
- Impact analysis (3+2 questions — answer before writing any code):
  1. Which files will this change touch? (list explicitly)
  2. Which existing behaviors could be affected? (side effects, shared state, callers)
  3. How will you verify nothing broke? (existing tests, new tests, manual check)
  If Q1 reveals >5 files or Q2 reveals cross-system effects not predicted at Entry Gate 9a:
  → flag to user before proceeding. Do not silently expand scope.
  +2 depth questions (run after Q1-Q3, skip if item is trivial):
  *Trivial* = meets ALL of: (a) touches ≤2 files, (b) no new state/parameters/API surface,
  (c) no behavioral change to existing code (e.g., config value tweak, comment fix, doc update,
  dependency version bump, renaming without logic change). If any condition fails → not trivial, run Q4-Q5.
  4. Redundancy check — does the framework, engine built-in, or a previous sprint item
     already provide this functionality? Search project code and dependencies before writing
     new logic. If overlap found → skip (already solved) or narrow to delta (only the gap).
  5. Lifecycle check — for every new parameter, state variable, or API method introduced:
     a. Persistence parity: if the value is recorded, does store→load round-trip produce
        the same result? (serialize/deserialize, save/replay, undo/redo)
     b. Async safety: if state is reset or disposed, are in-flight callbacks/promises
        guarded against accessing stale or destroyed references?
     c. API convention: do sibling methods in the same class/module follow a shared pattern
        (naming, flush/sync calls, error handling)? New method must follow the same pattern.
     If any sub-check reveals a gap → fix before proceeding to B, not after.

**A.5 Domain Research (conditional)**
Trigger: item was flagged `research: done` at Entry Gate (findings already documented),
OR the AI encounters uncertainty about the correct approach during pre-code check.

If Entry Gate already completed research for this item:
→ Read the §Domain Research section from `Docs/Planning/S<N>_ENTRY_GATE.md`.
  Verify findings are still applicable. Proceed to B.

If research was not done at Entry Gate but a knowledge gap is now apparent:
1. Search for authoritative sources (papers, specs, reference implementations).
2. Document exact formulas, algorithms, or specifications.
3. Cross-reference with at least 2 sources where possible.
4. Log research findings in TRACKING.md §Change Log:
   `"Domain research for CORE-###: [topic] — sources: [list]"`

Skip when: item uses well-known patterns, or Entry Gate already completed
research for this item and findings are documented and still valid.

**A.6 Approach Selection (conditional)**
Trigger: item has multiple viable implementation strategies (different algorithms,
data structures, architectural patterns, or library choices) AND the choice
significantly affects quality, performance, or maintainability.

When triggered:
1. Identify at least 2 candidate approaches.
2. Compare on three dimensions: correctness/quality, fit for project context
   (Critical Axis, existing architecture), and implementation cost.
3. State the selected approach with a one-line rationale.
4. Log in TRACKING.md §Change Log:
   `"Approach selection for CORE-###: chose [X] over [Y] — [reason]"`

Skip when: item has an obvious single approach (CRUD endpoint, config change,
test addition), or Entry Gate already specified the approach.

**B. Write code**
- Follow guardrails and immutable contracts throughout
- If you make a fix to a system that is NOT the current sprint item (scope-outside fix):
  immediately log it in TRACKING.md §Change Log:
  "Side fix: [system] — [what was wrong] — [what was changed] — not a sprint item."
  This ensures Sprint Close Step 7 can include it in the retrospective.

**B.1 Fix parity check (after writing code)**
When the change fixes a pattern (bug, anti-pattern, convention violation, missing guard):
1. Re-run the Q1 search (grep/find) that identified the affected files.
2. Verify every matching site received the same fix — not just the first match.
3. If remaining matches exist → apply fix to all before proceeding to C.
   Partial fix (one site fixed, others left) is a BLOCKER — item cannot pass Close Gate.
Skip when: change is a new feature with no existing pattern to match, or Q1 found only one site.

**C. Self-verify (5-point checklist)**
Run before writing any tests:
- [ ] Builds/parses without errors? *(compiled → compiles; interpreted → linter/syntax check; no tooling → manual review)*
- [ ] Matches spec from Entry Gate?
- [ ] No duplication with existing code?
- [ ] Follows project conventions?
- [ ] Tech debt introduced? → fix now or document in TRACKING.md.
  Temporary code must use `// TEMP(CORE-NNN): [reason]` format linking to a tracked item.
  Naked `// TODO` / `// FIXME` / `// HACK` without a CORE-ID are flagged at Close Gate.

If any item fails: fix and recheck. Max 3 rounds.

**Research fallback (before 3rd attempt):** If the failure pattern suggests incorrect domain
knowledge (wrong output values, mathematical errors, spec non-compliance) rather than a
coding bug — return to step A.5 for domain research before the 3rd attempt. The 3rd attempt
then uses verified knowledge instead of another guess. Log: "Research fallback triggered for
CORE-### at self-verify round [N]" in TRACKING.md §Change Log.

Still failing after 3 → stop and present
to user: "Self-verify item [X] still failing after 3 attempts. Options: (1) accept as known
technical debt — log in TRACKING.md and continue, (2) block — do not proceed until resolved,
(3) Sprint Abort if item is critical, (4) domain research — AI investigates root cause via
authoritative sources before next attempt (resets attempt counter)." User decides.

**D. Write tests**
Match test type to what was specified in Entry Gate 9b:
- Unit-testable logic → unit test
- Integration/async behavior → integration test
- Visual/UI → manual check + screenshot

Each test must encode the invariants from Entry Gate 9b.
Trivial tests ("it runs", "no exception", "no crash") are not acceptable — apply the same criteria as Entry Gate step 12c.

**D.5 Visual verification (visual items only)**
Trigger: item was marked "manual+screenshot" in Entry Gate 9b.
1. AI asks the user specific visual questions about what to look for
2. User runs the application and responds:
   - "OK" → proceed to D.6
   - "Problem: [description]" → log CORE-### in TRACKING.md, AI fixes, ask user again
   - Resolution = user confirms "OK". Max 3 attempts; if still failing: log visual gap in
     TRACKING.md evidence column ("visual unconfirmed — target sprint [N]"). Mark item `fixed`
     with caveat. Continue to D.6. At Close Gate Phase 1b: item flagged for manual re-verification.
3. If an automated proxy test exists for this item: still ask user for visual confirmation — proxy tests do not replace it.

**D.6 Incremental test run**
Run ALL tests written so far — current item + all previous items in this sprint:
- All PASS → proceed to E
- FAIL on new test → fix implementation, rerun
- FAIL on previous item's test → regression: fix before writing any more code
- Max 3 fix attempts → stop and present to user: "Test [X] still failing after 3 attempts.
  Options: (1) accept as known gap — log in TRACKING.md, mark test pending for Close Gate,
  (2) block — do not proceed to next item until resolved, (3) Sprint Abort if failure is
  critical, (4) domain research — AI investigates root cause via authoritative sources
  before next attempt (resets attempt counter)." User decides.

Test needs infrastructure not available locally?
→ Mark "pending" in TRACKING.md → it will run at Close Gate Phase 3.

**D.6b Cross-LLM audit (optional — only if `ENABLE_CROSS_AUDIT=true`)**
If the cross-LLM audit hook is enabled, external review findings are automatically injected
as `additionalContext` after source file changes. When findings arrive:
- **BLOCK verdict:** Present findings to the user. Do not proceed until the user reviews and decides.
- **WARN verdict:** Present findings alongside your own assessment. Let the user decide.
- **PASS verdict:** Mention as additional confidence signal, then continue.
- **Conflicting opinions:** If your assessment disagrees with the external audit, present both perspectives and let the user decide. Do not silently override either opinion.
This step is fully automated via the hook — no manual action needed. If the hook is not enabled, skip.
See [Docs/CROSS-LLM-AUDIT.md](Docs/CROSS-LLM-AUDIT.md) for setup.

**D.7 Acceptance criteria exit check**
Before marking the item done, read the item's acceptance criteria from the Entry Gate report
(S<N>_ENTRY_GATE.md) and check each one against the implementation:

```
## CORE-NNN Exit Check
- [x] AC1: "description" → file:line evidence
- [x] AC2: "description" → test_name evidence
- [ ] AC3: "description" → NOT MET → reason
```

Rules:
- Every AC must have a verdict (met / not met)
- "Met" requires a specific code location (file:line) or test name — not "I implemented it"
- "Not met" requires explanation: missing test, partial implementation, deferred
- All ACs met → proceed to E
- Any AC not met → either fix now, or mark item `partial` with explanation in TRACKING.md
  and log unmet ACs in Change Log. User decides at Close Gate whether partial is acceptable.

This is a self-check, not a gate — the implementation agent verifies its own work against
the original plan. Close Gate Phase 1c (fitness review) is the independent external review.

**E. Update TRACKING.md**
- Mark item `fixed` (`in_progress → fixed`), log key decisions made
- If bugs or failures were encountered during this item: log each to `§Failure Encounters`:
  `[item ID] | [category: direct/interaction/stress-edge] | [description] | [how detected]`

  ⚠ **AUTO-DETECTION CP3:** During any implementation step — past sprint API missing or broken, test from a past sprint now FAIL, profiler result contradicts a past sprint metric by >20% (and current sprint did not modify that system)?
  → Surface ⚠ AUDIT SIGNAL to user immediately. Do not silently continue.
  Present options: "(1) Pause implementation — open Retroactive Audit now,
  (2) Log signal and continue implementation — audit after sprint close." User decides.

**After all Must items:**
Ask user: "Must items done. Continue with Should/Could items, or close sprint?"
User decides. Should/Could items run the same A-E loop if continued.
This prompt fires only when the AI completed the final Must item in the current session.
Reading `verified` status from TRACKING.md at session start does NOT trigger this prompt.
Close Gate is always user-initiated — AI does not ask "shall we close?" unprompted.

---

## Close Gate — Sprint-End Audit

> **Parallel execution (user-triggered):** If the user requests parallel execution,
> agents with sub-agent support can run Close Gate audit phases in parallel waves —
> see [Docs/PARALLEL-EXECUTION.md](Docs/PARALLEL-EXECUTION.md) §Close Gate. Do not load that document automatically.

**Phase logging rule:** After completing each Close Gate phase, log to TRACKING.md Change Log:
"Close Gate Phase [X]: complete — [date]." This enables session recovery and pre-verdict
verification — AI can confirm all phases completed by reading Change Log, not relying on memory.

**Presentation rule:**
Interim "present to user" steps (Phase −1 state summary, Phase 0, 1a, 1b, 1c, 2, 4) are transparency checkpoints, not approval gates.
- Clean / minimal findings → batch into one combined report, do not pause for confirmation.
- Significant findings (blocker, regression, MISSED failure mode) → stop at that phase, present and ask.
- Mandatory user approval: Close Gate verdict only (final step before Sprint Close).

**Phase −1 — State recovery (mandatory, run before every Close Gate):**
Regardless of session history, interruptions, or prior context — always run this first.
1. Read `TRACKING.md` §Sprint Board → list every item for this sprint and its current status.
2. Read `Docs/Planning/S<N>_ENTRY_GATE.md` → list every metric gate defined for this sprint.
   If the file no longer exists: read `Docs/Planning/Roadmap.md` sprint section + TRACKING.md §Sprint Board
   for metric gate evidence. Note which source was used.
   Flag to user: "Entry Gate report missing — metric verification will rely on Roadmap
   thresholds only. Test scenario details from Entry Gate 9c may be incomplete."
3. State explicitly before proceeding:
   ```
   Sprint N — Close Gate starting.
   Items: [X Must / Y Should / Z Could]
   Metrics to verify in Phase 0: [list each metric, one per item]
   Source: [ENTRY_GATE.md | Roadmap.md fallback]
   ```
   If steps 1-2 cannot be completed (missing files, ambiguous state) → ask the user before proceeding.
   AI must not proceed to Phase 0 without completing this check.
   A response of "sprint looks done" or "ready to close" without this check is a protocol violation.

**Phase 0 — Metric gate check:**
- Can each metric be measured? Evidence exists? (all sprint metrics — every item has a metric gate)
- Failure mode coverage: for each modified subsystem, are failure modes listed in 3 categories (direct / interaction / stress-edge)? Each has a metric or test? Missing → add, or document as known gap with target sprint.
- **Structured metric verification** — fill this table for EVERY metric in the sprint.
  Empty cells = gate cannot close.
  ```
  ## Metric Verification — Sprint N
  | #  | Item(s)             | Metric              | Action Taken         | Status   | Evidence / Escalation                   |
  |----|---------------------|---------------------|----------------------|----------|-----------------------------------------|
  | 1  | CORE-001            | [metric from roadmap] | [what was done]    | ?        | [test link / escalation reason]         |
  | ...| ...                 | ...                 | ...                  | ...      | ...                                     |
  Action Taken values:
    existing   = test already existed and passed — no action needed
    written    = new test written this sprint
    fixed      = test existed but failed — code fixed to pass
    revised    = metric threshold or definition revised (note original → new)
    added      = metric was missing at sprint start — added during Entry/Close Gate
    escalated  = could not resolve — escalated as DEFERRED with reason
  Status values:
    PASS     = test exists + passes (link to test file:line)
    DEFERRED = blocked by prerequisite (must follow escalation below)
    FAIL     = test exists but fails (fix before closing; if unfixable → escalate as DEFERRED)
    MISSING  = no test exists (write one; if untestable → escalate as DEFERRED with reason)
  Rule: every row must be PASS or DEFERRED (with escalation). MISSING/FAIL → gate blocked.
  If a FAIL/MISSING metric cannot be resolved: escalate to user — present options
  (accept gap with target sprint, or §Sprint Abort if the metric is critical).
  Guard: if ALL metrics are DEFERRED → gate blocked. At least one metric must PASS.
  Present to user: "All metrics are deferred — no verified work this sprint.
  Options: (1) resolve at least one metric now to unblock gate, (2) §Sprint Abort."
  User decides.
  ```
- Unmet metric escalation — when a metric is DEFERRED or MISSING:
  Do NOT silently mark `[ ]` and move on. Required steps:
  1. **Explain** — what is blocking completion? (missing data, unfinished prerequisite, external dependency)
  2. **Trace** — is the blocker tracked in the roadmap? (has a CORE-### entry?)
     - Not tracked → propose adding it with a recommended sprint and priority level.
     - Tracked but no sprint assigned → propose a target sprint with reasoning.
  3. **Recommend** — present the gap analysis and a concrete proposal to the user.
     Include: what's done, what's missing, which sprint should finish it, and why.
  4. **User decides** — user picks target sprint and priority. Agent does not decide alone.
  5. **Log** — TRACKING.md: status = `deferred`, reason + target sprint documented.
- **Present completed table to user** — after all metrics are resolved (PASS or DEFERRED),
  present the full Metric Verification table to the user before proceeding to Phase 1a.
  This is mandatory regardless of which path was taken (test written or escalated).
  User sees every metric's final status and evidence. No silent close.
- **Log compact summary to TRACKING.md** — do NOT copy the full table.
  Write a one-line summary: `**Metric Verification:** X/Y PASS, Z DEFERRED (item-id reason → S<N>, ...)`
  The full table lives in the session; tests in the codebase are the persistent evidence.
  DEFERRED items already have their target sprint logged via the escalation procedure above.

**Phase 1a — Automated scan:**
- Run `Tools/sprint-audit.sh`
- Exit code 2 (setup error): fix script configuration (paths, patterns) before proceeding.
  Do not skip the automated scan — fix the script first.
  If the script cannot be adapted (unsupported language, missing tooling): present to user —
  "sprint-audit.sh cannot run ([reason]). Proceeding with manual audit only (Phase 1b). Confirm?"
  User approves before skipping. Log `sprint-audit.sh: not applicable — [reason]` in
  TRACKING.md Change Log.
- Exit code 1 (findings): review each finding, fix immediately or log with target sprint
  (user decides which findings to defer — same principle as Phase 2).
  **Blocker findings** (e.g., UNTRACKED_DEBT — naked `TODO`/`FIXME`/`HACK` without a CORE-ID)
  must be resolved before the gate can pass. Options: formalize as `// TEMP(CORE-NNN): [reason]`
  with a TRACKING.md entry, or resolve the debt now. Cannot be deferred as-is.
  **False positive review:** UNTRACKED_DEBT uses case-sensitive substring matching (`TODO`,
  `FIXME`, `HACK` — uppercase only). Typical camelCase names (`todoItems`) are not caught.
  However, SCREAMING_CASE identifiers (`TODO_ITEMS`) or strings containing uppercase markers
  are caught. Review each finding; false positives can be dismissed with a note in the scan summary.
  Present automated scan summary to user before proceeding to Phase 1b.
- Exit code 0 (clean): proceed (note "clean" to user before Phase 1b).

**Phase 1b — Spec-driven audit:**
Load Entry Gate data before starting:
- TRACKING.md §Predicted Failure Modes (written at Entry Gate 9a)
- S<N>_ENTRY_GATE.md verification plan per item (Entry Gate 9b invariants)

Abbreviated gate check (do this first):
- Is TRACKING.md Change Log entry for Entry Gate marked "Entry Gate (abbreviated)"?
  YES → §Predicted Failure Modes was cleared after abbreviated gate step 2 (no new
        predictions written for this sprint — step 9a was skipped). Skip step b for all items.
        Verification plan (9b-lite) still applies to step c.
  NO  → proceed normally (steps a, b, c for each item).

For each completed item (Must + Should + Could):
  a. Find implementing files:
     - VCS=git: `git diff` filtered by item context
     - VCS=none: read Entry Gate implementation plan notes for the item.
       If notes are insufficient or ambiguous: ask user explicitly —
       "For [CORE-###], which files did you modify?" — review those files.
       Log the user-provided file list in TRACKING.md Change Log for audit trail.
  b. Predicted failure modes → is each mode handled in code?
     - Direct: does the item break on its own? (null ref, off-by-one, wrong calc, missing guard)
     - Interaction: does combining with other systems cause failure? (timing, shared state, dispatch order)
     - Stress/edge: does extreme input/load/timing expose a break? (pool exhaustion, rapid oscillation, cascade)
  c. Verification plan invariants (from Entry Gate 9b) → do they hold in the implementation?
     ("Algorithmic items: what invariants must hold?" — if 9b specified them, check they are enforced in code)

Supplemental per-file check (issues outside item scope):
1. Resource/memory leaks
2. Missing observability (logging, profiling)
3. Dead code and orphan scaffolding
4. Debug path parity with production

Output: per-item summary (CORE-### → failure modes: HANDLED / MISSED / N/A)
        + supplemental findings per file.
  HANDLED = mode is applicable and addressed in code.
  MISSED  = mode is applicable but not addressed — must fix or defer.
  N/A     = mode is not applicable to this item's domain
            (e.g., stress/edge for a pure UI label item).
            Use sparingly: justify why it cannot apply.
Present summary to user before proceeding to Phase 1c.
Do not declare "audit complete" without per-item acknowledgment.

**Phase 1c — Fitness review:**
Read sprint type from Entry Gate report (step 12a).
Per completed item, answer three questions:
1. Is the implementation complete, or does it only cover the happy path?
2. Does it integrate correctly with the rest of the system (not just in isolation)?
3. Does it meet the project's Critical Axis standard (not just "no errors")?
Hardening sprint adjustment: if sprint type is hardening, focus Q1 on robustness
(edge cases, error paths) rather than feature completeness, and Q3 on "more robust
than before" rather than "meets new thresholds."
Per-item verdict: PASS or CONCERN (with explanation).
If all items CONCERN with no actionable fix → flag to user before proceeding.
Skip this phase for abbreviated-gate sprints (fitness metrics were not set at Entry Gate 9c).

**Phase 2 — Fix:**
- Fix immediately or log with target sprint (user decides which findings to defer).
- Critical Axis rule: read CLAUDE.md §Project Summary → Critical Axis.
  Any finding that touches the Critical Axis domain cannot be silently deferred.
  If deferral is proposed for a Critical Axis finding:
    → Stop. Present to user explicitly: "This finding touches [Critical Axis].
       Deferring [security/performance/...] findings is high risk in this project.
       Options: (1) fix now, (2) defer with explicit written rationale + target sprint,
       (3) invoke Sprint Abort if the risk is unacceptable."
    → User must choose explicitly. AI does not decide alone.
- After Phase 2: present fix/defer summary to user before proceeding to Phase 3.
  Show: which findings were fixed, which logged to target sprint with reason.
  Flag any deferred Critical Axis findings separately.

**Phase 3 — Regression test:**
- All tests must PASS after fixes
- Include any tests marked "pending" during D.6 that can now execute (infra available at Close Gate)
- If any test fails (including previously pending tests): return to Phase 2 — treat as new
  finding (fix immediately or defer with user decision, same escalation as Phase 2).
- Phase 2 → Phase 3 cycle: if same finding fails regression test 3 times after fix attempts →
  escalate to user: "Options: (1) defer with target sprint, (2) Sprint Abort if critical." User decides.

**Phase 4 — Test coverage gap:**
- 4a. File-level: new/modified code → matching test file exists?
- 4b. Item-level: every completed item (Must+Should+Could) → behavioral test exists?
  Log item → test mapping in TRACKING.md evidence. No test → write one or document why untestable.
- Present coverage gap summary to user before final test run:
  Show: which gaps were found, which tests were written, which items documented as untestable.
- Final test run PASS

**Close Gate verdict & user approval:**
- **Pre-verdict guard (mandatory):** Before issuing any recommendation, AI must confirm
  that ALL of the following phases were explicitly completed in this session:
  - Phase −1: items and metrics listed from source files? YES/NO
  - Phase 0: metric verification table filled and presented? YES/NO
  - Phase 1a: automated scan run (or documented as not applicable)? YES/NO
  - Phase 1b: spec-driven audit run per item? YES/NO
  - Phase 1c: fitness review run per item (or skipped for abbreviated gate)? YES/NO
  - Phase 2: findings fixed or deferred with user decision? YES/NO
  - Phase 3: regression tests PASS? YES/NO
  - Phase 4: coverage gaps resolved? YES/NO
  Any NO → run that phase before issuing the verdict.
  TRACKING.md showing items as `verified` is NOT a substitute for running these phases.
  "Sprint looks done" or "ready to close" without this checklist is a protocol violation.
- AI provides close gate assessment:
  - **Metric summary:** X/Y PASS, Z DEFERRED (list deferred items + target sprints).
    Include action breakdown: N existing, M written, K fixed, J revised, L added, P escalated.
  - **Findings summary:** N fixed, M deferred to target sprint, K untestable items
  - **Fitness summary:** X/Y PASS, Z CONCERN (list concerns). Omit if Phase 1c was skipped (abbreviated gate).
  - **Risk assessment:** clean / attention points exist (list them)
  - **Recommendation:** "Gate passed — recommend closing sprint" or "Gate blocked by [X]"
- User approves before Sprint Close begins.
  User does not approve → identify concern → return to the relevant phase for rework:
  Phase 0 (metric concerns) / Phase 1a (automated scan concerns) / Phase 1b (audit concerns)
  / Phase 1c (fitness concerns) / Phase 2 (fix/defer decisions) / Phase 3 (regression failures) / Phase 4 (coverage gaps).
- After approval: Update CLAUDE.md §Last Checkpoint: "Close Gate complete — Sprint N approved, starting Sprint Close."
  Session boundary (mandatory): Implementation session is heavily consumed by the time Close Gate runs.
  AI MUST recommend starting a fresh session to run Close Gate ("Run Close Gate, sprint N").
  User may choose to continue in the same session — that decision rests with the user.
  Close Gate + Sprint Close can run in the same session — Sprint Close is lightweight.

---

## Sprint Close — Post-Gate

1. Roadmap checkmarks
   Run `sprint-audit.sh` (full script runs — focus on Section 11 output for sync).
   Fix all mismatches before ticking.
   [x] = TRACKING.md verified (gate evidence logged)
   [~] = skipped + reason documented inline
   [ ] = not verified (open, in_progress, or fixed without evidence)
   Every [ ] item requires action — do NOT silently skip:
   → apply the unmet-metric escalation from Close Gate Phase 0
     (explain gap, trace blocker, propose target sprint, user decides).
   If gap is unacceptable and cannot be deferred: reopen Close Gate Phase 0 for that item —
   do not mark sprint done until resolved or explicitly accepted by user.
   After all checkmarks are applied: archive completed sprint sections older than 1 sprint
   to Docs/Archive/roadmap-archive.md. Keep active sprint + 1 previous sprint in Roadmap.md.
   Sprint Overview table stays in Roadmap.md (it is a summary, not per-sprint detail).
2. TRACKING.md update — `fixed → verified` transition:
   For each item being marked `verified`, confirm before writing:
   - Evidence column is filled (test file:line or run reference from Close Gate Phase 4b).
     Empty evidence column → item cannot be marked `verified`. Return to Close Gate Phase 4b,
     then re-run Phase 3 (regression check), then return to Sprint Close step 2.
     Return to Phase 4b twice for same item, still no evidence → escalate to user:
     "Options: (1) mark as untestable — stays `fixed` not `verified`, document rationale,
     (2) defer item with target sprint." User decides.
   - Status was `fixed` (not `open` or `in_progress`) — intermediate states cannot skip to `verified`.
   All Must items verified with evidence logged; completed Should/Could also updated.
3. CLAUDE.md checkpoint update (date, status, next focus)
4. Changelog archive (move entries to Docs/Archive/)
5. Performance baseline capture:
   - Record measurable metrics, compare vs previous sprint, flag regressions.
     If regression detected → surface to user: "⚠ Performance regression: [metric] was [X]
     in Sprint N-1, now [Y]. Options: (1) fix now — reopen Close Gate Phase 2,
     (2) accept and log in §Open Risks with target sprint." User decides.
   - If regression is intentional and accepted by user: add a new row to §Performance Baseline
     Log with the accepted value. This resets the comparison baseline so CP1 does not
     re-fire next sprint for the same accepted change.
   - No measurable metrics yet? Log: "Performance baseline: not yet established.
     Target: [which metrics to set up] by Sprint [N]." This is valid for early sprints.
     Do not invent fake baselines.
6. Workflow integrity check:
   - §Open Risks cleanup: review each R-### entry. Resolved → mark "RESOLVED — [date]."
     Do not delete — preserve audit trail. Entries older than 3 sprints with status RESOLVED
     may be archived to Docs/Archive/.
   - CLAUDE.md §Document Contract references → do target files and sections exist?
   - Guardrails §Entry Gate / §Close Gate → consistent with SPRINT_WORKFLOW.md procedures?
   - Do not manually count steps/phases. Instead: verify that each numbered step in
     SPRINT_WORKFLOW.md has a corresponding action (not that counts match across files).
   - Mismatch → fix before closing sprint.
     If irreconcilable → document discrepancy in TRACKING.md §Open Risks with target sprint.
7. Failure mode retrospective:
   a. Reconstruct actual failures: review Sprint Board for items that went through fix cycles,
      Change Log for bug-related entries, and §Failure Encounters (if logged during implementation).
      Also check Change Log for "Side fix:" entries — scope-outside fixes made during implementation.
      Include these in the retrospective (they are real bugs, even if unplanned).
      List every failure encountered with: Item, Category (direct/interaction/stress-edge), Detection method.
   b. Read TRACKING.md §Predicted Failure Modes (written at 9a).
   c. **Fill structured retrospective table** — one row per predicted mode + one row per actual failure:
      ```
      ## Failure Mode Retrospective — Sprint N
      | Predicted Mode | Predicted? | Actually Occurred? | Detection | Impact | Root Cause | New Guardrail? |
      |---------------|------------|-------------------|-----------|--------|------------|----------------|
      Every predicted mode must have an "Actually Occurred?" answer (yes/no).
      Every actual failure must appear — including unpredicted ones (Predicted? = no).
      Empty rows = step incomplete.
      ```
   d. Transfer rows to TRACKING.md §Failure Mode History (include Detection column: test / user-visual / profiler).
   e. Unpredicted failure → new guardrail rule. Before adding: present proposed rule to user —
      "Unpredicted failure [X] suggests guardrail: [rule]. Add to CODING_GUARDRAILS.md?"
      User approves before proceeding. Then follow §Update Rule
      (7 steps: dedup check, root cause, rule, anti-pattern, code comment, sprint-audit.sh, LESSONS_INDEX.md).
   f. Check §Failure Mode History for escalation triggers:
      - Same category 2+ times in last 3 sprints → flag "Architecture Review Required" at next Entry Gate
      - Same detection=user-visual 2+ times → flag "Can automated proxy test replace visual check?" at next Entry Gate
      Record flags in TRACKING.md §Open Risks so Entry Gate 9a picks them up.
   g. **Present completed retrospective table to user** before proceeding to step 7h.
   h. **Sprint index update** — update `Docs/SPRINT-INDEX.md`:
      Scan TRACKING.md for tagged entries (`<!-- topics:... -->`) from this sprint.
      For each tagged entry: add a one-line summary under each relevant topic heading,
      newest first. Create new topic headings as needed. If a topic has no entries in
      last 5 sprints, archive that topic section to `Docs/Archive/sprint-index-archive.md`.
      Also tag and index any untagged significant entries discovered during the retrospective
      (failures, decisions, guardrails added this sprint).
      **Topic naming consistency:** before creating a new topic heading, scan existing headings
      for synonyms (e.g. `auth` vs `authentication` vs `login`). Reuse the existing name.
      If genuinely distinct, create new. When in doubt, use the shorter, more general term.
   i. **Guardrail hygiene** — check `Docs/CODING_GUARDRAILS.md` size:
      If file exceeds 800 lines: flag to user "Guardrails file is [N] lines — consider pruning."
      Pruning actions (user decides which, if any):
      - Root cause descriptions → one sentence max (full story lives in sprint archive)
      - Code examples → one WRONG + one CORRECT pair per rule (remove extras)
      - Over-engineering notes / design justification → move to DESIGN.md or remove
      - Anti-patterns duplicated between §Anti-Pattern Quick Reference and domain sections → deduplicate
      Do not prune automatically — present the size and options, user decides.
      Skip if file is ≤800 lines or project has no guardrails file.
8. Failure Mode History maintenance:
   - If §Failure Mode History exceeds 30 rows: archive rows older than 5 sprints
     to Docs/Archive/failure-history-S1-S[N].md. Keep last 5 sprints in TRACKING.md.
   - Entry Gate 9a only needs recent history (last 3 sprints) for pattern detection.
9. Sprint Board maintenance:
   - Verified items older than 3 sprints → archive to Docs/Archive/sprint-board-archive.md.
     Keep current sprint + last 3 sprints in TRACKING.md.
10. Performance Baseline Log maintenance:
    - Keep last 5 sprints. Older rows → Docs/Archive/baseline-archive.md.
      CP1 only needs the last 2 sprints for regression detection.
11. Retroactive Audits maintenance:
    - CLOSED audits older than 3 sprints → archive to Docs/Archive/audits-archive.md.
      OPEN / IN_PROGRESS audits are never archived.
12. Dismissed Signals maintenance:
    - Suppressed signals older than 3 sprints → archive to Docs/Archive/signals-archive.md.
      Non-suppressed signals are never archived (they may still re-surface).
13. Entry Gate report cleanup:
    - Delete `Docs/Planning/S<N>_ENTRY_GATE.md` — its purpose (sprint-scoped reference) is fulfilled.
    - The gate execution log in TRACKING.md (from Entry Gate step 12d) persists as the permanent record.
14. User handoff summary:
    For each completed item, present to user:
    - **Before/after:** what changed in behavior (1-2 sentences, non-technical)
    - **How:** implementation approach in one sentence (user-level, not method names)
    - **Where:** file name / Inspector path so user can find it
    - **Verify:** specific runtime action + expected result
    - **Should NOT change:** what to check for regressions
    Invisible sprint (no visual change)? State explicitly:
    "No visible change — verify via [specific diagnostic/counter/log]"
    Present before marking sprint done. Do not skip if user "already knows" —
    the summary serves as a session handoff record, not just explanation.
15. Sprint "done"
    Log to TRACKING.md: "Sprint Close: [date], steps 1-15 ✓"

---

## Anti-Pattern Quick Reference

| # | Anti-Pattern | Correct Approach | Ref |
|---|-------------|-----------------|-----|
| 1 | [pattern] | [correct] | §X.Y |

---

## Update Rule

1. Check LESSONS_INDEX.md and anti-pattern table — does a rule for this root cause already exist?
   Yes → strengthen existing rule (tighten scope, add example). No → continue.
2. Identify root cause of bug
3. Add rule to relevant section
4. Add to anti-pattern table
5. Reference in code comment
6. Update sprint-audit.sh if pattern is grep-detectable
7. Add entry to Docs/LESSONS_INDEX.md (RuleID, root cause, guardrail section, sprint, source item)

### Mid-Sprint Scope Change

When an urgent item (critical bug, security fix, user-requested change) must enter a sprint
that has already passed Entry Gate:

```
1. User requests scope change (AI never initiates scope changes unilaterally)
2. AI assesses impact:
   a. Does the new item conflict with in-progress items?
   b. Does it invalidate any verified items? (if yes → regression, see §State Transitions.
      Before implementing fix: AI briefly re-assesses — what failure mode caused the regression?
      What test will verify the fix? Log in TRACKING.md. Full Entry Gate not required.
      If no → no regression impact, continue to next check)
   c. Will it push the sprint over scope limit?
3. AI presents options to user:
   - Add as new Must item (may push Should/Could to next sprint)
   - Add as new Must item + defer an existing Must item to make room (user picks which).
     Deferred item: TRACKING.md status → `deferred` + reason, Roadmap → `[~]`.
   - Add as hotfix outside sprint scope (no ID, no gate — emergency only).
     Hotfix = critical bug or security fix that cannot wait for next sprint's Entry Gate.
     Not eligible: new features, non-critical bugs, nice-to-haves.
     If item does not meet criteria: AI flags — "This item does not qualify as hotfix
     (not critical/security). Recommend adding as Must item instead." User overrides if needed.
     Hotfix still requires: TRACKING.md Change Log entry with description,
     test if testable, and inclusion in Sprint Close step 7 retrospective.
     Only the formal ID assignment and gate process are skipped.
   - Defer to next sprint (item not added now: log in Roadmap as future sprint sketch item)
4. User decides
5. Log decision in TRACKING.md Change Log:
   "Scope change: [date] — added [ID] mid-sprint. Reason: [why]. Impact: [what shifted]."
6. If new Must item added: create TRACKING.md entry (status: open), add to Roadmap
```

Rule: a scope change is NOT a new Entry Gate. The existing sprint plan stays valid;
only the added/removed items change.

### Scope Negotiation

When features exceed the sprint scope limit (Q2 at Initial Planning, or Phase 0 decomposition):

```
1. AI sorts features by dependency order + user-stated priority
2. First N features (where N = scope limit) become Must items for the sprint
3. Remaining features:
   a. If the feature is critical but can't fit → ask user: "Increase scope size, or defer?"
      Increase scope applies to this sprint only. Q2 default scope size remains unchanged
      for future sprints. To change the permanent default: user must explicitly request it —
      AI logs in CLAUDE.md §Operational Rules: "Sprint scope updated from [old] to [new] per
      user request, [date]."
   b. If the feature is nice-to-have → AI proposes Should/Could or later sprint.
      User confirms placement before AI moves the item.
4. Present the allocation to user for approval
5. User can override any placement (move items between Must/Should/Could/later sprint)
6. After user approval: return to the step that triggered Scope Negotiation and continue.
```

Rule: AI proposes, user disposes. Never silently drop features — always show where they went.

### Immutable Contract Revision

Immutable contracts (in CLAUDE.md §Immutable Contracts) are not truly permanent —
they require explicit revision when project direction changes.

```
Revision trigger: user explicitly requests a change to a listed contract.
AI never initiates contract revision unprompted.

Revision procedure:
1. AI identifies all code, tests, and items that depend on the contract
2. AI identifies blast radius (do not change any status yet):
   - Which verified items would become invalid?
   - Which in-progress items are affected?
   - Which guardrail rules reference the contract?
3. AI presents impact summary to user:
   "Changing [contract] affects [N] files, [M] verified items, [K] guardrail rules."
4. User confirms revision
5. After confirmation: mark affected verified items → status `open` (regression)
6. Update CLAUDE.md §Immutable Contracts (old value → new value, date, reason)
7. Log in TRACKING.md Change Log:
   "Contract revised: [date] — [old] → [new]. Reason: [why]. Affected items: [list]."
8. Affected guardrail rules → update or remove
```

### Sprint Abort

When the user decides to abandon a sprint mid-way (wrong direction, requirements changed drastically):

```
1. User requests abort (AI never initiates abort)
2. Mark all non-verified items as `deferred` with reason: "sprint aborted — [reason]"
3. Verified items keep their status (work is not lost)
4. Sprint branch cleanup (VCS=git only):
   - If verified items exist → cherry-pick their commits to main, then delete branch:
     git checkout main
     git tag sprint-N-pre-cherry-pick   # safety bookmark before cherry-picks
     git cherry-pick <verified-item-commits>
     # Post-cherry-pick verification: run test suite to catch broken cross-item dependencies
     # If tests fail → revert to safety bookmark (exact, no counting):
     #   git reset --hard sprint-N-pre-cherry-pick
     #   git tag -d sprint-N-pre-cherry-pick
     # Then investigate: retry selectively or defer all items to next sprint.
     git tag sprint-N-abort
     git branch -D sprint-N-impl
   - If no verified items → delete branch directly:
     git checkout main
     git tag sprint-N-abort
     git branch -D sprint-N-impl
   - main stays clean — only verified work lands.
   - Remote cleanup (if branch was pushed): `git push origin --delete sprint-N-impl`
5. Skip Close Gate (no items to audit)
6. Run abbreviated Sprint Close: steps 1-4 + step 6 + step 13 (checkmarks, TRACKING update,
   checkpoint, changelog archive, workflow integrity check, Entry Gate report cleanup).
   Skip steps 5, 7-12, 14, and 15 (no baselines, no FM retrospective, no archive maintenance
   for an aborted sprint). Abort step 7 below replaces the Sprint Close step 15 done log.
7. Log in TRACKING.md Change Log:
   "Sprint aborted: [date] — Reason: [why]. Verified: [list]. Deferred: [list]."
8. Next sprint Entry Gate runs normally — deferred items are reviewed at step 3
```

Rule: abort ≠ failure. Verified work persists, unfinished work is deferred, not deleted.

### Roadmap Realignment

**Purpose:** Re-synchronize Roadmap.md, TRACKING.md, and reality after unplanned events
(emergency fixes, mid-sprint pivots, accumulated scope creep, or multiple aborts) have caused
the planning documents to drift from the actual project state.

**When to use:** Roadmap no longer reflects what was actually built, deferred, or abandoned.
Items exist in one file but not the other. Sprint assignments are wrong. You look at the
roadmap and think "this isn't what happened."

**Who initiates:** User. AI may suggest realignment if it detects significant drift during
Entry Gate Phase 1 (e.g., orphan items, status mismatches), but the user decides.

```
Phase 1 — Snapshot current reality

1. Open TRACKING.md Sprint Board.
2. For each item, answer: "What is the ACTUAL status of this right now?"
   - Does the code exist and work? → verified (add evidence)
   - Does the code exist but is broken/incomplete? → open or in_progress
   - Was it intentionally skipped/postponed? → deferred (add reason + target sprint)
   - Was it abandoned and will never be done? → remove from Sprint Board,
     log in Change Log: "Removed: [ID] — [reason], [date]"
3. Update TRACKING.md statuses to match reality. Do not guess — check the code.

Phase 2 — Sync Roadmap.md to TRACKING.md

4. Open Roadmap.md Sprint Overview table.
   Update each sprint's Status column to match reality:
   - All items verified → completed
   - Some items still open → in_progress
   - Sprint was aborted → aborted
5. Walk through each sprint section in Roadmap.md:
   - Items verified in TRACKING.md → [x] in Roadmap
   - Items deferred in TRACKING.md → [~] in Roadmap + note target sprint
   - Items removed from TRACKING.md → delete from Roadmap sprint section
   - Items in TRACKING.md but missing from Roadmap → add to correct sprint section
   - Items in Roadmap but missing from TRACKING.md → either add to TRACKING.md
     (if still planned) or delete from Roadmap (if abandoned)
6. After sync: every CORE-### in TRACKING.md should appear in Roadmap.md
   and vice versa. No orphans.

Phase 3 — Repair forward plan

7. Identify items with status open/in_progress/deferred that have no sprint assignment
   or are assigned to a past sprint. These are "homeless items."
8. For each homeless item, user decides:
   - Assign to next sprint (add to that sprint's section in Roadmap)
   - Assign to a future sprint (add to sketch section)
   - Drop entirely (remove + log in Change Log)
9. Check sprint scope: if next sprint now has too many Must items from accumulated
   deferrals, run Scope Negotiation (see §Scope Negotiation above).

Phase 4 — Log and checkpoint

10. Log in TRACKING.md Change Log:
    "Roadmap realignment: [date] — Reason: [why drift occurred].
     Moved: [list]. Removed: [list]. Added: [list]."
11. Update CLAUDE.md §Last Checkpoint with current state.
12. Proceed to normal Entry Gate for next sprint.
```

Rule: realignment is a one-time cleanup, not a recurring process. If you need it often,
the root cause is likely insufficient Mid-Sprint Scope Change discipline — items are being
changed without logging. Address the process, not just the symptoms.

### Retroactive Sprint Audit

**Purpose:** Systematically audit a completed sprint when its output is found to be broken,
non-functional, or inconsistent with Close Gate claims in a later session.
This is evidence-based archaeology — not a blame exercise. Goal: locate the gap, classify it,
and resolve it with minimal disruption to the current sprint.

**Triggers — any one is sufficient to open an audit:**
- A runtime metric contradicts a Close Gate verdict
  (e.g., cache hit rate = 0% when Close Gate logged "verified"; FPS budget exceeded when sprint claimed "< Xms")
- A later sprint cannot build on a completed sprint's output (integration failure, API mismatch, missing output)
- A guardrail check now fails on code that was verified in the target sprint (sprint-audit.sh regression)
- A profiler shows a system that should be active is not running (cost = 0 → system is off, not optimized)
- User observes behavior that explicitly contradicts a verified item ("this was supposed to work")
- §Failure Mode History shows the same category 2+ times in recent sprints, tracing back to a specific earlier sprint
- Entry Gate §Open Risks contains a flag pointing at a specific past sprint's output

**Who initiates:** User or AI.
- User: any time a trigger is observed.
- AI: proactively, when a detection signal fires at a workflow checkpoint (see §Auto-Detection below).
  AI never opens an audit unilaterally — it proposes; the user confirms.
  AI never silently dismisses a detection signal — if signal fires, it must surface it.

**Scope rule:** One audit open at a time. If symptoms span multiple sprints, open the oldest
implicated sprint first. Resolve before opening the next.

**Audit depth limit:** Maximum 3 months back. For older sprints: present findings to user,
document in TRACKING.md §Open Risks, and treat as accepted technical debt unless user
explicitly requests a manual code archaeology exercise outside this workflow.

**Current sprint impact:** An audit does not pause current sprint implementation. However,
if the audit finds a blocker for a current sprint Must item: the blocker must be resolved
before Close Gate (implementation continues, but gate is blocked until resolved).
Resolution items are added to the current sprint (via Mid-Sprint Scope Change) or the next
sprint's backlog.

---

#### Phase 0 — Audit Setup

Before doing any file reading or measurement, establish:

```
1. Target sprint number: S[N]
2. Symptom (observable, measurable — not vague):
   BAD:  "S6 cache seems broken"
   GOOD: "S6 Data Cache: Hit=0, Miss=122, Rate=0% — Close Gate claimed 'cache verified'"
3. Close Gate claim being questioned:
   Quote the exact verified item or metric from TRACKING.md or S<N>_CLOSE_GATE.md.
   If no record exists → this becomes a FALSE_VERIFICATION finding immediately (Phase 4).
4. Blast radius estimate:
   List sprints that depend on target sprint's output (from Roadmap dependency map).
   Example: S6 (Data Cache) → S7 (Streaming depends on cache), S8 (profiler uses cache stats)
5. Present setup summary to user:
   "Opening Retroactive Audit for S[N]. Symptom: [X]. Claim questioned: [Y]. Depends-on chain: [Z].
    Proceeding with Phase 1 evidence collection."
   Wait for user confirmation before proceeding.
```

---

#### Phase 1 — Evidence Collection

Read all available artifacts from the target sprint in this order:

```
1. S<N>_CLOSE_GATE.md (Docs/Planning/) — if it exists (not created by default workflow;
   may exist if manually saved during Close Gate session)
   → read Phase 1b audit table, Phase 2 verdict, all metrics
   → if absent (typical case): proceed directly to TRACKING.md

2. TRACKING.md §Sprint N
   → all verified items (status = verified) with their evidence logs
   → all metric gate values recorded
   → Failure Mode Retrospective for Sprint N
   → Change Log entries dated within Sprint N

3. Roadmap.md Sprint N section
   → which items are [x] (verified) vs [~] (deferred)?
   → note any items that were silently [~] without documented reason

4. Git log for target sprint
   → git log --oneline <phase-tag-before>...<phase-tag-after> (if tags exist)
   → git log --oneline --since="[sprint start date]" --until="[sprint end date]"
   → look for: last-minute commits, hotfix commits, revert commits

5. sprint-audit.sh output (if preserved in TRACKING.md or Docs/)
   → section 11 output: were all items verified?
   → any check that was WARN or SKIP at close?

6. CODING_GUARDRAILS.md rules added during Sprint N
   → what rules existed at Sprint N time? (git blame or log)

7. Failure Mode History entries from Sprint N
   → what was predicted? what actually occurred?
```

Evidence collection output — fill before proceeding to Phase 2:
```
## Audit Evidence — Sprint N
Close Gate record found: YES / NO (if NO → FALSE_VERIFICATION likely)
Verified items at Close Gate: [list of CORE-### with their claimed evidence]
Metric gates at Close Gate: [list of metric name + value]
Git commits in sprint: [count] — notable: [any reversions/hotfixes]
sprint-audit.sh at close: PASS / WARN / SKIP / not preserved
Failure modes predicted: [list]
Failure modes that actually occurred: [list]
```

---

#### Phase 2 — Current State Assessment

Measure the system as it stands today — using the same measurement method as Close Gate.

```
1. Run sprint-audit.sh (full run)
   → record which sections PASS / FAIL / WARN vs Close Gate state

2. Run the target system's specific measurement:
   → If performance claim: profiler capture in relevant test scene (same camera, same conditions)
   → If test claim: re-run the exact test suite that was verified
   → If integration claim: trace the data flow from entry point to output
   → If metric claim: reproduce the metric (frame count, cache rate, memory, etc.)

3. Enable diagnostic output if available:
   → debug overlays, log verbose, counters, HUD metrics
   → capture: screenshots, log excerpts, profiler screenshots

4. Check kill-switch state:
   → Is the system enabled? (feature flag, config toggle, build define)
   → Is it conditionally disabled? (scene-only, platform-only, requires init sequence?)

5. Check initialization sequence:
   → Does the system require warm-up frames before metrics are meaningful?
   → If yes: measure after warm-up (document warm-up frame count)

6. Dependency check:
   → Does the system depend on a previous system's output?
   → If yes: verify that previous system is running and producing output
```

Current state output — fill before proceeding to Phase 3:
```
## Current State — Sprint N Audit
Date of measurement: [date]
sprint-audit.sh result: [PASS/FAIL, section list]
System enabled (kill-switch): YES / NO / N/A
Measurements:
  [metric name]: [current value] (method: [how measured])
  [metric name]: [current value] (method: [how measured])
Dependency systems running: YES / NO / PARTIAL
Notes: [anything unusual about measurement conditions]
```

---

#### Phase 3 — Gap Analysis

Compare Phase 1 (Close Gate claims) vs Phase 2 (current measurements) systematically.

**Item-level comparison:**

```
For each verified item [x] in the target sprint:
```

| Item ID | Close Gate Claim | Current State | Match? | Notes |
|---------|-----------------|---------------|--------|-------|
| CORE-### | [exact claim from evidence] | [current observation] | YES / NO | [discrepancy detail] |

**Metric-level comparison:**

| Metric | Close Gate Value | Current Value | Delta | Within Tolerance? |
|--------|-----------------|---------------|-------|-------------------|
| [name] | [value at close] | [value now] | [±%] | YES / NO |

**Gap tolerance rules:**
```
Continuous metrics (ms, MB, %, count):
  < 5% delta    → measurement variance; note but do not classify as gap
  5-20% delta   → borderline; classify as gap, investigate root cause
  > 20% delta   → definitive gap; classify and resolve
  0 vs non-zero → always a gap (system on vs off is not variance)

Binary metrics (PASS/FAIL, exists/missing):
  Any difference → gap; no tolerance

Edge case — warm-start vs cold-start:
  If metric requires warm-up (e.g., cache hit rate needs N frames to populate):
  Measure at warm-start. If warm-start also fails → gap. If only cold-start fails → COLD_STATE.
```

**Gap summary table (fill before Phase 4):**
```
## Gap Summary — Sprint N Audit
Total items compared: [N]
Items with NO match: [list of CORE-###]
Metrics with gap: [list]
Items with YES match (confirmed working): [list]
```

---

#### Phase 4 — Root Cause Classification

For each gap identified in Phase 3, assign exactly one category:

| Category | Definition | Key Question |
|----------|-----------|-------------|
| **REGRESSION** | Was working at Close Gate; broken by code merged in a subsequent sprint | "Which commit after Sprint N broke this?" |
| **INTEGRATION_GAP** | Worked in isolation (sandbox/EditMode test) but was never wired into the runtime path | "Does the system actually get called in the live game loop?" |
| **FALSE_VERIFICATION** | Close Gate metrics were insufficient: test measured the wrong thing, or passed a cherry-picked case | "Would the Close Gate metric have caught this failure if it occurred then?" |
| **COLD_STATE** | Current behavior is correct for the current conditions (cache empty after clean build, kill-switch OFF, first run) | "Is this the expected state given current conditions?" |
| **SCOPE_DRIFT** | A later sprint changed requirements or contracts that made the earlier implementation invalid | "Did a later sprint's design decision break this retroactively?" |
| **ENVIRONMENT_DELTA** | Works in original environment; fails due to engine version, platform, or dependency change since Sprint N | "Did anything in the build environment change between Sprint N and now?" |

**Classification priority rule:**
If multiple categories could apply, assign primary category per this priority order:
`REGRESSION > INTEGRATION_GAP > FALSE_VERIFICATION > COLD_STATE > SCOPE_DRIFT > ENVIRONMENT_DELTA`
Note secondary category in evidence column: "Primary: REGRESSION. Contributing factor: SCOPE_DRIFT."

**Classification procedure for each gap:**
```
1. REGRESSION check:
   → git log --oneline <sprint-N-tag>..HEAD -- [affected files]
   → Did any commit after Sprint N modify the affected system?
   → If yes → candidate for REGRESSION. Identify the responsible commit.
   → Squash merge? Run `git show <merge-commit>` to read the per-item commit list
     embedded in the merge message. This reveals which CORE-### item changed the file.

2. INTEGRATION_GAP check:
   → Trace the call chain from the game loop entry point to the system.
   → Is there a missing hook, missing registration, or path that never reaches the system?
   → If yes → INTEGRATION_GAP.

3. FALSE_VERIFICATION check:
   → Read the Close Gate evidence for the item.
   → Would that evidence have caught the current failure mode at Sprint N time?
   → If not → FALSE_VERIFICATION.

4. COLD_STATE check:
   → What conditions would make the current behavior correct?
   → Are those conditions present? (kill-switch, cold cache, first run, missing asset)
   → If yes → COLD_STATE. Document expected behavior explicitly.
   → Staleness rule: COLD_STATE is valid for a maximum of 2 consecutive sprints.
     Consecutive = consecutive sprints in which this metric was actually measured.
     Sprints where the metric was not measured do not count toward or reset the counter.
     If the same metric shows the same cold-state failure for 3+ consecutive sprints
     despite normal project operation (runtime sessions, test runs), COLD_STATE is no
     longer a valid explanation. At the 3rd occurrence: take a warm-start measurement.
       - Warm-start passes → the system works but was always measured cold.
         Fix: update Close Gate procedure to mandate warm-start measurement for this metric.
         Classification stays COLD_STATE; add measurement protocol fix as Must item.
       - Warm-start also fails → the system is broken regardless of start conditions.
         Re-classify as INTEGRATION_GAP (system never actually warms up / is never called).
         Escalate: open Phase 0 regardless of prior dismissal history.

5. SCOPE_DRIFT check:
   → Did a subsequent sprint change an interface, format, or contract that this system depends on?
   → Check: Roadmap.md for contract revisions, TRACKING.md Change Log after Sprint N.
   → If yes → SCOPE_DRIFT.

6. ENVIRONMENT_DELTA check:
   → Engine/SDK/package version changes since Sprint N?
   → Platform target changes?
   → If yes → ENVIRONMENT_DELTA.
```

**Classification output:**
```
## Classification — Sprint N Audit
| Gap | Category | Evidence for Classification |
|-----|----------|-----------------------------|
| CORE-### [description] | REGRESSION | Commit [hash] on [date] modified [file] |
| [metric] gap | FALSE_VERIFICATION | Close Gate tested [X], current failure is [Y] — different scenario |
```

---

#### Phase 5 — Dependency Impact Assessment

For each gap classified as REGRESSION, INTEGRATION_GAP, FALSE_VERIFICATION, or SCOPE_DRIFT:

```
1. List all subsequent sprints that depend on the target sprint's output:
   → Use Roadmap.md dependency map (or TRACKING.md if dependency is documented there)

2. For each dependent sprint:
   a. Identify which of its verified items rely on the broken output
   b. Answer: does the gap affect the dependent item's correctness?
      - YES → mark that item as `open (regression)` in TRACKING.md
              Add note: "Re-verification required — see Retroactive Audit Sprint N, [date]"
      - NO  → document: "unaffected — gap is in [subsystem X], Sprint M used [subsystem Y]"

3. Re-verification scope rule:
   If ≥ 3 items require re-verification across dependent sprints →
   flag "Sprint Re-verification Cluster" in TRACKING.md §Open Risks.
   Present to user: "This gap affects [N] verified items across [M] sprints.
   Recommend scheduling a dedicated re-verification sprint."
   User declines → log in §Open Risks: "Re-verification cluster ([N] items) — user chose
   to address within current sprint. Items: [list]." Entry Gate next sprint re-checks at step 3.

4. Guardrail coverage check:
   For each classified gap: which guardrail rule should have prevented this?
   - Rule exists → was it present at Sprint N time? If not → when was it added?
   - Rule does not exist → create now (follow §Update Rule 7-step process)
   - Rule exists but was not enforced → add enforcement to sprint-audit.sh

5. Test coverage check:
   - Was there an automated test for the broken behavior?
   - If yes: why did it not catch the gap? (wrong assertion, wrong scenario, not run at gate)
   - If no: would one have been feasible? If yes → add as Must item for resolution sprint
```

**Dependency impact output:**
```
## Dependency Impact — Sprint N Audit
| Sprint | Dependent Item | Affected? | Action |
|--------|---------------|-----------|--------|
| S[M] | CORE-### [description] | YES | Mark open (regression) |
| S[M] | CORE-### [description] | NO | Unaffected — [reason] |

Re-verification cluster: YES (N items) / NO
New guardrail rules needed: [list or "none"]
New automated tests needed: [list or "none"]
```

---

#### Phase 6 — Resolution Plan

For each classified gap, define exactly one resolution path. Present all options to user; user decides.

**Resolution options:**

| Option | When to Use | Process |
|--------|------------|---------|
| **Fix now (current sprint)** | Gap is a blocker for current or next sprint's Must items | Add via §Mid-Sprint Scope Change as Must item |
| **Fix next sprint** | Gap is important but not immediately blocking | Add to next sprint Entry Gate backlog; log in TRACKING.md §Open Risks |
| **Accept + document** | Gap is COLD_STATE or acceptable limitation; no code change needed | Document expected behavior in TRACKING.md; update Close Gate metric definition |
| **Revert target sprint** | Gap is fundamental; fix would require redoing Sprint N from scratch | Present to user: "Sprint N output must be redone. Scope as a new sprint with Must items covering the affected deliverables." |
| **Quarantine** | Gap affects untested future scope only; no current sprint is broken | Add guard comment in code; flag at relevant future sprint's Entry Gate |

**Resolution output (one row per gap):**
```
## Resolution Plan — Sprint N Audit
| Gap | Category | Resolution Option | Target Sprint | Must-item ID | Blocker? |
|-----|----------|--------------------|--------------|--------------|---------|
| [description] | REGRESSION | Fix now | Current | CORE-[new] | YES |
| [description] | FALSE_VERIFICATION | Accept + document | Immediate | N/A | NO |
| [metric] gap | COLD_STATE | Accept + document | Immediate | N/A | NO |
```

**Blocking escalation rule:**
If a gap is REGRESSION or INTEGRATION_GAP and affects any current sprint Must item →
the gap is automatically a blocker. It must be resolved before the current sprint's Close Gate.
Present to user: "This audit found a blocker for the current sprint.
Recommend addressing [gap] before continuing with CORE-###."

---

#### Phase 7 — Audit Close

Required before marking audit complete and returning to current work:

```
1. Write audit summary to TRACKING.md §Retroactive Audits:

   ## Retroactive Audit — Sprint N
   Opened: [date] | Closed: [date]
   Trigger: [exact symptom that opened audit]
   Gaps found: [count]
   Classifications:
     REGRESSION: [count] — [brief description of each]
     INTEGRATION_GAP: [count] — [brief description]
     FALSE_VERIFICATION: [count] — [brief description]
     COLD_STATE: [count] — [brief description]
     SCOPE_DRIFT: [count] — [brief description]
     ENVIRONMENT_DELTA: [count] — [brief description]
   Items requiring re-verification: [list of CORE-### or "none"]
   New guardrail rules added: [list of rule IDs or "none"]
   New tests added: [list or "none"]
   Resolution: [summary — what was fixed now, what is deferred, what was accepted]
   Audit status: CLOSED

2. If FALSE_VERIFICATION found:
   Update Close Gate metric gate definition for Sprint N in TRACKING.md:
   "Metric gate updated post-audit [date]: [old gate] → [new gate]. Reason: [why original was insufficient]."
   Add improved metric to CODING_GUARDRAILS.md as a mandatory gate check.

3. If REGRESSION found:
   Add to TRACKING.md Change Log:
   "Regression identified [date]: Sprint N [system] broken by Sprint M commit [hash].
    Fix: [approach]. Responsible item: CORE-[new]."

4. If new guardrail rules created:
   Complete §Update Rule 7-step process for each rule.

5. If ≥ 1 item marked `open (regression)`:
   Ensure Entry Gate for next sprint will surface these at step 3 (deferred items review).

6. Present audit summary to user:
   "Audit closed. Found [N] gaps: [classification breakdown].
    [X] items need re-verification. [Y] new guardrail rules added.
    Resolution: [brief]. Resuming current sprint at [CORE-###]."

7. Resume current sprint work.
```

---

#### Auto-Detection — AI-Initiated Signals

The AI actively watches for suspicious signals at four checkpoints in the normal workflow.
When a signal fires, the AI **must** surface it to the user — it cannot silently continue.

**Detection format (mandatory when a signal fires):**
```
⚠ AUDIT SIGNAL — [Checkpoint]: [what was observed]
Past claim: Sprint N, CORE-###: "[exact close gate claim]"
Current observation: [measured value / behavior]
Delta: [quantified difference]
Proposed action: Open Retroactive Audit for Sprint N?
→ YES: proceed to Phase 0
→ NO: log signal in TRACKING.md §Dismissed Signals and continue
```

**Checkpoint 1 — Entry Gate Phase 1 step 3 (State Review)**

While reviewing TRACKING.md §Performance Baseline Log for the sprint being opened:
```
Signal fires if:
  - A metric that was logged as "verified" in a past sprint is now measurably worse
    AND the current sprint has not touched the responsible system
    Example: S6 claimed cache hit rate > 60%; sprint-audit baseline now shows 0%
             and the current sprint (S8) has not modified the cache system
  - A system is listed as "verified" in TRACKING.md but has no corresponding
    sprint-audit.sh check (verification cannot be reproduced)
  - A past sprint's metric gate value is missing from the baseline log
    (claimed verified but no number recorded)

Signal does NOT fire if:
  - Current sprint explicitly modified the responsible system (regression, not audit)
  - The metric is marked "not yet measurable" in the baseline log (COLD_STATE expected)
  - Delta is < 5% (within measurement variance)
  - The metric was previously dismissed as COLD_STATE AND fewer than 3 sprints have
    passed since the first dismissal (staleness not yet reached — see Phase 4 §COLD_STATE)
    ⚠ Once 3 sprints have passed under cold-state excuse, suppress is lifted automatically.
```

**Checkpoint 2 — Entry Gate step 9a (failure mode history scan)**

While reading §Failure Mode History for pattern detection:
```
Signal fires if:
  - Same failure category appears in 2+ sprints AND traces to a specific past sprint's output
    (not just repeated bugs — must converge on one sprint as the source)
    Example: INTEGRATION_GAP in S7, S8, S9 → all because S6 cache was never wired into runtime path
  - An "unpredicted" failure in a recent sprint maps to a system verified in an older sprint
    (the older sprint's verification did not predict this failure — FALSE_VERIFICATION candidate)
  - An open risk in §Open Risks is tagged with a sprint number older than current sprint - 2

Signal does NOT fire if:
  - Failures are in different systems with no shared dependency
  - Pattern is already tracked by an open audit (do not stack signals)
```

**Checkpoint 3 — Implementation session (live observation)**

During any implementation session, while reading code, running tests, or measuring:
```
Signal fires if:
  - AI is trying to use an output from a past sprint (API, buffer, file) and it is
    missing, differently shaped, or returning unexpected values
    Example: calling CacheManager.GetCachedValue() → always returns null
             despite S6 claiming "cache read path verified"
  - A test from a past sprint is now failing (sprint-audit.sh section regressed)
  - A profiler measurement contradicts a past sprint's metric gate by > 20%
    AND the current sprint has not modified the responsible system
  - A kill-switch that should be ON is OFF in the current scene/profile
    AND no sprint deliberately disabled it

Signal does NOT fire if:
  - The behavior is explained by a known Mid-Sprint Scope Change or Contract Revision
  - The system is in cold-start state (documented expected behavior)
  - The current sprint intentionally modified the system AND the modification intentionally
    changed the tested behavior (full redesign, replacement, or deliberate contract change).
    ⚠ Exception: if the modification broke a past sprint's verified guarantee as a side effect
    (breakage was unintended), the signal DOES fire — do not suppress it.
    Suppress example: "S8 replaced the entire cache system; S6 metrics no longer apply by design."
    Do NOT suppress: "S8 added config.threshold to ComputeKey() for CORE-106 but
    inadvertently broke S6's bit-exact output guarantee — that breakage was not the intent."
```

**Checkpoint 4 — Close Gate Phase 2 (verdict review)**

While computing the Close Gate verdict for the current sprint:
```
Signal fires if:
  - A Must item in the current sprint could not be verified because a dependency
    from a past sprint is not working as claimed
    Example: CORE-089 "cache improves streaming performance" cannot be measured
             because S6 cache hit rate is 0%
  - A deferred item (status: deferred) was first deferred 2+ sprints ago
    AND the reason for deferral references a past sprint's output
  - sprint-audit.sh produces a FAIL in a section that was PASS at the last sprint's close
    AND the failing code is from a sprint older than the current one

Signal does NOT fire if:
  - The dependency failure is already tracked by an open audit
  - The item was deliberately deferred due to scope (not dependency failure)
```

**Dismissed signal rule:**
If user says NO to a proposed audit, the signal is logged in TRACKING.md §Dismissed Signals:
```
## Dismissed Signals
| Date | Checkpoint | Signal Summary | User Decision | Revisit? |
|------|-----------|---------------|---------------|---------|
| [date] | Entry Gate step 6 | S6 cache hit 0% vs claimed >60% | NO — expected cold state | Next sprint Entry Gate |
```
A dismissed signal is re-surfaced at the next Entry Gate if the condition persists.
A signal dismissed twice for the same system is not re-surfaced unless a new trigger fires.

**Suppression scope (critical):** The two-dismissal suppression applies ONLY to
Checkpoint 1 and Checkpoint 2 re-surface logic at Entry Gate.
It does NOT apply to Checkpoint 3 (Implementation session) or Checkpoint 4 (Close Gate).
Those checkpoints evaluate independent observable consequences and are never suppressed
by prior dismissals — even if the same system was dismissed twice at Entry Gate.
Rationale: a dismissed signal means "user chose not to audit now." It does not mean
"the system is confirmed correct." When a new concrete failure manifests (blocked Must
item, implementation session failure), it overrides the user's prior "not now" decision.

**"Same system" definition:** A signal counts as the same system if it originates from
the same Checkpoint number AND references the same named subsystem (e.g., "CacheManager")
or the same CORE-### item. Signals from different Checkpoints, or referencing different
subsystems, are always independent — prior dismissal does not suppress them.

**"New trigger" definition:** A new trigger is any signal that either (a) originates from
a different Checkpoint than the previously dismissed signal, or (b) reports a different
observable consequence (e.g., a blocked Must item, a failing test, a new crash) rather
than re-observing the same metric. Re-observing the same metric at the same Checkpoint
is a re-surface, not a new trigger.

---

#### Integration with Existing Workflow

**Entry Gate step 3** (deferred items review):
→ Check TRACKING.md §Retroactive Audits for pending re-verification items.
   Items marked `open (regression)` from a past audit appear here as deferred items.

**Entry Gate step 9a** (failure mode history):
→ Audits closed in last 3 sprints are included in pattern analysis.
   Multiple audits of same category → "Architecture Review Required" flag.

**Close Gate Phase 1b** (abbreviated check):
→ If any current sprint item depends on an audited sprint's output:
   verify the dependency is using the corrected post-audit state, not the broken pre-audit state.

**Sprint Close step 7** (failure mode retrospective):
→ Cross-reference: if a gap was found via Close Gate (not audit),
   did a past audit predict this category? Pattern tracking.

**Sprint Close step 6** (workflow integrity check):
→ §Retroactive Audits section exists in TRACKING.md and is current?
   Audits without `status: CLOSED` → must be resolved before sprint marks "done".

### Roadmap.md Template

```markdown
# [Project Name] — Roadmap

## Sprint Overview

| Sprint | Focus | Dependencies | Status |
|--------|-------|-------------|--------|
| S1 | [focus area] | — | planned |
| S2 | [focus area] | S1 | planned |

---

## Sprint 1 — [Title]

**Goal:** [One sentence describing what this sprint achieves]

**Must:** (complete all before sprint is "done")
- [ ] CORE-001: [item description]
- [ ] CORE-002: [item description]

**Should:** (if budget remains after Must)
- [ ] CORE-003: [item description]
- [ ] CORE-004: [item description]

**Could:** (stretch goals)
- [ ] CORE-005: [item description]

**Metric gates:**
- [metric name]: [threshold] (how measured)

**Dependencies:** [list or "none"]

---

## Sprint 2 — [Title]

[Same structure as Sprint 1]
```

Checkbox notation:
- `- [ ]` = not verified (open, in_progress, or fixed — no gate evidence yet)
- `- [x]` = verified (TRACKING.md status = verified, gate evidence logged)
- `- [~]` = skipped / deferred (TRACKING.md status = deferred, reason documented inline)

Rule: checkbox tracks TRACKING.md status.
- `[x]` ↔ `verified`, `[~]` ↔ `deferred`. All other statuses → `[ ]`.
- Intermediate states (in_progress, fixed-untested) are NOT shown in roadmap.
- Checkbox format is mandatory. Plain bullets (`- CORE-###: ...`) break close gate tracking —
  `sprint-audit.sh` Section 11a/11c will not find them. Always use `- [ ] CORE-###: ...`.
- `sprint-audit.sh` Section 11 catches mismatches (including `[~]` ↔ `deferred` sync) automatically.

### LESSONS_INDEX.md Template

```markdown
# [Project Name] — Lessons Index

Maps bug root causes to guardrail rules. Grows as bugs are found and fixed.

| RuleID | Root Cause | Guardrail Section | Sprint | Source |
|--------|-----------|-------------------|--------|--------|
| G-001 | [what went wrong] | §1.1 | S1 | CORE-001 |
| G-002 | [pattern found in code] | §2.1 | bootstrap | bootstrap scan |

Source values: `CORE-###` (incident-driven), `bootstrap scan` (found during project setup).

This file starts empty on greenfield projects. Add entries when:
1. A bug is fixed and a guardrail rule is created
2. Bootstrap scan finds an anti-pattern in existing code (step 6)
3. A known anti-pattern from a previous project is imported
```

---

### Claude Code Hook Templates

**Only create these if the project uses Claude Code.** Other agents do not read `.claude/`.
Run `chmod +x .claude/hooks/*.sh` after creating the scripts.

**`.claude/hooks-config.sh`** — feature flags; set to `"false"` to disable a hook without touching `settings.json`:

```bash
# Claude Code Hooks — Feature Flags
# Toggle individual hooks on/off without touching settings.json
# Set WORKFLOW_MODE to auto-configure: "lite", "standard" (default), or "strict"

# Version — tracks which WORKFLOW.md version these hooks were generated from.
# Updated automatically during bootstrap and upgrade — do not edit manually.
HOOKS_VERSION="2.1"

WORKFLOW_MODE="standard"

# Mode-based defaults are set automatically (see actual file for case block).
# Individual overrides — uncomment to override the mode preset:

HOOK_PROTECT_CLAUDE_MD="${HOOK_PROTECT_CLAUDE_MD:-true}"
HOOK_PROTECT_SECRETS="${HOOK_PROTECT_SECRETS:-true}"
HOOK_VALIDATE_TRACKING="${HOOK_VALIDATE_TRACKING:-true}"
HOOK_SESSION_START_PROTOCOL="${HOOK_SESSION_START_PROTOCOL:-true}"
HOOK_VALIDATE_ID_UNIQUENESS="${HOOK_VALIDATE_ID_UNIQUENESS:-true}"
HOOK_ENTRY_GATE_SESSION="${HOOK_ENTRY_GATE_SESSION:-true}"
HOOK_DETECT_TEST_REGRESSION="${HOOK_DETECT_TEST_REGRESSION:-true}"
HOOK_VALIDATE_CLOSE_GATE="${HOOK_VALIDATE_CLOSE_GATE:-true}"
HOOK_VALIDATE_SPRINT_CLOSE="${HOOK_VALIDATE_SPRINT_CLOSE:-true}"
HOOK_DETECT_AUDIT_SIGNALS="${HOOK_DETECT_AUDIT_SIGNALS:-true}"

# Cross-LLM Audit (optional, independent of workflow mode)
# Disabled by default. Requires CROSS_AUDIT_API_KEY env var.
# See Docs/CROSS-LLM-AUDIT.md for setup.
ENABLE_CROSS_AUDIT="${ENABLE_CROSS_AUDIT:-false}"
# CROSS_AUDIT_PROVIDER="openai"    # "openai" (default) or "anthropic"

# Strict mode enforcement (overrides all individual flags to true)
```

**`.claude/settings.json`** — hook registrations:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/detect-audit-signals.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-claude.sh" }]
      },
      {
        "matcher": "Read|Bash",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-secrets.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-tracking.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-id-uniqueness.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cross-llm-audit.sh" }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/entry-gate-session.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-close-gate.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-sprint-close.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/detect-test-regression.sh" }]
      }
    ]
  }
}
```

**`.claude/hooks/protect-claude.sh`** — hard block; exit 2 aborts the Write:

```bash
#!/bin/bash
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_PROTECT_CLAUDE_MD" != "true" ]] && exit 0
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [[ "$TOOL" == "Write" ]] && [[ "$FILE" == *"CLAUDE.md"* ]]; then
    echo "BLOCKED: Writing to CLAUDE.md is not allowed (would overwrite existing content)." >&2
    echo "Use the Edit tool to append or modify specific sections." >&2
    exit 2
fi
exit 0
```

**`.claude/hooks/protect-secrets.sh`** — hard block; prevents AI from reading `.env`, `.key`, `.pem`, `credentials.json`.
6-layer Bash protection (direct reads, scripting languages, encoding tools, text processors, file redirects, env var exposure):

```bash
#!/bin/bash
# Hook: protect-secrets.sh
# Event: PreToolUse — Read, Bash
# Purpose: Prevent the AI from reading files that contain secrets.
#          API keys are managed by shell hooks (cross-llm-audit.sh) —
#          the AI should never see them directly.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_PROTECT_SECRETS" != "true" ]] && exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ── Block Read tool on secret files ──
if [[ "$TOOL" == "Read" ]]; then
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    BASE=$(basename "$FILE")

    # Allow .env.example (template, no secrets)
    [[ "$BASE" == ".env.example" ]] && exit 0

    case "$BASE" in
        .env|.env.*|*.key|*.pem|*.p12)
            echo "BLOCKED: Reading $BASE is not allowed — it may contain API keys or secrets." >&2
            echo "The cross-LLM audit hook reads .env automatically. You don't need to access it." >&2
            exit 2
            ;;
        credentials.json|secrets.yaml|secrets.yml)
            echo "BLOCKED: Reading $BASE is not allowed — it may contain secrets." >&2
            exit 2
            ;;
    esac
fi

# ── Block Bash commands that would expose secrets ──
if [[ "$TOOL" == "Bash" ]]; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

    # Helper: does the command reference a secret file?
    _has_secret_ref() {
        local cmd="$1"
        if echo "$cmd" | grep -qE '\.env([^a-zA-Z0-9_-]|$)'; then
            if ! echo "$cmd" | grep -qE '\.env\.example'; then
                return 0
            fi
        fi
        if echo "$cmd" | grep -qE 'credentials\.json|secrets\.ya?ml'; then return 0; fi
        if echo "$cmd" | grep -qE '\.(key|pem|p12)([^a-zA-Z0-9_-]|$)'; then return 0; fi
        return 1
    }

    # Layer 1: Direct read commands
    if echo "$CMD" | grep -qE '(cat|head|tail|less|more|bat|source)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        exit 2
    fi

    # Layer 2: Scripting languages
    if echo "$CMD" | grep -qE '(python|python3|perl|ruby|node|php)' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents via scripting." >&2
        exit 2
    fi

    # Layer 3: Encoding/dump tools
    if echo "$CMD" | grep -qE '(base64|xxd|od|hexdump|strings)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        exit 2
    fi

    # Layer 4: Text processing tools
    if echo "$CMD" | grep -qE '(awk|sed|grep|rg|jq|yq)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        exit 2
    fi

    # Layer 5: File redirects: < .env, $(<.env)
    if echo "$CMD" | grep -qE '<\s*\.env([^a-zA-Z0-9_-]|$)'; then
        if ! echo "$CMD" | grep -qE '\.env\.example'; then
            echo "BLOCKED: File redirect on .env detected." >&2
            exit 2
        fi
    fi

    # Layer 6: Explicit env var exposure
    if echo "$CMD" | grep -qiE '(echo|printf|printenv|env\s).*\$?\{?(CROSS_AUDIT_API_KEY|CROSS_AUDIT_.*KEY)'; then
        echo "BLOCKED: This command would expose the API key." >&2
        exit 2
    fi
fi

exit 0
```

**`.claude/hooks/validate-tracking.sh`** — soft warn (exit 1) after TRACKING.md edit:

```bash
#!/bin/bash
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_VALIDATE_TRACKING" != "true" ]] && exit 0
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
# Match TRACKING.md and TRACKING-[name].md (team per-person files)
BASENAME=$(basename "$FILE")
[[ "$BASENAME" != TRACKING*.md ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0
ERRORS=()
LEGAL="open|in_progress|fixed|verified|deferred|blocked"
ILLEGAL=$(grep -E '^\| CORE-[0-9]+' "$FILE" | awk -F'|' '{gsub(/ /,"",$4); print NR": "$4}' | grep -Ev "^[0-9]+:($LEGAL)$")
[[ -n "$ILLEGAL" ]] && ERRORS+=("Illegal status values: $ILLEGAL")
MISSING_EV=$(grep -E '^\| CORE-[0-9]+' "$FILE" | awk -F'|' '{gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6); if ($4=="verified" && $6=="") print $2}')
[[ -n "$MISSING_EV" ]] && ERRORS+=("'verified' items missing evidence: $MISSING_EV")
MISSING_RS=$(grep -E '^\| CORE-[0-9]+' "$FILE" | awk -F'|' '{gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6); if ($4=="deferred" && $6=="") print $2}')
[[ -n "$MISSING_RS" ]] && ERRORS+=("'deferred' items missing reason: $MISSING_RS")
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "TRACKING.md validation warnings:" >&2
    for e in "${ERRORS[@]}"; do echo "  $e" >&2; done
    exit 1
fi
exit 0
```

**`.claude/hooks/validate-id-uniqueness.sh`** — soft warn on duplicate `CORE-###`:

```bash
#!/bin/bash
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_VALIDATE_ID_UNIQUENESS" != "true" ]] && exit 0
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
# Match TRACKING.md and TRACKING-[name].md (team per-person files)
BASENAME=$(basename "$FILE")
[[ "$BASENAME" != TRACKING*.md ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0
DUPES=$(grep -oE 'CORE-[0-9]+' "$FILE" | sort | uniq -d)
if [[ -n "$DUPES" ]]; then
    echo "TRACKING.md ID uniqueness violation — duplicate CORE-### IDs found (never reuse an ID):" >&2
    while IFS= read -r id; do
        echo "  $id appears $(grep -oE "$id" "$FILE" | wc -l) times" >&2
    done <<< "$DUPES"
    exit 1
fi
exit 0
```

**`.claude/hooks/session-start.sh`** — injects session start protocol as additional context.
Handles four concerns: existing project (protocol), first-time setup (bootstrap guidance), cross-audit status (on/available/off), and version mismatch detection:

```bash
#!/bin/bash
# Hook: session-start.sh
# Event: SessionStart
# Purpose: Inject session start protocol context so the agent reads
#          TRACKING.md and CLAUDE.md before doing anything else.
#          WORKFLOW.md rule: "AI Agent Operational Rules — Session Start Protocol"

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_SESSION_START_PROTOCOL" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || { echo "WARNING: jq not found — session-start hook disabled. Install jq to enable workflow enforcement." >&2; exit 0; }

# Detect if TRACKING.md exists in working directory
TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)
CLAUDE_MD=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 1 -name "CLAUDE.md" 2>/dev/null | head -1)

if [[ -z "$TRACKING" && -z "$CLAUDE_MD" ]]; then
    # No workflow files found — guide user through first-time setup
    WORKFLOW_FILE=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 \( -name "WORKFLOW.md" -o -name "SPRINT_WORKFLOW.md" \) 2>/dev/null | head -1)
    if [[ -n "$WORKFLOW_FILE" ]]; then
        # WORKFLOW.md exists but project not bootstrapped yet
        jq -n --arg wf "$WORKFLOW_FILE" '{
          "additionalContext": (
            "=== FIRST-TIME SETUP DETECTED ===\n" +
            "WORKFLOW.md found but project is not bootstrapped yet.\n" +
            "No CLAUDE.md or TRACKING.md exists.\n\n" +
            "Guide the user:\n" +
            "  → \"Read \($wf) and bootstrap this project.\"\n" +
            "  → Or ask: \"Shall I bootstrap the sprint workflow for this project?\"\n\n" +
            "Do NOT start any implementation before bootstrap is complete.\n" +
            "================================="
          )
        }'
    fi
    # No WORKFLOW.md either — not a sprint workflow project, skip silently
    exit 0
fi

# ── Version mismatch detection ──
VERSION_WARNING=""
WORKFLOW_FILE=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 \( -name "WORKFLOW.md" -o -name "SPRINT_WORKFLOW.md" \) 2>/dev/null | head -1)
if [[ -n "$WORKFLOW_FILE" ]]; then
    # Extract workflow-version from WORKFLOW.md (<!-- workflow-version: X.Y -->)
    WF_VERSION=$(head -5 "$WORKFLOW_FILE" | sed -n 's/.*workflow-version: *\([0-9.]*\).*/\1/p')
    # HOOKS_VERSION is already sourced from hooks-config.sh
    HK_VERSION="${HOOKS_VERSION:-}"

    if [[ -n "$WF_VERSION" && -n "$HK_VERSION" && "$WF_VERSION" != "$HK_VERSION" ]]; then
        VERSION_WARNING="WORKFLOW VERSION MISMATCH: WORKFLOW.md is v${WF_VERSION} but hooks are v${HK_VERSION}. Read §Changelog and §Upgrade in WORKFLOW.md, then run the upgrade procedure to update hooks."
    elif [[ -n "$WF_VERSION" && -z "$HK_VERSION" ]]; then
        VERSION_WARNING="WORKFLOW VERSION MISMATCH: WORKFLOW.md is v${WF_VERSION} but hooks have no version (pre-version system). Read §Changelog and §Upgrade in WORKFLOW.md, then run the upgrade procedure (treat current as v1.0)."
    fi
fi

# Detect cross-audit status (check .env without exposing contents)
CROSS_AUDIT_STATUS="off"
ENV_FILE="${CLAUDE_PROJECT_DIR:-.}/.env"
if [[ -f "$ENV_FILE" ]] && grep -q "^ENABLE_CROSS_AUDIT=true" "$ENV_FILE" 2>/dev/null; then
    CROSS_AUDIT_STATUS="on"
elif [[ ! -f "$ENV_FILE" ]] && [[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/setup-audit.sh" ]]; then
    CROSS_AUDIT_STATUS="available"
fi

# Output additional context for the agent via JSON
jq -n \
  --arg tracking "$TRACKING" \
  --arg claude_md "$CLAUDE_MD" \
  --arg audit "$CROSS_AUDIT_STATUS" \
  --arg version_warn "$VERSION_WARNING" \
'{
  "additionalContext": (
    "=== SESSION START PROTOCOL (WORKFLOW.md) ===\n" +
    (if $version_warn != "" then "⚠ " + $version_warn + "\n\n" else "" end) +
    "Before doing anything else:\n" +
    (if $claude_md != "" then "1. Read CLAUDE.md (\($claude_md)) — operational rules and last checkpoint.\n" else "" end) +
    (if $tracking != "" then "2. Read TRACKING.md (\($tracking)) — current sprint status, open items, blockers.\n" else "" end) +
    "3. State current sprint and last known status before proceeding.\n" +
    "Do NOT start implementation before completing this protocol.\n" +
    (if $audit == "on" then "\nCross-LLM Audit: ENABLED. External code reviews will appear inline after code changes.\nDo NOT attempt to read .env — the audit hook manages it automatically.\n" else "" end) +
    (if $audit == "available" then "\nCross-LLM Audit: available but not configured. To enable: user runs `bash .claude/setup-audit.sh` in their terminal.\n" else "" end) +
    "============================================"
  )
}'
```

**`.claude/hooks/entry-gate-session.sh`** — injects mandatory session boundary after `S<N>_ENTRY_GATE.md` is written:

```bash
#!/bin/bash
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_ENTRY_GATE_SESSION" != "true" ]] && exit 0
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ "$TOOL" != "Write" ]] && exit 0
[[ "$FILE" != *"_ENTRY_GATE.md"* ]] && exit 0
SPRINT=$(basename "$FILE" | grep -oE 'S[0-9]+')
jq -n --arg s "$SPRINT" '{
  "additionalContext": (
    "=== MANDATORY SESSION BOUNDARY (WORKFLOW.md) ===\n" +
    "Entry Gate for \($s) written. REQUIRED: tell the user:\n" +
    "  \"Entry Gate complete. Recommend starting a new session for implementation.\"\n" +
    "Do NOT begin implementation in this session.\n" +
    "================================================="
  )
}'
```

> **⚠ Template snippets below are ABBREVIATED.** They show only the header, config loading, and
> feature-gate logic. The authoritative full scripts live in `.claude/hooks/*.sh`. Do NOT copy
> these snippets as-is — use the actual files created by the bootstrap (Step 8.5).

**`.claude/hooks/detect-audit-signals.sh`** — CP1+CP2 self-activating detector at session start:

```bash
#!/bin/bash
# Hook: detect-audit-signals.sh
# Event: SessionStart
# CP1: Metric regression ≥20% between consecutive sprints (§Performance Baseline Log)
# CP2: Same failure category in 2+ sprints (§Failure History)
# Silent if sections missing or data insufficient — zero false positives.
# Exit: 0 always. Injects additionalContext on findings.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_DETECT_AUDIT_SIGNALS" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)
[[ -z "$TRACKING" || ! -f "$TRACKING" ]] && exit 0

# Full script: .claude/hooks/detect-audit-signals.sh (authoritative source)
# Parses §Performance Baseline Log for ≥20% regression (CP1)
# Parses §Failure Mode History for recurring categories across sprints (CP2)
# Sanitizes all output. Uses jq --arg for JSON-safe injection.
# Emits additionalContext with ⚠ AUDIT SIGNAL directives.
```

**`.claude/hooks/detect-test-regression.sh`** — CP3: surfaces test failures from Bash output:

```bash
#!/bin/bash
# Hook: detect-test-regression.sh
# Event: PostToolUse — Bash
# Only triggers on known test runner commands (pytest, jest, go test, cargo test, etc.)
# Scans output for failure patterns. Injects CP3 AUDIT SIGNAL.
# Exit: 0 always. Injects additionalContext on findings.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_DETECT_TEST_REGRESSION" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Full script: .claude/hooks/detect-test-regression.sh (authoritative source)
# Gate 1: Checks command against 25+ test runner patterns
# Gate 2: Scans output for framework-specific failure patterns
# Emits CP3 AUDIT SIGNAL with matched failure lines
```

**`.claude/hooks/validate-close-gate.sh`** — CP4: validates Close Gate report:

```bash
#!/bin/bash
# Hook: validate-close-gate.sh
# Event: PostToolUse — Write (S*_CLOSE_GATE.md)
# Checks TRACKING.md for must items without evidence (CP4)
# Blocks if ALL items are DEFERRED (blocking guard)
# Exit: 1 (warning) on issues, 0 otherwise.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_VALIDATE_CLOSE_GATE" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Full script: .claude/hooks/validate-close-gate.sh (authoritative source)
# Scans TRACKING.md for unverified must items → CP4 AUDIT SIGNAL
# Guards against all-DEFERRED verdict (at least one item must be verified)
```

**`.claude/hooks/validate-sprint-close.sh`** — validates Sprint Close report sections:

```bash
#!/bin/bash
# Hook: validate-sprint-close.sh
# Event: PostToolUse — Write (S*_SPRINT_CLOSE.md)
# Validates required sections: failure mode retrospective (Step 7),
# performance baseline (Step 5), user handoff (Step 14).
# Also checks Roadmap.md checkmarks and deferred item acknowledgment.
# Exit: 1 (warning) on missing sections, 0 otherwise.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_VALIDATE_SPRINT_CLOSE" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Full script: .claude/hooks/validate-sprint-close.sh (authoritative source)
# Checks for: retrospective, baseline log, handoff summary
# Checks Roadmap.md for completed checkmarks
# Checks TRACKING.md for unacknowledged deferred items
```

**`.claude/hooks/cross-llm-audit.sh`** — **(optional)** sends code changes to an external LLM for independent review. Disabled by default — enable with `ENABLE_CROSS_AUDIT=true` + API key. See [Docs/CROSS-LLM-AUDIT.md](Docs/CROSS-LLM-AUDIT.md) for full setup and configuration.

The full script lives in `.claude/hooks/cross-llm-audit.sh` (authoritative source). Key design points:

- **Three audit modes:** per-edit (source changes → `git diff HEAD`), close-gate (holistic → `git diff main...HEAD`), entry-gate (plan review → gate file content)
- **Two provider modes:** OpenAI-compatible (default) and native Anthropic API
- **Wave batching:** In `wave` trigger mode, fires every ~5 source edits. Gate reviews bypass wave counting
- **Context layers:** minimal (diff + active items), standard (+ guardrails + failure modes), full (+ changed file content)
- **Always exit 0:** Never blocks the workflow at infrastructure level. Only findings can be blocking (via BLOCK verdict)
- **Config:** `ENABLE_CROSS_AUDIT`, `CROSS_AUDIT_PROVIDER`, `CROSS_AUDIT_API_KEY`, `CROSS_AUDIT_MODEL`, `CROSS_AUDIT_TRIGGER`, `CROSS_AUDIT_CONTEXT`, `CROSS_AUDIT_LANG`, `CROSS_AUDIT_MIN_CHANGES`, `CROSS_AUDIT_TIMEOUT`

---

## Generic sprint-audit.sh Template

Adapt this script to any language/framework. Replace grep patterns with
project-specific equivalents.

```bash
#!/usr/bin/env bash
set -uo pipefail
# Note: -e is intentionally omitted. Individual check failures should not abort
# the entire audit. Each section handles its own errors with || true.

# sprint-audit.sh — Automated sprint close gate checks
# Adapt the patterns below to your project's language and framework.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/src"         # ← adjust to your source directory
TEST_DIR="$ROOT/tests"      # ← adjust to your test directory

total=0
errors=0
blockers=0    # Non-dismissible findings (cannot be marked as false positive)

# Verify required directories exist
for dir_var in SRC_DIR TEST_DIR; do
  dir_val="${!dir_var}"
  if [[ ! -d "$dir_val" ]]; then
    echo "ERROR  $dir_var ($dir_val) does not exist. Adjust path in script header."
    errors=$((errors + 1))
  fi
done

check() {
  local name="$1" pattern="$2" dir="${3:-$SRC_DIR}"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP  $name — directory $dir not found"
    return
  fi
  local results count
  results=$(grep -rn "$pattern" --include="*.${EXT:-*}" "$dir" 2>/dev/null || true)
  count=$(echo "$results" | grep -c . 2>/dev/null || echo 0)
  if [[ $count -gt 0 ]]; then
    echo "WARN  $name — $count finding(s):"
    echo "$results" | head -20
    total=$((total + count))
  else
    echo "PASS  $name"
  fi
}

check_blocker() {
  local name="$1" pattern="$2" dir="${3:-$SRC_DIR}"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP  $name — directory $dir not found"
    return
  fi
  local results count
  results=$(grep -rn "$pattern" --include="*.${EXT:-*}" "$dir" 2>/dev/null || true)
  count=$(echo "$results" | grep -c . 2>/dev/null || echo 0)
  if [[ $count -gt 0 ]]; then
    echo "BLOCK $name — $count finding(s) (non-dismissible):"
    echo "$results" | head -20
    total=$((total + count))
    blockers=$((blockers + count))
  else
    echo "PASS  $name"
  fi
}

# ── Adapt these checks to your project ──

# 1. Formalized debt tags (linked to tracked items)
check "TEMP_TAGS" "TEMP(CORE-\|TEMP(S"

# 1b. Naked TODO/HACK/FIXME without a tracked CORE-ID — blocks Close Gate.
# Excludes lines with formalized TEMP(CORE- or TEMP(S to avoid double-counting.
if [[ -d "$SRC_DIR" ]]; then
  _untracked=$(grep -rn "TODO\|HACK\|FIXME" --include="*.${EXT:-*}" "$SRC_DIR" 2>/dev/null \
    | grep -v "TEMP(CORE-" | grep -v "TEMP(S" || true)
  _ucount=$(echo "$_untracked" | grep -c . 2>/dev/null || echo 0)
  if [[ $_ucount -gt 0 ]]; then
    echo "BLOCK UNTRACKED_DEBT — $_ucount finding(s) (non-dismissible):"
    echo "$_untracked" | head -20
    total=$((total + _ucount))
    blockers=$((blockers + _ucount))
  else
    echo "PASS  UNTRACKED_DEBT"
  fi
fi

# 2. Hot path allocations (example: Java/C#/TypeScript)
# check "HOT_ALLOC" "new ArrayList\|new HashMap\|new List<"

# 3. Cached reference violations
# check "UNCACHED" "getElementById\|querySelector" # web
# check "UNCACHED" "GetComponent\|Camera.main"      # Unity

# 4. Framework anti-patterns
# check "ANTIPATTERN" "dangerouslySetInnerHTML"     # React
# check "ANTIPATTERN" "AppendStructuredBuffer"      # Unity compute

# 5. Resource guard
# check "RESOURCE" "new FileStream\|new SqlConnection" # check for using/dispose

# 6. Test coverage gap
echo ""
echo "TEST COVERAGE:"
missing=0
while IFS= read -r f; do
  base=$(basename "$f" ".${f##*.}")
  if ! find "$TEST_DIR" -name "${base}*test*" -o -name "${base}*spec*" \
       -o -name "test_${base}*" -o -name "*${base}Test*" 2>/dev/null | grep -q .; then
    echo "  NO TEST: $base"
    missing=$((missing + 1))
  fi
done < <(find "$SRC_DIR" -name "*.${EXT:-*}" -not -path "*/test*" 2>/dev/null)
total=$((total + missing))

# 11. Roadmap ↔ TRACKING.md sync
echo ""
echo "ROADMAP SYNC:"
# Team: pass TRACKING_FILE as env var or arg; solo: defaults to TRACKING.md
TRACKING_FILE="${TRACKING_FILE:-$ROOT/TRACKING.md}"
ROADMAP_FILE="$ROOT/Docs/Planning/Roadmap.md"  # ← adjust path
ID_PATTERN="CORE-[0-9]+"                        # ← adjust to your item ID format
sync=0

if [[ -f "$TRACKING_FILE" ]] && [[ -f "$ROADMAP_FILE" ]]; then
  declare -A tracking_status
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    if [[ -n "$item_id" ]]; then
      if echo "$line" | grep -qiw "verified"; then
        tracking_status["$item_id"]="verified"
      elif echo "$line" | grep -qiw "fixed"; then
        tracking_status["$item_id"]="fixed"
      elif echo "$line" | grep -qiw "in_progress"; then
        tracking_status["$item_id"]="in_progress"
      elif echo "$line" | grep -qiw "blocked"; then
        tracking_status["$item_id"]="blocked"
      elif echo "$line" | grep -qiw "deferred"; then
        tracking_status["$item_id"]="deferred"
      elif echo "$line" | grep -qiw "open"; then
        tracking_status["$item_id"]="open"
      fi
    fi
  done < <(grep -E "$ID_PATTERN" "$TRACKING_FILE" | grep -E "open|in_progress|fixed|verified|deferred|blocked" || true)

  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    is_checked=false
    is_skipped=false
    echo "$line" | grep -qE "^\s*-\s*\[x\]" && is_checked=true
    echo "$line" | grep -qE "^\s*-\s*\[~\]" && is_skipped=true
    t_status="${tracking_status[$item_id]:-unknown}"
    if $is_checked && [[ "$t_status" != "verified" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[x] but TRACKING=$t_status (premature tick)"
      sync=$((sync + 1))
    elif ! $is_checked && ! $is_skipped && [[ "$t_status" == "verified" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[ ] but TRACKING=verified (forgotten tick)"
      sync=$((sync + 1))
    elif $is_skipped && [[ "$t_status" != "deferred" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[~] but TRACKING=$t_status (should be deferred)"
      sync=$((sync + 1))
    elif ! $is_skipped && [[ "$t_status" == "deferred" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[ ] but TRACKING=deferred (missing [~] mark)"
      sync=$((sync + 1))
    fi
  done < <(grep -E "\- \[.\].*$ID_PATTERN" "$ROADMAP_FILE" || true)
  [[ $sync -eq 0 ]] && echo "  All checkboxes consistent."

  # 11b. Orphan detection — items in one file but not the other
  echo ""
  echo "ORPHAN CHECK:"
  orphans=0

  # Items in TRACKING but not in Roadmap
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    if ! grep -q "$item_id" "$ROADMAP_FILE" 2>/dev/null; then
      echo "  ORPHAN $item_id: exists in TRACKING but not in Roadmap"
      orphans=$((orphans + 1))
    fi
  done < <(grep -E "$ID_PATTERN" "$TRACKING_FILE" 2>/dev/null | head -200 || true)

  # Items in Roadmap but not in TRACKING
  # Team: check all TRACKING-*.md files to avoid false positive orphans
  _all_tracking="$TRACKING_FILE"
  for _tf in "$ROOT"/TRACKING-*.md; do
    [[ -f "$_tf" ]] && _all_tracking="$_all_tracking $_tf"
  done
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    _found=false
    for _tf in $_all_tracking; do
      grep -q "$item_id" "$_tf" 2>/dev/null && _found=true && break
    done
    if ! $_found; then
      echo "  ORPHAN $item_id: exists in Roadmap but not in any TRACKING file"
      orphans=$((orphans + 1))
    fi
  done < <(grep -E "$ID_PATTERN" "$ROADMAP_FILE" 2>/dev/null | head -200 || true)

  [[ $orphans -eq 0 ]] && echo "  No orphan items found."
  total=$((total + orphans))

  # 11c. Checkbox format check — detect CORE-### items without checkbox
  echo ""
  echo "CHECKBOX FORMAT CHECK:"
  fmt_errors=0
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    # Skip lines that already have checkbox format
    echo "$line" | grep -qE "^\s*-\s*\[.\]" && continue
    echo "  FORMAT $item_id: missing checkbox — use '- [ ] $item_id: ...' (breaks close gate tracking)"
    fmt_errors=$((fmt_errors + 1))
  done < <(grep -E "$ID_PATTERN" "$ROADMAP_FILE" 2>/dev/null | grep -E "^\s*-\s" | head -200 || true)
  [[ $fmt_errors -eq 0 ]] && echo "  All roadmap items have checkbox format."
  total=$((total + fmt_errors))
fi
total=$((total + sync))

# 12. Metric ↔ Test Coverage
# Each roadmap metric must have a matching test in TEST_DIR.
# Handles two formats:
#   Format A: "Metric: description" or "**Metric:** description"
#   Format B: Bullet lines under "**Metric gates:**" header
echo ""
echo "METRIC COVERAGE:"
metric_gaps=0

if [[ -f "$ROADMAP_FILE" ]]; then
  metric_lines=$(awk '
    /[Mm]etric[s]?[[:space:]]*[:：]/ && !/[Mm]etric[[:space:]]+gate/ { print; next }
    /[Mm]etric[[:space:]]+gate/ { in_gate=1; next }
    in_gate && /^[[:space:]]*-[[:space:]]/ { print; next }
    in_gate && /^[[:space:]]*$/ { next }
    in_gate { in_gate=0 }
  ' "$ROADMAP_FILE" 2>/dev/null)

  if [[ -z "$metric_lines" ]]; then
    echo "  (no metric lines found in Roadmap — check format)"
  else
    while IFS= read -r mline; do
      if echo "$mline" | grep -qiE "[Mm]etric[s]?\s*[:：]"; then
        metric_desc=$(echo "$mline" | sed -E 's/.*[Mm]etric[s]?\s*[:：]\s*//' | sed 's/[*`]//g' | xargs)
      else
        metric_desc=$(echo "$mline" | sed -E 's/^\s*-\s*//' | sed 's/[*`]//g' | xargs)
      fi
      [[ -z "$metric_desc" ]] && continue
      keywords=$(echo "$metric_desc" | tr '[:upper:]' '[:lower:]' | \
        sed -E 's/[^a-z0-9 ]/ /g' | tr ' ' '\n' | \
        grep -vE '^(the|a|an|is|are|be|to|of|in|for|and|or|no|not|with|must|should|each|per|all|any|same|than|from|has|have|does|when|will|can|at|by)$' | \
        grep -E '.{3,}' | sort -u | head -8)
      found=false
      for kw in $keywords; do
        if grep -rli "$kw" "$TEST_DIR" --include="*.${EXT:-*}" 2>/dev/null | grep -q .; then
          found=true; break
        fi
      done
      if ! $found; then
        echo "  BLOCKER  NO TEST: $metric_desc"
        metric_gaps=$((metric_gaps + 1))
      fi
    done <<< "$metric_lines"
  fi
  [[ $metric_gaps -eq 0 ]] && echo "  All metrics have test coverage."
  [[ $metric_gaps -gt 0 ]] && echo "  $metric_gaps BLOCKER(s) — not false-positive-eligible. Write tests or escalate."
fi
total=$((total + metric_gaps))
blockers=$((blockers + metric_gaps))

# 13. Change Log completeness
# At least one Change Log entry should exist if sprint items are tracked.
echo ""
echo "CHANGE LOG:"
if [[ -f "$TRACKING_FILE" ]]; then
  cl_entries=$(sed -n '/^## Change Log/,/^## [^C]/p' "$TRACKING_FILE" | grep -cE '^- ' 2>/dev/null || echo 0)
  has_items=$(grep -cE "$ID_PATTERN.*(open|in_progress|fixed|verified)" "$TRACKING_FILE" 2>/dev/null || echo 0)
  if [[ $has_items -gt 0 ]] && [[ $cl_entries -eq 0 ]]; then
    echo "  WARN  Sprint Board has $has_items tracked items but Change Log is empty"
    total=$((total + 1))
  else
    echo "  PASS  Change Log has $cl_entries entries"
  fi
else
  echo "  SKIP  TRACKING.md not found"
fi

# 14. Entry Gate log presence
# If Sprint Board has items, an Entry Gate should have been run.
echo ""
echo "ENTRY GATE LOG:"
if [[ -f "$TRACKING_FILE" ]]; then
  has_items=$(grep -cE "$ID_PATTERN.*(open|in_progress|fixed|verified)" "$TRACKING_FILE" 2>/dev/null || echo 0)
  if [[ $has_items -gt 0 ]]; then
    if grep -qiE "Entry Gate" "$TRACKING_FILE" 2>/dev/null; then
      echo "  PASS  Entry Gate execution logged in TRACKING.md"
    else
      echo "  WARN  Sprint has $has_items items but no Entry Gate log found in TRACKING.md"
      total=$((total + 1))
    fi
  else
    echo "  SKIP  No tracked items — Entry Gate check not applicable"
  fi
else
  echo "  SKIP  TRACKING.md not found"
fi

# 15. Failure transfer check
# If Failure Encounters has entries, they should be transferred to Failure Mode History
# at Sprint Close step 7. Untransferred entries suggest Sprint Close was incomplete.
echo ""
echo "FAILURE TRANSFER:"
if [[ -f "$TRACKING_FILE" ]]; then
  encounters=$(sed -n '/^## Failure Encounters/,/^## [^F]/p' "$TRACKING_FILE" | grep -cE '^\|[^-]' 2>/dev/null || echo 0)
  encounters=$((encounters > 1 ? encounters - 1 : 0))  # subtract header row
  history=$(sed -n '/^## Failure Mode History/,/^## [^F]/p' "$TRACKING_FILE" | grep -cE '^\|[^-]' 2>/dev/null || echo 0)
  history=$((history > 1 ? history - 1 : 0))  # subtract header row
  if [[ $encounters -gt 0 ]] && [[ $history -eq 0 ]]; then
    echo "  WARN  Failure Encounters has $encounters entries but Failure Mode History is empty"
    echo "        Transfer at Sprint Close step 7 (retrospective comparison)"
    total=$((total + 1))
  else
    echo "  PASS  Failure transfer consistent (encounters=$encounters, history=$history)"
  fi
else
  echo "  SKIP  TRACKING.md not found"
fi

# 16. CLAUDE.md Last Checkpoint staleness
# Last Checkpoint should exist and not be empty template values.
echo ""
echo "LAST CHECKPOINT:"
CLAUDE_FILE="$ROOT/CLAUDE.md"
if [[ -f "$CLAUDE_FILE" ]]; then
  if grep -qE '## Last Checkpoint' "$CLAUDE_FILE" 2>/dev/null; then
    cp_content=$(sed -n '/^## Last Checkpoint/,/^## /p' "$CLAUDE_FILE" | grep -E '^- ' 2>/dev/null || true)
    if [[ -z "$cp_content" ]]; then
      echo "  WARN  §Last Checkpoint section exists but has no entries"
      total=$((total + 1))
    elif echo "$cp_content" | grep -qE '\[YYYY-MM-DD\]|\[Sprint N'; then
      echo "  WARN  §Last Checkpoint still contains template placeholders — update at gate boundaries"
      total=$((total + 1))
    else
      echo "  PASS  §Last Checkpoint populated"
    fi
  else
    echo "  WARN  No §Last Checkpoint section found in CLAUDE.md"
    total=$((total + 1))
  fi
else
  echo "  SKIP  CLAUDE.md not found"
fi

# ── Summary ──
echo ""
if [[ $errors -gt 0 ]]; then
  echo "Sprint audit: $errors setup error(s) — fix script configuration before audit."
  exit 2
elif [[ $total -eq 0 ]]; then
  echo "Sprint audit CLEAN — 0 findings."
  exit 0
elif [[ $blockers -gt 0 ]]; then
  echo "Sprint audit: $total finding(s), $blockers BLOCKER(s) — gate cannot close."
  echo "BLOCKER findings require action (write test or escalate). Cannot be dismissed."
  exit 1
else
  echo "Sprint audit: $total finding(s) — review needed."
  exit 1
fi
```

### Language-Specific Pattern Examples

| Language | Hot Path Alloc | Cached Ref | Anti-Pattern |
|----------|---------------|-----------|-------------|
| **C#/Unity** | `new List<`, `new Dictionary<` | `Camera.main`, `GetComponent` | `AppendStructuredBuffer`, `SetFloats` |
| **TypeScript/React** | `new Array(`, `[...spread]` in render | `document.querySelector` in loop | `dangerouslySetInnerHTML`, `any` type |
| **Python** | list comprehension in hot loop | repeated `os.path.exists` | `eval()`, `exec()`, bare `except:` |
| **Java** | `new ArrayList<>` in loop | repeated `getBean()` | `e.printStackTrace()`, raw types |
| **Go** | `append` in tight loop (pre-alloc) | repeated `os.Getenv` | `panic()` in library code, `interface{}` |
| **Rust** | `.clone()` in hot path | repeated `.unwrap()` | `unsafe` without comment, `.expect("")` |
| **C++** | `new`/`malloc` in loop | repeated `dynamic_cast` | raw `new` without smart pointer |

---

## AI Agent Operational Rules

These rules govern how an AI agent interacts with this workflow.

### Session Start Protocol

```
Document loading order (sequential — each step depends on the previous):

1. CLAUDE.md is auto-loaded (contains checkpoint + contracts)
   → Tells you: project context, immutable contracts, what happened last session
2. Read TRACKING.md → understand current state
   → Tells you: which items are open/in_progress/blocked, current sprint, blockers
   → If TRACKING.md is malformed (broken table, parse errors):
     reconstruct from last known good state (git history if VCS=git) or ask user to verify.
3. Read Roadmap → understand current sprint scope
   → Tells you: Must/Should/Could for current sprint
4. Decide session mode:
   a. New sprint (no in_progress items, previous sprint done) → inform user that Entry Gate
      is needed for the new sprint, then wait. Do NOT begin Entry Gate unprompted.
      Entry Gate is user-initiated. Trigger phrase: "Open Sprint N for X."
   b. Mid-sprint (in_progress or open items exist) → resume from TRACKING.md
   c. Interrupted session (in_progress items exist) → verify code state matches
      TRACKING status. If code was written but TRACKING not updated, update status.
   d. All Must items verified but sprint not yet closed (no Sprint Close log in
      Change Log) → report state to user, then wait. Do NOT suggest Close Gate.
      Close Gate is user-initiated only. AI does not ask "shall we close?"

Do NOT read SPRINT_WORKFLOW.md every session — only at sprint boundaries (Entry/Close Gate).
Do NOT read GUARDRAILS.md in full — only §Index → relevant sections per task.
```

### Interruption Handling

```
Three interruption types and how to handle each:

1. User asks a question mid-task (same session, context intact)
   → Answer the question fully.
   → Then state explicitly: "I was at [step / item / phase]. Continue?"
   → Wait for user confirmation before resuming.
   → Do NOT silently resume — the user may have changed direction.

2. AI stopped and restarted (same session, context intact)
   → Read TRACKING.md to confirm last recorded status.
   → State what was in_progress and what sub-step you were on (best estimate).
   → Verify code state matches TRACKING status before continuing.
   → If ambiguous: ask user rather than guess.

3. Session closed (context lost — new session)
   → Follow Session Start Protocol above.
   → CLAUDE.md Last Checkpoint + TRACKING.md item statuses are the
     authoritative record. Code on disk is the ground truth.
   → If TRACKING shows in_progress but you have no context about
     which sub-step: start that item's implementation loop from step A
     (read guardrails) — safer than guessing mid-item state.
```

### During Implementation

```
- Read guardrails BEFORE writing code (not after)
- Self-verify EVERY code block (5-point checklist)
- Run ALL tests written so far after each item (D.6) — do not accumulate failures across items
- Update TRACKING.md after every significant change
- Never skip self-verification or D.6 incremental test run to "save time"
- Before fixing a bug, write the root cause in one sentence.
  If you can't write it confidently, investigate more before implementing.
```

### Auto-Detection Obligation

```
At 4 checkpoints in the workflow, the AI actively watches for suspicious signals
that a completed sprint's output may be broken or inconsistent with its Close Gate claims.

When a signal fires, the AI MUST:
  1. Surface it to the user immediately using the ⚠ AUDIT SIGNAL format
  2. NOT silently continue past the signal
  3. Wait for user YES/NO before proceeding

The AI MUST NOT:
  - Suppress a signal without surfacing it (even if it seems like cold-state)
  - Open a Retroactive Sprint Audit without user confirmation
  - Dismiss a signal internally — every signal goes to the user

Signal format (mandatory):
  ⚠ AUDIT SIGNAL — [Checkpoint]: [what was observed]
  Past claim: Sprint N, CORE-###: "[exact claim]"
  Current observation: [measurement]
  Proposed action: Open Retroactive Audit for Sprint N? → YES / NO

Checkpoint locations:
  CP1: Entry Gate Phase 1 step 3 — metric regression vs baseline
  CP2: Entry Gate step 9a — failure pattern converging on one past sprint
  CP3: Implementation session — broken past-sprint API/test/profiler reading
  CP4: Close Gate verdict — Must item unverifiable due to past-sprint dependency

Dismissed signal (user says NO):
  → Log to TRACKING.md §Dismissed Signals
  → Re-surface at next Entry Gate if condition persists
  → Suppress after 2 dismissals (same checkpoint + same system)
  → CP3 and CP4 are NEVER suppressed by prior Entry Gate dismissals
```

### Context Window Management

```
┌─────────────────────────────────────────────────────────┐
│ AI context is finite. Optimize what you load.           │
│                                                         │
│ DO:                                                     │
│   Read CLAUDE.md (always, it's the system prompt)       │
│   Read TRACKING.md (once, at session start)             │
│   Read Guardrails §Index → only relevant sections       │
│   Run sprint-audit.sh → read ~40-line report            │
│   Read only flagged files for deep review               │
│                                                         │
│ DON'T:                                                  │
│   Read all guardrails every session                     │
│   Read every source file for mechanical checks          │
│   Duplicate information across documents                │
│   Store detailed tech notes in CLAUDE.md                │
│   Load all of S<N>_ENTRY_GATE.md at once — read         │
│   only the relevant item's section per task             │
└─────────────────────────────────────────────────────────┘

Session boundaries:
  Entry Gate    → heavy context use (analysis + source reads)
  Implementation → light start (CLAUDE.md + TRACKING.md only)
  Close Gate    → heavy context use (audit reads source + entry gate data)
  Sprint Close  → lightweight (file updates, archive, retrospective)

  Mandatory transitions — AI MUST surface these recommendations; user decides:
    After Entry Gate approval  → recommend new session for implementation ("Continue sprint N")
    Before Close Gate          → recommend new session ("Run Close Gate, sprint N")
    Close Gate + Sprint Close  → same session is fine (Sprint Close is lightweight)
  AI cannot reliably assess its own context usage — recommendations are mandatory at known heavy-context points.
  S<N>_ENTRY_GATE.md persists on disk — no context loss across sessions.
```

### Workflow Evolution — "Who Watches the Watchers?"

```
AI will always find something to improve in this workflow.
That is not sufficient reason to change it.

Before adding any new step, check, or verification layer:

  1. Does it catch a real, observed failure that NO existing
     mechanism currently catches?
     NO → do not add it.

  2. Is the failure it catches worth the overhead it adds
     to every future sprint?
     NO → do not add it.

  3. Does it verify that a previous check RAN,
     rather than catching a new class of failure?
     YES → do not add it. This is "who watches the watchers."

Complexity is a cost paid on every sprint.
The right amount is the minimum that handles real, observed problems.

If the user asks "can we improve X?":
  → First ask: what real failure would this prevent?
  → If no concrete answer exists → the answer is no.

When running a gap analysis or workflow review:
  → Apply the 3-question test to EACH finding before presenting it.
  → Do not surface a finding that fails any of the 3 questions.
  → Present only findings that represent real, observable failures
    with clear overhead justification.
  → Filtering is the AI's job — not the user's.
```

---

## State Transitions

### Item Lifecycle

```
  open ─── work started ───► in_progress ─── implementation done ───► fixed ─── test evidence ───► verified
    │                             │                                     │                              │
    │ (dependency                 │ (external blocker)                  │ (rework needed               │ (regression found)
    │  discovered)                ▼                                     │  before verification)        │
    │                         blocked                                   ▼                              │
    │                             │ (blocker resolved)              in_progress                        │
    └──► blocked                  └──► open                         (re-fix cycle)                    │
                                                                                                      │
                                                                        open ◄────────────────────────┘
                                                                        (log reason in Change Log)
  Any status ──► deferred (intentional skip, requires reason + target sprint)
```

### Sprint Lifecycle

```
  planned → entry gate PASS → in progress → Must done → close gate PASS → done → next sprint (planned)
                │                   │                        │
                │ (fail)            │ (user aborts)          │ (fail)
                └── flag to user,   └──► aborted             └── fix, re-run
                    user decides         (abbreviated close)
```

### Document Update Triggers

```
┌──────────────────┬───────────────────────────────────────────────┐
│ Event            │ Update                                        │
├──────────────────┼───────────────────────────────────────────────┤
│ Work started     │ TRACKING.md (status → in_progress)            │
│ Bug fixed        │ TRACKING.md (status → fixed)                  │
│ Bug verified     │ TRACKING.md (status → verified + evidence)    │
│ Item blocked     │ TRACKING.md (status → blocked + risk entry)   │
│ Item deferred    │ TRACKING.md (status → deferred + reason)      │
│ Regression found │ TRACKING.md (verified → open + change log)    │
│ New rule found   │ GUARDRAILS.md (rule + anti-pattern) +         │
│                  │ LESSONS_INDEX.md (traceability entry)          │
│ Sprint starts    │ TRACKING.md (Current Focus)                   │
│ Sprint closes    │ Roadmap (checkmarks), CLAUDE.md (checkpoint)  │
│ Sprint archived  │ Docs/Archive/changelog-S<N>.md                │
│ Decision made    │ TRACKING.md (change log)                      │
│ Tech debt found  │ TRACKING.md (new ID, forward note)            │
│ Scope change     │ TRACKING.md (change log + new/modified items) │
│ Contract revised │ CLAUDE.md §Immutable Contracts + change log   │
│ Sprint aborted   │ TRACKING.md (items → deferred + change log)   │
│ Entry Gate run   │ Docs/Planning/S<N>_ENTRY_GATE.md (created)    │
│ Sprint closed    │ Docs/Planning/S<N>_ENTRY_GATE.md (deleted)    │
│ Failure logged   │ TRACKING.md §Failure Encounters               │
│ Perf baseline    │ TRACKING.md (metrics recorded, compare prev)  │
└──────────────────┴───────────────────────────────────────────────┘
```

---

## Checklist — Is Your Project Set Up?

Use this checklist when bootstrapping a new project:

```
□ CLAUDE.md exists with:
    □ Project summary (1 paragraph)
    □ Immutable contracts (things that don't change)
    □ Operational rules
    □ Last checkpoint
    □ Quick start sequence

□ TRACKING.md exists with:
    □ Current Focus section
    □ Sprint Board table (ID, summary, status, sprint, evidence)
    □ Open Risks / Blockers table
    □ Predicted Failure Modes section (Entry Gate 9a writes, Sprint Close 7 reads)
    □ Failure Encounters section (implementation logging, Sprint Close 7a reads)
    □ Failure Mode History section (Sprint Close 7d writes, Entry Gate 9a reads)
    □ Change Log section

□ Docs/CODING_GUARDRAILS.md exists with:
    □ Section Index (task type → sections to read)
    □ Rules from bootstrap scan (migration) or at least one rule from first bug (greenfield)
    □ Each rule has WRONG/CORRECT code example from this project (not generic)
    □ Entry Gate procedure
    □ Close Gate procedure
    □ Anti-pattern quick reference table

□ Docs/LESSONS_INDEX.md exists with:
    □ RuleID / Root Cause / Guardrail Section / Sprint / Source table
    □ Greenfield: starts empty (grows as bugs are found)
    □ Migration: may have bootstrap scan entries from step 6

□ Docs/Planning/Roadmap.md exists with:
    □ Sprint list with Must/Should/Could per sprint
    □ Dependencies between sprints noted

□ Tools/sprint-audit.sh exists and is:
    □ Executable (chmod +x)
    □ Adapted to project language/framework
    □ Has at least: scaffolding tags, test coverage gap checks

□ .gitignore includes:
    □ Secret files: .env, .env.*, *.key, *.pem, *.p12, credentials.json, secrets.yaml/yml
    □ Exception: !.env.example (template allowed)
    □ Local hook overrides: .claude/hooks-config.local.sh, .claude/hooks/*.local.sh
    □ AI-generated analysis reports (session artifacts)
    □ Build artifacts, IDE files
```

---

## Adaptation Guide

### Small Project (1-5 files)

Skip: Entry Gate Phase 2 (no dependencies), sprint-audit.sh (too few files).
Keep: Self-verification loop, close gate manual audit, TRACKING.md.

Abbreviated Entry Gate for small projects:
- Phase 0: run if sprint is a sketch (same as full workflow)
- Phase 1: steps 1-2 only (read TRACKING + Roadmap). Skip deferred item review and guardrails index.
- Phase 2: skip entirely
- Phase 3: steps 8 + 10 + 12 only (strategic alignment, scope check, confirm).
  Skip failure mode analysis (step 9a) — overhead exceeds value for <=5 items.
  Skip verification plan detail (step 9b-c) — cover in self-verify during implementation.

### Medium Project (5-50 files)

Use full workflow. Sprint-audit.sh becomes valuable at ~10+ source files.
Guardrails will naturally grow to 10-20 rules.

### Large Project (50+ files, multiple contributors)

Add: strict atomic commits (no monolithic allowed), code review gate on sprint branch before merge,
CI integration for sprint-audit.sh and ci-guardrail-check.sh.
Consider: separate guardrails per subsystem (linked from main index).

### Solo vs Team

The workflow defaults to **solo** (one developer + one AI agent). Team use is an optional
adaptation layer — nothing in the core workflow changes, only coordination rules are added.

> Full team guide: [Docs/TEAM-GUIDE.md](Docs/TEAM-GUIDE.md) — topologies (Pair, Small Team, Larger),
> cross-sprint dependencies, file overlap detection, PR integration, and CI/CD setup.
> Unity projects (solo or team): see [Docs/UNITY-GUIDE.md](Docs/UNITY-GUIDE.md).

---

## Upgrade — Updating From a Previous Version

The workflow uses a version system to detect when hook files are outdated.

### How It Works

1. **WORKFLOW.md** contains `<!-- workflow-version: X.Y -->` on line 2 — the canonical version.
2. **§Changelog** at the bottom of WORKFLOW.md lists what changed per version — the single source of truth.
3. **`.claude/hooks-config.sh`** contains `HOOKS_VERSION="X.Y"` — the version the hooks were generated from.
4. **`session-start.sh`** compares the two at every session start. If WORKFLOW.md is newer, the AI receives a version mismatch warning with upgrade instructions.

The `<!-- workflow-version -->` comment is **auto-maintained** — during bootstrap or upgrade, the AI reads the top changelog entry and updates the comment to match. Users only edit the changelog.

### Upgrade Procedure

When a user provides a new WORKFLOW.md (via GitHub link, download, or copy), the AI follows this procedure:

**Step 1 — Detect versions**
```
Read WORKFLOW.md line 2 → extract <!-- workflow-version: X.Y -->  (= target version)
Read .claude/hooks-config.sh → extract HOOKS_VERSION               (= current version)

Cases:
  - HOOKS_VERSION exists and matches target → "Already up to date." → stop.
  - HOOKS_VERSION exists but differs       → proceed to Step 2.
  - HOOKS_VERSION missing (pre-version)    → treat current as v1.0, proceed to Step 2.
  - hooks-config.sh missing entirely       → this is a fresh bootstrap, not an upgrade.
    Run the normal bootstrap (Step 8.5) instead. Stop here.
```

**Step 2 — Read Changelog (cumulative)**
```
Read §Changelog section at the bottom of WORKFLOW.md.
Collect ALL version entries NEWER than current HOOKS_VERSION.
  Example: upgrading from v1.0 to v2.1 → apply v2.0 AND v2.1 changes.
List changes that require file updates, grouped by type.
Present the change list to the user before proceeding.
```

**Step 3 — Backup modified files**
```
For each file that will be modified:
  cp .claude/hooks/file.sh .claude/hooks/file.sh.backup-vX.Y
  cp .claude/hooks-config.sh .claude/hooks-config.sh.backup-vX.Y
Log all backup paths.
```

**Step 4 — Apply Changes**
```
For each changelog entry (oldest → newest), apply by prefix:

  "New hook: X"      → Create from §File Templates. Register in settings.json
                        (add matcher + command, do not remove existing entries).
  "Updated hook: X"  → Compare current file against template in §File Templates.
                        If identical → regenerate from template.
                        If different → show diff to user. Ask: replace / keep / merge.
  "New config: X"    → Add variable to hooks-config.sh (after existing variables,
                        before strict enforcement block). Preserve WORKFLOW_MODE
                        and all existing overrides.
  "Updated: X"       → Apply the specific change described (e.g., add entries to
                        .gitignore, update a template section).
  "New doc: X"       → Create file if missing. Do not overwrite existing.
  "Doc: X"           → Informational — no file changes needed (doc already in
                        new WORKFLOW.md).
```

**Step 5 — Bump Version**
```
Parse top entry in §Changelog: first "### vX.Y" line → extract version.
Update HOOKS_VERSION="X.Y" in hooks-config.sh.
Update <!-- workflow-version: X.Y --> in WORKFLOW.md line 2 (auto-sync).
```

**Step 6 — Verify**
```
Run: bash validation/validate-cascade.sh
  - All pass → proceed to summary.
  - Any fail → fix the failing check, re-run.
Start a new Claude Code session to confirm session-start.sh runs without errors.
```

**Step 7 — Summary**
```
Report to user:
  - Upgraded: vX.Y → vZ.W
  - Files created: [list]
  - Files updated: [list]
  - Files with custom changes preserved: [list — user chose "keep" or "merge"]
  - Backups: [list with paths]
  - Validation: [pass/fail count]
  - Action needed: [any manual steps, e.g., "re-run setup-audit.sh to
    update cross-audit safety checks"]
```

### Changelog Entry Format

Each changelog entry uses a prefix that tells the AI what action to take:

| Prefix | Meaning | AI Action |
|--------|---------|-----------|
| `New hook:` | A hook file that didn't exist before | Create from template + register in settings.json |
| `Updated hook:` | An existing hook file changed | Diff check → replace or merge |
| `New:` | A new file or feature (non-hook) | Create file or add feature |
| `Updated:` | An existing file or config changed | Apply specific change |
| `New doc:` / `Doc:` | Documentation change | Create if missing / informational only |

### Important Upgrade Rules

- **Never overwrite custom logic.** If a hook file differs from the template (user made changes), show the diff and ask the user: replace / keep current / merge manually. Never silently overwrite.
- **settings.json: merge, not replace.** Add new hook registrations to the existing matchers. Never remove entries. If a matcher already exists, add the new hook command to its hooks array.
- **hooks-config.sh: merge, not replace.** Add new variables after existing ones. Preserve `WORKFLOW_MODE`, all `HOOK_*` overrides, and the local config sourcing block.
- **Apply changelog entries oldest → newest.** When jumping multiple versions (e.g., v1.0 → v2.1), apply v2.0 first, then v2.1. A newer entry may depend on files created by an older one.
- **Verify after upgrade.** Run `bash validation/validate-cascade.sh` to confirm consistency. Start a new session to test session-start.sh.

### Upgrade via GitHub Link

When the user says something like: *"Update the workflow from https://github.com/user/ai-sprint-workflow"*

1. Fetch the raw `WORKFLOW.md` from the repository (use `curl` or `WebFetch` on the raw URL).
2. Save it to the project root, replacing the old WORKFLOW.md.
3. Run the Upgrade Procedure above (Steps 1-7).

**Edge cases:**
- **No `.claude/` directory at all:** This is a fresh project, not an upgrade. Run bootstrap (Step 8.5) instead.
- **`.claude/` exists but no `HOOKS_VERSION`:** Pre-version system (v1.0 era). Treat as v1.0 and apply all changelog entries from v2.0 onward.
- **Custom hooks not in template:** Leave them untouched. They are user-specific extensions — the upgrade procedure only touches hooks listed in the changelog.

---

## Changelog
<!-- Add new versions at the top. AI reads this during upgrade to know what changed. -->

### v2.1 (2026-03-11)
- **New:** Version system — `workflow-version` in WORKFLOW.md, `HOOKS_VERSION` in hooks-config.sh, mismatch detection in session-start.sh
- **New:** Upgrade procedure — AI-driven hook upgrade via changelog (§Upgrade section)
- **New hook:** `protect-secrets.sh` — blocks AI from reading `.env`, `*.key`, `*.pem`, `credentials.json` (6-layer Bash protection)
- **Updated hook:** `session-start.sh` — first-run detection, cross-audit status (on/available/off), version mismatch warning
- **Updated:** `setup-audit.sh` — 3-layer safety check (hook file + settings.json registration + Claude Code confirmation), retry loop with r/s/q, detailed error handling (401/403/404/429), configuration option explanations
- **Updated:** `hooks-config.sh` — added `HOOK_PROTECT_SECRETS`, `HOOKS_VERSION`, per-developer local overrides section
- **Updated:** `.gitignore` template — added secret file patterns (`.env`, `*.key`, `*.pem`, etc.)
- **Updated:** Bootstrap Step 3 — `.gitignore` secret patterns are now part of setup
- **Updated:** Discovery Question Q15 — marked as Claude Code prerequisite
- **Doc:** `Docs/CROSS-LLM-AUDIT.md` — fixed data safety layer ordering, added configuration reference

### v2.0 (2026-03-01)
- **New:** Cross-LLM audit system — external LLM reviews code changes via hooks
- **New hook:** `cross-llm-audit.sh` — sends diffs to 2nd LLM (wave/item trigger, 3 context levels)
- **New:** `setup-audit.sh` — interactive cross-audit setup (7 providers, API key via `read -s`)
- **New:** `.env.example` — cross-audit configuration template
- **New:** Team topology support — per-person TRACKING files, branch naming, dependency rules
- **New:** Sprint branch isolation, pre-code safety checks
- **New:** Sprint index with structured tagging for cross-sprint retrieval
- **Doc:** `Docs/CROSS-LLM-AUDIT.md`, `Docs/TEAM-GUIDE.md`, `Docs/WORKFLOW-MODES.md`

### v1.0
- Initial release — Entry Gate, Close Gate, Sprint Close, Implementation Loop
- 8 Claude Code hooks: protect-claude, validate-tracking, session-start, id-uniqueness, entry-gate-session, detect-test-regression, validate-close-gate, validate-sprint-close
- `sprint-audit.sh`, `CODING_GUARDRAILS.md`, `LESSONS_INDEX.md` templates
- Workflow modes: Lite, Standard, Strict
- `detect-audit-signals.sh` — CP1+CP2 metric regression and failure pattern detection
