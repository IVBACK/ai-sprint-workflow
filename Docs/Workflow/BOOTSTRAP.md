<instructions>

# CRITICAL: Never overwrite CLAUDE.md. Never overwrite source code. Never modify CI without user confirmation.

# Bootstrap — Project Setup

## 0. Install (when user gives repo link)

User says something like: "Set up sprint workflow from github.com/IVBACK/ai-sprint-workflow"

```
IF git available:
  1. git clone --depth 1 <url> /tmp/sprint-workflow-src
  2. Copy to project:
     - WORKFLOW.md
     - Docs/Workflow/ (all workflow instruction files)
     - Docs/Systems/ (HOOKS.md, MEMORY.md, TOOLS.md)
     - Tools/sprint-tools (dispatcher)
     - Tools/sprint-*.py (12 subcommands)
     - Tools/sprint_lib/ (shared library, 8 files)
     - Tools/sprint-audit.sh
     - checks/ → Tools/checks/ (modular audit adapters)
     - .claude/ (hooks, settings.json, setup-audit.sh) — Claude Code only
     - dashboard/ (sprint-status CLI + web dashboard)
     - .env.example, ARCHITECTURE.md
     - Docs/Workflow/Skeletons/ → project root:
       · Skeletons/CLAUDE.md → CLAUDE.md (if not exists)
       · Skeletons/TRACKING.md → TRACKING.md (if not exists)
       · Skeletons/Roadmap.md → Docs/Planning/Roadmap.md (if not exists)
       · Skeletons/SPRINT-INDEX.md → Docs/SPRINT-INDEX.md (if not exists)
       · Skeletons/gitignore → .gitignore (merge if exists)
  3. Do NOT copy: README.md, DESIGN.md, CONTRIBUTING.md, LICENSE,
     validation/, examples/, playbooks/, .github/,
     sprint-audit-template.sh, .editorconfig, .gitattributes
  4. chmod +x hooks and tools
  5. rm -rf /tmp/sprint-workflow-src

ELIF no git (VCS=none):
  1. Ask user to download zip from GitHub → extract
  2. Copy same files as above
  3. chmod +x hooks and tools

UPGRADE (Docs/Workflow/ already exists):
  → overwrite workflow instruction files (template, not user data)
  → do NOT overwrite: Roadmap.md, CODING_GUARDRAILS.md
  → CLAUDE.md, TRACKING.md: if skeleton-based (has [REQUIRED] or <!-- FILL --> markers), skip;
    if user-filled, preserve — only append missing sections via sprint-tools migrate
```

IF user already has workflow files (ran CLI or manual copy) → skip to 0b.

### VCS=none: What works, what doesn't

```
WORKS WITHOUT GIT:
  ✓ Discovery conversation + blind review
  ✓ TRACKING.md, CLAUDE.md, Roadmap.md, CODING_GUARDRAILS.md
  ✓ Entry Gate, Close Gate, Sprint Close
  ✓ sprint-tools: state, item, checkpoint, baseline, metrics, close, index
  ✓ sprint-tools review (use --stdin with file content or pass file path)

REQUIRES GIT (graceful skip):
  ✗ Sprint branch isolation (sprint-N-impl)
  ✗ Per-item commits + merge ceremony
  ✗ git diff based review (use file path instead)
  ✗ sprint-tools git (entirely git-dependent, skip)
  ✗ Cross-LLM audit hook (diff source is git, skip)

OPTIONAL (git-only features):
  ✗ Parallel execution (worktree-based agents)
  ✗ Team branch naming + PR integration
  ✗ Tag-based sprint boundaries

Record VCS status in CLAUDE.md §Project Summary: "VCS: git" or "VCS: none"
AI adapts behavior based on this field.
```

## 0b. Detect Project State

```
IF no source code AND no workflow files → Greenfield
ELIF source code OR workflow files exist → Migration → read §Migration Rules first
```

## Migration Rules

