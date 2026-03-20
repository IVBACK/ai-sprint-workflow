<instructions>

# Bootstrap Phase 4a — Blind Review

Read `.bootstrap/plan-draft.md` and send it to a sub-agent for independent review.

```
  → prompt: "You are reviewing a project plan. You have no context about
             why it was designed this way — evaluate it independently.

             [contents of .bootstrap/plan-draft.md]

             Review for:
             1. What assumptions are unchallenged?
             2. Security gaps or data loss scenarios
             3. Wrong or outdated technology choices
             4. Missing edge cases or dependencies
             5. Unrealistic scope (too many items, unclear ordering)
             6. Is the critical axis properly addressed throughout?

             For each finding: severity (critical/warning/info), description, suggestion."

  → sub-agent has no context from Phase 1-3 — that's the point (blind)
  → The plan-draft.md includes a 1-line project description and critical axis —
    this gives the reviewer WHAT context, not WHY context
  → WAIT for sub-agent to complete (do NOT background)
  → incorporate findings into .bootstrap/plan-draft.md

IF critical gap found (security, data loss, legal risk):
  → mention naturally when presenting plan in Phase 5
ELSE:
  → incorporate silently, user doesn't see this step
```

## Exit Condition

Blind review completed, findings incorporated into plan-draft.md.

→ Read **Docs/Workflow/BOOTSTRAP-PHASE4B.md**

</instructions>
