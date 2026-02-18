# Roadmap Design Session

**For the AI agent:** Read this file and conduct a roadmap design conversation with the user.
Goal: produce `Docs/Planning/Roadmap.md` rich enough to guide the full project — not a minimal skeleton.

**Usage flow:**
1. Start an AI session. Tell the agent:
   *"Fetch https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/ROADMAP-DESIGN-PROMPT.md and design the roadmap."*
2. Have the conversation. Agent writes `Docs/Planning/Roadmap.md` and asks for approval.
3. Then bootstrap — in the same or a new session:
   *"Fetch https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/TEMPLATE.md and bootstrap this project."*
   Bootstrap detects the existing `Roadmap.md` → skips Initial Planning automatically.

---

## Conversation Guide

Ask in **batches of 3-4 questions**, not one at a time. Let answers drive depth — extract everything
the user knows; do not pad if they know little.

**Batch 1 — Foundation**
- What are you building? (goal, scale, platform, target users)
- Is this a rewrite or iteration on prior work? If yes: what is the single biggest lesson from it?
- What technical decisions are already locked? (data formats, buffer layouts, API contracts, naming conventions)
- Critical Axis: what is the #1 non-negotiable quality concern? (security / performance / reliability / correctness / other)

**Batch 2 — Domain knowledge extraction** *(shaped by Batch 1 answers)*

If rewrite / prior work exists:
- What systems or patterns are absent from day 0 — and why?
- What failure chains or anti-patterns must be prevented?
- Are there architectural decisions that caused pain and must not be repeated?

If performance is the Critical Axis:
- Target hardware spec? FPS target? Any per-system time budgets?
- Which systems need kill-switches or fallback modes?

For all projects:
- Known technical constraints or external dependencies to work around?
- Any immutable contracts: data formats, wire protocols, serialization schemas, API surfaces?

**Batch 3 — Plan**

Once context is clear, propose — and get approval for each before proceeding:

1. **Phases** (4-6 max): title + one-line description each
2. **Sprint dependency sketch**: critical path + parallel opportunities (ASCII or prose)
3. **Sprint 1**: Must/Should/Could items → assign CORE-### IDs → add at least one metric per Must item
4. **Remaining sprints**: one-line sketches only (they are detailed at Entry Gate, not now)

---

## Output: `Docs/Planning/Roadmap.md`

Produce sections that have content. **Omit sections with nothing to say.**

```markdown
# [Project Name] Roadmap

## Context
[What this is, why now, key background decisions]

## Critical Learnings  ← only if rewrite / prior work
1. [Concrete lesson — what happened and why it's absent from day 0]
2. ...

## Non-Negotiable Contracts  ← only if locked technical decisions exist
- [Data format: e.g. "SDF: float4(density, materialID, reserved1, reserved2)"]
- [Layout: e.g. "Density grid: 35×35×35"]
- [Convention: e.g. "density > 0 = solid, density < 0 = air"]

## Performance Budget  ← only if performance is Critical Axis
| System | Budget | Measurement point |
|--------|--------|-------------------|
| ...    | ...    | ...               |

## Kill-Switch Strategy  ← only if applicable
| System | Toggle | Fallback |
|--------|--------|----------|
| ...    | ...    | ...      |

## Fallback Matrix  ← only if applicable
| System | Fail condition | Fallback | Sprint |
|--------|---------------|----------|--------|
| ...    | ...           | ...      | ...    |

## Sprint Dependency Map
```
S1 → S2 → S3 → ...
           ↳ S4 (parallel)
```

## Roadmap — [N] Phases, [M] Sprints

### Scope Execution Rule
- **Must:** sprint does not close without this item
- **Should:** done if time remains; otherwise moves to next sprint backlog automatically
- **Could:** taken only if budget exists; first to drop

### Phase 1 — [Name] (Sprint 1–N)

**Sprint 1 — [Title]**

**Must:**
- [ ] CORE-001: [deliverable behavior — one feature, fix, or refactor]

**Should:**
- [ ] CORE-002: [item]

**Could:**
- [ ] CORE-003: [item]

**Dependency:** None

**Metrics:**
- [ ] [measurable criterion — inputs, expected output, threshold]

**Sprint 2 — [Title]** *(sketch — detailed at Entry Gate)*
**Sprint 3 — [Title]** *(sketch)*
```

---

## Format Rules (Required for Workflow Compatibility)

- **CORE-### IDs:** every item needs one. Start at CORE-001, or continue from highest existing ID if `TRACKING.md` already has items. Never reuse an ID.
- **Must/Should/Could:** mandatory distinction on every sprint. No flat item lists.
- **Metrics:** at least one per Sprint 1 Must item. Later sprints: add metrics when detailed at Entry Gate.
- **Future sprints:** one-line sketches only — do not pre-detail them now.
- **Sections:** only write sections that have real content. An empty "Performance Budget" section is worse than none.