| File | If exists |
|------|-----------|
| `CLAUDE.md` | **Never overwrite.** Read first. Append missing sections only. |
| `TRACKING.md` | Skip. Ask user. IF solo→team migration: ask how to split. |
| `Docs/SPRINT-INDEX.md` | Skip if exists. Skeleton deployed only when missing. |
| `.gitignore` | Merge: append missing patterns, do not remove existing. |
| `Roadmap.md` | Skip. Ask user. |
| `CODING_GUARDRAILS.md` | Skip. Ask user. |
| `Tools/sprint-audit.sh` | Skip. Ask user. |
| `Docs/Workflow/` | Overwrite instruction files (template, not user data). |

Existing CI/CD: call existing commands, don't duplicate. Don't modify CI without confirmation.

---

## 1. Scan Project

```
IF empty project → skip to step 2
IF large project (100+ files) → scan configs + top-level dirs + 50 files max
```

Determine: language, framework, build system, test framework, VCS.

---

## 2. Discovery Conversation

**Do NOT ask 16 questions in a batch.** Have a conversation.

**No rush.** Discovery is the most important phase — a bad plan from a rushed conversation costs more than a few extra questions. Chat naturally, let the user talk, pick up on details. Move to Phase 2 only when you have a clear picture.

### Phase 1 — Quick Intake

Ask conversationally, adapt to answers. Start with ONE question, continue based on the response.

```
IF greenfield:
  → start with: "Tell me what you want to build."
  → follow up naturally based on the answer (who is it for, solo/team, etc.)
  → do NOT dump 3 questions at once

IF existing project:
  → start with: "What are you working on now?"
  → follow up about goals, pain points, team
```

Key questions to cover (across the conversation, not all at once):
- What the project does / will do
- Who it's for
- Solo or team
- What to tackle first

```
IF user's first message already answers some/all of these:
  → do NOT re-ask. Confirm what you understood: "So [X], [Y], [Z] — correct?"
  → ask only about what's still unclear
IF answer reveals critical domain (payments, medical, legal, auth):
  → note Critical Axis (will confirm later)
IF answer is vague ("e-commerce" with no specifics):
  → ask one follow-up: "What specifically? Product listings? Payments? Both?"
  → do NOT accept vague answers without at least one clarifying question
IF project scan already answered a question:
  → state what you found, confirm: "I see React + Express. Correct?"
```

### Phase 2 — Plan Draft (AI writes, user doesn't see yet)

From scan + answers, draft internally:
- What to build first (highest risk / highest value)
- What to build after
- Key assumptions
- Critical Axis — every project has one. Pick the most important:
  - **correctness**: payments, calculations, medical, legal
  - **security**: auth, user data, API keys, multi-tenant
  - **performance**: games, real-time, high traffic, video/audio
  - **reliability**: infrastructure, CI/CD, messaging, scheduling

```
IF greenfield:
  → plan is based purely on user's answers
IF existing project:
  → plan incorporates scan findings (existing patterns, tech debt, test coverage)
```

### Phase 3 — Research

```
Default: research. Ask the user:
  → "I'd like to research [specific topics] to make sure the plan is solid. Should I?"
  → list the specific things you'd research (e.g. "Fishnet vs Unity Netcode for 5v5", "Stripe checkout flow 2026")
  → IF yes: use WebSearch/WebFetch. Gather ALL needed topics in one batch.
  → IF no: note as risk in plan, proceed
  → incorporate findings into plan draft

ONLY skip if project is obviously trivial (single-file script, pure CLI with no deps).
```

### Phase 4 — Blind Review

```
IF sprint-tools review available (API key configured):
  → write plan draft to a temp file
  → run: sprint-tools review plan.md -q "What's missing? What are the risks?"
  → incorporate findings into plan

IF not available:
  → skip blind review, proceed to Phase 5

IF critical gap found (security, data loss, legal risk):
  → mention naturally when presenting plan in Phase 5
ELSE:
  → incorporate silently, user doesn't see this step
```

### Phase 5 — Present Plan (conversational, non-technical)

Present plan in plain language. No workflow jargon (sprint/gate/must/should).
Technical terms for the user's domain are fine (webhook, API, database) — avoid workflow-specific terms only:

