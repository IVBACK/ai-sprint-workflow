<instructions>

# Bootstrap Phase 3 — Plan Draft

This phase is internal — the user does NOT see the plan yet.
Write the plan to `.bootstrap/plan-draft.md` — Phase 4 reviewers read from this file.

This plan will become the project Roadmap after user approval. Each sprint in the Roadmap
has: a one-line goal, Must/Should/Could items with CORE-### IDs, metric gates, and dependencies.
Keep this target format in mind when structuring the plan — but write the plan draft as an
analysis document (dependencies, risks, reasoning), not as the final Roadmap.

Read `.bootstrap/intake-summary.md` and `.bootstrap/research-notes.md` if they exist.
These contain persisted findings from Phase 1 and Phase 2 — use them alongside conversation context.

From scan + answers + research findings, draft:

```
# Plan Draft

## Project
[1-line description: what it is, who it's for, key tech]

## Tech Stack
[languages, frameworks, databases, key libraries — from research findings + user answers]
[e.g. "Next.js 15, PostgreSQL, Stripe SDK, deployed on Vercel"]

## Critical Axis
[one of: correctness | security | performance | reliability]
[1-line why — e.g. "payments processing, calculation errors = financial loss"]

## Items
[List ALL items needed to complete the project, with dependencies]
1. [item] — depends on: nothing
2. [item] — depends on: 1
3. [item] — depends on: 1
...

## Sprint Split
Distribute items across sprints using these criteria:
- Build the dependency graph. Items with no dependencies (or only on completed items) can go first.
- Each sprint ends with something usable/testable — not half-built foundations.
- Sprint size: 3-5 Must items (small project), 5-8 (medium). Exceeding this = split further.
- Higher risk/uncertainty items in earlier sprints (fail fast).
- If everything fits in one sprint (≤5 items, no complex dependencies), one sprint is fine.

Result: assign each item a sprint number (S1, S2, ...) and priority (Must/Should/Could).
Later sprints are sketch-level only (goal + item names, no metric gates yet).

## Key Assumptions
[including any skipped research topics from Phase 2]

## Risks
[what could go wrong, what's uncertain]
```

Critical Axis — every project has one. Pick the most important:
- **correctness**: payments, calculations, medical, legal
- **security**: auth, user data, API keys, multi-tenant
- **performance**: games, real-time, high traffic, video/audio
- **reliability**: infrastructure, CI/CD, messaging, scheduling

```
IF greenfield:
  → plan is based on user's answers + research findings
IF existing project:
  → plan incorporates scan findings + research findings
```

## Exit Condition

Plan written to `.bootstrap/plan-draft.md`. Ready for blind review.

→ Read **Docs/Workflow/BOOTSTRAP-PHASE4.md**

</instructions>
