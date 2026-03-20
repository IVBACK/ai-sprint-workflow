<instructions>

# Bootstrap Phase 2 — Research

Research MUST happen BEFORE plan drafting. The plan quality depends on up-to-date information.

```
MANDATORY unless ALL of these are true:
  - project is obviously trivial (single-file script, pure CLI with no deps)
  - no external dependencies, APIs, or frameworks to evaluate
  - no technology choice decisions

HOW:
  1. Identify research topics from Phase 1 answers:
     - technology choices (e.g. "Fishnet vs Unity Netcode for 5v5")
     - API/SDK current state (e.g. "Stripe checkout flow 2026")
     - framework best practices for the stack
     - domain-specific constraints
  2. Present the list to the user:
     → "Before I plan, I want to research these:
        - [topic1] — [why]
        - [topic2] — [why]
        Anything else I should look into?"
  3. WAIT for user response. Add any extra topics they mention.
  4. Use WebSearch/WebFetch. Gather ALL topics in one batch.
     IF multiple independent topics: delegate to sub-agents per topic
     for parallel research (keeps main context clean).
     IMPORTANT: Do at least one WebSearch directly (not via sub-agent)
     to trigger the research-done marker. Then delegate remaining topics.
  5. Summarize key findings internally (user doesn't see raw results).
  6. IF stuck (search returns irrelevant results): try different search terms,
     alternative sources, or ask user for pointers. Do NOT repeat the same
     failing query. (Full escalation protocol: IMPL-LOOP.md §B.2)

IF trivial project (all skip conditions met) OR user explicitly says "skip research":
  → do a single WebSearch on the primary framework/language to satisfy the research marker
  → note skipped topics as assumptions/risks in the plan
  → proceed to Phase 3
```

## Exit Condition

Research completed — findings in hand, not backgrounded, ready to inform the plan.

→ Read **Docs/Workflow/BOOTSTRAP-PHASE3.md**

</instructions>
