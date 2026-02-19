# Roadmap Design Session

**For the AI agent:** Read this file and conduct a roadmap design conversation with the user.
Goal: produce `Docs/Planning/Roadmap.md` rich enough to guide the full project — not a minimal skeleton.

**Usage flow:**
1. Start an AI session. Tell the agent:
   *"Fetch https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/ROADMAP-DESIGN-PROMPT.md and design the roadmap."*
2. Have the conversation. Agent writes `Docs/Planning/Roadmap.md` and asks for approval.
3. Then bootstrap — in the same or a new session:
   *"Fetch https://raw.githubusercontent.com/IVBACK/ai-sprint-workflow/master/WORKFLOW.md and bootstrap this project."*
   Bootstrap detects the existing `Roadmap.md` → skips Initial Planning automatically.

---

## Conversation Guide

Ask in **batches of 3-4 questions**, not one at a time. Let answers drive depth — extract everything
the user knows; do not pad if they know little.

**When the user is undecided on a question:** do not leave it open. Present 2-3 concrete options
with one-line trade-offs, then give a recommendation based on what you know about the project so far.
Example: *"Option A (recommended for your use case): ... — Option B: ... — Option C: ..."*
Lock the chosen option as an immutable contract before moving to Batch 3.

**Batch 1 — Foundation**
- What are you building? (goal, scale, platform, target users)
- Is this a rewrite or iteration on prior work? If yes: what is the single biggest lesson from it?
- What tech stack? (language, framework, runtime — if undecided, resolve in Batch 2)
- What technical decisions are already locked? (data formats, buffer layouts, API contracts, naming conventions)
- Critical Axis: what is the #1 non-negotiable quality concern? (security / performance / reliability / correctness / other)

**Batch 2 — Domain knowledge extraction** *(shaped by Batch 1 answers)*

If rewrite / prior work exists:
- What systems or patterns are absent from day 0 — and why?
- What failure chains or anti-patterns must be prevented?
- Are there architectural decisions that caused pain and must not be repeated? *(produces "Architectural Differences" table)*

If performance is the Critical Axis:
- Target hardware spec? FPS target? Any per-system time budgets?
- Which systems need kill-switches or fallback modes?

If security is the Critical Axis:
- What data is stored and how sensitive? (user PII, financial, health, etc.)
- What auth model? (JWT, session, OAuth, API key — if undecided, offer options with recommendation)
- Any compliance requirements? (regulatory, data retention, audit logging)

If correctness is the Critical Axis:
- What constitutes a correctness failure? (financial loss, scientific error, legal liability)
- Are there external validators, auditors, or spec documents that define "correct"?

If reliability is the Critical Axis:
- What is the uptime / availability requirement? (99.9%? 99.99%?)
- What is the cost of downtime? (revenue, safety, contractual penalty)

For all projects:
- Expected scale: concurrent users / players / transactions? Any peak scenarios? *(shapes architecture decisions)*
- If platform answer was ambiguous (e.g. "mobile"): clarify type — responsive web, PWA, React Native, native iOS/Android?
- If tech stack was undecided in Batch 1: present 2-3 options with one-line trade-offs + recommendation based on project context
- Does the project write versioned formats to disk? (cache files, save files, binary streams, network protocol)
  If yes: establish MAJOR.MINOR versioning policy before Sprint 1.
- Known technical constraints or external dependencies to work around?
- Any immutable contracts: data formats, wire protocols, serialization schemas, API surfaces?

**Batch 3 — Plan**

Once context is clear, propose — and get approval for each before proceeding:

1. **Phases** (4-6 max): title + one-line description each
2. **Sprint dependency sketch**: critical path + parallel opportunities (ASCII or prose)
3. **Sprint 1**: Must/Should/Could items → assign CORE-### IDs → add at least one metric per Must item
4. **Remaining sprints**: brief sketches — not full plans. For each, include:
   - Core scope (one line: what this sprint delivers)
   - *Watch for* (1-2 known risks, open decisions, or dependencies to verify at Entry Gate)
   - Do NOT write Must/Should/Could or metrics yet — those are Entry Gate work
