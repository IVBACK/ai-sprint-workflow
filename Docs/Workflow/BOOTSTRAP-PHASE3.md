<instructions>

# Bootstrap Phase 3 — Plan Draft

This phase is internal — the user does NOT see the plan yet.
Write the plan to `.bootstrap/plan-draft.md` — Phase 4 reviewers read from this file.

From scan + answers + **research findings**, draft:

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

## Items (build order)
1. [highest risk/value first] — [why first]
2. [next] — [why]
...

## Dependencies
[which items depend on which — explicit order]

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
