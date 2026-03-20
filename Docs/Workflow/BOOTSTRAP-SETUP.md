<instructions>

# Bootstrap Setup — File Creation (Steps 3-10)

PREREQUISITE: User approved the plan in Phase 5.

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
IF already configured (set up during Phase 4 or pre-existing) → skip
IF not configured and not offered in Phase 4:
  → mention naturally: "One more thing — I can have a different AI silently
     review my work for bugs and blind spots. It needs an API key
     (OpenAI, Anthropic, or free local Ollama). Want to set it up now,
     or skip for later?"
  → IF yes: tell user to run in a SEPARATE terminal (not here — script needs hidden input):
       bash .claude/setup-audit.sh
     Wait for user to confirm it's done, then continue.
  → IF no/later: fine, move on. Mention `bash .claude/setup-audit.sh` for later.
```

## 10. Confirm and Start

```
Before starting, read Docs/Workflow/AGENT-RULES.md (prereq for Entry Gate).

"Everything's set up. Ready to start on [first thing]?"

IF user confirms → begin Entry Gate (user doesn't need to know it's called that)
IF user has concerns → address, then confirm
```

After bootstrap completes, clean up: `rm -rf .bootstrap/`

---

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
[ ] User confirmed plan before file creation
[ ] No template-repo files leaked (README, DESIGN, validation/, examples/)
```

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
    └── hooks/ (14 hooks + utilities)
```

# CRITICAL: Never overwrite CLAUDE.md. Never overwrite source code. Never modify CI without user confirmation.

</instructions>