5. **Final check**: before writing the file, present a summary of everything decided in the session, then ask if anything needs to change. Format:

   > **Here's what we've locked:**
   > - Stack: ...
   > - Contracts: ... (list all immutable decisions)
   > - Auth / money / storage rules: ...
   >
   > **Deferred (must resolve before indicated sprint):**
   > - [Decision] → Sprint N Entry Gate
   >
   > **Plan: [N] phases, [M] sprints**
   > - Sprint 1: [title] — [Must item count] Must items
   > - Sprint 2–N: [one-liner each]
   >
   > **Things you might also want to consider** *(based on your project context — ignore if not relevant):*
   > - [Suggestion 1 relevant to their domain/stack/scale]
   > - [Suggestion 2]
   > - [Suggestion 3 max]
   >
   > *Anything you'd like to add, change, or that I might have missed?*

   Incorporate any answers, then write the roadmap file.

   **Suggestion guidelines:** Base suggestions on what you know about the project — domain, stack, critical axis, scale. 2-3 max. Do not pad with generic advice. Examples by domain:
   - E-commerce: order cancellation flow, email notifications, discount/coupon system, return policy
   - Game: save/load system, analytics events, crash reporting, platform-specific constraints
   - SaaS: billing/subscription lifecycle, tenant isolation, audit logging, onboarding flow
   - API/backend: rate limiting, API versioning strategy, monitoring/alerting

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

## Architectural Differences  ← only if rewrite with intentional architecture changes
| Area | Before | Now | Reason |
|------|--------|-----|--------|
| ...  | ...    | ... | ...    |

## Non-Negotiable Contracts  ← only if locked technical decisions exist
- [Data format: e.g. "SDF: float4(density, materialID, reserved1, reserved2)"]
- [Layout: e.g. "Density grid: 35×35×35"]
- [Convention: e.g. "density > 0 = solid, density < 0 = air"]

## Versioning Policy  ← only if project writes versioned formats to disk
- Format: MAJOR.MINOR — MAJOR = breaking change (old file unreadable), MINOR = backward-compatible addition
- [Format name]: current v1, stored at [path/header location]
- Rule: MAJOR bump requires explicit commit message tag: [BREAKING] ...

## Performance Budget  ← only if performance is Critical Axis
| System | Budget | Measurement point |
|--------|--------|-------------------|
| ...    | ...    | ...               |

## Scale Targets  ← only if scale shapes architecture decisions
| Metric | Target | Notes |
|--------|--------|-------|
| ...    | ...    | ...   |

## Kill-Switch Strategy  ← only if applicable
| System | Toggle | Fallback |
|--------|--------|----------|
| ...    | ...    | ...      |

## Fallback Matrix  ← only if applicable
| System | Fail condition | Fallback | Sprint |
|--------|---------------|----------|--------|
| ...    | ...           | ...      | ...    |

## Deferred Decisions  ← only if critical decisions could not be locked in this session
| Decision | Options considered | Must resolve by | Blocks |
|----------|--------------------|----------------|--------|
| ...      | ...                | Sprint N Entry Gate | ... |

## Sprint Dependency Map
​```
S1 → S2 → S3 → ...
           ↳ S4 (parallel)
​```

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
Core: [one-line scope]
Watch for: [known risk or open decision] / [dependency to verify]

**Sprint 3 — [Title]** *(sketch)*
Core: [one-line scope]
Watch for: [known risk or open decision]
```

---

## Format Rules (Required for Workflow Compatibility)

- **CORE-### IDs:** every item needs one. Start at CORE-001, or continue from highest existing ID if `TRACKING.md` already has items. Never reuse an ID.
- **Must/Should/Could:** mandatory distinction on every sprint. No flat item lists.
- **Metrics:** at least one per Sprint 1 Must item. Later sprints: add metrics when detailed at Entry Gate.
- **Future sprints:** brief sketches — core scope (one line) + *Watch for* (1-2 known risks or open decisions). Do not write Must/Should/Could or metrics — that is Entry Gate work.
- **Sections:** only write sections that have real content. An empty "Performance Budget" section is worse than none.
- **Deferred Decisions:** Entry Gate for the blocking sprint must verify the decision is locked before proceeding. If still open at that Entry Gate, it is a blocker.