```
"Here's what I'll do:

 First: [most important/risky thing, plain language]
   - [key detail]
   - [key detail]

 Then: [next thing]
   - [key detail]

 My assumptions:
   - [assumption 1]
   - [assumption 2]

 Settings I picked based on our conversation:
   - [mode] — [one-line reason]
   - [critical axis or "none"]

 Any of this wrong? Questions? Want to change anything?"
```

Infer settings from conversation (do NOT ask separately):
- **Workflow mode**: solo + small project → Lite. Team or complex → Standard. Critical system → Strict.
- **Critical Axis**: from domain. Every project has one (see Phase 2 list).
- **Commit style**: from existing git history (if conventional commits detected → conventional, else free-form).
- **Sprint scope**: from plan complexity.
- **Cross-LLM audit**: enabled if API key configured.
- **Language**: from conversation language.

```
WHILE user has questions or changes:
  → answer / adjust plan (including settings)
  → continue: "Anything else?"

WHEN user says "looks good" / "start" / equivalent:
  → proceed to file creation
```

---

## 3. Verify Skeleton Files

Skeleton files (`CLAUDE.md`, `TRACKING.md`, `Docs/SPRINT-INDEX.md`, `.gitignore`) are
pre-shipped from `Docs/Workflow/Skeletons/` during install (Step 0). They contain the
complete structure with `[REQUIRED: ...]` placeholders for project-specific content (CLAUDE.md)
and `<!-- FILL: ... -->` placeholders for sprint-time content (TRACKING.md, Roadmap.md).

```
IF skeleton files exist (normal install):
  → verify they are present, do NOT recreate
  → proceed to step 4 (skeletons will be filled in step 5)

IF skeleton files are missing (manual install, upgrade, or VCS=none):
  → copy from Docs/Workflow/Skeletons/:
    · Skeletons/CLAUDE.md → CLAUDE.md
    · Skeletons/TRACKING.md → TRACKING.md
    · Skeletons/Roadmap.md → Docs/Planning/Roadmap.md
    · Skeletons/SPRINT-INDEX.md → Docs/SPRINT-INDEX.md
    · Skeletons/gitignore → .gitignore (merge with existing)

IF team → create per-person TRACKING-[name].md from Skeletons/TRACKING.md (see TEAM-GUIDE.md)
```

Also create if missing:
- `Docs/Archive/` — empty directory
- `Docs/Planning/` — empty directory (for Roadmap.md)

Ensure `.gitignore` includes stack-specific patterns (append to existing skeleton).
The skeleton already has secret patterns (.env, *.key, etc.).

## 4. Initial Planning → Roadmap

```
IF Roadmap.md already has items → skip
IF existing project → current work = Sprint 1
```

Populate from discovery conversation:
- First thing user wants → Sprint 1 Must items
- "Then" items → Sprint 2 sketch or Sprint 1 Should/Could
- Assign CORE-### IDs (continue from highest existing, never reuse)
- Identify immutable contracts → CLAUDE.md

## 5. Fill CLAUDE.md Placeholders

CLAUDE.md skeleton is pre-shipped with all static sections (Document Contract, Operational Rules,
Available Tools, Quick Start) already complete. Do NOT rewrite these sections.

Fill only the `[REQUIRED: ...]` placeholders from scan + conversation:
- `[Project Name]` in title
- §Project Summary: language, framework, VCS, Critical Axis, Team
- §Immutable Contracts: data formats, API contracts, conventions
- §Operational Rules: language and commit style placeholders only
- §Last Checkpoint: initial values

```
IMPORTANT: Do NOT rewrite or regenerate static sections.
  The skeleton contains the authoritative Available Tools list, Document Contract,
  Operational Rules structure, and Quick Start. These are workflow-invariant.
  Only replace [REQUIRED: ...] markers with project-specific values.
  All [REQUIRED] fields MUST be filled — do not leave them as placeholders.
```

## 6. Populate CODING_GUARDRAILS.md

