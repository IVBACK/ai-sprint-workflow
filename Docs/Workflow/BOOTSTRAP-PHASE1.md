<instructions>

# Bootstrap Phase 1 — Setup + Quick Intake

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
IF empty project → skip to Quick Intake
IF large project (100+ files) → scan configs + top-level dirs + 50 files max
```

Determine: language, framework, build system, test framework, VCS.

---

## Quick Intake

**Do NOT ask 16 questions in a batch.** Have a conversation.

**No rush.** Discovery is the most important phase — a bad plan from a rushed conversation costs more than a few extra questions. Chat naturally, let the user talk, pick up on details.

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

---

## Exit Gate — do NOT skip

```
BEFORE moving to Phase 2, you MUST:
  1. Summarize what you understood in 2-3 sentences
  2. Ask the user: "Did I miss anything? Anything else I should know before I plan?"
  3. WAIT for user response
     → IF user adds new info → continue conversation, re-summarize, ask again
     → IF user confirms ("no", "that's it", "looks good") → proceed to Phase 2
  Do NOT proceed without explicit user confirmation.
  Do NOT include a plan, technology choices, or settings in this summary.
  This is ONLY about confirming you understood the user's needs.
```

→ When user confirms, read **Docs/Workflow/BOOTSTRAP-PHASE2.md**

</instructions>