Three-layer scan:
```
a. Stack-specific: known footguns for detected framework
b. Domain-specific: risks for project's business domain
c. Codebase-specific: actual anti-patterns in existing code
```

```
Present: "Found N risk patterns. Review?"
User may remove rules or skip scan entirely.
IF user skips → create minimal template-only CODING_GUARDRAILS.md (section headers, no rules).
IF empty project → stack rules only, domain emerges in Sprint 1.
```

## 7. Adapt sprint-audit.sh

Set `SRC_DIR`, `TEST_DIR`, `EXT` for detected language.

## 8. Verify Docs

Confirm `Docs/Workflow/` exists with all files.

## 8.5. Claude Code Hooks (skip for other agents)

```
IF .claude/hooks/ exists (step 0 copied them) → validate, chmod +x, skip to 9
ELSE (hooks missing after install) → re-copy from template repo .claude/ directory.
  Hook scripts are complex and must be copied from the template repo, not generated.
```

## 9. Offer Cross-LLM Review Setup

```
IF .env has no API key configured (or .env doesn't exist):
  → mention naturally: "One more thing — I can have a different AI silently
     review my work for bugs and blind spots. It needs an API key
     (OpenAI, Anthropic, or free local Ollama). Want to set it up now,
     or skip for later?"
  → IF yes: tell user to run in a SEPARATE terminal (not here — script needs hidden input):
       bash .claude/setup-audit.sh
     Wait for user to confirm it's done, then continue.
  → IF no/later: fine, move on. Mention `bash .claude/setup-audit.sh` for later.

IF .env already has a key → skip, already configured.
```

## 10. Confirm and Start

```
Before starting, read Docs/Workflow/AGENT-RULES.md (prereq for Entry Gate).

"Everything's set up. Ready to start on [first thing]?"

IF user confirms → begin Entry Gate (user doesn't need to know it's called that)
IF user has concerns → address, then confirm
```

---

## File Structure

```
project-root/
├── .gitignore
├── CLAUDE.md
├── TRACKING.md
├── Docs/
│   ├── CODING_GUARDRAILS.md
│   ├── Workflow/ (all workflow instruction files)
│   │   └── Skeletons/ (CLAUDE.md, TRACKING.md, Roadmap.md, SPRINT-INDEX.md, gitignore)
│   ├── SPRINT-INDEX.md
│   ├── Planning/
│   │   ├── Roadmap.md
│   │   └── S<N>_ENTRY_GATE.md (temporary)
│   └── Archive/
├── Tools/
│   ├── sprint-audit.sh
│   ├── sprint-tools (dispatcher)
│   ├── sprint-review.py (blind review)
│   ├── sprint_lib/ (parsers, models, writers)
│   └── checks/ (modular audit adapters per language)
└── .claude/ (Claude Code only)
    ├── hooks-config.sh, settings.json, setup-audit.sh
    └── hooks/ (12 hooks + utilities)
```

## Checklist (AI self-check before step 10)

```
[ ] CLAUDE.md skeleton present, all [REQUIRED] placeholders replaced
[ ] CLAUDE.md §Available Tools section intact (not rewritten or truncated)
[ ] TRACKING.md skeleton present, Current Focus and Sprint Board filled
[ ] Docs/SPRINT-INDEX.md skeleton present
[ ] .gitignore present with secret patterns + stack-specific additions
[ ] CODING_GUARDRAILS.md with stack/domain rules
[ ] Roadmap.md with Sprint 1 items
[ ] Tools/sprint-tools + 12 .py subcommands present
[ ] Tools/sprint_lib/ complete (8 modules)
[ ] Tools/sprint-audit.sh adapted to language
[ ] Tools/checks/ present (modular audit adapters)
[ ] dashboard/ present (sprint-status)
[ ] Blind review completed (before presenting plan)
[ ] User confirmed plan before file creation
[ ] No template-repo files leaked (README, DESIGN, validation/, examples/)
```

# CRITICAL: Never overwrite CLAUDE.md. Discovery is a conversation, not a form. Present plans in plain language. Run blind review before presenting plan to user.

</instructions>
